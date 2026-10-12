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
            L(N, "石垒坡的麦要到月底才黄。你把石担卸在田埂上，麻绳在肩上勒出两道暗红的沟。", music="castle", camera="wide", pace="slow"),
            L(N, "东边是朔澜陆桥。北隘那个缺口上立着一根烟，细，直，风吹不弯。"),
            L(WT, "又在看烟。去年你说要挣一个称呼，说了三遍。第三遍你没看我，看的是桥。"),
            L(N, "坡下，弟弟小粟赶着驴车往北走。车上是交给槐里家的粮，要过隘口那条窄路。"),
            L(MOM, "北边有槐里家的骑哨。是他们的路，他们会管。"),
            L(N, "傍晚，烟变成了两根。小粟没有回来。", pace="beat", tension=0.3),
            L(OS, "我找丰年的儿子。二十年前他给灰旗打过一个铁箍。杆断了，箍还在。", camera="close"),
            L(OS, "窄路上有人卡着收过路银。灰旗名下有一张北隘护路契，二十年没人认。"),
            L(OS, "今夜有人把这块布扛进隘口，契就活了。打输了，布就盖在扛布的人身上。"),
            L(MOM, "你要的那个字，你爹也想要过。他想要的时候已经有了你，他没去。", expr="sorrow"),
            L(MOM, "你去吧。把小粟带回来。"),
            L(N, "坡顶的老槐树下，你在灰布上写下那个字。起笔太重，收笔有点歪。", camera="banner", pace="slow"),
            L(OS, "姓和颜色，你已经写下了。布认字。今夜之后，石垒坡出来的人要被叫做团长。"),
            L(WT, "我跟的是你。旗若散了，我还认得田埂上那个人。别为了姓把那个人弄丢。"),
            L(N, "槐树另一侧有人笑了一声。河卫打扮，背一张长弓，下巴上有护颈的晒痕。"),
            L(DY, DENGYING),
            L(OS, "一个跟的是人，一个跟的是路。布都收下。"),
        ],
        "actions": [
            A("enter_banner", "让这个颜色落进旗心", [goto()]),
            A("guides_brief", "（我玩过战棋：教学从简，可直接结算）", [setf(BRIEF), goto()]),
        ],
        "next": "0.05",
    },
    {
        "id": "0.05", "title": "旗面初成",
        "lines": [
            L(N, "老旗手把颜色抹进旗心，用手掌压平。他的手在抖。", camera="banner"),
            L(WT, "你手抖什么？"),
            L(OS, "太久了。太久没见过一整块还肯认人的布。"),
            L(OS, "底是灰，是邦给的，谁都一样。旗心这一块是你。陆桥上的人先认这块颜色。"),
            L(OS, "中间那道叫带，堡里有了功往上加。边上一圈叫缘，是堡的墙。这布跟堡走，不跟人走。"),
            L(OS, "人会老，会嫁娶，会死。堡还在，布就还挂着，一年比一年重。", camera="wide"),
            L("斥候", "北隘起了烽。不是炊烟。七辆车卡在窄路上，堡里的粮撑不了几顿。", tension=0.5),
            L(DY, "窄路只够你选一个落点。我守侧翼。人挤成一堆，火会把名字烧成同一块。"),
            L(WT, "烽火要的是一个名字。打赢了，陆桥才肯停下来问你姓什么。"),
        ],
        "actions": [A("to_pass", "走向已经亮起的烽", [goto()])],
        "next": "0.1",
    },
    {
        "id": "0.1", "title": "窄路",
        "lines": [
            L(N, "窄路两边是湿石壁，只容两辆车。卡路的人把粮袋垒成墙，在墙后生火。", music="tension", tension=0.6),
            L(DY, "先选落点。选了就站住，别追。追出第二辆车，就是他们的地形了。"),
            L(DY, "上面那块岩台归我。有弓，我先压弓。你们往前推，推到第二辆车就停。"),
            L(WT, "小粟在第二辆车后面。别急。你急了，他也跟着急。"),
            L(OS, "烽已经亮了。这一仗打完，姓才算被人听见。"),
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
            L(N, "烟散了。有人还在往前爬。灯影的箭钉在他面前三寸的石头上，箭尾还在颤。", music="castle", tension=0.2, camera="close"),
            L(N, "第二辆车后面，小粟抱着驴的脖子。驴在抖，他也在抖。"),
            L(DY, "活口说，背后有人收过路银。不是普通抢粮。名字他不肯吐。"),
            L(WT, "你的手在抖。抖完，姓还在。石垒坡只会听说隘口。抖留在你掌心里。"),
            L(DY, "你可以把他交给哨堡，也可以让他跟着粮车走。"),
            L(DY, "交给哨堡，他大概活不过这个月。留着他，他就吃我们的粮。"),
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
            L(N, "第二天中午，哨堡的人来了。马车窗上嵌着磨砂玻璃，玻璃后挂着一盏霜灯。", pace="beat"),
            L(HZ, "灰旗？我以为这东西早烂了。"),
            L(JB, "我认得这块布。我年轻的时候，它还是一整面。你是丰年的儿子。"),
            L(JB, "北隘烽起，槐里家骑哨统领衡舟率众击退流匪，救回粮车七辆。簿子上这么写。"),
            L(WT, "骑哨在哨堡里，一夜没出来。", expr="anger"),
            L(JB, "我知道是谁打的。这本簿子不是写给我看的，是写给白垣议会看的。"),
            L(JB, "我孙女青禾脖子上有河图，不亮。立一场当众的功，议会唱了票，才算点亮。"),
            L(JB, "这一仗记在她名下。灰旗堡的地契送你，这一季的饷我出。你要的不就是这些？"),
            L(QH, "记在我名下，脖子上还是一样，只是簿子上多一行。我不要一盏借来的灯。", camera="close"),
            L(JB, "青禾。借来的灯也是灯。没有灯的人，在白垣连门都进不去。"),
            L(DY, "衡舟经过空车时看了活口一眼。活口也看着他。他们认识。", F("pro_survivor_kept")),
            L(DY, "活口被骑哨押走时没挣。押他的人，像是早就认得他。", F("pro_survivor_handed")),
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
            L(N, "不收地契，就没有饷银。你在陆桥驿外的石阶上数碎银，数了三遍。"),
            L(WT, "人不够。四个人守不了一个堡，也护不了一条路。"),
            L(N, "傍晚，娘从石垒坡走来，鞋底磨薄了。她从布包最里层拿出一张折了四折的纸。", pace="slow"),
            L(MOM, "采石坡那块的租契。你爹拿命换的，换来一行小字。押出去，能换三个月的饷。"),
            L(MOM, "赎不回来就不赎。我老了，不想再看那行小字。", expr="sorrow"),
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
            L(N, "烽火酒馆的门轴一响，响的是想把自己这个月卖出去的嘴。", music="hub"),
            L("掌柜", "隘口那一仗，有人说是槐里家打的，有人说是一面破旗打的。我不管是谁打的。"),
            L("掌柜", "这里不赊命，只赊月饷。看脸，看这个人肯不肯在空席上坐到发饷那天。"),
            L("掌柜", "至少带走一个。看走眼，月饷会回来找你。每到发饷那天，堡里的银就少一截。"),
            L(WT, "我已经在队里。柜上这个是陌生人。陌生人跟的是银，不是田埂上的你。"),
            L(DY, "槐里家的银在你袋里。花的时候记着，那一仗也在他们簿子上。", F("pro_merit_patron")),
            L(DY, "你娘的契换的银。挑人别挑贵的，挑坐得住的。", F("pro_lease_pawned")),
            L(DY, "银只够一个人。挑一个肯早点告诉你走不走的人。", F("pro_lease_kept")),
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
            L(N, "有人进门先看旗，有人先看账。先看账的那个，翻开一页给你看。"),
            L(N, "那一页记着上一个雇主的饷。最后三个月，发饷的日子画着空圈。"),
            L(DY, "跟银的人不坏。月饷按日子给，他们比谁都坐得住。晚一天，就当你是上一个。"),
            L(WT, "空房间比露宿强。可名册若只有认得的名字，这就还是一伙人，不是一个家。"),
            L("管事", "灯可以亮了。先去看那本名册。"),
        ],
        "actions": [A("enter_keep", "入驻灰旗堡", [setf("hub_open"), goto()])],
        "next": "0.3",
    },
    {
        "id": "0.3", "title": "名册空席",
        "lines": [
            L(N, "破堡亮起第一盏灯。光很小，柱上的旧刀痕却很清楚。前人在这里守过，也败过。", music="castle", pace="slow"),
            L("管事", "花名册翻开了。写上的人很少，空席很多。空席是还没人肯把命放进来。"),
            L(WT, "你要的家，现在就是这些空椅子。椅子不会因为你想立家，就自己坐上人。"),
            L(OS, "第一行，我求你一件事。空着，留给灰旗以前的人。北隘那夜的人，我记不全。", expr="sorrow", camera="close"),
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
            L(OS, "册子是活人用的。你说得对。旧人在最前面，我看得见。", F("pro_roster_wantan")),
            L(N, "晚担走过来，伸出那只虎口裂开的手，在自己的名字上按了一下。", F("pro_roster_wantan")),
            L(OS, "空着一行，就当他们都在。", F("pro_roster_blank")),
            L(WT, "第二行也行。我跟的是人，不是行数。", F("pro_roster_blank")),
            L("管事", "门楼木板墙上钉着委托。找羊，找人，护货，清狼窝，修路。每张下面写着酬金。"),
            L("管事", "灰旗在的时候，这块板子比堡门还重要。堡里的饷，一半是从这上面揭下来的。"),
            L("管事", "这块板子不会让你出名。它让你活到出名那一天。"),
            L(DY, "你没押你娘的契。那这块板子，就是你娘的契。", F("pro_lease_kept")),
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
            L(N, "那晚老旗手在大厅里铺开一张旧舆图，边缘已经脆了，四角压着镇纸。", music="atlas", camera="wide"),
            L(OS, "这是灰烬，这是陆桥。桥东是灯市、霜冕、星津，桥西是朔影、清河。"),
            L(OS, "十个国，十种认人的办法。每一种都觉得自己对，都在等一面旗过去替它说话。"),
            L(OS, "路是连着的。你护住一段，就有人请你护下一段。那个字会走得比你远。"),
            L(DY, "桥上的路看着近，每一段都要交钱、都要等。日子按驿站算，不按眼睛算。"),
            L(WT, "粮带少了，回程就饿着走。我小时候以为石垒坡就是全天下。"),
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
            L(N, "西桥头堡的税吏在收据抬头写下「{surname}」。写对了。你把收据折好，贴身放着。", pace="beat"),
            L(N, "夜里商队在远处敲锣。锣声里夹着闲话：隘口打赢了，旗是新的，团长还没成亲。"),
            L("春令使者", "春令将近。诸邦看旗，也看家。无家之旗，高门不收帖。"),
            L(HZ, "春令的帖，我也有一张。我在槐里家马棚睡了三年，换一个村名錾在铜牌上。", camera="close"),
            L(HZ, "你一夜就有了。一块破布，一截断杆，一个老头子。"),
            L(HZ, "春令那天，你有证据就拿出来。拿出来我就完了，不拿你就完了。"),
            L(HZ, "我们两个没有姓的人，只能活一个。桥上只记得一个。", tension=0.4),
            L(QH, "祖父想让我嫁他。功是衡舟的，衡舟是槐里家的，那一仗就名正言顺了。"),
            L(QH, "我想让河图自己亮，或者不亮。借来的灯，我的孩子也得接着借。"),
            L(WT, "他说错了一件事。哪一件，得你自己去找。"),
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
            L(N, "春令那天，大厅长桌两边坐了三家。桌中间放着一只空的玻璃香盏。", music="tension", tension=0.7, pace="slow"),
            L(HZ, "灰旗的帖我有异议。隘口是槐里骑哨打的。灰旗不过是碰巧在那里的流民。"),
            L(SV, "过路银交到哨堡后面的马棚。收银的人骑灰马，三成留哨堡，剩下的往东送。", F("pro_survivor_kept")),
            L(SV, "东边的人我没见过，只见过他们的签，签上有半个环。灰马是他的。", F("pro_survivor_kept")),
            L(DY, "活口押进哨堡第三天就死了。我只留下他靴筒里这支签，签上有半个环。", F("pro_survivor_handed")),
            L(DY, "签是从哨堡后面的马棚流出来的。那里只拴着一匹灰马。", F("pro_survivor_handed")),
            L(N, "衡舟的手按在了刀上。没有人动。景伯慢慢把手从玻璃帖上拿开了。", camera="shake"),
            L(WT, "别为了姓把那个人弄丢。我说的不只是你。"),
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
            L(N, "使者的人带走了衡舟。门口，老旗手没有让路，断杆的影子落在他背上。", F("pro_rival_exposed")),
            L(QH, "祖父一句话没说。陆桥明天会念你的姓，念得很响。也会念槐里家。", F("pro_rival_exposed")),
            L(N, "你叫住要走的衡舟：名册还有空席，从最后一行写起。他没有回头。", F("pro_rival_spared")),
            L(QH, "你本可以让陆桥念得更响。祖父看见了。他会记得这一桌是谁留了余地。", F("pro_rival_spared")),
            L(N, "你把手按在香盏的玻璃上。玻璃是凉的。旗誓是站着说的。", music="dynasty:inheritance", camera="close", pace="slow"),
            L(OS, "说吧。说你身后站着谁。"),
            L(N, "名册第一行，跟银的人，为路留下的人，扛杆的人。堡是租的，饷撑不了几个月。", {"not_flag": "pro_merit_patron"}),
            L(N, "名册第一行，跟银的人，为路留下的人，扛杆的人。地契是槐里家给的，那一仗在别人簿子上。", F("pro_merit_patron")),
            L(N, "你要一个划不掉的字。今天你知道了：字划得掉。划不掉的，是写字时身后站着谁。"),
            L("春令使者", "春令认了。灰烬这边的门，开到能递帖。"),
        ],
        "actions": [A("to_seat", "入席", [goto()])],
        "next": "0.4",
    },
    {
        "id": "0.4", "title": "春令试婚",
        "prepare": [{"op": "ensure_reputation", "when": {"not_flag": "married"}, "realm": "ashland", "below": 30, "set": 35, "also_if_tier": "none", "log": "春令使者代请：灰烬邦声望升至友善"}],
        "lines": [
            L("春令使者", "隘口一仗，槐里家的呈报议会收了。旗帅的名字不在上面。", F("pro_merit_patron")),
            L("春令使者", "隘口一仗，议会收到两份呈报：槐里家一份，商队联名一份。还没唱票。", F("pro_merit_own")),
            L("春令使者", "灰烬这边的门，我代你问过了。进门是试婚。人先入席，情爱不在这一季结算。"),
            L("春令使者", "入席之前，把期望那一行自己念完。念不下去，就不要点头。孩子不来今夜。"),
            L(QH, "入谁的席，是你在联姻廷里定。我只求一件事：别把谁的河图写成借来的。"),
            L(DY, "别被百年吓住。先过完这一年。联姻是城门认不认这个姓，心可以以后再谈。"),
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
            L(N, "酒是薄的，誓是重的。老旗手把旗又升高一寸，像是怕风看不见。", music="dynasty:marriage"),
            L("盟友亲属", "我们把人托付给这面旗，不是托付给一夜的喜欢。请让孩子将来敢承认它。"),
            L(WT, "你没有把喜欢说出口。这样也好。喜欢若拿来当今晚的借口，这席就是空的。"),
            L(DY, "我只会在一种条件下成婚：对方在名册上留着我的姓。我的姓被涂过一次。"),
            L(DY, "家有了。初啼还没到。族谱那一页还空着。孩子不按你的日子来。"),
        ],
        "actions": [A("wait_birth", "等待初啼", [goto()])],
        "next": "0.5",
    },
    {
        "id": "0.5", "title": "月份",
        "lines": [
            L(N, "席散以后，日子照常走。灰旗揭委托板上的纸，护陆桥驿的路，发饷。", music="castle"),
            L("管事", "孩子要等的月份，一个都省不了。每过一个月，饷照发，粮照吃。"),
            L(WT, "小粟来过两回，送粮，送你娘做的鞋。他长高了，不用再抱驴脖子。"),
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
            L("稳婆", "旗下有了哭声。不好听。肺是孩子自己的，命也是。旗排在这声哭的后面。", music="dynasty:birth", pace="slow"),
            L(N, "稳婆在门里叫了你一声。叫的是「{surname}」。这是第一次有人这样叫你。"),
            L(WT, "石垒坡没有给这种哭声留座位。你要的家，从这一声开始算人数。"),
            L("稳婆", "去看那一页。以后的城门认这个孩子，认的是这一页，不是你的野心。"),
            L("管事", "族谱上新写了一行。墨干得很快。边境的风一向不客气。"),
            L(OS, "孩子还上不了阵。有一天授旗会比任何胜仗都沉。今天还不是那天。"),
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
            L("管事", "丰收月到了。工资、口粮、士气要结清。孩子也跟着吃。"),
            L(DY, "粮饷簿不认眼泪，也不认初啼。"),
            L(N, "采石坡那块插上了槐里家的界桩，白生生的。娘的契赎不回来了。", F("pro_lease_pawned")),
            L(N, "娘的契还在石垒坡的柜子里。这一年的饷，是从门楼上一张一张揭下来的。", F("pro_lease_kept")),
            L(N, "槐里家的饷花完了。簿子上那一仗还在别人名下，堡的地契在你手里。", F("pro_merit_patron")),
            L(N, "小粟捎来一双小鞋，鞋面绣着那个字，比你写的还歪。娘照着旗描了三天。", pace="slow"),
            L(WT, "把账结清。结清了，我跟的那个人还在。"),
            L("管事", "手记等账清了再写。写完，才算上路。陆桥会重复这个姓，你得在场。"),
        ],
        "actions": [
            A("write_journal", "写下这一年", [{"op": "journal"}], {"any_flag": ["harvest_done", "chapter0_done"]}),
            A("free_play", "先回堡里", [setf("chapter0_done"), {"op": "scene", "path": "res://scenes/hub/castle_hub.tscn"}], {"any_flag": ["harvest_done", "chapter0_done"]}),
            A("old_volume", "踏上第一卷·过路银的收据", [setf("chapter0_done"), {"op": "open_chapter", "id": "e1_01"}], {"any_flag": ["harvest_done", "chapter0_done"]}),
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
