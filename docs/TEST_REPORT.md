# Test report

Generated: 2026-10-17T11:01:43Z

- Godot: `4.6.3.stable.official.7d41c59c4`
- Commit: `fa1d02cbbfb0507c98a292d90033c0f487a644c0`

## Build report
```json
{
  "project": "Japan Open World",
  "godot_version": "4.6.3",
  "godot_binary": "/tmp/godot/Godot_v4.6.3-stable_linux.x86_64",
  "platform": "Linux/X11 x86_64",
  "export_preset": "Linux/X11",
  "duration_seconds": 26,
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
    "packaged_smoke": "pass"
  },
  "generated_utc": "2026-10-17T11:00:05Z"
}
```

## Static + data validation (55 assertions)
```
  PASS  autoload SettingsManager -> res://scripts/autoload/settings_manager.gd

=== summary ===
passed: 55   warnings: 0   failures: 0

RESULT: PASS
```

## Runtime smoke test (15 assertions)
```
  PASS  GameManager autoload present
  PASS  SettingsManager autoload present
  PASS  draw distance configured: 1400 m
  PASS  terrain node exists
  PASS  terrain streamed 97 chunks around the player
  PASS  terrain covers 4007 x 3980 m
  PASS  elevation sampling works (centre 55.5 m, offset 43.9 m)
  PASS  OSM buildings parsed: 61368 footprints
  PASS  OSM roads parsed: 8500 ways
  PASS  city geometry streamed in 97 chunks
  PASS  player spawned at (-231.2809, 48.00214, -218.2667)
  PASS  player is above terrain (1.00 m)
  PASS  8 lantern objectives placed
  PASS  GameManager objective total matches placed lanterns (8)
  PASS  player did not fall through terrain after physics step
RESULT: PASS
```

## Packaged build smoke test
```
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org

[smoke] booting world directly
[smoke] terrain_chunks=97 city_chunks=97 lanterns=8 player=yes
[smoke] RESULT: PASS
```

## Measured runtime metrics

| Metric | Value |
|---|---|
| Packaged game to world-ready (headless) | 4.13 s |
| Packaged game peak RSS | 397.5 MB |
| Headless asset import | 4.49 s / 625.6 MB peak |
| Terrain + city chunks resident | 97 + 97 |

## Artifact checksums
```
0880cc6cf2dc53600e485187254c98e16a2720698f983544ad0a59faa1d584da  japan_open_world-linux-x86_64.tar.gz
2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0  japan_open_world.x86_64
43a199903527e0d225d21aa59a4d4e816f6f6fff33fe0732cfd7912743360b2c  japan_open_world.pck
```

## Notes

- Logs contain only `Unable to load fontconfig` on this minimal container; Godot's bundled
  default font still renders UI text. Install `libfontconfig1` to silence it.
- Frame rate, GPU frame time and visual quality are **not** measured here because the build
  environment is headless. Validate on real hardware using `TESTING.md`.
