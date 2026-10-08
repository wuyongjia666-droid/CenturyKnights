extends Node
## 简体中文字符串表

var strings: Dictionary = {
	"menu_new": "新的旗号",
	"menu_continue": "继续历程",
	"menu_settings": "设置",
	"menu_quit": "退出",
	"game_title": "百年骑士·同型原创",
	"subtitle": "灰烬旗 · 朔澜陆桥",
	"hub_title": "灰旗堡",
	"btn_roster": "花名册",
	"btn_tavern": "烽火酒馆",
	"btn_quests": "委任榜",
	"btn_train": "演武场",
	"btn_forge": "炉火工坊",
	"btn_shrine": "祠堂",
	"btn_lineage": "族谱",
	"btn_marriage": "联姻廷",
	"btn_hourglass": "岁月沙漏",
	"btn_market": "陆桥商路",
	"btn_back": "返回",
	"btn_deploy": "出战编队",
	"silver": "银币",
	"food": "粮食",
	"iron": "铁料",
	"herb": "药材",
	"morale": "士气",
	"year_month": "第 %d 年 %d 月",
	"rep_none": "陌生",
	"rep_known": "认识",
	"rep_friendly": "友善",
	"rep_trusted": "信赖",
	"rep_respected": "尊敬",
	"stat_str": "力",
	"stat_vit": "体",
	"stat_skl": "技",
	"stat_agi": "敏",
	"stat_per": "感",
	"stat_wil": "意",
	"rules_preview": "规则透视",
	"dynasty_journal": "王朝手记",
	"heir_expect": "子嗣期望",
	"not_enough_silver": "银币不足",
	"not_enough_rep": "声望不足，还差：%s",
	"save_ok": "存档成功",
	"load_ok": "读档成功",
	"battle_win": "胜利",
	"battle_lose": "全军覆没——可重试",
	"move": "移动",
	"attack": "攻击",
	"wait": "待命",
	"end_turn": "结束回合",
	"recruit": "招募",
	"marry": "成婚",
	"advance_month": "度过一月",
	"advance_season": "度过一季",
	"forecast": "将发生",
	"heirloom_preview": "传家宝槽（完整版开放）",
	"chapter1_title": "第一章·陆桥烽火",
}

func _ready() -> void:
	_merge_locale_dir("res://data/locale")
	# S09 的曲名表。目录扫描已经会带上它；这里再按路径登记一次，避免以后收窄扫描时丢掉。
	_merge_csv("res://data/locale/audio.csv")

func _merge_locale_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			_merge_csv("%s/%s" % [path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

func _merge_csv(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var header := f.get_csv_line()
	var key_i := header.find("keys")
	if key_i < 0:
		key_i = header.find("key")
	var zh_i := header.find("zh_CN")
	if key_i < 0 or zh_i < 0:
		f.close()
		return
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() <= maxi(key_i, zh_i):
			continue
		var k := str(row[key_i]).strip_edges()
		if k == "" or strings.has(k):
			continue
		strings[k] = str(row[zh_i])
	f.close()

func t(key: String, args: Array = []) -> String:
	var s = strings.get(key, key)
	if args.is_empty():
		return s
	return s % args
