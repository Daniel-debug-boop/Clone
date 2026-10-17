#!/usr/bin/env python3
"""
Japan Open World - Poly Haven PBR material fetcher.

Downloads real, CC0-licensed PBR material sets from Poly Haven's public API and
writes them into assets/textures/<asset_id>/ together with a provenance manifest.

Poly Haven assets are released under CC0 1.0 (public domain):
  https://polyhaven.com/license

Resolution/format defaults to 2k JPG (good quality, repo-friendly size).

Idempotent: existing files whose SHA-256 matches the manifest are kept.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
import urllib.request

UA = "JapanOpenWorld/1.0 (Godot build pipeline)"
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "textures")

# Material id -> why the game uses it.
MATERIALS = {
    "aerial_grass_rock": "terrain ground (grass / exposed rock)",
    "aerial_asphalt_01": "road surface",
    "rocky_terrain_02": "hillside / cliff detail",
    "painted_concrete": "building facades and retaining walls",
}

# Map slot -> Godot usage. Poly Haven names are stable API keys.
MAPS = {
    "Diffuse": "albedo",
    "nor_gl": "normal",
    "Rough": "roughness",
}

# HDRI environments (real captured skies) for image-based lighting.
HDRIS = {
    "kloofendal_48d_partly_cloudy_puresky": "daylight sky / IBL for the open world",
}

RESOLUTION = os.environ.get("PH_RES", "2k")
FORMAT = os.environ.get("PH_FORMAT", "jpg")


def log(msg: str) -> None:
    print(f"[fetch_assets] {msg}", flush=True)


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download(url: str, dest: str, expected_size: int | None = None) -> tuple[int, str]:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = resp.read()
    if expected_size is not None and len(data) != expected_size:
        raise RuntimeError(f"size mismatch for {url}: got {len(data)} expected {expected_size}")
    tmp = dest + ".part"
    with open(tmp, "wb") as fh:
        fh.write(data)
    os.replace(tmp, dest)
    return len(data), hashlib.sha256(data).hexdigest()


def main() -> int:
    os.makedirs(OUT_ROOT, exist_ok=True)
    manifest_path = os.path.join(OUT_ROOT, "manifest.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as fh:
            manifest = json.load(fh)

    failures = 0
    for asset_id, purpose in MATERIALS.items():
        try:
            files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
        except Exception as exc:  # noqa: BLE001
            log(f"{asset_id}: metadata failed ({exc})")
            failures += 1
            continue

        asset_dir = os.path.join(OUT_ROOT, asset_id)
        os.makedirs(asset_dir, exist_ok=True)
        entry = manifest.setdefault(asset_id, {
            "purpose": purpose,
            "source": f"https://polyhaven.com/a/{asset_id}",
            "license": "CC0 1.0",
            "license_url": "https://polyhaven.com/license",
            "resolution": RESOLUTION,
            "format": FORMAT,
            "files": {},
        })

        for ph_name, slot in MAPS.items():
            if ph_name not in files:
                log(f"{asset_id}: missing map {ph_name}, skipped")
                continue
            res_node = files[ph_name].get(RESOLUTION)
            if not res_node or FORMAT not in res_node:
                log(f"{asset_id}: no {RESOLUTION} {FORMAT} for {ph_name}")
                continue

            url = res_node[FORMAT]["url"]
            size = res_node[FORMAT].get("size")
            filename = f"{asset_id}_{slot}.{FORMAT}"
            dest = os.path.join(asset_dir, filename)

            known = entry["files"].get(slot, {})
            if os.path.exists(dest) and known.get("url") == url:
                log(f"{asset_id}/{filename}: cached")
                continue

            try:
                nbytes, sha = download(url, dest, size)
                entry["files"][slot] = {
                    "file": filename, "url": url, "bytes": nbytes, "sha256": sha,
                }
                log(f"{asset_id}/{filename}: {nbytes/1e6:.2f} MB")
            except Exception as exc:  # noqa: BLE001
                log(f"{asset_id}/{filename}: download failed ({exc})")
                failures += 1

    # ---- HDRIs ----------------------------------------------------------------
    hdri_root = os.path.join(PROJECT_ROOT, "assets", "hdri")
    os.makedirs(hdri_root, exist_ok=True)
    for hdri_id, purpose in HDRIS.items():
        try:
            files = get_json(f"https://api.polyhaven.com/files/{hdri_id}")
        except Exception as exc:  # noqa: BLE001
            log(f"{hdri_id}: metadata failed ({exc})")
            failures += 1
            continue
        node = files.get("hdri", {}).get("2k", {})
        if "hdr" not in node:
            log(f"{hdri_id}: no 2k hdr available")
            continue
        url = node["hdr"]["url"]
        size = node["hdr"].get("size")
        dest = os.path.join(hdri_root, f"{hdri_id}_2k.hdr")
        try:
            nbytes, sha = download(url, dest, size)
            manifest[hdri_id] = {
                "purpose": purpose, "source": f"https://polyhaven.com/a/{hdri_id}",
                "license": "CC0 1.0", "license_url": "https://polyhaven.com/license",
                "files": {"hdri": {"file": os.path.basename(dest), "url": url,
                                    "bytes": nbytes, "sha256": sha}},
            }
            log(f"{hdri_id}: {nbytes/1e6:.2f} MB")
        except Exception as exc:  # noqa: BLE001
            log(f"{hdri_id}: download failed ({exc})")
            failures += 1

    manifest["_meta"] = {
        "source": "Poly Haven",
        "license": "CC0 1.0 Universal",
        "attribution": "Assets courtesy of Poly Haven (polyhaven.com). CC0 - attribution appreciated, not required.",
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(manifest_path, "w") as fh:
        json.dump(manifest, fh, indent=2)
    log(f"wrote {manifest_path}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
