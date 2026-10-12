#!/usr/bin/env python3
"""Gate and ingest FARM-04 status overlay plates into portraits/status/.

Design (docs/art/status-portraits-v92.md): six shared RGBA overlays on a
768×1024 plate — not a face×status matrix. Missing files stay missing; this
script never invents stand-in art.

Usage:
  # Dry-run against farm output (or any inbox of PNGs named by job id / status_id)
  python3 tools/farm_queue/ingest_status_overlays.py \\
      --inbox D:/AIComics/CenturyKnights_farm/out \\
      --dry-run

  # Gate + write PASS plates into the repo (PNG master + shipping WebP)
  python3 tools/farm_queue/ingest_status_overlays.py \\
      --inbox D:/AIComics/CenturyKnights_farm/out

Alpha gate (opaque = alpha > 0.5):
  min_opaque_ratio / max_opaque_ratio / min_mean_alpha_opaque from each job's
  gate block (defaults 0.008 / 0.40 / 0.35). Style-lock colour metrics run on
  opaque pixels only; lab distance is skipped (overlays are sparse paint).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "tools" / "farm_queue" / "v92_status_overlays.json"
DEST = ROOT / "project" / "assets" / "art" / "portraits" / "status"
PROJECT = ROOT / "project"
LOCK_PATH = ROOT / "docs" / "art" / "style-lock-v89.json"
REPORT = ROOT / "docs" / "art" / "review" / "status_overlays_v92.json"
SIZE = (768, 1024)
QUALITY = 92
UID_ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"


def load_jobs() -> list[dict]:
    doc = json.loads(QUEUE.read_text(encoding="utf-8"))
    return list(doc.get("jobs", []))


def lock_check() -> dict:
    return json.loads(LOCK_PATH.read_text(encoding="utf-8"))["check"]


def find_source(inbox: Path, job: dict) -> Path | None:
    """Match farm output by job id, status_id, out_path stem, or filename_prefix."""
    status_id = str(job.get("status_id", ""))
    job_id = str(job.get("id", ""))
    out_stem = Path(str(job.get("out_path", ""))).stem
    names = []
    for key in (job_id, status_id, out_stem, f"v92_status_{status_id}"):
        if not key:
            continue
        names.extend(
            [
                f"{key}.png",
                f"{key}.webp",
                f"{key}_00001_.png",
                f"{key}_00001.png",
            ]
        )
    # also search recursively once
    for name in names:
        direct = inbox / name
        if direct.is_file():
            return direct
    if not inbox.is_dir():
        return None
    lowered = {n.lower(): n for n in names}
    for path in inbox.rglob("*"):
        if not path.is_file():
            continue
        if path.name.lower() in lowered or path.stem.lower() in {job_id.lower(), status_id.lower(), out_stem.lower()}:
            if path.suffix.lower() in {".png", ".webp"}:
                return path
    return None


def _hsv(rgb: np.ndarray):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    h = np.where(
        mx == r,
        ((g - b) / d) % 6,
        np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4),
    ) * 60.0
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-6), 0)
    return h, s, mx


def gate_plate(path: Path, job: dict, style: dict) -> tuple[bool, dict]:
    im = Image.open(path).convert("RGBA")
    if im.size != SIZE:
        return False, {"fail": f"size {im.size} want {SIZE}"}
    arr = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = arr[..., :3], arr[..., 3]
    opaque = alpha > 0.5
    opaque_ratio = float(opaque.mean())
    g = job.get("gate") or {}
    min_op = float(g.get("min_opaque_ratio", 0.008))
    max_op = float(g.get("max_opaque_ratio", 0.40))
    min_a = float(g.get("min_mean_alpha_opaque", 0.35))
    metrics = {
        "opaque_ratio": opaque_ratio,
        "mean_alpha_opaque": float(alpha[opaque].mean()) if opaque.any() else 0.0,
        "size": list(im.size),
    }
    fails: list[str] = []
    if opaque_ratio < min_op:
        fails.append("too_transparent")
    if opaque_ratio > max_op:
        fails.append("too_opaque")
    if opaque.any() and metrics["mean_alpha_opaque"] < min_a:
        fails.append("weak_paint")
    if not opaque.any():
        fails.append("empty")
        metrics["pass"] = False
        metrics["fails"] = fails
        return False, metrics

    h, s, v = _hsv(rgb)
    hm, sm, vm = h[opaque], s[opaque], v[opaque]
    n = max(1, int(opaque.sum()))
    skin = (hm < 32) & (sm > 0.10) & (sm < 0.62) & (vm > 0.30)
    ns = ~skin
    nn = max(1, int(ns.sum()))
    gold = float(((hm > 32) & (hm < 58) & (sm > 0.42) & (vm > 0.35)).sum() / n)
    parchment = float(
        ((hm > 20) & (hm < 50) & (sm > 0.12) & (sm < 0.40) & (vm > 0.55) & ns).sum() / n
    )
    warm = float(((((hm < 60) | (hm > 330)) & (sm > 0.30)) & ns).sum() / n)
    mean_sat = float(sm.mean())
    cool = float((rgb[opaque][ns][:, 2] - rgb[opaque][ns][:, 0]).mean()) if ns.any() else 0.0
    metrics.update(
        {
            "gold_ratio": gold,
            "parchment_ratio": parchment,
            "warm_ratio": warm,
            "mean_saturation": mean_sat,
            "cool_bias": cool,
        }
    )
    # Prefer per-job gate, fall back to style-lock.
    max_gold = float(g.get("max_gold_ratio", style["max_gold_ratio"]))
    max_parch = float(g.get("max_parchment_ratio", style["max_parchment_ratio"]))
    max_warm = float(g.get("max_warm_ratio", style["max_warm_ratio"]))
    max_sat = float(g.get("max_mean_saturation", style["max_mean_saturation"]))
    min_cool = float(g.get("min_cool_bias", style["min_cool_bias"]))
    if gold > max_gold:
        fails.append("gold")
    if parchment > max_parch:
        fails.append("parchment")
    if warm > max_warm:
        fails.append("warm")
    if mean_sat > max_sat:
        fails.append("saturation")
    if cool < min_cool:
        fails.append("not-cool")
    metrics["pass"] = not fails
    metrics["fails"] = fails
    return metrics["pass"], metrics


def _uid_from(path: Path) -> str:
    digest = hashlib.md5(path.as_posix().encode("utf-8")).hexdigest()
    # stable 13-char uid-ish token from md5
    chars = []
    n = int(digest[:16], 16)
    for _ in range(13):
        chars.append(UID_ALPHABET[n % len(UID_ALPHABET)])
        n //= len(UID_ALPHABET)
    return "uid://" + "".join(chars)


def write_import(webp: Path) -> None:
    rel = webp.relative_to(PROJECT).as_posix()
    digest = hashlib.md5(webp.read_bytes()).hexdigest()
    dest = f"res://.godot/imported/{webp.name}-{digest}.ctex"
    uid = _uid_from(webp)
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
        "compress/mode=0\n"  # lossless — preserve overlay alpha edges
        "compress/high_quality=true\n"
        "compress/lossy_quality=0.92\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=false\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        "roughness/src_normal=\"\"\n"
        "process/channel_remap/red=0\n"
        "process/channel_remap/green=1\n"
        "process/channel_remap/blue=2\n"
        "process/channel_remap/alpha=3\n"
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/normal_map_invert_y=false\n"
        "process/hdr_as_srgb=false\n"
        "process/hdr_clamp_exposure=false\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n"
        "svg/scale=1.0\n"
        "editor/scale_with_editor_scale=false\n"
        "editor/convert_colors_with_editor_theme=false\n"
    )
    Path(str(webp) + ".import").write_text(text, encoding="utf-8")


def write_shipping(src: Path, status_id: str) -> dict:
    DEST.mkdir(parents=True, exist_ok=True)
    png_dest = DEST / f"{status_id}.png"
    webp_dest = DEST / f"{status_id}.webp"
    im = Image.open(src).convert("RGBA")
    if im.size != SIZE:
        im = im.resize(SIZE, Image.Resampling.LANCZOS)
    im.save(png_dest, "PNG")
    im.save(webp_dest, "WEBP", quality=QUALITY, method=6, lossless=True)
    write_import(webp_dest)
    def _rel(p: Path) -> str:
        try:
            return str(p.relative_to(ROOT))
        except ValueError:
            return str(p)

    return {
        "png": _rel(png_dest),
        "webp": _rel(webp_dest),
        "bytes_png": png_dest.stat().st_size,
        "bytes_webp": webp_dest.stat().st_size,
    }


def run(inbox: Path, dry_run: bool, review_dir: Path | None) -> int:
    style = lock_check()
    jobs = load_jobs()
    report = {"jobs": [], "passed": [], "rejected": [], "missing": []}
    if review_dir is None:
        review_dir = inbox / "_status_overlay_review"
    review_dir.mkdir(parents=True, exist_ok=True)

    for job in jobs:
        status_id = str(job["status_id"])
        job_id = str(job["id"])
        src = find_source(inbox, job)
        row = {"id": job_id, "status_id": status_id, "source": None}
        if src is None:
            row["result"] = "missing"
            report["missing"].append(status_id)
            report["jobs"].append(row)
            print(f"MISSING {job_id}")
            continue
        row["source"] = str(src)
        ok, metrics = gate_plate(src, job, style)
        row["metrics"] = metrics
        if not ok:
            row["result"] = "reject"
            report["rejected"].append(status_id)
            reject_path = review_dir / f"REJECT_{status_id}{src.suffix.lower()}"
            if not dry_run:
                Image.open(src).convert("RGBA").save(reject_path)
            print(f"REJECT {job_id} fails={metrics.get('fails')} opaque={metrics.get('opaque_ratio'):.4f}")
            report["jobs"].append(row)
            continue
        row["result"] = "pass"
        report["passed"].append(status_id)
        if dry_run:
            print(f"PASS   {job_id} opaque={metrics['opaque_ratio']:.4f} (dry-run, not copied)")
        else:
            written = write_shipping(src, status_id)
            row["written"] = written
            print(f"PASS   {job_id} -> {written['webp']} opaque={metrics['opaque_ratio']:.4f}")
        report["jobs"].append(row)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    if not dry_run:
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    else:
        (review_dir / "status_overlays_dry_run.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    print(
        f"STATUS OVERLAYS passed={len(report['passed'])} "
        f"rejected={len(report['rejected'])} missing={len(report['missing'])} "
        f"total={len(jobs)}"
    )
    if len(report["passed"]) == len(jobs) and not report["rejected"] and not report["missing"]:
        print("INGEST STATUS PASS")
        return 0
    if dry_run and report["passed"] and not report["rejected"]:
        # dry-run with some missing is still useful; only fail hard on rejects
        print("DRY-RUN PARTIAL")
        return 0 if not report["rejected"] else 1
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gate+ingest status overlay plates")
    parser.add_argument("--inbox", required=True, help="farm output / inbox directory")
    parser.add_argument("--dry-run", action="store_true", help="gate only; do not write into the repo")
    parser.add_argument("--review", default="", help="reject dump directory")
    args = parser.parse_args(argv)
    inbox = Path(args.inbox)
    if not inbox.exists():
        print(f"FAIL inbox missing: {inbox}")
        return 2
    review = Path(args.review) if args.review else None
    return run(inbox, args.dry_run, review)


if __name__ == "__main__":
    sys.exit(main())
