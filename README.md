# Japan Open World

A playable third-person open-world game set in **central Kyoto**, built with **Godot 4.6.3**.
The world is generated from **real elevation data** and **real OpenStreetMap** roads and
building footprints, and shaded with **real CC0 PBR materials and an HDRI** from Poly Haven.

The repository contains a reproducible build pipeline that runs end-to-end in Google Colab
and produces a Linux x86_64 desktop build.

---

## What is actually in the game

| Feature | Status |
|---|---|
| Third-person character (walk / sprint / jump / camera orbit / interact) | Implemented, tested |
| Terrain from real Kyoto DEM, 512×512, 29–245 m elevation | Implemented, tested |
| ~4.0 km × 4.0 km playable region (Kyoto basin + eastern hills) | Implemented, tested |
| 8,500 real OSM road ways rendered as terrain-following ribbons | Implemented, tested |
| 61,368 real OSM building footprints extruded with collision | Implemented, tested |
| Chunk streaming (16×16 grid) with automatic load/unload | Implemented, tested |
| Real Poly Haven PBR materials (grass, rock, asphalt, concrete) | Implemented, tested |
| Real Poly Haven HDRI sky + image-based lighting | Implemented, tested |
| Main menu, settings (resolution, quality, render scale, sensitivity, view distance) | Implemented, tested |
| Pause menu, save game, quit-to-menu | Implemented |
| Objective loop: restore 8 lanterns at real Kyoto landmarks | Implemented, tested |
| Headless validation + runtime smoke test | Implemented, tested |
| Linux export + packaged-build smoke test + SHA-256 archive | Implemented, tested |
| Terrain3D native GDExtension | **Not integrated** — see `BUILD.md` |
| Rigged humanoid character model | **Not integrated** — capsule proxy is used, see `ASSET_MANIFEST.md` |
| Multiplayer | Not implemented |
| Building interiors | Not implemented |

Full detail, including everything downloaded but not integrated, is in
[`docs/FEATURE_MATRIX.md`](docs/FEATURE_MATRIX.md) and
[`ASSET_MANIFEST.md`](ASSET_MANIFEST.md).

---

## Play the prebuilt Linux build

```bash
tar -xzf japan_open_world-linux-x86_64.tar.gz
./japan_open_world.x86_64
```

**Controls**

| Input | Action |
|---|---|
| `W A S D` | Move |
| `Shift` | Sprint |
| `Space` | Jump |
| `E` | Interact / restore lantern |
| `C` | Toggle first/third person |
| Mouse | Look |
| `Esc` | Pause |

**Goal:** restore the eight lanterns placed at real Kyoto landmarks — the Imperial Palace,
Nijo Castle, Nishiki Market, Sanjo Ohashi, City Hall, Yasaka Shrine, Chion-in and Heian Shrine.

---

## Build it yourself

### Google Colab (recommended, minimal steps)

Open [`notebooks/build_japan_open_world.ipynb`](notebooks/build_japan_open_world.ipynb) and run all
cells. The single *RUN EVERYTHING* cell clones the repo, downloads pinned Godot, regenerates the
world data, validates, smoke-tests, exports and archives the build.

### Locally on Linux

```bash
python3 -m pip install pillow numpy
python3 tools/build_world.py        # real Kyoto DEM + OSM data
python3 tools/fetch_assets.py       # Poly Haven CC0 materials + HDRI
bash tools/build_release.sh         # downloads Godot, builds, tests, packages
```

See [`BUILD.md`](BUILD.md) for requirements, the Terrain3D evaluation and troubleshooting.

---

## How the world is built

```
AWS Terrain Tiles (Terrarium) ──► tools/build_world.py ──► assets/terrain/heightmap.f32
OpenStreetMap via Overpass    ──► tools/build_world.py ──► assets/world/roads.dat, buildings.dat
Poly Haven API                ──► tools/fetch_assets.py ─► assets/textures/, assets/hdri/
                                      │
                                      ▼
             TerrainStreamer (chunked DEM mesh + collision)
             OsmCity (extruded buildings + road ribbons, streamed per chunk)
                                      │
                                      ▼
                       main_world.tscn + player + lanterns
```

The pipeline is deterministic and re-runnable: verified downloads are cached, and generated
data is only rebuilt when missing or when `--force` is passed.

**Region:** 34.994°–35.030° N, 135.747°–135.791° E (Kyoto Imperial Palace, Gion, Kamo river,
and the eastern Higashiyama hills).

---

## Repository layout

```
project.godot              Godot project (input map, autoloads, rendering)
export_presets.cfg         Linux/X11 export preset
scenes/                    main_menu, main_world, player
scripts/autoload/          GameManager, SettingsManager
scripts/world/             TerrainStreamer, OsmCity, main_world
scripts/player/            PlayerController
scripts/gameplay/          LanternObjective
scripts/ui/                HUD, main menu
assets/terrain/            DEM-derived heightmap + metadata (real)
assets/world/              OSM roads/buildings, JSON sources + compact binaries
assets/textures/           Poly Haven PBR sets (CC0)
assets/hdri/               Poly Haven HDRI (CC0)
tools/                     build_world.py, fetch_assets.py, build_release.sh, manifests
notebooks/                 Colab builder
tests/                     validate_project.gd, smoke_test.gd/.tscn
docs/                      feature matrix, test report
```

---

## Documentation

- [`BUILD.md`](BUILD.md) — build pipeline, dependencies, Terrain3D rationale
- [`TESTING.md`](TESTING.md) — what is tested and how to reproduce it
- [`ASSET_MANIFEST.md`](ASSET_MANIFEST.md) — every asset, licence, hash, integration status
- [`DEPENDENCIES.lock`](DEPENDENCIES.lock) — pinned versions and checksums
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — attribution requirements
- [`CHANGELOG.md`](CHANGELOG.md) — change history
- [`docs/FEATURE_MATRIX.md`](docs/FEATURE_MATRIX.md) — honest feature status

---

## Scope statement

This is an **implemented, playable vertical slice** of a real Japanese location — not a
completed commercial open-world game. The region is deliberately bounded to a 4 km square so
that terrain, roads, buildings, collision, streaming and performance can actually be validated.
Expanding the region is a matter of changing the bounding box in `tools/build_world.py` and
re-running the pipeline; the streaming architecture already supports it.

---

## Licence

Project code: MIT — see [`LICENSE`](LICENSE).
Bundled data and art keep their own licences; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
