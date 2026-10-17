# Test report

Generated: 2026-10-17T10:58:06Z

Godot: 4.6.3.stable.official.7d41c59c4

## Build report
```json
{
  "project": "Japan Open World",
  "godot_version": "4.6.3",
  "godot_binary": "/tmp/godot/Godot_v4.6.3-stable_linux.x86_64",
  "platform": "Linux/X11 x86_64",
  "export_preset": "Linux/X11",
  "duration_seconds": 25,
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
  "generated_utc": "2026-10-17T10:57:58Z"
}
```

## Validation (static + data)
```
  PASS  autoload SettingsManager -> res://scripts/autoload/settings_manager.gd

=== summary ===
passed: 55   warnings: 0   failures: 0

RESULT: PASS
```

## Runtime smoke test
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

## Artifacts
```
5c886c61647b7a08a786653ded9792b30af4d071d855803d1c2da56991c1ec7b  japan_open_world-linux-x86_64.tar.gz
2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0  japan_open_world.x86_64
8c4e4060cf2427bb6735367ac68e9aff9418403603fcd4ff0b7306d8a8cf0f78  japan_open_world.pck
```
