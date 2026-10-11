#!/usr/bin/env python3
"""Re-encode shipping WebP from PNG masters at quality 92, native size.

Masters live in the parent of the q78 pass (commit 8be73223^). Extract them
first:

    git archive 8be73223^ project/assets/art | tar -x -C /tmp/ck-masters

Lossy WebP cannot be sharpened by re-saving it. This script reads the PNG
and writes a new WebP. It never resizes. Doll plates (Godot compress/mode 0)
stay lossless and are not touched. Godot .import lossy_quality is raised to
0.92 so the engine does not run a second, softer pass.

A missing master is reported and left as-is, except the import quality is
still raised so Godot does not crush it further.
"""
from __future__ import annotations

import argparse
import json
import os
import re
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "project" / "assets" / "art"
REPORT = ROOT / "tools" / "ci" / "webp_sharpness_report.json"
QUALITY = 92
LOSSY_RE = re.compile(r"compress/lossy_quality=([0-9.]+)")
MODE_RE = re.compile(r"compress/mode=(\d+)")
SAMPLES = {
    "project/assets/art/portraits/genome/bank/elder_0133cd4f080bf504.webp",
    "project/assets/art/portraits/hireuniq_376.webp",
    "project/assets/art/portraits/hireface_wheat_pine_m_cheek_thick.webp",
    "project/assets/art/atlas/cities/v87_city_eo_archive.webp",
    "project/assets/art/scenes/v8_scene_ch0_pass.webp",
    "project/assets/art/ui/battle_backdrop.webp",
    "project/assets/art/castle/v92_castle_academy_t1.webp",
    "project/assets/art/estates/v92_estate_ashbanner_g1.webp",
    "project/assets/art/battle/v8_battle_biome_archive.webp",
}


def _rmse(master: Image.Image, other: Image.Image) -> float:
    a = master.convert("RGB")
    b = other.convert("RGB")
    if b.size != a.size:
        b = b.resize(a.size, Image.Resampling.LANCZOS)
    pa = list(a.getdata())
    pb = list(b.getdata())
    if not pa:
        return 0.0
    acc = 0.0
    for ca, cb in zip(pa, pb):
        acc += (ca[0] - cb[0]) ** 2 + (ca[1] - cb[1]) ** 2 + (ca[2] - cb[2]) ** 2
    return (acc / (len(pa) * 3)) ** 0.5


def _patch_import(import_path: Path) -> str:
    if not import_path.is_file():
        return "no-import"
    text = import_path.read_text(encoding="utf-8", errors="replace")
    mode = MODE_RE.search(text)
    if mode and mode.group(1) == "0":
        return "lossless-kept"
    found = LOSSY_RE.search(text)
    current = float(found.group(1)) if found else 0.0
    if current >= 0.92 and "compress/high_quality=true" in text:
        return "import-already-92"
    text = LOSSY_RE.sub("compress/lossy_quality=0.92", text, count=1)
    text = text.replace("compress/high_quality=false", "compress/high_quality=true")
    import_path.write_text(text, encoding="utf-8")
    return "import-92"


def _restore(task: tuple[str, str, bool]) -> dict:
    webp_s, master_s, sample = task
    webp = Path(webp_s)
    before = webp.stat().st_size
    before_size = list(Image.open(webp).size)
    import_path = Path(str(webp) + ".import")
    text = import_path.read_text(encoding="utf-8", errors="replace") if import_path.is_file() else ""
    mode = MODE_RE.search(text)
    if mode and mode.group(1) == "0":
        return {"path": webp_s, "status": "skipped-lossless", "before": before, "after": before}
    master = Path(master_s)
    if not master.is_file():
        note = _patch_import(import_path)
        return {
            "path": webp_s,
            "status": "missing-master",
            "before": before,
            "after": before,
            "import": note,
        }
    im = Image.open(master)
    im.load()
    if "A" in im.getbands():
        im = im.convert("RGBA")
        im.save(webp, "WEBP", quality=QUALITY, method=6, alpha_quality=100)
    else:
        im = im.convert("RGB")
        im.save(webp, "WEBP", quality=QUALITY, method=6)
    after = webp.stat().st_size
    note = _patch_import(import_path)
    return {
        "path": webp_s,
        "status": "restored",
        "before": before,
        "after": after,
        "master_bytes": master.stat().st_size,
        "before_size": before_size,
        "after_size": list(im.size),
        "import": note,
        "sample": sample,
    }


def _restore_with_before(task: tuple[str, str, bool]) -> dict:
    webp_s, master_s, sample = task
    try:
        webp = Path(webp_s)
        before_im = None
        if sample and webp.is_file():
            before_im = Image.open(webp)
            before_im.load()
        row = _restore(task)
        if sample and before_im is not None and Path(master_s).is_file() and row.get("status") == "restored":
            master = Image.open(master_s)
            master.load()
            row["rmse_before"] = round(_rmse(master, before_im), 3)
            row["rmse_after"] = round(_rmse(master, Image.open(webp)), 3)
        return row
    except Exception as exc:  # noqa: BLE001 — one bad plate must not abort the pass
        return {"path": webp_s, "status": "error", "error": str(exc), "before": 0, "after": 0}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--masters", default="/tmp/ck-masters", help="git archive root")
    args = parser.parse_args()
    masters = Path(args.masters)
    if not (masters / "project" / "assets" / "art").is_dir():
        print(f"masters missing under {masters}")
        return 1
    tasks = []
    for path in sorted(ART.rglob("*.webp")):
        name = path.name
        if name.endswith(".small.webp") or name.endswith(".medium.webp") or name.endswith(".large.webp"):
            continue
        rel = path.relative_to(ROOT).as_posix()
        png_rel = rel[: -len(".webp")] + ".png"
        tasks.append((str(path), str(masters / png_rel), rel in SAMPLES))
    workers = min(8, os.cpu_count() or 4)
    print(f"restore {len(tasks)} webp from {masters} with {workers} workers", flush=True)
    restored = skipped = missing = errors = 0
    before_b = after_b = 0
    samples = []
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for i, row in enumerate(pool.map(_restore_with_before, tasks, chunksize=4), start=1):
            status = row.get("status")
            if status == "restored":
                restored += 1
                before_b += row["before"]
                after_b += row["after"]
                if row.get("sample"):
                    samples.append(row)
            elif status == "missing-master":
                missing += 1
            elif status == "skipped-lossless":
                skipped += 1
            else:
                errors += 1
                print("ERR", row, flush=True)
            if i % 200 == 0 or i == len(tasks):
                print(
                    f"  {i}/{len(tasks)} restored={restored} missing={missing} "
                    f"lossless={skipped} delta={(after_b-before_b)/1024/1024:.1f}MB",
                    flush=True,
                )
    report = {
        "quality": QUALITY,
        "method": 6,
        "resized": False,
        "masters": "git 8be73223^ project/assets/art PNG",
        "restored": restored,
        "missing_master": missing,
        "skipped_lossless": skipped,
        "errors": errors,
        "bytes_before": before_b,
        "bytes_after": after_b,
        "samples": samples,
        "policy": (
            "WebP quality 92 at native resolution. "
            "Godot import lossy_quality 0.92. "
            "Gene bank ships in the base export. Small and medium tiers are separate siblings."
        ),
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"restored={restored} missing={missing} lossless_skipped={skipped} "
        f"before={before_b/1024/1024:.1f}MB after={after_b/1024/1024:.1f}MB"
    )
    print(f"wrote {REPORT}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
