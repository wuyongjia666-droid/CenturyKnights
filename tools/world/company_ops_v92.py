# -*- coding: utf-8 -*-
"""CMP-04 world-internal content: one scripted contract chain per nation, and rival companies.

Objective-typed commissions (siege relief, duel, rescue, escort battle, intel race) stay out
until BTL-02 lands victory conditions. These chains use the existing deliver / escort / scout
turn-in rules so they can be walked inside world.gd.

Do not full-regenerate world_v87.json from gen_world_v87.py: commission base silver in that
generator is still the pre-v9.1 table.
"""


def _step(kind, issuer, target, title, brief):
    return {
        "kind": kind,
        "issuer": issuer,
        "target": target,
        "title": title,
        "brief": brief,
    }


def _chain(cid, nation, title, steps):
    return {"id": cid, "nation": nation, "title": title, "steps": steps}


CONTRACT_CHAINS = [
    _chain("chain_ash", "ashbanner", "烬纹三程", [
        _step("deliver", "ash_capital", "reed_ford", "白垣的未签字账", "议会账房少了一本没签字的过路账。送到苇原渡的船工手里，让他核对夜航的粮袋。"),
        _step("deliver", "reed_ford", "stone_slope", "苇原的回执", "船工在回执上画了渡口的水位。石垒坡的采石匠要拿它去对洞口的工期。"),
        _step("deliver", "stone_slope", "fog_vale", "石垒的样本", "采石匠封了一小袋石粉，雾谷的药户要用它试井水。"),
        _step("deliver", "fog_vale", "ash_market", "雾谷的结算单", "药户把结算单交给灰市账房。这本账从白垣走到这里，才算合上。"),
    ]),
    _chain("chain_sy", "shuoying", "夜阙点名", [
        _step("deliver", "sy_capital", "sy_stair", "兵器名录的副本", "夜阙把外来兵器名录的副本交到千阶城，上层要亲自看。"),
        _step("deliver", "sy_stair", "sy_coast", "千阶的夜航许可", "千阶城开了一张只在入夜后有效的出海许可，冷湾的港吏认这个印。"),
        _step("deliver", "sy_coast", "sy_ridge", "冷湾的冰情", "港吏把冰层厚度写在一张布上。狼脊村的猎人要按它改猎线。"),
        _step("deliver", "sy_ridge", "sy_frostfort", "狼脊的回报", "猎人把改过的猎线交回寒垒。点名从夜阙开始，在军垒结束。"),
    ]),
    _chain("chain_qh", "qinghe", "河道正本", [
        _step("deliver", "qh_capital", "qh_isle", "抄反的河道图", "书院学徒把左右抄反了。正本要先送到浮洲，染坊靠这条河吃饭。"),
        _step("deliver", "qh_isle", "qh_orchard", "浮洲的水色样本", "染工封了一小瓶上游的水。粉霞坞的果户要看它会不会伤花。"),
        _step("deliver", "qh_orchard", "qh_mist", "花坞的勘误", "果户在图边上标了三处雾里会消失的渡口。送回雾果村的驿柜。"),
    ]),
    _chain("chain_lt", "lantern", "灯价五夜", [
        _step("deliver", "lt_capital", "lt_harbor", "被涂改的价牌", "夜市同一盏灯写了两个价。把原牌送到港上，让船主按旧价装货。"),
        _step("deliver", "lt_harbor", "lt_isle", "港上的夜契", "船主签了一份只在灯亮时生效的短契。岛上的琉璃匠要看条款。"),
        _step("deliver", "lt_isle", "lt_south", "岛上的灯芯清单", "匠人列出熄过的潮灯。南岸的市吏负责把它们点回去。"),
        _step("deliver", "lt_south", "lt_lane", "南岸的对牌记录", "市吏的对牌记录要交给巷里的账房，避免明天再被涂掉。"),
        _step("deliver", "lt_lane", "lt_docks", "巷里的静港账", "账房不肯把这笔写进税牌。码头只收这份私下的账，五夜到此为止。"),
    ]),
    _chain("chain_fc", "frostcrown", "冰钟四响", [
        _step("deliver", "fc_capital", "fc_tower", "少了一声的钟谱", "这一时辰冰钟少了一声。把钟谱送到塔上，问值钟人缺的是哪一拍。"),
        _step("deliver", "fc_tower", "fc_lake", "值钟人的批注", "值钟人在谱边写了风从湖上来。湖畔的库吏要按它改开门的时辰。"),
        _step("deliver", "fc_lake", "fc_peak", "库吏的旧信", "霜晶裂开时露出的旧信，库吏请你带到峰上的观测点。"),
        _step("deliver", "fc_peak", "fc_banner", "峰上的时辰", "观测点确认了少掉的那一声。把更正后的时辰交到关楼，仪仗才重新上路。"),
    ]),
    _chain("chain_eo", "emberold", "冷窑四印", [
        _step("deliver", "eo_capital", "eo_kiln", "没对上的窑印", "城档里有一块对不上号的窑印。送到还温着的窑，让师傅认。"),
        _step("deliver", "eo_kiln", "eo_shrine", "师傅的窑号", "师傅指出它属于一座已经冷掉的窑。祠边的守档人收这个号。"),
        _step("deliver", "eo_shrine", "eo_crack", "旧典的陶片", "守档人从旧典里抄下一片过路数目。废墟口的人在按这片陶片收费。"),
        _step("deliver", "eo_crack", "eo_glass", "废墟的勘误", "把陶片上的数目更正，交到玻璃城的城防。夹层里的敲击不归旧典管。"),
    ]),
    _chain("chain_sm", "saltmarsh", "盐印四潮", [
        _step("deliver", "sm_capital", "sm_mid", "缺角的盐引", "关卡说盐引缺了一角。中段的潮吏有补印的模。"),
        _step("deliver", "sm_mid", "sm_banner", "补好的一角", "潮吏补了印。关楼上的人要在下一潮之前核过。"),
        _step("deliver", "sm_banner", "sm_south", "关楼的潮时", "核过的潮时和告示差了半个时辰。南岸的船要按新的时辰走。"),
        _step("deliver", "sm_south", "sm_west", "南岸的干粮账", "船走了，岸上留下等退潮的人。把干粮账交回西岸，盐引这才算完整。"),
    ]),
    _chain("chain_ig", "irongorge", "峡索四班", [
        _step("deliver", "ig_capital", "ig_tower", "少了一根的索册", "中层吊桥少了一根钢索。索册要先送到塔上的值桥人。"),
        _step("deliver", "ig_tower", "ig_bottom", "值桥人的班表", "值桥人的今夜班表被送到了错的城。底层炉区才是正主。"),
        _step("deliver", "ig_bottom", "ig_lower", "底层的钢印", "炉区在班表上盖了钢印。下层吊篮的人要拿它核对夜运。"),
        _step("deliver", "ig_lower", "ig_mine", "吊篮的税牌", "没有税牌的峡钢锭不该出矿。把税牌送到矿口，这一班才算闭。"),
    ]),
    _chain("chain_sr", "starriver", "星位四宿", [
        _step("deliver", "sr_capital", "sr_pagoda", "对不上的路引", "观象台说今夜星位和路引差了一宿。把路引送到塔上重抄。"),
        _step("deliver", "sr_pagoda", "sr_east", "重抄的星位", "塔上抄好的星位要交给东桥的桥吏，他只收写明了星位的文书。"),
        _step("deliver", "sr_east", "sr_south", "桥吏的船号", "桥吏发现船号被记成了邻队的。南岸货栈正准备错发。"),
        _step("deliver", "sr_south", "sr_west", "更正后的船号", "货栈更正了船号。西岸的渡手要按新号靠岸。"),
    ]),
    _chain("chain_sz", "southzephyr", "萤雾四渡", [
        _step("deliver", "sz_capital", "sz_harbor", "被雾吞掉的渡灯图", "渡口的灯进了萤雾。把灯位图送到港上，让对岸的船对准。"),
        _step("deliver", "sz_harbor", "sz_isle", "港上的蜂蜡账", "货栈说蜂蜡短了两块。岛上的仓要按昨晚的账重称。"),
        _step("deliver", "sz_isle", "sz_south", "仓里的椒引", "重称之后多出来的南椒引，南岸的人循着气味跟了一夜。把引子交给他们的头。"),
        _step("deliver", "sz_south", "sz_bamboo", "南岸的雾路", "头目把一条只在雾里看得见的小路画下来。竹林驿要收这张图，四渡才算完。"),
    ]),
]


RIVAL_COMPANIES = [
    {
        "id": "night_ledger",
        "name": "夜账行",
        "home": "lt_capital",
        "price_mul": 1.2,
        "blurb": "灯市出身的账房佣兵。他们不抢货，抢的是别人已经贴出来的护送单，再把城里的买价抬一成。",
    },
    {
        "id": "bridge_bone",
        "name": "桥骨团",
        "home": "lb_mid",
        "price_mul": 1.2,
        "blurb": "长年睡在陆桥驿棚的老团。委托榜一换，他们的旗比雇主的信使先到。",
    },
    {
        "id": "frost_blade",
        "name": "霜刃伙",
        "home": "fc_capital",
        "price_mul": 1.2,
        "blurb": "从霜冕廷下来的散团。遇见别的旗就要求让路，不让就在原地开打。",
    },
    {
        "id": "salt_crow",
        "name": "盐鸦队",
        "home": "sm_capital",
        "price_mul": 1.2,
        "blurb": "盐泽的船佣兵。潮一起他们就改道，专截送达和收购，把岸上的价一起带高。",
    },
]
