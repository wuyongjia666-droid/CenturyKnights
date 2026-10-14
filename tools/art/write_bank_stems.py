#!/usr/bin/env python3
"""Write project/data/art/genome_bank_stems.json: every gene-bank plate stem by age stage.

The device must not list res://assets/art/portraits/genome/bank at runtime. On Android the
bank lives in APK assets, where each listed entry costs a JNI AssetManager.list() call
(~4.8k entries) and only .import sidecars ship, so the packed index is the source of truth
in exports. Run after every bank ingest; tests/suites/art/bank_stems_index_check keeps it fresh.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "project/assets/art/portraits/genome/bank"
OUT = ROOT / "project/data/art/genome_bank_stems.json"
STAGES = ["infant", "youth", "young_adult", "middle", "elder"]


def stems() -> dict:
    out: dict = {}
    for p in BANK.iterdir():
        name = p.name
        for suf in (".import", ".remap"):
            if name.endswith(suf):
                name = name[: -len(suf)]
        low = name.lower()
        if any(t in low for t in (".small.", ".medium.", ".large.")):
            continue
        if not (low.endswith(".webp") or low.endswith(".png")):
            continue
        stem = name.rsplit(".", 1)[0]
        for st in sorted(STAGES, key=len, reverse=True):
            if stem.startswith(st + "_"):
                out.setdefault(st, set()).add(stem)
                break
    return {k: sorted(v) for k, v in sorted(out.items())}


if __name__ == "__main__":
    data = {"version": 1, "stems": stems()}
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print("wrote", OUT, {k: len(v) for k, v in data["stems"].items()})
