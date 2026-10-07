#!/usr/bin/env python3
"""Ingest qwen_v800 plates into atlas/scenes/battle/ui/portraits/tokens/fx."""
from __future__ import annotations
import json, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "project/assets/art/farm_inbox/qwen_v800"
META = ROOT / "tools/farm_queue/shots_v800_art_meta.json"
ART = ROOT / "project/assets/art"

HUB_ALIAS = {
    "menu":"menu","castle":"castle","tavern":"tavern","roster":"roster","lineage":"lineage",
    "market":"market","forge":"forge","estates":"estates","deploy":"deploy","train":"train",
    "shrine":"shrine","heir":"heir","marriage":"marriage","works":"works","quests":"quests",
    "rival":"rival","skill":"skill","hourglass":"hourglass","inheritance":"inheritance","settings":"settings",
}

def dest_for(label: str, kind: str) -> Path | None:
    if kind == "atlas":
        return ART / "atlas" / f"{label}.png"
    if kind == "scene_map":
        return ART / "scenes" / f"{label}.png"
    if kind == "battle_bg":
        return ART / "battle" / f"{label}.png"
    if kind == "hub":
        key = label.replace("v8_hub_", "")
        theme = HUB_ALIAS.get(key, key)
        return ART / "ui" / f"{theme}_backdrop.png"
    if kind == "hero":
        return ART / "portraits" / f"{label}.png"
    if kind == "bust":
        return ART / "portraits" / f"{label}.png"
    if kind == "token":
        return ART / "tokens" / f"{label}.png"
    if kind == "ui":
        # v8_ui_panel_frame -> panel_chrome / keep label
        name = label.replace("v8_ui_", "")
        special = {
            "panel_frame": "panel_chrome.png",
            "btn_primary": "btn_accent_chrome.png",
            "btn_ghost": "btn_chrome.png",
            "btn_danger": "btn_danger_chrome.png",
            "nav_rail": "hub_nav_chrome.png",
            "top_status": "hub_banner_strip.png",
            "modal_frame": "modal_chrome.png",
            "hp_bar_kit": "hp_bar_kit.png",
            "crest_blank": "crest_blank.png",
            "battle_hud_frame": "battle_hud_frame.png",
        }
        return ART / "ui" / special.get(name, f"{label}.png")
    if kind == "fx":
        return ART / "fx" / f"{label.replace('v8_fx_', '')}.png"
    return None

def main() -> int:
    meta = {r["label"]: r for r in json.loads(META.read_text())}
    if not INBOX.exists():
        print("missing inbox", INBOX); return 1
    n = 0
    for src in sorted(INBOX.glob("*.png")):
        lab = src.stem
        kind = meta.get(lab, {}).get("kind", "")
        dst = dest_for(lab, kind)
        if dst is None:
            print("skip", lab, kind); continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        n += 1
        print("INGEST", lab, "->", dst.relative_to(ROOT))
        # also keep battle plain as default battle_backdrop if biome plain
        if lab == "v8_battle_biome_plain":
            shutil.copy2(src, ART / "ui" / "battle_backdrop.png")
        if lab == "v8_hub_castle":
            shutil.copy2(src, ART / "ui" / "hub_backdrop.png")
        if lab == "v8_atlas_world":
            shutil.copy2(src, ART / "ui" / "atlas_world.png")
    print("done", n)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
