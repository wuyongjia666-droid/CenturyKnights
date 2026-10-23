#!/usr/bin/env python3
"""Write tools/farm_queue/v92_y1a_gap_speakers.json: the nine story speakers
that #335 found missing on both desktop and Android (no plate on either side).

Four supporting stubs (xinyu/ahe/hutie/shouhuo) + five v9.2 villains
(zhexian/lanzhi/jixun/qianzhan/guheng). Looks/ages live in supporting_v92.json
and antagonists_v92.json; this script only rebuilds the farm queue.

  python3 tools/farm_queue/make_y1a_gap_speakers.py          # write
  python3 tools/farm_queue/make_y1a_gap_speakers.py --check  # exit 1 if stale
"""
from __future__ import annotations

import json
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "docs" / "art" / "style-lock-v89.json"
SUPPORTING = ROOT / "project" / "data" / "cast" / "supporting_v92.json"
ANTAGONISTS = ROOT / "project" / "data" / "cast" / "antagonists_v92.json"
OUT = ROOT / "tools" / "farm_queue" / "v92_y1a_gap_speakers.json"

# Fixed set from docs/design/y1a-mobile-audit-2026-10.md / PR #335 gap list.
GAP_KEYS = (
    "xinyu", "ahe", "hutie", "shouhuo",
    "zhexian", "lanzhi", "jixun", "qianzhan", "guheng",
)

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


def people_by_key() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for path in (SUPPORTING, ANTAGONISTS):
        for row in json.loads(path.read_text(encoding="utf-8")).get("people", []):
            key = str(row.get("cast_key", ""))
            if key:
                out[key] = row
    return out


def build() -> dict:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    q = lock["qwen"]
    people = people_by_key()
    jobs = []
    missing = []
    for key in GAP_KEYS:
        p = people.get(key)
        if p is None or "look" not in p or "age" not in p or "sex" not in p:
            missing.append(key)
            continue
        age, sex = int(p["age"]), str(p["sex"])
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
            "speaker": str(p.get("name", key)), "cast_id": str(p.get("id", "")), "cast_key": key,
            "age": age, "age_band": band(age), "sex": sex,
            "edit": "full",
        })
    if missing:
        raise SystemExit(f"cast gaps missing age/sex/look: {missing}")
    return {
        "version": "v92", "kind": "speaker",
        "note": "Y1-A #335 gap: nine story speakers with no art on desktop or Android. Supporting stubs + v9.2 villains.",
        "style_lock": "docs/art/style-lock-v89.json",
        "jobs": jobs,
    }


def main() -> int:
    text = json.dumps(build(), ensure_ascii=False, indent=1) + "\n"
    if "--check" in sys.argv:
        ok = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("Y1A GAP SPEAKER QUEUE PASS" if ok else "Y1A GAP SPEAKER QUEUE STALE")
        return 0 if ok else 1
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} jobs={len(json.loads(text)['jobs'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
