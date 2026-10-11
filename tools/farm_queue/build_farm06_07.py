#!/usr/bin/env python3
"""Write the FARM-06 / FARM-07 smoke queues.

FARM-06 is Hunyuan3D on :8327 (SaveGLB), fed by a Qwen turnaround on :8322.
FARM-07 is a few new-job tokens and busts. Neither file is shots_v92_farm.json
and neither is named v92_*.json, so submit_v92_stills.py will not pick them up.

This script does not render and does not submit. Re-run after style-lock edits,
then validate.

  python3 tools/farm_queue/build_farm06_07.py
  python3 tools/farm_queue/build_farm06_07.py --emit <batchDir> --only sheets|tokens|all
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "tools" / "farm_queue"
LOCK_PATH = ROOT / "docs" / "art" / "style-lock-v89.json"
WORLD_PATH = ROOT / "project" / "data" / "world_v87.json"
JOBS_PATH = ROOT / "project" / "data" / "jobs.json"
UNITS = ROOT / "project" / "assets" / "models" / "units"

sys.path.insert(0, str(ROOT / "tools" / "farm_queue"))
sys.path.insert(0, str(ROOT / "tools" / "farm_v87"))
import gen_qwen  # noqa: E402
import validate_queue_v92 as gate  # noqa: E402

LOCK = json.loads(LOCK_PATH.read_text())
PREFIX = str(LOCK["qwen"]["prefix"])
NEGATIVE = str(LOCK["qwen"]["negative"])
ALLY = str(LOCK["qwen"]["ally_accent"])
ENEMY = str(LOCK["qwen"]["enemy_accent"])
FORBID = [str(w) for w in LOCK["anti_trope"]["forbid_in_positive"]]
THRESH = {
    "max_gold_ratio": LOCK["check"]["max_gold_ratio"],
    "max_parchment_ratio": LOCK["check"]["max_parchment_ratio"],
    "max_warm_ratio": LOCK["check"]["max_warm_ratio"],
    "max_mean_saturation": LOCK["check"]["max_mean_saturation"],
    "min_cool_bias": LOCK["check"]["min_cool_bias"],
    "max_lab_hist_distance": LOCK["check"]["max_lab_hist_distance"],
}
TOON = LOCK["toon_3d"]
SHEET = gen_qwen.SHEET
MOUNT_SHEET = (
    "Creature turnaround reference sheet for 3D modeling: exactly two views side by side of the SAME horse — "
    "FRONT view on the left half, BACK view on the right half. Full body from the ears to the hooves, "
    "all four hooves visible, standing square, orthographic camera, flat even studio light, "
    "no cast shadow, plain uniform light grey #D9DEE3 background, no rider, no saddle weapons, no ground plane."
)
ACTIONS = ["idle", "advance", "attack", "skill", "hit", "dodge", "crit", "death"]
HUNYUAN = {
    "port": 8327,
    "ckpt": "hunyuan3d-dit-v2_fp16.safetensors",
    "resolution": 8192,
    "steps": 50,
    "cfg": 8.0,
    "sampler": "euler",
    "scheduler": "normal",
    "octree_resolution": 512,
    "num_chunks": 32000,
    "threshold": 0.6,
    "algorithm": "surface net",
}
# token_readability_v85.TEAM. Kept here so the queue stays stdlib-only.
TEAM_RGB = {"ally": [0.4, 0.95, 0.8], "enemy": [1.0, 0.45, 0.42]}
SMOKE_NATIONS = ("ashbanner", "shuoying")
NATION_CLAUSE = {
    "ashbanner": {
        "line": (
            "Stocky enemy line infantry from the ash-plains hosts, bald smooth head, "
            "broad layered charcoal technical coat, one frost-chrome pauldron, short back cape, "
            "coral-red seam stitching, wrapped forearms, heavy boots. Blocky shoulder mass, wider than the skirmisher."
        ),
        "skirmish": (
            "Lean enemy skirmisher from the ash-plains hosts, bald smooth head, "
            "hooded asymmetric charcoal coat with the hood down, one light bracer, coral-red waist binding, "
            "fitted trousers, soft boots. Narrower body than the line infantry."
        ),
    },
    "shuoying": {
        "line": (
            "Tall enemy line infantry from the northern night hosts, bald smooth head, "
            "long narrow obsidian coat to the boot tops, high closed collar, vertical frost hairline trims, "
            "coral-red collar stitch, slim armoured boots. A tall column silhouette."
        ),
        "skirmish": (
            "Wiry enemy skirmisher from the northern night hosts, bald smooth head, "
            "short indigo wrap coat ending above the knee, obsidian hood down, light frost-silver arm guard, "
            "coral-red cuff stitch, soft boots. A short broken outline next to the tall line coat."
        ),
    },
}
ARMOR = (
    {
        "job_id": "sentinel",
        "clause": (
            "A young man of average build with a bald smooth head wearing sentinel armour: "
            "heavy segmented frost-chrome plates, a tall gorget, broad shoulder plates, a wide kite-shaped back plate, "
            "ink-navy technical undersuit, armoured boots. Wide guard silhouette, empty hands."
        ),
    },
    {
        "job_id": "mage",
        "clause": (
            "A young man of average build with a bald smooth head wearing mage coat-armour: "
            "a long high-collared frost-white coat with a split front, one slate side panel, a frost circuit sash, "
            "an ink-navy undersuit, slim boots. Slim coat silhouette, empty hands."
        ),
    },
)
MOUNT_CLAUSE = (
    "A riding horse in contemporary frost kit: ink-navy technical caparison with a frost hairline trim, "
    "a frost-silver brow band and chest plate, dark mane and tail, four straight legs, no rider."
)
TOKEN_WHO = {
    "sentinel": "a sentinel in heavy frost-chrome plates and a tall gorget, wide shoulders, dark ink-navy undersuit",
    "mage": "a mage in a long frost-white split coat and a slate side panel, slim dark ink-navy figure",
    "outrider": "an outrider in a fitted riding coat with a long split tail, knee-high boots, a light frost-chrome chest plate",
}
NOT_A_NATION = {"landbridge"}


def _seed(key: str) -> int:
    h = 2166136261
    for ch in key:
        h ^= ord(ch)
        h = (h * 16777619) & 0xFFFFFFFF
    return max(1, h & 0x7FFFFFFF)


def _positive(clause: str, sheet: str, accent: str) -> str:
    parts = [PREFIX, clause]
    if sheet:
        parts.append(sheet)
    parts.append(accent)
    text = " ".join(parts)
    hits = gate.forbidden_hits(text, FORBID)
    if hits:
        raise SystemExit(f"clause hits {hits}: {clause}")
    return text


def _qwen(ident: str, positive: str, width: int, height: int, prefix: str) -> dict:
    return {
        "port": 8322,
        "positive": positive,
        "negative": NEGATIVE,
        "seed": _seed(ident),
        "steps": 28,
        "cfg": 1.0,
        "sampler": "euler",
        "scheduler": "simple",
        "width": width,
        "height": height,
        "filename_prefix": prefix,
        "gate": dict(THRESH),
    }


def _toon(side: str) -> dict:
    enemy = side == "enemy"
    return {
        "ramp": TOON["ramp"],
        "rim": "#FF7A70" if enemy else "#6ED4FF",
        "rim_power": 3.0,
        "rim_strength": 0.55,
        "outline": "inverted hull 0.006m, colour #0A0E14",
        "specular": TOON["specular"],
        "emissive_trim": "#FF7A70 x2.0" if enemy else "#6ED4FF x2.2",
    }


def _hy(ident: str, kind: str, side: str, clause: str, sheet_text: str, sheet_file: str, glb_path: str, extra: dict) -> dict:
    accent = ENEMY if side == "enemy" else ALLY
    row = {
        "id": ident,
        "card": "FARM-06",
        "kind": kind,
        "side": side,
        "clause": clause,
        "sheet_file": sheet_file,
        "glb_path": glb_path,
        "triangle_budget_max": 15000,
        "decimate": "tools/models/rig_mesh_v87.py --tris 15000",
        "actions": list(ACTIONS),
        "toon": _toon(side),
        "sheet": _qwen(ident, _positive(clause, sheet_text, accent), 1536, 1024, "ck87_" + Path(sheet_file).stem),
        "hunyuan": dict(HUNYUAN),
    }
    row["hunyuan"]["filename_prefix"] = "ck87_" + ident
    row["hunyuan"]["input_image"] = "ck87_" + ident + ".jpg"
    row.update(extra)
    return row


def shipped_outfit_jobs() -> list[str]:
    found = []
    for path in sorted(UNITS.glob("outfit_*_t1_m.glb")):
        job = path.name[len("outfit_") : -len("_t1_m.glb")]
        found.append(job)
    return found


def nation_ids() -> list[str]:
    world = json.loads(WORLD_PATH.read_text())
    ids = [key for key in world["nations"] if key not in NOT_A_NATION]
    if len(ids) != 10:
        raise SystemExit(f"expected 10 nations, got {ids}")
    return ids


def expand_armors(smoke_jobs: set[str]) -> list[str]:
    shipped = set(shipped_outfit_jobs())
    jobs = json.loads(JOBS_PATH.read_text())["jobs"]
    return [row["id"] for row in jobs if row["id"] not in shipped and row["id"] not in smoke_jobs]


def farm06_document() -> dict:
    jobs = []
    for nation in SMOKE_NATIONS:
        for role in ("line", "skirmish"):
            ident = f"hy_enemy_{nation}_{role}"
            sheet_file = f"enemy_{nation}_{role}.png"
            jobs.append(
                _hy(
                    ident,
                    "enemy_silhouette",
                    "enemy",
                    NATION_CLAUSE[nation][role],
                    SHEET,
                    sheet_file,
                    f"project/assets/models/units/enemy_{nation}_{role}.glb",
                    {"nation": nation, "role": role, "slice": "enemy_nations"},
                )
            )
    for armor in ARMOR:
        job_id = armor["job_id"]
        ident = f"hy_armor_{job_id}"
        jobs.append(
            _hy(
                ident,
                "armor",
                "ally",
                armor["clause"],
                SHEET,
                f"armor_{job_id}.png",
                f"project/assets/models/units/outfit_{job_id}_t2_m.glb",
                {"job_id": job_id, "slice": "armor"},
            )
        )
    jobs.append(
        _hy(
            "hy_mount_courser",
            "mount",
            "ally",
            MOUNT_CLAUSE,
            MOUNT_SHEET,
            "mount_courser.png",
            "project/assets/models/mounts/mount_courser.glb",
            {"slice": "mount"},
        )
    )
    smoke_armor = {row["job_id"] for row in ARMOR}
    remaining = [nation for nation in nation_ids() if nation not in SMOKE_NATIONS]
    return {
        "version": "farm06-smoke-1",
        "card": "FARM-06",
        "scope": "smoke",
        "style_lock": "docs/art/style-lock-v89.json",
        "not_in_shots_v92": True,
        "note": (
            "Smoke only: 2 nations × 2 silhouettes, plus 1 mount and 2 new-job armours (7 Hunyuan jobs). "
            "Full 10-nation batch stays in expand. Do not submit GLBs from this file, and do not merge it into shots_v92_farm.json."
        ),
        "triangle_budget_max": 15000,
        "triangle_budget_note": (
            "Hunyuan octree 512 emits a dense mesh. Decimate with rig_mesh_v87.py --tris 15000 before ingest. "
            "Low-end budget is ≤15000 triangles per GLB. rig_mesh normalises human height to 1.78m; do not use that scale as the mount's final size."
        ),
        "actions": list(ACTIONS),
        "hunyuan": dict(HUNYUAN),
        "expand": {
            "nations": remaining,
            "silhouettes_per_nation": ["line", "skirmish"],
            "armors": expand_armors(smoke_armor),
            "note": "Copy a smoke job and change id, clause, and paths. Leave these ids out until a later batch.",
        },
        "jobs": jobs,
    }


def _token_clause(who: str, team: str) -> str:
    if team == "ally":
        tint, rim = "mint (#5EE0B5)", "#5EE0B5"
    else:
        tint, rim = "coral-red (#FF7A70)", "#FF7A70"
    return (
        f"Square game token, one centred full-body dark ink-navy figure of {who}. "
        f"The figure is the darkest mass and stays readable at 48 pixels. "
        f"Calm radial field from an ink void centre to a faint {tint} edge, "
        f"thin {rim} rim light on the silhouette, no bright crystal swirl, no scenery, no text."
    )


def _bust_clause(who: str) -> str:
    return (
        "Job bust, three-quarter view facing camera-left, chest-up, eye level. "
        f"A young man who is {who}. Plain uniform light grey #D9DEE3 background, no text."
    )


def farm07_document() -> dict:
    jobs = []
    for job_id, who in TOKEN_WHO.items():
        for team in ("ally", "enemy"):
            ident = f"v8_job_{job_id}_{team}"
            accent = ALLY if team == "ally" else ENEMY
            positive = _positive(_token_clause(who, team), "", accent)
            jobs.append(
                {
                    "id": ident,
                    "card": "FARM-07",
                    "kind": "token",
                    "job_id": job_id,
                    "team": team,
                    "positive": positive,
                    "negative": NEGATIVE,
                    "seed": _seed(ident),
                    "steps": 28,
                    "cfg": 1.0,
                    "sampler": "euler",
                    "scheduler": "simple",
                    "width": 512,
                    "height": 512,
                    "filename_prefix": ident,
                    "out_path": f"project/assets/art/tokens/{ident}.png",
                    "gate": dict(THRESH),
                    "readability": {
                        "script": "tools/fx/token_readability_v85.py",
                        "glob": "v8_job_*_*.png",
                        "figure": "dark",
                        "bright_fig": False,
                        "zoom": 1.22,
                        "fig_r": 0.86,
                        "team_rgb": list(TEAM_RGB[team]),
                        "note": "Default branch: dark centred figure. light_inf and apprentice are the only bright_fig names.",
                    },
                }
            )
        bust_id = f"v8_bust_m_{job_id}"
        jobs.append(
            {
                "id": bust_id,
                "card": "FARM-07",
                "kind": "bust",
                "job_id": job_id,
                "positive": _positive(_bust_clause(who), "", ALLY),
                "negative": NEGATIVE,
                "seed": _seed(bust_id),
                "steps": 28,
                "cfg": 1.0,
                "sampler": "euler",
                "scheduler": "simple",
                "width": 512,
                "height": 640,
                "filename_prefix": bust_id,
                "out_path": f"project/assets/art/portraits/{bust_id}.png",
                "gate": dict(THRESH),
                "camera": LOCK["cameras"]["bust_hero"],
            }
        )
    return {
        "version": "farm07-smoke-1",
        "card": "FARM-07",
        "scope": "smoke",
        "style_lock": "docs/art/style-lock-v89.json",
        "not_in_shots_v92": True,
        "note": (
            "Smoke tokens and busts for sentinel, mage, and outrider. "
            "Do not append these rows to shots_v92_farm.json. "
            "After ingest, run token_readability_v85.py; it rewrites every v8_job_*_*.png."
        ),
        "readability_script": "tools/fx/token_readability_v85.py",
        "expand_jobs": expand_armors(set(TOKEN_WHO)),
        "jobs": jobs,
    }


def dumps(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def write_queues() -> tuple[Path, Path]:
    farm06 = QUEUE / "farm06_hunyuan_smoke.json"
    farm07 = QUEUE / "farm07_tokens_smoke.json"
    farm06.write_text(dumps(farm06_document()))
    farm07.write_text(dumps(farm07_document()))
    return farm06, farm07


def emit(batch: Path, only: str) -> int:
    """Write Qwen Comfy jobs for farm.ps1. Hunyuan graphs stay with gen_hunyuan_v87.py."""
    batch.mkdir(parents=True, exist_ok=True)
    jobs_dir = batch / "jobs"
    jobs_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    if only in ("all", "sheets"):
        doc = json.loads((QUEUE / "farm06_hunyuan_smoke.json").read_text())
        pending = []
        for row in doc["jobs"]:
            sheet = row["sheet"]
            graph = gen_qwen.qwen_job(
                sheet["positive"],
                sheet["filename_prefix"],
                int(sheet["width"]),
                int(sheet["height"]),
                int(sheet["seed"]),
                steps=int(sheet["steps"]),
                neg=sheet["negative"],
            )
            path = jobs_dir / f"8322__{row['id']}.json"
            path.write_text(json.dumps(graph, ensure_ascii=False))
            pending.append(
                {
                    "id": row["id"],
                    "sheet_file": row["sheet_file"],
                    "glb_path": row["glb_path"],
                    "triangle_budget_max": row["triangle_budget_max"],
                    "hunyuan": row["hunyuan"],
                }
            )
            written += 1
        (batch / "hunyuan_pending.json").write_text(dumps({"jobs": pending}))
    if only in ("all", "tokens"):
        doc = json.loads((QUEUE / "farm07_tokens_smoke.json").read_text())
        for row in doc["jobs"]:
            graph = gen_qwen.qwen_job(
                row["positive"],
                row["filename_prefix"],
                int(row["width"]),
                int(row["height"]),
                int(row["seed"]),
                steps=int(row["steps"]),
                neg=row["negative"],
            )
            path = jobs_dir / f"8322__{row['id']}.json"
            path.write_text(json.dumps(graph, ensure_ascii=False))
            written += 1
    print(f"EMIT {written} qwen jobs -> {batch}")
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Write FARM-06/07 smoke queues")
    parser.add_argument("--emit", default="", help="batch directory for farm.ps1 Qwen jobs")
    parser.add_argument("--only", choices=("all", "sheets", "tokens"), default="all")
    args = parser.parse_args(argv)
    write_queues()
    print("WROTE farm06_hunyuan_smoke.json farm07_tokens_smoke.json")
    if args.emit:
        emit(Path(args.emit), args.only)
    return 0


if __name__ == "__main__":
    sys.exit(main())
