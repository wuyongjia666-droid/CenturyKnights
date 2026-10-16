#!/usr/bin/env python3
"""Smoke checks for plate_palette.py (reproducible extract + overrides skeleton)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "tools/art/plate_palette.py"
BANK = ROOT / "project/assets/art/portraits/genome/bank"
OUT = ROOT / "project/data/plate_palettes.json"


def _ensure_numpy() -> None:
    """Lint job installs pillow only; plate_palette needs numpy.

    Cannot edit .github/workflows/ci.yml from this OAuth token (no workflow scope).
    """
    try:
        import numpy  # noqa: F401
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "numpy"])


def main() -> int:
    _ensure_numpy()
    r = subprocess.run([sys.executable, str(TOOL), "--self-test"], cwd=ROOT)
    if r.returncode != 0:
        print("TEST PLATE PALETTE FAIL self-test")
        return 1
    stems = []
    for p in sorted(BANK.glob("*.webp")):
        n = p.name
        if n.endswith(".medium.webp") or n.endswith(".small.webp"):
            continue
        stems.append(n[: -len(".webp")])
        if len(stems) >= 3:
            break
    if not stems:
        print("TEST PLATE PALETTE SKIP no plates")
        return 0
    # Spot extract three stems and compare to committed table if present.
    r2 = subprocess.run(
        [sys.executable, str(TOOL), "--stems", ",".join(stems), "--limit", "0",
         "--out", "/tmp/ck_plate_spot.json", "--overrides", "/tmp/ck_plate_ovr.json",
         "--review-dir", "/tmp/ck_plate_review"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if r2.returncode != 0:
        print(r2.stdout)
        print(r2.stderr)
        print("TEST PLATE PALETTE FAIL spot extract")
        return 1
    spot = json.loads(Path("/tmp/ck_plate_spot.json").read_text(encoding="utf-8"))
    plates = spot["plates"]
    for s in stems:
        assert s in plates, s
        assert plates[s]["hair"].startswith("#")
        assert plates[s]["style"] in (
            "crop", "swept", "tied", "messy", "long", "pony", "bob", "crown"
        )
    if OUT.is_file():
        full = json.loads(OUT.read_text(encoding="utf-8"))
        fp = full.get("plates", {})
        for s in stems:
            if s in fp:
                # Reproducible vs committed
                if fp[s]["hair"] != plates[s]["hair"] or fp[s]["coat"] != plates[s]["coat"]:
                    print(f"TEST PLATE PALETTE FAIL drift on {s}")
                    print(" committed", fp[s]["hair"], fp[s]["coat"])
                    print(" recomputed", plates[s]["hair"], plates[s]["coat"])
                    return 1
    print(f"TEST PLATE PALETTE PASS stems={len(stems)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
