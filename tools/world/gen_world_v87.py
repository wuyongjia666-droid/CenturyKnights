#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build project/data/world_v87.json (geography, economy, road events, commission templates)
and project/data/world_items_v87.json (nation lines + city signature arms) from world_content_v87.py.
Deterministic: re-running yields identical files. Also writes tools/world/shots_v87_atlas.json (farm prompts,
style-lock prefix applied by tools/farm_v87/gen_atlas_v87.py)."""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from world_content_v87 import NATIONS, C, ROADS, CROSS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "project", "data")

GOODS = {
 # id: name, base price, store (castle stockpile var) or cargo, smith material?, flavour
 "grain":        ("粮", 2, "food", False, "军粮与口粮。跑图每日消耗，也入城堡粮仓。"),
 "iron":         ("铁料", 8, "iron", True, "通用锻料，所有铁匠铺都收。"),
 "herb":         ("药材", 6, "herb", False, "疗伤与神殿祭仪用药。"),
 "ashsteel":     ("烬灰钢", 18, "", True, "灰烬邦白垣军械署的夹芯钢，西陆制式兵器标准料。"),
 "obsidian":     ("影曜石", 22, "", True, "朔影国矿脉产出的吸光黑石，刀刃夜里几乎不可见。"),
 "jade":         ("河玉", 26, "", True, "清河碧潭潭底的青玉，护符与剑格的上料。"),
 "lampglass":    ("灯琉璃", 20, "", True, "灯市联琉璃匠吹制的发光琉璃，包钢后会微微发亮。"),
 "frostcrystal": ("霜晶", 30, "", True, "霜冕廷高原的永冻晶体，极寒而锋利。"),
 "magmaglass":   ("熔曜玻", 28, "", True, "余烬旧邦古城的熔玻璃，仍有余温。"),
 "saltcrystal":  ("盐晶", 12, "", True, "盐泽潮滩长出的透明盐晶，也是盐引的实物。"),
 "gorgesteel":   ("峡钢锭", 24, "", True, "铁峡领冷光锻炉的高碳钢锭，十国最硬。"),
 "stardust":     ("星砂", 34, "", True, "星津陨星田的星砂，秘术与弓弦的增幅料。"),
 "hardwood":     ("南泽硬木", 14, "", True, "南泽雾林的硬木，弓臂与窑薪首选。"),
 "silk":         ("雾丝", 16, "", False, "清河与星津的雾丝绸，贵族与学者的衣料。"),
 "tea":          ("云茶", 10, "", False, "雾果林与南泽山茶，北地极受欢迎。"),
 "fur":          ("霜貂皮", 15, "", True, "北境霜貂皮，轻甲衬里与御寒必需。"),
 "spice":        ("南椒", 12, "", False, "南泽与灯市的香料，跑海路的硬通货。"),
}

TYPE_NOUN = {"sword": "长剑", "blade": "战刀", "spear": "长枪", "lance": "骑枪", "axe": "战斧", "bow": "长弓",
             "crossbow": "劲弩", "staff": "法杖", "focus": "法器", "shield": "塔盾", "armor": "轻甲", "charm": "护符"}
TYPE_SLOT = {"sword": "weapon", "blade": "weapon", "spear": "weapon", "lance": "weapon", "axe": "weapon", "bow": "weapon",
             "crossbow": "weapon", "staff": "weapon", "focus": "weapon", "shield": "armor", "armor": "armor", "charm": "charm"}
TYPE_JOBS = {
 "sword": ["squire", "light_inf", "heavy_inf", "warrior", "light_cavalry"],
 "blade": ["squire", "light_inf", "heavy_inf", "warrior", "light_cavalry", "hunter", "archer"],
 "spear": ["squire", "light_inf", "heavy_inf", "warrior", "light_cavalry"],
 "lance": ["squire", "light_cavalry"],
 "axe": ["light_inf", "heavy_inf", "warrior"],
 "bow": ["hunter", "archer"],
 "crossbow": ["hunter", "archer"],
 "staff": ["apprentice", "priest"],
 "focus": ["apprentice", "priest"],
 "shield": ["squire", "light_inf", "heavy_inf", "warrior", "light_cavalry"],
 "armor": [], "charm": [],
}
# stat profile per type: f(tier) -> dict
def profile(t, tier):
    T = tier
    p = {
     "sword":    {"atk": 2*T, "hit": 5, "crit": 2},
     "blade":    {"atk": 2*T-1, "crit": 3*T},
     "spear":    {"atk": 2*T-1, "hit": 5, "def": 1},
     "lance":    {"atk": 2*T+1, "hit": -5, "crit": T},
     "axe":      {"atk": 2*T+2, "hit": -10},
     "bow":      {"atk": 2*T, "hit": 5},
     "crossbow": {"atk": 2*T+1, "hit": 10, "avo": -3},
     "staff":    {"atk": 2*T-1, "def": 1, "hp": 2*T},
     "focus":    {"atk": 2*T+1, "crit": 3},
     "shield":   {"def": T+1, "avo": 2, "hp": 3*T},
     "armor":    {"def": T+1, "avo": -1} if T < 3 else {"def": 2*T, "avo": -3, "hp": 2*T},
     "charm":    {"hit": 3*T, "avo": 2*T, "hp": T},
    }[t]
    return {k: v for k, v in p.items() if v != 0}

TYPE_SKILL = {  # (signature skill, legendary skill) — existing battle skills granted while equipped
 "sword": ("banner_crash", "cleave_arc"), "blade": ("rush", "wheel_cut"), "spear": ("lance_thrust", "shatter_line"),
 "lance": ("charge_break", "wheel_cut"), "axe": ("power_strike", "shatter_line"), "bow": ("rain_volleys", "sky_piercer"),
 "crossbow": ("mark_death", "sky_piercer"), "staff": ("ember_seal", "sanctuary"), "focus": ("smite", "judgment"),
 "shield": ("iron_wall", "hold_phalanx"), "armor": ("terrain_ward", "anchor_guard"), "charm": ("disengage_step", "lock_breaker"),
}
NATION_EDGE = {  # legendary nation passive (extra stat)
 "ashbanner": {"atk": 1, "def": 1}, "shuoying": {"avo": 6}, "qinghe": {"hit": 8}, "lantern": {"hit": 6, "crit": 3},
 "frostcrown": {"def": 3}, "emberold": {"atk": 3}, "saltmarsh": {"hp": 6}, "irongorge": {"def": 2, "atk": 1},
 "starriver": {"crit": 6}, "southzephyr": {"move": 1}, "landbridge": {"hit": 4, "avo": 3},
}
STAT_ZH = {"atk": "攻", "def": "防", "hit": "命中", "avo": "回避", "crit": "暴击", "move": "移动", "hp": "生命"}
TIER_PRICE = {1: 45, 2: 100, 3: 210, 4: 420}
NATION_LINE = {  # 7 common items per region: (type, tier)
 "ashbanner":  [("sword", 1), ("spear", 1), ("shield", 2), ("blade", 2), ("bow", 2), ("armor", 3), ("sword", 3)],
 "shuoying":   [("blade", 1), ("crossbow", 1), ("blade", 2), ("charm", 2), ("bow", 2), ("armor", 3), ("crossbow", 3)],
 "qinghe":     [("sword", 1), ("bow", 1), ("staff", 2), ("focus", 2), ("charm", 2), ("bow", 3), ("sword", 3)],
 "lantern":    [("blade", 1), ("spear", 1), ("crossbow", 2), ("sword", 2), ("staff", 2), ("charm", 3), ("blade", 3)],
 "frostcrown": [("spear", 1), ("staff", 1), ("shield", 2), ("lance", 2), ("sword", 2), ("armor", 3), ("spear", 3)],
 "emberold":   [("axe", 1), ("focus", 1), ("sword", 2), ("armor", 2), ("staff", 2), ("axe", 3), ("focus", 3)],
 "saltmarsh":  [("spear", 1), ("blade", 1), ("crossbow", 2), ("armor", 2), ("charm", 2), ("sword", 3), ("spear", 3)],
 "irongorge":  [("axe", 1), ("sword", 1), ("shield", 2), ("spear", 2), ("crossbow", 2), ("armor", 3), ("axe", 3)],
 "starriver":  [("staff", 1), ("bow", 1), ("focus", 2), ("spear", 2), ("charm", 2), ("staff", 3), ("bow", 3)],
 "southzephyr":[("bow", 1), ("spear", 1), ("blade", 2), ("armor", 2), ("staff", 2), ("bow", 3), ("charm", 3)],
 "landbridge": [("blade", 1), ("lance", 1), ("spear", 2), ("shield", 2), ("sword", 2), ("lance", 3), ("armor", 3)],
}
TIER_WORD = {1: "", 2: "精制", 3: "名匠"}

def mats_for(nation, t, tier, sig=False, legendary=False):
    mat = NATIONS[nation]["mat"]
    m = {}
    base_iron = {1: 2, 2: 3, 3: 4, 4: 5}[tier]
    if t in ("staff", "focus", "charm"):
        base_iron = max(0, base_iron - 2)
    if base_iron:
        m["iron"] = base_iron
    if tier >= 2 and mat != "iron":
        m[mat] = tier - 1 + (1 if sig else 0) + (1 if legendary else 0)
    if t in ("bow", "crossbow", "staff") and nation != "southzephyr":
        m["hardwood"] = m.get("hardwood", 0) + (1 if tier < 3 else 2)
    if t == "armor":
        m["fur"] = m.get("fur", 0) + 1
    if t in ("focus", "charm") and tier >= 2:
        m["stardust" if nation != "starriver" else "jade"] = 1
    if legendary:
        m["gorgesteel" if mat != "gorgesteel" else "frostcrystal"] = m.get("gorgesteel", 0) + 1
    if mat == "iron" and tier >= 2:
        m["iron"] = m.get("iron", 0) + tier
    return m

def mk_item(iid, name, nation, t, tier, city="", sig=0, lore=""):
    st = profile(t, tier)
    if sig:
        for k, v in profile(t, min(4, tier)).items():
            pass
        # signature: +1 to the primary stat line, legendary adds nation edge
        prim = "atk" if TYPE_SLOT[t] == "weapon" else ("def" if t in ("armor", "shield") else "avo")
        st[prim] = st.get(prim, 0) + (1 if sig == 1 else 2)
        if sig == 2:
            for k, v in NATION_EDGE[nation].items():
                st[k] = st.get(k, 0) + v
    price = int(TIER_PRICE[tier] * (1.45 if sig == 1 else (2.1 if sig == 2 else 1.0)))
    it = {"id": iid, "name": name, "nation": nation, "type": t, "type_name": TYPE_NOUN[t], "slot": TYPE_SLOT[t], "tier": tier,
          "stats": st, "jobs": TYPE_JOBS[t], "price": price, "mats": mats_for(nation, t, tier, sig >= 1, sig == 2),
          "forge_silver": int(price * 0.38), "lore": lore}
    if t == "armor" and tier >= 3:
        it["jobs"] = ["squire", "heavy_inf", "warrior", "light_cavalry", "light_inf"]
    if city:
        it["city"] = city
    if sig:
        it["signature"] = sig  # 1 = city signature, 2 = legendary (needs the city commission)
        it["skill"] = TYPE_SKILL[t][sig - 1]
        it["rep_req"] = 10 if sig == 1 else 55
    return it

def foe_templates():
    """[weak, melee, ranged, boss] per foe prefix, validated against CharacterFactory.make_enemy match arms."""
    src = open(os.path.join(ROOT, "project/scripts/characters/character_factory.gd")).read()
    import re
    have = set(re.findall(r'^\s*"([a-z_]+)":\s*$', src, re.M))
    out = {}
    prefixes = sorted({f for n in NATIONS.values() for f in n["foes"]})
    for p in prefixes:
        if p == "bandit":
            row = ["bandit_weak", "bandit", "bandit_archer", "bandit_chief"]
        elif p == "escort":
            row = ["escort_thief", "escort_raider", "escort_sniper", "escort_boss"]
        elif p == "paper":
            row = ["paper_thief", "paper_thief", "paper_archer", "paper_boss"]
        else:
            row = [p + "_thug", p + "_thug", p + "_archer", p + "_boss"]
        for t in row:
            assert t in have, t
        out[p] = row
    return out

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])

def main():
    by_id = {c["id"]: c for c in C}
    items = []
    for nid, line in NATION_LINE.items():
        pre = NATIONS[nid]["prefix"]
        for i, (t, tier) in enumerate(line):
            nm = pre + TIER_WORD[tier] + TYPE_NOUN[t] if not (t == "armor" and tier >= 3) else pre + "重铠"
            items.append(mk_item("%s_%s_%d" % (nid, t, tier), nm, nid, t, tier,
                                 lore="%s铁匠铺的制式货。%s" % (NATIONS[nid]["name"], GOODS[NATIONS[nid]["mat"]][4] if tier >= 2 else "")))
    for c in C:
        for k, s in enumerate(c["sig"]):
            nm, t, flav = s
            items.append(mk_item("%s_sig%d" % (c["id"], k + 1), nm, c["nation"], t, 3 if k == 0 else 4, c["id"], k + 1, flav))
    # nodes
    nodes = []
    for c in C:
        n = NATIONS[c["nation"]]
        kind = c["kind"]
        smith = {"village": 1, "town": 2, "port": 2, "fortress": 2, "city": 3, "capital": 3, "castle": 0}[kind]
        tav = {"village": 1, "town": 2, "port": 2, "fortress": 1, "city": 3, "capital": 3, "castle": 0}[kind]
        node = {k: c[k] for k in ("id", "name", "nation", "kind", "size", "pos", "biome", "specialty", "lore", "produce", "demand")}
        node["smith_tier"] = smith
        node["tavern_slots"] = tav
        node["sig_items"] = ["%s_sig%d" % (c["id"], k + 1) for k in range(len(c["sig"]))]
        if c["quest"]:
            node["sig_quest"] = {"id": "sq_" + c["id"], "title": c["quest"][0], "kind": c["quest"][1], "brief": c["quest"][2]}
        nodes.append(node)
    roads = []
    for a, b, dg in ROADS:
        A, B = by_id[a], by_id[b]
        assert A["nation"] == B["nation"], (a, b)
        days = max(1, round(dist(A["pos"], B["pos"]) * 5.2))
        roads.append({"a": a, "b": b, "days": days, "danger": dg, "kind": "road"})
    for a, b, days, dg, kind in CROSS:
        assert by_id[a]["nation"] != by_id[b]["nation"], (a, b)
        r = {"a": a, "b": b, "days": days, "danger": dg, "kind": kind}
        if kind == "sea":
            r["fare"] = 30 if days <= 6 else 45
        roads.append(r)
    # connectivity check
    adj = {c["id"]: set() for c in C}
    for r in roads:
        adj[r["a"]].add(r["b"]); adj[r["b"]].add(r["a"])
    seen, st = {"hq"}, ["hq"]
    while st:
        x = st.pop()
        for y in adj[x]:
            if y not in seen:
                seen.add(y); st.append(y)
    assert len(seen) == len(C), set(adj) - seen
    nations = {}
    for nid, n in NATIONS.items():
        d = {k: n[k] for k in ("name", "en", "cont", "mat", "foes", "blood", "jobs", "culture", "smith", "prefix", "stance", "toll")}
        d["wpos"] = list(n["wpos"])
        d["plate"] = n.get("plate", "v8_atlas_nation_%s" % nid)
        d["capital"] = next((c["id"] for c in C if c["nation"] == nid and c["kind"] == "capital"), next(c["id"] for c in C if c["nation"] == nid))
        nations[nid] = d
    goods = {k: {"name": v[0], "base": v[1], "store": v[2], "material": v[3], "desc": v[4]} for k, v in GOODS.items()}
    world = {
        "version": "v8.7-atlas-1",
        "home": "hq",
        "nations": nations,
        "nodes": nodes,
        "roads": roads,
        "goods": goods,
        "events": EVENTS,
        "commissions": COMMISSIONS,
        "volume_nation": ["ashbanner", "ashbanner", "saltmarsh", "frostcrown", "starriver", "irongorge", "emberold", "shuoying",
                          "qinghe", "lantern", "southzephyr", "landbridge"],
        "rules": RULES,
        "foe_templates": foe_templates(),
        "biome_keyword": {"fort": "keep", "urban": "street", "ford": "ford", "hill": "hill", "fog": "fog", "snow": "snow", "pass": "pass",
                          "nightcamp": "night", "harbor": "harbor", "archive": "archive", "plain": "plain", "marsh": "marsh", "forge": "forge", "shrine": "shrine"},
    }
    json.dump(world, open(os.path.join(DATA, "world_v87.json"), "w"), ensure_ascii=False, indent=1)
    json.dump({"version": "v8.7-atlas-1", "items": items}, open(os.path.join(DATA, "world_items_v87.json"), "w"), ensure_ascii=False, indent=1)
    # farm prompts (subject text only; style-lock prefix/negative appended by the farm job builder)
    shots = []
    for c in C:
        n = NATIONS[c["nation"]]
        shots.append({"label": "v87_city_%s" % c["id"], "kind": "city", "w": 1280, "h": 720,
                      "subject": "city vignette plate of a %s-sized %s in the %s region: %s. %s. three-quarter aerial view at 35 degrees elevation, "
                                 "atmospheric depth toward the top, settlement centred with clear silhouette, dark UI-safe lower third, no people close-up"
                                 % ("large" if c["size"] >= 4 else ("modest" if c["size"] >= 3 else "small"), c["kind"], n["en"], ENG_BIOME.get(c["biome"], c["biome"]), ENG_NATION[c["nation"]])})
    for nid, n in NATIONS.items():
        shots.append({"label": "v87_smith_%s" % nid, "kind": "city", "w": 1280, "h": 720,
                      "subject": "interior of a contemporary-fantasy smithy of the %s region, %s; weapon racks of %s arms, cool forge glow (no warm fire light, cyan-white forge plasma), workbench in front, UI-safe dark left third"
                                 % (n["en"], ENG_NATION[nid], ENG_MAT[n["mat"]])})
    for it in items:
        shots.append({"label": "v87_item_%s" % it["id"], "kind": "icon", "w": 768, "h": 768,
                      "subject": "single %s game item icon (%s): one %s made of %s, %s, isolated on plain light grey #D9DEE3 background, 30 degree three-quarter top-down view, diagonal from bottom-left to top-right, centred, whole object visible, no hands"
                                 % (ENG_TYPE[it["type"]], "legendary" if it.get("signature") == 2 else ("signature" if it.get("signature") else "standard issue"),
                                    ENG_TYPE[it["type"]], ENG_MAT[NATIONS[it["nation"]]["mat"]], ENG_MOTIF[it["nation"]])})
    json.dump(shots, open(os.path.join(os.path.dirname(__file__), "shots_v87_atlas.json"), "w"), ensure_ascii=False, indent=1)
    print("nodes", len(nodes), "roads", len(roads), "items", len(items), "sig", sum(1 for i in items if i.get("signature")),
          "goods", len(goods), "events", len(EVENTS), "commission templates", len(COMMISSIONS), "shots", len(shots))

ENG_BIOME = {"fort": "fortified walls and gate towers", "urban": "dense contemporary-fantasy city blocks", "ford": "river crossing and jade water channels",
             "hill": "terraced stone hills", "fog": "mist-veiled valley", "snow": "snow plateau and ice ridges", "pass": "mountain pass and cliffs",
             "nightcamp": "night court lit by cool lanterns", "harbor": "harbour piers and moored ships", "archive": "academy library towers",
             "plain": "open fields and orchards", "marsh": "tidal marsh with salt crystals and reeds", "forge": "forge district with cool-lit chimneys",
             "shrine": "shrine courtyard and ancient tree"}
ENG_NATION = {"ashbanner": "ash-grey plains citadels with luminous river veins", "shuoying": "deep indigo northern frost ridges, black obsidian spires",
              "qinghe": "jade river delta, pale mist orchards", "lantern": "glass lantern towers over a night sea, coastal market glow",
              "frostcrown": "iceglass crystal halls on a high plateau", "emberold": "cracked magma-glass ruins under cool dusk",
              "saltmarsh": "tidal flats with pale salt crystal formations and reed haze", "irongorge": "vertical canyon forges in cold steel light",
              "starriver": "night river reflecting constellation bridges", "southzephyr": "luminous fog forest wetlands with ferry lights",
              "landbridge": "a colossal stone landbridge between two continents with relay forts"}
ENG_MAT = {"ashsteel": "ash-grey layered steel", "obsidian": "light-absorbing black obsidian", "jade": "pale jade", "lampglass": "glowing lamp glass over steel",
           "frostcrystal": "translucent frost crystal", "magmaglass": "dark magma glass with faint inner glow", "saltcrystal": "clear salt crystal",
           "gorgesteel": "cold blue high-carbon steel", "stardust": "star-dust inlaid silver", "hardwood": "dense dark hardwood", "iron": "frosted brushed steel"}
ENG_MOTIF = {"ashbanner": "faint luminous river-vein etching", "shuoying": "indigo wrap and night-court engraving", "qinghe": "jade inlay and flowing water engraving",
             "lantern": "small glowing lamp-glass inset", "frostcrown": "crystal frost facets", "emberold": "cracked dark glass seams with faint inner glow",
             "saltmarsh": "clear crystal shards and reed-wrapped grip", "irongorge": "cold blue forge-hammered facets", "starriver": "tiny star-dust constellation inlay",
             "southzephyr": "dark hardwood with woven vine wrap", "landbridge": "relay-courier frost trims"}
ENG_TYPE = {"sword": "longsword", "blade": "single-edged sabre", "spear": "spear", "lance": "cavalry lance", "axe": "battle axe", "bow": "recurve longbow",
            "crossbow": "crossbow", "staff": "mage staff", "focus": "arcane focus orb", "shield": "tower shield", "armor": "armour cuirass", "charm": "amulet charm"}

# ── road events: weight, filters, options[effects] ─────────────
EVENTS = [
 {"id": "ambush", "title": "伏击", "text": "道旁林影一动——{foe}早已埋伏在此。", "weight": 10, "min_danger": 1, "kinds": ["road", "border"],
  "options": [{"label": "列阵迎战", "fx": {"battle": "ambush"}}, {"label": "丢下部分货物脱身", "fx": {"lose_cargo": 0.3, "morale": -2}}]},
 {"id": "toll", "title": "拦路收银", "text": "一伙人横在路中：「过路银，{toll} 两。」", "weight": 8, "min_danger": 1, "kinds": ["road", "border"],
  "options": [{"label": "付银了事", "fx": {"silver": "-toll"}}, {"label": "拔刀", "fx": {"battle": "toll"}}]},
 {"id": "merchant", "title": "行商", "text": "一位行商赶着驮兽同路，愿意低价出手一批{good}。", "weight": 9, "min_danger": 0, "kinds": ["road", "border", "sea"],
  "options": [{"label": "买下（7 折）", "fx": {"buy_deal": 0.7}}, {"label": "道别", "fx": {}}]},
 {"id": "refugees", "title": "难民", "text": "一队难民向你们讨粮，孩子们看着军旗。", "weight": 6, "min_danger": 0, "kinds": ["road", "border"],
  "options": [{"label": "分出 6 份粮", "fx": {"food": -6, "rep_nation": 4, "morale": 1}}, {"label": "继续赶路", "fx": {"morale": -1}}]},
 {"id": "shrine", "title": "路边小祠", "text": "古祠里还有人添灯。歇一歇脚？", "weight": 6, "min_danger": 0, "kinds": ["road"],
  "options": [{"label": "歇息疗伤（+1 日）", "fx": {"heal": 0.35, "days": 1}}, {"label": "上香祈愿", "fx": {"morale": 2}}]},
 {"id": "storm", "title": "恶劣天气", "text": "{weather}压了下来，前路难辨。", "weight": 7, "min_danger": 0, "kinds": ["road", "border"],
  "options": [{"label": "就地扎营（+1 日）", "fx": {"days": 1}}, {"label": "花 12 银借宿农家", "fx": {"silver": -12}}]},
 {"id": "crate", "title": "遗落货箱", "text": "翻倒的货车旁散着几箱{good}，主人不知去向。", "weight": 5, "min_danger": 0, "kinds": ["road"],
  "options": [{"label": "收下", "fx": {"gain_good": 3, "rep_nation": -1}}, {"label": "交给下一座城的巡卫", "fx": {"rep_dest": 3}}]},
 {"id": "patrol", "title": "巡逻队盘查", "text": "{nation}巡逻队拦下了你们，要查文书。", "weight": 6, "min_danger": 0, "kinds": ["road", "border"],
  "options": [{"label": "出示佣兵契", "fx": {"patrol": True}}, {"label": "塞 15 银", "fx": {"silver": -15, "rep_nation": 1}}]},
 {"id": "merc", "title": "落单佣兵", "text": "一名落单的佣兵坐在路边磨刀，打量着你们的旗。", "weight": 4, "min_danger": 0, "kinds": ["road", "border"],
  "options": [{"label": "邀其入团（{hire} 银）", "fx": {"recruit": True}}, {"label": "点头而过", "fx": {}}]},
 {"id": "rumor", "title": "茶摊传闻", "text": "茶摊老板压低声音：{tip}", "weight": 6, "min_danger": 0, "kinds": ["road", "border", "sea"],
  "options": [{"label": "记下", "fx": {"tip": True}}]},
 {"id": "herbs", "title": "野生药草", "text": "路旁坡地长满了药草。", "weight": 4, "min_danger": 0, "kinds": ["road"], "biomes": ["fog", "plain", "hill", "shrine", "marsh", "ford"],
  "options": [{"label": "采集（+1 日，+3 药材）", "fx": {"herb": 3, "days": 1}}, {"label": "不耽搁", "fx": {}}]},
 {"id": "bridge", "title": "断桥", "text": "桥被冲垮了一半。", "weight": 4, "min_danger": 0, "kinds": ["road"], "biomes": ["ford", "marsh", "pass", "harbor"],
  "options": [{"label": "绕路（+1 日）", "fx": {"days": 1}}, {"label": "出 15 银雇人修桥", "fx": {"silver": -15, "rep_nation": 3}}]},
 {"id": "caravan", "title": "同路商队", "text": "一支商队请求同行，愿付护送费。", "weight": 5, "min_danger": 1, "kinds": ["road", "border"],
  "options": [{"label": "同行护送（+20 银，伏击风险）", "fx": {"silver": 20, "risk": 0.35}}, {"label": "婉拒", "fx": {}}]},
 {"id": "deserters", "title": "逃兵", "text": "一群逃兵占了路边的驿亭，正在抢劫旅人。", "weight": 5, "min_danger": 2, "kinds": ["road", "border"],
  "options": [{"label": "驱逐他们", "fx": {"battle": "deserters", "rep_nation_win": 5}}, {"label": "避开", "fx": {"days": 1}}]},
 {"id": "omen", "title": "异兆", "text": "夜空里{omen}。老兵说这是好兆头。", "weight": 3, "min_danger": 0, "kinds": ["road", "sea"],
  "options": [{"label": "全军振奋", "fx": {"morale": 3}}]},
 {"id": "rival_scouts", "title": "朔影探子", "text": "几个朔影探子尾随你们多时。", "weight": 6, "min_danger": 0, "kinds": ["road", "border"], "nations": ["shuoying", "ashbanner", "frostcrown"],
  "options": [{"label": "反包围", "fx": {"battle": "scouts"}}, {"label": "放出假消息（-10 银）", "fx": {"silver": -10, "rep_nation": 1}}]},
 {"id": "sea_storm", "title": "海上风暴", "text": "风暴把船推离了航线。", "weight": 10, "min_danger": 0, "kinds": ["sea"],
  "options": [{"label": "硬扛（+2 日）", "fx": {"days": 2}}, {"label": "抛货减重", "fx": {"lose_cargo": 0.25}}]},
 {"id": "fair", "title": "集会消息", "text": "前方{dest}正逢集会，商人们说货价会涨。", "weight": 4, "min_danger": 0, "kinds": ["road", "border", "sea"],
  "options": [{"label": "加快脚步", "fx": {"fair": True}}]},
]
WEATHER = {"snow": "暴雪", "marsh": "潮雾", "fog": "浓雾", "harbor": "海风", "pass": "山崩落石", "forge": "灰烬雨", "nightcamp": "冰雾"}

COMMISSIONS = [
 # kind, title patterns, turn-in, base reward, days budget factor
 {"kind": "deliver", "titles": ["急件：{parcel}送{target}", "{parcel}托运·{target}", "代送{parcel}"], "turn_in": "target",
  "parcels": ["药箱", "账册", "盐引", "家书", "星图副本", "军械清单", "婚书", "种子", "铁匠图样", "议会公文"], "silver": 28, "rep": 5, "battle": False},
 {"kind": "escort", "titles": ["护送{client}前往{target}", "{client}的远行·{target}", "随行护卫：{client}"], "turn_in": "target",
  "clients": ["盐商", "学者", "信使", "药师", "朝圣者", "工匠", "老兵遗孀", "画师", "退役骑士", "说书人"], "silver": 40, "rep": 7, "battle": False, "risk": 0.25},
 {"kind": "hunt", "titles": ["追缉：{foe_name}", "悬赏·{foe_name}", "{target}外的{foe_name}"], "turn_in": "issuer",
  "foe_names": ["劫道悍匪", "逃狱死囚", "剪径大盗", "黑市刀客", "叛逃斥候", "盗墓头子", "人贩团伙"], "silver": 55, "rep": 9, "battle": True},
 {"kind": "clear", "titles": ["清剿{road}匪营", "{road}肃清令", "打通{road}"], "turn_in": "issuer", "silver": 60, "rep": 10, "battle": True},
 {"kind": "defend", "titles": ["{target}告急", "守卫{target}", "{target}求援"], "turn_in": "target", "silver": 65, "rep": 11, "battle": True},
 {"kind": "gather", "titles": ["收购{good}", "{good}告罄", "紧缺：{good}"], "turn_in": "issuer", "silver": 18, "rep": 5, "battle": False},
 {"kind": "scout", "titles": ["探听{target}虚实", "{target}的消息", "走一趟{target}"], "turn_in": "issuer", "silver": 22, "rep": 5, "battle": False},
]

RULES = {
 "food_per_member_day": 0.5, "starve_morale_per_day": 4, "days_per_month": 30,
 "cargo_base": 30, "cargo_per_member": 6, "board_size": {"village": 2, "town": 3, "port": 3, "fortress": 3, "city": 4, "capital": 5, "castle": 0},
 "board_refresh_days": 30, "active_limit": 5, "rep_tiers": [0, 10, 30, 55, 80], "smith_rep_bonus": [30, 55],
 "event_base_chance": 0.22, "event_danger_chance": 0.12, "price_spread": 0.08, "rep_price_cut": 0.10,
 "weather": WEATHER,
}

if __name__ == "__main__":
    main()
