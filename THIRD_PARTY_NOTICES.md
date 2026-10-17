# Third-party notices and attribution

This project includes or derives from the following third-party works. The obligations below
are **required**, not optional.

---

## 1. Godot Engine 4.6.3

- **Used for:** engine, editor, export templates.
- **Licence:** MIT.
- **Source:** https://github.com/godotengine/godot
- **Obtained from:** https://github.com/godotengine/godot/releases/tag/4.6.3-stable
- **SHA-256 (linux.x86_64 editor zip):** `d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3`
- **SHA-256 (export templates tpz):** `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`

The Godot licence text ships with the engine; see `LICENSE.txt` in the Godot distribution.
Exported builds include Godot engine code and must retain its MIT notice.

---

## 2. Terrain elevation data — Mapzen / AWS Terrain Tiles

- **Used for:** the Kyoto terrain heightmap (`assets/terrain/heightmap.f32`,
  `assets/terrain/heightmap.png`), derived by `tools/build_world.py`.
- **Dataset:** "Terrain Tiles", a Linux Foundation / Mapzen project, distributed through the
  Registry of Open Data on AWS.
- **Accessed via:** `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png`
- **Registry entry:** https://registry.opendata.aws/terrain-tiles/
- **Licence / attribution:** https://github.com/tilezen/joerd/blob/master/docs/attribution.md

**Required attribution (reproduced from the upstream attribution document):**

```
* ArcticDEM terrain data DEM(s) were created from DigitalGlobe, Inc., imagery and
funded under National Science Foundation awards 1043681, 1559691, and 1542736;
* Australia terrain data © Commonwealth of Australia (Geoscience Australia) 2017;
* Austria terrain data © offene Daten Österreichs – Digitales Geländemodell (DGM) Österreich;
* Canada terrain data contains information licensed under the Open Government Licence – Canada;
* Europe terrain data produced using Copernicus data and information funded by the
European Union - EU-DEM layers;
* Global ETOPO1 terrain data U.S. National Oceanic and Atmospheric Administration
* Mexico terrain data source: INEGI, Continental relief, 2016;
* New Zealand terrain data Copyright 2011 Crown copyright (c) Land Information New Zealand
and the New Zealand Government (All rights reserved);
* Norway terrain data © Kartverket;
* United Kingdom terrain data © Environment Agency copyright and/or database right 2015.
All rights reserved;
* United States 3DEP (formerly NED) and global GMTED2010 and SRTM terrain data courtesy of
the U.S. Geological Survey.
```

Additionally: `3DEP data courtesy of the U.S. Geological Survey` and
`SRTM data courtesy of the U.S. Geological Survey`.

The specific region used here (central Kyoto) is covered by the global SRTM / GMTED2010 sources,
so the USGS courtesy notice applies. Attribution is reproduced in-game in the pause menu footer
and in this repository.

---

## 3. OpenStreetMap data

- **Used for:** road centrelines and building footprints
  (`assets/world/roads.dat`, `assets/world/buildings.dat`, and their `.json` sources).
- **Obtained via:** the Overpass API (https://overpass-api.de/api/interpreter).
- **Licence:** Open Data Commons Open Database License (ODbL) 1.0.
- **Copyright:** © OpenStreetMap contributors.
- **Required attribution:** "© OpenStreetMap contributors" and a link to
  https://www.openstreetmap.org/copyright

Derived databases produced from OSM data remain subject to ODbL 1.0. If you redistribute
`roads.dat` or `buildings.dat`, keep this attribution and the ODbL terms.

---

## 4. Poly Haven textures and HDRIs

- **Used for:** PBR materials and the sky/IBL environment.
- **Licence:** CC0 1.0 Universal (public domain dedication). Attribution is appreciated but
  not legally required.
- **Source:** https://polyhaven.com/ — licence: https://polyhaven.com/license

| Asset | Type | Used in |
|---|---|---|
| `aerial_grass_rock` | PBR material (2k) | lowland terrain |
| `rocky_terrain_02` | PBR material (2k) | terrain above 115 m |
| `aerial_asphalt_01` | PBR material (2k) | road ribbons |
| `painted_concrete` | PBR material (2k) | building facades |
| `kloofendal_48d_partly_cloudy_puresky` | HDRI (2k) | sky + image-based lighting |

Exact file names and SHA-256 values are recorded in `ASSET_MANIFEST.md` and
`DEPENDENCIES.lock`.

---

## 5. Terrain3D (evaluated, not linked)

- **Project:** https://github.com/TokisanGames/Terrain3D
- **Version evaluated:** v1.0.2-stable
- **Licence:** MIT
- **Status:** **Not included in the build.** The release publishes no prebuilt binaries for any
  platform; it is a source-only GDExtension that must be compiled against the engine. It is
  therefore not shipped and imposes no notice obligation here. The evaluation and the reasoning
  are documented in `BUILD.md`.

---

## 6. PLATEAU 3D city models (Project PLATEAU, MLIT)

- **Used for:** the real building geometry streamed as `assets/plateau/**/*.pmesh`.
- **Project:** "Project PLATEAU", the Ministry of Land, Infrastructure, Transport and Tourism
  (国土交通省, MLIT) 3D city-model initiative — https://www.mlit.go.jp/plateau/
- **Dataset used:** Kyoto City 3D Tiles (LOD2, noTexture variant), published through the
  PLATEAU View asset CDN (`assets.cms.plateau.reearth.io`). Five Kyoto wards inside the
  playable region: kamigyo-ku (上京区), sakyo-ku (左京区), nakagyo-ku (中京区),
  higashiyama-ku (東山区), shimogyo-ku (下京区) — 193 tiles, 1,946,208 triangles.
- **Discovery API:** https://api.plateauview.mlit.go.jp/datacatalog/plateau-datasets
- **Licence:** **Public Data License 1.0 (公共データ利用規約 第1.0版)**, the MLIT terms of use.
  MLIT states this rule is compatible with **CC BY 4.0** and permits use under CC BY, ODC BY
  or ODbL. Source: https://www.mlit.go.jp/plateau/site-policy/ ("3. コンテンツの利用").
- **Copyright:** 国土交通省 (MLIT), except that for 3D city models published via the
  "G空間情報センター" open-data channel copyright belongs to each local municipality.

**Required attribution (per MLIT's stated examples):**

```
出典：国土交通省 PLATEAUウェブサイト（https://www.mlit.go.jp/plateau/）
```

MLIT additionally requires that when content is edited or modified, the modification is
stated, and that modified material is never presented as if MLIT produced it. Our pipeline
Decodes the Draco-compressed b3dm payloads, re-projects them into the game's local frame and
drops texture and material data, so the required "modified" form is used:

```
「国土地理院／国土交通省 実在空間3D都市モデル」を加工して作成
（出典：国土交通省 PLATEAUウェブサイト https://www.mlit.go.jp/plateau/）
```

The exact per-tile upstream URL of every converted tile is recorded in
`assets/plateau/index.json` under `tiles[].source`, so provenance is auditable tile by tile.

**Note on coverage:** PLATEAU LOD2 buildings carry no interior geometry and the
`no_texture` variant carries no facade textures. Interior spaces, street furniture, vehicles
and vegetation therefore do **not** come from PLATEAU; see `ASSET_MANIFEST.md` for the
licensed fallbacks actually used, and `docs/FEATURE_MATRIX.md` for what remains unimplemented.

---

## Attribution in the shipped game

The HUD footer displays:

> Terrain: Mapzen/AWS Terrain Tiles (SRTM, USGS). Map data © OpenStreetMap contributors (ODbL).
> 3D buildings: 国土交通省 PLATEAU, 「実在空間3D都市モデル」を加工して作成.
> Materials: Poly Haven (CC0). Engine: Godot (MIT).

This satisfies the "reasonable to the medium" requirement of the OSM, terrain-tile and
PLATEAU (PDL 1.0 / CC BY-compatible) attribution policies for a bundled desktop build.
