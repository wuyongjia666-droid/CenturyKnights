#!/usr/bin/env python3
"""v8.7 atlas/cities farm batch: city vignettes, smithy interiors, weapon/item icons.
Prompt = style-lock-v87.json qwen.prefix (verbatim) + subject; negative = qwen.negative (verbatim) + class-specific appendix.
Usage: gen_atlas_v87.py <batch_dir>  -> <batch_dir>/jobs/8322__<label>.json  (submit with farm.ps1 submit <batch_dir>)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import qwen_job, seed_of, Batch, _LOCK

PREFIX = _LOCK["qwen"]["prefix"]
NEG = _LOCK["qwen"]["negative"]
CAM = _LOCK["cameras"]
APPEND = {
    "city": ", people close-up, portrait, characters in foreground, map legend, ui overlay, warm sunset sky, golden roofs",
    "icon": ", multiple objects, hands, character, busy background, scene, landscape, gold trim, gilded hilt",
}

def main(out):
    shots = json.load(open(os.path.join(os.path.dirname(__file__), "..", "world", "shots_v87_atlas.json")))
    b = Batch(out)
    for s in shots:
        cam = CAM["city_plate"] if s["kind"] == "city" else CAM["weapon_icon"]
        prompt = "%s %s. Camera: %s." % (PREFIX, s["subject"], cam)
        job = qwen_job(prompt, s["label"], s["w"], s["h"], seed_of(s["label"]), steps=_LOCK["qwen"]["steps"], neg=NEG + APPEND[s["kind"]])
        b.add(s["label"], job)
    print("jobs", b.n, "->", out)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/ck_v87_atlas_batch")
