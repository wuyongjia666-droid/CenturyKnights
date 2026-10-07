#!/usr/bin/env python3
"""Map project/assets/art/farm_inbox/* into live UI/FX/portrait paths.
Prefer Qwen plates (qwen_*/ or *_qwen_*); fall back to SN. Run after CopyToBox.
"""
from __future__ import annotations
import shutil, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "project/assets/art/farm_inbox"
UI = ROOT / "project/assets/art/ui"
FX = ROOT / "project/assets/art/fx"
POR = ROOT / "project/assets/art/portraits"

MAP = {
    "ui_market_banner": UI / "market_banner.png",
    "ui_caravan_banner": UI / "caravan_banner.png",
    "ui_works_banner": UI / "works_banner.png",
    "ui_estates_banner": UI / "estates_banner.png",
    "ui_estate_focus_grain": UI / "estate_focus_grain.png",
    "ui_estate_focus_cash": UI / "estate_focus_cash.png",
    "ui_estate_focus_fortify": UI / "estate_focus_fortify.png",
    "ui_estate_focus_triptych": UI / "estates_backdrop.png",  # triptych wash
    "ui_alliance_duty": UI / "alliance_duty_chip.png",
    "ui_convoy_grain": UI / "convoy_grain.png",
    "ui_convoy_iron": UI / "convoy_iron.png",
    "ui_convoy_spice": UI / "convoy_spice.png",
    "ui_hub_banner_strip": UI / "hub_banner_strip.png",
    "ui_lineage_banner": UI / "lineage_banner.png",
    "ui_marriage_banner": UI / "marriage_banner.png",
    "hub_monthly_settle": UI / "monthly_banner.png",
    "hub_panel_chrome": UI / "hub_panel_edge.png",
    "battle_backdrop_wash": UI / "battle_backdrop.png",
    "concept_hire_plate_m": POR / "hireuniq_farm_m.png",
    "concept_hire_plate_f": POR / "hireuniq_farm_f.png",
    "fx_zoc_pulse_sheet": FX / "zoc_pulse_sheet.png",
    "fx_lock_spark_sheet": FX / "lock_spark_sheet.png",
    "fx_hit_spark_sheet": FX / "hit_spark_sheet.png",
    "fx_dmg_pop_sheet": FX / "dmg_pop_sheet.png",
    "fx_slash_sheet": FX / "slash_sheet.png",
    "fx_crit_sheet": FX / "crit_sheet.png",
    "fx_heal_sheet": FX / "heal_sheet.png",
    "fx_unlock_sheet": FX / "unlock_sheet.png",
    "fx_shield_sheet": FX / "shield_sheet.png",
    "fx_spark_sheet": FX / "spark_sheet.png",
    "portrait_leader_plate": POR / "leader_plate.png",
    "portrait_ally_dengying": POR / "ally_dengying.png",
    "portrait_tank_plate": POR / "tank_plate.png",
    "portrait_ranger_plate": POR / "ranger_plate.png",
    "portrait_mage_plate": POR / "mage_plate.png",
    "portrait_skirm_plate": POR / "skirm_plate.png",
    "concept_hire_elder": POR / "hireuniq_farm_elder.png",
    "ui_zoc_chip_lock3": UI / "zoc_chip_lock3.png",
    "ui_zoc_chip_leave2": UI / "zoc_chip_leave2.png",
    "ui_zoc_chip_zoc": UI / "zoc_chip_zoc.png",
    "ui_zoc_chip_safe": UI / "zoc_chip_safe.png",
    "ui_month_chip_grain": UI / "month_chip_grain.png",
    "ui_month_chip_silver": UI / "month_chip_silver.png",
    "ui_month_chip_morale": UI / "month_chip_morale.png",
    "ui_btn_chrome": UI / "btn_chrome.png",
    "ui_btn_accent": UI / "btn_accent_chrome.png",
    "ui_transition_rule": UI / "transition_rule.png",
    "hub_nav_hover": UI / "hub_nav_hover.png",
    "ui_ambition_strip": UI / "ambition_strip.png",
    "ui_lock_tip_banner": UI / "lock_tip_banner.png",
    "ui_lock_tip_step0": UI / "lock_tip_step0.png",
    "ui_lock_tip_step1": UI / "lock_tip_step1.png",
    "ui_lock_tip_step2": UI / "lock_tip_step2.png",
    "ui_patrol_icon": UI / "patrol_icon.png",
    "ui_blood_bar_fill": UI / "blood_bar_fill.png",
    "fx_crit_bloom_sheet": FX / "crit_bloom_sheet.png",
    "fx_move_dust_sheet": FX / "move_dust_sheet.png",
    "fx_turn_flash_sheet": FX / "turn_flash_sheet.png",
    "portrait_hire_youth_m": POR / "hireuniq_farm_youth_m.png",
    "portrait_hire_youth_f": POR / "hireuniq_farm_youth_f.png",
    "portrait_hire_veteran": POR / "hireuniq_farm_veteran.png",
    "portrait_hire_scholar": POR / "hireuniq_farm_scholar.png",
    "ui_month_chip_blood": UI / "month_chip_blood.png",
    "ui_month_chip_marriage": UI / "month_chip_marriage.png",
    "ui_month_chip_ambition": UI / "month_chip_ambition.png",
    "ui_trait_chip": UI / "trait_chip.png",
    "hub_panel_chrome_v2": UI / "hub_panel_edge.png",
    "battle_grid_select_wash": FX / "select_wash.png",
    "ui_caravan_escort_chip": UI / "caravan_escort_chip.png",
    "lineage_tree_node": UI / "lineage_tree_node.png",
    "castle_crest_plate": UI / "castle_crest_plate.png",
    "fx_blood_splash_sheet": FX / "blood_splash_sheet.png",
    "fx_block_parry_sheet": FX / "block_parry_sheet.png",
    "fx_levelup_sheet": FX / "levelup_sheet.png",
    "fx_heal_aura_sheet": FX / "heal_aura_sheet.png",
    "ui_deploy_banner": UI / "deploy_banner.png",
    "ui_roster_banner": UI / "roster_banner.png",
    "ui_train_banner": UI / "train_banner.png",
    "ui_tavern_banner": UI / "tavern_banner.png",
    "ui_shrine_banner": UI / "shrine_banner.png",
    "ui_quests_banner": UI / "quests_banner.png",
    "portrait_hire_merchant": POR / "hireuniq_farm_merchant.png",
    "portrait_hire_guard": POR / "hireuniq_farm_guard.png",
    "portrait_hire_huntress": POR / "hireuniq_farm_huntress.png",
    "portrait_hire_monk": POR / "hireuniq_farm_monk.png",
    "portrait_hire_child_m": POR / "hireuniq_farm_child_m.png",
    "portrait_hire_child_f": POR / "hireuniq_farm_child_f.png",
    "ui_hourglass_chip": UI / "hourglass_chip.png",
    "ui_save_chip": UI / "save_chip.png",
    "ui_settings_gear": UI / "settings_gear.png",
    "battle_grid_attack_wash": FX / "attack_wash.png",
    "ui_skill_node_lit": UI / "skill_node_lit.png",
    "ui_skill_node_dim": UI / "skill_node_dim.png",
    "ui_marriage_vow_seal": UI / "marriage_vow_seal.png",
    "ui_estate_raid_warn": UI / "estate_raid_warn.png",



}

def _label_of(stem: str) -> str | None:
    s = stem
    # strip engine prefixes/suffixes
    s = re.sub(r"^(qwen_|sn_|sn_local_)", "", s)
    s = re.sub(r"_(qwen|sn|sn_local).*$", "", s)
    if s in MAP:
        return s
    for k in MAP:
        if s.startswith(k) or k in s:
            return k
    return None

def _prefer_rank(path: Path) -> int:
    n = path.name.lower()
    if "qwen" in n or path.parent.name == "qwen":
        return 0
    if "sn" in n:
        return 2
    return 1

def main() -> int:
    if not INBOX.exists():
        print("no inbox", INBOX); return 1
    files = list(INBOX.rglob("*.png")) + list(INBOX.rglob("*.webp"))
    if not files:
        print("inbox empty — drop farm plates then re-run"); return 2
    # prefer Qwen when both engines present for same label
    best: dict[str, Path] = {}
    for f in files:
        lab = _label_of(f.stem)
        if lab is None:
            print("skip unmapped", f.relative_to(INBOX)); continue
        cur = best.get(lab)
        if cur is None or _prefer_rank(f) < _prefer_rank(cur):
            best[lab] = f
    n = 0
    for lab, f in sorted(best.items()):
        dest = MAP[lab]
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dest)
        print("INGEST", f.relative_to(INBOX), "->", dest.relative_to(ROOT))
        n += 1
        if lab.endswith("_sheet"):
            print("  NOTE: sheet kept whole; slice frames in Godot or extend this script")
    print(f"done {n} files (prefer Qwen). Re-import / run CI.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
