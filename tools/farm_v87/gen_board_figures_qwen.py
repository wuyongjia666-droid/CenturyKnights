"""Board-figure P1 Qwen batch (:8322): orthographic FRONT|BACK turnarounds for
Opus v2 立绘同源写实棋子. Priority kit = leader / hunter / bandit (+ light_inf body).

Usage:
  python3 tools/farm_v87/gen_board_figures_qwen.py <batch_dir>

Outputs ComfyUI API jobs under <batch>/jobs and refs under <batch>/inputs.
Submit on m173:  farm.ps1 submit <batch_dir>
"""
import os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import *

# Board-figure addendum: readable at chess-piece scale — slightly larger head,
# clear silhouette, empty hands (weapons are modular), A-pose turnaround.
BOARD = (
    " Board-piece concept for an SRPG chess-like board: realistic adult proportions "
    "about 5.45 heads tall with the head enlarged about 1.35x relative to a real adult "
    "so the face and hair silhouette stay readable at small size; chin slightly lifted; "
    "clear separation of hair, skin, outer coat, and dark trousers/boots; "
    "no helmet covering the face; no weapon in hand (weapons are separate modules); "
    "semi-realistic contemporary fantasy, soft airbrushed shading, NOT chibi, NOT cartoon Q-version, NOT flat cel-shade."
)

def sheet(name, who, refimg=None, side="ally", extra=""):
    acc = ALLY if side == "ally" else ENEMY
    lead = (
        " Use the person in image 1 as the exact identity reference for face, hairstyle, "
        "hair colour, skin tone and upper-outfit design; extend the outfit naturally to the full body. "
    ) if refimg else " "
    p = STYLE + lead + who + " " + extra + BOARD + " " + SHEET + " " + acc
    b.add(name, qwen_job(p, "ck_bf_" + name, 1536, 1024, seed_of("bf_" + name),
                         refs=[refimg] if refimg else (), steps=30))

root = sys.argv[1] if len(sys.argv) > 1 else "/workspace/farm_board_fig_t1"
b = Batch(root)
REF = os.path.join(root, "refs")

def take(src_name, as_name):
    src = os.path.join(REF, src_name)
    if not os.path.isfile(src):
        raise SystemExit("missing ref " + src)
    return b.ref(src, as_name)

# ---- P1 priority cast (bust / plate referenced) ----
sheet("bf_leader_m",
      "Young male knight-commander, short dark tousled hair, high-collared frost-chrome armoured coat "
      "over an ink-navy tunic, one articulated pauldron, fitted trousers, armoured boots.",
      take("ref_leader_m1.png", "ck_bf_ref_leader_m.png"))
sheet("bf_leader_f",
      "Young female knight-commander, dark hair, frost-chrome armoured long coat, navy undersuit, armoured boots.",
      take("ref_leader_f1.png", "ck_bf_ref_leader_f.png"))
sheet("bf_hunter_m",
      "Young male hunter, asymmetrical slate hooded wrap (hood down around the neck), bracers, "
      "quiver harness on the back, soft tall boots, short hem and wrapped calves.",
      take("ref_hunter_m.png", "ck_bf_ref_hunter_m.png") if os.path.isfile(os.path.join(REF, "ref_hunter_m.png")) else None)
sheet("bf_hunter_f",
      "Young female reed-marsh hunter, long dark hair, layered pale frost-white and navy hooded wrap coat "
      "with fur-trimmed collar (hood down), fitted leggings, soft tall boots, quiver strap on the back.",
      take("ref_hunter_f.png", "ck_bf_ref_hunter_f.png") if os.path.isfile(os.path.join(REF, "ref_hunter_f.png")) else None)
sheet("bf_bandit",
      "Stocky male mountain-pass bandit raider, patched scavenged charcoal armour vest with coral glow seams, "
      "hood down, short beard, patched trousers, worn boots.",
      take("ref_bandit.png", "ck_bf_ref_bandit.png") if os.path.isfile(os.path.join(REF, "ref_bandit.png")) else None,
      side="enemy")
sheet("bf_bandit_archer",
      "Wiry female bandit archer, charcoal hooded cloak with coral-red bindings (hood down), light leather-like vest, "
      "quiver harness on the back, arm guard, fitted trousers, boots.",
      side="enemy")
sheet("bf_bandit_chief",
      "Massive male bandit chief, heavy scavenged charcoal plate with glowing coral-red seams, torn coral-tinged cloak, "
      "shaved head, heavy boots; overall slightly larger stature.",
      side="enemy")
sheet("bf_bandit_weak",
      "Lean male mountain-pass bandit, ragged charcoal hooded technical jacket (hood down), wrapped forearms, "
      "patched trousers, worn boots; cloth clothes, no heavy armour.",
      side="enemy")
# ---- modular body bases (short neutral hair; documented mannequin, not bald) ----
# Used for part swaps after Hunyuan. Keep face readable so sheets do not look like scrap.
for g, who in (("m", "athletic young man of average build"),
               ("f", "athletic young woman of average build")):
    sheet("bf_base_body_" + g,
          who + ", short neat neutral dark hair (NOT bald), clear facial features with visible eyes "
          "eyebrows nose and lips, neutral expression, wearing a seamless fitted ink-navy technical "
          "undersuit bodysuit with thin frost seam lines, simple soft boots.")

# ---- t1 outfits: full hair + clear face matching class (NOT bald mannequin) ----
# Must read as the same profession as bf_leader / bf_hunter / light_inf cast sheets.
OUTFIT_WHO = {
    "leader_coat": {
        "m": ("Young male knight-commander with short dark tousled hair and a clear readable face "
              "(defined eyes, brows, nose, lips — NOT bald, NOT featureless), wearing a "
              "knight-commander outfit: high-collared frost-chrome armoured coat over ink-navy tunic, "
              "one articulated pauldron, fitted trousers, armoured boots, short back cape."),
        "f": ("Young female knight-commander with dark shoulder-length hair and a clear readable face "
              "(defined eyes, brows, nose, lips — NOT bald, NOT featureless), wearing a "
              "knight-commander outfit: high-collared frost-chrome armoured long coat, navy undersuit, "
              "armoured boots, short back cape."),
    },
    "hunter": {
        "m": ("Young male hunter with short dark messy hair and a clear readable face "
              "(defined eyes, brows, nose, lips — NOT bald, NOT featureless), wearing a "
              "hunter outfit: hooded asymmetric slate cloak worn down around the neck, bracers, "
              "quiver harness, soft boots, short hem, wrapped calves."),
        "f": ("Young female reed-marsh hunter with long dark hair and a clear readable face "
              "(defined eyes, brows, nose, lips — NOT bald, NOT featureless), wearing a "
              "hunter outfit: layered pale frost-white and navy hooded wrap coat with fur-trimmed "
              "collar (hood down), fitted leggings, soft tall boots, quiver strap."),
    },
    "light_inf": {
        "m": ("Young male light infantryman with short neat dark hair and a clear readable face "
              "(defined eyes, brows, nose, lips — NOT bald, NOT featureless), wearing a "
              "light infantry outfit: layered ink-navy padded technical coat, single light shoulder "
              "guard, belt kit, mid-length hem, boots."),
        "f": ("Young female light infantry soldier with tied-back dark hair and a clear readable face "
              "(defined eyes, brows, nose, lips — NOT bald, NOT featureless), wearing a "
              "light infantry outfit: layered ink-navy padded technical coat, single light shoulder "
              "guard, belt kit, mid-length hem, boots."),
    },
}
for job, by_g in OUTFIT_WHO.items():
    for g, who in by_g.items():
        sheet(f"bf_outfit_{job}_t1_{g}", who)

print("board_figure qwen jobs", b.n, "->", root)
