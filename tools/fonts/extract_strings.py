#!/usr/bin/env python3
"""Scan CJK string literals and mint locale keys.

Default: print candidate keys for the UI shell (does not edit files).
--apply rewrites those literals to Locale.t("key") and writes
project/data/locale/strings.csv. Literals already inside Locale.t(...) or
tr(...) are left alone. A missing English cell falls back to zh_CN at runtime.
"""
from __future__ import annotations

import csv
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import i18n_ratchet as ratchet  # noqa: E402

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
NUM = r"[0-9]+|[一二三四五六七八九十百千零〇两]+"
PUNCT = {
    "。": ". ",
    "，": ", ",
    "、": ", ",
    "：": ": ",
    "；": "; ",
    "「": '"',
    "」": '"',
    "『": '"',
    "』": '"',
    "（": " (",
    "）": ") ",
    "——": " — ",
    "—": " — ",
    "·": " · ",
    "　": " ",
    "！": "! ",
    "？": "? ",
    "％": "%",
}
# Display names for chapter epithets and leftover shell words.
GLOSS = {
    "一": "one", "七": "seven", "三": "three", "下": "lower", "不": "not", "与": "and",
    "业": "craft", "丝": "silk", "两": "two", "中": "mid", "丰": "harvest", "主": "main",
    "义": "oath", "之": "of", "九": "nine", "习": "drill", "事": "affair", "二": "two",
    "五": "five", "井": "well", "交": "cross", "亦": "also", "人": "people", "仓": "granary",
    "代": "era", "令": "order", "任": "duty", "休": "rest", "会": "meet", "伞": "umbrella",
    "传": "pass", "佃": "tenant", "位": "seat", "余": "after", "佣": "hire", "候": "watch",
    "先": "first", "入": "enter", "八": "eight", "六": "six", "共": "joint", "关": "pass",
    "册": "register", "写": "write", "冠": "crown", "冢": "mound", "冰": "ice", "决": "decide",
    "冷": "cold", "出": "out", "击": "strike", "刃": "blade", "分": "part", "切": "cut",
    "则": "rule", "前": "front", "剧": "play", "务": "duty", "动": "move", "募": "recruit",
    "北": "north", "区": "ward", "医": "heal", "十": "ten", "升": "rise", "半": "half",
    "单": "single", "南": "south", "印": "seal", "却": "retreat", "卷": "volume", "厅": "hall",
    "压": "press", "原": "plain", "厩": "stable", "口": "mouth", "可": "can", "台": "stage",
    "各": "each", "同": "same", "名": "name", "后": "after", "启": "open", "告": "notice",
    "命": "order", "响": "echo", "商": "trade", "嗣": "heir", "四": "four", "回": "return",
    "囤": "hoard", "园": "garden", "囱": "chimney", "图": "chart", "圃": "plot", "地": "field",
    "场": "yard", "坊": "workshop", "坑": "pit", "城": "city", "堂": "hall", "堆": "stack",
    "堡": "keep", "塔": "tower", "塘": "pond", "墙": "wall", "士": "knight", "多": "many",
    "夜": "night", "大": "great", "头": "head", "夺": "seize", "奏": "play", "姓": "surname",
    "委": "entrust", "姻": "marriage", "子": "child", "孔": "aperture", "字": "glyph",
    "存": "keep", "季": "season", "孤": "orphan", "学": "study", "宅": "house", "守": "guard",
    "完": "done", "定": "set", "宴": "feast", "家": "house", "容": "looks", "对": "pair",
    "局": "board", "属": "estate", "岁": "year", "岭": "ridge", "岸": "shore", "峡": "gorge",
    "川": "river", "巢": "nest", "工": "work", "已": "already", "巷": "lane", "币": "coin",
    "市": "market", "帘": "curtain", "席": "seat", "幕": "curtain", "年": "year", "并": "join",
    "庄": "manor", "库": "store", "应": "answer", "度": "measure", "座": "seat", "廷": "court",
    "开": "open", "引": "guide", "当": "current", "影": "shadow", "役": "service", "往": "go",
    "征": "campaign", "径": "path", "御": "drive", "快": "swift", "急": "urgent", "总": "whole",
    "情": "feeling", "愈": "heal", "戏": "play", "成": "complete", "或": "or", "战": "battle",
    "房": "room", "打": "strike", "托": "entrust", "执": "hold", "承": "inherit", "技": "skill",
    "抄": "copy", "把": "grip", "拉": "pull", "拍": "clap", "招": "call", "持": "hold",
    "挑": "raise", "换": "swap", "捺": "press", "授": "grant", "排": "rank", "接": "receive",
    "推": "push", "摊": "stall", "撞": "strike", "擂": "beat", "支": "branch", "收": "gather",
    "攻": "attack", "敌": "foe", "散": "scatter", "整": "order", "断": "break", "新": "new",
    "方": "side", "旁": "side", "族": "clan", "旗": "banner", "旬": "tenday", "星": "star",
    "春": "spring", "晒": "sun", "晓": "dawn", "晚": "late", "晾": "air", "暂": "pause",
    "暖": "warm", "曜": "light", "曲": "bend", "最": "most", "有": "have", "朔": "new-moon",
    "望": "full-moon", "朝": "court", "期": "term", "本": "root", "材": "timber", "枢": "pivot",
    "架": "frame", "染": "dye", "栈": "trestle", "树": "tree", "校": "drill", "案": "desk",
    "桑": "mulberry", "档": "file", "桥": "bridge", "梨": "pear", "梯": "ladder", "检": "inspect",
    "棚": "shed", "楼": "tower", "榨": "press", "正": "straight", "步": "step", "段": "span",
    "每": "each", "氏": "clan", "气": "breath", "汇": "confluence", "汐": "tide", "池": "pool",
    "河": "river", "波": "wave", "注": "pour", "泽": "marsh", "津": "ford", "洽": "accord",
    "海": "sea", "涉": "ford", "深": "deep", "渔": "fish", "港": "port", "湖": "lake",
    "滩": "beach", "潮": "tide", "火": "fire", "灯": "lamp", "灰": "ash", "炉": "forge",
    "点": "point", "烘": "bake", "烟": "smoke", "烬": "ember", "烽": "beacon", "煎": "pan",
    "熏": "smoke", "爵": "rank", "特": "mark", "独": "lone", "率": "lead", "王": "king",
    "瓷": "porcelain", "生": "life", "由": "from", "甲": "first", "百": "hundred", "的": "of",
    "皆": "all", "盐": "salt", "盟": "oath", "直": "straight", "相": "mutual", "着": "on",
    "石": "stone", "码": "yard", "砚": "inkstone", "砧": "anvil", "破": "break", "确": "sure",
    "礁": "reef", "礼": "rite", "祈": "pray", "祠": "shrine", "祷": "prayer", "租": "rent",
    "移": "shift", "窑": "kiln", "窖": "cellar", "立": "stand", "站": "station", "章": "chapter",
    "竹": "bamboo", "竿": "pole", "笋": "shoot", "笛": "flute", "第": "number", "签": "tally",
    "篁": "bamboo", "籍": "register", "粮": "grain", "糟": "lees", "约": "pact", "级": "grade",
    "纸": "paper", "线": "line", "终": "end", "经": "pass", "绘": "paint", "继": "continue",
    "续": "continue", "维": "cord", "缓": "slow", "缔": "bind", "编": "weave", "缫": "reel",
    "置": "place", "署": "office", "职": "post", "联": "alliance", "胤": "heir", "脉": "vein",
    "自": "self", "舆": "atlas", "船": "boat", "色": "color", "节": "festival", "茧": "cocoon",
    "茶": "tea", "草": "grass", "药": "herb", "菜": "greens", "营": "camp", "落": "fall",
    "蒸": "steam", "蚕": "silkworm", "蜂": "bee", "蜜": "honey", "血": "blood", "行": "march",
    "街": "street", "袭": "raid", "规": "rule", "视": "look", "解": "loose", "誓": "vow",
    "认": "recognize", "设": "set", "请": "ask", "貌": "looks", "货": "goods", "质": "pledge",
    "赴": "go", "跑": "run", "路": "road", "转": "turn", "轮": "wheel", "轴": "axle",
    "辎": "baggage", "达": "reach", "返": "return", "这": "this", "进": "advance", "远": "far",
    "选": "choose", "递": "relay", "速": "speed", "造": "make", "道": "road", "遗": "remain",
    "避": "avoid", "都": "capital", "酒": "wine", "酿": "brew", "釉": "glaze", "重": "heavy",
    "野": "field", "金": "metal", "钟": "bell", "钤": "seal", "铁": "iron", "铃": "bell",
    "铜": "copper", "银": "silver", "锁": "lock", "镇": "town", "镖": "escort", "镜": "mirror",
    "长": "long", "门": "gate", "阙": "gate", "队": "squad", "防": "guard", "阶": "step",
    "陆": "land", "陌": "lane", "集": "market", "雨": "rain", "雪": "snow", "零": "zero",
    "雾": "fog", "霜": "frost", "青": "cyan", "面": "face", "鞍": "saddle", "音": "sound",
    "预": "preview", "风": "wind", "馆": "hall", "香": "incense", "马": "horse", "驯": "tame",
    "驿": "post", "验": "test", "骑": "ride", "麾": "banner", "黑": "black", "鼓": "drum",
    "选中": "select",
}

# Polished English for the shell a player actually reads. Chapter ladder lines
# that are not listed here go through the numeral patterns below.
HAND = {
    "「%s堡」": "%s Keep",
    "主菜单": "Main menu",
    "存档": "Save",
    "战役": "Campaign",
    "出战编成 · 最多四人": "Field company · four at most",
    "六维与转职": "Six stats and class change",
    "战技树": "Battle arts",
    "冷却与二阶": "Cooldowns and the second tier",
    "招募新刃": "Recruit a new blade",
    "灰刃与铁火": "Ash blades and iron fire",
    "粮铁药材": "Grain, iron, herbs",
    "属地": "Estates",
    "四野租佃庄园": "Tenant manors in the four fields",
    "陆桥委托": "Land-bridge contracts",
    "工事": "Works",
    "厅堂校场市集": "Hall, yard, and market",
    "名册与立绘": "Roster and portraits",
    "祈愈与丰收": "Prayer, healing, harvest",
    "春令与期望": "Spring rite and expectations",
    "血胤与容貌": "Bloodline and looks",
    "授旗礼": "Banner rite",
    "子嗣三步入队": "Three steps for an heir to join",
    "预告与推进": "Forecast and advance",
    "设置": "Settings",
    "规则与速度": "Rules and speed",
    "舆图": "Atlas",
    "跑图 · 城镇 · 委托": "Roads, towns, contracts",
    "本季事务": "This season",
    "%s · %s旗大厅事务汇总": "%s · %s hall, this month",
    "MAINLINE · 主线": "MAINLINE · Story",
    "战役推进": "Campaign",
    "继续主线": "Continue story",
    "RECRUIT · 征募": "RECRUIT · Hiring",
    "酒馆有新面孔": "New faces in the tavern",
    "烽火酒馆的候选人每旬轮换；职业、特质与佣金各不相同。": "Beacon Tavern rotates candidates every tenday. Class, traits, and fee all differ.",
    "麾下": "Company",
    "%d 人": "%d people",
    "银币": "Silver",
    "前往酒馆接洽": "Go to the tavern",
    "ALLIANCE · 家族": "ALLIANCE · Household",
    "联姻与传承": "Marriage and inheritance",
    "联姻缔约决定血脉与可遗传特质；子嗣成年后可行授旗礼入队。": "A marriage contract sets the blood and the traits that pass on. Grown heirs can take the banner rite and join.",
    "已缔约": "Contracted",
    "%d 对": "%d pairs",
    "子嗣": "Heirs",
    "前往联姻廷": "Go to the marriage court",
    "确认 / 选定": "Confirm / choose",
    "返回中枢": "Back to the hub",
    "快速休整": "Quick rest",
    "当前中枢士气：%d%%  ●": "Hub morale: %d%%",
    "%d 岁": "Age %d",
    "生命 HP": "HP",
    "攻击 ATK": "ATK",
    "防御 DEF": "DEF",
    "移动 MOV": "MOV",
    "%s旗家主，率 %d 名骑士守着这座堡。工事、委任与联姻誓约都会写入家族旁注。": "%s heads the house and holds this keep with %d knights. Works, contracts, and marriage vows are written into the family notes.",
    "检视骑士完整档案": "Open the full file",
    "请爵": "Petitions",
    "确认": "Confirm",
    "返回": "Back",
    "切换分区": "Switch section",
    "主线暂缓。敌宅交涉、授旗分支、战技与传代皆可。": "The story is paused. Rival houses, banner branches, battle arts, and succession are all open.",
    "新的旗号": "New banner",
    "继续历程": "Continue",
    "退出": "Quit",
    "百年骑士·同型原创": "Century Knights",
    "灰烬旗 · 朔澜陆桥": "Ash Banner · Shuo Lan Bridge",
    "灰旗堡": "Ash Keep",
    "花名册": "Roster",
    "烽火酒馆": "Beacon Tavern",
    "委任榜": "Contracts",
    "演武场": "Drill yard",
    "炉火工坊": "Forge",
    "祠堂": "Shrine",
    "族谱": "Lineage",
    "联姻廷": "Marriage court",
    "岁月沙漏": "Hourglass",
    "陆桥商路": "Bridge market",
    "出战编队": "Deploy",
    "粮食": "Grain",
    "铁料": "Iron",
    "药材": "Herbs",
    "士气": "Morale",
    "第 %d 年 %d 月": "Year %d, month %d",
    "陌生": "Unknown",
    "认识": "Known",
    "友善": "Friendly",
    "信赖": "Trusted",
    "尊敬": "Respected",
    "力": "STR",
    "体": "VIT",
    "技": "SKL",
    "敏": "AGI",
    "感": "PER",
    "意": "WIL",
    "规则透视": "Rules preview",
    "王朝手记": "Dynasty journal",
    "子嗣期望": "Heir expectations",
    "银币不足": "Not enough silver",
    "声望不足，还差：%s": "Renown short: %s",
    "存档成功": "Saved",
    "读档成功": "Loaded",
    "胜利": "Victory",
    "全军覆没——可重试": "Wiped out — you can retry",
    "移动": "Move",
    "攻击": "Attack",
    "待命": "Wait",
    "结束回合": "End turn",
    "招募": "Recruit",
    "成婚": "Marry",
    "度过一月": "Advance a month",
    "度过一季": "Advance a season",
    "将发生": "Coming",
    "传家宝槽（完整版开放）": "Heirloom slot (opens in the full edition)",
    "第一章·陆桥烽火": "Chapter 1 · Bridge beacons",
    "SIL Open Font License 1.1。本仓库只带项目用到的子集。": "SIL Open Font License 1.1. This repo ships only the subset the project uses.",
    "SIL Open Font License 1.1。粗体子集，许可与常规体相同。": "SIL Open Font License 1.1. Bold subset, same license as the regular face.",
    "SIL Open Font License 1.1。用于数字与等宽读数。": "SIL Open Font License 1.1. Used for numerals and monospace readouts.",
    "制作人员 · CREDITS": "Credits",
    "百年骑士": "Century Knights",
    "独立原创项目。本页只列仓库里真实在用的第三方字体，不编造职务名单。": "An original project. This page lists only the third-party fonts actually used in the repo. It does not invent a staff list.",
    "原创声明": "Original work",
    "系统、文本、界面与代码均为本项目原创。对战棋类型的致敬只留在规则层，不收入其他作品的名称、角色、图像或音频。": "Systems, text, interface, and code are original to this project. The nod to the tactics genre stays in the rules. No other work's names, characters, images, or audio are included.",
    "字体许可": "Font licenses",
    "三份字体均为 SIL Open Font License 1.1，说明见 docs/licenses.md。": "All three fonts are SIL Open Font License 1.1. See docs/licenses.md.",
    "粮": "Grain",
    "铁": "Iron",
    "药": "Herb",
    "[b]%s[/b]　%s　%d岁　%s": "[b]%s[/b]  %s  age %d  %s",
    "六维 力%d 体%d 技%d 敏%d 感%d 意%d": "Stats STR %d VIT %d SKL %d AGI %d PER %d WIL %d",
    "血胤 %s": "Blood %s",
    "禀性 ": "Traits ",
    "无": "None",
    "[color=#c75a5a]【临时伤】[/color]": "[b]Temporary wound[/b]",
    "历": "Date",
    "返回城堡": "Back to keep",
    "继续 / 选择": "Continue / choose",
    "CENTURY KNIGHTS · 百年骑士": "CENTURY KNIGHTS",
    "战棋 · 城堡 · 联姻 · 传代——一面旗，要扛过百年。": "Tactics, a keep, marriage, and succession. One banner has to last a century.",
    "原创 IP · v8.6 · Godot 4.3": "Original · v8.6 · Godot 4.3",
    "↑ ↓ 选择    Enter 确认": "Up / down to choose    Enter to confirm",
    "设置 · SETTINGS": "Settings",
    "界面缩放": "UI scale",
    "色觉": "Color vision",
    "标准（薄荷 / 珊瑚）": "Standard (mint / coral)",
    "绿色弱": "Green-weak",
    "红色弱": "Red-weak",
    "蓝色弱": "Blue-weak",
    "高对比": "High contrast",
    "棋子预览": "Piece preview",
    "我军": "Ally",
    "敌军": "Enemy",
    "震屏强度": "Shake",
    "触感": "Haptics",
    "战斗规则透视（命中/伤害区间）": "Combat readout (hit and damage range)",
    "新手高亮指引": "First-visit highlights",
    "文字速度": "Text speed",
    "背景音乐（程序氛围床）": "Music (procedural bed)",
    "音效": "Sound effects",
    "3D 战斗演出": "3D battle scenes",
    "战斗演出默认 2×": "Battle scenes default to 2x",
    "减动效": "Reduced motion",
    "音频为程序生成。色觉模式用圆和三角区分敌我，不单靠颜色。": "Audio is generated in code. Color-vision modes mark allies with a circle and enemies with a triangle, not color alone.",
    "切换": "Toggle",
    "系统百科": "System codex",
    "关闭": "Close",
    "点击继续": "Tap to continue",
    "战棋": "Tactics",
    "墨蓝棋盘上轮流行动。薄荷标记是自己人，珊瑚标记是对手，危险区用半透明珊瑚铺开。": "Sides act in turns on the ink-blue board. Mint marks your own people, coral marks the opponent, and danger is laid down in translucent coral.",
    "城堡": "Castle",
    "灰旗堡按月推进。名册、酒馆、工坊、商路和祠堂都从这里进出。": "Ash Keep advances by the month. The roster, tavern, workshop, trade road, and shrine are all entered from here.",
    "佣兵团": "Company",
    "银币、粮食、铁料和药材是这个月过不过得去的账。出战前先看伤病和士气。": "Silver, grain, iron, and herbs are the books for this month. Check wounds and morale before you march.",
    "联姻": "Marriage",
    "婚约写进族谱。显征会传到下一代，朝堂上看的是血缘，不是空头衔。": "A marriage contract is written into the lineage. Visible traits pass on. The court reads blood, not empty titles.",
    "十国城埠之间跑商、接委托。路上的旗号决定别人认不认你。": "Trade and contracts run between the cities of the ten nations. The banner you fly decides whether they know you.",
    "灯引": "Lamp guide",
    "LAMP · 灯引": "LAMP",
    "第一次走进某个地方时，灯引只亮一次。可以在设置里关掉高亮，也可以在这本百科里重看。": "The lamp guide lights only the first time you enter a place. Turn the highlight off in settings, or reread it in this codex.",
    "灯引只在第一次走进某个地方时点亮。设置里可以关掉新手高亮。": "The lamp guide lights only the first time you enter a place. First-visit highlights can be turned off in settings.",
    "系统百科收着战棋、城堡、联姻和舆图的短说明，随时能翻。": "The codex keeps short notes on tactics, the keep, marriage, and the atlas.",
    "CODEX · 系统百科": "CODEX",
    "军务": "Military",
    "内政": "Stewardship",
    "家族": "Household",
    "朝堂": "Court",
    "本月待办": "This month",
    "可升级工事": "Works to raise",
    "可交付委托": "Contracts ready",
    "可议婚事": "Marriages to discuss",
    "伤病": "Wounded",
    "节庆": "Festival",
    "可演武": "Drill is open",
    "语言": "Language",
    "中文": "Chinese",
    "战技": "Art",
    "取消": "Cancel",
    "第 1 回合": "Round 1",
    "玩家回合": "Player turn",
    "第 %d 回合": "Round %d",
    "%s · 玩家回合": "%s · Player turn",
    "%s · 我方行动": "%s · Your move",
    "%s · 敌方行动": "%s · Enemy move",
    "%s · 第 %d 回合": "%s · Round %d",
    "战报": "Report",
    "左键 选中/移动 · Q 攻击 · W 战技 · E 待命 · Enter 结束回合 · 右键 取消": "Left click select/move · Q attack · W art · E wait · Enter end turn · Right click cancel",
    "点按 选中/确认 · 长按 情报 · 单指平移 · 双指缩放 · 底栏下达指令": "Tap select/confirm · Hold for intel · Drag to pan · Pinch to zoom · Commands sit on the bottom bar",
    "选中单位后点「战技」循环选择；进攻技在攻击时消耗。": "Select a unit, then tap Art to cycle. Attack arts are spent when you strike.",
    "败北": "Defeat",
    "返回舆图": "Back to atlas",
    "返回章节": "Back to chapter",
    "确认指令": "Confirm",
    "重新挑战": "Retry",
    "无人阵亡": "No one fell",
    "%d 人负伤撤离": "%d withdrawn wounded",
    "出战骑士历练": "Knights in the field",
    "出战骑士状态": "Knight status",
    "负伤撤离 · HP 已按 30% 回复": "Withdrawn wounded · HP restored to 30%",
    "已全员回满，可立即重试": "Everyone is restored. You can retry now.",
    "战役缴获物资": "Spoils",
    "战败须知": "After a loss",
    "SILVER · 军资入库": "SILVER · deposited",
    "声望": "Renown",
    "RENOWN · 灰烬邦": "RENOWN · Ash League",
    "战技点": "Art points",
    "SKILL POINT · 可在战技树分配": "ART POINT · spend it on the art tree",
    "进度": "Progress",
    "PROGRESS · 旗标保留": "PROGRESS · flags kept",
    "保留": "Kept",
    "生命": "HP",
    "HP · 全员回满": "HP · fully restored",
    "建议": "Tip",
    "TIP · 先锁定再推进": "TIP · lock a foe before you advance",
    "重试": "Retry",
    "FORCE WITHDRAWN // 战败可重试，进度旗标保留": "FORCE WITHDRAWN // you can retry, and progress flags stay",
    "%s肃清。灰旗仍在风里——战报已写入家族史。": "%s is clear. The ash banner is still in the wind. The report is in the family history.",
    "旗可再举。败北不毁进度：调整编成与站位后重试。": "The banner can be raised again. A loss does not erase progress. Change the company and the line, then retry.",
    "当前卷": "Current volume",
    "已解锁章节": "Chapters open",
    "%d 章": "%d chapters",
    "CAMPAIGN // 章节直达": "CAMPAIGN // chapter jump",
    "前往选中章": "Open the selected chapter",
    "第零章进行中：节拍 %s —— 点「第零章节拍」继续剧情": "Chapter 0 is in progress: beat %s. Continue the story from that beat.",
    "暂停": "Paused",
    "继续": "Continue",
    "读档": "Load",
    "回到标题": "Title",
    "攻%d  防%d  命%d  避%d  移%d": "ATK %d  DEF %d  HIT %d  AVO %d  MOV %d",
    "%s　余%d%s": "%s  left %d%s",
    "　冷却%d": "  cooldown %d",
    "[b]选择己方单位开始行动[/b]\n目标：歼灭全部敌人。\n蓝格可移动 · 红格为可攻目标 · 攻击模式后点敌。": "[b]Choose one of yours to act[/b]\nGoal: defeat every enemy.\nBlue cells are movement · red cells can be attacked · enter attack mode, then tap a foe.",
    "【攻击模式】点击红格敌人": "[Attack] Tap an enemy on a red cell",
    "【已移动】可攻击 / 待命": "[Moved] You can attack or wait",
    "【已选中】点击蓝格移动，或开攻击模式": "[Selected] Tap a blue cell to move, or enter attack mode",
    "[b]%s[/b]（%s·%s） HP %d/%d\n攻 %d 防 %d\n地形：%s（回避+%d 防+%d）\n（仍选中我军，可继续移动/攻击）": "[b]%s[/b] (%s · %s) HP %d/%d\nATK %d DEF %d\nTerrain: %s (avo +%d def +%d)\n(Your unit stays selected. You can still move or attack.)",
    "[b]%s[/b]（%s·%s） HP %d/%d\n攻 %d 防 %d 命中 %d 回避 %d 移动 %d\n地形：%s（回避+%d 防+%d）\n": "[b]%s[/b] (%s · %s) HP %d/%d\nATK %d DEF %d HIT %d AVO %d MOV %d\nTerrain: %s (avo +%d def +%d)\n",
    "透视→%s：命中 %d%% 伤害 %d–%d 暴%d%%%s\n": "Preview → %s: hit %d%% damage %d–%d crit %d%%%s\n",
    "功": "Merit",
    "剂": "Dose",
    "槛": "Bar",
    "显": "Shown",
    "隐": "Hidden",
    "父": "Father",
    "女": "Daughter",
    "合": "Match",
    "母": "Mother",
    "龄": "Age",
    "纯": "Pure",
    "添丁": "Birth",
    "辞世": "Death",
    "更替": "Succession",
    "危机": "Crisis",
    "配婚": "Match",
    "归国": "Return",
    "尚未入册。法则：%s。见过或在祠堂验到之后，图鉴才写下名字。": "Not entered yet. Law: %s. The codex writes the name after you have met them or tested them at the shrine.",
    "无父母可溯": "No parents on record",
    "不在谱": "Not on the tree",
    "来自": "From",
    "未验": "Untested",
    "双亲未见此因": "Neither parent shows this cause",
    "选定双方后，这里按性状给出子嗣概率。": "After you pick both sides, the odds for the child are written here.",
    " · 携因须立功": " · a carried cause still needs a deed",
    "  女%d%% · 男%d%%": "  daughter %d%% · son %d%%",
    "  女%d · 男%d": "  daughter %d · son %d",
    "这对父母没有可计算的冕征或特征。": "These parents have no crown sign or trait the court can count.",
}

SHELL_FILES = [
    "project/scripts/hub/castle_hub.gd",
    "project/scripts/ui/settings.gd",
    "project/scripts/ui/ui_kit.gd",
    "project/scripts/ui/credits.gd",
    "project/scripts/ui/unit_card.gd",
    "project/scripts/ui/main_menu.gd",
    "project/scripts/ui/widgets/help_codex.gd",
    "project/scripts/ui/widgets/tips_registry.gd",
    "project/scripts/ui/widgets/coach.gd",
    "project/scripts/battle/ui/battle_mobile_bar.gd",
    "project/scripts/battle/ui/battle_info_panel.gd",
    "project/scripts/battle/ui/battle_report.gd",
    "project/scripts/battle/battle_controller.gd",
]
# battle_controller stays with the battle stream except these HUD labels.
BATTLE_ALLOW = {
    "第 1 回合",
    "玩家回合",
    "第 %d 回合",
    "%s · 玩家回合",
    "%s · 我方行动",
    "%s · 敌方行动",
    "战报",
    "左键 选中/移动 · Q 攻击 · W 战技 · E 待命 · Enter 结束回合 · 右键 取消",
    "点按 选中/确认 · 长按 情报 · 单指平移 · 双指缩放 · 底栏下达指令",
    "选中单位后点「战技」循环选择；进攻技在攻击时消耗。",
}
LOCALE_KEYS = [
    ("menu_new", "新的旗号"),
    ("menu_continue", "继续历程"),
    ("menu_settings", "设置"),
    ("menu_quit", "退出"),
    ("game_title", "百年骑士·同型原创"),
    ("subtitle", "灰烬旗 · 朔澜陆桥"),
    ("hub_title", "灰旗堡"),
    ("btn_roster", "花名册"),
    ("btn_tavern", "烽火酒馆"),
    ("btn_quests", "委任榜"),
    ("btn_train", "演武场"),
    ("btn_forge", "炉火工坊"),
    ("btn_shrine", "祠堂"),
    ("btn_lineage", "族谱"),
    ("btn_marriage", "联姻廷"),
    ("btn_hourglass", "岁月沙漏"),
    ("btn_market", "陆桥商路"),
    ("btn_back", "返回"),
    ("btn_deploy", "出战编队"),
    ("silver", "银币"),
    ("food", "粮食"),
    ("iron", "铁料"),
    ("herb", "药材"),
    ("morale", "士气"),
    ("year_month", "第 %d 年 %d 月"),
    ("rep_none", "陌生"),
    ("rep_known", "认识"),
    ("rep_friendly", "友善"),
    ("rep_trusted", "信赖"),
    ("rep_respected", "尊敬"),
    ("stat_str", "力"),
    ("stat_vit", "体"),
    ("stat_skl", "技"),
    ("stat_agi", "敏"),
    ("stat_per", "感"),
    ("stat_wil", "意"),
    ("rules_preview", "规则透视"),
    ("dynasty_journal", "王朝手记"),
    ("heir_expect", "子嗣期望"),
    ("not_enough_silver", "银币不足"),
    ("not_enough_rep", "声望不足，还差：%s"),
    ("save_ok", "存档成功"),
    ("load_ok", "读档成功"),
    ("battle_win", "胜利"),
    ("battle_lose", "全军覆没——可重试"),
    ("move", "移动"),
    ("attack", "攻击"),
    ("wait", "待命"),
    ("end_turn", "结束回合"),
    ("recruit", "招募"),
    ("marry", "成婚"),
    ("advance_month", "度过一月"),
    ("advance_season", "度过一季"),
    ("forecast", "将发生"),
    ("heirloom_preview", "传家宝槽（完整版开放）"),
    ("chapter1_title", "第一章·陆桥烽火"),
    ("shell_language", "语言"),
    ("shell_lang_zh", "中文"),
    ("shell_lang_en", "English"),
    ("locale_missing", "（缺译文）"),
    ("pause_heading", "暂停"),
    ("pause_continue", "继续"),
    ("pause_save", "存档"),
    ("pause_load", "读档"),
    ("pause_settings", "设置"),
    ("pause_title", "回到标题"),
]


def cn_int(token: str) -> int:
    if token.isdigit():
        return int(token)
    digits = {"零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}
    units = {"十": 10, "百": 100, "千": 1000}
    total = 0
    cur = 0
    for ch in token:
        if ch in digits:
            cur = digits[ch]
        elif ch in units:
            if cur == 0:
                cur = 1
            total += cur * units[ch]
            cur = 0
        else:
            return -1
    return total + cur


def _specs(fmt: str) -> list[str]:
    return re.findall(r"%(?:\d+\$)?[-+#0 ]*\d*(?:\.\d+)?[sdif]", fmt.replace("%%", ""))


def _gloss_rest(text: str) -> str:
    out: list[str] = []
    buf: list[str] = []

    def flush() -> None:
        if buf:
            out.append(" ".join(buf))
            buf.clear()

    for ch in text:
        if ch in PUNCT:
            flush()
            out.append(PUNCT[ch])
            continue
        if CJK_RE.match(ch):
            buf.append(GLOSS.get(ch, "x"))
            continue
        flush()
        out.append(ch)
    flush()
    folded = "".join(out)
    folded = re.sub(r"[ \t]{2,}", " ", folded)
    folded = re.sub(r" +([.,;:!?])", r"\1", folded)
    return folded.strip()


PHRASES = (
    ("点「继续主线」", "choose Continue "),
    ("可继续", "Continue "),
    ("可点", "Open "),
    ("继续主线", "continue the story"),
    ("已执", " is done"),
    ("中段", " midpoint"),
    ("后半", " second half"),
    ("前半", " first half"),
    ("或经营", " or run the keep"),
    ("席终", " closing"),
    ("进行中", " in progress"),
    ("节拍", " beat"),
)


def translate(text: str) -> str:
    if text in HAND:
        return HAND[text]
    vol = re.fullmatch(rf"卷({NUM})", text)
    if vol and cn_int(vol.group(1)) >= 0:
        return "Volume %d" % cn_int(vol.group(1))
    worked = text
    for src, dst in PHRASES:
        worked = worked.replace(src, dst)
    worked = re.sub(rf"第({NUM})章", lambda m: "Chapter %d" % cn_int(m.group(1)) if cn_int(m.group(1)) >= 0 else m.group(0), worked)
    worked = re.sub(rf"第({NUM})卷", lambda m: "Volume %d" % cn_int(m.group(1)) if cn_int(m.group(1)) >= 0 else m.group(0), worked)
    worked = re.sub(rf"(?<![\w])({NUM})卷", lambda m: "Volume %d" % cn_int(m.group(1)) if cn_int(m.group(1)) >= 0 else m.group(0), worked)
    en = _gloss_rest(worked)
    if _specs(text) != _specs(en):
        # Keep the Chinese format tokens aligned if a gloss ate one.
        en = _gloss_rest(text)
    if CJK_RE.search(en):
        en = re.sub(r"[\u4e00-\u9fff]", "x", en)
    return en


def decode_gd(body: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(body):
        if body[i] != "\\":
            out.append(body[i])
            i += 1
            continue
        if i + 1 >= len(body):
            out.append("\\")
            break
        nxt = body[i + 1]
        mapping = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}
        if nxt in mapping:
            out.append(mapping[nxt])
            i += 2
            continue
        out.append(nxt)
        i += 2
    return "".join(out)


def literal_body(raw: str) -> str:
    if raw.startswith(('"""', "'''")):
        return decode_gd(raw[3:-3])
    return decode_gd(raw[1:-1])


def key_for(text: str) -> str:
    digest = hashlib.sha1(text.encode("utf-8")).hexdigest()[:8]
    return "shell_" + digest


def _line_at(text: str, pos: int) -> str:
    start = text.rfind("\n", 0, pos) + 1
    end = text.find("\n", pos)
    if end < 0:
        end = len(text)
    return text[start:end]


def skip_literal(text: str, pos: int, decoded: str, path: str) -> bool:
    if path.endswith("battle_controller.gd") and decoded not in BATTLE_ALLOW:
        return True
    if path.endswith("battle_info_panel.gd") and decoded in {"匪首", "头目"}:
        return True
    window = text[max(0, pos - 12):pos]
    if window.endswith(".find(") or window.endswith("find("):
        return True
    line = _line_at(text, pos)
    stripped = line.lstrip("\t")
    indent = len(line) - len(stripped)
    if indent == 0 and stripped.startswith("var "):
        return True
    if stripped.startswith("func ") or stripped.startswith("static func "):
        return True
    return False


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT).as_posix()
    spans = ratchet._exempt_spans(text)
    found: list[tuple[int, str, str]] = []
    for pos, raw in ratchet._literals(text):
        if ratchet._inside(spans, pos):
            continue
        if not CJK_RE.search(raw):
            continue
        decoded = literal_body(raw)
        if skip_literal(text, pos, decoded, rel):
            continue
        found.append((pos, raw, decoded))
    return found


def rewrite(path: Path, rows: dict[str, tuple[str, str]]) -> int:
    text = path.read_text(encoding="utf-8")
    found = scan_file(path)
    if not found:
        return 0
    for pos, raw, decoded in sorted(found, key=lambda item: item[0], reverse=True):
        key = key_for(decoded)
        rows[key] = (decoded, translate(decoded))
        text = text[:pos] + 'Locale.t("%s")' % key + text[pos + len(raw):]
    if path.name == "ui_kit.gd" and 'back_text: String = "返回城堡"' in text:
        text = text.replace('back_text: String = "返回城堡"', 'back_text: String = ""', 1)
        needle = "\tvar bar := Control.new()\n"
        insert = '\tif back_text == "":\n\t\tback_text = Locale.t("%s")\n' % key_for("返回城堡")
        rows[key_for("返回城堡")] = ("返回城堡", translate("返回城堡"))
        if needle in text and insert not in text:
            text = text.replace(needle, insert + needle, 1)
    path.write_text(text, encoding="utf-8")
    return len(found)


def write_csv(path: Path, rows: list[tuple[str, str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["keys", "zh_CN", "en"])
        for key, zh, en in rows:
            writer.writerow([key, zh, en])


def fill_ux_csv() -> int:
    path = ROOT / "project/data/locale/ux.csv"
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or ["keys", "zh_CN", "en"]
        body = list(reader)
    filled = 0
    for row in body:
        zh = row.get("zh_CN", "") or ""
        en = row.get("en", "") or ""
        if zh and not en:
            row["en"] = translate(zh)
            filled += 1
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(body)
    return filled


def collect_rows() -> tuple[dict[str, tuple[str, str]], int]:
    rows: dict[str, tuple[str, str]] = {}
    total = 0
    for rel in SHELL_FILES:
        path = ROOT / rel
        if not path.is_file():
            print("missing", rel)
            continue
        found = scan_file(path)
        total += len(found)
        for _pos, _raw, decoded in found:
            rows[key_for(decoded)] = (decoded, translate(decoded))
    return rows, total


def main() -> int:
    apply = "--apply" in sys.argv
    rows, total = collect_rows()
    missing_gloss = sorted({ch for zh, _en in rows.values() for ch in zh if CJK_RE.match(ch) and ch not in GLOSS and zh not in HAND})
    cjk_en = [key for key, (_zh, en) in rows.items() if CJK_RE.search(en)]
    bad_spec = [key for key, (zh, en) in rows.items() if _specs(zh) != _specs(en)]
    print("candidates=%d unique=%d gloss_gaps=%d cjk_en=%d spec_mismatch=%d" % (total, len(rows), len(missing_gloss), len(cjk_en), len(bad_spec)))
    if missing_gloss:
        print("GLOSS GAP " + "".join(missing_gloss))
    if cjk_en:
        print("CJK EN " + " ".join(cjk_en[:12]))
    if bad_spec:
        print("SPEC " + " ".join(bad_spec[:12]))
    if not apply:
        for key in sorted(rows)[:8]:
            zh, en = rows[key]
            print("%s\t%s\t=> %s" % (key, zh[:40].replace("\n", "\\n"), en[:60].replace("\n", "\\n")))
        print("EXTRACT PASS")
        return 0
    rewritten = 0
    for rel in SHELL_FILES:
        path = ROOT / rel
        if path.is_file():
            rewritten += rewrite(path, rows)
    ordered: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for key, zh in LOCALE_KEYS:
        en = "" if key == "locale_missing" else translate(zh)
        if key == "shell_lang_en":
            en = "English"
        ordered.append((key, zh, en))
        seen.add(key)
    for key in sorted(rows):
        if key in seen:
            continue
        zh, en = rows[key]
        ordered.append((key, zh, en))
    write_csv(ROOT / "project/data/locale/strings.csv", ordered)
    filled = fill_ux_csv()
    print("rewritten=%d csv_rows=%d ux_en_filled=%d" % (rewritten, len(ordered), filled))
    print("EXTRACT PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
