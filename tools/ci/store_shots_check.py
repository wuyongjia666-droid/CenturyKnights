#!/usr/bin/env python3
"""Store listing screenshots gate (五张横屏 ≥1080p) — no upload, no CAP H/I.

Validates a shots manifest + PNG files against docs/store/screenshots-checklist.md
and cross-checks listing-copy-zh.md selling-point keywords.

Env:
  CK_STORE_SHOTS=0  → print STORE SHOTS SKIP and exit 0 (CI runners without frames).
  Default (unset/1): require real shots; FAIL if missing/wrong size.

Also supports --write-manifest-from OUT to rebuild docs/store/shots-manifest.json
(with sha256 / WxH) after a local capture.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_IDS = [
    "01_castle_hub",
    "02_battle",
    "03_genealogy",
    "04_cs_dialogue",
    "05_month_echo",
]

# Align with docs/store/screenshots-checklist.md ↔ listing-copy-zh.md 五条卖点.
LISTING_KEYWORDS = {
    "01_castle_hub": ["百年", "王朝", "城堡", "枢纽", "主城"],
    "02_battle": ["战棋", "策略", "对战", "战斗"],
    "03_genealogy": ["血脉", "族谱", "联姻", "传代", "嗣"],
    "04_cs_dialogue": ["内容季", "叙事", "可玩章", "旗", "灯"],
    "05_month_echo": ["月回响", "产业", "属地", "收成", "经营"],
}

MIN_SHORT = 1080
DEFAULT_MANIFEST = ROOT / "docs" / "store" / "shots-manifest.json"
DEFAULT_SHOT_DIRS = [
    ROOT / "docs" / "store" / "shots",
    Path("/tmp/ck-store-shots"),
]


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _png_size(path: Path) -> tuple[int, int]:
    """Read IHDR without full decode; fall back to Pillow."""
    data = path.read_bytes()
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
        w = int.from_bytes(data[16:20], "big")
        h = int.from_bytes(data[20:24], "big")
        return w, h
    try:
        from PIL import Image

        im = Image.open(path)
        return int(im.size[0]), int(im.size[1])
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(f"cannot read PNG size {path}: {exc}") from exc


def _find_shot(fname: str, search_dirs: list[Path]) -> Path | None:
    for d in search_dirs:
        p = d / fname
        if p.is_file():
            return p
    return None


def write_manifest_from(out_dir: Path, dest: Path) -> int:
    raw = out_dir / "manifest.json"
    if not raw.is_file():
        print(f"FAIL missing capture manifest {raw}")
        return 1
    data = json.loads(raw.read_text(encoding="utf-8"))
    shots_out = []
    for row in data.get("shots", []):
        fname = str(row.get("file", ""))
        path = out_dir / fname
        if not path.is_file():
            print(f"FAIL missing png {path}")
            return 1
        w, h = _png_size(path)
        shots_out.append(
            {
                "id": row.get("id"),
                "file": fname,
                "width": w,
                "height": h,
                "sha256": _sha256(path),
                "scene": row.get("scene", ""),
                "listing_bullet": next(
                    (
                        b.get("bullet")
                        for b in data.get("listing_bullets", [])
                        if b.get("id") == row.get("id")
                    ),
                    "",
                ),
                "selling_point_zh": next(
                    (
                        b.get("selling_point_zh")
                        for b in data.get("listing_bullets", [])
                        if b.get("id") == row.get("id")
                    ),
                    "",
                ),
            }
        )
    payload = {
        "version": 1,
        "generated_by": "tools/ci/store_shots_check.py --write-manifest-from",
        "capture_suite": "res://tests/suites/store/store_listing_shots.tscn",
        "capture_script": "scripts/capture_store_shots.sh",
        "min_short_side": MIN_SHORT,
        "landscape_required": True,
        "note_zh": "PNG 本体 gitignore（docs/store/shots/ 或 /tmp/ck-store-shots）；本清单入库供门禁与工程自检。",
        "shots": shots_out,
        "listing_copy": "docs/store/listing-copy-zh.md",
        "checklist": "docs/store/screenshots-checklist.md",
    }
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"STORE SHOTS MANIFEST WROTE {dest} count={len(shots_out)}")
    return 0


def check_listing_alignment(fails: list[str]) -> None:
    listing = ROOT / "docs" / "store" / "listing-copy-zh.md"
    if not listing.is_file():
        fails.append("missing docs/store/listing-copy-zh.md")
        return
    body = listing.read_text(encoding="utf-8")
    # At least one keyword per selling-point bucket must appear in listing copy.
    for shot_id, keys in LISTING_KEYWORDS.items():
        if not any(k in body for k in keys):
            fails.append(
                f"listing-copy-zh.md missing keywords for {shot_id} (need one of {keys})"
            )


def _allow_missing_files() -> bool:
    """CI runners / explicit skip: validate manifest schema without local PNG blobs."""
    if os.environ.get("CK_STORE_SHOTS", "1") == "0":
        return True
    if os.environ.get("CK_STORE_SHOTS_MANIFEST_ONLY", "") == "1":
        return True
    # GitHub Actions shots job may not have store frames; schema still gated.
    if os.environ.get("GITHUB_ACTIONS", "").lower() in ("1", "true"):
        return True
    return False


def check_shots(manifest_path: Path, search_dirs: list[Path], fails: list[str]) -> None:
    if not manifest_path.is_file():
        try:
            rel = manifest_path.relative_to(ROOT)
        except ValueError:
            rel = manifest_path
        fails.append(f"missing manifest {rel}")
        return
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    shots = data.get("shots") or []
    by_id = {str(s.get("id")): s for s in shots}
    allow_missing = _allow_missing_files()
    found_any = False
    for rid in REQUIRED_IDS:
        if rid not in by_id:
            fails.append(f"manifest missing shot id {rid}")
            continue
        row = by_id[rid]
        fname = str(row.get("file", ""))
        if not fname:
            fails.append(f"{rid} missing file")
            continue
        mw = int(row.get("width") or 0)
        mh = int(row.get("height") or 0)
        msha = str(row.get("sha256") or "")
        if mw < 1 or mh < 1:
            fails.append(f"{rid} manifest missing width/height")
            continue
        if min(mw, mh) < MIN_SHORT:
            fails.append(f"{rid} manifest short side {min(mw, mh)} < {MIN_SHORT}")
        if mw < mh:
            fails.append(f"{rid} manifest not landscape ({mw}x{mh})")
        if len(msha) != 64:
            fails.append(f"{rid} manifest sha256 missing/short")
        path = _find_shot(fname, search_dirs)
        if path is None:
            if allow_missing:
                print(f"STORE SHOT SCHEMA {rid} declared {mw}x{mh} (png absent; CI/skip ok)")
                continue
            fails.append(
                f"{rid} png not found ({fname}); searched "
                + ", ".join(str(d) for d in search_dirs)
                + " — run: bash scripts/capture_store_shots.sh"
            )
            continue
        found_any = True
        w, h = _png_size(path)
        short = min(w, h)
        if short < MIN_SHORT:
            fails.append(f"{rid} short side {short} < {MIN_SHORT} ({w}x{h})")
        if w < h:
            fails.append(f"{rid} not landscape ({w}x{h})")
        if mw and mh and (mw != w or mh != h):
            fails.append(f"{rid} size mismatch file={w}x{h} manifest={mw}x{mh}")
        digest = _sha256(path)
        if msha and msha != digest:
            fails.append(f"{rid} sha256 mismatch")
        print(f"STORE SHOT OK {rid} {w}x{h} sha256={digest[:12]}… file={path}")
    if found_any:
        print("STORE SHOTS files-verified=1")
    elif allow_missing:
        print("STORE SHOTS files-verified=0 schema-only=1")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="committed shots-manifest.json path",
    )
    ap.add_argument(
        "--shots-dir",
        action="append",
        default=[],
        help="extra directory to search for PNGs (repeatable)",
    )
    ap.add_argument(
        "--write-manifest-from",
        type=Path,
        default=None,
        help="rebuild committed manifest from a capture OUT dir",
    )
    args = ap.parse_args(argv)

    if args.write_manifest_from is not None:
        return write_manifest_from(args.write_manifest_from, args.manifest)

    if os.environ.get("CK_STORE_SHOTS", "1") == "0":
        print("STORE SHOTS SKIP CK_STORE_SHOTS=0")
        return 0

    fails: list[str] = []
    # Suite + script must exist (engineering path).
    suite = ROOT / "project/tests/suites/store/store_listing_shots.tscn"
    script = ROOT / "scripts/capture_store_shots.sh"
    if not suite.is_file():
        fails.append("missing project/tests/suites/store/store_listing_shots.tscn")
    if not script.is_file():
        fails.append("missing scripts/capture_store_shots.sh")
    check_listing_alignment(fails)

    search = [Path(p) for p in args.shots_dir] + list(DEFAULT_SHOT_DIRS)
    # De-dupe preserving order
    seen: set[str] = set()
    search_dirs: list[Path] = []
    for d in search:
        key = str(d.resolve()) if d.exists() else str(d)
        if key in seen:
            continue
        seen.add(key)
        search_dirs.append(d)

    check_shots(args.manifest, search_dirs, fails)

    # Checklist doc must still mention gate keywords.
    checklist = ROOT / "docs/store/screenshots-checklist.md"
    if checklist.is_file():
        body = checklist.read_text(encoding="utf-8")
        for phrase in ("1080", "横屏", "五张", "store_shots_check", "capture_store_shots"):
            if phrase not in body:
                fails.append(f"screenshots-checklist.md missing {phrase!r}")
    else:
        fails.append("missing docs/store/screenshots-checklist.md")

    if fails:
        print("FAIL store_shots_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE SHOTS PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
