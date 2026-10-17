# Asset manifest

Every asset below was downloaded from its real published endpoint, verified, and
recorded with its SHA-256. Integration status is stated honestly.

## Integration status legend

- **Integrated** — referenced and used by the running game.
- **Partially integrated** — used, but not in every intended context.
- **Downloaded, not integrated** — present but unused by the build.
- **Blocked** — could not be obtained or used.

## Summary

| Asset | Type | Licence | Destination | Status |
|---|---|---|---|---|
| aerial_grass_rock | PBR material set (albedo/normal/roughness) | CC0 1.0 | `assets/textures/aerial_grass_rock/` | Integrated — lowland terrain |
| rocky_terrain_02 | PBR material set | CC0 1.0 | `assets/textures/rocky_terrain_02/` | Integrated — terrain above 115 m |
| aerial_asphalt_01 | PBR material set | CC0 1.0 | `assets/textures/aerial_asphalt_01/` | Integrated — OSM road ribbons |
| painted_concrete | PBR material set | CC0 1.0 | `assets/textures/painted_concrete/` | Integrated — extruded building facades |
| kloofendal_48d_partly_cloudy_puresky | HDRI environment | CC0 1.0 | `assets/hdri/` | Integrated — sky + image-based lighting |
| Kyoto DEM (Terrarium tiles) | Elevation raster, 512×512 | see notices | `assets/terrain/heightmap.f32` | Integrated — terrain mesh + collision |
| OpenStreetMap roads | Vector ways | ODbL 1.0 | `assets/world/roads.dat` | Integrated — road ribbons |
| OpenStreetMap buildings | Vector footprints | ODbL 1.0 | `assets/world/buildings.dat` | Integrated — extruded buildings + collision |

## Not integrated / blocked

| Candidate | Reason |
|---|---|
| Terrain3D v1.0.2 | No prebuilt binaries are published for any platform; the addon must be compiled as a GDExtension against the engine. Not linked; DEM chunk streaming is used instead. See BUILD.md. |
| Rigged humanoid character | No CC0 rigged character with licensed animations was obtained in this pass. The player is a clearly-labelled capsule proxy. |
| meshoptimizer integration | Not integrated; Godot's own mesh/LOD pipeline and chunk streaming are used. See BUILD.md. |
| Building interiors | OSM provides footprints only, not interior geometry. |

## Provenance table (verified files)

| File | Bytes | SHA-256 |
|---|---|---|
| `assets/textures/aerial_grass_rock/aerial_grass_rock_albedo.jpg` | 2624635 | `1a2ddfa4652adbe00447b940c40019d46f4b88245bc1b341cdf622c2110b7bc5` |
| `assets/textures/aerial_grass_rock/aerial_grass_rock_normal.jpg` | 3799025 | `c6aa14b042ce243f93a6ca807f46a085711c23ad316b104578e92df7770ee285` |
| `assets/textures/aerial_grass_rock/aerial_grass_rock_roughness.jpg` | 1495844 | `fc0fff40e3378f2f54d225db6e3e566a8563bb2c143eef0f09b543c9d4698776` |
| `assets/textures/aerial_asphalt_01/aerial_asphalt_01_albedo.jpg` | 2802005 | `a85ce28b8e6ed90acb0234832969b27f5b73fe055a0d5b94f34fc2943d319fb5` |
| `assets/textures/aerial_asphalt_01/aerial_asphalt_01_normal.jpg` | 2751902 | `cb7e5b75ff47ad672ab820f71b77566419b612e52e7791c5ed90a7fa27b71807` |
| `assets/textures/aerial_asphalt_01/aerial_asphalt_01_roughness.jpg` | 1392536 | `20fdcdc9fc2a3efef83fd8a3453d2bc0a8543ee3ebb2badf148e4c142704eeff` |
| `assets/textures/rocky_terrain_02/rocky_terrain_02_albedo.jpg` | 3232826 | `9b042fe0618ffbc3650592456d7d8d265ba9a1cb5ce802f5f1d86b7ee79508a1` |
| `assets/textures/rocky_terrain_02/rocky_terrain_02_normal.jpg` | 4149208 | `556ed903180a9431b253fc1c334c769dc4615c5c0f4ef1cedf20533ae8409ce8` |
| `assets/textures/rocky_terrain_02/rocky_terrain_02_roughness.jpg` | 1589303 | `89f3c7b9e467160a821cbac32a1fdfd75f13cb87c9deeb22099d16677a711126` |
| `assets/textures/painted_concrete/painted_concrete_albedo.jpg` | 4055196 | `558ae59b4b9d159f24686e4ee0a768ea89cbc02f08ede82b91445d57850748b8` |
| `assets/textures/painted_concrete/painted_concrete_normal.jpg` | 2786551 | `8da7fbbb29311fc53b052167c9fcfa73027c0a06808120a200295d866587a813` |
| `assets/textures/painted_concrete/painted_concrete_roughness.jpg` | 1926276 | `136ef5e95e17a8103a2bf311c5f55008a1ca56e57bf5904160491f0a7cde0b65` |
| `assets/hdri/kloofendal_48d_partly_cloudy_puresky_2k.hdr` | 5451493 | `5244534e9cf5b606f2ff513aa00ddb161b0a4826ffd88a0d3bd03ac29247d198` |
| `assets/terrain/heightmap.f32` | 1048584 | `1212e9fa67e896574af9c85fa129bea965550e1edd9244df86a68c25f3456158` |
| `assets/world/roads.dat` | 476340 | `fd45a749043dd47d80f333dc1a2ad9b67912a4c63cf24526c64202afc75ae114` |
| `assets/world/buildings.dat` | 3585608 | `e46b6d7159dd94edaf374a3cc944c770a049e92c8547c98bc3f6697830a6211f` |

