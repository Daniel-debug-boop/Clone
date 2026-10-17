# Testing

Three independent layers. All are run by `tools/build_release.sh`; any failure aborts the build.

---

## 1. Static + data validation — `tests/validate_project.gd`

```bash
godot --headless --path . --script tests/validate_project.gd
```

Checks (55 assertions as of the current commit):

- `application/run/main_scene` is set and the file exists;
- project name, renderer, and all gameplay input actions are registered;
- every `.gd` file parses — verified by invoking the engine in `--check-only` mode per script
  and failing on genuine `Parse Error` output;
- every scene file is present and `main_world.tscn` parses as a `PackedScene`;
- world data files exist, are non-empty, and:
  - `heightmap.f32` header `(w, h)` matches the file size exactly;
  - `heightmap.json` contains a valid bbox and a non-degenerate elevation range;
  - `roads.dat` / `buildings.dat` magic numbers are correct;
- all referenced textures and the HDRI exist;
- both autoloads point at existing scripts.

Exit code is non-zero on any failure. Autoload identifiers cannot resolve in `--script` mode, so
that mode deliberately does **not** attempt runtime compilation — layer 2 does.

---

## 2. Runtime smoke test — `tests/smoke_test.tscn`

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

Runs as a real scene, so autoloads exist and everything compiles for real. It:

- confirms `GameManager` and `SettingsManager` exist and the view distance is configured;
- instantiates the actual `main_world.tscn`;
- asserts terrain chunks stream (> 0) and the region is > 1 km across;
- samples elevation at two points and asserts they are plausible and different;
- asserts the OSM parser produced > 1,000 building footprints and > 100 road ways;
- asserts city geometry streamed into chunks;
- asserts the player spawned above the terrain surface;
- asserts lantern objectives were placed and that `GameManager.objectives_total` matches;
- steps physics twice and asserts the player did not fall through the terrain.

Current result: **15/15 pass**, 97 terrain chunks, 97 city chunks, 61,368 buildings, 8,500 roads,
8 lanterns.

---

## 3. Packaged build smoke test

```bash
cd build_output
./japan_open_world.x86_64 --headless -- --smoke-test
```

Boots the **exported** binary (not the editor), skips the menu, starts the world, waits 90 frames,
prints terrain/city/lantern/player counts and exits `0` on success, `1` on failure. This is the
check that proves the shipped PCK contains the data and scripts.

Current result: `terrain_chunks=97 city_chunks=97 lanterns=8 player=yes` → `RESULT: PASS`.

---

## What is *not* automatically tested

| Area | Why | How to validate manually |
|---|---|---|
| Visual quality | No display in headless CI/Colab | Run the build on a machine with a GPU; check terrain silhouette, material tiling, building alignment, sky/IBL, shadows |
| Frame rate | Same | Use the in-game FPS readout (top-right). Record on the declared target hardware |
| Gamepad input | No device | Plug in a controller; axes are not bound yet (see feature matrix) |
| Long-session streaming stability | Runtime budget | Walk the full 4 km region for ~10 minutes and watch the FPS/chunk counters |
| Save/load round-trip | Not yet automated | Pause → Save Game → quit → Continue |

These are reported as **unverified** rather than passing.

---

## Performance baseline

The renderer is headless during automated tests, so **no FPS number is claimed**. The following
figures were measured on the build machine and are reproducible:

| Metric | Value | How measured |
|---|---|---|
| Packaged game → world ready (headless) | **4.13 s** | `./japan_open_world.x86_64 --headless -- --smoke-test`, wall clock |
| Packaged game peak RSS | **397.5 MB** | `getrusage(RUSAGE_CHILDREN).ru_maxrss` |
| Headless asset import | **4.49 s**, 625.6 MB peak | editor `--import` |
| Full build (cached engine, all tests, export) | **~26 s** | `tools/build_release.sh` |
| Terrain chunks resident at 1400 m view distance | **97** | smoke test |
| City chunks resident | **97** | smoke test |
| Building footprints parsed at startup | **61,368** | smoke test |

The design bounds work as follows:

- 250 m chunks; 33×33 vertices each (1,089 verts, 2,048 tris);
- at the default 1400 m view distance, ~97 terrain chunks are resident (~199k tris) plus ~97
  city chunks of merged building/road geometry;
- buildings and roads are merged into **one mesh per chunk** rather than one node per object,
  which keeps draw calls proportional to chunk count, not building count;
- chunk unload uses a 1.35× hysteresis band to avoid load/unload thrash at the boundary.

To profile on real hardware: run the game, watch the HUD's FPS/chunk counters, and use the
engine's built-in profiler (`Debugger → Profiler`) for frame-time breakdown.
