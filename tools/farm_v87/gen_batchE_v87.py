"""Batch E (Qwen :8322): paper-doll part EDITS of each face base (reference edit -> doll_extract_v87 diff = aligned part).
Bases are uploaded as ck87_base_<bloodline>_<g>.png (copied from batch-1 outputs on the relay).
Hair/brows are rendered in NEUTRAL silver-grey so the runtime gradient map can paint any genome colour."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import *

KEEP = (" Keep EVERYTHING else pixel-identical: same person, same face, same pose, same framing, same lighting, same "
        "ink-navy undershirt, same plain light grey #D9DEE3 background. Change only what is described.")
HAIR = {
    "m": {"crop": "short textured crop", "swept": "swept-back undercut with longer top", "tied": "shoulder-length hair tied in a low tail", "messy": "messy medium-length layered hair falling over the forehead"},
    "f": {"long": "long straight hair falling past the shoulders with side-swept bangs", "pony": "high ponytail with face-framing strands", "bob": "sleek chin-length bob", "crown": "braided crown updo with loose strands"},
}
BROW = {"thick": "thick strong eyebrows", "straight": "straight level eyebrows", "arch": "elegantly arched eyebrows", "soft": "faint soft thin eyebrows"}
MARKS = {
    "ears_crest": "change only the ears: give them fine elegant pointed ear tips (subtle, not exaggerated), same skin tone.",
    "mark_crown_rime": "add only a small glowing crystal-frost birthmark pattern of fine ice-crystal lines on the left temple, pale cyan glow.",
    "mark_ember_sigil": "add only a thin faintly glowing ember vein line running under the right eye along the cheekbone.",
    "scar_cheek_l": "add only a healed thin diagonal battle scar across the left cheek.",
    "scar_brow_r": "add only a healed short vertical scar cutting through the right eyebrow.",
    "scar_chin": "add only a small healed scar on the chin.",
    "iris_mask": "change only the irises of both eyes to flat pure bright green #00FF00, nothing else.",
    "elder": "age this exact person to about 65 years old: wrinkles, slightly hollow cheeks, silver-white cropped hair; same identity.",
    "young": "make this exact person about 14 years old: younger rounder face, same identity and features.",
}
OUTFIT = {
    "squire": "light frost-chrome breastplate over an ink-navy riding jacket collar",
    "light_inf": "layered ink-navy padded technical coat with a single light shoulder guard",
    "heavy_inf": "heavy segmented frosted-chrome armour with a tall gorget",
    "hunter": "asymmetric slate hooded cloak with the hood down around the neck",
    "apprentice": "high-collared frost-white coat with luminous frost circuit lines",
    "light_cavalry": "fitted riding armour with a high split collar",
    "warrior": "broad frost-chrome pauldrons over a sleeveless armoured vest",
    "archer": "streamlined slate archer coat with a single chest plate",
    "priest": "layered frost-white and navy vestments with a crystal halo-ring collar",
}
HONOR = {"honor_frost_pin": "add only a small glowing frost-crystal pin on the collar.",
         "honor_rime_circlet": "add only a thin elegant frosted-silver circlet with a small ice crystal on the forehead.",
         "honor_crown_line": "add only a fine glowing frost tattoo line running from the left temple down the jaw."}

def edit(b, base, name, instr, seed_name=None):
    p = STYLE + " Edit image 1. " + instr + KEEP
    b.add(name, qwen_job(p, "ck87_" + name, 1024, 1024, seed_of(seed_name or name), refs=[base]))

if __name__ == "__main__":
    b = Batch(sys.argv[1])
    bloods = ["ember_noble", "river_ward", "frost_crown", "common_ash"]  # trio-critical bloodlines first
    for bl in bloods:
        for g in ("m", "f"):
            base = f"ck87_base_{bl}_{g}.png"
            for hid, desc in HAIR[g].items():
                edit(b, base, f"doll_{bl}_{g}_hair_{hid}", f"Change only the hair to {desc}, rendered in neutral light silver-grey colour.")
            for bid, desc in BROW.items():
                edit(b, base, f"doll_{bl}_{g}_brow_{bid}", f"Change only the eyebrows to {desc}, neutral grey colour.")
            for mid, instr in MARKS.items():
                edit(b, base, f"doll_{bl}_{g}_{mid}", instr[0].upper() + instr[1:])
    for g in ("m", "f"):
        base = f"ck87_base_common_ash_{g}.png"
        for job, desc in OUTFIT.items():
            edit(b, base, f"doll_outfit_{job}_t1_{g}", f"Change only the clothing to a {desc}; keep the head, hair and face untouched.")
        for hid, instr in HONOR.items():
            edit(b, base, f"doll_{hid}_{g}", instr[0].upper() + instr[1:])
    print("edit jobs", b.n)
