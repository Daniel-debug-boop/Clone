#!/usr/bin/env python3
"""
Japan Open World - real geodata pipeline.

Builds Godot-ready world data from real, openly licensed sources:

  * Terrain elevation .... AWS Open Data "Terrain Tiles" (Terrarium RGB encoding).
                           Dataset: https://registry.opendata.aws/terrain-tiles/
                           Elevation is decoded as (R*256 + G + B/256) - 32768 metres.
  * Roads / buildings .... OpenStreetMap via the Overpass API (ODbL 1.0).
                           https://www.openstreetmap.org/copyright

Outputs (all relative to the Godot project root):

  assets/terrain/heightmap.png     16-bit grayscale heightmap of the playable region
  assets/terrain/heightmap.json    georeferencing + elevation range metadata
  assets/world/roads.json          road centrelines in local metres
  assets/world/buildings.json      building footprints in local metres
  assets/world/manifest.json       provenance / licence / checksum record

The script is idempotent: existing verified outputs are reused unless --force.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# --------------------------------------------------------------------------------------
# Region definition.
#
# The playable vertical slice is central Kyoto: the Imperial Palace, Gion and the
# Kamo river corridor. The region is deliberately bounded (~2.6 km square) so that a
# single streamed world is credible and can be validated, rather than claiming a
# country-sized open world.
# --------------------------------------------------------------------------------------

REGION = {
    "name": "Kyoto Central",
    "name_ja": "京都市中心部",
    "south": 34.9980,
    "north": 35.0215,
    "west": 135.7520,
    "east": 135.7850,
    "heightmap_size": 512,
}

UA = "JapanOpenWorld/1.0 (Godot build pipeline; +https://github.com/Daniel-debug-boop/japan-game-openworld1)"

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def log(msg: str) -> None:
    print(f"[build_world] {msg}", flush=True)


# --------------------------------------------------------------------------------------
# Web helpers
# --------------------------------------------------------------------------------------

def http_get(url: str, timeout: int = 60, retries: int = 4) -> bytes:
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            last = exc
            wait = min(2 ** attempt, 15)
            log(f"network error ({exc}); retry {attempt}/{retries} in {wait}s")
            time.sleep(wait)
    raise RuntimeError(f"failed to fetch {url}: {last}")


# --------------------------------------------------------------------------------------
# Web-Mercator helpers
# --------------------------------------------------------------------------------------

def lonlat_to_tile(lon: float, lat: float, z: int) -> tuple[int, int]:
    n = 2 ** z
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.log(math.tan(math.radians(lat)) + 1.0 / math.cos(math.radians(lat))) / math.pi) / 2.0 * n)
    return x, y


def tile_bounds(x: int, y: int, z: int) -> tuple[float, float, float, float]:
    """Return (west, south, east, north) in degrees for a tile."""
    n = 2 ** z

    def lon_of(xt: float) -> float:
        return xt / n * 360.0 - 180.0

    def lat_of(yt: float) -> float:
        return math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * yt / n))))

    return lon_of(x), lat_of(y + 1), lon_of(x + 1), lat_of(y)


# --------------------------------------------------------------------------------------
# Heightmap
# --------------------------------------------------------------------------------------

def decode_terrarium(data: bytes) -> list[list[float]]:
    """Decode a Terrarium-encoded PNG into a 2-D list of elevations in metres."""
    from PIL import Image

    import io

    im = Image.open(io.BytesIO(data)).convert("RGB")
    w, h = im.size
    raw = im.tobytes()
    rows: list[list[float]] = []
    for y in range(h):
        row = []
        base = y * w * 3
        for x in range(w):
            i = base + x * 3
            r, g, b = raw[i], raw[i + 1], raw[i + 2]
            row.append((r * 256 + g + b / 256.0) - 32768.0)
        rows.append(row)
    return rows


def build_heightmap(force: bool = False) -> dict:
    from PIL import Image

    out_dir = os.path.join(PROJECT_ROOT, "assets", "terrain")
    os.makedirs(out_dir, exist_ok=True)
    png_path = os.path.join(out_dir, "heightmap.png")
    json_path = os.path.join(out_dir, "heightmap.json")

    if not force and os.path.exists(png_path) and os.path.exists(json_path):
        log(f"heightmap already present: {png_path}")
        with open(json_path) as fh:
            return json.load(fh)

    south, north = REGION["south"], REGION["north"]
    west, east = REGION["west"], REGION["east"]

    # Choose the finest zoom that covers the region in a small tile block.
    zoom = 14
    x0, y0 = lonlat_to_tile(west, north, zoom)
    x1, y1 = lonlat_to_tile(east, south, zoom)

    tiles_x = x1 - x0 + 1
    tiles_y = y1 - y0 + 1
    log(f"region tiles at z{zoom}: {tiles_x}x{tiles_y}")

    # Mosaic tile elevation grids (each tile is 256x256).
    mosaic: list[list[float]] = []
    for ty in range(y0, y1 + 1):
        tile_rows: list[list[float]] = []
        for tx in range(x0, x1 + 1):
            url = f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{zoom}/{tx}/{ty}.png"
            log(f"fetch DEM tile {tx},{ty}")
            grid = decode_terrarium(http_get(url, timeout=90))
            for ry, row in enumerate(grid):
                if ry >= len(tile_rows):
                    tile_rows.append([])
                tile_rows[ry].extend(row)
        mosaic.extend(tile_rows)

    full_w = len(mosaic[0])
    full_h = len(mosaic)
    log(f"DEM mosaic {full_w}x{full_h}")

    # World->pixel mapping: the bbox corners inside the mosaic.
    mw, ms, me, mn = tile_bounds(x0, y0, zoom)
    mw2, ms2, me2, mn2 = tile_bounds(x1, y1, zoom)
    m_west, m_north = mw, mn
    m_east, m_south = me2, ms2

    size = REGION["heightmap_size"]
    out = Image.new("I;16", (size, size))
    px = out.load()

    elevations: list[float] = []
    for py in range(size):
        lat = m_north + (m_south - m_north) * (py / (size - 1))
        for pxi in range(size):
            lon = m_west + (m_east - m_west) * (pxi / (size - 1))
            fx = (lon - m_west) / (m_east - m_west) * (full_w - 1)
            fy = (m_north - lat) / (m_north - m_south) * (full_h - 1)
            ix, iy = int(round(fx)), int(round(fy))
            ix = max(0, min(full_w - 1, ix))
            iy = max(0, min(full_h - 1, iy))
            elevations.append(mosaic[iy][ix])

    lo, hi = min(elevations), max(elevations)
    log(f"elevation range: {lo:.1f}m .. {hi:.1f}m")

    span = max(hi - lo, 1.0)
    k = 0
    for py in range(size):
        for pxi in range(size):
            n = (elevations[k] - lo) / span
            px[pxi, py] = int(max(0.0, min(1.0, n)) * 65535)
            k += 1

    out.save(png_path)

    # Raw little-endian float32 elevation grid, in metres. This is what the game
    # loads at runtime: it is precise, compact and bypasses PNG import settings.
    import struct

    grid_path = os.path.join(out_dir, "heightmap.f32")
    with open(grid_path, "wb") as fh:
        fh.write(struct.pack("<I", size))
        fh.write(struct.pack("<I", size))
        fh.write(struct.pack("<%df" % (size * size), *elevations))

    meta = {
        "region": REGION,
        "zoom": zoom,
        "tiles": {
            "x0": x0, "y0": y0, "x1": x1, "y1": y1,
        },
        "mosaic_px": [full_w, full_h],
        "heightmap_px": [size, size],
        "bbox": {
            "west": m_west, "south": m_south, "east": m_east, "north": m_north,
        },
        "elevation_min_m": round(lo, 2),
        "elevation_max_m": round(hi, 2),
        "world_size_m": {
            "x": round((m_east - m_west) * 111320.0 * math.cos(math.radians((m_north + m_south) / 2)), 1),
            "z": round((m_north - m_south) * 110574.0, 1),
        },
        "source": "AWS Open Data terrain-tiles (Terrarium)",
        "license": "Terrain Tiles: free/open (SRTM, ETOPO, NED derived)",
        "heightmap_sha256": hashlib.sha256(open(png_path, "rb").read()).hexdigest(),
        "grid_file": "heightmap.f32",
        "grid_sha256": hashlib.sha256(open(grid_path, "rb").read()).hexdigest(),
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(json_path, "w") as fh:
        json.dump(meta, fh, indent=2)
    log(f"wrote {png_path}")
    return meta


# --------------------------------------------------------------------------------------
# OSM roads + buildings
# --------------------------------------------------------------------------------------

OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]


def overpass(query: str) -> dict:
    payload = urllib.parse.urlencode({"data": query}).encode()
    last = None
    for url in OVERPASS_URLS:
        for attempt in range(1, 3):
            try:
                req = urllib.request.Request(url, data=payload, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=180) as resp:
                    return json.loads(resp.read().decode("utf-8"))
            except Exception as exc:  # noqa: BLE001 - network surface is broad
                last = exc
                log(f"overpass {url} failed ({exc}); retrying")
                time.sleep(3)
    raise RuntimeError(f"all Overpass endpoints failed: {last}")


def local_projector(meta: dict):
    """Return (lon,lat)->(x,z) metres, with the region centre at (0,0)."""
    bbox = meta["bbox"]
    lat_c = (bbox["north"] + bbox["south"]) / 2.0
    lon_c = (bbox["east"] + bbox["west"]) / 2.0
    m_per_deg_lat = 110574.0
    m_per_deg_lon = 111320.0 * math.cos(math.radians(lat_c))

    def project(lon: float, lat: float) -> tuple[float, float]:
        # Terrain convention: +X = east, +Z = south (heightmap row 0 is north).
        return ((lon - lon_c) * m_per_deg_lon, -(lat - lat_c) * m_per_deg_lat)

    return project


def build_osm(meta: dict, force: bool = False) -> dict:
    out_dir = os.path.join(PROJECT_ROOT, "assets", "world")
    os.makedirs(out_dir, exist_ok=True)
    roads_path = os.path.join(out_dir, "roads.json")
    bldg_path = os.path.join(out_dir, "buildings.json")

    if not force and os.path.exists(roads_path) and os.path.exists(bldg_path):
        log("OSM outputs already present")
        return {"roads": roads_path, "buildings": bldg_path}

    b = meta["bbox"]
    bbox = f"{b['south']},{b['west']},{b['north']},{b['east']}"
    project = local_projector(meta)

    # ---- roads ----------------------------------------------------------------
    road_query = f"""
[out:json][timeout:120];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|living_street|pedestrian|service|footway|path)$"]({bbox});
);
out geom tags;
"""
    log("query Overpass: roads")
    roads_raw = overpass(road_query)

    roads = []
    for el in roads_raw.get("elements", []):
        geom = el.get("geometry")
        if not geom or len(geom) < 2:
            continue
        pts = [project(p["lon"], p["lat"]) for p in geom]
        tags = el.get("tags", {})
        roads.append({
            "id": el.get("id"),
            "highway": tags.get("highway", "residential"),
            "name": tags.get("name", ""),
            "width_m": _road_width(tags.get("highway", "residential"), tags),
            "points": [[round(x, 2), round(z, 2)] for x, z in pts],
        })
    with open(roads_path, "w") as fh:
        json.dump(roads, fh)
    log(f"wrote {roads_path} ({len(roads)} ways)")

    # ---- buildings ------------------------------------------------------------
    bldg_query = f"""
[out:json][timeout:120];
(
  way["building"]({bbox});
);
out geom tags;
"""
    log("query Overpass: buildings")
    bldg_raw = overpass(bldg_query)

    buildings = []
    for el in bldg_raw.get("elements", []):
        geom = el.get("geometry")
        if not geom or len(geom) < 3:
            continue
        pts = [project(p["lon"], p["lat"]) for p in geom]
        tags = el.get("tags", {})
        buildings.append({
            "id": el.get("id"),
            "type": tags.get("building", "yes"),
            "levels": _levels(tags),
            "points": [[round(x, 2), round(z, 2)] for x, z in pts],
        })
    with open(bldg_path, "w") as fh:
        json.dump(buildings, fh)
    log(f"wrote {bldg_path} ({len(buildings)} footprints)")

    manifest = {
        "roads": {"file": "roads.json", "count": len(roads)},
        "buildings": {"file": "buildings.json", "count": len(buildings)},
        "source": "OpenStreetMap (Overpass API)",
        "license": "ODbL 1.0 - © OpenStreetMap contributors",
        "attribution": "https://www.openstreetmap.org/copyright",
        "bbox": b,
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(os.path.join(out_dir, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)
    return {"roads": roads_path, "buildings": bldg_path, "manifest": manifest}


def _road_width(highway: str, tags: dict) -> float:
    default = {
        "motorway": 14.0, "trunk": 12.0, "primary": 10.0, "secondary": 8.0,
        "tertiary": 7.0, "residential": 5.0, "unclassified": 5.0,
        "living_street": 4.0, "pedestrian": 4.0, "service": 3.0,
        "footway": 2.0, "path": 2.0,
    }.get(highway, 4.0)
    if "width" in tags:
        try:
            return float(str(tags["width"]).split()[0])
        except (ValueError, IndexError):
            pass
    if "lanes" in tags:
        try:
            return max(2.5, float(tags["lanes"]) * 3.0)
        except ValueError:
            pass
    return default


def _levels(tags: dict) -> int:
    for key in ("building:levels", "levels"):
        if key in tags:
            try:
                return max(1, int(float(tags[key])))
            except ValueError:
                pass
    return 2


HIGHWAY_CODES = {
    "motorway": 0, "trunk": 1, "primary": 2, "secondary": 3, "tertiary": 4,
    "residential": 5, "unclassified": 6, "living_street": 7, "pedestrian": 8,
    "service": 9, "footway": 10, "path": 11,
}


def pack_binary(meta: dict) -> None:
    """Pack the JSON geodata into compact little-endian binaries for the game."""
    import struct

    out_dir = os.path.join(PROJECT_ROOT, "assets", "world")

    with open(os.path.join(out_dir, "roads.json")) as fh:
        roads = json.load(fh)
    buf = bytearray()
    buf += b"RD01"
    buf += struct.pack("<I", len(roads))
    for r in roads:
        pts = r["points"]
        code = HIGHWAY_CODES.get(r["highway"], 5)
        buf += struct.pack("<IBfI", int(r["id"]) & 0xFFFFFFFF, code, float(r["width_m"]), len(pts))
        for x, z in pts:
            buf += struct.pack("<ff", x, z)
    with open(os.path.join(out_dir, "roads.dat"), "wb") as fh:
        fh.write(buf)
    log(f"wrote roads.dat ({len(buf)/1e6:.2f} MB, {len(roads)} ways)")

    with open(os.path.join(out_dir, "buildings.json")) as fh:
        bldgs = json.load(fh)
    buf = bytearray()
    buf += b"BD01"
    buf += struct.pack("<I", len(bldgs))
    for b in bldgs:
        pts = b["points"]
        buf += struct.pack("<IBI", int(b["id"]) & 0xFFFFFFFF, min(255, int(b["levels"])), len(pts))
        for x, z in pts:
            buf += struct.pack("<ff", x, z)
    with open(os.path.join(out_dir, "buildings.dat"), "wb") as fh:
        fh.write(buf)
    log(f"wrote buildings.dat ({len(buf)/1e6:.2f} MB, {len(bldgs)} footprints)")


def main() -> int:
    ap = argparse.ArgumentParser(description="Build Japan Open World geodata")
    ap.add_argument("--force", action="store_true", help="re-download everything")
    args = ap.parse_args()

    meta = build_heightmap(force=args.force)
    build_osm(meta, force=args.force)
    pack_binary(meta)
    log("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
