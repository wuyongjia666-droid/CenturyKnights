#!/usr/bin/env python3
"""Dry-run the v9.2 farm queues.

Checks style-lock prefix/negative, sampler settings, sizes, unique output paths,
anti-trope word boundaries, and the city/item/smith coverage the backlog asks for.
Also checks tools/farm_queue/genome_bank_v92.json (ART-01 buckets).

Exit 0 when every queue is clean.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "tools" / "farm_queue"
LOCK_PATH = ROOT / "docs" / "art" / "style-lock-v89.json"
WORLD = ROOT / "project" / "data" / "world_v87.json"
ITEMS = ROOT / "project" / "data" / "world_items_v87.json"
PASSED = ROOT / "docs" / "art" / "review" / "atlas_v87_ingest.json"
CAST = ROOT / "project" / "data" / "cast" / "companions_v92.json"
EXPR_EMOTIONS = {"neutral", "joy", "anger", "sorrow", "surprise"}

SIZES = {
    "city": (1280, 720),
    "smith": (1280, 720),
    "item": (512, 512),
    "scene": (1280, 720),
    "expression": (768, 1024),
    "castle": (1280, 720),
    "estate": (1280, 720),
    "genome": (768, 1024),
}


def _is_word(ch: str) -> bool:
    if not ch:
        return False
    o = ord(ch)
    return (48 <= o <= 57) or (65 <= o <= 90) or (97 <= o <= 122) or o == 95


def has_term(text: str, term: str) -> bool:
    """Same boundary rule as CKPortraitBank._has_term. 'no ' immediately before is not a hit."""
    low = text.lower()
    term = term.lower().strip()
    if not term:
        return False
    start = 0
    n = len(term)
    while True:
        i = low.find(term, start)
        if i < 0:
            return False
        before_ok = i == 0 or not _is_word(low[i - 1])
        after = i + n
        after_ok = after >= len(low) or not _is_word(low[after])
        if before_ok and after_ok:
            if i >= 3 and low[i - 3 : i] == "no ":
                start = after
                continue
            return True
        start = i + 1


def forbidden_hits(text: str, words: list[str]) -> list[str]:
    return [w for w in words if has_term(text, w)]


def _load(path: Path) -> dict:
    return json.loads(path.read_text())


def _jobs_from(doc: dict, default_kind: str) -> list[dict]:
    rows = doc.get("jobs", doc.get("buckets", []))
    kind = str(doc.get("kind", default_kind))
    out = []
    for row in rows:
        item = dict(row)
        item.setdefault("kind", kind if "buckets" not in doc else "genome")
        out.append(item)
    return out


def collect_jobs() -> tuple[list[dict], list[str]]:
    jobs: list[dict] = []
    names: list[str] = []
    for path in sorted(QUEUE.glob("v92_*.json")):
        doc = _load(path)
        jobs.extend(_jobs_from(doc, path.stem))
        names.append(path.name)
    bank = QUEUE / "genome_bank_v92.json"
    if bank.exists():
        doc = _load(bank)
        for row in doc.get("buckets", []):
            item = dict(row)
            item["kind"] = "genome"
            jobs.append(item)
        names.append(bank.name)
    return jobs, names


def _cfg_ok(value) -> bool:
    try:
        return abs(float(value) - 1.0) < 1e-6
    except (TypeError, ValueError):
        return False


def _expression_identity(expr: list[dict], forbid: list[str]) -> list[str]:
    """FARM-04 list: 12 named companions, five emotions, one seed, local redraws."""
    errors: list[str] = []
    cast = _load(CAST).get("companions", [])
    if len(cast) != 12:
        errors.append(f"cast {len(cast)}")
        return errors
    by_slot: dict[str, dict[str, dict]] = {}
    for row in expr:
        slot = str(row.get("companion_slot", ""))
        emo = str(row.get("emotion", ""))
        by_slot.setdefault(slot, {})[emo] = row
    want_slots = [f"c{i:02d}" for i in range(1, 13)]
    if sorted(by_slot) != want_slots:
        errors.append(f"expression slots {sorted(by_slot)}")
        return errors
    for i, person in enumerate(cast):
        slot = want_slots[i]
        rows = by_slot[slot]
        if set(rows) != EXPR_EMOTIONS:
            errors.append(f"{slot} emotions {sorted(rows)}")
            continue
        seeds = {int(rows[emo].get("seed", 0)) for emo in EXPR_EMOTIONS}
        if seeds != {int(rows["neutral"].get("seed", 0))} or min(seeds) <= 0:
            errors.append(f"{slot} seed")
        neutral = rows["neutral"]
        if str(neutral.get("companion_id", "")) != str(person.get("id", "")):
            errors.append(f"{slot} id")
        if str(neutral.get("companion_name", "")) != str(person.get("name", "")):
            errors.append(f"{slot} name")
        if str(neutral.get("cast_key", "")) != str(person.get("cast_key", "")):
            errors.append(f"{slot} cast_key")
        if str(neutral.get("edit", "")) != "full":
            errors.append(f"{slot} neutral edit")
        ref = str(neutral.get("out_path", ""))
        for emo, row in rows.items():
            pos = str(row.get("positive", ""))
            if "frosted glass" not in pos or "mint" not in pos or "coral" not in pos:
                errors.append(f"{slot} {emo} finish")
            hits = forbidden_hits(pos, forbid)
            if hits:
                errors.append(f"{slot} {emo} trope {hits}")
            if emo == "neutral":
                continue
            if str(row.get("edit", "")) != "local" or str(row.get("identity_ref", "")) != ref:
                errors.append(f"{slot} {emo} redraw")
            if "local redraw" not in pos:
                errors.append(f"{slot} {emo} redraw clause")
    return errors


def check() -> list[str]:
    lock = _load(LOCK_PATH)
    prefix = str(lock["qwen"]["prefix"])
    negative = str(lock["qwen"]["negative"])
    forbid = [str(w) for w in lock["anti_trope"]["forbid_in_positive"]]
    gate = lock["check"]
    errors: list[str] = []
    jobs, names = collect_jobs()
    if not names:
        return ["no queue files"]
    seen: dict[str, str] = {}
    by_kind: dict[str, list[dict]] = {}
    for row in jobs:
        kind = str(row.get("kind", ""))
        by_kind.setdefault(kind, []).append(row)
        label = str(row.get("id") or row.get("bucket_key") or row.get("out_path"))
        pos = str(row.get("positive", ""))
        if not pos.startswith(prefix):
            errors.append(f"{label}: positive missing style-lock prefix")
        if str(row.get("negative", "")) != negative:
            errors.append(f"{label}: negative mismatch")
        try:
            seed = int(row.get("seed", 0))
        except (TypeError, ValueError):
            seed = 0
        if seed <= 0:
            errors.append(f"{label}: seed")
        if int(row.get("steps", 0)) != 28:
            errors.append(f"{label}: steps")
        if not _cfg_ok(row.get("cfg")):
            errors.append(f"{label}: cfg")
        if str(row.get("sampler", "")) != "euler" or str(row.get("scheduler", "")) != "simple":
            errors.append(f"{label}: sampler")
        wh = SIZES.get(kind)
        if wh is None:
            errors.append(f"{label}: kind {kind}")
        elif (int(row.get("width", 0)), int(row.get("height", 0))) != wh:
            errors.append(f"{label}: size {row.get('width')}x{row.get('height')}")
        hits = forbidden_hits(pos, forbid)
        if hits:
            errors.append(f"{label}: anti-trope {hits}")
        # gate thresholds must be present and not looser than the lock
        row_gate = row.get("gate", gate if kind == "genome" else None)
        if kind != "genome":
            if not isinstance(row_gate, dict):
                errors.append(f"{label}: gate")
            else:
                for key, limit in (
                    ("max_gold_ratio", gate["max_gold_ratio"]),
                    ("max_parchment_ratio", gate["max_parchment_ratio"]),
                    ("max_warm_ratio", gate["max_warm_ratio"]),
                    ("max_mean_saturation", gate["max_mean_saturation"]),
                    ("min_cool_bias", gate["min_cool_bias"]),
                    ("max_lab_hist_distance", gate["max_lab_hist_distance"]),
                ):
                    if key not in row_gate:
                        errors.append(f"{label}: gate.{key}")
                        break
                    if key.startswith("min"):
                        if float(row_gate[key]) < float(limit):
                            errors.append(f"{label}: gate.{key} looser")
                            break
                    elif float(row_gate[key]) > float(limit):
                        errors.append(f"{label}: gate.{key} looser")
                        break
        path = str(row.get("out_path", ""))
        if not path.startswith("project/assets/art/") or not path.endswith(".png"):
            errors.append(f"{label}: out_path {path}")
        elif path in seen:
            errors.append(f"path conflict {path} ({seen[path]} vs {label})")
        else:
            seen[path] = label
    world = _load(WORLD)
    node_ids = [n["id"] for n in world["nodes"]]
    if len(node_ids) != 74 or len(set(node_ids)) != 74:
        errors.append(f"world nodes {len(node_ids)}")
    passed = {p.removeprefix("v87_city_") for p in _load(PASSED)["passed"]}
    if len(passed) != 39:
        errors.append(f"passed cities {len(passed)}")
    want = [i for i in node_ids if i not in passed]
    got = []
    redraw = 0
    for row in by_kind.get("city", []):
        cid = str(row.get("node_id", ""))
        got.append(cid)
        if row.get("redraw"):
            redraw += 1
    if sorted(got) != sorted(want) or len(got) != 35:
        errors.append(f"cities {len(got)} expected {len(want)}")
    if redraw != 8:
        errors.append(f"redraws {redraw}")
    nations = sorted({n["nation"] for n in world["nodes"]})
    smiths = sorted(str(r.get("nation", "")) for r in by_kind.get("smith", []))
    if smiths != nations or len(smiths) != 11:
        errors.append(f"smiths {smiths}")
    item_ids = [i["id"] for i in _load(ITEMS)["items"]]
    if len(item_ids) != 223:
        errors.append(f"item catalog {len(item_ids)}")
    queued = sorted(str(r.get("item_id", "")) for r in by_kind.get("item", []))
    if queued != sorted(item_ids):
        errors.append(f"items {len(queued)}")
    if len(by_kind.get("scene", [])) != 50:
        errors.append(f"scenes {len(by_kind.get('scene', []))}")
    expr = by_kind.get("expression", [])
    if len(expr) != 60:
        errors.append(f"expressions {len(expr)}")
    errors.extend(_expression_identity(expr, forbid))
    if len(by_kind.get("castle", [])) != 28:
        errors.append(f"castle {len(by_kind.get('castle', []))}")
    if len(by_kind.get("estate", [])) != 55:
        errors.append(f"estates {len(by_kind.get('estate', []))}")
    genome = by_kind.get("genome", [])
    if len(genome) > 6000 or len(genome) == 0:
        errors.append(f"genome buckets {len(genome)}")
    series: dict[str, set[str]] = {}
    for row in genome:
        key = str(row.get("bucket_key", ""))
        stage, _, tail = key.rpartition("_")
        series.setdefault(tail, set()).add(stage)
    bad_series = [k for k, stages in series.items() if stages != {"infant", "youth", "young_adult", "middle", "elder"}]
    if bad_series:
        errors.append(f"genome stages {len(bad_series)}")
    return errors


def main() -> int:
    errors = check()
    jobs, names = collect_jobs()
    if errors:
        for err in errors[:40]:
            print("FAIL", err)
        print(f"QUEUE FAIL errors={len(errors)} jobs={len(jobs)}")
        return 1
    print(f"QUEUE PASS files={len(names)} jobs={len(jobs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
