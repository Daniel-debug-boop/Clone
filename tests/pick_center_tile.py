#!/usr/bin/env python3
"""Print the PLATEAU .pmesh path whose tile centre is nearest the world origin.

Used by tests/run_tests.sh to hide a tile that is definitely inside the loader's
streaming radius, so the graceful-degradation path is actually exercised.
"""

import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "assets", "plateau", "index.json")


def main() -> int:
    if not os.path.exists(INDEX):
        return 1
    with open(INDEX) as fh:
        idx = json.load(fh)

    best = None
    best_d = float("inf")
    for tile in idx.get("tiles", []):
        b = tile.get("bounds") or []
        if len(b) < 6:
            continue
        cx = (b[0] + b[3]) / 2.0
        cz = (b[2] + b[5]) / 2.0
        d = math.hypot(cx, cz)
        if d < best_d:
            best_d = d
            best = tile.get("file")

    if not best:
        return 1
    path = os.path.join(ROOT, "assets", "plateau", best)
    if not os.path.exists(path):
        return 1
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
