#!/usr/bin/env python3
"""Write tools/farm_queue/v92_story_speakers.json: one waist-up plate per
speaking supporting-cast voice in the prologue (ch0) and chapter 1 (era1_01)
that has no portrait. Ages come from project/data/cast/supporting_v92.json
and decide the band words (0-2 infant, 3-11 child, 12-15 teen, 16+ adult).

  python3 tools/farm_queue/make_story_speakers.py          # write
  python3 tools/farm_queue/make_story_speakers.py --check  # exit 1 if stale
"""
from __future__ import annotations

import json
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "docs" / "art" / "style-lock-v89.json"
CAST = ROOT / "project" / "data" / "cast" / "supporting_v92.json"
OUT = ROOT / "tools" / "farm_queue" / "v92_story_speakers.json"
CHAPTERS = ("ch0", "era1_01")
GATE = {
    "max_gold_ratio": 0.04, "max_parchment_ratio": 0.1, "max_warm_ratio": 0.22,
    "max_mean_saturation": 0.42, "min_cool_bias": -0.02, "max_lab_hist_distance": 0.62,
}


def band(age: int) -> str:
    if age <= 2:
        return "infant"
    if age <= 11:
        return "child"
    if age <= 15:
        return "teen"
    return "adult"


def band_words(age: int, sex: str) -> str:
    who = {"f": "woman", "m": "man"}[sex]
    b = band(age)
    if b == "infant":
        return "a newborn infant swaddled in cloth"
    if b == "child":
        return f"a {age}-year-old {'girl' if sex == 'f' else 'boy'} with child proportions"
    if b == "teen":
        return f"a {age}-year-old teenage {'girl' if sex == 'f' else 'boy'}"
    if age >= 60:
        return f"an elderly {who} of about {age}, deep wrinkles, grey hair"
    if age >= 45:
        return f"a middle-aged {who} of about {age}, lined face, greying hair"
    return f"an adult {who} of about {age}"


def chapter_speakers() -> list[str]:
    seen: list[str] = []

    def walk(x):
        if isinstance(x, dict):
            sp = x.get("speaker")
            if isinstance(sp, str) and sp not in seen:
                seen.append(sp)
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    for ch in CHAPTERS:
        walk(json.loads((ROOT / f"project/data/story/chapters/{ch}.json").read_text(encoding="utf-8")))
    return seen


def build() -> dict:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    q = lock["qwen"]
    people = {p["name"]: p for p in json.loads(CAST.read_text(encoding="utf-8"))["people"]}
    jobs = []
    for sp in chapter_speakers():
        p = people.get(sp)
        if p is None or "look" not in p:
            continue  # narrator, system, leader, companions: already handled elsewhere
        age, sex = int(p["age"]), str(p["sex"])
        key = str(p["cast_key"])
        pos = (
            f"{q['prefix']} waist-up portrait of {band_words(age, sex)}, {p['look']}, "
            "three-quarter view facing camera-left, eye level, head top at 10% from top, "
            "plain plate background, unmarked skin, rounded ears, ink-navy and slate cloth, no text"
        )
        jobs.append({
            "id": f"v92_speaker_{key}",
            "kind": "speaker",
            "positive": pos,
            "negative": q["negative"],
            "seed": zlib.crc32(f"ck_speaker_{key}".encode()) % 2_000_000_000 + 1,
            "steps": q["steps"], "cfg": q["cfg"], "sampler": q["sampler"], "scheduler": q["scheduler"],
            "width": 768, "height": 1024,
            "gate": dict(GATE),
            "out_path": f"project/assets/art/portraits/speakers/{key}.png",
            "speaker": sp, "cast_id": p["id"], "cast_key": key,
            "age": age, "age_band": band(age), "sex": sex,
            "edit": "full",
        })
    return {
        "version": "v92", "kind": "speaker",
        "note": "Story speakers (ch0 prologue + era1_01 chapter 1) that showed a silhouette. One plate per voice; age band from supporting_v92.json.",
        "style_lock": "docs/art/style-lock-v89.json",
        "jobs": jobs,
    }


def main() -> int:
    text = json.dumps(build(), ensure_ascii=False, indent=1) + "\n"
    if "--check" in sys.argv:
        ok = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("SPEAKER QUEUE PASS" if ok else "SPEAKER QUEUE STALE")
        return 0 if ok else 1
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} jobs={len(json.loads(text)['jobs'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
