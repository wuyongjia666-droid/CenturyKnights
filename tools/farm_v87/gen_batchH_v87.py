"""Batch H (Qwen :8322 -> Hunyuan :8327): hair MODULE sources. A featureless mannequin head wearing one hairstyle in
neutral silver-grey (front view) -> Hunyuan3D -> Blender subtracts the canonical skull -> hair_<style>.glb (genome-tinted)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import *
STY = {
    "crop": "short textured crop haircut", "swept": "swept-back undercut with a longer top", "tied": "shoulder-length hair tied in a low tail",
    "messy": "messy medium-length layered hair falling over the forehead", "long": "long straight hair falling past the shoulders with side-swept bangs",
    "pony": "high ponytail with face-framing strands", "bob": "sleek chin-length bob", "crown": "braided crown updo with loose strands",
}
b = Batch(sys.argv[1])
for sid, desc in STY.items():
    p = (STYLE + " 3D modeling reference of a single hairstyle: a smooth featureless pale grey mannequin head and neck with no facial details, "
         f"strict front view, centred, wearing a {desc} rendered in neutral light silver-grey with soft painted strand clumps, "
         "whole head and hair fully visible with generous margin, plain light grey #D9DEE3 background, no body, no shoulders, no accessories.")
    b.add("hairmod_" + sid, dict(qwen_job(p, "ck87_hairmod_" + sid, 1024, 1024, seed_of("hairmod_" + sid)), front=True))
print("jobs", b.n)
