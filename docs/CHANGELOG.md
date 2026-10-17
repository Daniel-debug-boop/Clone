# Changelog

All notable changes are listed here.

## 2026-10-17 — PLATEAU Kyoto building integration (this commit: `4a467c2`)

- Added `tools/fetch_plateau.py`: official PLATEAU/MLIT tileset discovery → 3D Tiles 1.0 b3dm → Draco decode (via `DracoPy`) → Godot `.pmesh` + collision, georeferenced with a real vertical offset (224.95 m).
- Added `scripts/world/plateau_city.gd`: streaming PLATEAU loader (radius + hysteresis unload, async build, cache, graceful missing-tile skip) integrated with `main_world.gd`, suppressing OSM box buildings under real PLATEAU coverage.
- Added PLATEAU validation assertions (index, vertical offset, source, sampled `.pmesh` structural validity) in `tests/validate_project.gd`, and PLATEAU streaming/runtime assertions in `tests/smoke_test.gd`.
- Added dedicated `tests/plateau_failure_test.gd`/`.tscn` for missing-tile resilience.
- Added screenshot capture harness `tests/capture_screenshots.gd`/`.tscn` and frame/rendering probe scenes (`tests/probe_rendering.gd`, `tests/probe_frames.gd`).
- Updated `tools/build_release.sh` with a `step_plateau` build step (skip-able via `--skip-plateau`).
- Updated docs: `FEATURE_MATRIX.md`, `TEST_REPORT.md`, `THIRD_PARTY_NOTICES.md` (PDL 1.0 attribution), `BUILD.md`.
- Verified on this commit: static + data validation 59 assertions / exit 0; runtime smoke 20 assertions / exit 0; packaged smoke / exit 0.

## 2026-10-17 — docs: record measured build metrics and full test report (commit `d7355f3`)

- Recorded measured build metrics and a full test report in `docs/TEST_REPORT.md`.
- Static + data validation: 55 assertions, exit 0. Runtime smoke: 15 assertions, exit 0. Packaged smoke: exit 0.

## 2026-10-16 — feat: playable Kyoto open-world slice with verified Linux build pipeline (commit `3051712`)

- First playable vertical slice: main menu + settings, third-person controller, orbit camera, interact/objective loop, save/pause, DEM terrain, OSM roads + buildings, chunk streaming, Poly Haven PBR + HDRI, Linux/X11 export with packaged smoke test and SHA-256 archive.
