#!/usr/bin/env python3
"""Gene-bank plate index: cheap structure checks on every plate, decodes only where needed.

Every run (no decode): each stem under the bank has large/medium/small WebP
plus a .import sidecar for each, and nothing else lives there. The git blob
ids of the bank form a content index; its digest is printed so two runs can be
compared without reading pixels.

Decode (Pillow): large must be the 768x1024 master, medium and small its 2/3
and 1/2 even-size siblings, RGB(A), and not a flat frame.
  --changed  decode only plates changed since the PR merge-base (default on PRs)
  --all      decode every plate whose blob id is not in --verified-cache
             (main and nightly; the cache file is persisted by actions/cache)

Manifest coverage (bucket keys with a plate) is reported, not enforced: the
farm renders plates after the manifest grows.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import git_base  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BANK_REL = "project/assets/art/portraits/genome/bank"
BANK = ROOT / BANK_REL
MANIFEST = ROOT / "tools" / "farm_queue" / "genome_bank_v92.json"
TIERS = ("webp", "medium.webp", "small.webp")
MASTER = (768, 1024)
SCALES = {"medium.webp": 2.0 / 3.0, "small.webp": 0.5}


def _even(value: float) -> int:
    rounded = int(round(value))
    if rounded % 2:
        rounded -= 1
    return max(2, rounded)


def _git(*args: str) -> str:
    out = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True, check=False)
    return out.stdout if out.returncode == 0 else ""


def _blob_index() -> dict[str, str]:
    index: dict[str, str] = {}
    for line in _git("ls-files", "-s", "--", BANK_REL).splitlines():
        meta, _, path = line.partition("\t")
        parts = meta.split()
        if len(parts) >= 2 and path.endswith(".webp"):
            index[Path(path).name] = parts[1]
    return index


def structure() -> tuple[list[str], dict[str, set[str]]]:
    errors: list[str] = []
    stems: dict[str, set[str]] = {}
    if not BANK.is_dir():
        return [f"missing {BANK_REL}"], stems
    names = {p.name for p in BANK.iterdir() if p.is_file()}
    for name in sorted(names):
        if name.endswith(".import"):
            if name[: -len(".import")] not in names:
                errors.append(f"orphan sidecar {name}")
            continue
        stem, _, tier = name.partition(".")
        if tier not in TIERS:
            errors.append(f"unexpected file {name}")
            continue
        if f"{name}.import" not in names:
            errors.append(f"missing sidecar {name}.import")
        stems.setdefault(stem, set()).add(tier)
    for stem, tiers in sorted(stems.items()):
        missing = [t for t in TIERS if t not in tiers]
        if missing:
            errors.append(f"{stem} missing tiers {missing}")
    return errors, stems


def decode(stem: str) -> list[str]:
    from PIL import Image, ImageStat

    errors: list[str] = []
    try:
        with Image.open(BANK / f"{stem}.webp") as large:
            large.load()
            size = large.size
            if size != MASTER:
                errors.append(f"{stem}.webp is {size[0]}x{size[1]}, want {MASTER[0]}x{MASTER[1]}")
            if large.mode not in ("RGB", "RGBA"):
                errors.append(f"{stem}.webp mode {large.mode}")
            spread = ImageStat.Stat(large.convert("L")).stddev[0]
            if spread < 4.0:
                errors.append(f"{stem}.webp is a flat frame (stddev {spread:.1f})")
        for tier, scale in SCALES.items():
            want = (_even(size[0] * scale), _even(size[1] * scale))
            with Image.open(BANK / f"{stem}.{tier}") as img:
                img.load()
                if img.size != want:
                    errors.append(f"{stem}.{tier} is {img.size[0]}x{img.size[1]}, want {want[0]}x{want[1]}")
    except Exception as exc:  # noqa: BLE001 - any decode failure is a bad plate
        errors.append(f"{stem} decode failed: {exc}")
    return errors


def changed_stems() -> set[str] | None:
    base = git_base.pr_merge_base()
    if base is None:
        return None
    out = _git("diff", "--name-only", "--diff-filter=ACMRT", base, "HEAD", "--", BANK_REL)
    return {Path(p).name.split(".", 1)[0] for p in out.splitlines() if p.endswith(".webp")}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--all", action="store_true")
    mode.add_argument("--changed", action="store_true")
    ap.add_argument("--verified-cache", type=Path, default=None)
    args = ap.parse_args(argv)

    errors, stems = structure()
    blobs = _blob_index()
    digest = hashlib.sha256("\n".join(f"{k} {v}" for k, v in sorted(blobs.items())).encode()).hexdigest()
    print(f"BANK INDEX plates={len(stems)} files={len(blobs)} digest={digest[:16]}")

    if MANIFEST.is_file():
        keys = {str(r.get("bucket_key", "")) for r in json.loads(MANIFEST.read_text(encoding="utf-8")).get("buckets", [])}
        print(f"BANK COVERAGE manifest={len(keys)} with_plate={len(keys & set(stems))} plates_outside_manifest={len(set(stems) - keys)}")

    verified: set[str] = set()
    if args.verified_cache and args.verified_cache.is_file():
        verified = set(args.verified_cache.read_text(encoding="utf-8").split())

    def stem_key(stem: str) -> str:
        return ":".join(blobs.get(f"{stem}.{t}", "?") for t in TIERS)

    if args.all:
        todo = [s for s in sorted(stems) if stem_key(s) not in verified]
        label = "all"
    else:
        picked = changed_stems()
        if picked is None and not args.changed:
            print("BANK NOTE no PR merge-base; decoding nothing (use --all for a full pass)")
            picked = set()
        todo = sorted((picked or set()) & set(stems))
        label = "changed"
    print(f"BANK DECODE mode={label} plates={len(todo)} cached={len(verified)}")
    for stem in todo:
        bad = decode(stem)
        errors.extend(bad)
        if not bad:
            verified.add(stem_key(stem))

    if args.verified_cache:
        args.verified_cache.parent.mkdir(parents=True, exist_ok=True)
        args.verified_cache.write_text("\n".join(sorted(verified)) + "\n", encoding="utf-8")

    for err in errors[:50]:
        print(f"BANK ERROR {err}")
    if errors:
        print(f"BANK INDEX FAIL errors={len(errors)}")
        return 1
    print("BANK INDEX PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
