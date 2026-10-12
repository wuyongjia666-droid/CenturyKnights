#!/usr/bin/env python3
"""Generate project/data/territory_v93.json: neutral sites the company can capture.

Hand-written content. Each site hangs off an existing atlas node (anchor) and
draws its yield from that nation's resource table (nation mat / node produce).
Run: python3 tools/world/territory_sites.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORLD = json.loads((ROOT / "project/data/world_v87.json").read_text(encoding="utf-8"))
OUT = ROOT / "project/data/territory_v93.json"

# kind -> base numbers. yield = per month. garrison 1..3 levels; upkeep per level.
KINDS = {
    "village": {"zh": "村寨", "silver": 10, "qty": 6, "upkeep": 4, "danger": 1},
    "mine": {"zh": "矿坑", "silver": 6, "qty": 3, "upkeep": 6, "danger": 2},
    "ferry": {"zh": "渡口", "silver": 22, "qty": 1, "upkeep": 5, "danger": 1},
    "lodge": {"zh": "林舍", "silver": 8, "qty": 3, "upkeep": 4, "danger": 2},
    "watchtower": {"zh": "烽台", "silver": 4, "qty": 0, "upkeep": 5, "danger": 2},
    "saltpan": {"zh": "盐场", "silver": 12, "qty": 3, "upkeep": 5, "danger": 1},
}

# (id, name, nation, kind, anchor, dx, dy, good, lore)
SITES = [
    ("t_ash_millrun", "磨坊溪村", "ashbanner", "village", "reed_ford", 0.07, 0.08, "grain", "苇原渡上游的水磨村，磨盘夜里也在转。谁守得住溪口，谁就吃得上白面。"),
    ("t_ash_cinderpit", "烬坑", "ashbanner", "mine", "stone_slope", -0.08, -0.07, "ashsteel", "石垒坡背后的老烬钢坑。军械署弃了它，坑里的夹芯矿脉还没挖完。"),
    ("t_ash_beacon", "灰烽台", "ashbanner", "watchtower", "fog_vale", 0.08, 0.1, "", "雾谷口的旧烽台。点起火来，整条发光河脉都看得见。"),
    ("t_sy_furtrap", "貂径猎舍", "shuoying", "lodge", "sy_ridge", 0.08, -0.08, "fur", "霜脊下的猎户木屋群。朔影宫廷的貂皮一半出自这里。"),
    ("t_sy_blackvein", "黑脉矿口", "shuoying", "mine", "sy_spire", -0.07, 0.09, "obsidian", "影曜石露头的矿口，白天看去只是一道裂缝。"),
    ("t_sy_icetower", "冰哨", "shuoying", "watchtower", "sy_frostfort", 0.09, 0.08, "", "霜堡外的孤哨。朔影的巡骑会来盘问每一面陌生旗。"),
    ("t_qh_teaterrace", "云阶茶寨", "qinghe", "village", "qh_mist", 0.08, 0.07, "tea", "雾里一层层的茶田，寨民只认守得住山道的人。"),
    ("t_qh_jadepool", "碧潭采玉场", "qinghe", "mine", "qh_south", -0.08, -0.08, "jade", "河玉潭的浅滩采场，潜工靠绳子下潭。"),
    ("t_qh_reedferry", "芦笙渡", "qinghe", "ferry", "qh_ford", -0.09, -0.06, "silk", "运丝船在这里换缆。渡口收的过船钱足够养一队人。"),
    ("t_lt_glasskiln", "吹琉璃坊", "lantern", "mine", "lt_hill", 0.08, 0.08, "lampglass", "灯市联城外的琉璃窑，窑火照得整座山发亮。"),
    ("t_lt_spicewharf", "椒码头", "lantern", "ferry", "lt_docks", 0.08, -0.08, "spice", "南椒卸货的小码头，账本比船还多。"),
    ("t_lt_lighthouse", "雾灯塔", "lantern", "watchtower", "lt_harbor", 0.07, 0.1, "", "港外礁上的灯塔，守塔的人能看见每一条进港的船。"),
    ("t_fc_crystalcut", "霜晶凿场", "frostcrown", "mine", "fc_spire", -0.08, 0.08, "frostcrystal", "冰川断面上的凿场，凿下的霜晶要用皮囊裹着下山。"),
    ("t_fc_sablelodge", "雪貂林舍", "frostcrown", "lodge", "fc_plateau", 0.08, -0.08, "fur", "高原林缘的猎舍，冬天封路三个月。"),
    ("t_fc_bellpost", "钟岭哨", "frostcrown", "watchtower", "fc_peak", -0.08, -0.08, "", "挂着铜钟的山哨，钟响一次，霜冕廷就知道有人越岭。"),
    ("t_eo_slagfield", "熔渣坡", "emberold", "mine", "eo_crack", 0.08, -0.07, "magmaglass", "地裂旁的熔渣坡，熔曜玻像黑冰一样嵌在渣里。"),
    ("t_eo_incensevill", "香灰村", "emberold", "village", "eo_shrine", 0.07, 0.08, "herb", "神庙下的制香村，村里人靠药草和香灰过活。"),
    ("t_eo_kilnferry", "窑口渡", "emberold", "ferry", "eo_glass", -0.08, 0.08, "magmaglass", "运玻璃的平底船在这里过河，船工最怕碰。"),
    ("t_sm_saltflat", "白滩盐场", "saltmarsh", "saltpan", "sm_west", 0.08, 0.08, "saltcrystal", "潮退后的白滩，晒盐的人踩着高跷走路。"),
    ("t_sm_reedvill", "苇荡村", "saltmarsh", "village", "sm_mid", -0.07, 0.09, "grain", "芦苇荡里的高脚村，稻子种在浮田上。"),
    ("t_sm_tideferry", "潮信渡", "saltmarsh", "ferry", "sm_shoal", 0.09, -0.07, "saltcrystal", "看潮信开船的渡口，渡钱随潮水涨落。"),
    ("t_ig_deepshaft", "深井矿", "irongorge", "mine", "ig_mine", 0.08, -0.08, "gorgesteel", "铁峡最深的竖井，下井的人要先在井口挂名牌。"),
    ("t_ig_drumtower", "鼓楼哨", "irongorge", "watchtower", "ig_plateau", 0.08, 0.08, "", "峡口的鼓楼，鼓声顺着峡壁能传二十里。"),
    ("t_ig_forgevill", "炉边村", "irongorge", "village", "ig_lower", -0.08, 0.07, "iron", "围着公炉住的锻工村，孩子们学会走路就学拉风箱。"),
    ("t_sr_stargrove", "星砂河湾", "starriver", "saltpan", "sr_west", 0.08, 0.08, "stardust", "河湾的淘砂场，夜里星砂在水下发光。"),
    ("t_sr_fluteferry", "笛声渡", "starriver", "ferry", "sr_sw", 0.08, -0.07, "grain", "摆渡人吹笛报船，粮船从这里北上。"),
    ("t_sr_pagodawatch", "塔影哨", "starriver", "watchtower", "sr_nw", -0.07, 0.09, "", "古塔改成的哨所，塔顶能望见陆桥。"),
    ("t_sz_hardwood", "铁木林场", "southzephyr", "lodge", "sz_vine", 0.08, -0.08, "hardwood", "南泽硬木的伐场，一棵树要三年才能运出林子。"),
    ("t_sz_hivevill", "蜂巢村", "southzephyr", "village", "sz_temple", -0.08, 0.08, "herb", "庙后山坡上养蜂的村子，蜜和药材一起卖。"),
    ("t_sz_bambooferry", "竹筏渡", "southzephyr", "ferry", "sz_isle", 0.08, 0.07, "spice", "竹筏连成的浮渡，椒商最爱走这条水路。"),
    ("t_lb_waystation", "断碑驿", "landbridge", "village", "lb_mid", 0.07, 0.09, "grain", "陆桥中段的废驿，修好了就是商队的歇脚处。"),
    ("t_lb_bridgetower", "桥心烽", "landbridge", "watchtower", "lb_south", 0.08, -0.08, "", "陆桥南岸的烽台。谁的旗挂在这里，桥上的商队就认谁。"),
]


def main() -> None:
    nodes = {n["id"]: n for n in WORLD["nodes"]}
    goods = WORLD["goods"]
    sites = []
    for sid, name, nat, kind, anchor, dx, dy, good, lore in SITES:
        a = nodes[anchor]
        assert a["nation"] == nat, (sid, anchor)
        assert a["kind"] not in ("castle", "capital"), sid
        assert good == "" or good in goods, (sid, good)
        k = KINDS[kind]
        stance = WORLD["nations"][nat]["stance"]
        danger = min(4, k["danger"] + (1 if stance == "hostile" else 0))
        px = round(min(0.95, max(0.05, a["pos"][0] + dx)), 3)
        py = round(min(0.95, max(0.05, a["pos"][1] + dy)), 3)
        sites.append({
            "id": sid, "name": name, "nation": nat, "kind": kind, "anchor": anchor,
            "pos": [px, py], "biome": a["biome"], "good": good,
            "yield_qty": k["qty"] if good else 0, "yield_silver": k["silver"],
            "upkeep": k["upkeep"], "danger": danger, "lore": lore,
        })
    data = {
        "version": "v9.3-territory-1",
        "kinds": {k: {"zh": v["zh"]} for k, v in KINDS.items()},
        "rules": {
            "garrison_max": 3, "garrison_cost": 40, "garrison_upkeep": 4,
            "contest_base": 0.05, "contest_per_danger": 0.02, "contest_per_garrison": 0.02,
            "contest_watchtower": 0.03, "contest_rival_near": 0.04, "contest_cap": 0.2,
            "threat_days": 30, "hold_per_garrison": 0.25, "hold_base": 0.1,
            "unrest_months": 2, "req_nation_rep": 10, "req_nation_rep_hostile": 30,
            "max_sites": 8, "sell_rate": 0.7,
        },
        "sites": sites,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("territory sites:", len(sites))


if __name__ == "__main__":
    main()
