#!/usr/bin/env python3
"""Compress shipping art under project/assets/art to Godot 4.3 WebP.

Photographs (gene portraits, cities, scenes, castle, estates, backdrops)
become WebP at quality 92, at the master's native resolution. Nothing in
this pass is resized, and nothing is encoded below PHOTO_QUALITY. Package
size is not a reason to soften a plate. Portrait lists, dialogue, and
detail use the small / medium / large siblings from
tools/art/build_portrait_tiers.py. The gene bank stays in the base export.
Paper-doll parts stay lossless WebP so alpha edges remain sharp. UI chrome,
FX, tokens, terrain, glyphs and the farm inbox stay PNG.

Farm queue JSON still names the generator's .png target. Loaders resolve
the shipped .webp beside that name.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "project" / "assets" / "art"
PROJECT = ROOT / "project"
REPORT = ROOT / "tools" / "ci" / "webp_pass_report.json"
UID_ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"
SKIP_TOP = {"fx", "tokens", "tiles", "terrain_v86", "banners", "farm_inbox"}
# Near-lossless. Do not drop this to save bytes; split packs instead.
PHOTO_QUALITY = 0.92


def shipping_quality(parts: tuple[str, ...]) -> float | None:
    """Lossy quality in 0..1, or None when the plate must stay lossless."""
    if parts and parts[0] == "doll":
        return None
    return PHOTO_QUALITY


def shipping_size(width: int, height: int, _parts: tuple[str, ...]) -> tuple[int, int]:
    """Native pixels. Shipping never resizes a plate to hit a size budget."""
    return width, height


def _bucket(path: Path) -> str:
    rel = path.relative_to(ART)
    parts = rel.parts
    if parts[0] == "portraits" and len(parts) > 1 and parts[1] == "genome":
        return "portraits/genome"
    if parts[0] == "portraits":
        return "portraits/other"
    if parts[0] == "atlas" and len(parts) > 1 and parts[1] == "cities":
        return "atlas/cities"
    if parts[0] == "ui" and len(parts) > 1 and parts[1] == "items":
        return "ui/items"
    return parts[0]


def _measure() -> dict[str, int]:
    totals: dict[str, int] = {}
    for path in ART.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg"}:
            continue
        key = _bucket(path)
        totals[key] = totals.get(key, 0) + path.stat().st_size
    return totals


def _uid_from_text(text: str) -> str | None:
    match = re.search(r'uid="(uid://[^"]+)"', text)
    return match.group(1) if match else None


def _uid_for(rel: str, old_import: Path) -> str:
    if old_import.is_file():
        found = _uid_from_text(old_import.read_text(encoding="utf-8", errors="replace"))
        if found:
            return found
    digest = hashlib.sha1(rel.encode()).digest()
    chars = "".join(UID_ALPHABET[b % len(UID_ALPHABET)] for b in digest[:13])
    return "uid://" + chars


def _write_import(webp: Path, lossy_q: float | None, old_import: Path) -> None:
    rel = webp.relative_to(PROJECT).as_posix()
    # Godot names the .ctex after md5("res://" + rel); any other digest forces a reimport on every fresh checkout.
    digest = hashlib.md5(f"res://{rel}".encode()).hexdigest()
    dest = f"res://.godot/imported/{webp.name}-{digest}.ctex"
    mode = 0 if lossy_q is None else 1
    quality = 1.0 if lossy_q is None else lossy_q
    uid = _uid_for(rel, old_import)
    text = (
        "[remap]\n\n"
        'importer="texture"\n'
        'type="CompressedTexture2D"\n'
        f'uid="{uid}"\n'
        f'path="{dest}"\n'
        "metadata={\n"
        '"vram_texture": false\n'
        "}\n\n"
        "[deps]\n\n"
        f'source_file="res://{rel}"\n'
        f'dest_files=["{dest}"]\n\n'
        "[params]\n\n"
        f"compress/mode={mode}\n"
        "compress/high_quality=true\n"
        f"compress/lossy_quality={quality:.2f}\n"
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
    webp.with_name(webp.name + ".import").write_text(text, encoding="utf-8")


def _should_skip(path: Path) -> str:
    rel = path.relative_to(ART)
    parts = rel.parts
    if parts[0] in SKIP_TOP:
        return "sharp-or-inbox"
    if "glyph" in parts:
        return "glyph"
    if parts[0] == "ui" and len(parts) > 1 and parts[1] in {"v85", "v86"}:
        return "ui-chrome"
    return ""


def _prepare(path: Path) -> tuple[Image.Image, float | None, str] | None:
    """Return (image, lossy quality or None for lossless, note) or None to keep PNG."""
    rel = path.relative_to(ART)
    parts = rel.parts
    reason = _should_skip(path)
    if reason:
        return None
    im = Image.open(path)
    im.load()
    if parts[0] == "doll":
        return im.convert("RGBA"), None, "doll-lossless"
    name = path.name
    w, h = im.size
    w, h = shipping_size(w, h, parts)
    if (w, h) != im.size:
        im = im.resize((w, h), Image.Resampling.LANCZOS)
    if parts[0] == "ui" and "items" not in parts:
        if "backdrop" not in name and max(w, h) < 480:
            return None
        if any(tok in name for tok in ("banner", "chip", "frame", "hatch", "legend", "icon")):
            return None
    if parts[0] == "estates" and max(w, h) <= 256:
        return None
    keep_alpha = False
    if im.mode in {"RGBA", "LA"} or (im.mode == "P" and "transparency" in im.info):
        rgba = im.convert("RGBA")
        amin, _amax = rgba.getchannel("A").getextrema()
        keep_alpha = amin < 240
        im = rgba if keep_alpha else rgba.convert("RGB")
    else:
        im = im.convert("RGB")
    quality = shipping_quality(parts)
    note = "native-q92"
    if keep_alpha:
        note += "+alpha"
    return im, quality, note


def _convert(path_str: str) -> dict:
    path = Path(path_str)
    before = path.stat().st_size
    try:
        prepared = _prepare(path)
    except Exception as exc:  # noqa: BLE001 — keep the PNG and report
        return {"path": path_str, "status": "error", "before": before, "after": before, "error": str(exc)}
    if prepared is None:
        return {"path": path_str, "status": "skipped", "before": before, "after": before}
    im, quality, note = prepared
    dest = path.with_suffix(".webp")
    if quality is None:
        im.save(dest, "WEBP", lossless=True, quality=100, method=4)
    else:
        q = int(round(quality * 100))
        im.save(dest, "WEBP", quality=q, method=6, alpha_quality=100)
    after = dest.stat().st_size
    if after >= int(before * 0.92):
        dest.unlink(missing_ok=True)
        return {"path": path_str, "status": "skipped", "before": before, "after": before, "note": "not-smaller"}
    return {
        "path": path_str,
        "status": "converted",
        "before": before,
        "after": after,
        "quality": quality,
        "note": note,
        "webp": str(dest),
    }


def _finish(row: dict) -> None:
    if row.get("status") != "converted":
        return
    src = Path(row["path"])
    webp = Path(row["webp"])
    old_import = Path(str(src) + ".import")
    _write_import(webp, row.get("quality"), old_import)
    src.unlink(missing_ok=True)
    old_import.unlink(missing_ok=True)


def main() -> int:
    before = _measure()
    pngs = sorted(str(p) for p in ART.rglob("*.png"))
    workers = min(8, os.cpu_count() or 4)
    print(f"compress {len(pngs)} pngs with {workers} workers", flush=True)
    converted = 0
    skipped = 0
    errors = 0
    saved = 0
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for i, row in enumerate(pool.map(_convert, pngs, chunksize=8), start=1):
            if row["status"] == "converted":
                _finish(row)
                converted += 1
                saved += row["before"] - row["after"]
            elif row["status"] == "error":
                errors += 1
                print("ERR", row["path"], row.get("error"), flush=True)
            else:
                skipped += 1
            if i % 200 == 0 or i == len(pngs):
                print(f"  {i}/{len(pngs)} converted={converted} skipped={skipped} saved={saved/1024/1024:.1f}MB", flush=True)
    after = _measure()
    keys = sorted(set(before) | set(after), key=lambda k: -before.get(k, 0))
    report = {
        "converted": converted,
        "skipped": skipped,
        "errors": errors,
        "before": before,
        "after": after,
        "notes": {
            "quality": "photographs encode at WebP quality 92, native resolution",
            "portraits": "768x1024 gene plates stay full size; Godot import lossy_quality 0.92",
            "cities": "city boards stay at their master size",
            "backdrops": "1920 plates stay 1920; portrait lists use a prebuilt small tier instead of a softer encode",
            "doll": "lossless WebP; alpha overlays",
            "kept_png": "fx, tokens, terrain, banners, glyphs, small UI chrome, farm_inbox",
        },
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{'bucket':22} {'before_MB':>10} {'after_MB':>10}")
    tb = ta = 0
    for key in keys:
        b = before.get(key, 0)
        a = after.get(key, 0)
        tb += b
        ta += a
        print(f"{key:22} {b/1024/1024:10.1f} {a/1024/1024:10.1f}")
    print(f"{'TOTAL':22} {tb/1024/1024:10.1f} {ta/1024/1024:10.1f}")
    print(f"wrote {REPORT}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
