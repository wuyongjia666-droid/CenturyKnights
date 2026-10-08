#!/usr/bin/env python3
"""Author the v8.9 multi-trait royal sets into bloodlines_v89.json and the design-doc tables.

Re-run after editing the spec below. Trait loci are appended after the original ten
signature loci; this script never reorders those ten.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "project/data/bloodlines_v89.json"
LOCK = ROOT / "docs/art/style-lock-v89.json"
DOC = ROOT / "docs/design/bloodlines-v89.md"

NATION_ORDER = [
    "ashbanner", "shuoying", "qinghe", "lantern", "frostcrown",
    "emberold", "saltmarsh", "irongorge", "starriver", "southzephyr",
]
ROYAL_LINE = {
    "ashbanner": "ash_chart", "shuoying": "sy_eclipse", "qinghe": "qh_jade", "lantern": "lt_filament",
    "frostcrown": "frost_crown", "emberold": "eo_kiln", "saltmarsh": "sm_tide", "irongorge": "ig_gorge",
    "starriver": "sr_dipper", "southzephyr": "sz_firefly",
}
MARK = {
    "ashbanner": "river_chart", "shuoying": "eclipse_full", "qinghe": "jade_lock", "lantern": "filament",
    "frostcrown": "rime_lash", "emberold": "kiln_crackle", "saltmarsh": "tide_ring", "irongorge": "gorge_split",
    "starriver": "qi_xing", "southzephyr": "firefly",
}


def T(slot, law, kind, i, zh, en, vis, desc, prompt, young, elder, **k):
    row = {
        "slot": slot, "law": law, "kind": kind, "id": i, "zh": zh, "en": en, "vis": vis,
        "desc": desc, "prompt": prompt, "young": young, "elder": elder,
    }
    row.update(k)
    return row


def N(i, zh, en, vis, desc, prompt, young, elder):
    return {"id": i, "zh": zh, "en": en, "vis": vis, "desc": desc, "prompt": prompt, "young": young, "elder": elder}


# Royal slots are the coordinated set. `noble` is the high-house echo on the SAME locus.
# Unique noble / folk loci are listed separately so they do not dilute the royal allele.
HOUSES = [
    {
        "id": "ashbanner", "name": "灰烬邦",
        "noble_line": "banner_marshal", "noble_mark": "chart_trunk", "folk_line": "common_ash",
        "why": "河网图的人：墨发里夹一条灰纹，眼睛里一根石墨辐，脸是低而宽的平原骨，肤色暖泥，立功之后下颌才浮出冷灰。",
        "traits": [
            T("hair", "dominant", "diploid", "ash_wire", "烬丝发", "ink wire-crop", "overt",
              "粗硬墨发，脑后平切，额前一道灰纹。",
              "coarse ink-black hair cut blunt at the nape, with one ash-grey forelock stripe",
              "short soft ink-black hair, the ash forelock only a faint thread",
              "thinned ink-black hair, the forelock stripe wider and frost-silver at the roots",
              noble=N("ash_crop", "旗裁发", "marshal crop", "overt", "墨发平切到下颌，没有额纹。",
                      "ink-black hair cut blunt at the jaw, with no forelock stripe",
                      "a soft jaw-length ink crop, still uneven in youth",
                      "a jaw-length ink crop gone thin at the temples with age")),
            T("iris", "recessive", "diploid", "ash_spoke", "石墨辐", "graphite iris spoke", "subtle",
              "炭黑虹膜里，七点钟方向一根石墨色辐条。近看才稳。",
              "charcoal irises with a single graphite spoke at seven o'clock",
              "dark irises, the graphite spoke only a short tick in youth",
              "charcoal irises, the graphite spoke longer and paler with age",
              catch=True),
            T("bone", "threshold", "value", "ash_bone", "阔梁灰面", "wide low brow shelf", "subtle",
              "眉骨低平、鼻梁宽、颊面平、下巴方。玉值式的骨相，过槛才完整。",
              "a low straight brow shelf, a wide nasal bridge, flat cheek planes and a squared chin",
              "a softer wide face, the brow shelf not yet heavy in youth",
              "the brow shelf heavier, cheek planes hollower, chin still square in age",
              catch=True,
              noble=N("ash_jaw", "厚颌", "heavy marshal jaw", "subtle", "下颌厚，眉骨还没有王族那么低。",
                      "a heavy jaw and a moderate brow shelf, cheeks still full",
                      "a heavy jaw still padded with youth",
                      "a heavy jaw, the cheek softer and lined with age")),
            T("skin", "age_awakened", "diploid", "ash_jawcast", "冷颌", "cool jaw cast", "overt",
              "暖泥肤。二十八岁后下颌浮出冷灰，此前看不出来。",
              "warm clay skin with a cool grey cast along the jaw",
              "even warm clay skin, the jaw still the same tone as the cheek",
              "warm clay skin, the cool grey jaw cast deeper, with a silver-violet thread at the hairline",
              age_min=28),
            T("bearing", "penetrance", "diploid", "ash_hook", "钩领势", "collar-hook stance", "overt",
              "重心在后脚，下颌平，右手拇指扣着领缘。约六成外显。",
              "weight on the back foot, chin level, right thumb hooked on the collar edge, voice in short clipped orders",
              "the back-foot stance loose, the thumb hook not yet a habit in youth",
              "the back-foot stance deeper, the thumb hook stiff, the voice lower and shorter with age",
              bark="旗在左。"),
            T("regalia", "dominant", "diploid", "ash_cloak", "开领短氅", "open-collar short cloak", "overt",
              "左领敞开的短灰氅，霜银发丝压边。衣冠是家传的披法，不是冠。",
              "a short ash cloak, collar open on the left, frost-silver hairline trim on matte technical cloth",
              "the same short ash cloak worn a little large, trim still bright in youth",
              "the short ash cloak worn thinner at the edge, trim dulled to brushed frost metal with age",
              modules=["regalia_ash_collar", "regalia_ash_cloak"],
              palette={"cloth": "#1C2330", "trim": "#9AA6B8", "metal": "#C9D3DE"}),
            T("pure", "pureblood", "diploid", "ash_pure", "双烬纹", "split forelock pure mark", "overt",
              "颈纹延伸到锁骨，额纹分成平行两股。只在河图已显且两份纯血等位时出现。",
              "the neck tracery continues onto the collarbone and the ash forelock stripe splits into two parallel threads",
              "the split forelock threads are short, the collarbone tracery faint in a young pure line",
              "the split forelock threads are frost-silver and the collarbone tracery deeper with age"),
        ],
        "unique": T("bearing", "dominant", "diploid", "marshal_strap", "肩革痕", "strap pressure line", "subtle",
                    "左肩一道皮带压出来的浅痕，皮略厚。旗帅自家的征，不是河图。",
                    "a pale pressure line on the left shoulder where a strap sits, the skin there slightly thickened",
                    "a faint shoulder pressure line, not yet thickened in youth",
                    "a pale shoulder pressure line, the skin thicker and a little creased with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_ash_hair", "风剪灰棕", "weather-cropped ash hair", "overt",
              "风剪过的灰棕发，后颈参差。",
              "ash-brown hair cropped by weather, uneven at the nape",
              "softer ash-brown hair, the nape still uneven in youth",
              "ash-brown hair thinner and more uneven at the nape with age"),
            T("skin", "dominant", "diploid", "folk_ash_skin", "暖泥肤", "plain clay skin", "overt",
              "暖泥肤，下颌没有冷灰。",
              "warm clay skin with no grey cast along the jaw",
              "even warm clay skin, smoother in youth",
              "warm clay skin, more creased at the eyes with age, still no grey jaw cast"),
            T("bone", "dominant", "diploid", "folk_ash_bone", "劳作宽颌", "work-broad jaw", "overt",
              "劳作出来的宽下颌，眉骨低，颊有日晒纹。",
              "a broad work-worn jaw and a low brow, cheeks creased by weather",
              "a broad jaw still soft, the brow not yet low in youth",
              "a broader jaw, the brow lower and the cheeks more lined with age"),
        ],
    },
    {
        "id": "shuoying", "name": "朔影国",
        "noble_line": "sy_night", "noble_mark": "eclipse_crescent", "folk_line": "sy_ridge",
        "why": "日食瞳之外还有一整张夜的脸：几何墨裁、灰巩膜、窄高鼻梁、冷橄榄肤，年纪到了才把眨眼压慢。",
        "traits": [
            T("hair", "recessive", "diploid", "sy_geom", "几何墨裁", "geometric ink cut", "overt",
              "蓝黑直发中分，齐到下颌，切线几何。两份才显。",
              "straight blue-black hair, centre-parted, cut on a geometric line at the jaw",
              "shorter blue-black hair, the jaw line not yet exact in youth",
              "blue-black hair still geometric, with a dull silver thread at the part in age",
              noble=N("sy_crop", "夜裁", "night crop", "overt", "墨发短于下颌，不是几何齐切。",
                      "straight black hair cut shorter than the jaw, not a geometric line",
                      "a soft black crop above the jaw in youth",
                      "a black crop, slightly receded at the temples with age")),
            T("iris", "dominant", "diploid", "sy_sclera", "灰巩膜", "dusk-grey sclera", "subtle",
              "巩膜是暮灰而不是白，不充血。近看，和银环不是同一征。",
              "dusk-grey sclera rather than white, never bloodshot, a quiet field around the iris",
              "sclera only a shade off white in youth",
              "sclera a deeper dusk-grey, still clear, in age",
              catch=True),
            T("bone", "threshold", "value", "sy_bridge", "窄高梁", "narrow high bridge", "subtle",
              "窄脸、高鼻梁、颊浅、人中长。",
              "a narrow face, a high nasal bridge, shallow cheeks and a long philtrum",
              "a narrow face still soft, the bridge not yet high in youth",
              "a narrower face, cheeks hollower, the bridge sharper with age",
              catch=True,
              noble=N("sy_cheek", "浅颊", "shallow court cheek", "subtle", "颊浅，鼻梁还没有王室那么高。",
                      "shallow cheeks and a straight nose, the bridge not yet high",
                      "shallow cheeks still rounded in youth",
                      "shallower cheeks and a finer nose with age")),
            T("skin", "dominant", "diploid", "sy_olive", "冷橄榄", "cool olive-slate skin", "overt",
              "冷橄榄带石板灰，不是苍白。",
              "cool olive-slate skin, matte, not pale",
              "cool olive-slate skin, a little warmer and smoother in youth",
              "cooler olive-slate skin, drier at the cheek, in age"),
            T("bearing", "age_awakened", "diploid", "sy_still", "静视", "still gaze", "overt",
              "二十二岁后视线放稳，少眨眼，嘴角不单侧上扬。",
              "a still gaze, a low blink, no one-sided smile, voice measured and quiet",
              "an ordinary blink and a mouth that still moves freely in youth",
              "a stiller gaze, an even lower blink, the voice thinner with age",
              age_min=22, bark="灯灭了。"),
            T("regalia", "x_dominant", "x", "sy_collar", "窄银领", "narrow frost collar band", "overt",
              "窄霜银领，衣身墨色，一条竖向霜线。父传全女。",
              "a narrow frost-silver collar band on an ink coat, one vertical frost stitch, matte cloth",
              "the narrow collar band worn slightly loose in youth",
              "the narrow collar band still exact, the frost stitch dulled with age",
              modules=["regalia_sy_collar", "regalia_sy_cloak"],
              palette={"cloth": "#07080C", "trim": "#C9D3DE", "metal": "#6ED4FF"}),
            T("pure", "pureblood", "diploid", "sy_pure", "双银环", "double eclipse ring", "overt",
              "瞳外银环变成同心两圈。须全朔已显且两份纯血。",
              "two thin concentric pale-silver rings around each pupil, the outer ring finer than the inner",
              "the outer silver ring only a broken arc in a young pure line",
              "both silver rings complete and a little brighter against dusk-grey sclera in age"),
        ],
        "unique": T("iris", "dominant", "diploid", "sy_canthus", "外眦银点", "outer-canthus silver tick", "subtle",
                    "外眼角一点霜银，不是环。",
                    "one pale-silver tick at the outer corner of each eye, not a ring",
                    "a tiny pale tick at the outer eye corner, easy to miss in youth",
                    "a slightly longer pale tick at the outer eye corner in age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_sy_hair", "靛兜发", "hood-line black hair", "overt",
              "直黑发，发际有深靛兜影。",
              "straight black hair with a deep indigo hood-line across the brow",
              "straight black hair, the indigo hood-line faint in youth",
              "straight black hair, the indigo hood-line wider with age"),
            T("skin", "dominant", "diploid", "folk_sy_skin", "风燎肤", "wind-burned slate skin", "overt",
              "风燎过的石板肤，鼻梁更暗。",
              "wind-burned slate skin, darker across the nose",
              "slate skin, the nose not yet darker in youth",
              "slate skin, the nose darker and the cheek drier with age"),
            T("bone", "dominant", "diploid", "folk_sy_bone", "短梁", "short ridge bridge", "overt",
              "鼻梁短、下颌紧，不像宫里的窄高脸。",
              "a short nasal bridge and a compact jaw, unlike the narrow court face",
              "a short bridge and a compact jaw still soft in youth",
              "a shorter-looking bridge and a more compact jaw with age"),
        ],
    },
    {
        "id": "qinghe", "name": "清河国",
        "noble_line": "river_ward", "noble_mark": "jade_sheen", "folk_line": "qh_delta",
        "why": "玉缕是发。其余是水梳过的墨发、虹膜上一圈软玉缘、细梁卵面，肤色的青灰只跟母亲走。",
        "traits": [
            T("hair", "dominant", "diploid", "qh_smooth", "顺水墨", "water-combed ink hair", "overt",
              "其余的发光滑如水梳过，右耳后一挽。圆耳。",
              "the rest of the hair smooth and water-combed, one tuck behind the right ear",
              "softer ink hair, the tuck loose and unfinished in youth",
              "water-combed ink hair, finer, the tuck still exact in age",
              noble=N("qh_tuck", "单挽", "single tuck", "overt", "右耳后一挽，发没有王族那么顺。",
                      "ink hair with one tuck behind the right ear, the lengths less smooth",
                      "a loose tuck behind the right ear in youth",
                      "a precise tuck, the hair finer with age")),
            T("iris", "recessive", "diploid", "qh_limbal", "玉缘瞳", "nephrite limbal ring", "subtle",
              "松绿灰虹膜，边缘一圈软玉色环。两份才显。",
              "pine-grey irises with a soft nephrite ring at the limbus",
              "pine-grey irises, the nephrite limbal ring only a faint arc in youth",
              "pine-grey irises, the nephrite limbal ring wider and softer with age",
              catch=True),
            T("bone", "threshold", "value", "qh_oval", "细梁卵面", "fine oval", "subtle",
              "窄卵面、颊峰低、鼻梁细直、下颌柔。",
              "a narrow oval face, a low cheek apex, a fine straight nose and a gentle jaw",
              "a narrow oval still rounder, the nose finer but short in youth",
              "a narrower oval, the cheek lower and the nose still fine in age",
              catch=True,
              noble=N("qh_lowcheek", "低颊", "low cheek", "subtle", "颊峰低，卵面还没那么窄。",
                      "a low cheek apex and a straight nose on a moderate oval",
                      "a low cheek still full in youth",
                      "a lower cheek apex and a finer nose with age")),
            T("skin", "maternal", "value", "qh_undertone", "青灰肤", "green-grey undertone", "overt",
              "凉白里带青灰，只随母亲的数值走。",
              "cool fair skin with a green-grey undertone, matte rather than luminous",
              "cool fair skin, the green-grey undertone faint in youth",
              "cooler fair skin, the green-grey undertone clearer at the temple in age"),
            T("bearing", "penetrance", "diploid", "qh_fold", "合手", "folded-hands bearing", "overt",
              "双手交叠，声线平，听人时头微侧。约六成外显。",
              "hands folded, voice even, a slight head tilt when listening",
              "hands not yet folded by habit, the head tilt occasional in youth",
              "hands folded closer, the head tilt smaller, the voice drier with age",
              bark="按牒。"),
            T("regalia", "dominant", "diploid", "qh_collar", "闭领", "closed slate collar", "overt",
              "哑光石板高闭领，一条软玉色压线，短披肩。",
              "a high closed collar of matte slate, one nephrite-thread placket, a short capelet",
              "the closed slate collar a little tall for the neck in youth",
              "the closed slate collar still exact, the nephrite thread paler with age",
              modules=["regalia_qh_collar", "regalia_qh_capelet"],
              palette={"cloth": "#2A3442", "trim": "#5EE0B5", "metal": "#C9D3DE"}),
            T("pure", "pureblood", "diploid", "qh_pure", "双玉缕", "second nape lock", "overt",
              "玉缕透到发根，颈后再有一缕极细的同色发。须玉缕已显。",
              "the jade lock is translucent to the root and a second micro-lock of the same green sits at the nape",
              "the nape micro-lock is short and the root translucency slight in youth",
              "the nape micro-lock longer, the root translucency clearer in age"),
        ],
        "unique": T("skin", "dominant", "diploid", "qh_web", "渡茧", "thumb-web pad", "subtle",
                    "右拇指蹼一块厚茧。渡口世家的手，不是玉缕。",
                    "a thickened pad of skin in the right thumb web",
                    "a slight thickening in the right thumb web in youth",
                    "a thicker pad in the right thumb web, more creased with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_qh_hair", "湿梢墨", "damp-ended ink hair", "overt",
              "墨发松着，发梢常湿，没有鬓缕。",
              "loose ink-black hair, often damp at the ends, no temple lock",
              "looser ink-black hair, ends damp, shorter in youth",
              "loose ink-black hair, ends still damp, finer with age"),
            T("skin", "dominant", "diploid", "folk_qh_skin", "河岸肤", "river-tan skin", "overt",
              "河岸暖棕，只有颊窝一点雾灰。",
              "river-tan skin with cool mist-grey only in the hollow of the cheek",
              "river-tan skin, the cheek hollow not yet grey in youth",
              "river-tan skin, the cheek hollow greyer with age"),
            T("bone", "dominant", "diploid", "folk_qh_bone", "圆颏", "soft delta chin", "overt",
              "下巴圆，鼻梁有一点骨节。",
              "a soft rounded chin and a nose with a slight bridge bump",
              "a rounder chin, the bridge bump small in youth",
              "a rounded chin and a more noticeable bridge bump with age"),
        ],
    },
    {
        "id": "lantern", "name": "灯市联",
        "noble_line": "lt_glass", "noble_mark": "glass_sheen", "folk_line": "lt_tide",
        "why": "灯丝在发梢。脸上另外是不对称的墨裁、烟晶虹膜里一粒冷白高光、软卵面，颊上的冷泽要立了功才亮。",
        "traits": [
            T("hair", "recessive", "diploid", "lt_asym", "偏裁墨", "asymmetric ink cut", "overt",
              "玻璃般的直墨发，左侧更长。两份才显，和灯丝不是一回事。",
              "glassy-straight dark hair in an asymmetric cut, longer on the left",
              "dark hair only slightly longer on the left, still soft in youth",
              "the left side still longer, the lengths finer and a little grey at the scalp in age",
              noble=N("lt_merchantcut", "商裁", "merchant cut", "overt", "墨发收短，左右齐。",
                      "dark hair cut even, practical, no long left side",
                      "an even dark crop, a little fluffy in youth",
                      "an even dark crop, thinner at the temples with age")),
            T("iris", "dominant", "diploid", "lt_quartz", "烟晶瞳", "smoky-quartz iris", "subtle",
              "烟晶色虹膜，一点冷白高光，不是金瞳。",
              "smoky-quartz irises with a pinpoint cool-white catchlight",
              "smoky-quartz irises, the catchlight soft and wide in youth",
              "smoky-quartz irises, the catchlight smaller and sharper with age",
              catch=True),
            T("bone", "dominant", "diploid", "lt_soft", "软卵面", "soft oval", "subtle",
              "软卵面、短鼻、圆颏、眉会动。近看才和普通卵面分开。",
              "a soft oval face, a short nose, a rounded chin and mobile brows",
              "a softer rounder face, the nose short, brows very mobile in youth",
              "a soft oval, the chin a little sharper, brows still mobile in age",
              catch=True,
              noble=N("lt_shortchin", "短颏", "short chin", "subtle", "下巴短，卵面普通。",
                      "a short chin and ordinary cheeks",
                      "a short chin still round in youth",
                      "a shorter-looking chin with a finer jawline in age")),
            T("skin", "awakened", "diploid", "lt_sheen", "颊冷泽", "oath cheek sheen", "overt",
              "颊骨一层冷玻璃泽。伯爵或立过誓才显。",
              "an even neutral beige skin with a faint cool sheen on the cheekbones, like frosted glass",
              "even neutral beige skin, the cheek sheen not yet present",
              "neutral beige skin, the cool cheek sheen wider and drier with age",
              deed={"rank_min": "count", "honors_any": ["crown_line", "banner_oath"]}),
            T("bearing", "penetrance", "diploid", "lt_count", "抬颌数指", "coin-count gesture", "overt",
              "下颌微抬，手指像在数看不见的钱。约六成外显。",
              "chin slightly lifted, fingers counting invisible coins, voice in a quick even cadence",
              "the chin lift occasional, the finger count not yet a habit in youth",
              "the chin lift habitual, the finger count slower, the voice drier with age",
              bark="这盏算我的。"),
            T("regalia", "dominant", "diploid", "lt_bind", "玻璃压边", "glass edge binding", "overt",
              "短石板外套，领与下摆是玻璃纤维压边。",
              "a short slate jacket with clear glass-fibre edge binding and a small cool-white stitch",
              "the glass-fibre binding bright and a little stiff in youth",
              "the glass-fibre binding still clear, the jacket softer at the edge with age",
              modules=["regalia_lt_binding", "regalia_lt_jacket"],
              palette={"cloth": "#161B24", "trim": "#F4F7FB", "metal": "#6ED4FF"}),
            T("pure", "pureblood", "diploid", "lt_pure", "双层灯丝", "inner glass ring", "overt",
              "灯丝之内再有一圈更短的玻璃丝。须灯丝已显且两份纯血。",
              "a second, shorter ring of glass fibre just inside the glowing hair ends",
              "the inner glass ring only a few fibres long in youth",
              "the inner glass ring longer and still cool-white in age"),
        ],
        "unique": T("skin", "dominant", "diploid", "lt_knuckle", "指节冷泽", "frosted knuckles", "subtle",
                    "指节一层冷霜泽，像常握玻璃。",
                    "a cool frosted sheen across the knuckles, as if they handled cold glass",
                    "a faint cool sheen on the knuckles in youth",
                    "a wider cool sheen on the knuckles, skin drier with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_lt_hair", "市井束发", "market tie", "overt",
              "深发束起干活，发梢普通、不透。",
              "practical dark hair tied up, the ends ordinary and opaque",
              "dark hair tied up, a little messy in youth",
              "dark hair tied up, finer at the scalp with age, ends still opaque"),
            T("skin", "dominant", "diploid", "folk_lt_skin", "港暖肤", "harbor beige", "overt",
              "中性米色，额心因港风更亮。",
              "neutral beige skin, slightly shinier at the forehead from harbor weather",
              "neutral beige skin, the forehead shine light in youth",
              "neutral beige skin, the forehead drier and shinier with age"),
            T("bone", "dominant", "diploid", "folk_lt_bone", "宽嘴", "wide easy mouth", "overt",
              "嘴宽、颊骨普通。",
              "a wide easy mouth and average cheekbones",
              "a wide mouth, cheeks still round in youth",
              "a wide mouth and slightly lower cheeks with age"),
        ],
    },
    {
        "id": "frostcrown", "name": "霜冕廷",
        "noble_line": "fc_hall", "noble_mark": "rime_tip", "folk_line": "fc_plateau",
        "why": "霜睫之外，鬓角才是霜银、虹膜是风暴灰、脸又长又窄，冷粉灰的肤跟 X 走，手静下来要到年纪。",
        "traits": [
            T("hair", "dominant", "diploid", "fc_temple", "鬓霜墨", "temple-silver ink hair", "overt",
              "发身是墨，只有两鬓霜银，细而直。",
              "ink hair, fine and straight, frost-silver only at the temples",
              "ink hair, the temple silver only a few hairs in youth",
              "ink hair finer, the temple silver wider toward the part in age",
              noble=N("fc_short", "短霜鬓", "short temple silver", "subtle", "鬓角一点霜，发身不一定是墨。",
                      "a small frost-silver patch at one temple, the rest of the hair dark",
                      "a few frost-silver hairs at one temple in youth",
                      "a wider frost-silver patch at one temple in age")),
            T("iris", "recessive", "diploid", "fc_storm", "风暴灰瞳", "storm-grey iris", "subtle",
              "风暴灰虹膜，瞳孔边缘一圈更深的石板色。两份才显。",
              "storm-grey irises with a darker slate collar around the pupil",
              "storm-grey irises, the slate collar faint in youth",
              "storm-grey irises, the slate collar wider with age",
              catch=True),
            T("bone", "threshold", "value", "fc_long", "长窄面", "long narrow face", "subtle",
              "长窄脸、薄鼻、眉骨高、颊微凹。",
              "a long narrow face, a thin nose, a high brow bone and a slight hollow cheek",
              "a long face still softer, the nose thin, the cheek not hollow in youth",
              "a longer-looking face, the cheek hollower, the nose still thin in age",
              catch=True,
              noble=N("fc_thin", "薄鼻", "thin nose", "subtle", "鼻薄，脸还没有那么长。",
                      "a thin nose and a moderately long face",
                      "a thin nose on a face that is still short in youth",
                      "a thinner-looking nose and a longer face with age")),
            T("skin", "x_dominant", "x", "fc_skin", "冷粉灰", "cool pink-grey skin", "overt",
              "冷粉灰，太阳穴细血管看起来是银而不是蓝。父传全女。",
              "cool pink-grey skin, the fine temple vessels reading silver rather than blue",
              "cool pink-grey skin, temple vessels hardly visible in youth",
              "cooler pink-grey skin, temple vessels a little clearer and still silver in age",
              modules=[], palette={}),
            T("bearing", "age_awakened", "diploid", "fc_hands", "静手", "quiet hands", "overt",
              "二十八岁后手才放稳，声线往下走。",
              "upright posture, hands quiet at the sides, voice low and unhurried",
              "upright posture, hands still restless in youth",
              "upright posture a little shorter, hands quieter, voice lower with age",
              age_min=28, bark="钟还在。"),
            T("regalia", "dominant", "diploid", "fc_collar", "高直领", "tall matte collar", "overt",
              "高哑光领，霜白发丝滚边，短氅左右对称。",
              "a tall matte collar, frost-white hairline piping, a short symmetrical cloak",
              "the tall collar slightly too high, piping very bright in youth",
              "the tall collar still symmetrical, piping softened to brushed frost metal in age",
              modules=["regalia_fc_collar", "regalia_fc_cloak"],
              palette={"cloth": "#2A3442", "trim": "#F4F7FB", "metal": "#6ED4FF"}),
            T("pure", "pureblood", "diploid", "fc_pure", "霜线合", "temple silver meets", "overt",
              "两鬓霜银在头顶汇成一条细线。须霜睫已显且两份纯血。",
              "the temple silver of the hair meets in a fine line over the top of the head",
              "the meeting line of temple silver is broken in youth",
              "the meeting line of temple silver is continuous and wider in age"),
        ],
        "unique": T("bearing", "dominant", "diploid", "fc_mouth", "闭唇", "level closed mouth", "subtle",
                    "默认闭唇，嘴角平，没有笑纹。",
                    "lips closed by default, corners level, no smile crease",
                    "lips often closed, the face still smooth in youth",
                    "lips closed, a level line, still no smile crease in age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_fc_hair", "钝灰梢", "dull grey tips", "overt",
              "深发，梢是钝灰，不是鬓银。",
              "dark hair faded at the tips to a dull grey, not silver at the temples",
              "dark hair, the dull grey tips short in youth",
              "dark hair, the dull grey tips longer with age, temples still dark"),
            T("skin", "dominant", "diploid", "folk_fc_skin", "高原肤", "plateau skin", "overt",
              "高原肤，只有鼻翼发红粗糙。",
              "high-plateau skin, chapped and pink only at the nostrils",
              "high-plateau skin, nostrils barely chapped in youth",
              "high-plateau skin, nostrils more chapped, cheeks drier with age"),
            T("bone", "dominant", "diploid", "folk_fc_bone", "牧户宽面", "pastoral broad face", "overt",
              "牧户的宽面、短鼻。",
              "a broad pastoral face with a short nose",
              "a broad face, the nose short and the cheeks full in youth",
              "a broad face, the nose still short, cheeks lower with age"),
        ],
    },
    {
        "id": "emberold", "name": "余烬旧邦",
        "noble_line": "ember_noble", "noble_mark": "ember_sigil", "folk_line": "eo_ashland",
        "why": "冰裂只传子。配套是后掠的墨发加一缕青灰、虹膜里的细裂丝、阔颧，以及同样只传子的左偏领。",
        "traits": [
            T("hair", "dominant", "diploid", "eo_sweep", "青丝掠", "celadon-streak sweep", "overt",
              "密黑微卷，向后掠，左鬓一条青灰纹，不是开片。",
              "dense black hair with a slight wave, swept back, a celadon-grey streak at the left temple",
              "dense black hair, the celadon-grey streak only a few hairs in youth",
              "dense black hair swept back, the celadon-grey streak wider in age",
              noble=N("eo_short", "短掠", "short sweep", "overt", "黑发后掠，没有青灰纹。",
                      "black hair swept back, no grey-green streak",
                      "shorter black hair swept back in youth",
                      "black hair swept back, thinner at the temples with age")),
            T("iris", "recessive", "diploid", "eo_stroma", "裂丝瞳", "stroma crackle", "subtle",
              "深暮色虹膜，基质里几根细裂丝。两份才显。",
              "deep dusk irises with a few fine crackle lines in the stroma",
              "deep dusk irises, one short crackle line in youth",
              "deep dusk irises, the stromal crackle lines a little longer with age",
              catch=True),
            T("bone", "threshold", "value", "eo_zygo", "阔颧", "broad cheekbone", "subtle",
              "颧骨宽、鼻短而头平、眉脊重。",
              "broad cheekbones, a short nose with a flat tip and a heavy brow ridge",
              "broad cheekbones still padded, the nose short in youth",
              "broader-looking cheekbones, the brow ridge heavier in age",
              catch=True,
              noble=N("eo_shortnose", "短鼻", "short flat nose", "subtle", "鼻短头平，颧还没有那么宽。",
                      "a short nose with a flat tip and moderate cheeks",
                      "a short flat nose, cheeks still round in youth",
                      "a short flat nose and slightly wider cheeks with age")),
            T("skin", "dominant", "diploid", "eo_clay", "窑灰暖肤", "kiln-clay skin", "overt",
              "暖棕里带灰绿，像窑土，不是橙色。",
              "warm tan skin with a grey-green undertone, like kiln clay, matte",
              "warm tan skin, the grey-green undertone faint in youth",
              "warm tan skin, the grey-green undertone clearer in the creases with age"),
            T("bearing", "penetrance", "diploid", "eo_pause", "停顿掌心", "pause then palm", "overt",
              "肩平，先停一下再说话，掌心向下。约六成外显。",
              "shoulders square, a pause before speech, a palm-down gesture, voice low",
              "shoulders square, the pause not yet habitual in youth",
              "shoulders still square, the pause longer, the voice rougher with age",
              bark="窑还热。"),
            T("regalia", "y_linked", "y", "eo_collar", "左偏领", "asymmetric left collar", "overt",
              "领口左偏，让出左鬓，压边是青灰。只传儿子。",
              "an asymmetric collar cut away on the left, celadon piping, matte charcoal cloth",
              "the left collar cut a little uneven in youth",
              "the left collar cut still open, the celadon piping dulled with age",
              modules=["regalia_eo_collar", "regalia_eo_piping"],
              palette={"cloth": "#1C2330", "trim": "#9AA6B8", "metal": "#C9D3DE"}),
            T("pure", "pureblood", "diploid", "eo_pure", "裂及颌", "crackle to the jaw", "overt",
              "开片延伸到下颌，青灰发纹分叉。须冰裂已显且两份纯血。",
              "the celadon crackle reaches the jawline and the temple streak forks",
              "the forked streak is short and the jawline crackle faint in youth",
              "the forked streak wider and the jawline crackle clearer in age"),
        ],
        "unique": T("bone", "dominant", "diploid", "eo_notch", "耳垂窑缺", "earlobe notch", "subtle",
                    "左耳垂一个小缺口，耳廓仍圆、贴近。",
                    "a small notch in the left earlobe; the ear is round and close-set",
                    "a shallow notch in the left earlobe in youth",
                    "a small notch in the left earlobe, the lobe a little longer with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_eo_hair", "窑短发", "kiln-short hair", "overt",
              "黑发剪短，沾一点灰，方便进窑。",
              "black hair cut short for kiln work, dulled by pale dust",
              "short black hair, the dusting light in youth",
              "short black hair, thinner, still dust-dulled with age"),
            T("skin", "dominant", "diploid", "folk_eo_skin", "手纹灰", "crease-grey tan", "overt",
              "窑镇暖棕，只有手纹是灰的。",
              "kiln-town tan, grey only in the creases of the hands",
              "kiln-town tan, hand creases barely grey in youth",
              "kiln-town tan, hand creases greyer and deeper with age"),
            T("bone", "dominant", "diploid", "folk_eo_bone", "方作颌", "square work jaw", "overt",
              "劳作的方颌，颧骨并不宽。",
              "a square work jaw without the wide cheekbones of the kiln house",
              "a square jaw still soft in youth",
              "a squarer jaw, cheeks ordinary, with age"),
        ],
    },
    {
        "id": "saltmarsh", "name": "盐泽盟",
        "noble_line": "sm_ledger", "noble_mark": "salt_band", "folk_line": "sm_reed",
        "why": "潮环在发上。另外是盐硬的低盘发、海玻璃色的虹膜（也走 X）、宽而短的脸，肤上的盐光只跟母亲。",
        "traits": [
            T("hair", "recessive", "diploid", "sm_coil", "盐硬盘", "salt-stiff nape coil", "overt",
              "发厚，在颈后盘低，手感盐硬。两份才显。",
              "thick hair in a low coil at the nape, salt-stiff to the touch",
              "thick hair, the nape coil loose and less stiff in youth",
              "thick hair, the nape coil lower, salt-stiff and a little grey in age",
              noble=N("sm_knot", "低髻", "low knot", "overt", "低髻，并不盐硬。",
                      "a low knot of dark hair, soft rather than salt-stiff",
                      "a loose low knot in youth",
                      "a low knot, finer hair, in age")),
            T("iris", "x_dominant", "x", "sm_iris", "海玻璃瞳", "sea-glass iris", "subtle",
              "海玻璃般的灰绿虹膜，角膜缘一圈淡盐色。父传全女。",
              "sea-glass grey-green irises with a pale salt ring at the limbus",
              "sea-glass irises, the salt limbal ring faint in youth",
              "sea-glass irises, the salt limbal ring a little wider with age",
              catch=True),
            T("bone", "threshold", "value", "sm_wide", "宽短面", "wide short face", "subtle",
              "脸宽、鼻短而阔、颊满、下颌浅。",
              "a wide face, a short broad nose, full cheeks and a shallow jaw",
              "a wide face still rounder, the nose short in youth",
              "a wide face, cheeks a little lower, the nose still short and broad in age",
              catch=True,
              noble=N("sm_full", "丰颊", "full cheek", "subtle", "颊满，脸还没有那么宽。",
                      "full cheeks and a moderate nose",
                      "full cheeks, rounder in youth",
                      "full cheeks, a little lower with age")),
            T("skin", "maternal", "value", "sm_sheen", "盐光橄榄", "salt-sheen olive", "overt",
              "日晒橄榄肤，表面一层凉盐光。只随母亲。",
              "sun-warmed olive skin with a cool salt sheen, matte in the shadows",
              "olive skin, the salt sheen faint in youth",
              "olive skin, the salt sheen drier and more even in age"),
            T("bearing", "age_awakened", "diploid", "sm_stance", "宽站", "wide tide stance", "overt",
              "二十四岁后站距变宽，转身先转头。",
              "a wide stance, the head turning before the body, voice counting like a tide",
              "a narrower stance, the head and body turning together in youth",
              "a wider stance, the head turn slower, the voice lower with age",
              age_min=24, bark="潮回来了。"),
            T("regalia", "dominant", "diploid", "sm_band", "横带短衣", "horizontal mint bands", "overt",
              "短外套，胸前两道霜薄荷横带，领口开。",
              "a cropped jacket with two horizontal frost-mint bands and an open throat, matte cloth",
              "the cropped jacket a little long, the mint bands very clean in youth",
              "the cropped jacket still open at the throat, the mint bands softened with age",
              modules=["regalia_sm_band", "regalia_sm_jacket"],
              palette={"cloth": "#2A3442", "trim": "#5EE0B5", "metal": "#F4F7FB"}),
            T("pure", "pureblood", "diploid", "sm_pure", "三环潮", "three even tide rings", "overt",
              "潮环至少三道且间距相等，盐色角膜缘闭合成环。须潮痕已显。",
              "three or more evenly spaced salt-white hair rings and a complete salt ring at the limbus",
              "three hair rings present but the limbus ring still open in youth",
              "three or more hair rings, the limbus ring complete and a little wider in age"),
        ],
        "unique": T("skin", "dominant", "diploid", "sm_lip", "唇盐褶", "lower-lip crease", "subtle",
                    "下唇一道横褶。",
                    "one horizontal crease across the lower lip",
                    "a faint horizontal crease on the lower lip in youth",
                    "a deeper horizontal crease on the lower lip with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_sm_hair", "盐硬辫", "work braid", "overt",
              "盐硬的深发松辫，没有等距白环。",
              "salt-stiff dark hair in a loose work braid, with no even white bands",
              "a loose work braid, less stiff in youth",
              "a work braid, stiffer and a little grey, still without even bands, in age"),
            T("skin", "dominant", "diploid", "folk_sm_skin", "芦滩肤", "reed-marsh tan", "overt",
              "芦滩暖棕，只有发际有干盐。",
              "reed-marsh tan with dry salt only at the hairline",
              "reed-marsh tan, the hairline salt faint in youth",
              "reed-marsh tan, the hairline salt drier and wider with age"),
            T("bone", "dominant", "diploid", "folk_sm_bone", "晒眯面", "sun-squint face", "overt",
              "常眯眼的脸，鼻宽、颊浅。",
              "a sun-squint face with a broad nose and shallow cheeks",
              "a sun-squint face, cheeks still fuller in youth",
              "a sun-squint face, the nose broad, cheeks shallower with age"),
        ],
    },
    {
        "id": "irongorge", "name": "铁峡领",
        "noble_line": "ig_warden", "noble_mark": "brow_notch", "folk_line": "ig_forge",
        "why": "峡眉是缝。其余是铁黑的侧分、扁长的高光、重颌长鼻、钢底肤，喉领要过了二十五岁才坐正。",
        "traits": [
            T("hair", "dominant", "diploid", "ig_part", "铁黑侧分", "iron side part", "overt",
              "铁黑短发，一道钝侧分。",
              "iron-black hair, short, cut by a blunt side part",
              "shorter iron-black hair, the side part soft in youth",
              "iron-black hair, the side part higher, scalp a little visible in age",
              noble=N("ig_crop", "短铁裁", "iron crop", "overt", "铁黑短发，没有侧分线。",
                      "a short iron-black crop with no side part",
                      "a soft short iron-black crop in youth",
                      "a short iron-black crop, thinner on top with age")),
            T("iris", "recessive", "diploid", "ig_catch", "扁光瞳", "flat catchlight", "subtle",
              "铁灰虹膜，高光是一条扁的长方形。两份才显。",
              "iron-grey irises with a flat rectangular catchlight",
              "iron-grey irises, the catchlight shorter in youth",
              "iron-grey irises, the rectangular catchlight longer with age",
              catch=True),
            T("bone", "dominant", "diploid", "ig_jaw", "重颌长鼻", "heavy jaw long nose", "subtle",
              "下颌重、鼻长梁高、下颌角宽。近看才稳。",
              "a heavy jaw, a long nose with a high bridge and a wide jaw angle",
              "a heavy jaw still padded, the nose long but softer in youth",
              "a heavier jaw angle, the nose still long, cheeks lower in age",
              catch=True,
              noble=N("ig_gonial", "宽下颌", "wide jaw angle", "subtle", "下颌角宽，鼻还没有那么长。",
                      "a wide jaw angle and a straight medium nose",
                      "a wide jaw angle, still soft in youth",
                      "a wider jaw angle and a leaner cheek in age")),
            T("skin", "dominant", "diploid", "ig_steel", "钢底肤", "steel-undertone skin", "overt",
              "中性红棕，底色是冷钢，毛孔可见。",
              "ruddy-neutral skin with a cool steel undertone and visible pores",
              "ruddy-neutral skin, pores finer, the steel undertone light in youth",
              "ruddy-neutral skin, pores clearer, the steel undertone cooler in age"),
            T("bearing", "penetrance", "diploid", "ig_lean", "前倾", "forward lean", "overt",
              "身体前倾，收下颌，休息时拳是握着的。约六成外显。",
              "a forward lean, chin tucked, the resting hand closed, voice one hard syllable",
              "a slight forward lean, the hand not yet closed at rest in youth",
              "a deeper forward lean, the closed hand stiffer, the voice rougher with age",
              bark="断。"),
            T("regalia", "age_awakened", "diploid", "ig_throat", "钢喉领", "square throat plate", "overt",
              "二十五岁后，拉丝钢喉领才坐正。",
              "a brushed-steel throat plate sitting square, with a short matte cape",
              "a brushed-steel throat plate sitting slightly crooked",
              "a brushed-steel throat plate sitting square, the edge dulled with age",
              age_min=25,
              modules=["regalia_ig_throat", "regalia_ig_cape"],
              palette={"cloth": "#2A3442", "trim": "#9AA6B8", "metal": "#C9D3DE"}),
            T("pure", "pureblood", "diploid", "ig_pure", "发际峡口", "hairline notch", "overt",
              "双眉的窄隙之外，发际正中再有一个同样的缺口。须峡眉已显。",
              "a matching narrow notch in the centre hairline, aligned with the brow gaps",
              "the hairline notch shallow in youth",
              "the hairline notch a little deeper, still narrow, in age"),
        ],
        "unique": T("bone", "dominant", "diploid", "ig_ridge", "指节棱", "knuckle ridge", "overt",
                    "两手第一指节一道凸棱。",
                    "a raised ridge across the first knuckles of both hands",
                    "a slight ridge across the first knuckles in youth",
                    "a higher ridge across the first knuckles with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_ig_hair", "刀裁短发", "knife-cut hair", "overt",
              "深发用刀削短，没有侧分。",
              "short dark hair cut with a knife, no side part",
              "short knife-cut dark hair, uneven in youth",
              "short knife-cut dark hair, thinner, still without a side part, in age"),
            T("skin", "dominant", "diploid", "folk_ig_skin", "峡尘肤", "canyon-dust skin", "overt",
              "峡尘肤，毛孔发灰，只有指节发红。",
              "canyon-dust skin, grey in the pores, ruddy only at the knuckles",
              "canyon-dust skin, knuckles barely ruddy in youth",
              "canyon-dust skin, pores greyer, knuckles ruddier with age"),
            T("bone", "dominant", "diploid", "folk_ig_bone", "钝作鼻", "blunt work nose", "overt",
              "鼻头钝、下颌因干活而重。",
              "a blunt nose and a jaw heavy from work",
              "a blunt nose and a jaw still soft in youth",
              "a blunter nose and a heavier work jaw with age"),
        ],
    },
    {
        "id": "starriver", "name": "星津邦",
        "noble_line": "sr_east_arc", "noble_mark": "san_tai",
        "noble_line_b": "sr_west_arc", "noble_mark_b": "si_fu",
        "folk_line": "sr_ford",
        "why": "七星在颧上。其余是耳上一条窄剃线、虹膜里三粒淡斑、偏长的中面，视线往左上飘跟 X 走。",
        "traits": [
            T("hair", "dominant", "diploid", "sr_shave", "窄剃线", "narrow shaved line", "overt",
              "墨发直，耳上一条窄剃线。",
              "straight ink hair with a narrow shaved line above the ear",
              "ink hair, the shaved line shorter and softer in youth",
              "ink hair, the shaved line a little higher and wider with age",
              noble=N("sr_half", "半剃", "half shave", "subtle", "耳上只有半段剃线。",
                      "straight dark hair with a half-length shaved line above one ear",
                      "a short half-line above one ear in youth",
                      "a half-length shaved line, a little wider with age")),
            T("iris", "recessive", "diploid", "sr_fleck", "三微斑", "three iris flecks", "subtle",
              "近黑虹膜里三粒淡斑，排成小弧。两份才显。不是脸上的痣。",
              "near-black irises with exactly three tiny pale flecks in a small arc",
              "near-black irises, only one pale fleck clear in youth",
              "near-black irises, the three pale flecks a little larger with age",
              catch=True),
            T("bone", "threshold", "value", "sr_mid", "长中面", "long midface", "subtle",
              "中面长、颊不高、鼻直、眉平。",
              "a long midface, modest cheeks, a straight nose and level brows",
              "a long midface still softer, brows level in youth",
              "a longer midface, cheeks lower, brows still level in age",
              catch=True,
              noble=N("sr_brow", "平眉骨", "level brow bone", "subtle", "眉骨平，中面还没那么长。",
                      "level brows and a moderate midface",
                      "level brows on a shorter face in youth",
                      "level brows and a slightly longer midface with age")),
            T("skin", "dominant", "diploid", "sr_olive", "匀橄榄", "even olive", "overt",
              "浅橄榄，均匀。",
              "even light-olive skin, matte, no patches",
              "even light-olive skin, a little warmer in youth",
              "even light-olive skin, drier at the cheek with age"),
            T("bearing", "x_dominant", "x", "sr_glance", "左上视", "up-left glance", "overt",
              "想事情时视线往左上，食指点两下。父传全女。",
              "the gaze ticks up and to the left when thinking, then the index finger taps twice",
              "the up-left glance occasional, the tap not yet paired in youth",
              "the up-left glance slower, the double tap still exact in age",
              bark="在那边。"),
            T("regalia", "dominant", "diploid", "sr_arc", "弧缝短氅", "arc-stitched short cloak", "overt",
              "不对称短氅，一道浅弧霜线，墨色领。",
              "an asymmetric short cloak with a shallow frost stitch in an arc, and an ink collar",
              "the short cloak a little long, the arc stitch very bright in youth",
              "the short cloak still asymmetric, the arc stitch softened with age",
              modules=["regalia_sr_cloak", "regalia_sr_arc"],
              palette={"cloth": "#10141C", "trim": "#6ED4FF", "metal": "#F4F7FB"}),
            T("pure", "pureblood", "diploid", "sr_pure", "点线相合", "flecks align", "overt",
              "三粒虹膜淡斑与外三颗痣的弧对齐。须七星已显且两份纯血。",
              "the three pale iris flecks align with the arc of the outer three moles",
              "the flecks and the outer moles nearly align, still a little off in youth",
              "the flecks and the outer moles align exactly in age"),
        ],
        "unique": T("bearing", "dominant", "diploid", "sr_tap", "双点指", "double tap", "subtle",
                    "食指像刚点过两下，然后停住。东虹自家的手势。",
                    "the index finger rests as if it has just tapped twice, then gone still",
                    "an occasional single tap, not yet a double, in youth",
                    "the double-tap rest still exact, the finger a little stiffer in age"),
        "unique_b": T("bearing", "dominant", "diploid", "sr_shoulder", "左肩微耸", "raised left shoulder", "subtle",
                      "左肩比右肩略高。西虹自家的站法。",
                      "the left shoulder sits slightly higher than the right",
                      "the left shoulder only a little high, easy to miss in youth",
                      "the left shoulder higher, the line of the neck a little shorter in age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_sr_hair", "风缠发", "wind-tangled hair", "overt",
              "渡口黑发，被风缠着，没有剃线。",
              "ferry-black hair, wind-tangled, with no shaved line",
              "wind-tangled black hair, shorter in youth",
              "wind-tangled black hair, a little grey, still with no shaved line, in age"),
            T("skin", "dominant", "diploid", "folk_sr_skin", "桥镇肤", "bridge-town skin", "overt",
              "桥镇均匀肤，只有领口更暗一点。",
              "even bridge-town skin, a little darker at the collar line",
              "even bridge-town skin, the collar line not yet darker in youth",
              "even bridge-town skin, the collar line darker with age"),
            T("bone", "dominant", "diploid", "folk_sr_bone", "普通卵面", "ordinary oval", "overt",
              "普通卵面，眉平，鼻中等。",
              "an ordinary oval face with level brows and a medium nose",
              "an ordinary oval, cheeks fuller in youth",
              "an ordinary oval, cheeks slightly lower with age"),
        ],
    },
    {
        "id": "southzephyr", "name": "南泽邦",
        "noble_line": "sz_ferry", "noble_mark": "firefly_trace", "folk_line": "sz_fogwood",
        "why": "萤斑只随母亲。配套是雾灰的发梢、苔色的虹膜（也只随母亲）、圆脸，以及年纪到了才出现的侧耳晚笑。",
        "traits": [
            T("hair", "dominant", "diploid", "sz_wave", "雾尖波", "fog-tipped waves", "overt",
              "柔软的深色波浪，梢是雾灰，不是金。",
              "soft dark waves with fog-grey tips, tucked behind one ear",
              "softer shorter waves, the fog-grey tips only a haze in youth",
              "dark waves, the fog-grey tips longer and duller with age",
              noble=N("sz_short", "短波", "short wave", "overt", "短波浪，梢不发灰。",
                      "short dark waves with ordinary dark tips",
                      "short soft waves in youth",
                      "shorter dark waves, a little finer with age")),
            T("iris", "maternal", "value", "sz_moss", "苔缘瞳", "moss limbal haze", "subtle",
              "苔绿虹膜，角膜缘一圈薄荷雾。亮度跟母亲的数值。",
              "moss irises with a pale mint haze at the limbus",
              "moss irises, the mint limbal haze faint in youth",
              "moss irises, the mint limbal haze a little wider with age",
              catch=True),
            T("bone", "threshold", "value", "sz_round", "圆面", "round face", "subtle",
              "圆脸、小鼻、低颊、眼距宽。",
              "a round face, a small nose, low cheeks and wide-set eyes",
              "a rounder face, the nose small, cheeks full in youth",
              "a round face, cheeks lower, the nose still small in age",
              catch=True,
              noble=N("sz_smallnose", "小鼻", "small nose", "subtle", "鼻小，脸还没那么圆。",
                      "a small nose and moderate cheeks",
                      "a small nose, cheeks fuller in youth",
                      "a small nose and slightly lower cheeks with age")),
            T("skin", "dominant", "diploid", "sz_mint", "薄荷影", "mint-shadow skin", "overt",
              "暖米色，阴影里一点薄荷底。",
              "warm beige skin with a cool mint undertone in the shadows",
              "warm beige skin, the mint undertone faint in youth",
              "warm beige skin, the mint undertone clearer in the shadows with age"),
            T("bearing", "age_awakened", "diploid", "sz_listen", "侧耳晚笑", "late smile", "overt",
              "二十六岁后才习惯侧过来听，笑来得晚。",
              "a lean-in to listen, the smile arriving late, voice soft and short",
              "a quicker smile, the lean-in not yet habitual in youth",
              "a slower lean-in, the late smile smaller, the voice softer with age",
              age_min=26, bark="雾里见。"),
            T("regalia", "dominant", "diploid", "sz_hood", "兜领", "hood-collar", "overt",
              "哑光石板兜领，一道薄荷缝，短披。",
              "a hood-collar of matte slate with one mint stitch and a short cape",
              "the hood-collar a little deep, the mint stitch bright in youth",
              "the hood-collar still soft, the mint stitch paler with age",
              modules=["regalia_sz_hood", "regalia_sz_cape"],
              palette={"cloth": "#1C2330", "trim": "#5EE0B5", "metal": "#9AA6B8"}),
            T("pure", "pureblood", "diploid", "sz_pure", "桥斑", "bridge freckle path", "overt",
              "萤斑在鼻梁上收成一条窄桥，薄荷角膜缘闭合成环。须萤斑已显。",
              "the luminous freckles tighten into a narrow bridge across the nose and the mint limbal haze closes into a ring",
              "the freckle bridge is short and the limbal ring still open in youth",
              "the freckle bridge complete and the limbal ring closed in age"),
        ],
        "unique": T("bearing", "dominant", "diploid", "sz_squint", "左目微眯", "left-eye rest", "subtle",
                    "左眼静息时比右眼略窄。",
                    "the left eye rests a little narrower than the right",
                    "the left eye only slightly narrower, easy to miss in youth",
                    "the left eye narrower at rest, the difference clearer with age"),
        "folk": [
            T("hair", "dominant", "diploid", "folk_sz_hair", "雾卷", "fog curls", "overt",
              "紧的深卷，带着雾气，梢不发灰。",
              "tight dark curls with fog moisture, tips not grey",
              "tight dark curls, softer in youth, tips dark",
              "tight dark curls, a little looser with age, tips still dark"),
            T("skin", "dominant", "diploid", "folk_sz_skin", "林米色", "forest beige", "overt",
              "林间米色，雀斑普通、不发光。",
              "forest beige skin, freckles ordinary and not luminous",
              "forest beige skin, ordinary freckles light in youth",
              "forest beige skin, ordinary freckles a little denser with age, still not luminous"),
            T("bone", "dominant", "diploid", "folk_sz_bone", "雾林圆面", "fog-wood round face", "overt",
              "圆脸、小鼻、眼距宽，没有光斑。",
              "a round fog-wood face with a small nose and wide-set eyes",
              "a rounder face, small nose, in youth",
              "a round face, cheeks lower, nose still small, in age"),
        ],
    },
]


def forbid_hit(text, words):
    low = text.lower()
    for w in words:
        if re.search(r"\b" + re.escape(w.lower()), low):
            return w
    return ""


def build():
    lock = json.loads(LOCK.read_text())
    forbid = lock["anti_trope"]["forbid_in_positive"]
    d = json.loads(DATA.read_text())
    # Idempotent: drop anything this generator wrote last time.
    old = d.get("generated_traits", {})
    for lid in old.get("loci", []):
        d.get("loci", {}).pop(lid, None)
    for sid in old.get("signatures", []):
        d.get("signatures", {}).pop(sid, None)
    for line in d.get("lines", []):
        line["sig"] = [e for e in line.get("sig", []) if not e.get("trait")]
        line.pop("trait_set", None)
    for nat in d.get("nations", {}).values():
        nat.pop("catch_traits", None)
    d.pop("trait_order", None)

    laws = d.setdefault("laws", {})
    laws["age_awakened"] = {
        "name": "年觉律",
        "name_en": "Age-awakened dominant",
        "short": "显性携因，到龄方显",
        "desc": "等位显性，但要到位点写明的年龄才在脸上显出来。此前是潜征，祠堂能验到因，肖像不画。",
        "punnett": "显因 × 无：子代约 50% 携因；未到龄不显。纯合 × 无：子代全部携因，到龄才显。",
    }
    laws["pureblood"] = {
        "name": "纯血律",
        "name_en": "Pure-line recessive",
        "short": "两份纯血，且本冕已显",
        "desc": "稀有隐性。两份纯血等位，并且本国的王族冕征已经显出来，才出现那一个额外表情。冕征未显时纯血只是潜征。",
        "punnett": "纯血杂合 × 杂合：约 25% 纯合。纯合是否看得见，还要看本冕是否已显。",
    }

    loci = d.setdefault("loci", {})
    sigs = d.setdefault("signatures", {})
    lines = {l["id"]: l for l in d["lines"]}
    trait_order = []
    made_loci = []
    made_sigs = []
    texts = []

    def add_sig(nation, slot, scope, spec, locus_id):
        sid = spec["id"]
        if sid in sigs:
            raise SystemExit(f"duplicate signature {sid}")
        entry = {
            "zh": spec["zh"], "name_en": spec["en"], "tier": scope if scope != "royal" else "royal",
            "visibility": spec["vis"], "nation": nation, "slot": slot, "locus": locus_id,
            "desc": spec["desc"], "prompt": spec["prompt"],
            "prompt_young": spec["young"], "prompt_elder": spec["elder"],
            "generated": "trait-set-v89",
        }
        if scope == "folk":
            entry["tier"] = "folk"
        elif scope == "noble":
            entry["tier"] = "noble"
        for k in ("bark", "modules", "palette"):
            if spec.get(k):
                entry[k] = spec[k]
        sigs[sid] = entry
        made_sigs.append(sid)
        for key in ("prompt", "young", "elder", "desc", "en"):
            texts.append((sid, spec[key]))
        return sid

    def add_locus(nation, row, scope):
        lid = "tr_" + row["id"]
        if lid in loci:
            raise SystemExit(f"duplicate locus {lid}")
        law = row["law"]
        kind = row["kind"]
        alleles = [row["id"]]
        noble = row.get("noble")
        if noble:
            alleles.append(noble["id"])
        alleles.append("none")
        states = {"royal": row["id"]}
        if noble:
            states["noble"] = noble["id"]
        ld = {
            "nation": nation, "slot": row["slot"], "scope": scope, "law": law, "kind": kind,
            "alleles": alleles, "royal": row["id"], "states": states,
            "generated": "trait-set-v89",
        }
        if noble:
            ld["noble"] = noble["id"]
        if kind != "value":
            ld["mutation_loss"] = 0.004
        if law == "threshold":
            ld.update({"royal_min": 0.72, "noble_min": 0.48, "latent_min": 0.40, "noise": 0.035, "regress": 0.15})
        if law == "maternal":
            ld.update({"royal_min": 0.70, "noble_min": 0.40, "latent_min": 0.28, "drift": 0.05})
        if law == "penetrance":
            ld["penetrance"] = 0.6
        if law == "age_awakened":
            ld["age_min"] = int(row.get("age_min", 28))
        if law == "awakened":
            ld["deed"] = row.get("deed", {"rank_min": "count", "honors_any": ["crown_line"]})
        if row.get("catch"):
            ld["catch"] = True
        if scope == "folk":
            ld["display_tier"] = "folk"
        if scope == "noble":
            ld["display_tier"] = "noble"
        loci[lid] = ld
        trait_order.append(lid)
        made_loci.append(lid)
        add_sig(nation, row["slot"], "royal" if scope == "royal" else scope, row, lid)
        if noble:
            add_sig(nation, row["slot"], "noble", noble, lid)
        return lid

    def geno_entry(lid, row, scope):
        law = row["law"]
        kind = row["kind"]
        rid = row["id"]
        noble = row.get("noble")
        if scope == "royal" and kind == "value":
            return {"locus": lid, "trait": True, "value": [0.88, 0.03]}
        if scope == "noble" and kind == "value":
            return {"locus": lid, "trait": True, "value": [0.56, 0.025]}
        if scope == "folk" or scope == "noble_unique":
            allele = rid
            if kind == "x":
                return {"locus": lid, "trait": True, "f": {f"{allele}|{allele}": 1.0}, "m": {allele: 1.0}}
            if kind == "y":
                return {"locus": lid, "trait": True, "f": {}, "m": {allele: 1.0}}
            return {"locus": lid, "trait": True, "genotypes": {f"{allele}|{allele}": 1.0}}
        # royal discrete
        if kind == "y":
            return {"locus": lid, "trait": True, "f": {}, "m": {rid: 0.96, "none": 0.04}}
        if kind == "x":
            return {"locus": lid, "trait": True,
                    "f": {f"{rid}|{rid}": 0.7, f"{rid}|none": 0.3},
                    "m": {rid: 0.9, "none": 0.1}}
        if law == "pureblood":
            return {"locus": lid, "trait": True, "genotypes": {f"{rid}|{rid}": 0.16, f"{rid}|none": 0.34, "none|none": 0.5}}
        if law == "recessive":
            return {"locus": lid, "trait": True, "genotypes": {f"{rid}|{rid}": 0.55, f"{rid}|none": 0.40, "none|none": 0.05}}
        # dominant / penetrance / age / awakened: a carrier shows (or can show)
        return {"locus": lid, "trait": True, "genotypes": {f"{rid}|{rid}": 0.72, f"{rid}|none": 0.28}}

    def noble_geno(lid, row):
        kind = row["kind"]
        noble = row.get("noble")
        if not noble:
            return None
        if kind == "value":
            return {"locus": lid, "trait": True, "value": [0.56, 0.025]}
        nid_ = noble["id"]
        if kind == "x":
            return {"locus": lid, "trait": True, "f": {f"{nid_}|none": 1.0}, "m": {nid_: 1.0}}
        if kind == "y":
            return {"locus": lid, "trait": True, "f": {}, "m": {nid_: 1.0}}
        return {"locus": lid, "trait": True, "genotypes": {f"{nid_}|none": 1.0}}

    catch = {n: [] for n in NATION_ORDER}
    royal_sets = {n: [MARK[n]] for n in NATION_ORDER}
    noble_sets = {}
    folk_sets = {}

    for house in HOUSES:
        nid = house["id"]
        echo_loci = []
        for row in house["traits"]:
            lid = add_locus(nid, row, "royal")
            lines[ROYAL_LINE[nid]]["sig"].append(geno_entry(lid, row, "royal"))
            royal_sets[nid].append(row["id"])
            if row.get("catch"):
                catch[nid].append(row["id"])
            if row.get("noble"):
                echo_loci.append((lid, row))
        # unique noble locus
        u = house["unique"]
        ulid = add_locus(nid, u, "noble")
        lines[house["noble_line"]]["sig"].append(geno_entry(ulid, u, "noble_unique"))
        noble_sets[house["noble_line"]] = [house["noble_mark"]]
        for lid, row in echo_loci:
            if row["slot"] in ("hair", "bone"):
                ng = noble_geno(lid, row)
                if ng:
                    lines[house["noble_line"]]["sig"].append(ng)
                    noble_sets[house["noble_line"]].append(row["noble"]["id"])
        noble_sets[house["noble_line"]].append(u["id"])
        if house.get("unique_b"):
            ub = house["unique_b"]
            ubid = add_locus(nid, ub, "noble")
            lines[house["noble_line_b"]]["sig"].append(geno_entry(ubid, ub, "noble_unique"))
            noble_sets[house["noble_line_b"]] = [house["noble_mark_b"]]
            for lid, row in echo_loci:
                if row["slot"] in ("hair", "bone"):
                    ng = noble_geno(lid, row)
                    if ng:
                        lines[house["noble_line_b"]]["sig"].append(ng)
                        noble_sets[house["noble_line_b"]].append(row["noble"]["id"])
            noble_sets[house["noble_line_b"]].append(ub["id"])
        folk_sets[house["folk_line"]] = []
        for row in house["folk"]:
            flid = add_locus(nid, row, "folk")
            lines[house["folk_line"]]["sig"].append(geno_entry(flid, row, "folk"))
            folk_sets[house["folk_line"]].append(row["id"])
        d["nations"][nid]["catch_traits"] = catch[nid]

    for lid, ids in (("royal", royal_sets), ("noble", noble_sets), ("folk", folk_sets)):
        pass
    for line_id, ids in {**{ROYAL_LINE[n]: royal_sets[n] for n in NATION_ORDER}, **noble_sets, **folk_sets}.items():
        # de-dup preserving order
        seen = []
        for i in ids:
            if i not in seen:
                seen.append(i)
        lines[line_id]["trait_set"] = seen

    d["trait_order"] = trait_order
    d["generated_traits"] = {"loci": made_loci, "signatures": made_sigs}
    d["version"] = "v8.9-bloodlines-2"
    d["rng_note"] = (
        "Original ten signature loci stay first in CKBloodline.LOCUS_ORDER and are drawn before trait_order. "
        "founder_sig/cross_sig use one forked RNG. Appending trait_order does not change draws for the original ten, "
        "nor the v8.7 loci (those run on the caller RNG before the fork). Reordering trait_order re-rolls trait genotypes only."
    )

    # prompts must be unique and clean
    seen_p = {}
    for sid, text in texts:
        bad = forbid_hit(str(text), forbid)
        if bad:
            raise SystemExit(f"{sid}: forbidden '{bad}' in {text}")
        if text in seen_p and str(text).startswith("a ") or True:
            if text in seen_p and sid != seen_p[text]:
                # allow identical desc? no, all narrative strings should be unique enough for prompts
                if text == seen_p[text]:
                    pass
            if text in seen_p:
                raise SystemExit(f"duplicate text {sid} == {seen_p[text]}: {text}")
        seen_p[text] = sid

    # royal readability
    for i, a in enumerate(NATION_ORDER):
        pa = set()
        for sid in royal_sets[a]:
            pr = sigs.get(sid, {}).get("prompt") or ""
            # crown signatures live in the original table
            if not pr and sid in d["signatures"]:
                pr = d["signatures"][sid].get("prompt") or ""
            if pr:
                pa.add(pr)
        for b in NATION_ORDER[i + 1:]:
            pb = set()
            for sid in royal_sets[b]:
                pr = d["signatures"].get(sid, {}).get("prompt") or ""
                if pr:
                    pb.add(pr)
            if len(pa - pb) < 5 or len(pb - pa) < 5:
                raise SystemExit(f"readability {a} vs {b}: {len(pa - pb)} / {len(pb - pa)}")

    for house in HOUSES:
        n = house["id"]
        if not (6 <= len(royal_sets[n]) <= 8):
            raise SystemExit(f"{n} royal set {len(royal_sets[n])}")
        if len(catch[n]) < 2:
            raise SystemExit(f"{n} catch")
        if not (3 <= len(noble_sets[house["noble_line"]]) <= 5):
            raise SystemExit(f"noble {house['noble_line']} {noble_sets[house['noble_line']]}")
        if house.get("noble_line_b") and not (3 <= len(noble_sets[house["noble_line_b"]]) <= 5):
            raise SystemExit(f"noble {house['noble_line_b']} {noble_sets[house['noble_line_b']]}")
        if not (2 <= len(folk_sets[house["folk_line"]]) <= 3):
            raise SystemExit(f"folk {house['folk_line']}")

    DATA.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
    write_doc(d, royal_sets)
    print(f"trait loci={len(made_loci)} signatures={len(made_sigs)} order={len(trait_order)}")


def write_doc(d, royal_sets):
    sigs = d["signatures"]
    lines = []
    lines.append("## 11. 多征签名集（v8.9.2）")
    lines.append("")
    lines.append("王族不该只有一个胎记。每国王胤是 **6–8 个互相咬合的征**，各自挂在一个基因组位点上，遗传律彼此不同。贵胤拿走其中 3–5 个（王室的弱回声 + 自己的一个征）。民胤 2–3 个地域征，不借用王室等位。")
    lines.append("")
    lines.append("**为什么要拆开。** 一个征只能告诉你「像不像这家人」。一套征才能让混血在脸上拼出来：父亲的虹膜、母亲的肤、两边都留下的骨相。稀释的王血只剩残套。伪胤可以描明征（染缕、假灯丝），描不出要近看的隐征；祠堂对等位，眼尖的人看缺了哪一笔。纯血表情要本冕已经显出、并且两份纯血等位同时在，所以满血是看得见的，不是百分比。")
    lines.append("")
    lines.append("**随机流。** 新位点写在 `trait_order`，接在原来的十个冕征位点之后，用同一把分叉 RNG。前十个位点的抽取次数与顺序不变，v8.7 的发色瞳色也不动（它们在分叉之前）。因此 `GENOME` / `KINSHIP` 的旧数字保持原样。调换 `trait_order` 只会重抽这些新征。")
    lines.append("")
    lines.append("**年龄。** 每条征有青年 / 盛年 / 晚年三句提示词。年觉律的征在到龄之前是潜征，肖像不画。纯血律的征默认不进「盛年王胤」示例，只有两份纯血且本冕已显才出现。")
    lines.append("")
    lines.append("**3D。** 只给调色和冠饰模块 id（`regalia_*`），不新增网格。模块在遗传到衣冠征时才挂上。纸冕、伪胤没有这些 id。")
    lines.append("")
    lines.append("| 律 | 在签名集里的角色 |")
    lines.append("|---|---|")
    lines.append("| 显性 / 隐性 / 外显 | 发、虹膜、体态；外显约六成，其余藏着照样传 |")
    lines.append("| 父传女（X） | 朔影窄银领、霜冕冷粉灰、盐泽海玻璃瞳、星津左上视 |")
    lines.append("| 父传子（Y） | 余烬左偏领，和冰裂一样只走儿子 |")
    lines.append("| 母传 | 清河青灰肤、盐泽盐光、南泽苔缘瞳 |")
    lines.append("| 阈值（多基因） | 各国骨相，混血时是中间值而不是开关 |")
    lines.append("| 年觉 | 到龄才显：冷颌、静视、静手、宽站、钢喉领、侧耳晚笑 |")
    lines.append("| 功觉 | 灯市颊冷泽，伯爵或旗誓/冠线才亮，和河图同一条功勋门 |")
    lines.append("| 纯血 | 每国一个稀有表情，本冕未显则只是潜征 |")
    lines.append("")
    slot_zh = {
        "hair": "发", "iris": "虹膜", "bone": "骨相", "skin": "肤",
        "bearing": "体态/声", "regalia": "衣冠", "pure": "纯血", "mark": "冕征",
    }
    for house_id in NATION_ORDER:
        # find house
        house = next(h for h in HOUSES if h["id"] == house_id)
        nat = d["nations"][house_id]
        lines.append(f"### {house['name']} · {nat.get('name_en', house_id)}")
        lines.append("")
        lines.append(house["why"])
        lines.append("")
        lines.append("| 槽 | 征 | 律 | 显隐 | 盛年 |")
        lines.append("|---|---|---|---|---|")
        mark = sigs[MARK[house_id]]
        law0 = d["loci"][nat["locus"]]["law"]
        lines.append(f"| 冕征 | {mark['zh']} | {d['laws'][law0]['name']} | {mark['visibility']} | （原冕征，保持不变） |")
        for row in house["traits"]:
            if row["slot"] == "pure" or True:
                law_name = d["laws"][row["law"]]["name"]
                catch = " · 验伪" if row.get("catch") else ""
                lines.append(f"| {slot_zh.get(row['slot'], row['slot'])} | {row['zh']}{catch} | {law_name} | {row['vis']} | {row['desc']} |")
        lines.append("")
        nb = "、".join(sigs[i]["zh"] for i in lines and [])
        # noble / folk names
        def zh_of(ids):
            return "、".join(sigs[i]["zh"] if i in sigs else i for i in ids)
        # trait sets stored on lines
        # retrieve from data lines
        pass
        lines.append(f"贵胤（{house['noble_line']}）：见数据 `trait_set`，含原小征与发/骨回声，另有自家一征。")
        if house.get("noble_line_b"):
            lines.append(f"另一贵胤（{house['noble_line_b']}）：同样的回声，自家的征不同。")
        lines.append(f"民胤（{house['folk_line']}）：" + "、".join(row["zh"] for row in house["folk"]) + "。")
        lines.append("")
    lines.append("混血时两个国家的征可以同时出现在一句肖像里（`mixed blood, both houses visible`）。只剩一两成王血的人，显性征按来源血统的权重随机留下，骨相和母传数值会被拉低，看起来是残套。伪胤的基因组来自民胤，明征靠伪造提示词，`catch_traits` 里的隐征既没有等位，也不会画进肖像。")
    lines.append("")
    text = "\n".join(lines)
    doc = DOC.read_text()
    begin = "<!-- TRAIT-SET:BEGIN -->"
    end = "<!-- TRAIT-SET:END -->"
    if begin not in doc or end not in doc:
        raise SystemExit("design doc markers missing")
    pre, rest = doc.split(begin, 1)
    _, post = rest.split(end, 1)
    DOC.write_text(pre + begin + "\n" + text + "\n" + end + post)


if __name__ == "__main__":
    build()
