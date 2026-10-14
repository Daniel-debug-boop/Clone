#!/usr/bin/env bash
#
# Fetch, validate and link the third-party Godot modules this repository needs
# into a Godot engine source tree.
#
# Everything is checked before anything is compiled, and the checks report all
# problems at once so a failure names the exact repository, file, module
# configuration or duplicate dependency at fault instead of a compiler error.
#
# Usage:
#   integrate_engine_modules.sh plan           Show the resolved integration plan.
#   integrate_engine_modules.sh check-remote   Verify the URLs of active rows are reachable.
#   integrate_engine_modules.sh fetch          Clone the engine and the active modules.
#   integrate_engine_modules.sh validate       Check sources, module registration and duplicates.
#   integrate_engine_modules.sh link           Symlink active modules into <engine>/modules.
#   integrate_engine_modules.sh all            fetch + validate + link.
#
# Environment:
#   WORKSPACE       Repository root. Default: $GITHUB_WORKSPACE, else git top level, else $PWD.
#   MODULES_DIR     Where third-party sources live. Default: $WORKSPACE/modules.
#   MANIFEST        Manifest path. Default: <script dir>/modules.manifest.tsv.
#   ENGINE_KEY      Manifest key of the engine row. Default: godot-engine.
#   ENGINE_REF      Optional ref override for the engine row.
#   LINK_MODULES    Comma separated manifest keys of the modules to link. Empty = every
#                   'module' row in the manifest. Use this for an engine-only build.
#   CLONE_DEPTH     git clone depth. Default: 1.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${MANIFEST:-$SELF_DIR/modules.manifest.tsv}"
WORKSPACE="${WORKSPACE:-${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
MODULES_DIR="${MODULES_DIR:-$WORKSPACE/modules}"
ENGINE_KEY="${ENGINE_KEY:-godot-engine}"
ENGINE_REF="${ENGINE_REF:-}"
# NOTE: LINK_MODULES is deliberately left unset when the caller does not provide
# it, so `${LINK_MODULES+set}` below can tell "unset" from "set to empty".
CLONE_DEPTH="${CLONE_DEPTH:-1}"

KEYS=(); URLS=(); REFS=(); ROLES=(); LINKS=(); NOTES=()
ACTIVE_KEYS=()
PROBLEMS=()

log()     { printf '\033[1;34m[integrate]\033[0m %s\n' "$*"; }
ok()      { printf '\033[1;32m[   ok   ]\033[0m %s\n' "$*"; }
warn()    { printf '\033[1;33m[  warn  ]\033[0m %s\n' "$*"; }
problem() { PROBLEMS+=("$1"); printf '\033[1;31m[  FAIL  ]\033[0m %s\n' "$1"; }
die()     { printf '\033[1;31m[  FAIL  ]\033[0m %s\n' "$*" >&2; exit 1; }

summary() {
  # Publish to the GitHub Actions job summary when running in Actions.
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
}

# --- manifest ---------------------------------------------------------------

load_manifest() {
  [ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"

  # Guard against the classic TSV trap: tab is IFS whitespace, so an empty field
  # collapses and shifts every following column. Require all 6 fields present.
  local bad
  bad="$(awk -F'\t' '
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    { if (NF != 6) { printf "line %d has %d fields; ", NR, NF; next }
      for (i = 1; i <= 6; i++)
        if ($i == "") { printf "line %d field %d is empty; ", NR, i }
    }' "$MANIFEST")"
  [ -z "$bad" ] || die "manifest $MANIFEST must have exactly 6 tab-separated fields per row and none may be empty: $bad"

  local key url ref role link note
  while IFS=$'\t' read -r key url ref role link note || [ -n "${key:-}" ]; do
    case "${key:-}" in ''|'#'*) continue ;; esac
    # '-' is the manifest's placeholder for "not applicable".
    [ "$ref" = "-" ] && ref=""
    [ "$link" = "-" ] && link=""
    KEYS+=("$key"); URLS+=("$url"); REFS+=("$ref"); ROLES+=("$role"); LINKS+=("$link"); NOTES+=("${note:-}")
  done < "$MANIFEST"

  [ "${#KEYS[@]}" -gt 0 ] || die "manifest $MANIFEST contains no entries"
}

role_of() { # key -> role
  local i
  for i in "${!KEYS[@]}"; do
    if [ "${KEYS[$i]}" = "$1" ]; then printf '%s' "${ROLES[$i]}"; return 0; fi
  done
  return 1
}

index_of() { # key -> index
  local i
  for i in "${!KEYS[@]}"; do
    if [ "${KEYS[$i]}" = "$1" ]; then printf '%s' "$i"; return 0; fi
  done
  printf '%s' "-1"
}

validate_manifest() {
  local i j engines=0
  for i in "${!KEYS[@]}"; do
    [ "${ROLES[$i]}" = "engine" ] && engines=$((engines + 1))
    case "${ROLES[$i]}" in
      engine|module|exclude) ;;
      *) problem "manifest row '${KEYS[$i]}' has unknown role '${ROLES[$i]}' (expected engine|module|exclude)" ;;
    esac
    [ -n "${URLS[$i]}" ] || problem "manifest row '${KEYS[$i]}' has no url"
    if [ "${ROLES[$i]}" = "module" ]; then
      [ -n "${LINKS[$i]}" ] || problem "manifest module row '${KEYS[$i]}' has no link name"
    fi
    # duplicate keys / duplicate link names
    for j in "${!KEYS[@]}"; do
      [ "$j" -gt "$i" ] || continue
      [ "${KEYS[$i]}" = "${KEYS[$j]}" ] && problem "manifest declares key '${KEYS[$i]}' twice"
      if [ -n "${LINKS[$i]}" ] && [ "${LINKS[$i]}" = "${LINKS[$j]}" ]; then
        problem "manifest maps '${LINKS[$i]}' to two different rows ('${KEYS[$i]}' and '${KEYS[$j]}')"
      fi
    done
  done
  [ "$engines" -eq 1 ] || problem "manifest must declare exactly one engine row, found $engines"
}

# Resolve which module rows are active (LINK_MODULES override, else every module row).
resolve_active() {
  ACTIVE_KEYS=()
  local want=() i k found
  # LINK_MODULES set (even to the empty string) selects exactly those modules;
  # LINK_MODULES unset means "every module row in the manifest".
  if [ -n "${LINK_MODULES+set}" ]; then
    want=()
    IFS=',' read -r -a want <<< "$LINK_MODULES"
  else
    for i in "${!KEYS[@]}"; do
      [ "${ROLES[$i]}" = "module" ] && want+=("${KEYS[$i]}")
    done
  fi
  for k in "${want[@]}"; do
    k="${k// /}"
    [ -n "$k" ] || continue
    local role; role="$(role_of "$k" || true)"
    if [ -z "$role" ]; then
      problem "LINK_MODULES names unknown key '$k'; manifest keys are: ${KEYS[*]}"
      continue
    fi
    if [ "$role" != "module" ]; then
      problem "LINK_MODULES names '$k' but its role is '$role', not 'module'"
      continue
    fi
    found=0
    for i in "${ACTIVE_KEYS[@]}"; do [ "$i" = "$k" ] && found=1; done
    [ "$found" -eq 1 ] || ACTIVE_KEYS+=("$k")
  done
}

repo_dir() { printf '%s/%s' "$MODULES_DIR" "$1"; }
engine_dir() { repo_dir "$ENGINE_KEY"; }

# --- commands ---------------------------------------------------------------

cmd_plan() {
  local i
  log "workspace: $WORKSPACE"
  log "manifest : $MANIFEST"
  printf '\n%-38s %-9s %-10s %s\n' KEY ROLE LINK URL
  for i in "${!KEYS[@]}"; do
    printf '%-38s %-9s %-10s %s\n' "${KEYS[$i]}" "${ROLES[$i]}" "${LINKS[$i]:--}" "${URLS[$i]}"
  done
  printf '\nactive modules to link: %s\n' "${ACTIVE_KEYS[*]:-<none>}"
  printf '\n%s\n' "notes:"
  for i in "${!KEYS[@]}"; do
    [ "${ROLES[$i]}" = "exclude" ] || continue
    printf '  %-36s %s\n' "${KEYS[$i]}" "${NOTES[$i]}"
  done
}

cmd_check_remote() {
  local i key role url ref
  local active=( "$ENGINE_KEY" "${ACTIVE_KEYS[@]}" )
  for key in "${active[@]}"; do
    [ -n "$key" ] || continue
    i="$(index_of "$key")"; [ "$i" != "-1" ] || continue
    url="${URLS[$i]}"; ref="${REFS[$i]}"
    [ "$key" = "$ENGINE_KEY" ] && [ -n "$ENGINE_REF" ] && ref="$ENGINE_REF"
    local reachable=1
    if [ -n "$ref" ]; then
      git ls-remote --exit-code "$url" "$ref" >/dev/null 2>&1 && reachable=0
    else
      git ls-remote --exit-code --heads "$url" >/dev/null 2>&1 && reachable=0
    fi
    if [ "$reachable" -eq 0 ]; then
      ok "reachable: $key ($url)"
    else
      problem "required repository '$key' is not reachable: $url (404, renamed or private?)"
    fi
  done
}

clone_one() { # key
  local key="$1" i dest url ref
  i="$(index_of "$key")"
  url="${URLS[$i]}"; ref="${REFS[$i]}"
  [ "$key" = "$ENGINE_KEY" ] && [ -n "$ENGINE_REF" ] && ref="$ENGINE_REF"
  dest="$(repo_dir "$key")"

  if [ -d "$dest/.git" ]; then
    ok "already cloned: modules/$key"
    return 0
  fi
  mkdir -p "$MODULES_DIR"
  # A tracked gitlink without .gitmodules leaves an empty directory behind; clear it.
  rm -rf "$dest"

  local attempt
  for attempt in 1 2 3; do
    if [ -n "$ref" ]; then
      if git clone --filter=blob:none --no-checkout "$url" "$dest" 2>/dev/null \
         && git -C "$dest" checkout --quiet "$ref"; then
        ok "cloned modules/$key @ $ref"
        return 0
      fi
    elif git clone --depth "$CLONE_DEPTH" --recurse-submodules --shallow-submodules "$url" "$dest"; then
      ok "cloned modules/$key (default branch)"
      return 0
    fi
    warn "clone attempt $attempt/3 failed for $key ($url)"
    rm -rf "$dest"
    sleep $((attempt * 5))
  done
  problem "could not clone '$key' from $url (ref '${ref:-<default branch>}')"
  return 1
}

cmd_fetch() {
  clone_one "$ENGINE_KEY" || true
  local key
  for key in "${ACTIVE_KEYS[@]}"; do
    clone_one "$key" || true
  done
}

validate_engine() {
  local dir; dir="$(engine_dir)"
  if [ ! -d "$dir" ]; then
    problem "engine source missing at modules/$ENGINE_KEY; run '$0 fetch' first"
    return 1
  fi
  local rel missing=()
  for rel in SConstruct version.py core main platform modules thirdparty; do
    [ -e "$dir/$rel" ] || missing+=("$rel")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    problem "engine source at modules/$ENGINE_KEY is incomplete; missing: ${missing[*]}"
    return 1
  fi
  ok "engine source complete: modules/$ENGINE_KEY"
  return 0
}

validate_module() { # key
  local key="$1" dir missing=()
  dir="$(repo_dir "$key")"
  if [ ! -d "$dir" ]; then
    problem "required module '$key' is missing at modules/$key (tracked gitlink with no .gitmodules?)"
    return 1
  fi
  if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    problem "required module '$key' at modules/$key is an empty directory (submodule never initialized?)"
    return 1
  fi
  [ -f "$dir/config.py" ] || missing+=("config.py")
  if [ ! -f "$dir/register_types.cpp" ] && [ ! -f "$dir/register_types.h" ]; then
    missing+=("register_types.cpp or register_types.h")
  fi
  if [ "${#missing[@]}" -gt 0 ]; then
    problem "module '$key' has no valid Godot module registration at modules/$key; missing ${missing[*]}"
    return 1
  fi
  if [ ! -f "$dir/SCsub" ]; then
    warn "module '$key' has no SCsub; relying on the default source globbing"
  fi
  ok "module '$key': config.py + register_types present"
  return 0
}

# Report third-party sources that the engine already ships, so a duplicate is
# visible before it turns into a confusing module-name collision.
detect_duplicates() {
  local edir; edir="$(engine_dir)"
  [ -d "$edir/modules" ] || return 0
  local i name cand role hit
  for i in "${!KEYS[@]}"; do
    role="${ROLES[$i]}"
    [ "$role" = "engine" ] && continue
    for name in "${KEYS[$i]}" "${LINKS[$i]}"; do
      [ -n "$name" ] || continue
      for cand in "$name" "${name//-/_}"; do
        hit=""
        if [ -e "$edir/modules/$cand" ]; then hit="modules/$cand"; fi
        if [ -e "$edir/thirdparty/$cand" ]; then hit="${hit:+$hit and }thirdparty/$cand"; fi
        [ -n "$hit" ] || continue
        if [ "$role" = "module" ]; then
          problem "duplicate dependency: '$name' collides with $hit already shipped by the engine"
        else
          warn "duplicate dependency: '$name' matches $hit already shipped by the engine (row is role=$role, so it is not linked)"
        fi
        break
      done
    done
  done
}

cmd_validate() {
  validate_manifest
  validate_engine || true
  local key
  for key in "${ACTIVE_KEYS[@]}"; do
    validate_module "$key" || true
  done
  detect_duplicates
  [ "${#PROBLEMS[@]}" -eq 0 ] && cmd_summary
  return 0
}

cmd_link() {
  local edir target key dest resolved i
  edir="$(engine_dir)"
  target="$edir/modules"
  [ -d "$target" ] || die "engine modules directory not found: $target"
  for key in "${ACTIVE_KEYS[@]}"; do
    i="$(index_of "$key")"
    dest="$target/${LINKS[$i]}"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      problem "refusing to replace non-symlink $dest (existing module with the same name?)"
      continue
    fi
    # The engine lives at modules/<engine>, so its own modules/ is two levels down.
    ln -sfn "../../$key" "$dest"
    resolved="$(readlink -f "$dest" 2>/dev/null || true)"
    if [ -z "$resolved" ] || [ ! -d "$resolved" ]; then
      problem "symlink $dest -> ../../$key is dangling (expected to resolve into modules/$key)"
      continue
    fi
    if [ ! -f "$resolved/config.py" ]; then
      problem "symlink $dest resolves to $resolved, which has no config.py"
      continue
    fi
    ok "linked modules/${LINKS[$i]} -> ../../$key"
  done
}

fail_if_problems() {
  local n="${#PROBLEMS[@]}" i=1 p
  if [ "$n" -gt 0 ]; then
    printf '\n'
    printf '\033[1;31m%d integration problem(s):\033[0m\n' "$n"
    for p in "${PROBLEMS[@]}"; do
      printf '  %d. %s\n' "$i" "$p"
      i=$((i + 1))
    done
    summary "### Integration failed"
    summary ""
    for p in "${PROBLEMS[@]}"; do summary "- $p"; done
    exit 1
  fi
}

cmd_summary() {
  summary "### Engine integration"
  summary ""
  summary "| key | role | link | module registration |"
  summary "| --- | --- | --- | --- |"
  local i key reg
  for i in "${!KEYS[@]}"; do
    [ "${ROLES[$i]}" = "engine" ] && continue
    reg="not linked"
    if [ "${ROLES[$i]}" = "module" ] && [ -f "$(repo_dir "${KEYS[$i]}")/config.py" ]; then
      reg="config.py + register_types"
    fi
    summary "| \`${KEYS[$i]}\` | ${ROLES[$i]} | ${LINKS[$i]:--} | ${reg} |"
  done
}

cmd_all() { cmd_fetch; cmd_validate; fail_if_problems; cmd_link; fail_if_problems; cmd_summary; }

main() {
  load_manifest
  resolve_active
  local cmd="${1:-plan}"
  case "$cmd" in
    plan)         cmd_plan ;;
    check-remote) cmd_check_remote; fail_if_problems ;;
    fetch)        cmd_fetch; fail_if_problems ;;
    validate)     cmd_validate; fail_if_problems ;;
    link)         cmd_link; fail_if_problems ;;
    all)          cmd_all ;;
    *)            die "unknown command '$cmd' (expected: plan|check-remote|fetch|validate|link|all)" ;;
  esac
}

main "$@"
