extends Node
## UX-06：入口分组、本月待办六类、解锁接口、章节梯子、dynasty.csv 的 payoff 文案。

const Todo := preload("res://scripts/ui/widgets/todo_center.gd")

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	Todo.reset_for_tests()
	_payoff_strings()
	_ladder()
	_unlock_and_scale()
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	_todos()
	await _hub()
	if _fails.is_empty():
		print("HUB_IA PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL hub_ia: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _payoff_strings() -> void:
	_ok(Locale.t("payoff_forecast") == "战斗投影", "payoff_forecast=%s" % Locale.t("payoff_forecast"))
	_ok(Locale.t("payoff_tactic") == "战术禀性", "payoff_tactic=%s" % Locale.t("payoff_tactic"))
	_ok(Locale.t("payoff_effect") == "效果", "payoff_effect=%s" % Locale.t("payoff_effect"))
	_ok(Locale.t("payoff_tier") == "王技分阶", "payoff_tier=%s" % Locale.t("payoff_tier"))

func _ladder() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/hub/castle_hub.gd")
	var re := RegEx.new()
	re.compile("chapter[0-9]*_done")
	var n := re.search_all(src).size()
	_ok(n <= 2, "chapter ladder count %d" % n)

func _unlock_and_scale() -> void:
	_ok(Todo.is_unlocked("deploy"), "deploy locked")
	_ok(not Todo.is_unlocked("marriage"), "marriage open before its chapter")
	_ok(not Todo.is_unlocked("not_a_real_entry"), "unknown entry unlocked")
	_ok(is_equal_approx(Todo.narrow_scale(1280.0), 1.0), "desktop scale")
	_ok(is_equal_approx(Todo.narrow_scale(1080.0), 1080.0 / 1280.0), "phone scale")

func _todos() -> void:
	var leader = GameState.get_leader()
	if leader:
		leader.injured = true
	Calendar.month = Calendar.SPRING_MONTH
	if GameState.quests.is_empty():
		GameState.quests.append({"id": "probe"})
	if GameState.marriage_candidates.is_empty():
		GameState.marriage_candidates.append({"id": "probe"})
	GameState.silver = maxi(int(GameState.silver), int(GameState.train_cost()))
	Todo.register("probe", "atlas", "探针", 1)
	var cats := {}
	for item in Todo.snapshot():
		cats[str(item.get("category", ""))] = int(item.get("count", 0))
	for id in ["buildings", "quests", "marriage", "injured", "festival", "train"]:
		_ok(int(cats.get(id, 0)) > 0, "todo %s count %s" % [id, str(cats.get(id, 0))])
	_ok(cats.size() >= 6, "categories %d" % cats.size())
	_ok(int(cats.get("probe", 0)) == 1, "register missing")

func _hub() -> void:
	var packed: PackedScene = load("res://scenes/hub/castle_hub.tscn")
	_ok(packed != null, "castle_hub missing")
	if packed == null:
		return
	var hub = packed.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(hub.get_script() != null and hub.has_method("panel_button_labels"), "castle_hub script failed to load")
	if not hub.has_method("panel_button_labels"):
		hub.queue_free()
		return
	var labels: Array = hub.panel_button_labels()
	_ok(labels.size() <= 6, "year-one buttons %s" % str(labels))
	_ok(labels.size() >= 4, "buttons %s" % str(labels))
	for sub in ["出战", "演武", "酒馆", "花名册", "岁月", "设置"]:
		var found := false
		for lb in labels:
			if str(lb).find(sub) >= 0:
				found = true
				break
		_ok(found, "missing %s in %s" % [sub, str(labels)])
	for title in ["军务", "内政", "家族", "朝堂", "舆图"]:
		var node := hub.find_child("NavGroup_%s" % _group_id(title), true, false)
		_ok(node != null, "group %s" % title)
	var row := hub.find_child("TodoRow", true, false)
	_ok(row != null and row.get_child_count() >= 6, "todo row %s" % str(row))
	hub.queue_free()
	await get_tree().process_frame

func _group_id(title: String) -> String:
	match title:
		"军务":
			return "military"
		"内政":
			return "civil"
		"家族":
			return "family"
		"朝堂":
			return "court"
		_:
			return "atlas"
