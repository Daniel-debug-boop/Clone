#!/usr/bin/env bash
#
# Verify that a freshly built Godot engine binary really exists and runs.
#
# Checks, in order:
#   1. a matching binary exists under <engine_dir>/bin
#   2. it is executable
#   3. it is an ELF executable
#   4. it is plausibly complete (>= MIN_BINARY_BYTES)
#   5. `<binary> --version` exits 0 and identifies itself as Godot
#   6. `<binary> --headless --version` exits 0 (the headless startup path works)
#   7. no shared library is missing according to ldd
#
# On success the absolute path is printed to stdout and exported as the
# `binary` (and `version`) step output when running under GitHub Actions.
#
# Usage:
#   verify_engine_binary.sh <engine_dir> [name_pattern]
#
# Environment:
#   MIN_BINARY_BYTES      Minimum plausible binary size. Default: 20000000.
#   VERSION_TIMEOUT       Seconds allowed for the version run. Default: 120.
#   EXPECT_VERSION_REGEX  ERE the `--version` output must match. Default: '^[0-9]+\.[0-9]+'
#                         (Godot prints e.g. "4.6.stable.official.1234abcd", not a banner).
#   EXPECT_VERSION        Optional exact substring that must appear in `--version` output.
#   RUN_STARTUP_TEST      Set to 0 to skip the headless startup check. Default: 1.
#   SKIP_LD_CHECK         Set to 1 to skip the ldd check.

set -euo pipefail

ENGINE_DIR="${1:-}"
PATTERN="${2:-godot.linuxbsd.editor*}"

die() { printf '\033[1;31m[  FAIL  ]\033[0m %s\n' "$*" >&2; exit 1; }
ok()  { printf '\033[1;32m[   ok   ]\033[0m %s\n' "$*"; }
log() { printf '\033[1;34m[ verify ]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[  warn  ]\033[0m %s\n' "$*"; }

[ -n "$ENGINE_DIR" ] || die "usage: verify_engine_binary.sh <engine_dir> [name_pattern]"
[ -d "$ENGINE_DIR" ] || die "engine directory not found: $ENGINE_DIR"

MIN_BINARY_BYTES="${MIN_BINARY_BYTES:-20000000}"
VERSION_TIMEOUT="${VERSION_TIMEOUT:-120}"
EXPECT_VERSION_REGEX="${EXPECT_VERSION_REGEX:-^[0-9]+\.[0-9]+}"
EXPECT_VERSION="${EXPECT_VERSION:-}"

BIN_DIR="$ENGINE_DIR/bin"
[ -d "$BIN_DIR" ] || die "no build output directory at $BIN_DIR (SCons never produced bin/)"

log "looking for '$PATTERN' in $BIN_DIR"
# Collect everything that matches, then pick the most specific executable.
# .so/.debugsymbols/.console are never the engine executable.
mapfile -t MATCHES < <(
  find "$BIN_DIR" -maxdepth 1 -type f -name "$PATTERN" \
    ! -name '*.so' ! -name '*.debugsymbols' ! -name '*.console' | sort
)
if [ "${#MATCHES[@]}" -eq 0 ]; then
  printf 'contents of %s:\n' "$BIN_DIR" >&2
  ls -la "$BIN_DIR" >&2 || true
  die "expected engine binary matching '$PATTERN' was not produced in $BIN_DIR"
fi

BINARY=""
for cand in "${MATCHES[@]}"; do
  if [ -x "$cand" ]; then BINARY="$cand"; break; fi
done
if [ -z "$BINARY" ]; then
  printf 'candidates (none executable): %s\n' "${MATCHES[*]}" >&2
  die "no executable engine binary in $BIN_DIR; the link step probably failed"
fi
BINARY="$(cd "$(dirname "$BINARY")" && pwd -P)/$(basename "$BINARY")"
ok "binary found: $BINARY"

# 2 + 3: ELF magic (no dependency on the `file` utility).
MAGIC="$(od -An -tx1 -N4 "$BINARY" | tr -d ' \n')"
[ "$MAGIC" = "7f454c46" ] || die "not an ELF executable (magic '$MAGIC'): $BINARY"
ok "ELF executable"

# 4: plausible size, catches truncated/failed links.
SIZE="$(stat -c '%s' "$BINARY")"
[ "$SIZE" -ge "$MIN_BINARY_BYTES" ] \
  || die "binary is only $SIZE bytes, expected at least $MIN_BINARY_BYTES (truncated build?)"
ok "size $SIZE bytes"

# 5: real version check. Godot's `--version` prints just the version number
# (e.g. "4.6.stable.official.1234abcd"), not the "Godot Engine v..." banner.
set +e
VERSION_OUT="$(timeout "$VERSION_TIMEOUT" "$BINARY" --version 2>&1)"
VERSION_RC=$?
set -e
[ "$VERSION_RC" -eq 0 ] || die "\`--version\` exited with $VERSION_RC: $VERSION_OUT"
[ -n "$VERSION_OUT" ] || die "\`--version\` produced no output"
VERSION_LINE="$(printf '%s\n' "$VERSION_OUT" | head -1)"
if [ -n "$EXPECT_VERSION" ]; then
  case "$VERSION_OUT" in
    *"$EXPECT_VERSION"*) ;;
    *) die "\`--version\` output does not contain '$EXPECT_VERSION': $VERSION_OUT" ;;
  esac
elif ! printf '%s' "$VERSION_LINE" | grep -Eq "$EXPECT_VERSION_REGEX"; then
  die "\`--version\` output does not look like a Godot version (expected /$EXPECT_VERSION_REGEX/): $VERSION_OUT"
fi
ok "version: $VERSION_LINE"

# 6: headless startup path.
case "${RUN_STARTUP_TEST:-1}" in
  0|false|no)
    warn "skipping the headless startup check (RUN_STARTUP_TEST=${RUN_STARTUP_TEST})"
    ;;
  *)
    set +e
    HEADLESS_OUT="$(timeout "$VERSION_TIMEOUT" "$BINARY" --headless --version 2>&1)"
    HEADLESS_RC=$?
    set -e
    [ "$HEADLESS_RC" -eq 0 ] || die "\`--headless --version\` exited with $HEADLESS_RC: $HEADLESS_OUT"
    ok "headless startup ok"
    ;;
esac

# 7: missing shared libraries.
if [ "${SKIP_LD_CHECK:-0}" != "1" ] && command -v ldd >/dev/null 2>&1; then
  MISSING="$(ldd "$BINARY" 2>/dev/null | grep 'not found' || true)"
  if [ -n "$MISSING" ]; then
    printf '%s\n' "$MISSING" >&2
    die "binary is missing shared libraries at build time (install the matching -dev packages)"
  fi
  ok "all shared libraries resolve"
fi

printf '%s\n' "$BINARY"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'binary=%s\n' "$BINARY"
    printf 'version=%s\n' "$VERSION_LINE"
    printf 'size=%s\n' "$SIZE"
  } >> "$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    printf '### Built executable\n\n'
    printf -- '- Path: `%s`\n' "${BINARY#"$ENGINE_DIR"/}"
    printf -- '- Version: `%s`\n' "$VERSION_LINE"
    printf -- '- Size: %s bytes\n' "$SIZE"
  } >> "$GITHUB_STEP_SUMMARY"
fi
