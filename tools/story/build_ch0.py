#!/usr/bin/env python3
"""Build project/data/story/chapters/ch0.json from the prologue script below.

Source of truth for the words: docs/story/prologue-novella.md (story) and
docs/story/prologue-bible.md (beats -> mechanics). Edit here, rerun, commit the JSON.
Line ids are derived from beat id + order, so reordering a beat renumbers only that beat.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "project/data/story/chapters/ch0.json"
RET = "res://scenes/story/chapter0.tscn"

N = "旁白"
WT = "石垒·晚担"
DY = "苇原·灯影"
OS = "老旗手"
MOM = "石垒·荞娘"
JB = "槐里·景伯"
QH = "槐里·青禾"
HZ = "鸦渡·衡舟"
SV = "活口"
DENGYING = "我跟着你不是为了姓。是为了隘口那条路还能走人。不过——姓也重要。没姓的旗，风一吹就散。"


def L(speaker, text, when=None, expr=None, **stage):
    row = {"speaker": speaker, "text": text}
    if expr:
        row["expression"] = expr
    if stage:
        row["stage"] = stage
    if when:
        row["when"] = when
    return row


def F(flag):
    return {"flag": flag}


def goto(beat="next"):
    return {"op": "goto", "beat": beat}


def setf(flag):
    return {"op": "set_flag", "flag": flag, "value": True}


def A(aid, label, do, when=None, disabled=False):
    row = {"id": aid, "label": label, "do": do}
    if when:
        row["when"] = when
    if disabled:
        row["disabled"] = True
    return row


BRIEF = "pro_guides_brief"

BEATS = [
    {
        "id": "0.0", "title": "麦未黄",
        "lines": [
            L(N, "你是石垒坡的佃户，没有姓，也没有爵位。刚挑完一担石头，肩膀还疼。", music="castle", camera="wide", pace="slow"),
            L(N, "你看向北边的隘口。那里冒起一股烟，不是做饭的烟，是出事了。"),
            L(WT, "又在看烟？你说过好几回，想出去闯，挣个自己的姓。我都记着。"),
            L(N, "你弟弟小粟今天赶着粮车往北走，要过隘口那条窄路。"),
            L(MOM, "北边有槐里家的骑兵守着，路是他们的，他们会管的。"),
            L(N, "到了傍晚，烟变成了两股。小粟还没回来。", pace="beat", tension=0.3),
            L(OS, "你是丰年的儿子吧？你爹当年给我们灰旗打过旗杆上的铁箍。", camera="close"),
            L(OS, "隘口被一伙强盗堵了，专收过路钱。灰旗本来负责护这条路，可已经散了二十年。"),
            L(OS, "只要今晚有人扛着这面旗把路打通，灰旗就能重新立起来。当然，也可能会死。"),
            L(MOM, "你爹年轻时也想出去闯。后来有了你，他就没走。", expr="sorrow"),
            L(MOM, "去吧。一定把小粟带回来。"),
            L(N, "你在旧旗上写下了自己的姓。字有点歪，但这是你的。", camera="banner", pace="slow"),
            L(OS, "好，旗上有了你的姓和颜色。从今晚起，你就是灰旗的团长。"),
            L(WT, "我跟你走，是因为信你这个人。别为了出名，把自己变成另一个人。"),
            L(N, "树后走出一个背弓的女人。她是清河来的护路人，常年在隘口带人过路。"),
            L(DY, DENGYING),
            L(OS, "一个为人，一个为路。都好，都欢迎。"),
        ],
        "actions": [
            A("enter_banner", "让这个颜色落进旗心", [goto()]),
            A("guides_brief", "（我玩过战棋：跳过教学，能直接结算的就直接结算）", [setf(BRIEF), goto()]),
        ],
        "next": "0.05",
    },
    {
        "id": "0.05", "title": "旗面初成",
        "lines": [
            L(N, "老旗手把你选的颜色涂在旗子中间。他的手有点抖。", camera="banner"),
            L(WT, "您手怎么抖了？"),
            L(OS, "太久没见过这面旗重新立起来了。"),
            L(OS, "灰底是灰烬邦的，大家都一样。中间这块颜色是你的，别人靠它认出你。"),
            L(OS, "以后立了功，可以往旗上加图案。记住：这面旗属于城堡，不属于哪个人。"),
            L(OS, "人会老，会结婚，会死。城堡还在，旗就一直挂着。", camera="wide"),
            L("斥候", "隘口点了烽火！七辆粮车被堵住了，城里的粮食撑不了几天。", tension=0.5),
            L(DY, "路很窄。你选好站的位置，我守旁边。别挤成一堆，容易被一起打。"),
            L(WT, "打赢这一仗，大家才会知道灰旗回来了。"),
        ],
        "actions": [A("to_pass", "走向已经亮起的烽", [goto()])],
        "next": "0.1",
    },
    {
        "id": "0.1", "title": "窄路",
        "lines": [
            L(N, "隘口很窄，强盗用粮袋堆了一道墙，躲在后面。", music="tension", tension=0.6),
            L(DY, "先挪到好位置再出手。打退他们就行，别追太远，追出去会吃亏。"),
            L(DY, "我上高处，先对付他们的弓手。你们往前推，推到第二辆车就停。"),
            L(WT, "小粟就在第二辆车后面。稳住，别慌。"),
            L(OS, "走吧。打赢这一仗，大家才记得住你的姓。"),
        ],
        "actions": [
            A("after_smoke", "听烟散之后", [goto()], F("battle_done")),
            A("start_battle", "走进隘口", [{"op": "battle", "map": "ch0_pass", "objective": "rout", "return": RET}], {"not_flag": "battle_done"}),
            A("skip_battle", "（教学从简）这一仗按胜记，直接听烟散", [{"op": "skip_battle"}, goto()], {"all": [F(BRIEF), {"not_flag": "battle_done"}]}),
            A("retry_note", "这一仗可以再打。旗还在。", [], {"not_flag": "battle_done"}, disabled=True),
        ],
        "next": "0.15",
    },
    {
        "id": "0.15", "title": "烟散之后",
        "lines": [
            L(N, "仗打完了。还有一个强盗想爬走，灯影一箭把他拦住了。", music="castle", tension=0.2, camera="close"),
            L(N, "小粟躲在车后，吓得发抖，但人没事。"),
            L(DY, "这人说，背后有人专门收这笔过路钱。是谁，他不肯说。"),
            L(WT, "你手在抖。没事，第一次都这样。我们赢了。"),
            L(DY, "这个俘虏怎么办？可以交给哨所，也可以带着他走。"),
            L(DY, "交出去，他多半活不长。带着他，就得多养一张嘴。"),
        ],
        "actions": [
            A("keep_survivor", "让他跟着粮车走。他见过收银的人，我没有", [setf("pro_survivor_kept"), goto()]),
            A("hand_survivor", "把他交给哨堡，按规矩办", [setf("pro_survivor_handed"), goto()]),
        ],
        "next": "0.17",
    },
    {
        "id": "0.17", "title": "功劳簿",
        "lines": [
            L(N, "第二天，槐里家的人坐着马车来了。", pace="beat"),
            L(HZ, "灰旗？我还以为早就没了。"),
            L(JB, "我认得这面旗，年轻时我也在它下面打过仗。你是丰年的儿子吧。"),
            L(JB, "我的功劳簿上写着：这一仗是我家骑兵队长衡舟打赢的。"),
            L(WT, "可你们的骑兵一整晚都没出来！", expr="anger"),
            L(JB, "我知道是你们打的。但这本簿子要交给议会。"),
            L(JB, "我孙女青禾有贵族血统，但得立过大功，议会才承认她。"),
            L(JB, "把这功劳让给她。我送你城堡，再给你一季的军饷。怎么样？"),
            L(QH, "爷爷，别人打的仗算在我头上，我不要。", camera="close"),
            L(JB, "傻孩子。没有功劳，议会连门都不让你进。"),
            L(DY, "我注意到，衡舟和那个俘虏对看了一眼。他们认识。", F("pro_survivor_kept")),
            L(DY, "俘虏被押走时一点都不挣扎。押他的人好像认识他。", F("pro_survivor_handed")),
        ],
        "actions": [
            A("merit_own", "不换。仗是灰旗打的，簿子上写什么我管不着", [
                setf("pro_merit_own"),
                {"op": "adjust", "reputation": {"ashland": 5}, "log": "隘口之功不让：陆桥商队开始传灰旗的名"},
                goto(),
            ]),
            A("merit_patron", "收下地契和饷银，让这一仗记在槐里家", [
                setf("pro_merit_patron"),
                {"op": "adjust", "silver": 80, "log": "槐里家送来地契与一季饷银（+80 银）"},
                goto(),
            ]),
        ],
        "next": "0.18",
    },
    {
        "id": "0.18", "title": "押契", "when": F("pro_merit_own"),
        "lines": [
            L(N, "没要槐里家的钱，你手头很紧。银子数了三遍，还是不够。"),
            L(WT, "我们才四个人，守不住城堡，也护不了路。得雇人。"),
            L(N, "傍晚，娘走了一整天路来找你，拿出一张纸。", pace="slow"),
            L(MOM, "这是家里那块地的租契。拿去押了，够发三个月军饷。"),
            L(MOM, "赎不回来也没关系。娘支持你。", expr="sorrow"),
        ],
        "actions": [
            A("pawn_lease", "收下租契，押给账房", [setf("pro_lease_pawned"), {"op": "adjust", "silver": 90, "log": "押出采石坡租契（+90 银）"}, goto()]),
            A("keep_lease", "把契还给娘。饷我去委托板上挣", [setf("pro_lease_kept"), goto()]),
        ],
        "next": "0.2",
    },
    {
        "id": "0.2", "title": "烽火酒馆",
        "lines": [
            L(N, "烽火酒馆里坐满了找活干的人。", music="hub"),
            L("掌柜", "听说隘口那仗是你们打的？谁打的我不管，我只管介绍人。"),
            L("掌柜", "雇人要先付钱，以后每个月还得发工资。挑个靠得住的。"),
            L("掌柜", "至少雇一个吧。记住，人越多，每月要发的工资越多。"),
            L(WT, "我是跟着你来的。这里的人不一样，他们是为了钱。"),
            L(DY, "你用的是槐里家给的钱。别忘了，那一仗算他们的了。", F("pro_merit_patron")),
            L(DY, "这是你娘押地换来的钱。别挑最贵的，挑靠得住的。", F("pro_lease_pawned")),
            L(DY, "钱只够雇一个人，好好挑。", F("pro_lease_kept")),
        ],
        "actions": [
            A("sheathe", "让陌生人站进队列", [goto()], F("recruited")),
            A("open_tavern", "进烽火酒馆，至少带一个人回来", [{"op": "scene", "path": "res://scenes/hub/tavern.tscn"}], {"not_flag": "recruited"}),
            A("auto_recruit", "（教学从简）按银挑一个，直接进列", [{"op": "auto_recruit"}, goto()], {"all": [F(BRIEF), {"not_flag": "recruited"}]}),
        ],
        "next": "0.25",
    },
    {
        "id": "0.25", "title": "陌生人进列",
        "lines": [
            L(N, "新来的人翻开一本旧账本给你看。"),
            L(N, "上一个老板欠了他三个月工资没发。"),
            L(DY, "为钱干活的人也很可靠。只要工资按时发，他们就不会走。"),
            L(WT, "有个落脚的地方了。可光有熟人还不够，得有更多人才像个家。"),
            L("管事", "城堡收拾好了。先来看看名册吧。"),
        ],
        "actions": [A("enter_keep", "入驻灰旗堡", [setf("hub_open"), goto()])],
        "next": "0.3",
    },
    {
        "id": "0.3", "title": "名册空席",
        "lines": [
            L(N, "你们住进了破旧的灰旗堡。柱子上还有以前打仗留下的刀痕。", music="castle", pace="slow"),
            L("管事", "这是城堡的名册，人很少，空位很多。"),
            L(WT, "这就是你的家，现在还全是空椅子。人得一个一个找。"),
            L(OS, "我想求你件事：名册第一行空着，留给以前战死的老兄弟。", expr="sorrow", camera="close"),
        ],
        "actions": [
            A("roster_wantan", "第一行写石垒·晚担。旧人写在封二，比第一行还前", [setf("pro_roster_wantan"), setf("hub_open"), goto()]),
            A("roster_blank", "第一行空着，留给灰旗旧人", [setf("pro_roster_blank"), setf("hub_open"), goto()]),
        ],
        "next": "0.32",
    },
    {
        "id": "0.32", "title": "门楼上的纸",
        "lines": [
            L(OS, "你说得对，名册是给活人用的。老兄弟写在封面后面，也挺好。", F("pro_roster_wantan")),
            L(N, "晚担看着名册上自己的名字，用力按了一下。", F("pro_roster_wantan")),
            L(OS, "谢谢你，就当他们都还在。", F("pro_roster_blank")),
            L(WT, "我写第二行也没关系。", F("pro_roster_blank")),
            L("管事", "门口这块是委托板。上面贴着各种活儿：护送、找人、打狼，都有报酬。"),
            L("管事", "接委托是城堡赚钱的主要办法，军饷有一半靠它。"),
            L("管事", "接委托不会让你出名，但能让大家吃饱饭。"),
            L(DY, "你没押你娘的地，那就得靠委托多挣钱了。", F("pro_lease_kept")),
        ],
        "actions": [
            A("open_quests", "去门楼看委托板", [{"op": "visit", "path": "res://scenes/hub/quests.tscn"}]),
            A("take_escort", "揭一张陆桥驿的护送，先看路", [goto()]),
            A("open_hub", "去看名册上的空席", [setf("hub_open"), {"op": "scene", "path": "res://scenes/hub/castle_hub.tscn"}]),
        ],
        "next": "0.33",
    },
    {
        "id": "0.33", "title": "舆图",
        "lines": [
            L(N, "晚上，老旗手摊开一张世界地图。", music="atlas", camera="wide"),
            L(OS, "我们在灰烬邦。中间是陆桥，桥两边一共有十个国家。"),
            L(OS, "每个国家规矩都不一样，以后你会和它们打交道。"),
            L(OS, "路是连着的。名气大了，会有更远的地方请你去。"),
            L(DY, "出门赶路要花时间，过关要交钱。别看地图上近，走起来远。"),
            L(WT, "出门记得多带粮，不然回来就得饿肚子。"),
        ],
        "actions": [
            A("open_atlas", "摊开舆图，走一趟陆桥驿", [{"op": "visit", "path": "res://scenes/hub/atlas_view.tscn"}]),
            A("hear_bridge", "先听陆桥耳语", [goto()]),
        ],
        "next": "0.35",
    },
    {
        "id": "0.35", "title": "陆桥耳语",
        "lines": [
            L(N, "过关时，税吏在收据上写下了「{surname}」，这是别人第一次写你的姓。", pace="beat"),
            L(N, "路上的商队都在聊：灰旗打赢了隘口，团长还没成亲。"),
            L("春令使者", "春天要到了。想被贵族认可，光有旗不够，还得成家。"),
            L(HZ, "我也收到了春天的请帖。我给槐里家干了十年，才换来一个姓。", camera="close"),
            L(HZ, "你倒好，一晚上就有了。"),
            L(HZ, "春天那天，你有证据就拿出来。不然倒霉的就是你。"),
            L(HZ, "我们俩只能留一个。", tension=0.4),
            L(QH, "爷爷想让我嫁给衡舟，这样那一仗就彻底算我家的了。"),
            L(QH, "我不想靠别人的功劳。不然我的孩子以后也只能这样。"),
            L(WT, "他说错了。你会想明白的。"),
        ],
        "actions": [
            A("to_spring", "去春令那张桌子", [goto()]),
            A("back_hub", "先回灰旗堡", [{"op": "scene", "path": "res://scenes/hub/castle_hub.tscn"}]),
        ],
        "next": "0.38",
    },
    {
        "id": "0.38", "title": "香盏",
        "lines": [
            L(N, "春天到了。大厅里，三方人围着一张长桌坐下。", music="tension", tension=0.7, pace="slow"),
            L(HZ, "我反对！隘口是我们骑兵打的，灰旗只是碰巧在场。"),
            L(SV, "我说实话。过路钱交给哨所后面的人，那人骑一匹灰马。", F("pro_survivor_kept")),
            L(SV, "钱最后送去东边。那匹灰马是他的。", F("pro_survivor_kept")),
            L(DY, "那个俘虏押进哨所第三天就死了。我只拿到他身上这根签子。", F("pro_survivor_handed")),
            L(DY, "签子是从哨所马棚来的。那里只有衡舟的灰马。", F("pro_survivor_handed")),
            L(N, "衡舟的手按上了刀。景伯一句话也没说。", camera="shake"),
            L(WT, "想想清楚怎么处理他。"),
        ],
        "actions": [
            A("expose_rival", "当众请使者带走衡舟，让陆桥都听见", [
                setf("pro_rival_exposed"),
                {"op": "adjust", "reputation": {"ashland": 10}, "log": "春令席上揭出过路银：灰旗之名传遍陆桥"},
                goto(),
            ]),
            A("spare_rival", "过路银写进护路呈报。桌上只说灰旗的事，给衡舟留一行", [
                setf("pro_rival_spared"),
                {"op": "adjust", "morale": 5, "log": "春令席上留了余地：名册末行空着一席"},
                goto(),
            ]),
        ],
        "next": "0.39",
    },
    {
        "id": "0.39", "title": "身后站着谁",
        "lines": [
            L(N, "衡舟被带走了。", F("pro_rival_exposed")),
            L(QH, "爷爷什么都没说。明天大家都会知道你的名字，也会知道我家的丑事。", F("pro_rival_exposed")),
            L(N, "你对衡舟说：哪天想改过，灰旗还有空位。他没回头，走了。", F("pro_rival_spared")),
            L(QH, "你本来可以更出风头的。爷爷会记得你给他留了面子。", F("pro_rival_spared")),
            L(N, "你站起来，把手放在桌上的玻璃盏上，准备立誓。", music="dynasty:inheritance", camera="close", pace="slow"),
            L(OS, "说吧，告诉大家谁和你站在一起。"),
            L(N, "你的同伴们都在。城堡是租的，钱也不多，但人心齐。", {"not_flag": "pro_merit_patron"}),
            L(N, "你的同伴们都在。城堡是槐里家给的，功劳算在别人头上，但人心齐。", F("pro_merit_patron")),
            L(N, "你终于明白：姓可以被人划掉，但跟着你的这些人，谁也抢不走。"),
            L("春令使者", "好，议会承认灰旗。你可以去求亲了。"),
        ],
        "actions": [A("to_seat", "入席", [goto()])],
        "next": "0.4",
    },
    {
        "id": "0.4", "title": "春令试婚",
        "prepare": [{"op": "ensure_reputation", "when": {"not_flag": "married"}, "realm": "ashland", "below": 30, "set": 35, "also_if_tier": "none", "log": "春令使者代请：灰烬邦声望升至友善"}],
        "lines": [
            L("春令使者", "议会收了槐里家的报告，上面没有你的名字。", F("pro_merit_patron")),
            L("春令使者", "隘口这一仗，议会收到两份报告，还没决定算谁的。", F("pro_merit_own")),
            L("春令使者", "我替你打过招呼了。这门亲事主要看两家合不合适，感情以后再说。"),
            L("春令使者", "选人之前，先看清楚将来孩子可能是什么样。想好了再答应。"),
            L(QH, "选谁由你决定。我只希望你别靠别人的功劳。"),
            L(DY, "别想太远，先把今年过好。结婚是为了让大家认可你，感情慢慢来。"),
        ],
        "actions": [
            A("to_feast", "赴双姓共席", [goto()], F("married")),
            A("open_marriage", "前往联姻廷", [{"op": "scene", "path": "res://scenes/hub/marriage.tscn"}], {"not_flag": "married"}),
            A("auto_marry", "（教学从简）请使者择一席，直接入席", [{"op": "auto_marry"}, goto("0.4")], {"all": [F(BRIEF), {"not_flag": "married"}]}),
        ],
        "next": "0.45",
    },
    {
        "id": "0.45", "title": "双姓共席",
        "lines": [
            L(N, "婚礼很简单，但大家都很认真。老旗手把旗举得高高的。", music="dynasty:marriage"),
            L("盟友亲属", "我们把孩子交给你们了。请让以后的孩子为这面旗骄傲。"),
            L(WT, "你没说什么甜言蜜语。这样挺好，实在。"),
            L(DY, "要是我结婚，一定要保留我自己的姓。我的姓被人抹掉过一次。"),
            L(DY, "家成了，接下来就等孩子出生了。这急不来。"),
        ],
        "actions": [A("wait_birth", "等待初啼", [goto()])],
        "next": "0.5",
    },
    {
        "id": "0.5", "title": "月份",
        "lines": [
            L(N, "婚后日子照常过。接委托，护商路，按月发工资。", music="castle"),
            L("管事", "等孩子出生要好几个月。每过一个月，都要发工资、吃粮食。"),
            L(WT, "小粟来看过你两次，送了粮食和娘做的鞋。他长高了。"),
        ],
        "actions": [
            A("advance_birth", "让月份走到孩子落地", [{"op": "advance", "until_flag": "child_born", "max": 14}], {"not_flag": "child_born"}),
            A("open_page", "去听那一声哭", [goto()], F("child_born")),
        ],
        "next": "0.55",
    },
    {
        "id": "0.55", "title": "初啼",
        "lines": [
            L("稳婆", "生了！孩子哭得很响，身体很好。", music="dynasty:birth", pace="slow"),
            L(N, "稳婆喊你「{surname}团长」。这是第一次有人用姓来叫你。"),
            L(WT, "你的家，从这个孩子开始，真正有了下一代。"),
            L("稳婆", "去族谱上把孩子的名字写上吧。以后别人就靠这一页认他。"),
            L("管事", "族谱上多了一行新名字。"),
            L(OS, "等孩子长大了，有一天会接过这面旗。不过那是很久以后的事。"),
        ],
        "actions": [
            A("see_lineage", "去看族谱上那一页", [{"op": "scene", "path": "res://scenes/hub/lineage_view.tscn"}]),
            A("to_harvest", "去把粮饷结清", [goto()]),
        ],
        "next": "0.6",
    },
    {
        "id": "0.6", "title": "结清与上路",
        "lines": [
            L("管事", "秋收到了，要结算这一年的工资、粮食和士气。孩子也要吃饭。"),
            L(DY, "账本可不管你高不高兴，账就是账。"),
            L(N, "家里那块地已经归槐里家了，赎不回来了。", F("pro_lease_pawned")),
            L(N, "娘的地还在。这一年的工资，全靠接委托一张一张挣来的。", F("pro_lease_kept")),
            L(N, "槐里家给的钱花完了。功劳是别人的，城堡是你的。", F("pro_merit_patron")),
            L(N, "小粟带来一双小鞋，上面绣着你的姓。娘不识字，照着旗绣了三天。", pace="slow"),
            L(WT, "把账算清楚吧。你还是当初那个你，挺好。"),
            L("管事", "算完账，写下这一年的记录，就可以出发去更远的地方了。"),
        ],
        "actions": [
            A("write_journal", "写下这一年", [{"op": "journal"}], {"any_flag": ["harvest_done", "chapter0_done"]}),
            A("free_play", "先回堡里", [setf("chapter0_done"), {"op": "scene", "path": "res://scenes/hub/castle_hub.tscn"}], {"any_flag": ["harvest_done", "chapter0_done"]}),
            A("old_volume", "踏上第一章·陆桥烽火", [setf("chapter0_done"), {"op": "set_beat", "chapter": 1, "beat": "1.0"}, {"op": "archive_notice"}], {"any_flag": ["harvest_done", "chapter0_done"]}),
            A("fast_harvest", "把月份推到丰收，结清这一笔", [{"op": "fast_harvest"}], {"not_any_flag": ["harvest_done", "chapter0_done"]}),
            A("open_hourglass", "去看月份怎么往前走", [{"op": "visit", "path": "res://scenes/hub/hourglass.tscn"}], {"not_any_flag": ["harvest_done", "chapter0_done"]}),
        ],
        "next": None,
    },
]


def build():
    beats = []
    for b in BEATS:
        out = {"id": b["id"], "title": b["title"]}
        if "when" in b:
            out["when"] = b["when"]
        if "prepare" in b:
            out["prepare"] = b["prepare"]
        lines = []
        for i, row in enumerate(b["lines"]):
            lid = "ch0_%s_l%d" % (b["id"].replace(".", "_"), i)
            lines.append({"id": lid, **row})
        out["lines"] = lines
        out["actions"] = b["actions"]
        out["next"] = b["next"]
        beats.append(out)
    doc = {
        "id": "ch0",
        "title": "第零章·那个字",
        "legacy_index": 0,
        "return_scene": RET,
        "source": "docs/story/prologue-novella.md",
        "beats": beats,
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return doc


if __name__ == "__main__":
    d = build()
    import re
    worst = max(len(re.findall(r"[\u4e00-\u9fff]", l["text"])) for b in d["beats"] for l in b["lines"])
    print("beats", len(d["beats"]), "lines", sum(len(b["lines"]) for b in d["beats"]), "max hanzi", worst)
