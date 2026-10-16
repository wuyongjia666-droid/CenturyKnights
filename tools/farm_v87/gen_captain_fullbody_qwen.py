"""Captain FULL-BODY A-pose turnaround refs for Hunyuan cloud (no head-attach path).

Uses Qwen :8322 with v8_hero_leader_m as identity ref.
Generates front / three-quarter / side (+ optional front|back sheet).

Usage (on box — prepare only):
  python3 tools/farm_v87/gen_captain_fullbody_qwen.py \\
    /workspace/board_figure_p1_review/captain_v2/farm_fullbody_ref

Submit (on m173 LAN):
  powershell -File tools/farm_v87/farm.ps1 submit <batchDir>
  powershell -File tools/farm_v87/farm.ps1 watch  <batchDir>

Probe from box:
  bash tools/farm_queue/probe_farm.sh
"""
from __future__ import annotations

import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import ALLY, Batch, NEG, SHEET, STYLE, qwen_job, seed_of

# Full-body A-pose for Hunyuan (hands clear of face, portrait-faithful)
CAPTAIN_WHO = (
    "Young adult male knight-commander identical to the reference portrait: "
    "short dark side-swept tousled hair, sharp brows, pale skin, stern expression; "
    "cold-grey (#586070–#707888) high-collared long coat with clear lapels (NOT frost-white, NOT icy chrome wash), "
    "black high-collar inner shirt, thin key pendant necklace on chest, "
    "compass-star sleeve badge, fitted dark trousers, armoured boots; "
    "empty hands, no weapon, no props."
)

POSE = (
    " Full body from crown to soles, both feet fully visible with 5% margin, "
    "realistic adult proportions about 7.5 heads tall (NOT chibi, NOT doll-head), "
    "neutral A-pose, arms angled 30–40 degrees from torso, hands open and away from face and hips, "
    "legs shoulder-width, facing camera, flat even studio light, no dramatic side shadow, "
    "plain light grey #D9DEE3 background, orthographic-like camera at mid-torso height."
)

VIEWS = {
    "captain_fullbody_front": "front view, 0 degrees, facing camera.",
    "captain_fullbody_34": "three-quarter view, about 35 degrees to the right of front.",
    "captain_fullbody_side": "strict side profile view, 90 degrees, facing left of frame.",
    "captain_fullbody_back": "back view, 180 degrees, back of head and coat hem fully visible.",
}


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "/workspace/board_figure_p1_review/captain_v2/farm_fullbody_ref"
    b = Batch(root)
    refs_dir = os.path.join(root, "refs")
    portrait = os.path.join(refs_dir, "v8_hero_leader_m.png")
    if not os.path.isfile(portrait):
        # fallback: convert from project
        proj = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..",
            "..",
            "project",
            "assets",
            "art",
            "portraits",
            "v8_hero_leader_m.webp",
        )
        os.makedirs(refs_dir, exist_ok=True)
        from PIL import Image

        Image.open(proj).convert("RGB").save(portrait)
    ref_name = b.ref(portrait, "ck_captain_ref_leader_m.png")

    lead = (
        " Use the person in image 1 as the exact identity reference for face, hairstyle, "
        "hair colour, skin tone and upper outfit; keep the same man as the portrait; "
        "extend the cold-grey coat naturally to full body length. "
    )
    for name, view in VIEWS.items():
        prompt = STYLE + lead + CAPTAIN_WHO + POSE + " " + view + " " + ALLY
        # taller for single-view full body
        w, h = (1024, 1536)
        b.add(name, qwen_job(prompt, "ck_cap_" + name, w, h, seed_of("cap_" + name), refs=[ref_name], steps=30))

    # Also a two-panel FRONT|BACK sheet for multi-view Hunyuan
    sheet_prompt = (
        STYLE
        + lead
        + CAPTAIN_WHO
        + " "
        + SHEET
        + " Coat colour cold grey not frost white. "
        + ALLY
    )
    b.add(
        "captain_fullbody_turnaround_sheet",
        qwen_job(sheet_prompt, "ck_cap_turnaround", 1536, 1024, seed_of("cap_turnaround"), refs=[ref_name], steps=30),
    )
    print(f"wrote {b.n} jobs -> {root}/jobs ; ref={ref_name}")
    print("submit on m173:  powershell -File tools/farm_v87/farm.ps1 submit", root)


if __name__ == "__main__":
    main()
