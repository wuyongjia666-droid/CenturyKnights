#!/usr/bin/env python3
"""Board-figure gate (pawn-redesign-opus §6 P0 / §7.1).

P0: verify style-lock board_figure (§3.4), plate_palettes coverage, overrides skeleton,
§4.2 current baseline JSON, and existing coral / house_color locks on main.
P1: also require board_figures_v1.glb/json + data/board_figures.json mapping.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEMES = ROOT / "project/data/enemy_themes.json"
DESIGN = ROOT / "docs/design/pawn-redesign-opus.md"
STYLE = ROOT / "docs/art/style-lock-v89.json"
BASELINE = ROOT / "project/data/board_figure_baseline.json"
PALETTES = ROOT / "project/data/plate_palettes.json"
OVERRIDES = ROOT / "project/data/plate_palette_overrides.json"
PORTRAIT_BANK = ROOT / "project/scripts/art/portrait_bank.gd"
UNIT_MODEL = ROOT / "project/scripts/art/unit_model.gd"
UNIT_ART = ROOT / "project/scripts/art/unit_art.gd"
PLATE_TOOL = ROOT / "tools/art/plate_palette.py"

ALLY_H0, ALLY_H1 = 150.0, 220.0
TARGET_PLATES = 1595
# Accept partial local banks but require a real extracted set for P0.
MIN_EXTRACTED = 100

SECTION34_KEYS = ("scope", "proportion", "finish", "lineart", "palette", "key")


def _hex_to_hsv(hx: str) -> tuple[float, float, float]:
    hx = hx.strip().lstrip("#")
    r, g, b = int(hx[0:2], 16) / 255.0, int(hx[2:4], 16) / 255.0, int(hx[4:6], 16) / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    chroma = mx - mn
    if chroma < 1e-6:
        return 0.0, 0.0, mx
    if mx == r:
        h = (60.0 * ((g - b) / chroma) + 360.0) % 360.0
    elif mx == g:
        h = 60.0 * ((b - r) / chroma) + 120.0
    else:
        h = 60.0 * ((r - g) / chroma) + 240.0
    s = chroma / mx if mx > 0 else 0.0
    return h, s, mx


def _fail(msg: str) -> int:
    print(f"BOARD FIGURE GATE FAIL {msg}")
    return 1


def check_style_lock() -> str | None:
    if not STYLE.is_file():
        return f"missing {STYLE.relative_to(ROOT)}"
    data = json.loads(STYLE.read_text(encoding="utf-8"))
    bf = data.get("board_figure")
    if not isinstance(bf, dict):
        return "style-lock missing board_figure"
    for k in SECTION34_KEYS:
        if not str(bf.get(k, "")).strip():
            return f"style-lock board_figure missing §3.4 field {k}"
    if "no chibi" not in str(bf.get("proportion", "")):
        return "style-lock board_figure.proportion must forbid chibi"
    return None


def check_baseline() -> str | None:
    if not BASELINE.is_file():
        return f"missing {BASELINE.relative_to(ROOT)}"
    data = json.loads(BASELINE.read_text(encoding="utf-8"))
    desk = data.get("desktop_cell85")
    if not isinstance(desk, dict):
        return "baseline missing desktop_cell85"
    for key in (
        "head_h_px",
        "separation",
        "contour",
        "luma_span",
        "head_torso_de",
        "hair_de",
        "coat_de_ally",
        "house_de_ally",
        "id8_top3",
        "id13_head_top3",
    ):
        if key not in desk:
            return f"baseline desktop_cell85 missing {key}"
    thr = data.get("thresholds_s7_1")
    if not isinstance(thr, dict) or "contour_min" not in thr:
        return "baseline missing thresholds_s7_1"
    # Sanity: §4.2 current means should match locked numbers (±0.05).
    if abs(float(desk["head_h_px"]["mean"]) - 17.7) > 0.05:
        return "baseline head_h mean drift from §4.2"
    if abs(float(desk["separation"]["mean"]) - 0.275) > 0.01:
        return "baseline separation mean drift from §4.2"
    if abs(float(desk["contour"]["mean"]) - 0.514) > 0.01:
        return "baseline contour mean drift from §4.2"
    return None


def check_palettes() -> str | None:
    if not PLATE_TOOL.is_file():
        return f"missing {PLATE_TOOL.relative_to(ROOT)}"
    if not OVERRIDES.is_file():
        return f"missing {OVERRIDES.relative_to(ROOT)}"
    if not PALETTES.is_file():
        return f"missing {PALETTES.relative_to(ROOT)} (run tools/art/plate_palette.py)"
    data = json.loads(PALETTES.read_text(encoding="utf-8"))
    plates = data.get("plates")
    if not isinstance(plates, dict) or len(plates) < MIN_EXTRACTED:
        return f"plate_palettes too small: {0 if not isinstance(plates, dict) else len(plates)} < {MIN_EXTRACTED}"
    # Spot-check schema on a few rows.
    checked = 0
    for stem, row in plates.items():
        if not isinstance(row, dict):
            return f"bad plate row {stem}"
        for k in ("hair", "skin", "coat", "coat_dark", "style"):
            if not row.get(k):
                return f"plate {stem} missing {k}"
        if str(row.get("style")) not in (
            "crop",
            "swept",
            "tied",
            "messy",
            "long",
            "pony",
            "bob",
            "crown",
        ):
            return f"plate {stem} bad style {row.get('style')}"
        checked += 1
        if checked >= 5:
            break
    extracted = int(data.get("plate_count_extracted", len(plates)))
    available = int(data.get("plate_count_available", extracted))
    gap = int(data.get("coverage_gap", max(0, TARGET_PLATES - available)))
    if available < TARGET_PLATES and gap < (TARGET_PLATES - available):
        return "coverage_gap inconsistent"
    return None


def check_try_texture_stem() -> str | None:
    if not PORTRAIT_BANK.is_file():
        return "missing portrait_bank.gd"
    text = PORTRAIT_BANK.read_text(encoding="utf-8")
    if '-> Dictionary' not in text or '"stem"' not in text:
        return "try_texture must return Dictionary with stem"
    if "static func try_texture" not in text:
        return "try_texture missing"
    # Must document that stem is the loaded plate key.
    if "stem" not in text.lower():
        return "try_texture stem docs missing"
    return None


def check_coral_locks() -> tuple[str | None, int, int]:
    """Existing fill_color / house_color checks from #300 era."""
    if not THEMES.is_file():
        return f"missing {THEMES.relative_to(ROOT)}", 0, 0
    data = json.loads(THEMES.read_text(encoding="utf-8"))
    themes = data.get("themes", {})
    if not isinstance(themes, dict) or not themes:
        return "no themes", 0, 0
    allyish = 0
    for _tid, row in themes.items():
        if not isinstance(row, dict):
            continue
        pal = row.get("palette", {}) if isinstance(row.get("palette"), dict) else {}
        trim = str(pal.get("trim", row.get("trim", "")))
        if not trim or not trim.startswith("#"):
            continue
        h, _s, _v = _hex_to_hsv(trim)
        hx = trim.lstrip("#")
        r = int(hx[0:2], 16) / 255.0
        g_ = int(hx[2:4], 16) / 255.0
        b = int(hx[4:6], 16) / 255.0
        chroma = max(r, g_, b) - min(r, g_, b)
        if ALLY_H0 <= h <= ALLY_H1 and chroma > 0.15:
            allyish += 1
    model = UNIT_MODEL.read_text(encoding="utf-8") if UNIT_MODEL.is_file() else ""
    if "Faction cloth locked to coral" not in model and "UIKit.DANGER" not in model:
        return "fill_color_for coral lock missing", len(themes), allyish
    if "house_color" not in UNIT_ART.read_text(encoding="utf-8"):
        return "house_color missing", len(themes), allyish
    return None, len(themes), allyish



KIT_GLB = ROOT / "project/assets/models/board/board_figures_v1.glb"
KIT_MAN = ROOT / "project/assets/models/board/board_figures_v1.json"
MAP = ROOT / "project/data/board_figures.json"
BOARD_FIG_GD = ROOT / "project/scripts/art/board_figure.gd"
SHADER = ROOT / "project/shaders/board_figure.gdshader"


def check_p1_kit() -> str | None:
    if not KIT_GLB.is_file():
        return f"missing {KIT_GLB.relative_to(ROOT)}"
    if KIT_GLB.stat().st_size < 100_000:
        return "board_figures_v1.glb too small"
    if not KIT_MAN.is_file():
        return f"missing {KIT_MAN.relative_to(ROOT)}"
    man = json.loads(KIT_MAN.read_text(encoding="utf-8"))
    parts = man.get("parts", {})
    if not isinstance(parts, dict) or len(parts) < 20:
        return "manifest parts incomplete"
    for need in ("body_m", "body_f", "head_m", "outfit_captain", "outfit_hunter",
                 "outfit_bandit_bandit", "outfit_bandit_chief", "weapon_sword", "weapon_bow",
                 "hair_crop", "hair_tied"):
        if need not in parts:
            return f"manifest missing {need}"
        if need.startswith("hair_") and int(parts[need].get("tris", 99999)) > 1200:
            return f"{need} hair LOD over 1.2k tris"
    if not MAP.is_file():
        return f"missing {MAP.relative_to(ROOT)}"
    mp = json.loads(MAP.read_text(encoding="utf-8"))
    for tmpl in ("bandit_weak", "bandit", "bandit_archer", "bandit_chief"):
        if tmpl not in (mp.get("enemy_templates") or {}):
            return f"board_figures.json missing enemy template {tmpl}"
    for jid in ("captain", "hunter", "squire"):
        if jid not in (mp.get("jobs") or {}):
            return f"board_figures.json missing job {jid}"
    gd = BOARD_FIG_GD.read_text(encoding="utf-8") if BOARD_FIG_GD.is_file() else ""
    if "farm_cast" in gd and "_assemble_farm_cast" in gd:
        return "CKBoardFigure still has farm_cast formal assemble path"
    if "appearance_hash" not in gd or "spec_for" not in gd:
        return "CKBoardFigure missing appearance_hash/spec_for"
    if not SHADER.is_file():
        return "missing board_figure.gdshader"
    sh = SHADER.read_text(encoding="utf-8")
    if "palette[20]" not in sh and "palette[" not in sh:
        return "shader missing palette[20]"
    if "board_compact" in sh:
        return "formal shader must not use board_compact"
    # Budget bump present
    ratchet = json.loads((ROOT / "tools/ci/ratchet.json").read_text(encoding="utf-8"))
    if int(ratchet.get("export_base_budget_bytes", 0)) < 296000000:
        return "export_base_budget_bytes should include P1 +3MB"
    return None


def main() -> int:
    if not DESIGN.is_file():
        return _fail(f"missing {DESIGN.relative_to(ROOT)}")

    for checker in (check_style_lock, check_baseline, check_palettes, check_try_texture_stem, check_p1_kit):
        err = checker()
        if err:
            return _fail(err)

    coral_err, n_themes, allyish = check_coral_locks()
    if coral_err:
        return _fail(coral_err)

    pal = json.loads(PALETTES.read_text(encoding="utf-8"))
    n_plat = len(pal.get("plates", {}))
    gap = int(pal.get("coverage_gap", 0))
    needs = int(pal.get("needs_review", 0))
    print(
        "BOARD FIGURE GATE PASS "
        f"style_lock=ok baseline=§4.2 palettes={n_plat} gap={gap} needs_review={needs} "
        f"themes={n_themes} trim_would_be_allyish={allyish} try_texture_stem=ok p1_kit=ok"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
