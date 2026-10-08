# -*- coding: utf-8 -*-
"""v8.7 hand-authored world content: 10 nations + 陆桥 region, 74 settlements, roads, signature arms.
Consumed by gen_world_v87.py -> project/data/world_v87.json + world_items_v87.json.
Positions are normalised (x, y) on each nation's existing v8 plate (assets/art/atlas/v8_atlas_nation_<id>.png),
picked by eye on the painted settlements so nodes sit on real towers/harbours/citadels."""

# id: (name, en, continent, world_pos on v8_atlas_world, material good, enemy prefix(es), bloodlines, job bias,
#      culture, smith house, common-arms prefix, stance)
NATIONS = {
 "ashbanner":  dict(name="灰烬邦", en="ASH BANNER", cont="west", wpos=(0.27, 0.46), mat="ashsteel",
                    foes=["bandit", "escort"], blood=["common_ash", "common_ash", "river_ward"], jobs=["light_inf", "squire", "heavy_inf"],
                    culture="陆桥西岸的烬灰平原。城堡群沿发光河脉排开，佣兵与商队是这里的血液。灰旗出身于此。",
                    smith="白垣军械署", prefix="烬纹", stance="home", toll=0),
 "shuoying":   dict(name="朔影国", en="SHUOYING", cont="west", wpos=(0.36, 0.22), mat="obsidian",
                    foes=["shadow", "snow"], blood=["common_ash", "ember_noble"], jobs=["hunter", "light_inf"],
                    culture="北境霜脊上的夜之公国。宫廷优雅而多疑，朔影家与灰旗世仇未解，关卡盘查最严。",
                    smith="夜阙影工坊", prefix="影曜", stance="hostile", toll=18),
 "qinghe":     dict(name="清河国", en="QINGHE", cont="west", wpos=(0.24, 0.66), mat="jade",
                    foes=["dye", "ink", "paper"], blood=["river_ward", "river_ward", "common_ash"], jobs=["hunter", "apprentice", "light_inf"],
                    culture="玉色三角洲与雾中果林。河卫世家掌渡口，旧钱谨慎，书院与染坊并立。",
                    smith="玉澜河工坊", prefix="澜玉", stance="wary", toll=8),
 "lantern":    dict(name="灯市联", en="LANTERN LEAGUE", cont="east", wpos=(0.88, 0.42), mat="lampglass",
                    foes=["lamp", "fisher", "tide"], blood=["common_ash", "river_ward"], jobs=["squire", "hunter", "light_inf"],
                    culture="海岸夜市与琉璃灯群岛结成的商联。价格一夜三变，契约比刀快。",
                    smith="琉光灯铸行", prefix="琉灯", stance="wary", toll=10),
 "frostcrown": dict(name="霜冕廷", en="FROSTCROWN", cont="west", wpos=(0.19, 0.18), mat="frostcrystal",
                    foes=["snow", "bell"], blood=["common_ash", "frost_crown"], jobs=["heavy_inf", "apprentice"],
                    culture="高原冰晶殿堂中的残存王廷。王胤稀薄而尊贵，廷议寂静，冰钟报时。",
                    smith="霜阙冰铸司", prefix="霜冕", stance="neutral", toll=12),
 "emberold":   dict(name="余烬旧邦", en="EMBER OLD REALM", cont="east", wpos=(0.78, 0.70), mat="magmaglass",
                    foes=["copper", "porcelain", "incense"], blood=["ember_noble", "ember_noble", "common_ash"], jobs=["heavy_inf", "apprentice", "warrior"],
                    culture="冷暮下龟裂的熔玻璃古城。余烬贵胤守着旧典与窑火，废墟里埋着最好的料。",
                    smith="焚阙窑铸坊", prefix="熔曜", stance="neutral", toll=10),
 "saltmarsh":  dict(name="盐泽盟", en="SALTMARSH", cont="west", wpos=(0.17, 0.82), mat="saltcrystal",
                    foes=["salt", "rain"], blood=["common_ash", "river_ward"], jobs=["hunter", "light_inf"],
                    culture="潮滩、盐晶与芦苇薄雾组成的城盟。盐引即货币，潮汐即法度。",
                    smith="晶垣盐铸会", prefix="盐晶", stance="neutral", toll=6),
 "irongorge":  dict(name="铁峡领", en="IRON GORGE", cont="east", wpos=(0.80, 0.16), mat="gorgesteel",
                    foes=["copper", "drum", "relay"], blood=["common_ash", "ember_noble"], jobs=["heavy_inf", "warrior", "light_inf"],
                    culture="垂直峡谷里的锻炉领。冷钢之光昼夜不熄，峡谷吊桥连通三层城区。",
                    smith="铁阙峡钢厂", prefix="峡钢", stance="neutral", toll=12),
 "starriver":  dict(name="星津邦", en="STARFORD", cont="east", wpos=(0.64, 0.25), mat="stardust",
                    foes=["flute", "relay", "bell"], blood=["river_ward", "common_ash"], jobs=["apprentice", "hunter", "squire"],
                    culture="夜河映出星座之桥的学术邦国。观象台与双虹桥是陆桥东岸的门户。",
                    smith="双虹星工院", prefix="星津", stance="friendly", toll=6),
 "southzephyr":dict(name="南泽邦", en="SOUTH ZEPHYR", cont="east", wpos=(0.62, 0.76), mat="hardwood",
                    foes=["bamboo", "hive", "grain"], blood=["common_ash", "river_ward"], jobs=["light_inf", "hunter"],
                    culture="萤雾森林与渡口灯火的湿地邦国。硬木、蜂蜡与南椒顺水而下。",
                    smith="雾林木铸社", prefix="泽木", stance="neutral", toll=8),
 "landbridge": dict(name="朔澜陆桥", en="LANDBRIDGE", cont="bridge", wpos=(0.51, 0.37), mat="iron",
                    foes=["escort", "bandit"], blood=["common_ash", "river_ward"], jobs=["light_inf", "squire", "hunter"],
                    culture="连接东西两陆的天险石桥与其驿城群。谁守住陆桥，谁就握住十国商路。",
                    smith="陆桥驿铁坊", prefix="桥锋", stance="neutral", toll=4, plate="v8_atlas_landbridge_inset"),
}

# kind: capital|city|town|port|fortress|village|castle ; biome = battle biome keyword (atlas_art.biome_for_map)
# sig: [(name, type, flavour)] x2 — first is the shop signature (tier 3), second the legendary (tier 4, unlocked by the city commission)
# quest: (title, kind, brief) — the city's unique signature commission
C = []
def city(nation, cid, name, kind, size, pos, biome, specialty, lore, produce, demand, sig, quest):
    C.append(dict(nation=nation, id=cid, name=name, kind=kind, size=size, pos=list(pos), biome=biome,
                  specialty=specialty, lore=lore, produce=produce, demand=demand, sig=sig, quest=quest))

# ── 灰烬邦 ───────────────────────────────────────────
city("ashbanner", "hq", "灰旗堡", "castle", 3, (0.29, 0.76), "fort", "家族城堡 · 经营中枢",
     "灰旗佣兵团的本堡。议事厅、校场、市集、工坊与祠堂都在这里——跑图归来，先回家。",
     ["grain"], ["herb"], [], None)
city("ashbanner", "ash_capital", "烬都·白垣", "capital", 5, (0.62, 0.38), "urban", "烬灰钢军械 · 陆桥议会",
     "白垣城墙由烬灰与冷钢浇筑，陆桥议会在此决定商路关税。军械署的烬灰钢是西陆制式兵器的标准。",
     ["ashsteel", "iron"], ["silk", "spice", "frostcrystal"],
     [("白垣制式长剑", "sword", "议会卫队的制式剑，烬灰钢夹芯，挥砍稳定。"), ("议会之誓·烬冠剑", "sword", "只授予为议会立下大功的佣兵团长。剑脊有一道永不熄灭的灰焰纹。")],
     ("议会密令·清剿关税贼", "clear", "有人冒充议会收取陆桥关税。查清他们的营地，清剿干净，别让议会丢脸。"))
city("ashbanner", "reed_ford", "苇原渡", "village", 2, (0.37, 0.19), "ford", "护商旧道 · 渡口粮仓",
     "苇海里的老渡口，商队出发前都在这里囤粮。渡口老人说，灰旗的旗子一亮，劫匪就让路。",
     ["grain", "herb"], ["iron", "ashsteel"],
     [("苇原分水枪", "spear", "渡口民兵的长枪，枪缨染成苇色，便于在芦苇中伏击。"), ("渡魂·千苇枪", "spear", "传说用渡口第一株苇根做柄，能感知水下的脚步声。")],
     ("苇原夜渡·护送粮船", "escort", "汛期粮船必须连夜过渡。护送船队到白垣，一袋粮都不能少。"))
city("ashbanner", "stone_slope", "石垒坡", "village", 2, (0.76, 0.76), "hill", "丘地佃庄 · 采石场",
     "丘地上层层石垒，佃农靠采石与种麦为生。过去有人在这里收「过路银」，直到灰旗来了。",
     ["iron", "grain"], ["herb", "tea"],
     [("石垒破甲锤", "axe", "采石匠改制的重锤，对重甲有奇效。"), ("坡脊·裂岩巨斧", "axe", "一斧劈开过整面石垒的传说之斧，斧刃嵌着烬灰钢。")],
     ("石垒坡余孽", "hunt", "过路银匪帮的残党躲进了采石洞。追上去，结束这件事。"))
city("ashbanner", "fog_vale", "雾谷", "village", 1, (0.16, 0.20), "fog", "药田 · 雾中猎场",
     "终年雾锁的谷地，药草长得最好。猎户熟悉每一条雾路，也熟悉雾里的危险。",
     ["herb"], ["grain", "ashsteel"],
     [("雾谷猎弓", "bow", "猎户的反曲弓，弓臂缠药藤，潮湿天气也不变形。"), ("无踪·雾隐长弓", "bow", "雾谷猎王的遗弓。拉满时，弓弦声会被雾吞没。")],
     ("雾中的药童", "escort", "药童要把一批珍稀药草送到灰旗堡的祠堂。雾路上有人盯着这批货。"))
city("ashbanner", "tide_bridge", "断潮渡哨", "fortress", 3, (0.88, 0.30), "fort", "陆桥西门户 · 河卫哨所",
     "守在断潮河口的石哨，是通往陆桥的最后一道关。河卫邦派人在此值夜。",
     ["ashsteel"], ["grain", "herb", "fur"],
     [("断潮守桥盾", "shield", "哨所值夜人的大盾，盾面有防滑的潮纹。"), ("不退·断潮城盾", "shield", "据说这面盾挡住过一整夜的洪水与箭雨。")],
     ("守桥夜战", "defend", "探子说今晚会有人夺桥。守住断潮渡哨，直到天亮。"))
city("ashbanner", "ash_market", "灰市", "town", 3, (0.92, 0.84), "urban", "西陆最大的佣兵市集",
     "灰市什么都卖：消息、刀剑、人手。陆桥商队在这里结算，赏金榜一天换三次。",
     ["ashsteel", "spice"], ["lampglass", "stardust"],
     [("灰市双刃短刀", "blade", "市集掮客最爱的防身短刀，好藏、好拔、好出手。"), ("黑账·灰市鬼刃", "blade", "灰市地下账房的镇店之刃，据说刀身上刻着三百笔血债。")],
     ("灰市赏金·假币工坊", "clear", "有人在灰市流通假银。找到工坊，砸掉它。"))
# ── 朔影国 ───────────────────────────────────────────
city("shuoying", "sy_capital", "朔都·夜阙", "capital", 5, (0.68, 0.43), "nightcamp", "影曜石宫廷 · 夜之议席",
     "夜阙宫殿只在入夜后点灯。朔影家的议席在此，外人入城须交出兵器名录。",
     ["obsidian", "fur"], ["grain", "tea", "spice"],
     [("夜阙影刃", "blade", "宫廷影卫的佩刀，影曜石刀刃吸光，夜里几乎看不见。"), ("朔夜·无月之刃", "blade", "朔影家主的家传刀，只在新月之夜出鞘。")],
     ("夜阙密使", "escort", "一位愿与灰旗和谈的朔影使者需要安全离开夜阙。别让宫廷影卫发现。"))
city("shuoying", "sy_frostfort", "寒垒", "fortress", 4, (0.17, 0.20), "snow", "北境军垒 · 雪原斥候",
     "建在冰崖上的军垒，朔影的斥候从这里出发。城墙上挂满了冻硬的旗。",
     ["fur", "obsidian"], ["grain", "herb"],
     [("寒垒斥候弩", "crossbow", "斥候的轻弩，弩臂裹貂皮，零下也能击发。"), ("霜脊·穿云重弩", "crossbow", "寒垒镇守的重弩，据说能射穿冰崖对面的旗杆。")],
     ("寒垒雪狼", "hunt", "雪狼群袭击了补给线。猎杀狼王，寒垒会记住这份人情。"))
city("shuoying", "sy_spire", "影针塔", "town", 3, (0.40, 0.43), "pass", "观测塔 · 影曜石矿",
     "一根黑色石针刺入夜空，塔下是影曜石矿脉。矿工说，塔会在暴风雪前低鸣。",
     ["obsidian"], ["iron", "grain"],
     [("影针刺枪", "spear", "矿工改制的细长刺枪，枪头是一整块影曜石。"), ("夜针·天穹之枪", "spear", "影针塔顶取下的一截石针，据说指向北极星。")],
     ("矿脉塌方", "deliver", "矿道塌方，困住了十二名矿工。把救援物资送到千阶城换回绞盘。"))
city("shuoying", "sy_banner", "墨旗关", "fortress", 3, (0.88, 0.30), "fort", "西北关隘 · 通往霜冕廷",
     "墨色旗帜在关楼上翻卷。朔影与霜冕廷的使者都要在这里换文书。",
     ["fur"], ["ashsteel", "jade"],
     [("墨旗关刀", "blade", "关卒的制式长刀，刀柄缠黑绸。"), ("墨雪·关山大刀", "blade", "关楼上供奉的古刀，刀身雪亮，刀镡墨黑。")],
     ("墨旗关夜袭", "defend", "霜原上的马贼盯上了墨旗关的粮仓。帮关卒守过这一夜。"))
city("shuoying", "sy_stair", "千阶城", "city", 4, (0.55, 0.67), "urban", "千阶石梯 · 工匠城",
     "整座城建在一道千级石阶上。下层是铁匠与皮匠，上层是朔影贵族。",
     ["fur", "obsidian"], ["silk", "jade"],
     [("千阶贵族细剑", "sword", "上层贵族的决斗细剑，护手是影曜石雕花。"), ("登阶·千夜细剑", "sword", "传说中在千阶决斗中从未落败的剑。")],
     ("千阶决斗", "hunt", "一名朔影贵族向灰旗下了决斗书。去千阶顶上，让他闭嘴。"))
city("shuoying", "sy_coast", "冷湾", "port", 3, (0.49, 0.91), "harbor", "北海冰港 · 南泽海路",
     "冰层里凿出的港口，海路通往遥远的南泽。渔民用影曜石做鱼钩。",
     ["fur", "obsidian"], ["spice", "hardwood", "tea"],
     [("冷湾破冰叉", "spear", "破冰渔叉改制的武器，三齿，带倒钩。"), ("鲸歌·冰海之叉", "spear", "据说曾刺中过北海冰鲸的古叉。")],
     ("冷湾走私船", "clear", "走私船在冷湾外抢劫渔民。登船清剿。"))
city("shuoying", "sy_ridge", "狼脊村", "village", 1, (0.18, 0.82), "snow", "边境猎村 · 灰烬邦门户",
     "朔影与灰烬邦边界上的猎村。村民两边都不信，只信猎物。",
     ["fur"], ["grain", "ashsteel"],
     [("狼脊猎刀", "blade", "猎村的剥皮刀，刀背有狼牙锯齿。"), ("头狼·脊骨弯刀", "blade", "狼脊村代代相传的弯刀，刀柄是头狼的脊骨。")],
     ("狼脊村的猎人", "scout", "村里的老猎人在边境失踪了。去影针塔打听消息再回来。"))
# ── 清河国 ───────────────────────────────────────────
city("qinghe", "qh_capital", "清都·玉澜", "capital", 5, (0.73, 0.37), "urban", "河卫世家 · 玉器与书院",
     "玉澜城依河而建，河卫世家掌管所有渡口。城里的书院藏着十国最全的河道图。",
     ["jade", "silk"], ["iron", "fur", "ashsteel"],
     [("玉澜河卫剑", "sword", "河卫世家子弟的佩剑，剑格嵌青玉。"), ("清澜·玉魄剑", "sword", "河卫家主的传承之剑，剑身内封着一缕河魂。")],
     ("玉澜书院失窃", "hunt", "书院的河道总图被盗。追回它，别让盗贼把图卖给朔影。"))
city("qinghe", "qh_mist", "雾果村", "village", 2, (0.18, 0.18), "fog", "雾中果林 · 灰烬邦边境",
     "雾里的果林一年两熟。灰烬邦的商队常来收果，也常在雾里迷路。",
     ["tea", "grain"], ["iron", "ashsteel"],
     [("雾果短弓", "bow", "果农驱鸟用的短弓，轻巧精准。"), ("霞雾·千果长弓", "bow", "用千年果树枝做的长弓，弓身仍会开花。")],
     ("雾果收成", "gather", "果农需要铁器修整果园。带 4 份铁料回来，换一季好茶。"))
city("qinghe", "qh_isle", "浮洲", "town", 3, (0.51, 0.69), "ford", "河心岛 · 染坊",
     "河心的浮岛，染坊的布匹在水面上晾成彩带。染工的手终年是蓝色的。",
     ["silk", "jade"], ["saltcrystal", "grain"],
     [("浮洲染刃", "blade", "染坊护卫的刀，刀身染过靛青，不反光。"), ("青澜·千染之刃", "blade", "在千缸染料中淬火的刀，刀纹如流水。")],
     ("染坊的毒", "clear", "有人在上游投毒，染缸一夜全黑。顺着河找到投毒者的营地。"))
city("qinghe", "qh_orchard", "粉霞坞", "village", 2, (0.16, 0.65), "plain", "花坞 · 蜂蜜与花茶",
     "春天整片河岸都是粉色的。坞里的女人们会用花瓣酿酒。",
     ["tea", "herb"], ["iron", "fur"],
     [("粉霞细杖", "staff", "花坞祭花用的细杖，杖头雕成花苞。"), ("春醒·霞落之杖", "staff", "据说挥动时会落下花瓣，伤者闻之止血。")],
     ("花期护坞", "defend", "花期时总有流寇来抢酒。守住粉霞坞。"))
city("qinghe", "qh_ford", "三汊渡", "town", 3, (0.42, 0.89), "ford", "三河交汇 · 盐泽商路",
     "三条河在此汇合，渡口税是清河国最大的财源之一。盐泽的盐船在此卸货。",
     ["silk", "tea"], ["saltcrystal", "iron"],
     [("三汊分水刺", "spear", "渡口卫的三叉短刺，适合在船上作战。"), ("汇流·三河之叉", "spear", "三汊渡的镇河之宝，传说能分开河水。")],
     ("三汊盐船", "escort", "一艘盐船要去盐泽盟的白幡镇。河上水匪很多。"))
city("qinghe", "qh_south", "碧潭城", "city", 4, (0.76, 0.72), "ford", "碧潭 · 玉矿与工匠",
     "城中央是一汪深不见底的碧潭，潭底有玉矿。匠人们在潭边雕玉。",
     ["jade"], ["fur", "obsidian", "grain"],
     [("碧潭玉护符", "charm", "潭底青玉雕成的护符，佩戴者心神清明。"), ("潭心·碧落玉玺", "charm", "从潭心最深处采出的玉，据说能映出敌人的杀意。")],
     ("潭底的东西", "hunt", "潭底有东西在吃采玉人。下去，把它解决掉。"))
city("qinghe", "qh_upper", "上河书院", "town", 3, (0.37, 0.20), "archive", "书院 · 河道图与秘术",
     "清河国最古老的书院，学子们研究河道、星象与秘术。院长和霜冕廷有通信。",
     ["silk"], ["stardust", "frostcrystal"],
     [("书院镇纸法器", "focus", "院长赐给优秀学子的镇纸，可以引导秘术。"), ("河图·上善之卷", "focus", "书院秘藏的河图原卷，展开时水纹流动。")],
     ("借书不还", "deliver", "书院要把一套河道志送到星津邦的观象台交换星图。"))
# ── 灯市联 ───────────────────────────────────────────
city("lantern", "lt_capital", "灯都·琉光", "capital", 5, (0.76, 0.24), "urban", "琉璃灯塔 · 夜市联议",
     "整座城由琉璃灯塔组成，夜里亮得像白昼。灯市联的议员都是商人。",
     ["lampglass", "spice"], ["iron", "grain", "fur"],
     [("琉光灯刃", "sword", "灯塔守卫的剑，剑身是琉璃包钢，会发微光。"), ("不夜·琉光圣剑", "sword", "灯市联镇城之剑，传说它亮着，灯都就不会陷落。")],
     ("灯都夜市抢劫案", "hunt", "一伙人连抢了三家灯铺。在他们出海前抓住他们。"))
city("lantern", "lt_harbor", "西港", "port", 4, (0.15, 0.39), "harbor", "东陆西港 · 星津门户",
     "西港面向星津邦，货船昼夜进出。码头工会比市政厅更有权。",
     ["spice", "lampglass"], ["stardust", "silk"],
     [("西港船钩枪", "spear", "码头工会的船钩长枪，能钩能刺。"), ("潮主·西港巨钩", "spear", "码头工会会长的权杖兼武器，据说钩沉过海盗船。")],
     ("码头罢工", "deliver", "工会需要一批南椒安抚码头工人。送到中灯屿。"))
city("lantern", "lt_isle", "中灯屿", "city", 4, (0.51, 0.50), "harbor", "灯群岛中心 · 琉璃工坊",
     "群岛中央最大的灯屿，琉璃匠在这里吹制灯罩。火光映着海面。",
     ["lampglass"], ["saltcrystal", "hardwood"],
     [("中灯琉璃杖", "staff", "琉璃匠的吹管杖，杖头是一盏小灯。"), ("海灯·千火之杖", "staff", "用千盏灯的灯芯炼成的杖，能照亮海底。")],
     ("琉璃窑熄火", "gather", "窑火需要硬木续燃。带 3 份南泽硬木回来。"))
city("lantern", "lt_south", "南灯坊", "town", 3, (0.78, 0.67), "urban", "灯坊街 · 刺客行会传闻",
     "狭窄的灯坊街，灯笼一盏挨一盏。传闻刺客行会就藏在某盏灯后面。",
     ["lampglass", "spice"], ["obsidian", "jade"],
     [("南灯袖箭", "crossbow", "灯坊工匠做的袖里小弩，装在灯笼骨里也能用。"), ("灯影·无声手弩", "crossbow", "刺客行会的传说之弩，发射时没有任何声音。")],
     ("灯后之人", "clear", "灯坊街的保护费越收越高。找到幕后的人。"))
city("lantern", "lt_hill", "望灯台", "fortress", 3, (0.35, 0.18), "fort", "山顶烽台 · 铁峡商道",
     "山顶的烽台能看见整个灯市联。铁峡领的钢锭从这里下山。",
     ["lampglass"], ["gorgesteel", "grain"],
     [("望灯烽火弓", "bow", "烽台守卫的长弓，箭矢可以点火作信号。"), ("烽燧·望海长弓", "bow", "据说一箭能把火信送到十里外的海上。")],
     ("烽台失守", "defend", "山贼盯上了望灯台的军械库。守住它。"))
city("lantern", "lt_docks", "渔火埠", "village", 2, (0.07, 0.82), "harbor", "渔村 · 盐泽海路",
     "渔火点点的小村，往盐泽盟的海船在这里补给。",
     ["spice", "grain"], ["saltcrystal", "iron"],
     [("渔火鱼叉", "spear", "渔民的鱼叉，结实耐用。"), ("夜潮·渔火神叉", "spear", "渔村祭海用的神叉，据说能唤来鱼群。")],
     ("渔火夜盗", "hunt", "夜里有人偷渔网，还伤了人。抓住他们。"))
city("lantern", "lt_lane", "夜航渡", "port", 3, (0.57, 0.85), "harbor", "夜航港 · 余烬旧邦商路",
     "只在夜里开船的港口。往余烬旧邦的商船避开白天的海盗。",
     ["lampglass", "spice"], ["magmaglass", "fur"],
     [("夜航弯刀", "blade", "夜航水手的弯刀，刀身涂黑。"), ("暗流·夜航长刀", "blade", "夜航渡第一船长的刀，从未在夜里输过。")],
     ("夜航护卫", "escort", "商船要去余烬旧邦的焰旗要塞。陆路护送货主。"))
# ── 霜冕廷 ───────────────────────────────────────────
city("frostcrown", "fc_capital", "冕都·霜阙", "capital", 5, (0.61, 0.37), "snow", "冰晶王廷 · 霜冕王胤",
     "冰晶宫阙矗立在高原上，王廷寂静如雪。霜冕王胤在此等待复兴。",
     ["frostcrystal"], ["grain", "spice", "tea"],
     [("霜阙近卫枪", "spear", "王廷近卫的长枪，枪头是一整块霜晶。"), ("冕光·霜王之枪", "spear", "霜冕先王的佩枪。王胤持之，霜晶会发出钟鸣。")],
     ("王胤的护卫", "escort", "一位霜冕王胤要秘密前往冰钟城。护送她，不许外人知道。"))
city("frostcrown", "fc_banner", "雪幡哨", "fortress", 3, (0.20, 0.24), "snow", "西境哨所 · 雪原巡逻",
     "雪原上的白幡哨所，巡逻队骑着雪驼出发。",
     ["fur"], ["grain", "herb"],
     [("雪幡骑枪", "lance", "雪原骑手的骑枪，枪尾缀白幡。"), ("白幡·雪崩骑枪", "lance", "据说冲锋时能引发雪崩的骑枪。")],
     ("雪原失踪", "scout", "一支巡逻队失踪了。去镜湖关打听，再回来报告。"))
city("frostcrown", "fc_spire", "孤针镇", "town", 3, (0.47, 0.22), "snow", "冰针塔 · 霜晶矿",
     "一根冰针刺向天空，镇民在塔下开采霜晶。",
     ["frostcrystal"], ["iron", "hardwood"],
     [("孤针冰刺", "sword", "矿工用霜晶磨成的细剑，极寒锋利。"), ("孤高·冰针圣剑", "sword", "从冰针塔顶折下的一截，永远不会融化。")],
     ("矿下的寒兽", "hunt", "霜晶矿下醒来了一只寒兽。处理掉它。"))
city("frostcrown", "fc_tower", "冰钟城", "city", 4, (0.88, 0.30), "snow", "冰钟 · 王廷报时与秘术",
     "巨大的冰钟每天鸣响十二次。秘术师们说钟声能驱散邪祟。",
     ["frostcrystal", "fur"], ["silk", "stardust"],
     [("冰钟秘杖", "staff", "钟楼秘术师的杖，杖头悬一枚小冰钟。"), ("钟鸣·万籁之杖", "staff", "敲响时万籁俱寂，敌人的咒语也会被打断。")],
     ("冰钟裂痕", "gather", "冰钟出现了裂痕。带 3 份霜晶来修补。"))
city("frostcrown", "fc_lake", "镜湖关", "fortress", 4, (0.55, 0.69), "snow", "冰湖关隘 · 王廷南门",
     "关隘建在冰封的镜湖上，湖面映出整座关城。",
     ["frostcrystal"], ["ashsteel", "grain"],
     [("镜湖冰盾", "shield", "关卒的盾，盾面打磨如镜，能晃敌人的眼。"), ("镜渊·无瑕之盾", "shield", "据说从未被打出过一道划痕的盾。")],
     ("镜湖破冰", "defend", "有人想在冰面最薄时偷袭镜湖关。守住它。"))
city("frostcrown", "fc_peak", "鹰岩村", "village", 2, (0.90, 0.69), "pass", "鹰岩 · 雪鹰与猎手",
     "建在鹰岩上的小村，村民驯养雪鹰。",
     ["fur"], ["grain", "iron"],
     [("鹰岩猎弓", "bow", "驯鹰人的猎弓，弓梢雕鹰首。"), ("鹰王·穿岩之弓", "bow", "据说一箭射穿过鹰岩的弓。")],
     ("雪鹰被盗", "hunt", "有人偷走了村里的雪鹰幼雏。追回来。"))
city("frostcrown", "fc_plateau", "冻原村", "village", 1, (0.18, 0.85), "snow", "冻原 · 朔影边境",
     "冻原上的游牧村落，朔影的商人会在这里交易皮毛。",
     ["fur"], ["grain", "tea"],
     [("冻原手斧", "axe", "牧民的手斧，能砍冰也能砍人。"), ("永冻·冰原战斧", "axe", "冻原部族的传承战斧，斧刃上的冰从未融化。")],
     ("冻原迁徙", "escort", "牧民要迁往雪幡哨避寒。路上有狼也有人。"))
# ── 余烬旧邦 ─────────────────────────────────────────
city("emberold", "eo_capital", "旧都·焚阙", "capital", 5, (0.59, 0.50), "forge", "熔玻古城 · 余烬贵胤",
     "龟裂的熔玻璃城墙下仍有余温。余烬贵胤守着祖先的窑火，等一个复兴的机会。",
     ["magmaglass"], ["grain", "tea", "frostcrystal"],
     [("焚阙熔刃", "sword", "余烬贵胤的佩剑，剑身是熔玻璃包钢，暗红纹路如岩浆。"), ("余烬·焚天之剑", "sword", "旧邦末代君王的剑，据说握住它的人能听见古城的心跳。")],
     ("古城地宫", "hunt", "焚阙地宫里有盗墓贼在挖祖陵。清理干净。"))
city("emberold", "eo_kiln", "窑火镇", "town", 3, (0.13, 0.22), "forge", "千年窑 · 冰瓷",
     "镇上的千年窑从未熄过火。烧出的冰瓷薄如蝉翼。",
     ["magmaglass"], ["hardwood", "iron"],
     [("窑火锻锤", "axe", "窑工的重锤，锤头是熔玻璃。"), ("千窑·不熄之锤", "axe", "千年窑的镇窑锤，据说锤下的火永不熄灭。")],
     ("窑火续薪", "gather", "千年窑需要硬木续火。带 4 份南泽硬木回来。"))
city("emberold", "eo_archive", "灰典城", "city", 4, (0.37, 0.20), "archive", "旧典 · 秘术学府",
     "城中的灰典阁收藏着旧邦所有的典籍，秘术师在此研究余烬之术。",
     ["magmaglass", "silk"], ["stardust", "jade"],
     [("灰典法器", "focus", "学府颁发的法器，内封一页灰典。"), ("典焰·焚书之典", "focus", "传说中焚毁了半个旧邦的禁典，仍在燃烧。")],
     ("禁典外流", "deliver", "一页禁典落到了外人手里，已被赎回。送去旧都封存。"))
city("emberold", "eo_shrine", "余火祠", "village", 2, (0.16, 0.35), "shrine", "祠堂 · 余火祭司",
     "供奉旧邦先祖的祠堂，祭司守着一盏不灭的余火。",
     ["herb", "magmaglass"], ["grain", "tea"],
     [("余火祭杖", "staff", "祭司的杖，杖头燃着微弱的余火。"), ("长明·余火圣杖", "staff", "祠堂中那盏长明余火的灯台，据说能照亮亡者的路。")],
     ("祠火将熄", "defend", "有人想熄灭祠堂的余火。守护祭司过完祭典。"))
city("emberold", "eo_crack", "裂谷村", "village", 1, (0.29, 0.74), "pass", "裂谷 · 南泽边境",
     "大地裂开的谷底有一座小村，熔玻璃矿脉暴露在外。",
     ["magmaglass"], ["grain", "hardwood"],
     [("裂谷矿镐斧", "axe", "矿工的镐斧，一头尖一头宽。"), ("地裂·熔心之斧", "axe", "从裂谷最深处挖出的古斧，斧心仍在发烫。")],
     ("裂谷塌陷", "scout", "裂谷又裂开了一道口子。去古樟祠请祭司来看看，再回来。"))
city("emberold", "eo_banner", "焰旗要塞", "fortress", 4, (0.88, 0.30), "fort", "东北要塞 · 灯市商路",
     "焰色旗帜飘扬的要塞，守着通往灯市联的商路。",
     ["magmaglass"], ["lampglass", "grain"],
     [("焰旗战刀", "blade", "要塞卫的长刀，刀镡是熔玻璃。"), ("焚旗·烈阵战刀", "blade", "要塞历代守将的刀，砍断过三面敌旗。")],
     ("要塞围城", "defend", "灯市的雇佣兵要来夺要塞。帮守将守住。"))
city("emberold", "eo_glass", "熔镜镇", "town", 3, (0.73, 0.65), "forge", "熔镜 · 琉璃与铠甲",
     "镇上的匠人把熔玻璃打磨成镜面铠甲。",
     ["magmaglass"], ["iron", "fur"],
     [("熔镜轻甲", "armor", "镜面熔玻璃轻甲，能偏转箭矢。"), ("镜焰·熔光重铠", "armor", "熔镜镇大师的毕生之作，铠面映出的火光会灼伤敌人的眼。")],
     ("镜甲试炼", "hunt", "大师要用一头熔岩兽的甲壳做铠。猎杀它。"))
# ── 盐泽盟 ───────────────────────────────────────────
city("saltmarsh", "sm_capital", "盐都·晶垣", "capital", 5, (0.49, 0.52), "marsh", "盐晶城 · 盐引交易所",
     "巨大的盐晶从潮滩中长出，城就建在晶体之间。盐引交易所决定西陆的盐价。",
     ["saltcrystal"], ["iron", "hardwood", "fur"],
     [("晶垣盐晶剑", "sword", "盐晶包钢的剑，剑身透明如冰。"), ("潮王·晶垣圣剑", "sword", "盐泽盟盟主的剑，据说是从第一块盐晶中取出的。")],
     ("盐引伪造", "hunt", "有人伪造盐引扰乱市场。抓住伪造者。"))
city("saltmarsh", "sm_west", "苇幡村", "village", 1, (0.20, 0.26), "marsh", "芦苇村 · 灰烬邦边境",
     "芦苇丛中挂满白幡的小村。村民说幡是给潮神看的。",
     ["saltcrystal", "grain"], ["iron", "ashsteel"],
     [("苇幡竹枪", "spear", "芦苇村民的竹枪，轻便。"), ("潮神·苇幡神枪", "spear", "祭潮神用的神枪，枪缨是千年芦苇。")],
     ("潮神祭", "defend", "潮神祭当晚总有人来抢祭品。守住村子。"))
city("saltmarsh", "sm_banner", "白幡镇", "town", 3, (0.74, 0.24), "marsh", "白幡 · 清河商路",
     "镇口一排白幡，清河的商船在此靠岸。",
     ["saltcrystal"], ["silk", "tea"],
     [("白幡短弩", "crossbow", "镇卫的短弩，弩身漆白。"), ("白潮·连珠之弩", "crossbow", "能连发五矢的传说之弩。")],
     ("白幡失窃", "clear", "镇上的盐仓被盗。盗贼的营地就在芦苇深处。"))
city("saltmarsh", "sm_far", "潮哨", "fortress", 3, (0.88, 0.30), "fort", "潮汐哨塔 · 海防",
     "潮汐最高时哨塔会被海水包围，成为孤岛。",
     ["saltcrystal"], ["grain", "ashsteel"],
     [("潮哨长戟", "spear", "哨塔守卫的长戟，戟刃是盐晶。"), ("怒潮·孤哨之戟", "spear", "据说孤身守住潮哨一夜的守卫留下的戟。")],
     ("潮哨夜袭", "defend", "海盗要趁大潮夺哨。守住。"))
city("saltmarsh", "sm_mid", "晒盐场", "village", 2, (0.63, 0.25), "plain", "盐田 · 盐工",
     "一望无际的盐田，盐工们在烈日下劳作。",
     ["saltcrystal", "grain"], ["herb", "tea"],
     [("盐工耙斧", "axe", "盐工的耙斧，结实。"), ("盐田·白浪巨斧", "axe", "盐工领袖的巨斧，挥动时盐晶飞溅如浪。")],
     ("盐工病了", "gather", "盐工们染了湿热病。带 3 份药草回来。"))
city("saltmarsh", "sm_south", "晶滩港", "port", 4, (0.50, 0.87), "harbor", "南港 · 灯市海路",
     "盐泽盟最大的港口，海船往返于灯市联。",
     ["saltcrystal", "spice"], ["lampglass", "hardwood"],
     [("晶滩水手刀", "blade", "水手的弯刀，刀身抗盐蚀。"), ("海晶·破浪长刀", "blade", "晶滩港老船王的刀，劈开过风暴。")],
     ("晶滩海盗", "clear", "海盗在港外劫船。清剿他们的登陆营地。"))
city("saltmarsh", "sm_shoal", "芦浦城", "city", 4, (0.29, 0.77), "marsh", "芦浦 · 水上城",
     "建在芦苇浅滩上的水城，房屋都架在木桩上。",
     ["saltcrystal", "herb"], ["iron", "fur"],
     [("芦浦轻甲", "armor", "浸过盐水的皮甲，轻便耐用。"), ("浦魂·盐晶鳞甲", "armor", "镶满盐晶鳞片的铠甲，据说在水中更坚固。")],
     ("浅滩巨鳄", "hunt", "浅滩里有一头巨鳄吃人。猎杀它。"))
# ── 铁峡领 ───────────────────────────────────────────
city("irongorge", "ig_capital", "峡都·铁阙", "capital", 5, (0.73, 0.33), "fort", "峡钢锻炉 · 铁峡领主",
     "铁阙城沿峡谷崖壁层层而建，锻炉的冷光昼夜不熄。",
     ["gorgesteel", "iron"], ["grain", "tea", "herb"],
     [("铁阙峡钢剑", "sword", "峡钢锻造的剑，坚韧无比。"), ("铁峡·万锻之剑", "sword", "据说经过一万次锻打的剑，铁峡领主的佩剑。")],
     ("峡都叛工", "clear", "一伙叛工占据了废弃锻炉。清剿他们。"))
city("irongorge", "ig_plateau", "高台镇", "town", 3, (0.22, 0.20), "pass", "崖顶高台 · 鹰旗商道",
     "崖顶的平台小镇，吊篮把货物从谷底拉上来。",
     ["gorgesteel"], ["grain", "spice"],
     [("高台吊索枪", "spear", "吊篮工人的长枪，枪尾有钩索。"), ("凌崖·天台之枪", "spear", "据说从崖顶掷下能钉穿谷底巨石的枪。")],
     ("吊篮断了", "deliver", "吊篮绳索断了，镇上急需一批新索。从谷底市运上来。"))
city("irongorge", "ig_mine", "深镐村", "village", 2, (0.15, 0.65), "pass", "深矿 · 矿工村",
     "矿道深入山腹的小村，矿工们一辈子不见阳光。",
     ["iron", "gorgesteel"], ["grain", "herb"],
     [("深镐矿斧", "axe", "矿工的镐斧。"), ("地心·深镐巨斧", "axe", "从最深矿道挖出的古斧。")],
     ("矿道怪声", "hunt", "矿道深处有怪声，已经有人失踪。下去查。"))
city("irongorge", "ig_banner", "鹰旗关", "fortress", 4, (0.88, 0.30), "fort", "东境关隘 · 灯市商道",
     "鹰旗飘扬的关隘，守着通往灯市联的山道。",
     ["gorgesteel"], ["lampglass", "grain"],
     [("鹰旗重盾", "shield", "关卒的峡钢重盾。"), ("鹰扬·铁壁之盾", "shield", "据说挡住过一整支骑兵冲锋的盾。")],
     ("鹰旗关告急", "defend", "山贼集结要攻关。帮守军守住。"))
city("irongorge", "ig_tower", "悬桥城", "city", 4, (0.49, 0.47), "pass", "峡谷吊桥 · 三层城区",
     "三层吊桥连接峡谷两岸，城区悬在半空。",
     ["gorgesteel"], ["silk", "tea"],
     [("悬桥重弩", "crossbow", "吊桥守卫的重弩，峡钢弩臂。"), ("悬空·贯峡之弩", "crossbow", "能一箭射穿峡谷的传说重弩。")],
     ("吊桥破坏者", "hunt", "有人在夜里锯吊桥的绳索。抓住他。"))
city("irongorge", "ig_bottom", "谷底市", "town", 3, (0.55, 0.89), "forge", "谷底市集 · 锻炉街",
     "峡谷最底层的市集，锻炉街的火光映着溪流。",
     ["gorgesteel", "iron"], ["grain", "spice"],
     [("谷底锻甲", "armor", "锻炉街的峡钢板甲。"), ("炉心·峡钢重铠", "armor", "锻炉街大师的毕生之作，重而不滞。")],
     ("锻炉街火灾", "gather", "锻炉街失火，需要粮食安置灾民。带 10 份粮回来。"))
city("irongorge", "ig_lower", "炉烟村", "village", 2, (0.79, 0.72), "forge", "炉烟 · 星津边境",
     "炉烟缭绕的小村，星津的学者常来这里买峡钢。",
     ["gorgesteel"], ["stardust", "grain"],
     [("炉烟铁锤", "axe", "铁匠的锻锤。"), ("炉神·烟火之锤", "axe", "据说炉神亲手打造的锤。")],
     ("炉烟路劫", "escort", "星津学者买了一批峡钢要运回观象台。护送他。"))
# ── 星津邦 ───────────────────────────────────────────
city("starriver", "sr_capital", "星都·双虹", "capital", 5, (0.50, 0.50), "ford", "双虹桥 · 星象学院",
     "两道虹桥横跨夜河，桥上的星灯与河中的倒影连成星座。",
     ["stardust", "silk"], ["iron", "grain", "fur"],
     [("双虹星杖", "staff", "星象学院的法杖，杖头镶星砂。"), ("虹桥·双星之杖", "staff", "双虹桥建成时铸造的法杖，能召唤星光。")],
     ("双虹桥失窃", "hunt", "桥上的星灯被盗了三盏。追回来。"))
city("starriver", "sr_nw", "观象台", "town", 3, (0.20, 0.21), "shrine", "观象台 · 星图",
     "观象台的学者每夜记录星象，星图卖到十国。",
     ["stardust"], ["gorgesteel", "silk"],
     [("观象星盘", "focus", "学者的星盘，可引导星光。"), ("天枢·观象星盘", "focus", "观象台镇台之宝，能预知敌人的动向。")],
     ("星图被盗", "scout", "一份星图被盗，据说流到了炉烟村。去打听再回来。"))
city("starriver", "sr_west", "西津村", "village", 2, (0.15, 0.38), "ford", "西渡口 · 陆桥东门户",
     "陆桥东端的渡口小村，西来的旅人在此第一次看见星河。",
     ["grain", "stardust"], ["ashsteel", "iron"],
     [("西津渡刀", "blade", "渡口卫的短刀。"), ("星渡·西津长刀", "blade", "据说斩过星河中的倒影的刀。")],
     ("陆桥来客", "escort", "一位西陆商人要去星都。护送他。"))
city("starriver", "sr_pagoda", "塔影城", "city", 4, (0.78, 0.30), "urban", "七层塔 · 星砂工坊",
     "七层宝塔的影子落在河上，星砂工坊在塔下研磨星砂。",
     ["stardust"], ["jade", "silk"],
     [("塔影星弓", "bow", "星砂镶嵌的长弓，箭矢带星光。"), ("七曜·塔影神弓", "bow", "七层塔顶供奉的神弓。")],
     ("塔下的贼", "clear", "有人在塔下挖地道偷星砂。清剿。"))
city("starriver", "sr_east", "东津港", "port", 4, (0.90, 0.46), "harbor", "东港 · 灯市海路",
     "星津邦的东港，与灯市联的西港隔海相望。",
     ["stardust", "spice"], ["lampglass", "hardwood"],
     [("东津船弩", "crossbow", "港口卫的船弩。"), ("星潮·东津重弩", "crossbow", "东津港镇港重弩。")],
     ("东津走私", "clear", "走私犯在港外的小岛上设了营地。清剿。"))
city("starriver", "sr_sw", "落星村", "village", 1, (0.29, 0.75), "plain", "陨星田 · 星砂矿",
     "传说星星落在这里，村民在田里挖出星砂。",
     ["stardust", "grain"], ["iron", "tea"],
     [("落星镰", "blade", "农夫的镰刀，刃口镶星砂。"), ("陨星·坠天之镰", "blade", "用陨星铁打造的镰刀。")],
     ("陨星争夺", "defend", "又有星星落下了。盗贼要来抢。守住村子。"))
city("starriver", "sr_south", "渡星关", "fortress", 4, (0.73, 0.76), "fort", "南关 · 南泽商路",
     "守着通往南泽邦的关隘，关楼上有一座小观象台。",
     ["stardust"], ["hardwood", "grain"],
     [("渡星关枪", "spear", "关卒的长枪。"), ("南斗·渡星之枪", "spear", "关楼供奉的古枪，据说指向南斗。")],
     ("南关告急", "defend", "南泽的走私团伙要冲关。守住。"))
# ── 南泽邦 ───────────────────────────────────────────
city("southzephyr", "sz_capital", "泽都·雾林", "capital", 5, (0.51, 0.43), "fog", "雾林城 · 萤火议会",
     "建在巨树上的城市，萤火虫是这里的灯。萤火议会由各部族长老组成。",
     ["hardwood", "spice"], ["iron", "fur", "saltcrystal"],
     [("雾林硬木弓", "bow", "南泽硬木的长弓，弹性极佳。"), ("萤王·雾林神弓", "bow", "萤火议会议长的神弓，箭矢带萤光。")],
     ("萤火议会的危机", "hunt", "一个部族叛乱了。找到叛军首领。"))
city("southzephyr", "sz_temple", "古樟祠", "village", 2, (0.37, 0.20), "shrine", "古樟树祠 · 余烬边境",
     "一棵千年古樟下的祠堂，祭司能听懂树语。",
     ["herb", "hardwood"], ["magmaglass", "grain"],
     [("古樟祭杖", "staff", "古樟枝做的祭杖。"), ("千年·古樟神杖", "staff", "据说是古樟树主动折下的一枝。")],
     ("古樟病了", "gather", "古樟树病了，祭司需要药草。带 4 份药草回来。"))
city("southzephyr", "sz_vine", "藤桥村", "village", 1, (0.16, 0.65), "fog", "藤桥 · 雨林部族",
     "藤蔓编成的吊桥连接着树屋。",
     ["hardwood", "herb"], ["iron", "saltcrystal"],
     [("藤桥吹箭", "bow", "部族的吹箭筒。"), ("林魂·藤蔓长弓", "bow", "藤蔓自己长成的长弓。")],
     ("藤桥断了", "deliver", "藤桥断了，需要一批绳索。从雾港运来。"))
city("southzephyr", "sz_harbor", "雾港", "port", 4, (0.91, 0.44), "harbor", "雾港 · 星津海路",
     "雾中的港口，船只靠萤火灯塔导航。",
     ["spice", "hardwood"], ["stardust", "iron"],
     [("雾港船刀", "blade", "水手的弯刀。"), ("雾海·萤港长刀", "blade", "雾港港主的刀。")],
     ("雾港迷航", "escort", "一艘船在雾中迷航后靠岸了，船主要去渡星关。护送他。"))
city("southzephyr", "sz_south", "南湾城", "city", 4, (0.88, 0.84), "harbor", "南湾 · 冷湾海路",
     "南泽邦最大的城市，海船往返于遥远的北海冷湾。",
     ["spice", "hardwood"], ["fur", "obsidian"],
     [("南湾轻甲", "armor", "硬木片与藤编的轻甲。"), ("湾主·木鳞重铠", "armor", "硬木鳞片编成的重铠。")],
     ("南湾海盗", "clear", "海盗在南湾外设了营地。清剿。"))
city("southzephyr", "sz_isle", "萤洲", "town", 3, (0.50, 0.69), "marsh", "萤火洲 · 蜂蜡",
     "萤火虫聚集的沙洲，蜂农在此采蜡。",
     ["spice", "herb"], ["iron", "grain"],
     [("萤洲护符", "charm", "蜂蜡封着萤火的护符。"), ("萤心·不灭护符", "charm", "据说里面封着萤火之王。")],
     ("萤洲蜂灾", "hunt", "毒蜂群袭击了萤洲。找到蜂巢。"))
city("southzephyr", "sz_bamboo", "竹篁寨", "fortress", 3, (0.27, 0.32), "fog", "竹林要塞 · 部族战士",
     "竹林深处的要塞，部族战士在此训练。",
     ["hardwood"], ["iron", "gorgesteel"],
     [("竹篁长枪", "spear", "竹枪，枪头是硬木。"), ("篁影·万竹之枪", "spear", "竹篁寨镇寨之枪。")],
     ("竹篁试炼", "hunt", "寨主要你证明实力。击败竹林里的挑战者。"))
# ── 朔澜陆桥 ─────────────────────────────────────────
city("landbridge", "lb_west", "西桥头堡", "fortress", 4, (0.18, 0.20), "fort", "陆桥西端 · 灰烬邦门户",
     "陆桥西端的桥头堡，灰烬邦与陆桥议会共同驻守。",
     ["iron", "ashsteel"], ["grain", "herb"],
     [("桥头斩马刀", "blade", "桥头堡守卫的斩马刀。"), ("天堑·桥头大刀", "blade", "据说守住陆桥百年的刀。")],
     ("桥头堡告急", "defend", "有人要夺西桥头堡。守住。"))
city("landbridge", "lb_mid", "陆桥驿", "town", 3, (0.54, 0.41), "pass", "陆桥中段 · 驿站与商队",
     "陆桥正中的驿城，十国商队都在这里歇脚。",
     ["grain", "iron"], ["spice", "silk", "lampglass"],
     [("陆桥驿骑枪", "lance", "驿骑的骑枪。"), ("通衢·十国骑枪", "lance", "据说跑遍十国的驿骑留下的枪。")],
     ("驿站的信", "deliver", "一封急信要送到东桥头堡。"))
city("landbridge", "lb_east", "东桥头堡", "fortress", 4, (0.89, 0.45), "fort", "陆桥东端 · 星津门户",
     "陆桥东端的桥头堡，星津邦驻守。",
     ["iron", "stardust"], ["grain", "ashsteel"],
     [("东桥长戟", "spear", "东桥守卫的长戟。"), ("东望·星桥之戟", "spear", "东桥头堡镇堡之戟。")],
     ("东桥夜袭", "defend", "盗匪要趁夜冲桥。守住。"))
city("landbridge", "lb_south", "桥市", "town", 3, (0.29, 0.75), "urban", "桥下市集 · 十国货物",
     "陆桥下的市集，十国的货物都能在这里买到。",
     ["spice", "silk"], ["frostcrystal", "magmaglass"],
     [("桥市护身符", "charm", "桥市商人的护身符。"), ("万商·桥市金符", "charm", "桥市商会会长的护符，据说能让人逢凶化吉。")],
     ("桥市假货", "clear", "有人在桥市卖假货。找到他们的仓库。"))

# Roads inside each region: (a, b, danger 1-3). Days derived from plate distance.
ROADS = [
 # ashbanner
 ("hq", "stone_slope", 1), ("hq", "fog_vale", 2), ("hq", "ash_capital", 1), ("fog_vale", "reed_ford", 1), ("reed_ford", "ash_capital", 1),
 ("ash_capital", "tide_bridge", 1), ("ash_capital", "stone_slope", 2), ("stone_slope", "ash_market", 1), ("ash_market", "tide_bridge", 2),
 # shuoying
 ("sy_frostfort", "sy_spire", 2), ("sy_spire", "sy_capital", 2), ("sy_capital", "sy_banner", 2), ("sy_capital", "sy_stair", 1),
 ("sy_stair", "sy_coast", 2), ("sy_spire", "sy_ridge", 3), ("sy_ridge", "sy_coast", 2), ("sy_stair", "sy_spire", 2),
 # qinghe
 ("qh_mist", "qh_upper", 1), ("qh_upper", "qh_capital", 1), ("qh_capital", "qh_south", 1), ("qh_south", "qh_isle", 1),
 ("qh_isle", "qh_ford", 2), ("qh_isle", "qh_orchard", 2), ("qh_orchard", "qh_mist", 2), ("qh_upper", "qh_isle", 2), ("qh_ford", "qh_orchard", 2),
 # lantern
 ("lt_hill", "lt_capital", 2), ("lt_hill", "lt_harbor", 2), ("lt_harbor", "lt_isle", 1), ("lt_isle", "lt_capital", 1), ("lt_isle", "lt_south", 1),
 ("lt_south", "lt_lane", 2), ("lt_harbor", "lt_docks", 2), ("lt_docks", "lt_lane", 3), ("lt_capital", "lt_south", 1),
 # frostcrown
 ("fc_banner", "fc_spire", 2), ("fc_spire", "fc_capital", 1), ("fc_capital", "fc_tower", 1), ("fc_capital", "fc_lake", 1),
 ("fc_lake", "fc_peak", 2), ("fc_tower", "fc_peak", 2), ("fc_banner", "fc_plateau", 3), ("fc_plateau", "fc_lake", 2),
 # emberold
 ("eo_kiln", "eo_shrine", 1), ("eo_kiln", "eo_archive", 2), ("eo_archive", "eo_capital", 1), ("eo_shrine", "eo_capital", 2),
 ("eo_shrine", "eo_crack", 2), ("eo_crack", "eo_capital", 2), ("eo_capital", "eo_glass", 1), ("eo_capital", "eo_banner", 2), ("eo_banner", "eo_glass", 2),
 # saltmarsh
 ("sm_west", "sm_capital", 2), ("sm_west", "sm_shoal", 2), ("sm_capital", "sm_mid", 1), ("sm_mid", "sm_banner", 1), ("sm_banner", "sm_far", 2),
 ("sm_capital", "sm_south", 1), ("sm_shoal", "sm_south", 2), ("sm_capital", "sm_shoal", 1),
 # irongorge
 ("ig_plateau", "ig_tower", 2), ("ig_plateau", "ig_mine", 3), ("ig_mine", "ig_bottom", 2), ("ig_tower", "ig_capital", 1), ("ig_capital", "ig_banner", 2),
 ("ig_tower", "ig_bottom", 1), ("ig_bottom", "ig_lower", 2), ("ig_capital", "ig_lower", 2),
 # starriver
 ("sr_nw", "sr_west", 1), ("sr_west", "sr_capital", 1), ("sr_nw", "sr_capital", 2), ("sr_capital", "sr_pagoda", 1), ("sr_pagoda", "sr_east", 1),
 ("sr_capital", "sr_sw", 2), ("sr_capital", "sr_south", 1), ("sr_south", "sr_east", 2), ("sr_sw", "sr_south", 2),
 # southzephyr
 ("sz_temple", "sz_bamboo", 2), ("sz_bamboo", "sz_capital", 2), ("sz_temple", "sz_capital", 2), ("sz_capital", "sz_harbor", 2),
 ("sz_capital", "sz_isle", 1), ("sz_isle", "sz_vine", 2), ("sz_vine", "sz_bamboo", 3), ("sz_isle", "sz_south", 2), ("sz_harbor", "sz_south", 2),
 # landbridge
 ("lb_west", "lb_mid", 2), ("lb_mid", "lb_east", 2), ("lb_mid", "lb_south", 1), ("lb_south", "lb_west", 1),
]
# Cross-border crossings and sea lanes: (a, b, days, danger, kind)
CROSS = [
 ("tide_bridge", "lb_west", 2, 1, "border"), ("lb_east", "sr_west", 2, 1, "border"),
 ("fog_vale", "sy_ridge", 3, 3, "border"), ("reed_ford", "qh_mist", 3, 1, "border"), ("hq", "sm_west", 3, 2, "border"),
 ("sy_banner", "fc_plateau", 3, 2, "border"), ("qh_ford", "sm_banner", 3, 1, "border"), ("sy_frostfort", "fc_banner", 4, 3, "border"),
 ("sr_nw", "ig_lower", 3, 2, "border"), ("sr_east", "lt_harbor", 2, 1, "border"), ("ig_banner", "lt_hill", 3, 2, "border"),
 ("lt_lane", "eo_banner", 3, 2, "border"), ("eo_crack", "sz_temple", 3, 2, "border"), ("sz_harbor", "sr_south", 3, 1, "border"),
 ("sm_south", "lt_docks", 6, 0, "sea"), ("sy_coast", "sz_south", 8, 0, "sea"),
]
