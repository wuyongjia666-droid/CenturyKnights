#!/usr/bin/env python3
"""Dry-run the FARM-06 Hunyuan smoke queue and the FARM-07 token/bust smoke queue.

Exit 0 when both files stay inside the smoke budget and match style-lock v8.9.
Does not submit, and does not read shots_v92_farm.json.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "tools" / "farm_queue"
LOCK_PATH = ROOT / "docs" / "art" / "style-lock-v89.json"
WORLD_PATH = ROOT / "project" / "data" / "world_v87.json"
UNITS = ROOT / "project" / "assets" / "models" / "units"

sys.path.insert(0, str(QUEUE))
import validate_queue_v92 as gate  # noqa: E402

ACTIONS = ["idle", "advance", "attack", "skill", "hit", "dodge", "crit", "death"]
SMOKE_NATIONS = {"ashbanner", "shuoying"}
SMOKE_ARMOR = {"sentinel", "mage"}
SMOKE_TOKENS = {"sentinel", "mage", "outrider"}
TEAM_RGB = {"ally": [0.4, 0.95, 0.8], "enemy": [1.0, 0.45, 0.42]}
NOT_A_NATION = {"landbridge"}


def _load(path: Path) -> dict:
    return json.loads(path.read_text())


def _cfg_ok(value, expect: float) -> bool:
    try:
        return abs(float(value) - expect) < 1e-6
    except (TypeError, ValueError):
        return False


def _gate_ok(row_gate: dict, lock_gate: dict, label: str, errors: list[str]) -> None:
    if not isinstance(row_gate, dict):
        errors.append(f"{label}: gate")
        return
    for key, limit in (
        ("max_gold_ratio", lock_gate["max_gold_ratio"]),
        ("max_parchment_ratio", lock_gate["max_parchment_ratio"]),
        ("max_warm_ratio", lock_gate["max_warm_ratio"]),
        ("max_mean_saturation", lock_gate["max_mean_saturation"]),
        ("min_cool_bias", lock_gate["min_cool_bias"]),
        ("max_lab_hist_distance", lock_gate["max_lab_hist_distance"]),
    ):
        if key not in row_gate:
            errors.append(f"{label}: gate.{key}")
            return
        if key.startswith("min"):
            if float(row_gate[key]) < float(limit):
                errors.append(f"{label}: gate.{key} looser")
                return
        elif float(row_gate[key]) > float(limit):
            errors.append(f"{label}: gate.{key} looser")
            return


def _qwen_ok(row: dict, label: str, prefix: str, negative: str, forbid: list[str], lock_gate: dict, errors: list[str]) -> str:
    pos = str(row.get("positive", ""))
    if not pos.startswith(prefix):
        errors.append(f"{label}: positive missing style-lock prefix")
    if str(row.get("negative", "")) != negative:
        errors.append(f"{label}: negative mismatch")
    hits = gate.forbidden_hits(pos, forbid)
    if hits:
        errors.append(f"{label}: anti-trope {hits}")
    try:
        seed = int(row.get("seed", 0))
    except (TypeError, ValueError):
        seed = 0
    if seed <= 0:
        errors.append(f"{label}: seed")
    if int(row.get("steps", 0)) != 28:
        errors.append(f"{label}: steps")
    if not _cfg_ok(row.get("cfg"), 1.0):
        errors.append(f"{label}: cfg")
    if str(row.get("sampler", "")) != "euler" or str(row.get("scheduler", "")) != "simple":
        errors.append(f"{label}: sampler")
    _gate_ok(row.get("gate", {}), lock_gate, label, errors)
    return pos


def _shipped_outfits() -> set[str]:
    found = set()
    for path in UNITS.glob("outfit_*_t1_m.glb"):
        found.add(path.name[len("outfit_") : -len("_t1_m.glb")])
    return found


def _nations() -> list[str]:
    world = _load(WORLD_PATH)
    return [key for key in world["nations"] if key not in NOT_A_NATION]


def check_farm06(lock: dict) -> list[str]:
    errors: list[str] = []
    path = QUEUE / "farm06_hunyuan_smoke.json"
    doc = _load(path)
    prefix = str(lock["qwen"]["prefix"])
    negative = str(lock["qwen"]["negative"])
    forbid = [str(w) for w in lock["anti_trope"]["forbid_in_positive"]]
    lock_gate = lock["check"]
    if doc.get("card") != "FARM-06" or doc.get("scope") != "smoke":
        errors.append("farm06 scope")
    if doc.get("not_in_shots_v92") is not True:
        errors.append("farm06 still mixed into v92")
    if int(doc.get("triangle_budget_max", 0)) != 15000:
        errors.append("farm06 budget")
    if doc.get("actions") != ACTIONS:
        errors.append("farm06 actions")
    jobs = doc.get("jobs", [])
    if not 6 <= len(jobs) <= 12:
        errors.append(f"farm06 count {len(jobs)}")
    by_kind: dict[str, list[dict]] = {}
    seen_glb = set()
    seen_id = set()
    for row in jobs:
        ident = str(row.get("id", ""))
        if ident in seen_id or not ident.startswith("hy_"):
            errors.append(f"farm06 id {ident}")
        seen_id.add(ident)
        kind = str(row.get("kind", ""))
        by_kind.setdefault(kind, []).append(row)
        if int(row.get("triangle_budget_max", 0)) != 15000:
            errors.append(f"{ident}: tris")
        if row.get("actions") != ACTIONS:
            errors.append(f"{ident}: actions")
        glb = str(row.get("glb_path", ""))
        if glb in seen_glb:
            errors.append(f"{ident}: glb dup")
        seen_glb.add(glb)
        if kind == "mount":
            if not glb.startswith("project/assets/models/mounts/") or not glb.endswith(".glb"):
                errors.append(f"{ident}: mount path")
        elif not glb.startswith("project/assets/models/units/") or not glb.endswith(".glb"):
            errors.append(f"{ident}: unit path")
        sheet = row.get("sheet", {})
        pos = _qwen_ok(sheet, ident, prefix, negative, forbid, lock_gate, errors)
        if (int(sheet.get("width", 0)), int(sheet.get("height", 0))) != (1536, 1024):
            errors.append(f"{ident}: sheet size")
        if "FRONT view on the left half" not in pos or "BACK view on the right half" not in pos:
            errors.append(f"{ident}: turnaround")
        hy = row.get("hunyuan", {})
        if int(hy.get("port", 0)) != 8327:
            errors.append(f"{ident}: port")
        if int(hy.get("resolution", 0)) != 8192 or int(hy.get("steps", 0)) != 50:
            errors.append(f"{ident}: hunyuan sample")
        if not _cfg_ok(hy.get("cfg"), 8.0):
            errors.append(f"{ident}: hunyuan cfg")
        if int(hy.get("octree_resolution", 0)) != 512 or float(hy.get("threshold", 0)) != 0.6:
            errors.append(f"{ident}: hunyuan mesh")
        if hy.get("algorithm") != "surface net":
            errors.append(f"{ident}: algorithm")
        if hy.get("filename_prefix") != "ck87_" + ident:
            errors.append(f"{ident}: prefix")
        if hy.get("input_image") != "ck87_" + ident + ".jpg":
            errors.append(f"{ident}: input")
        toon = row.get("toon", {})
        if toon.get("ramp") != lock["toon_3d"]["ramp"] or toon.get("specular") != lock["toon_3d"]["specular"]:
            errors.append(f"{ident}: toon")
        if "0.006m" not in str(toon.get("outline", "")) or "#0A0E14" not in str(toon.get("outline", "")):
            errors.append(f"{ident}: outline")
        enemy = row.get("side") == "enemy"
        want_rim = "#FF7A70" if enemy else "#6ED4FF"
        if toon.get("rim") != want_rim:
            errors.append(f"{ident}: rim")
        if not _cfg_ok(toon.get("rim_power"), 3.0) or not _cfg_ok(toon.get("rim_strength"), 0.55):
            errors.append(f"{ident}: rim strength")
    sil = by_kind.get("enemy_silhouette", [])
    armor = by_kind.get("armor", [])
    mounts = by_kind.get("mount", [])
    if len(sil) != 4 or len(armor) != 2 or len(mounts) != 1 or len(jobs) != 7:
        errors.append(f"farm06 mix sil={len(sil)} armor={len(armor)} mount={len(mounts)}")
    nations = {}
    for row in sil:
        nations.setdefault(str(row.get("nation")), set()).add(str(row.get("role")))
        if row.get("side") != "enemy":
            errors.append(f"{row.get('id')}: side")
        if "A-pose" not in str(row.get("sheet", {}).get("positive", "")):
            errors.append(f"{row.get('id')}: pose")
    if set(nations) != SMOKE_NATIONS or any(roles != {"line", "skirmish"} for roles in nations.values()):
        errors.append(f"farm06 nations {nations}")
    armor_ids = {str(row.get("job_id")) for row in armor}
    if armor_ids != SMOKE_ARMOR:
        errors.append(f"farm06 armor {armor_ids}")
    for row in armor:
        if row.get("side") != "ally":
            errors.append(f"{row.get('id')}: ally")
        if "empty hands" not in str(row.get("clause", "")):
            errors.append(f"{row.get('id')}: hands")
    if mounts[0].get("id") != "hy_mount_courser" if mounts else True:
        errors.append("farm06 mount id")
    elif "no rider" not in str(mounts[0].get("clause", "")):
        errors.append("farm06 rider")
    expand = doc.get("expand", {})
    ten = _nations()
    if len(ten) != 10:
        errors.append(f"nations {len(ten)}")
    extra = list(expand.get("nations", []))
    if set(extra) & SMOKE_NATIONS or set(extra) | SMOKE_NATIONS != set(ten):
        errors.append("farm06 expand nations")
    if expand.get("silhouettes_per_nation") != ["line", "skirmish"]:
        errors.append("farm06 expand roles")
    shipped = _shipped_outfits()
    extra_armor = list(expand.get("armors", []))
    if set(extra_armor) & SMOKE_ARMOR or set(extra_armor) & shipped:
        errors.append("farm06 expand armor overlap")
    if len(extra_armor) < 8:
        errors.append("farm06 expand armor short")
    return errors


def check_farm07(lock: dict) -> list[str]:
    errors: list[str] = []
    path = QUEUE / "farm07_tokens_smoke.json"
    doc = _load(path)
    prefix = str(lock["qwen"]["prefix"])
    negative = str(lock["qwen"]["negative"])
    forbid = [str(w) for w in lock["anti_trope"]["forbid_in_positive"]]
    lock_gate = lock["check"]
    if doc.get("card") != "FARM-07" or doc.get("scope") != "smoke":
        errors.append("farm07 scope")
    if doc.get("not_in_shots_v92") is not True:
        errors.append("farm07 still mixed into v92")
    if doc.get("readability_script") != "tools/fx/token_readability_v85.py":
        errors.append("farm07 script")
    jobs = doc.get("jobs", [])
    if not jobs or len(jobs) > 12:
        errors.append(f"farm07 count {len(jobs)}")
    tokens: dict[str, set[str]] = {}
    busts = set()
    seen = set()
    for row in jobs:
        ident = str(row.get("id", ""))
        if ident in seen:
            errors.append(f"farm07 dup {ident}")
        seen.add(ident)
        kind = str(row.get("kind", ""))
        job_id = str(row.get("job_id", ""))
        pos = _qwen_ok(row, ident, prefix, negative, forbid, lock_gate, errors)
        out = str(row.get("out_path", ""))
        if kind == "token":
            team = str(row.get("team", ""))
            tokens.setdefault(job_id, set()).add(team)
            want = f"project/assets/art/tokens/v8_job_{job_id}_{team}.png"
            if out != want or ident != f"v8_job_{job_id}_{team}":
                errors.append(f"{ident}: token path")
            if (int(row.get("width", 0)), int(row.get("height", 0))) != (512, 512):
                errors.append(f"{ident}: token size")
            if "dark ink-navy" not in pos or "48 pixels" not in pos:
                errors.append(f"{ident}: readability prompt")
            if "crystal swirl" not in pos:
                errors.append(f"{ident}: swirl")
            read = row.get("readability", {})
            if read.get("bright_fig") is not False or read.get("figure") != "dark":
                errors.append(f"{ident}: bright_fig")
            if not _cfg_ok(read.get("zoom"), 1.22) or not _cfg_ok(read.get("fig_r"), 0.86):
                errors.append(f"{ident}: zoom")
            if read.get("team_rgb") != TEAM_RGB.get(team):
                errors.append(f"{ident}: team rgb")
            if read.get("script") != "tools/fx/token_readability_v85.py":
                errors.append(f"{ident}: script")
        elif kind == "bust":
            busts.add(job_id)
            want = f"project/assets/art/portraits/v8_bust_m_{job_id}.png"
            if out != want or ident != f"v8_bust_m_{job_id}":
                errors.append(f"{ident}: bust path")
            if (int(row.get("width", 0)), int(row.get("height", 0))) != (512, 640):
                errors.append(f"{ident}: bust size")
            if "three-quarter view facing camera-left" not in pos or "chest-up" not in pos:
                errors.append(f"{ident}: bust camera")
            if str(row.get("camera", "")) != str(lock["cameras"]["bust_hero"]):
                errors.append(f"{ident}: camera lock")
        else:
            errors.append(f"{ident}: kind {kind}")
    if set(tokens) != SMOKE_TOKENS or busts != SMOKE_TOKENS:
        errors.append(f"farm07 jobs tokens={sorted(tokens)} busts={sorted(busts)}")
    for job_id, teams in tokens.items():
        if teams != {"ally", "enemy"}:
            errors.append(f"{job_id}: teams")
    if set(doc.get("expand_jobs", [])) & SMOKE_TOKENS:
        errors.append("farm07 expand overlap")
    return errors


def check_separated() -> list[str]:
    errors: list[str] = []
    for name in ("farm06_hunyuan_smoke.json", "farm07_tokens_smoke.json"):
        if name.startswith("v92_"):
            errors.append(name)
    v92_ids = set()
    jobs, _names = gate.collect_jobs()
    for row in jobs:
        v92_ids.add(str(row.get("id") or row.get("bucket_key") or ""))
    for name in ("farm06_hunyuan_smoke.json", "farm07_tokens_smoke.json"):
        doc = _load(QUEUE / name)
        for row in doc["jobs"]:
            ident = str(row["id"])
            if ident in v92_ids:
                errors.append(f"{ident} leaked into v92")
            blob = json.dumps(row)
            if "shots_v92_farm.json" in blob:
                errors.append(f"{ident} points at v92 shots")
    shots = QUEUE / "shots_v92_farm.json"
    if shots.exists():
        errors.append("shots_v92_farm.json is in the tree")
    return errors


def check() -> list[str]:
    lock = _load(LOCK_PATH)
    errors = []
    errors.extend(check_farm06(lock))
    errors.extend(check_farm07(lock))
    errors.extend(check_separated())
    return errors


def main() -> int:
    errors = check()
    if errors:
        for err in errors[:40]:
            print("FAIL", err)
        print(f"FARM06-07 FAIL errors={len(errors)}")
        return 1
    farm06 = _load(QUEUE / "farm06_hunyuan_smoke.json")
    farm07 = _load(QUEUE / "farm07_tokens_smoke.json")
    print(f"FARM06-07 PASS hunyuan={len(farm06['jobs'])} tokens={len(farm07['jobs'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
