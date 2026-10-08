"""Batch 1 (Qwen :8322): A cast/hero turnarounds (bust-referenced), B base bodies, C job outfits (ally) + enemy
templates, D paper-doll face bases (bloodline x gender). All prompts start with the style-lock prefix."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import *
from PIL import Image
P = "/workspace/CenturyKnights/project/assets/art/portraits/"
b = Batch(sys.argv[1] if len(sys.argv) > 1 else "/workspace/farm_v87/b1")

def ref(src, name):
    im = Image.open(P + src).convert("RGB"); im.thumbnail((768, 768)); im.save(os.path.join(b.root, "inputs", name)); return name

def sheet_job(name, who, refimg=None, side="ally", extra=""):
    acc = ALLY if side == "ally" else ENEMY
    lead = (" Use the person in image 1 as the exact identity, face, hairstyle, hair colour and outfit design reference, "
            "and extend the outfit naturally to the full body. ") if refimg else " "
    p = STYLE + lead + who + " " + extra + " " + SHEET + " " + acc
    b.add(name, qwen_job(p, "ck87_" + name, 1536, 1024, seed_of(name), refs=[refimg] if refimg else ()))

# ---- A: tutorial cast + named heroes (bust-referenced)
CAST = {
    "cast_leader": ("v8_hero_leader_m.png", "Young male knight-commander of the Grey Banner house, short dark tousled hair, high-collared frost-chrome armoured coat over an ink-navy tunic, one articulated pauldron, fitted trousers and armoured boots."),
    "cast_dengying": ("v8_bust_f_hunter.png", "Young female reed-marsh hunter, long dark hair in a high ponytail with a fine frost circlet, layered pale frost-white and navy hooded wrap coat with fur-trimmed collar, fitted leggings, soft tall boots, quiver strap."),
    "cast_militia_a": ("v8_bust_m_spear.png", "Young male militia spearman, dark tousled hair with a thin frost headband, light frost-chrome shoulder guard over a long ink-navy technical coat, belt kit, boots."),
    "cast_militia_b": ("v8_bust_m_guard.png", "Young male militia shield guard, dark spiky hair with a frost headband, fur-collared slate coat over frost-chrome chest plate, bracers, boots."),
    "hero_heir_f": ("v8_hero_heir_f.png", "Young noble heiress, hair in an elegant updo with frost hairpins, high-collared frost-white long coat dress with navy panels."),
    "hero_heir_m": ("v8_hero_heir_m.png", "Young noble heir, refined high-collared navy and frost-white coat, light chest plate."),
    "hero_leader_f": ("v8_hero_leader_f.png", "Female knight-commander, frost-chrome armoured long coat, navy undersuit, armoured boots."),
    "hero_priest_f": ("v8_hero_priest_f.png", "Female frost priest, layered flowing frost-white and navy vestments with a crystal halo collar."),
    "hero_rival_m": ("v8_hero_rival_m.png", "Male rival house knight, sharp slate and frost-chrome armour coat."),
    "hero_strategist_f": ("v8_hero_strategist_f.png", "Female strategist, long tailored navy coat with frost circuit trims, gloves."),
    "hero_veteran_m": ("v8_hero_veteran_m.png", "Grizzled veteran male knight, heavy frosted-chrome armour, worn navy cloak, short grey beard."),
}
for name, (src, who) in CAST.items():
    sheet_job(name, who, ref(src, "ck87_ref_" + name + ".png"))
sheet_job("enemy_bandit_weak", "Lean male mountain-pass bandit, ragged charcoal hooded technical jacket, cracked half-face mask with coral-red visor slit, wrapped forearms, patched trousers, worn boots.", side="enemy")
sheet_job("enemy_bandit_archer", "Wiry female bandit archer, charcoal hooded cloak with coral-red bindings, light leather-like vest, quiver harness on the back, arm guard, fitted trousers, boots.", side="enemy")
sheet_job("enemy_bandit", "Stocky male bandit raider, patched scavenged charcoal armour vest with coral glow seams, hood down, short beard, boots.", side="enemy")
sheet_job("enemy_bandit_chief", "Massive male bandit chief, heavy scavenged charcoal plate armour with glowing coral-red seams, torn cloak, shaved head.", side="enemy")

# ---- B: base bodies (module base, heads/hair/outfits are swapped on top)
for g, who in (("m", "athletic young man of average build"), ("f", "athletic young woman of average build")):
    sheet_job("base_body_" + g, who + ", wearing a seamless fitted ink-navy technical undersuit bodysuit with thin frost seam lines, simple soft boots, bald smooth head (no hair), neutral expression.")

# ---- C: job outfits tier 1 (ally); worn by a neutral mannequin-like figure with a bald head so heads/hair can be swapped
JOBS = {
    "squire": "squire rider outfit: light frost-chrome breastplate over an ink-navy riding jacket, short back cape, riding boots",
    "light_inf": "light infantry outfit: layered ink-navy padded technical coat, single light shoulder guard, belt kit, boots",
    "heavy_inf": "heavy infantry outfit: heavy segmented frosted-chrome armour, tall gorget, large shoulder plates, armoured boots",
    "hunter": "hunter outfit: hooded asymmetric slate cloak (hood down), bracers, quiver harness, soft boots",
    "apprentice": "arcane apprentice outfit: long high-collared frost-white coat with luminous frost circuit lines, navy sash, slim boots",
    "light_cavalry": "light cavalry outfit: fitted riding armour, long split coat tails, knee-high boots",
    "warrior": "warrior outfit: broad frost-chrome pauldrons, sleeveless armoured vest, wrapped forearms, heavy boots",
    "archer": "archer outfit: streamlined slate archer coat, single chest plate, arm guard on the left arm, boots",
    "priest": "priest outfit: flowing layered frost-white and navy vestments, crystal halo-ring collar",
}
for job, outfit in JOBS.items():
    for g, who in (("m", "young man of average build"), ("f", "young woman of average build")):
        sheet_job(f"outfit_{job}_t1_{g}", f"A {who} with a bald smooth head wearing a {outfit}.")

# ---- D: 2D paper-doll face bases (front, shared canvas/anchor, neutral grey cropped hair, neutral eyes)
BLOOD = {
    "common_ash": "broad honest face, sturdy jaw, warm neutral skin tone",
    "river_ward": "lean face, long narrow eyes, fair cool-toned skin",
    "ember_noble": "high cheekbones, strong straight brow ridge, light olive skin",
    "frost_crown": "narrow refined face, tall forehead, delicate features, porcelain skin",
}
PART = ("Paper-doll portrait base layer: strictly front-facing head-and-shoulders portrait, eye level, symmetrical, "
        "top of head at 10% from the top edge, chin at 52% of the height, shoulders filling the width, "
        "very short close-cropped neutral silver-grey hair, neutral grey irises, relaxed neutral expression, "
        "plain high-collared ink-navy undershirt, no jewellery, no accessories, plain uniform light grey #D9DEE3 background.")
for bl, face in BLOOD.items():
    for g, who in (("m", "young man"), ("f", "young woman")):
        name = f"face_{bl}_{g}"
        b.add(name, qwen_job(STYLE + f" A {who} with a {face}. " + PART, "ck87_" + name, 1024, 1024, seed_of(name)))
print("jobs", b.n)
