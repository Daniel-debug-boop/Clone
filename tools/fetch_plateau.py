#!/usr/bin/env python3
"""
Japan Open World - PLATEAU 3D Tiles pipeline.

Fetches Japan's official, free PLATEAU building models for the Kyoto wards that
overlap our playable region, decodes the Draco-compressed b3dm payloads, and
converts them into compact engine-ready meshes aligned with our terrain.

Why this shape of pipeline (measured, not assumed):

  * PLATEAU publishes 3D Tiles 1.0 whose b3dm payloads embed glTF compressed with
    KHR_draco_mesh_compression (verified on every Kyoto ward variant).
  * Godot's runtime GLTFDocument cannot decode Draco, so the tiles cannot be
    loaded directly at runtime.
  * Therefore the conversion runs offline in this pipeline: DracoPy decodes each
    primitive, coordinates are converted ECEF -> geodetic -> local ENU, and a
    compact binary (.pmesh) is written. The game then streams those binaries.

Data source : PLATEAU (Project PLATEAU, MLIT Japan) - https://www.mlit.go.jp/plateau/
Catalog API : https://api.plateauview.mlit.go.jp/datacatalog/plateau-datasets
Tiles       : assets.cms.plateau.reearth.io
Licence     : MLIT Public Data License 1.0 (PDL 1.0, 公共データ利用規約 第1.0版);
            MLIT states this is compatible with CC BY 4.0 (see THIRD_PARTY_NOTICES.md)

Outputs
  assets/plateau/<ward>/tile_XXXX.pmesh   engine-ready mesh chunks
  assets/plateau/index.json               tile index consumed by the game
  assets/plateau/manifest.json            provenance, licences, checksums, offset

Idempotent: cached b3dm downloads and existing .pmesh outputs are reused.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import struct
import sys
import time
import urllib.error
import urllib.request

try:
    import DracoPy  # noqa: F401
except ImportError:
    print("[plateau] DracoPy is required: python3 -m pip install DracoPy", file=sys.stderr)
    raise

UA = "JapanOpenWorld/1.0 (Godot build pipeline; +https://github.com/Daniel-debug-boop/japan-game-openworld1)"
CATALOG_URL = "https://api.plateauview.mlit.go.jp/datacatalog/plateau-datasets"
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(PROJECT_ROOT, ".cache", "plateau")
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "plateau")
TERRAIN_META = os.path.join(PROJECT_ROOT, "assets", "terrain", "heightmap.json")
TERRAIN_GRID = os.path.join(PROJECT_ROOT, "assets", "terrain", "heightmap.f32")

# Kyoto city ward codes overlapping the playable region.
#   26102 Kamigyo-ku   (Imperial Palace, Nijo Castle)
#   26103 Sakyo-ku     (Heian Shrine, Chion-in)
#   26104 Nakagyo-ku   (Nishiki Market, City Hall)
#   26105 Higashiyama-ku (Yasaka Shrine, Gion)
#   26106 Shimogyo-ku  (south of Shijo)
WARD_CODES = ["26102", "26103", "26104", "26105", "26106"]

# A single ward's LOD2 can be ~130 MB. The no-texture LOD2 variant is much smaller
# and is what we want anyway: we shade with our own PBR materials.
PREFERRED_SUFFIXES = ["_bldg_lod2_no_texture", "_bldg_lod1"]

WGS84_A = 6378137.0
WGS84_F = 1.0 / 298.257223563
WGS84_E2 = WGS84_F * (2.0 - WGS84_F)

PMSH_MAGIC = b"PMSH"
PMSH_VERSION = 1


def log(msg: str) -> None:
    print(f"[plateau] {msg}", flush=True)


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------

def http_get(url: str, timeout: int = 120, retries: int = 4, cache_path: str | None = None) -> bytes:
    if cache_path and os.path.exists(cache_path):
        with open(cache_path, "rb") as fh:
            return fh.read()

    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = resp.read()
            if cache_path:
                os.makedirs(os.path.dirname(cache_path), exist_ok=True)
                tmp = cache_path + ".part"
                with open(tmp, "wb") as fh:
                    fh.write(data)
                os.replace(tmp, cache_path)
            return data
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            last = exc
            wait = min(2 ** attempt, 20)
            log(f"network error ({exc}); retry {attempt}/{retries} in {wait}s")
            time.sleep(wait)
    raise RuntimeError(f"failed to fetch {url}: {last}")


# ---------------------------------------------------------------------------
# Geodesy: ECEF -> geodetic -> local ENU (x=east, y=up, z=south)
# ---------------------------------------------------------------------------

def ecef_to_geodetic(x: float, y: float, z: float) -> tuple[float, float, float]:
    lon = math.atan2(y, x)
    p = math.hypot(x, y)
    lat = math.atan2(z, p * (1.0 - WGS84_E2))
    h = 0.0
    for _ in range(6):
        n = WGS84_A / math.sqrt(1.0 - WGS84_E2 * math.sin(lat) ** 2)
        h = p / math.cos(lat) - n
        lat = math.atan2(z, p * (1.0 - WGS84_E2 * n / (n + h)))
    n = WGS84_A / math.sqrt(1.0 - WGS84_E2 * math.sin(lat) ** 2)
    h = p / math.cos(lat) - n
    return lat, lon, h


class LocalFrame:
    """Origin fixed at the centre of our DEM region.

    World convention: +X east, +Z south, +Y up (metres, sea-level referenced).
    """

    def __init__(self, lat0_deg: float, lon0_deg: float):
        self.lat0_deg = lat0_deg
        self.lon0_deg = lon0_deg
        self.lat0 = math.radians(lat0_deg)
        self.m_per_deg_lon = 111320.0 * math.cos(self.lat0)
        self.m_per_deg_lat = 110574.0

    def ecef_to_local(self, x: float, y: float, z: float) -> tuple[float, float, float]:
        lat, lon, h = ecef_to_geodetic(x, y, z)
        # Geodetic deltas in degrees, matching the OSM projector used elsewhere.
        east = (math.degrees(lon) - self.lon0_deg) * self.m_per_deg_lon
        north = (math.degrees(lat) - self.lat0_deg) * self.m_per_deg_lat
        return east, h, -north


# ---------------------------------------------------------------------------
# b3dm / GLB parsing
# ---------------------------------------------------------------------------

def parse_b3dm(data: bytes) -> tuple[dict, bytes]:
    if len(data) < 28 or data[:4] != b"b3dm":
        raise ValueError("not a b3dm tile")
    _magic, _ver, _blen, ftj, ftb, btj, btb = struct.unpack("<4sIIIIII", data[:28])
    glb = data[28 + ftj + ftb + btj + btb:]
    if glb[:4] != b"glTF":
        raise ValueError("b3dm payload is not GLB")
    json_len, _json_type = struct.unpack("<II", glb[12:20])
    gltf = json.loads(glb[20:20 + json_len].decode("utf-8"))
    bin_off = 20 + json_len + 8
    return gltf, glb[bin_off:]


def decode_primitives(gltf: dict, binary: bytes):
    """Yield (positions, normals, indices) in tile-local Cartesian coordinates."""
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            ext = (prim.get("extensions") or {}).get("KHR_draco_mesh_compression")
            if not ext:
                continue
            bv = gltf["bufferViews"][ext["bufferView"]]
            start = bv.get("byteOffset", 0)
            payload = binary[start:start + bv["byteLength"]]
            mesh_obj = __import__("DracoPy").decode(payload)
            pts = mesh_obj.points
            faces = mesh_obj.faces
            normals = getattr(mesh_obj, "normals", None)
            if normals is None or len(normals) != len(pts):
                normals = [(0.0, 0.0, 0.0)] * len(pts)
            yield pts, normals, faces


# ---------------------------------------------------------------------------
# Region helpers
# ---------------------------------------------------------------------------

def load_terrain():
    with open(TERRAIN_META) as fh:
        meta = json.load(fh)
    with open(TERRAIN_GRID, "rb") as fh:
        raw = fh.read()
    w, h = struct.unpack("<II", raw[:8])
    heights = struct.unpack("<%df" % (w * h), raw[8:8 + w * h * 4])
    return meta, w, h, heights


def sample_terrain(meta, w, h, heights, x, z):
    size = meta["world_size_m"]
    u = (x / size["x"] + 0.5) * (w - 1)
    v = (z / size["z"] + 0.5) * (h - 1)
    if u < 0 or v < 0 or u > w - 1 or v > h - 1:
        return None
    return heights[int(v) * w + int(u)]


def region_lonlat(meta):
    b = meta["bbox"]
    return b["west"], b["south"], b["east"], b["north"]


def region_radians(meta):
    w, s, e, n = region_lonlat(meta)
    return math.radians(w), math.radians(s), math.radians(e), math.radians(n)


def tile_intersects(tile_bv: dict, rb) -> bool:
    reg = tile_bv.get("region")
    if not reg:
        return True  # box/sphere volumes: keep, let clipping decide
    tw, ts, te, tn = reg[0], reg[1], reg[2], reg[3]
    rw, rs, re, rn = rb
    return not (te < rw or tw > re or tn < rs or ts > rn)


# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

def select_datasets(wards: list[str]) -> list[dict]:
    log("querying PLATEAU datacatalog")
    raw = http_get(CATALOG_URL, cache_path=os.path.join(CACHE, "datacatalog.json"))
    catalog = json.loads(raw.decode("utf-8"))
    datasets = catalog.get("datasets", [])
    log(f"catalog contains {len(datasets)} datasets")

    chosen = []
    for ward in wards:
        candidates = [
            d for d in datasets
            if str(d.get("pref_code")) == "26"
            and str(d.get("id", "")).startswith(ward)
            and "建築物" in str(d.get("type"))
        ]
        if not candidates:
            log(f"ward {ward}: no building dataset")
            continue
        best = None
        for suffix in PREFERRED_SUFFIXES:
            for d in candidates:
                if str(d["id"]).endswith(suffix):
                    best = d
                    break
            if best:
                break
        if best is None:
            best = candidates[0]
        chosen.append(best)
        log(f"ward {ward}: selected {best['id']} ({best.get('file_size')} bytes claimed)")
    return chosen


def walk_tiles(node: dict, out: list[dict], parent_region=None):
    bv = node.get("boundingVolume", {})
    content = node.get("content") or {}
    uri = content.get("uri")
    if uri:
        out.append({
            "uri": uri,
            "boundingVolume": bv,
            "geometricError": float(node.get("geometricError", 0.0)),
        })
    for child in node.get("children", []):
        walk_tiles(child, out, bv.get("region", parent_region))


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def convert_dataset(dataset: dict, frame: LocalFrame, meta, w, h, heights, region_bounds_rad, max_tiles=None):
    dataset_id = dataset["id"]
    ward = dataset_id.split("_")[0]
    tileset_url = dataset["url"]
    base_url = tileset_url.rsplit("/", 1)[0]

    log(f"{dataset_id}: fetching tileset.json")
    tileset = json.loads(http_get(
        tileset_url,
        cache_path=os.path.join(CACHE, dataset_id, "tileset.json"),
    ).decode("utf-8"))

    tiles: list[dict] = []
    walk_tiles(tileset["root"], tiles)

    inside = [t for t in tiles if tile_intersects(t["boundingVolume"], region_bounds_rad)]
    log(f"{dataset_id}: {len(tiles)} tiles, {len(inside)} intersect the region")

    # Prefer the most detailed (lowest geometricError) tiles if we must cap.
    inside.sort(key=lambda t: t["geometricError"])
    if max_tiles:
        inside = inside[:max_tiles]

    out_dir = os.path.join(OUT_ROOT, ward)
    os.makedirs(out_dir, exist_ok=True)

    entries = []
    total_verts = 0
    total_tris = 0
    skipped = 0

    for idx, tile in enumerate(inside):
        uri = tile["uri"]
        tile_url = f"{base_url}/{uri}"
        cache_path = os.path.join(CACHE, dataset_id, uri)
        name = f"{ward}_{idx:04d}"
        out_path = os.path.join(out_dir, f"{name}.pmesh")

        try:
            data = http_get(tile_url, cache_path=cache_path)
            gltf, binary = parse_b3dm(data)
        except Exception as exc:  # noqa: BLE001 - tolerate individual bad tiles
            log(f"  skip {uri}: {exc}")
            skipped += 1
            continue

        rtc = ((gltf.get("extensions") or {}).get("CESIUM_RTC") or {}).get("center")
        if not rtc:
            log(f"  skip {uri}: no CESIUM_RTC centre")
            skipped += 1
            continue
        rx, ry, rz = float(rtc[0]), float(rtc[1]), float(rtc[2])

        verts: list[tuple[float, float, float]] = []
        norms: list[tuple[float, float, float]] = []
        faces: list[tuple[int, int, int]] = []

        try:
            for pts, nrm, fc in decode_primitives(gltf, binary):
                base = len(verts)
                for i, p in enumerate(pts):
                    # b3dm glTF payloads are Y-up; 3D Tiles expects Z-up. The
                    # rotation (x, y, z) -> (x, -z, y) was verified against the
                    # tile's own region bounding volume: without it the vertical
                    # spread came out at 165 m instead of the true 25.7 m.
                    ex = rx + float(p[0])
                    ey = ry - float(p[2])
                    ez = rz + float(p[1])
                    lx, ly, lz = frame.ecef_to_local(ex, ey, ez)
                    verts.append((lx, ly, lz))
                    n = nrm[i]
                    # Same rotation for normals (no translation).
                    norms.append((float(n[0]), -float(n[2]), float(n[1])))
                for f in fc:
                    faces.append((base + int(f[0]), base + int(f[1]), base + int(f[2])))
        except Exception as exc:  # noqa: BLE001
            log(f"  skip {uri}: decode failed ({exc})")
            skipped += 1
            continue

        if not verts or not faces:
            continue

        # Clip to the playable region (generous margin), keeping whole triangles.
        half_x = meta["world_size_m"]["x"] * 0.5
        half_z = meta["world_size_m"]["z"] * 0.5
        margin = 150.0

        keep_faces = []
        used: dict[int, int] = {}
        out_v: list[tuple[float, float, float]] = []
        out_n: list[tuple[float, float, float]] = []
        for a, b, c in faces:
            cx = (verts[a][0] + verts[b][0] + verts[c][0]) / 3.0
            cz = (verts[a][2] + verts[b][2] + verts[c][2]) / 3.0
            if abs(cx) > half_x + margin or abs(cz) > half_z + margin:
                continue
            tri = []
            for vi in (a, b, c):
                if vi not in used:
                    used[vi] = len(out_v)
                    out_v.append(verts[vi])
                    out_n.append(norms[vi])
                tri.append(used[vi])
            keep_faces.append(tuple(tri))

        if not keep_faces:
            continue

        minx = min(v[0] for v in out_v)
        maxx = max(v[0] for v in out_v)
        miny = min(v[1] for v in out_v)
        maxy = max(v[1] for v in out_v)
        minz = min(v[2] for v in out_v)
        maxz = max(v[2] for v in out_v)

        write_pmesh(out_path, out_v, out_n, keep_faces, (minx, miny, minz, maxx, maxy, maxz))
        entries.append({
            "file": f"{ward}/{name}.pmesh",
            "vertices": len(out_v),
            "triangles": len(keep_faces),
            "bounds": [round(minx, 2), round(miny, 2), round(minz, 2),
                       round(maxx, 2), round(maxy, 2), round(maxz, 2)],
            "source": tile_url,
        })
        total_verts += len(out_v)
        total_tris += len(keep_faces)

    log(f"{dataset_id}: wrote {len(entries)} tiles, {total_verts} verts, {total_tris} tris, skipped {skipped}")
    return entries, {
        "id": dataset_id,
        "url": tileset_url,
        "tiles_written": len(entries),
        "vertices": total_verts,
        "triangles": total_tris,
        "skipped": skipped,
    }


def write_pmesh(path: str, verts, norms, faces, bounds) -> None:
    vcount = len(verts)
    icount = len(faces) * 3
    buf = bytearray()
    buf += PMSH_MAGIC
    buf += struct.pack("<I", PMSH_VERSION)
    buf += struct.pack("<III", vcount, icount, 0)   # material slot placeholder
    buf += struct.pack("<6f", *bounds)
    flat_v = [c for v in verts for c in v]
    flat_n = [c for n in norms for c in n]
    buf += struct.pack("<%df" % len(flat_v), *flat_v)
    buf += struct.pack("<%df" % len(flat_n), *flat_n)
    flat_i = [i for f in faces for i in f]
    buf += struct.pack("<%dI" % len(flat_i), *flat_i)
    tmp = path + ".part"
    with open(tmp, "wb") as fh:
        fh.write(buf)
    os.replace(tmp, path)


# ---------------------------------------------------------------------------
# Vertical alignment
# ---------------------------------------------------------------------------

def compute_vertical_offset(entries, meta, w, h, heights):
    """PLATEAU heights are ellipsoidal; our DEM is orthometric. Measure the delta.

    Building bases sit on the ground, so the difference between our terrain height
    and the tile's minimum Y (taken near the tile centre) is approximately constant
    across the region. We use the median to stay robust against outliers such as
    towers whose lowest vertex is a podium roof.
    """
    deltas = []
    for e in entries:
        b = e["bounds"]
        cx = (b[0] + b[3]) * 0.5
        cz = (b[2] + b[5]) * 0.5
        t = sample_terrain(meta, w, h, heights, cx, cz)
        if t is None:
            continue
        deltas.append(t - b[1])
    if not deltas:
        return 0.0
    deltas.sort()
    return round(deltas[len(deltas) // 2], 2)


def main() -> int:
    ap = argparse.ArgumentParser(description="Fetch and convert PLATEAU Kyoto buildings")
    ap.add_argument("--wards", default=",".join(WARD_CODES))
    ap.add_argument("--max-tiles-per-ward", type=int, default=0)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(OUT_ROOT, exist_ok=True)

    if not os.path.exists(TERRAIN_META) or not os.path.exists(TERRAIN_GRID):
        print("[plateau] terrain data missing; run tools/build_world.py first", file=sys.stderr)
        return 2

    meta, w, h, heights = load_terrain()
    west, south, east, north = region_lonlat(meta)
    lat0 = (north + south) * 0.5
    lon0 = (east + west) * 0.5
    frame = LocalFrame(lat0, lon0)
    region_bounds_rad = region_radians(meta)

    wards = [x.strip() for x in args.wards.split(",") if x.strip()]
    datasets = select_datasets(wards)
    all_entries: list[dict] = []
    dataset_reports = []

    for ds in datasets:
        entries, report = convert_dataset(
            ds, frame, meta, w, h, heights, region_bounds_rad,
            max_tiles=args.max_tiles_per_ward or None,
        )
        all_entries.extend(entries)
        dataset_reports.append(report)

    if not all_entries:
        print("[plateau] no tiles converted", file=sys.stderr)
        return 1

    offset = compute_vertical_offset(all_entries, meta, w, h, heights)
    log(f"vertical offset (terrain minus PLATEAU): {offset:.2f} m")

    index = {
        "format": "pmesh",
        "version": PMSH_VERSION,
        "origin": {"lat": lat0, "lon": lon0},
        "vertical_offset_m": offset,
        "tile_count": len(all_entries),
        "vertices": sum(e["vertices"] for e in all_entries),
        "triangles": sum(e["triangles"] for e in all_entries),
        "tiles": all_entries,
    }
    with open(os.path.join(OUT_ROOT, "index.json"), "w") as fh:
        json.dump(index, fh)

    manifest = {
        "source": "PLATEAU (Project PLATEAU, MLIT Japan)",
        "portal": "https://www.mlit.go.jp/plateau/",
        "catalog_api": CATALOG_URL,
        "licence": "Public Data License 1.0 (PDL 1.0, 公共データ利用規約 第1.0版) - MLIT terms of use for Project PLATEAU; MLIT states this is compatible with CC BY 4.0",
        "licence_cc_by_compatible": True,
        "attribution": "3D city model data: Project PLATEAU, Ministry of Land, Infrastructure, Transport and Tourism (Japan)",
        "cartography_approval": "PLATEAU data is published for open use; see the portal for the current terms.",
        "wards": dataset_reports,
        "totals": {
            "tiles": index["tile_count"],
            "vertices": index["vertices"],
            "triangles": index["triangles"],
        },
        "vertical_offset_m": offset,
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(os.path.join(OUT_ROOT, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)

    index_sha = hashlib.sha256(open(os.path.join(OUT_ROOT, "index.json"), "rb").read()).hexdigest()
    log(f"index.json sha256={index_sha}")
    log(f"total: {index['tile_count']} tiles, {index['vertices']} verts, {index['triangles']} tris")
    return 0


if __name__ == "__main__":
    sys.exit(main())
