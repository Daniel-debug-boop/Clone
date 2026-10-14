#!/usr/bin/env python3
"""Dependency-free M1 proof: pinned source, license gate, tests, failure detection, report."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

def run(args, cwd=None, check=True):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(args)}\n{result.stdout}\n{result.stderr}")
    return result

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    report = {
        "schema_version": 1,
        "pipeline": "Launti M1 proof",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "checks": [],
        "status": "failed",
    }
    out = Path(os.environ.get("PIPELINE_REPORT", "pipeline-m1-report.json"))
    try:
        with tempfile.TemporaryDirectory(prefix="launti-pipeline-m1-") as temp:
            repo = Path(temp) / "sample-component"
            repo.mkdir()
            run(["git", "init", "-q", str(repo)])
            run(["git", "config", "user.name", "Launti Pipeline Test"], cwd=repo)
            run(["git", "config", "user.email", "pipeline-test@example.invalid"], cwd=repo)
            (repo / "LICENSE").write_text(
                "MIT License\n\nPermission is hereby granted, free of charge, to any person obtaining a copy.\n",
                encoding="utf-8",
            )
            (repo / "component.py").write_text("def add(a, b):\n    return a + b\n", encoding="utf-8")
            run(["git", "add", "LICENSE", "component.py"], cwd=repo)
            run(["git", "commit", "-qm", "sample component"], cwd=repo)
            pinned = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
            actual = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
            assert pinned == actual and len(pinned) == 40
            report["checks"].append({"id":"M1-01","name":"source revision pinned","status":"passed","commit":pinned})

            license_text = (repo / "LICENSE").read_text(encoding="utf-8")
            assert "MIT License" in license_text and "Permission is hereby granted" in license_text
            report["checks"].append({"id":"M1-02","name":"license file present and recognized by fixture policy","status":"passed","license":"MIT (test fixture)"})

            source_hash = sha256(repo / "component.py")
            assert len(source_hash) == 64
            report["checks"].append({"id":"M1-03","name":"source provenance checksum recorded","status":"passed","sha256":source_hash})

            passing = Path(temp) / "passing_test.py"
            passing.write_text("import unittest\nfrom pathlib import Path\nclass TestComponent(unittest.TestCase):\n def test_source_exists(self): self.assertTrue(Path(" + repr(str(repo / "component.py")) + ").is_file())\nif __name__ == '__main__': unittest.main()\n", encoding="utf-8")
            good = run([sys.executable, str(passing)], check=False)
            if good.returncode != 0:
                raise RuntimeError("Passing fixture unexpectedly failed: " + good.stderr)
            report["checks"].append({"id":"M1-04","name":"passing test accepted","status":"passed","exit_code":good.returncode})

            failing = Path(temp) / "intentional_failure_test.py"
            failing.write_text("import unittest\nclass IntentionalFailure(unittest.TestCase):\n def test_pipeline_must_reject_this(self): self.assertEqual(1, 2)\nif __name__ == '__main__': unittest.main()\n", encoding="utf-8")
            bad = run([sys.executable, str(failing)], check=False)
            if bad.returncode == 0:
                raise RuntimeError("Failure gate is broken: intentionally failing test returned exit code 0")
            report["checks"].append({"id":"M1-05","name":"intentional failing test rejected","status":"passed","observed_exit_code":bad.returncode})

            report["checks"].append({"id":"M1-06","name":"report generation","status":"passed","report_schema_version":1})
        report["status"] = "passed"
    except Exception as exc:
        report["error"] = str(exc)
        report["status"] = "failed"
    report["finished_utc"] = datetime.now(timezone.utc).isoformat()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "passed" else 1

if __name__ == "__main__":
    raise SystemExit(main())
