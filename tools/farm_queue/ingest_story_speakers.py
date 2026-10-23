#!/usr/bin/env python3
"""Gate and ingest story-speaker plates (tools/farm_queue/v92_story_speakers.json + v92_y1a_gap_speakers.json).

Colour gate = style-lock metrics from ingest_status_overlays (whole plate, no alpha
keying). PASS plates land as <out_path stem>.webp (q92) + .import under
portraits/speakers/; run tools/art/build_portrait_tiers.py afterwards for the
small/medium siblings. FAIL plates are listed and never written. A missing
plate keeps the in-game silhouette.

  python3 tools/farm_queue/ingest_story_speakers.py --inbox DIR [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ingest_status_overlays as iso  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
QUEUE_DIR = ROOT / "tools" / "farm_queue"
QUEUE_FILES = (
    QUEUE_DIR / "v92_story_speakers.json",
    QUEUE_DIR / "v92_y1a_gap_speakers.json",
)
REPORT = ROOT / "docs" / "art" / "review" / "story_speakers_v92.json"
SIZE = (768, 1024)


def load_jobs() -> list[dict]:
    jobs: list[dict] = []
    for path in QUEUE_FILES:
        if not path.exists():
            continue
        doc = json.loads(path.read_text(encoding="utf-8"))
        jobs.extend(doc.get("jobs", []))
    return jobs



def find_source(inbox: Path, job: dict) -> Path | None:
    hits = sorted(p for p in inbox.rglob(f"*{job['id']}*") if p.suffix.lower() in {".png", ".webp"})
    return hits[-1] if hits else None


def gate(path: Path, job: dict, style: dict) -> tuple[bool, dict]:
    im = Image.open(path).convert("RGB")
    if im.size != SIZE:
        im = im.resize(SIZE, Image.LANCZOS)
    rgba = np.dstack([np.asarray(im), np.full((SIZE[1], SIZE[0]), 255, np.uint8)])
    tmp = Image.fromarray(rgba, "RGBA")
    old = iso.key_void_to_alpha
    iso.key_void_to_alpha = lambda x: x  # full plate, keep every pixel
    try:
        tmp_path = path.with_suffix(".gate.png")
        tmp.save(tmp_path)
        relaxed = dict(job, gate=dict(job.get("gate", {}), min_opaque_ratio=0.0, max_opaque_ratio=1.0, min_mean_alpha_opaque=0.0))
        ok, m = iso.gate_plate(tmp_path, relaxed, style)
    finally:
        iso.key_void_to_alpha = old
        tmp_path.unlink(missing_ok=True)
    return ok, m


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--inbox", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    inbox = Path(a.inbox)
    style = iso.lock_check()
    jobs = load_jobs()
    report = []
    passed = 0
    for job in jobs:
        src = find_source(inbox, job)
        if src is None:
            print(f"MISSING {job['id']} ({job['speaker']})")
            report.append({"id": job["id"], "status": "missing"})
            continue
        ok, m = gate(src, job, style)
        row = {"id": job["id"], "speaker": job["speaker"], "status": "pass" if ok else "fail", "metrics": m, "src": src.name}
        report.append(row)
        if not ok:
            print(f"FAIL   {job['id']} {m.get('fails')}")
            continue
        passed += 1
        dest = ROOT / Path(job["out_path"]).with_suffix(".webp")
        print(f"PASS   {job['id']} -> {dest.relative_to(ROOT)}")
        if a.dry_run:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        Image.open(src).convert("RGB").resize(SIZE, Image.LANCZOS).save(dest, "WEBP", quality=92, method=6)
        iso.write_import(dest)
    if not a.dry_run:
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"SPEAKERS pass={passed} of {len(jobs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
