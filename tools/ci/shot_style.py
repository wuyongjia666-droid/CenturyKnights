#!/usr/bin/env python3
"""Reject capture frames whose gold or warm ratio exceeds the style lock.

Metrics come from tools/art/style_check_v87.py (the same HSV cuts as ingest).
Only gold and warm are gated here; portrait lab distance does not apply to UI frames.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCREENS = (
    "main_menu",
    "castle",
    "roster",
    "tavern",
    "marriage",
    "lineage",
    "atlas",
    "city",
    "battle",
    "cutscene",
    "settings",
    "codex",
)
RATIOS = ("1280x720", "1080x2400")


def _style():
    path = ROOT / "tools" / "art" / "style_check_v87.py"
    spec = importlib.util.spec_from_file_location("style_check_v87", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: shot_style.py OUT_DIR")
        return 2
    out = Path(sys.argv[1])
    lock = json.loads((ROOT / "docs" / "art" / "style-lock-v87.json").read_text(encoding="utf-8"))
    max_gold = float(lock["check"]["max_gold_ratio"])
    max_warm = float(lock["check"]["max_warm_ratio"])
    style = _style()
    missing = []
    fails = []
    for screen in SCREENS:
        for ratio in RATIOS:
            path = out / f"{screen}_{ratio}.png"
            if not path.is_file():
                missing.append(path.name)
                continue
            metrics, _hist = style.metrics(str(path))
            gold = float(metrics["gold_ratio"])
            warm = float(metrics["warm_ratio"])
            print(f"SHOT {path.name} gold={gold:.3f} warm={warm:.3f}")
            if gold > max_gold or warm > max_warm:
                fails.append(f"{path.name} gold={gold:.3f} warm={warm:.3f}")
    if missing or fails:
        print(f"SHOT STYLE FAIL missing={len(missing)} warm_or_gold={len(fails)}")
        for name in missing:
            print("MISSING", name)
        for line in fails:
            print("FAIL", line)
        return 1
    print(f"SHOT STYLE PASS files={len(SCREENS) * len(RATIOS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
