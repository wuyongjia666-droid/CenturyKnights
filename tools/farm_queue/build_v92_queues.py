#!/usr/bin/env python3
"""Write the v9.2 farm queues from world data and the style lock.

Genome buckets stay in genome_bank_v92.json (ART-01). This script does not
render images. Re-run after world or style-lock edits, then validate.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_queue_v92 as gate  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "tools" / "farm_queue"
LOCK = json.loads((ROOT / "docs/art/style-lock-v89.json").read_text())
WORLD = json.loads((ROOT / "project/data/world_v87.json").read_text())
ATLAS = json.loads((ROOT / "project/data/atlas_v8.json").read_text())
ITEMS = json.loads((ROOT / "project/data/world_items_v87.json").read_text())["items"]
REVIEW = json.loads((ROOT / "docs/art/review/atlas_v87_ingest.json").read_text())

PREFIX = LOCK["qwen"]["prefix"]
NEGATIVE = LOCK["qwen"]["negative"]
FORBID = [str(w) for w in LOCK["anti_trope"]["forbid_in_positive"]]
THRESH = {
    "max_gold_ratio": LOCK["check"]["max_gold_ratio"],
    "max_parchment_ratio": LOCK["check"]["max_parchment_ratio"],
    "max_warm_ratio": LOCK["check"]["max_warm_ratio"],
    "max_mean_saturation": LOCK["check"]["max_mean_saturation"],
    "min_cool_bias": LOCK["check"]["min_cool_bias"],
    "max_lab_hist_distance": LOCK["check"]["max_lab_hist_distance"],
}

KIND_WORDS = {
    "village": "village",
    "town": "walled town",
    "city": "city",
    "capital": "capital",
    "port": "harbor port",
    "fortress": "fortress",
    "castle": "citadel",
}
SIZE_WORDS = {1: "small", 2: "modest", 3: "mid-sized", 4: "large", 5: "sprawling"}
ITEM_WORDS = {
    "spear": "spear",
    "blade": "short blade",
    "sword": "straight sword",
    "bow": "recurve bow",
    "staff": "scholar staff",
    "axe": "axe",
    "armor": "plated coat",
    "crossbow": "crossbow",
    "charm": "small frost-glass charm",
    "shield": "heater shield",
    "focus": "focus crystal of frosted glass",
    "lance": "lance",
}
BUILDINGS = [
    ("hall", "the house hall, ink-navy stone and a frost-glass clerestory"),
    ("barracks", "the drill yard and barracks, slate roofs and weapon racks"),
    ("market", "the covered market, frost-silver stalls and cool cloth awnings"),
    ("forge", "the cold forge, brushed-chrome hoods and frost-cyan furnace glass"),
    ("shrine", "the ancestor shrine, ice-glass lamps and a quiet stone court"),
    ("infirmary", "the infirmary, pale linen screens and frost-glass windows"),
    ("academy", "the academy, lecture desks and a slate star map"),
    ("vault", "the vault, a sealed storehouse of frosted metal doors"),
    ("embassy", "the embassy, a reception hall with eleven empty banner poles"),
]
TIERS = [
    (1, "newly raised, sparse, the same camera and foundation"),
    (2, "half grown, added wings, the same camera and foundation"),
    (3, "fully built, dense but still the same camera and foundation"),
]
GRADES = [
    (1, "a hamlet of a few slate roofs"),
    (2, "a village with a lane and a well"),
    (3, "a manor with a walled yard"),
    (4, "a holding with storehouses and a gate"),
    (5, "a wide domain of fields and a small citadel"),
]
EMOTIONS = [
    ("neutral", "a calm neutral expression"),
    ("anger", "a contained angry expression, jaw set"),
    ("sorrow", "a quiet sorrowful expression"),
    ("joy", "a small genuine smile"),
    ("resolve", "a steady resolute expression"),
]
BIOMES = [
    "fog valley",
    "river ford",
    "snow plateau",
    "marsh",
    "forge district",
    "ancestor shrine court",
    "archive hall",
    "fortress gate",
    "night camp",
    "hill road",
    "open plain",
    "mountain pass",
    "harbor quay",
    "city street at dusk-cool light",
]


def _seed(key: str) -> int:
    h = 2166136261
    for ch in key:
        h ^= ord(ch)
        h = (h * 16777619) & 0xFFFFFFFF
    return max(1, h & 0x7FFFFFFF)


def _job(kind: str, ident: str, clause: str, w: int, h: int, out_path: str, extra: dict | None = None) -> dict:
    positive = PREFIX + " " + clause
    hits = gate.forbidden_hits(positive, FORBID)
    if hits:
        raise SystemExit(f"{ident} clause hits {hits}: {clause}")
    row = {
        "id": ident,
        "kind": kind,
        "positive": positive,
        "negative": NEGATIVE,
        "seed": _seed(ident),
        "steps": 28,
        "cfg": 1.0,
        "sampler": "euler",
        "scheduler": "simple",
        "width": w,
        "height": h,
        "gate": dict(THRESH),
        "out_path": out_path,
    }
    if extra:
        row.update(extra)
    return row


def _blurbs() -> dict[str, str]:
    return {n["id"]: str(n.get("blurb", n["id"])) for n in ATLAS["nations"]}


def cities() -> list[dict]:
    blurbs = _blurbs()
    passed = {p.removeprefix("v87_city_") for p in REVIEW["passed"]}
    rejected = set(REVIEW["rejected"])
    rows = []
    for node in WORLD["nodes"]:
        nid = node["id"]
        if nid in passed:
            continue
        label = f"v87_city_{nid}"
        kind = KIND_WORDS.get(node["kind"], "settlement")
        size = SIZE_WORDS.get(int(node.get("size", 2)), "modest")
        blurb = blurbs.get(node["nation"], node["nation"])
        clause = (
            f"city vignette plate of a {size} {kind} in the {node['nation']} region, "
            f"biome {node.get('biome', 'plain')}. {blurb}. "
            "three-quarter aerial view at 35 degrees elevation, atmospheric depth toward the top, "
            "settlement centred, full-bleed painting, no people close-up, no text"
        )
        redraw = label in rejected
        rows.append(_job(
            "city", label, clause, 1280, 720,
            f"project/assets/art/atlas/cities/{label}.png",
            {"node_id": nid, "redraw": redraw, "nation": node["nation"]},
        ))
    return rows


def smiths() -> list[dict]:
    blurbs = _blurbs()
    nations = sorted({n["nation"] for n in WORLD["nodes"]})
    rows = []
    for nid in nations:
        ident = f"v87_smith_{nid}"
        clause = (
            f"interior of a {nid} smithy. {blurbs.get(nid, nid)}. "
            "cold steel light, frosted brushed-chrome tools on a slate bench, "
            "frost-cyan furnace glass, no people, no text"
        )
        rows.append(_job(
            "smith", ident, clause, 1280, 720,
            f"project/assets/art/atlas/smiths/{ident}.png",
            {"nation": nid},
        ))
    return rows


def items() -> list[dict]:
    rows = []
    for item in ITEMS:
        word = ITEM_WORDS.get(item["type"], "crafted object")
        ident = f"v87_item_{item['id']}"
        clause = (
            f"isolated object icon of a tier-{int(item['tier'])} {word} from {item['nation']}, "
            "30 degree three-quarter top-down, diagonal from bottom-left to top-right, "
            "frosted silver and ink-navy materials, plain plate background #D9DEE3, no text, no hands"
        )
        rows.append(_job(
            "item", ident, clause, 512, 512,
            f"project/assets/art/ui/items/{ident}.png",
            {"item_id": item["id"], "item_type": item["type"]},
        ))
    return rows


def scenes() -> list[dict]:
    rows = []
    for n in range(50):
        biome = BIOMES[n % len(BIOMES)]
        ident = f"v92_scene_ch{n:02d}"
        clause = (
            f"story establishing plate for main-line chapter {n}, a {biome}, "
            "cool white key light, atmospheric depth, full-bleed painting, "
            "no people close-up, no text, no letters"
        )
        rows.append(_job(
            "scene", ident, clause, 1280, 720,
            f"project/assets/art/scenes/{ident}.png",
            {"chapter": n},
        ))
    return rows


def expressions() -> list[dict]:
    """12 slots × 5 emotions. NAR-01 names the twelve companions; ids stay stable."""
    rows = []
    for i in range(1, 13):
        slot = f"c{i:02d}"
        for emo, desc in EMOTIONS:
            ident = f"v92_expr_{slot}_{emo}"
            clause = (
                f"waist-up portrait of companion slot {slot}, same face across the set, {desc}, "
                "three-quarter view facing camera-left, plain plate background #D9DEE3, "
                "unmarked skin, rounded ears, ink-navy cloth, no text"
            )
            rows.append(_job(
                "expression", ident, clause, 768, 1024,
                f"project/assets/art/portraits/expressions/{ident}.png",
                {"companion_slot": slot, "emotion": emo},
            ))
    return rows


def castle() -> list[dict]:
    rows = []
    base = (
        "castle base plate, empty frost plateau with foundation marks only, "
        "three-quarter aerial, 35 degree elevation, same camera for every layer, no people, no text"
    )
    rows.append(_job(
        "castle", "v92_castle_base", base, 1280, 720,
        "project/assets/art/castle/v92_castle_base.png",
        {"building": "base", "tier": 0},
    ))
    for bid, desc in BUILDINGS:
        for tier, growth in TIERS:
            ident = f"v92_castle_{bid}_t{tier}"
            clause = (
                f"castle layer plate of {desc}, tier {tier}: {growth}. "
                "transparent-looking surroundings kept as flat slate so layers align, no people, no text"
            )
            rows.append(_job(
                "castle", ident, clause, 1280, 720,
                f"project/assets/art/castle/{ident}.png",
                {"building": bid, "tier": tier},
            ))
    return rows


def estates() -> list[dict]:
    blurbs = _blurbs()
    nations = sorted({n["nation"] for n in WORLD["nodes"]})
    rows = []
    for nid in nations:
        for grade, desc in GRADES:
            ident = f"v92_estate_{nid}_g{grade}"
            clause = (
                f"fief plate for {nid}, grade {grade}: {desc}. {blurbs.get(nid, nid)}. "
                "three-quarter aerial, cool white key light, no people close-up, no text"
            )
            rows.append(_job(
                "estate", ident, clause, 1280, 720,
                f"project/assets/art/estates/{ident}.png",
                {"nation": nid, "grade": grade},
            ))
    return rows


def _write(name: str, kind: str, rows: list[dict], note: str) -> None:
    payload = {
        "version": "v92",
        "kind": kind,
        "note": note,
        "style_lock": "docs/art/style-lock-v89.json",
        "jobs": rows,
    }
    path = QUEUE / name
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {path.name} jobs={len(rows)}")


def main() -> int:
    _write("v92_cities.json", "city", cities(), "74 world nodes minus 39 passing plates. 8 of these are saturation redraws.")
    _write("v92_smiths.json", "smith", smiths(), "One smithy interior per nation. Runtime path is atlas/smiths/.")
    _write("v92_items.json", "item", items(), "All world_items_v87 ids. Runtime path is ui/items/v87_item_*.png.")
    _write(
        "v92_scenes.json", "scene", scenes(),
        "50 main-line establishing plates (chapters 0-49). NAR-01 binds these ids to the story bible; do not rename.",
    )
    _write(
        "v92_expressions.json", "expression", expressions(),
        "12 companion slots × 5 emotions. NAR-01 assigns the twelve names onto c01-c12. Identity must stay fixed per slot.",
    )
    _write(
        "v92_castle.json", "castle", castle(),
        "CMP-03 / FARM-05: 9 buildings × 3 tiers + one shared base plate. Same camera on every layer.",
    )
    _write(
        "v92_estates.json", "estate", estates(),
        "11 nations × 5 fief grades. Formal art waits for the farm; paths stay under assets/art/estates/.",
    )
    errors = gate.check()
    if errors:
        for err in errors[:20]:
            print("FAIL", err)
        return 1
    print("build ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
