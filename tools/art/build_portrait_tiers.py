#!/usr/bin/env python3
"""Build small and medium portrait siblings from the sharp shipping plates.

Large is the file that already shipped: WebP quality 92 at the master pixel
size (768x1024 for the gene bank and expression plates). This pass does not
resize that file and does not encode below quality 92.

small  = 1/2 of the master (384x512 on a 768x1024 plate) — lists, chess tokens
medium = 2/3 of the master (512x682) — dialogue and half-body

Pixels are Lanczos-resampled from the quality-92 plate, which itself was
encoded from the PNG master. That is one sharp source, then a smaller grid,
not a second pass over the old soft q78 file. Plates already under 640px on
the long side are left alone: shrinking them would soften a face that is
already the size the UI shows.

Godot still loads the sibling with Image.load_from_file. The .import sidecar
keeps lossy_quality at 0.92 so an exported texture is not crushed softer.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "project" / "assets" / "art" / "portraits"
PROJECT = ROOT / "project"
REPORT = ROOT / "tools" / "ci" / "portrait_tiers_report.json"
QUALITY = 92
MIN_LONG_SIDE = 640
SCALES = {"small": 0.5, "medium": 2.0 / 3.0}
UID_ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"
MODE_RE = re.compile(r"compress/mode=(\d+)")


def even_size(width: int, height: int, scale: float) -> tuple[int, int]:
    def even(value: float) -> int:
        rounded = int(round(value))
        if rounded % 2:
            rounded -= 1
        return max(2, rounded)

    return even(width * scale), even(height * scale)


def tier_path(source: Path, tier: str) -> Path:
    return source.with_name(f"{source.stem}.{tier}.webp")


def _lossless_source(path: Path) -> bool:
    text_path = Path(str(path) + ".import")
    if not text_path.is_file():
        return False
    mode = MODE_RE.search(text_path.read_text(encoding="utf-8", errors="replace"))
    return bool(mode and mode.group(1) == "0")


def _write_import(webp: Path) -> None:
    rel = webp.relative_to(PROJECT).as_posix()
    digest = hashlib.md5(rel.encode()).hexdigest()
    dest = f"res://.godot/imported/{webp.name}-{digest}.ctex"
    uid_digest = hashlib.sha1(rel.encode()).digest()
    chars = "".join(UID_ALPHABET[b % len(UID_ALPHABET)] for b in uid_digest[:13])
    text = (
        "[remap]\n\n"
        'importer="texture"\n'
        'type="CompressedTexture2D"\n'
        f'uid="uid://{chars}"\n'
        f'path="{dest}"\n'
        "metadata={\n"
        '"vram_texture": false\n'
        "}\n\n"
        "[deps]\n\n"
        f'source_file="res://{rel}"\n'
        f'dest_files=["{dest}"]\n\n'
        "[params]\n\n"
        "compress/mode=1\n"
        "compress/high_quality=true\n"
        "compress/lossy_quality=0.92\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=false\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        'roughness/src_normal=""\n'
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/normal_map_invert_y=false\n"
        "process/hdr_as_srgb=false\n"
        "process/hdr_clamp_exposure=false\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n"
    )
    Path(str(webp) + ".import").write_text(text, encoding="utf-8")


def _already(dest: Path, size: tuple[int, int]) -> bool:
    if not dest.is_file() or dest.stat().st_size <= 0:
        return False
    with Image.open(dest) as existing:
        return existing.size == size


def _one(task: tuple[str, str]) -> dict:
    source_s, tier = task
    source = Path(source_s)
    try:
        im = Image.open(source)
        im.load()
        if im.mode in {"RGBA", "LA"} or (im.mode == "P" and "transparency" in im.info):
            im = im.convert("RGBA")
        else:
            im = im.convert("RGB")
        width, height = even_size(im.width, im.height, SCALES[tier])
        dest = tier_path(source, tier)
        if _already(dest, (width, height)):
            return {"status": "kept", "tier": tier, "bytes": dest.stat().st_size, "size": [width, height]}
        resized = im.resize((width, height), Image.Resampling.LANCZOS)
        if "A" in resized.getbands():
            resized.save(dest, "WEBP", quality=QUALITY, method=6, alpha_quality=100)
        else:
            resized = resized.convert("RGB")
            resized.save(dest, "WEBP", quality=QUALITY, method=6)
        _write_import(dest)
        return {
            "status": "wrote",
            "tier": tier,
            "bytes": dest.stat().st_size,
            "size": [width, height],
            "path": dest.relative_to(ROOT).as_posix(),
        }
    except Exception as exc:  # noqa: BLE001 — one plate must not abort the pass
        return {"status": "error", "tier": tier, "path": source_s, "error": str(exc), "bytes": 0}


def sources() -> list[Path]:
    found: list[Path] = []
    for path in sorted(ART.rglob("*.webp")):
        name = path.name
        if name.endswith(".small.webp") or name.endswith(".medium.webp") or name.endswith(".large.webp"):
            continue
        if "status" in path.parts:
            continue
        if _lossless_source(path):
            continue
        found.append(path)
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0, help="process only the first N masters (debug)")
    args = parser.parse_args()
    masters = sources()
    if args.limit:
        masters = masters[: args.limit]
    tasks: list[tuple[str, str]] = []
    skipped_small = 0
    for path in masters:
        with Image.open(path) as im:
            long_side = max(im.size)
        if long_side < MIN_LONG_SIDE:
            skipped_small += 1
            continue
        for tier in ("small", "medium"):
            tasks.append((str(path), tier))
    workers = min(8, os.cpu_count() or 4)
    print(f"tiers {len(tasks)} encodes from {len(masters) - skipped_small} masters, {workers} workers", flush=True)
    wrote = kept = errors = 0
    by_tier = {"small": 0, "medium": 0}
    sample: dict | None = None
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for i, row in enumerate(pool.map(_one, tasks, chunksize=2), start=1):
            status = row.get("status")
            if status == "error":
                errors += 1
                print("ERR", row, flush=True)
            else:
                by_tier[row["tier"]] = by_tier.get(row["tier"], 0) + int(row.get("bytes", 0))
                if status == "wrote":
                    wrote += 1
                    if sample is None and row["tier"] == "small":
                        sample = row
                else:
                    kept += 1
            if i % 200 == 0 or i == len(tasks):
                print(f"  {i}/{len(tasks)} wrote={wrote} kept={kept} errors={errors}", flush=True)
    report = {
        "quality": QUALITY,
        "method": 6,
        "scales": {"small": 0.5, "medium": 2 / 3, "large": 1.0},
        "min_long_side": MIN_LONG_SIDE,
        "masters": len(masters) - skipped_small,
        "skipped_already_small": skipped_small,
        "wrote": wrote,
        "kept": kept,
        "errors": errors,
        "bytes": by_tier,
        "sample": sample,
        "policy": (
            "Gene bank and other sharp plates ship inside the base export. "
            "Large stays native WebP quality 92. "
            "Small and medium are Lanczos siblings at quality 92."
        ),
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"wrote={wrote} kept={kept} errors={errors} "
        f"small={by_tier['small']/1024/1024:.1f}MB medium={by_tier['medium']/1024/1024:.1f}MB"
    )
    print(f"wrote {REPORT}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
