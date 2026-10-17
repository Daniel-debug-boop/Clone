# Changelog

All notable changes to this project. Format loosely follows Keep a Changelog.

## [0.1.0] — 2026-10-17

First playable vertical slice of central Kyoto, built entirely from real open data.

### Added — game

- Third-person `CharacterBody3D` controller: walk, sprint, jump, camera orbit with
  `SpringArm3D`, first/third-person toggle, interaction raycast.
- `TerrainStreamer`: 512×512 real-elevation terrain, chunked on a 16×16 grid, per-chunk
  `ArrayMesh` with trimesh collision, distance streaming with 1.35× unload hysteresis.
- `OsmCity`: parses binary OSM data, extrudes 61,368 building footprints into per-chunk merged
  meshes with collision, builds terrain-following road ribbons for 8,500 road ways.
- Objective loop: eight collectible shrine lanterns at real Kyoto landmarks (Imperial Palace,
  Nijo Castle, Nishiki Market, Sanjo Ohashi, City Hall, Yasaka Shrine, Chion-in, Heian Shrine).
- Main menu with New Game / Continue / Settings / Quit; settings for resolution, fullscreen,
  quality preset, render scale, mouse sensitivity and view distance.
- Pause menu with Resume / Save / Save & Quit, plus required third-party attribution.
- HUD: objective counter, interaction prompt, FPS/speed/view-distance/chunk readout.

### Added — real world data

- `tools/build_world.py`: downloads AWS/Mapzen Terrain Tiles (Terrarium) for
  `34.994–35.030 N, 135.747–135.791 E`, mosaics them, resamples to a 512×512 grid and writes
  `assets/terrain/heightmap.f32` plus georeferencing metadata.
- Same tool queries the Overpass API for roads and buildings, projects them into local metres
  (`+X` east, `+Z` south, matching the terrain), and packs compact `roads.dat` / `buildings.dat`.
- `tools/fetch_assets.py`: downloads four CC0 PBR material sets and a CC0 HDRI from Poly Haven,
  verifying byte sizes and recording SHA-256 in `assets/textures/manifest.json`.

### Added — build and quality

- `tools/build_release.sh`: pinned Godot 4.6.3 download with SHA-256 verification, export-template
  installation, headless import, validation, runtime smoke test, Linux export, packaged-binary
  smoke test, archive creation and checksum generation.
- `tests/validate_project.gd`: 55 static/data assertions including a real per-script
  `--check-only` parse check.
- `tests/smoke_test.gd` + `.tscn`: 15 runtime assertions over the real world scene.
- `-- --smoke-test` runtime flag so the exported binary can self-check.
- `tools/write_manifests.py`: generates `DEPENDENCIES.lock` and `ASSET_MANIFEST.md` from recorded
  hashes so documentation cannot drift from the artefacts.
- `notebooks/build_japan_open_world.ipynb`: one-cell Colab builder with Drive copy and optional
  GitHub Release upload.
- `.github/workflows/build.yml`: CI validation and Linux export.
- Documentation: README, BUILD, TESTING, THIRD_PARTY_NOTICES, ASSET_MANIFEST, DEPENDENCIES.lock,
  LICENSE, docs/FEATURE_MATRIX.md.

### Fixed

- OSM → terrain orientation mismatch: north must map to −Z to match the DEM row order. The
  projector now negates latitude and the data was regenerated.
- `settings_manager.gd` called `environment_set_ssao_quality()` with too many arguments.
- `osm_city.gd` redeclared `indices`, shadowing a function parameter.

### Changed

- Replaced the initial hand-written `export_presets` file — which contained invalid platform and
  option keys (`fame/X11`, `encryption_include`, `export_pck`) that prevent export — with a valid
  `export_presets.cfg` for `Linux/X11`.
- `project.godot` rewritten as a valid Godot 4.6 project: real input map, autoloads, physics
  layers, Forward+ rendering and shadow settings.

### Known limitations

- Terrain3D not integrated (no prebuilt binaries; see BUILD.md).
- Player is a labelled capsule proxy — no rigged character asset.
- No audio, gamepad bindings, NPCs, vehicles or multiplayer.
- Visual quality and frame rate are unverified (headless build environment).
