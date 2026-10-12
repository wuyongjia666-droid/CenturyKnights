#!/usr/bin/env python3
"""Tutorial-story v2 backgrounds (docs/design/tutorial-story-v2.md §3).
Clones the locked v92 scene job (style lock, negatives, sampler, gate) and swaps only the subject.
Out paths match chapter_player stage.bg keys: project/assets/art/story_bg/<key>.png (ingest -> .webp)."""
import json, pathlib, zlib
Q = pathlib.Path(__file__).resolve().parent
base = json.loads((Q / "v92_scenes.json").read_text())
tmpl = base["jobs"][0]
lock_head = tmpl["positive"].split(" story establishing plate")[0]
TAIL = ", atmospheric depth, full-bleed painting, empty of people, no people close-up, no text, no letters"
SUBJECTS = {
    "slope": "terraced stone-quarry farm slope at dawn, unripe wheat, a thin straight smoke column rising from a distant mountain pass on the horizon",
    "memory": "dim tenant cottage interior remembered, an open ledger on a bare table with one line struck through, desaturated, soft vignette",
    "yard_night": "cottage courtyard at night, a broken banner pole with an iron ferrule leaning on a low stone wall, faint hearth glow through a doorway",
    "tree_moon": "old locust tree on a hilltop under a cold moon, a grey cloth banner spread over the roots, small clay paint jars",
    "pass_night": "narrow mountain pass at night between wet cliff walls, overturned grain carts and a wall of grain sacks, mist and a small campfire",
    "pass_day": "the same narrow mountain pass at noon, pushed-aside carts, a torn grey banner planted on a rock, a lacquered carriage far off",
    "tavern": "crowded frontier tavern by a bridgehead, a wall of wooden hiring plaques above empty benches, abacus on the counter",
    "hall": "half-ruined hilltop keep great hall, long table with many empty dusty chairs, sword scars on the pillars, a single small lamp",
    "bridge_day": "long stone land-bridge toll post by day, glass-topped tax desk, sea mist on both sides, caravans in the distance",
    "gate": "keep gatehouse in early spring, an old iron banner ring over the gate, a plain horse tethered to it",
    "gate_night": "keep gatehouse at night under moonlight, a long shadow across a half-collapsed gate, empty mountain ridge path",
    "hall_feast": "great hall set for a ceremony, two sides of a long table facing each other, an empty glass incense bowl in the center",
    "slope_winter": "the terraced quarry slope in early winter, a fresh pale boundary stake in grey soil, a small cottage with a crooked chimney",
    "bridge_night": "land-bridge waystation wall at night with a new grey banner hanging, a far tiny frost lantern moving along the bridge, no smoke on the horizon",
}
jobs = []
for key, subj in SUBJECTS.items():
    j = {k: v for k, v in tmpl.items() if k not in ("id", "positive", "out_path", "chapter")}
    j["id"] = f"story_bg_{key}"
    j["kind"] = "story_bg"
    j["positive"] = f"{lock_head} story background plate for the prologue, {subj}, cool white key light{TAIL}"
    j["seed"] = zlib.crc32(key.encode()) % 2_000_000_000 + 1
    j["out_path"] = f"project/assets/art/story_bg/{key}.png"
    j["bg_key"] = key
    jobs.append(j)
doc = {"version": "v92", "kind": "story_bg", "note": "Prologue story backgrounds (tutorial-story v2). Keys are chapter_player stage.bg keys; do not rename.",
       "style_lock": base["style_lock"], "jobs": jobs}
(Q / "v92_story_bg.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
print("story bg jobs", len(jobs))
