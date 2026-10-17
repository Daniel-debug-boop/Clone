#!/usr/bin/env bash
# Provision a throwaway Xvfb + Mesa software-rendering display so the game can be
# rendered and captured on a machine with no GPU and no display server.
#
# Everything is extracted into .cache/xvfb (no root, no system changes).
#
# Usage:  bash tools/setup_software_display.sh
# Then:   DISPLAY=:99 godot --path .
#
# Notes:
#  * Mesa's swrast/llvmpipe DRI drivers must already exist on the host.
#  * Packages are downloaded from deb.debian.org (bookworm), which are ABI
#    compatible with modern Ubuntu hosts for these libraries.
#  * This is a *development aid* for visual validation; it is not part of the
#    game build and nothing here ships with the game.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT}/.cache/xvfb"
DEBS="${DEST}/debs"
EXTRACT="${DEST}/root"

BASE="http://deb.debian.org/debian/pool"

log() { printf '\033[36m[xvfb]\033[0m %s\n' "$*"; }

mkdir -p "$DEBS" "$EXTRACT"

fetch() {
  # fetch <pool path> <package glob prefix>
  local pooldir="$1" prefix="$2"
  local name
  name="$(curl -s --max-time 60 "${BASE}/${pooldir}/" \
    | grep -oE "${prefix}[^\"]*_(amd64|all)\.deb" \
    | sort -u | tail -n 1)"
  if [[ -z "$name" ]]; then
    log "WARN could not resolve ${prefix} in ${pooldir}"
    return 1
  fi
  if [[ ! -f "${DEBS}/${name}" ]]; then
    log "downloading ${name}"
    curl -fsSL --max-time 180 -o "${DEBS}/${name}.part" "${BASE}/${pooldir}/${name}"
    mv "${DEBS}/${name}.part" "${DEBS}/${name}"
  fi
  return 0
}

fetch "main/x/xorg-server"      "xvfb_"
fetch "main/libx/libxfont"      "libxfont2_"
fetch "main/libf/libfontenc"    "libfontenc1_"
fetch "main/p/pixman"           "libpixman-1-0_"
fetch "main/libx/libxcursor"    "libxcursor1_"
fetch "main/libx/libxinerama"   "libxinerama1_"
fetch "main/libx/libxi"         "libxi6_"
fetch "main/libx/libxrandr"     "libxrandr2_"
fetch "main/x/xkeyboard-config" "xkb-data_" || true

log "extracting packages"
for deb in "${DEBS}"/*.deb; do
  dpkg-deb -x "$deb" "$EXTRACT" 2>/dev/null || log "WARN failed to extract $(basename "$deb")"
done

XVFB="${EXTRACT}/usr/bin/Xvfb"
[[ -x "$XVFB" ]] || {
  # Some builds place it under /usr/lib/xorg.
  XVFB="$(find "$EXTRACT" -name Xvfb -type f -print -quit)"
}
[[ -n "$XVFB" && -x "$XVFB" ]] || { log "ERROR Xvfb binary not found"; exit 1; }

LIBDIR="${EXTRACT}/usr/lib/x86_64-linux-gnu"
XKB="${EXTRACT}/usr/share/X11/xkb"

cat > "${DEST}/env.sh" <<EOF
export XVFB_BIN="${XVFB}"
export XVFB_LIBS="${LIBDIR}"
export XKB_CONFIG_ROOT="${XKB}"
export LD_LIBRARY_PATH="${LIBDIR}:\${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
EOF

log "display tooling ready"
log "  Xvfb: ${XVFB}"
log "  libs: ${LIBDIR}"
log "run:  source ${DEST}/env.sh && \"\$XVFB_BIN\" :99 -screen 0 1600x900x24 &"
