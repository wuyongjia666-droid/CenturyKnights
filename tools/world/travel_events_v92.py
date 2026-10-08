# -*- coding: utf-8 -*-
"""Atlas road encounters (CMP-09).

Eighteen legacy beats stay, with a consequence on every option. Thirty nation beats
(three each), three landbridge beats, and three sea-lane beats bring the catalog to 54.
Prose is original to CenturyKnights. Do not copy festival names or proper nouns from
reference games. Anti-trope words from docs/art/style-lock-v89.json apply to title,
text, and option labels.
"""


def _o(label, fx):
    return {"label": label, "fx": fx}


def _e(eid, title, text, kinds, options, weight=4, min_danger=0, biomes=None, nations=None):
    row = {
        "id": eid,
        "title": title,
        "text": text,
        "weight": weight,
        "min_danger": min_danger,
        "kinds": kinds,
        "options": options,
    }
    if biomes:
        row["biomes"] = biomes
    if nations:
        row["nations"] = nations
    return row


def _nat(nid, eid, title, text, options, weight=3, min_danger=0, kinds=None):
    return _e(eid, title, text, kinds or ["road", "border"], options, weight, min_danger, nations=[nid])


TRAVEL_EVENTS = [
    _e("ambush", "伏击", "道旁林影一动——{foe}早已埋伏在此。", ["road", "border"], [
        _o("列阵迎战", {"battle": "ambush"}),
        _o("丢下部分货物脱身", {"lose_cargo": 0.3, "morale": -2}),
    ], weight=10, min_danger=1),
    _e("toll", "拦路收银", "一伙人横在路中：「过路银，{toll} 两。」", ["road", "border"], [
        _o("付银了事", {"silver": "-toll"}),
        _o("拔刀", {"battle": "toll"}),
    ], weight=8, min_danger=1),
    _e("merchant", "行商", "一位行商赶着驮兽同路，愿意低价出手一批{good}。", ["road", "border", "sea"], [
        _o("买下（7 折）", {"buy_deal": 0.7}),
        _o("道别", {"flag": "road_merchant_passed"}),
    ], weight=9),
    _e("refugees", "难民", "一队难民向你们讨粮，孩子们看着军旗。", ["road", "border"], [
        _o("分出 6 份粮", {"food": -6, "rep_nation": 4, "morale": 1}),
        _o("继续赶路", {"morale": -1}),
    ], weight=6),
    _e("shrine", "路边小祠", "古祠里还有人添灯。歇一歇脚？", ["road"], [
        _o("歇息疗伤（+1 日）", {"heal": 0.35, "days": 1}),
        _o("上香祈愿", {"morale": 2}),
    ], weight=6),
    _e("storm", "恶劣天气", "{weather}压了下来，前路难辨。", ["road", "border"], [
        _o("就地扎营（+1 日）", {"days": 1}),
        _o("花 12 银借宿农家", {"silver": -12}),
    ], weight=7),
    _e("crate", "遗落货箱", "翻倒的货车旁散着几箱{good}，主人不知去向。", ["road"], [
        _o("收下", {"gain_good": 3, "rep_nation": -1}),
        _o("交给下一座城的巡卫", {"rep_dest": 3}),
    ], weight=5),
    _e("patrol", "巡逻队盘查", "{nation}巡逻队拦下了你们，要查文书。", ["road", "border"], [
        _o("出示佣兵契", {"patrol": True}),
        _o("塞 15 银", {"silver": -15, "rep_nation": 1}),
    ], weight=6),
    _e("merc", "落单佣兵", "一名落单的佣兵坐在路边磨刀，打量着你们的旗。", ["road", "border"], [
        _o("邀其入团（{hire} 银）", {"recruit": True}),
        _o("点头而过", {"flag": "road_merc_passed"}),
    ], weight=4),
    _e("rumor", "茶摊传闻", "茶摊老板压低声音：{tip}", ["road", "border", "sea"], [
        _o("记下", {"tip": True}),
        _o("只当闲话", {"flag": "road_rumor_idle", "morale": -1}),
    ], weight=6),
    _e("herbs", "野生药草", "路旁坡地长满了药草。", ["road"], [
        _o("采集（+1 日，+3 药材）", {"herb": 3, "days": 1}),
        _o("不耽搁", {"flag": "road_herbs_skipped"}),
    ], weight=4, biomes=["fog", "plain", "hill", "shrine", "marsh", "ford"]),
    _e("bridge", "断桥", "桥被冲垮了一半。", ["road"], [
        _o("绕路（+1 日）", {"days": 1}),
        _o("出 15 银雇人修桥", {"silver": -15, "rep_nation": 3}),
    ], weight=4, biomes=["ford", "marsh", "pass", "harbor"]),
    _e("caravan", "同路商队", "一支商队请求同行，愿付护送费。", ["road", "border"], [
        _o("同行护送（+20 银，伏击风险）", {"silver": 20, "risk": 0.35}),
        _o("婉拒", {"flag": "road_caravan_declined"}),
    ], weight=5, min_danger=1),
    _e("deserters", "逃兵", "一群逃兵占了路边的驿亭，正在抢劫旅人。", ["road", "border"], [
        _o("驱逐他们", {"battle": "deserters", "rep_nation_win": 5}),
        _o("避开", {"days": 1}),
    ], weight=5, min_danger=2),
    _e("omen", "异兆", "夜空里{omen}。老兵说这是好兆头。", ["road", "sea"], [
        _o("全军振奋", {"morale": 3}),
        _o("记入路引批注", {"flag": "road_omen_logged", "sp": 1}),
    ], weight=3),
    _e("rival_scouts", "朔影探子", "几个朔影探子尾随你们多时。", ["road", "border"], [
        _o("反包围", {"battle": "scouts"}),
        _o("放出假消息（-10 银）", {"silver": -10, "rep_nation": 1}),
    ], weight=6, nations=["shuoying", "ashbanner", "frostcrown"]),
    _e("sea_storm", "海上风暴", "风暴把船推离了航线。", ["sea"], [
        _o("硬扛（+2 日）", {"days": 2}),
        _o("抛货减重", {"lose_cargo": 0.25}),
    ], weight=10),
    _e("fair", "集会消息", "前方{dest}正逢集会，商人们说货价会涨。", ["road", "border", "sea"], [
        _o("加快脚步", {"fair": True}),
        _o("先去粮栈补货", {"food": 4, "days": 1}),
    ], weight=4),

    # ── 灰烬邦 ──
    _nat("ashbanner", "ash_false_receipt", "灰市假收据",
         "灰市账房门口有人兜售盖着烬纹的过路收据，墨迹还没干。", [
             _o("买下当路引", {"silver": -18, "flag": "ash_false_receipt_bought"}),
             _o("揭穿并交给巡卫", {"rep_nation": 3, "morale": 1}),
             _o("当作没听见", {"flag": "ash_false_receipt_ignored", "morale": -1}),
         ]),
    _nat("ashbanner", "ash_night_ferry", "苇原夜船",
         "苇原渡的船工想连夜把粮袋送过发光河，求你们压一趟舱。", [
             _o("上船押运", {"silver": 16, "risk": 0.25}),
             _o("留下守渡口", {"rep_dest": 3, "days": 1}),
         ]),
    _nat("ashbanner", "ash_quarry_knock", "石垒洞响",
         "石垒坡的采石洞里有人敲壁，分不清是匠人还是躲进去的剪径者。", [
             _o("进洞查看", {"battle": "quarry"}),
             _o("封上洞口再报官", {"rep_nation": 2, "days": 1}),
         ]),

    # ── 朔影国 ──
    _nat("shuoying", "sy_weapon_roll", "夜阙兵器名录",
         "夜阙关卒把一本兵器名录摊在灯下，要你们逐件对上号。", [
             _o("配合点验", {"days": 1, "rep_nation": 2}),
             _o("塞银省事", {"silver": -20, "flag": "sy_roll_bribe"}),
         ]),
    _nat("shuoying", "sy_lost_packs", "寒垒驮队",
         "寒垒的补给驮队在霜脊上散了，护队只找回一半驮兽。", [
             _o("帮他们把货拢回", {"rep_nation": 4, "morale": 1}),
             _o("只护送人，货留给风", {"days": 1, "flag": "sy_packs_left"}),
         ]),
    _nat("shuoying", "sy_ice_smuggle", "冷湾冰下灯",
         "冷湾渔民说冰层下有一串不该出现的灯，像走私船在贴着冰走。", [
             _o("凿冰截停", {"battle": "ice_lamp", "rep_nation_win": 4}),
             _o("把坐标卖给港吏", {"silver": 14, "rep_nation": -2}),
         ]),

    # ── 清河国 ──
    _nat("qinghe", "qh_dye_upstream", "浮洲水色",
         "浮洲染坊的水一夜变深，工头说上游有人倒了不该倒的料。", [
             _o("沿河去看一眼", {"days": 1, "rep_dest": 3}),
             _o("分出药材给染工", {"herb": -2, "rep_nation": 2}),
         ]),
    _nat("qinghe", "qh_wrong_chart", "错抄的河道图",
         "玉澜书院的学徒把河道图抄反了左右，正本还在雾果村的驿柜里。", [
             _o("绕去取回正本", {"days": 1, "rep_nation": 3}),
             _o("按错图走", {"flag": "qh_wrong_chart", "morale": -1}),
         ]),
    _nat("qinghe", "qh_orchard_fog", "雾果林打转",
         "一队收果的人在雾果林里打转，把你们的旗当成了渡口的灯。", [
             _o("带他们出林", {"days": 1, "food": -3, "rep_dest": 2}),
             _o("把路引抄给他们", {"flag": "qh_fog_copy", "morale": 1}),
         ]),

    # ── 灯市联 ──
    _nat("lantern", "lt_remarked_price", "灯价被涂改",
         "灯市的价牌被人连夜涂过，同一盏琉璃灯写着两个数。", [
             _o("按低价收一批", {"buy_deal": 0.6}),
             _o("叫来市吏对牌", {"rep_nation": 3, "flag": "lt_price_reported"}),
         ]),
    _nat("lantern", "lt_night_contract", "夜市契约",
         "掮客把一份只在灯亮时生效的契约塞过来，换你们下一座城的路引。", [
             _o("签字交换", {"silver": 12, "rep_nation": -1, "flag": "lt_contract_signed"}),
             _o("拒绝，并记住他的脸", {"flag": "lt_contract_refused", "morale": 1}),
         ]),
    _nat("lantern", "lt_dark_beacon", "熄掉的潮灯",
         "港外有一盏潮灯熄了，渔船在雾里互相喊号。", [
             _o("出人去把灯点上", {"days": 1, "rep_dest": 4}),
             _o("把自己的路灯借出", {"morale": 2, "flag": "lt_lamp_lent"}),
         ]),

    # ── 霜冕廷 ──
    _nat("frostcrown", "fc_bell_missed", "冰钟少了一声",
         "霜冕廷的冰钟这一时辰少了一声。街上的人都停下来听。", [
             _o("去钟楼问值钟人", {"rep_nation": 2, "days": 1}),
             _o("按旧节奏继续赶路", {"flag": "fc_bell_ignored", "morale": -1}),
         ]),
    _nat("frostcrown", "fc_quiet_escort", "静路仪仗",
         "廷里的仪仗要过路，要求所有兵器包进布套，一路不许说话。", [
             _o("照办", {"days": 1, "rep_nation": 3}),
             _o("绕开仪仗走坡路", {"days": 1, "flag": "fc_escort_detour"}),
         ]),
    _nat("frostcrown", "fc_crystal_letter", "裂开的霜晶",
         "路上一块霜晶自己裂开，里面是一封没署名的旧信，收信人是下一座城的库吏。", [
             _o("把信送到库吏", {"rep_dest": 4, "flag": "fc_letter_delivered"}),
             _o("读完烧掉", {"morale": 1, "flag": "fc_letter_burned", "rep_nation": -1}),
         ]),

    # ── 余烬旧邦 ──
    _nat("emberold", "eo_kiln_mark", "旧窑印",
         "窑匠捧出一块还温着的窑印，请你们辨它属于哪一座冷掉的窑。", [
             _o("对照路引上的窑号", {"rep_nation": 3, "days": 1}),
             _o("出银请师傅直接说", {"silver": -16, "flag": "eo_kiln_paid"}),
         ]),
    _nat("emberold", "eo_old_toll", "旧典过路礼",
         "废墟口有人按一本旧典收过路礼，数目写在陶片上，不是现在的税。", [
             _o("按陶片付银", {"silver": -14, "rep_nation": 1}),
             _o("拒绝旧典", {"flag": "eo_old_toll_refused", "morale": 1}),
         ]),
    _nat("emberold", "eo_glass_knock", "熔玻墙缝",
         "冷暮下的玻璃墙缝里有敲击，像有人被关在夹层里。", [
             _o("砸开夹层", {"battle": "glass_wall"}),
             _o("记下位置交给城防", {"rep_dest": 3, "flag": "eo_glass_reported"}),
         ]),

    # ── 盐泽盟 ──
    _nat("saltmarsh", "sm_short_warrant", "盐引缺角",
         "盐泽关卡说你们的盐引缺了一角印，潮水上来之前必须补上。", [
             _o("补印", {"silver": -12, "rep_nation": 2}),
             _o("等下一潮再过", {"days": 1, "flag": "sm_wait_tide"}),
         ]),
    _nat("saltmarsh", "sm_early_tide", "潮时提前",
         "潮水比告示早了半个时辰，旧路已经没到脚踝。", [
             _o("雇浅舟", {"silver": -10, "morale": 1}),
             _o("涉水硬走", {"days": 1, "food": -2, "flag": "sm_wade"}),
         ]),
    _nat("saltmarsh", "sm_reed_passenger", "芦雾里的搭船人",
         "芦雾里有人挥灯，想搭你们的船过一条正在涨的潮沟。", [
             _o("让他上船", {"days": 1, "rep_nation": 2, "morale": 1}),
             _o("留下干粮让他等退潮", {"food": -4, "flag": "sm_left_rations"}),
         ]),

    # ── 铁峡领 ──
    _nat("irongorge", "ig_cable", "吊桥少索",
         "铁峡中层吊桥少了一根钢索，桥面会在下一个人踩上去时偏一掌。", [
             _o("出峡钢补索", {"iron": -2, "rep_dest": 4}),
             _o("贴告示绕下层", {"days": 1, "flag": "ig_cable_posted"}),
         ]),
    _nat("irongorge", "ig_shift_slip", "班次送错城",
         "锻炉学徒把今夜的换班表送到了你们手里，表上的城不是这座。", [
             _o("送回正确的炉区", {"days": 1, "rep_nation": 3}),
             _o("把表卖给对头炉", {"silver": 18, "rep_nation": -3, "flag": "ig_shift_sold"}),
         ]),
    _nat("irongorge", "ig_night_ingot", "夜运峡钢",
         "峡谷吊篮里有人在关灯之后往下运峡钢锭，没有税牌。", [
             _o("截住盘问", {"battle": "ingot", "rep_nation_win": 4}),
             _o("换一笔封口银", {"silver": 22, "rep_nation": -2, "flag": "ig_ingot_hush"}),
         ]),

    # ── 星津邦 ──
    _nat("starriver", "sr_star_off", "星位不符",
         "观象台说今夜的星位和你们路引上抄的那一宿对不上。", [
             _o("留下来重抄路引", {"days": 1, "rep_nation": 2, "sp": 1}),
             _o("按旧路引走", {"flag": "sr_old_chart", "morale": -1}),
         ]),
    _nat("starriver", "sr_bridge_clerk", "双虹桥文书",
         "双虹桥的桥吏不收过桥银，只收一份写明星位的过桥文书。", [
             _o("现写一份", {"days": 1, "rep_dest": 2}),
             _o("花银请代书", {"silver": -15, "flag": "sr_clerk_paid"}),
         ]),
    _nat("starriver", "sr_wrong_boat", "记错的船号",
         "夜河渡手把你们的船号记成了邻国商队的号，货栈正准备错发。", [
             _o("当场更正", {"rep_nation": 2, "flag": "sr_boat_fixed"}),
             _o("领走邻队的一箱货", {"gain_good": 2, "rep_nation": -2}),
         ]),

    # ── 南泽邦 ──
    _nat("southzephyr", "sz_ferry_fog", "萤雾吞了渡灯",
         "渡口的灯被萤雾吞了，对岸的船在喊，却看不见缆。", [
             _o("举旗给对岸对准", {"days": 1, "rep_dest": 3}),
             _o("雇熟悉雾路的渡手", {"silver": -12, "morale": 1}),
         ]),
    _nat("southzephyr", "sz_wax_short", "蜂蜡短两块",
         "货栈说你们名下的蜂蜡短了两块，账是昨晚才改的。", [
             _o("补上差额", {"silver": -8, "rep_nation": 1}),
             _o("要求对账", {"days": 1, "flag": "sz_wax_audit"}),
         ]),
    _nat("southzephyr", "sz_pepper_tail", "循椒而来",
         "有人循着南椒的气味跟了你们一夜，脚步很轻，不像劫道。", [
             _o("回头问清楚并邀入团", {"recruit": True, "flag": "sz_pepper_joined"}),
             _o("甩掉他们", {"days": 1, "flag": "sz_pepper_lost", "morale": -1}),
         ]),

    # ── 朔澜陆桥 ──
    _nat("landbridge", "lb_banner_check", "过桥符",
         "陆桥驿卒要核验灰旗的过桥符，符上的日期还是上一旬。", [
             _o("补办", {"days": 1, "silver": -8, "rep_nation": 2}),
             _o("走货运桥洞绕过", {"flag": "lb_under_bridge", "morale": -1}),
         ]),
    _nat("landbridge", "lb_fallen_stone", "桥面新石",
         "陆桥中段多了一块不该有的落石，石上还沾着东岸的泥。", [
             _o("搬开并记下缺口", {"days": 1, "rep_dest": 3}),
             _o("留下标记连夜通过", {"flag": "lb_stone_marked", "morale": 1}),
         ]),
    _nat("landbridge", "lb_pass_mismatch", "两陆关牒",
         "东岸关牒和西岸关牒对不上同一个商队的名字，驿吏请你们作个见证。", [
             _o("留下作见证", {"days": 1, "rep_nation": 4}),
             _o("两头都不沾", {"flag": "lb_pass_skipped", "morale": -1}),
         ]),

    # ── 海路 ──
    _e("sea_beacon", "漂离的航标", "一盏航标漂离了原位，夜航的船会把它当成下一港的灯。", ["sea"], [
        _o("把它拖回原位", {"silver": -6, "rep_nation": 3, "days": 1}),
        _o("记下偏位，到港再报", {"flag": "sea_beacon_logged", "morale": 1}),
    ], weight=6),
    _e("sea_ballast", "压舱争议", "船主要把你们的货算进压舱，说这样风暴里船才稳。", ["sea"], [
        _o("同意用货压舱", {"lose_cargo": 0.2, "morale": 1, "flag": "sea_ballast_agreed"}),
        _o("出银加真正的压石", {"silver": -18, "flag": "sea_ballast_paid"}),
    ], weight=6),
    _e("sea_quiet_due", "静港银", "水手说下一港在收一笔不写进税牌的静港银，不付就让你在雾里多停一夜。", ["sea"], [
        _o("付掉", {"silver": -16, "flag": "sea_quiet_paid"}),
        _o("不付，在雾里多停", {"days": 2, "flag": "sea_quiet_refused", "morale": -1}),
    ], weight=5),
]
