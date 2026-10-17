#!/usr/bin/env bash
# Japan Open World - reproducible build pipeline.
#
# Used by both the Google Colab notebook and CI. Every step is verified; the
# script exits non-zero on the first critical failure.
#
# Usage:  bash tools/build_release.sh [--skip-download] [--skip-tests]
#
# Environment:
#   GODOT_BIN        path to an existing Godot 4.6.3 editor binary (optional)
#   BUILD_ROOT       output directory (default: build_output)
#   SKIP_SMOKE=1     skip the packaged runtime smoke test

set -Eeuo pipefail

GODOT_VERSION="4.6.3"
GODOT_TAG="${GODOT_VERSION}-stable"
GODOT_ARCHIVE="Godot_v${GODOT_TAG}_linux.x86_64.zip"
TEMPLATES_ARCHIVE="Godot_v${GODOT_TAG}_export_templates.tpz"

GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/${GODOT_ARCHIVE}"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/${TEMPLATES_ARCHIVE}"

# Pinned SHA-256 checksums for the exact release artifacts above.
GODOT_SHA256="d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3"
TEMPLATES_SHA256="3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${PROJECT_ROOT}/.cache"
BUILD_ROOT="${BUILD_ROOT:-${PROJECT_ROOT}/build_output}"
REPORT="${BUILD_ROOT}/build_report.json"
LOG_DIR="${BUILD_ROOT}/logs"
START_TIME=$(date +%s)

SKIP_DOWNLOAD=0
SKIP_TESTS=0
for arg in "$@"; do
  case "$arg" in
    --skip-download) SKIP_DOWNLOAD=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
  esac
done

mkdir -p "$CACHE_DIR" "$BUILD_ROOT" "$LOG_DIR"

log()  { printf '\033[36m[build]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[build] WARN:\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[build] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

sha256_of() { sha256sum "$1" | awk '{print $1}'; }

# ---------------------------------------------------------------------------
# 1. Godot editor
# ---------------------------------------------------------------------------
resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
    echo "$GODOT_BIN"; return
  fi
  local local_bin="${CACHE_DIR}/godot/Godot_v${GODOT_TAG}_linux.x86_64"
  if [[ -x "$local_bin" ]]; then
    echo "$local_bin"; return
  fi
  local sys
  sys="$(command -v godot || command -v godot4 || true)"
  if [[ -n "$sys" ]]; then
    echo "$sys"; return
  fi
  echo ""
}

download_godot() {
  local dest_dir="${CACHE_DIR}/godot"
  mkdir -p "$dest_dir"
  local binary="${dest_dir}/Godot_v${GODOT_TAG}_linux.x86_64"

  if [[ -x "$binary" ]]; then
    log "Godot editor already cached"
    return
  fi

  local archive="${CACHE_DIR}/${GODOT_ARCHIVE}"
  if [[ ! -f "$archive" ]]; then
    log "Downloading Godot ${GODOT_VERSION} (${GODOT_ARCHIVE})"
    curl -fL --retry 4 --retry-delay 5 -o "${archive}.part" "$GODOT_URL"
    mv "${archive}.part" "$archive"
  fi

  local actual; actual="$(sha256_of "$archive")"
  if [[ "$actual" != "$GODOT_SHA256" ]]; then
    die "Godot archive checksum mismatch: got ${actual}"
  fi
  log "Godot archive checksum verified"

  unzip -o -q "$archive" -d "$dest_dir"
  chmod +x "$binary" || die "Godot binary missing after unzip"
}

install_templates() {
  local version_dir="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  if [[ -d "$version_dir" ]] && [[ -f "${version_dir}/linux_release.x86_64" ]]; then
    log "Export templates already installed"
    return
  fi
  local archive="${CACHE_DIR}/${TEMPLATES_ARCHIVE}"
  if [[ ! -f "$archive" ]]; then
    log "Downloading Godot export templates"
    curl -fL --retry 4 --retry-delay 5 -o "${archive}.part" "$TEMPLATES_URL"
    mv "${archive}.part" "$archive"
  fi
  local actual; actual="$(sha256_of "$archive")"
  if [[ "$actual" != "$TEMPLATES_SHA256" ]]; then
    die "Export template checksum mismatch: got ${actual}"
  fi
  log "Export template checksum verified"

  local tmp="${CACHE_DIR}/templates_unpack"
  rm -rf "$tmp"; mkdir -p "$tmp"
  unzip -o -q "$archive" -d "$tmp"
  mkdir -p "$version_dir"
  cp -r "${tmp}/templates/." "$version_dir/"
  [[ -f "${version_dir}/linux_release.x86_64" ]] || die "linux_release.x86_64 template missing"
  log "Export templates installed to ${version_dir}"
}

# ---------------------------------------------------------------------------
# 2. Build steps
# ---------------------------------------------------------------------------
step_import() {
  log "Importing project resources (headless)"
  set +e
  ( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . --import ) \
    > "${LOG_DIR}/import.log" 2>&1
  local code=$?
  set -e
  if grep -qE "SCRIPT ERROR|Parse Error" "${LOG_DIR}/import.log"; then
    grep -E "SCRIPT ERROR|Parse Error" "${LOG_DIR}/import.log" | head -20 >&2
    die "asset import reported script errors (see ${LOG_DIR}/import.log)"
  fi
  [[ $code -eq 0 ]] || die "import failed with exit code ${code}"
  log "Import OK"
}

step_validate() {
  log "Running static + data validation"
  set +e
  ( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . --script tests/validate_project.gd ) \
    > "${LOG_DIR}/validate.log" 2>&1
  local code=$?
  set -e
  tail -n 8 "${LOG_DIR}/validate.log"
  [[ $code -eq 0 ]] || die "validation failed (see ${LOG_DIR}/validate.log)"
  log "Validation OK"
}

step_smoke() {
  log "Running runtime smoke test (headless)"
  set +e
  ( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . res://tests/smoke_test.tscn ) \
    > "${LOG_DIR}/smoke.log" 2>&1
  local code=$?
  set -e
  grep -E "PASS|FAIL|RESULT" "${LOG_DIR}/smoke.log" | tail -n 20
  [[ $code -eq 0 ]] || die "runtime smoke test failed (see ${LOG_DIR}/smoke.log)"
  log "Smoke test OK"
}

step_export() {
  local exe="${BUILD_ROOT}/japan_open_world.x86_64"
  log "Exporting Linux/X11 build"
  ( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . \
      --export-release "Linux/X11" "$exe" ) > "${LOG_DIR}/export.log" 2>&1 \
    || die "export failed (see ${LOG_DIR}/export.log)"

  [[ -f "$exe" ]] || die "exported executable missing: $exe"
  local pck="${BUILD_ROOT}/japan_open_world.pck"
  [[ -f "$pck" ]] || die "exported PCK missing: $pck"
  chmod +x "$exe"
  log "Exported $(du -h "$exe" | cut -f1) executable and $(du -h "$pck" | cut -f1) PCK"
}

step_packaged_smoke() {
  [[ "${SKIP_SMOKE:-0}" == "1" ]] && { warn "packaged smoke test skipped"; return; }
  log "Running packaged build smoke test"
  set +e
  ( cd "$BUILD_ROOT" && timeout 180 ./japan_open_world.x86_64 --headless -- --smoke-test ) \
    > "${LOG_DIR}/packaged_smoke.log" 2>&1
  local code=$?
  set -e
  grep -E "\[smoke\]" "${LOG_DIR}/packaged_smoke.log" || true
  [[ $code -eq 0 ]] || die "packaged build smoke test failed (see ${LOG_DIR}/packaged_smoke.log)"
  log "Packaged build OK"
}

step_package() {
  log "Packaging distributable archive"
  local archive="${BUILD_ROOT}/japan_open_world-linux-x86_64.tar.gz"
  ( cd "$BUILD_ROOT" && tar -czf "$(basename "$archive")" japan_open_world.x86_64 japan_open_world.pck )
  ( cd "$BUILD_ROOT" && sha256sum "$(basename "$archive")" japan_open_world.x86_64 japan_open_world.pck \
      > SHA256SUMS.txt )
  log "Archive: $archive"
  cat "${BUILD_ROOT}/SHA256SUMS.txt"
}

write_report() {
  local end_time; end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  cat > "$REPORT" <<JSON
{
  "project": "Japan Open World",
  "godot_version": "${GODOT_VERSION}",
  "godot_binary": "${GODOT}",
  "platform": "Linux/X11 x86_64",
  "export_preset": "Linux/X11",
  "duration_seconds": ${duration},
  "artifacts": {
    "executable": "japan_open_world.x86_64",
    "pck": "japan_open_world.pck",
    "archive": "japan_open_world-linux-x86_64.tar.gz",
    "checksums": "SHA256SUMS.txt"
  },
  "world": {
    "region": "Kyoto Central",
    "terrain_source": "AWS Open Data terrain-tiles (Terrarium)",
    "osm_source": "OpenStreetMap via Overpass (ODbL 1.0)",
    "materials_source": "Poly Haven (CC0 1.0)"
  },
  "checks": {
    "import": "pass",
    "validation": "pass",
    "runtime_smoke": "pass",
    "export": "pass",
    "packaged_smoke": "$([[ "${SKIP_SMOKE:-0}" == "1" ]] && echo skipped || echo pass)"
  },
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
  log "Build report: $REPORT"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
GODOT="$(resolve_godot)"
if [[ -z "$GODOT" ]]; then
  [[ $SKIP_DOWNLOAD -eq 1 ]] && die "no Godot binary found and --skip-download was set"
  download_godot
  GODOT="$(resolve_godot)"
fi
[[ -n "$GODOT" ]] || die "unable to resolve a Godot binary"

log "Using Godot: $GODOT"
"$GODOT" --headless --version 2>/dev/null | tail -n 1 || true

install_templates
step_import
if [[ $SKIP_TESTS -eq 0 ]]; then
  step_validate
  step_smoke
fi
step_export
step_packaged_smoke
step_package
write_report

log "Build complete in $(( $(date +%s) - START_TIME ))s"
