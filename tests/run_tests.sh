#!/usr/bin/env bash
# Japan Open World - full test suite.
#
# Runs, in order:
#   1. static + data validation          (validate_project.gd)
#   2. runtime smoke test                (smoke_test.tscn)
#   3. PLATEAU graceful-degradation test (plateau_failure_test.tscn)
#
# Usage: bash tests/run_tests.sh
# Env:   GODOT_BIN=/path/to/godot

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log()  { printf '\033[36m[test]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }

GODOT="${GODOT_BIN:-}"
if [[ -z "$GODOT" ]]; then
  if [[ -x "$PROJECT_ROOT/.cache/godot/Godot_v4.6.3-stable_linux.x86_64" ]]; then
    GODOT="$PROJECT_ROOT/.cache/godot/Godot_v4.6.3-stable_linux.x86_64"
  elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  else
    fail "no Godot binary found; set GODOT_BIN"
  fi
fi

LOG_DIR="build_output/logs"
mkdir -p "$LOG_DIR"

run_step() {
  local name="$1"; shift
  local logfile="$LOG_DIR/$name.log"
  log "running $name"
  set +e
  "$@" >"$logfile" 2>&1
  local code=$?
  set -e
  if [[ $code -ne 0 ]]; then
    tail -n 40 "$logfile" >&2
    fail "$name exited $code (see $logfile)"
  fi
  # Surface results without hiding the real exit code (already checked above).
  grep -E "RESULT:|passed:|summary" "$logfile" | tail -n 3 || true
  log "$name OK"
}

# --- 1. static + data -------------------------------------------------------
set +e
"$GODOT" --headless --path . --script tests/validate_project.gd >"$LOG_DIR/validate.log" 2>&1
code=$?
set -e
if [[ $code -ne 0 ]]; then
  tail -n 40 "$LOG_DIR/validate.log" >&2
  fail "validation exited $code"
fi
grep -E "RESULT:|passed:" "$LOG_DIR/validate.log" | tail -n 2 || true
log "validation OK"

# --- 2. runtime smoke -------------------------------------------------------
run_step smoke "$GODOT" --headless --path . res://tests/smoke_test.tscn

# --- 3. graceful degradation ------------------------------------------------
# Hide the tile nearest the world origin: that is certainly inside the streaming
# radius used by the test, so the loader will actually attempt it.
TILE=""
if [[ -f assets/plateau/index.json ]]; then
  TILE="$(python3 tests/pick_center_tile.py 2>/dev/null || true)"
fi

if [[ -n "$TILE" && -f "$TILE" ]]; then
  log "temporarily hiding $TILE"
  mv "$TILE" "$TILE.hidden"
  restore_tile() { [[ -f "$TILE.hidden" ]] && mv "$TILE.hidden" "$TILE" || true; }
  trap restore_tile EXIT

  set +e
  "$GODOT" --headless --path . res://tests/plateau_failure_test.tscn >"$LOG_DIR/plateau_failure.log" 2>&1
  code=$?
  set -e

  restore_tile
  trap - EXIT

  if [[ $code -ne 0 ]]; then
    tail -n 40 "$LOG_DIR/plateau_failure.log" >&2
    fail "plateau failure test exited $code"
  fi
  grep -E "RESULT:|passed:|PASS" "$LOG_DIR/plateau_failure.log" | tail -n 8 || true
  log "plateau failure test OK"
else
  log "no PLATEAU tiles present - skipping graceful-degradation test"
fi

log "all tests passed"
