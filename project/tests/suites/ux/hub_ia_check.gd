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
	_mainline()
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
	var todo := FileAccess.get_file_as_string("res://scripts/ui/widgets/todo_center.gd")
	var re := RegEx.new()
	re.compile("chapter[0-9]*_done")
	var n := re.search_all(src).size()
	_ok(n <= 2, "chapter ladder count %d" % n)
	var scenes := RegEx.new()
	scenes.compile("chapter[0-9]+\\.tscn")
	_ok(scenes.search_all(src).size() == 0, "scene ladder still listed")
	_ok(src.find("_chapter_catalog") < 0, "catalog function remains")
	_ok(src.find("StoryCatalog.request_chapter") >= 0, "player entry missing")
	_ok(todo.find("CKStoryState") >= 0, "story state not used")
	_ok(src.find("mainline_target") >= 0, "hub ignores mainline target")

func _unlock_and_scale() -> void:
	_ok(Todo.is_unlocked("deploy"), "deploy locked")
	_ok(Todo.is_unlocked("marriage"), "marriage is a year-one door (#148)")
	_ok(Todo.is_unlocked("atlas"), "atlas is a year-one door (#148)")
	_ok(Todo.is_unlocked("territory"), "territory ledger is a year-one door (P1-UX-04)")
	var st := UnlockSchedule.state("forge")
	_ok(bool(st.locked) and str(st.reason).find("第一卷第 5 章") >= 0 and str(st.link) == "mainline", "forge lock reason %s" % str(st))
	_ok(str(UnlockSchedule.state("rite").reason) != "" and str(UnlockSchedule.state("rite").link) == "", "rite lock reason")
	_ok(bool(UnlockSchedule.state("not_a_real_entry").locked), "unknown entry state")
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
	# Audit P1-1: only real to-dos; catalog length, works, suitors and the tutor are not counted.
	for id in ["injured", "festival"]:
		_ok(int(cats.get(id, 0)) > 0, "todo %s count %s" % [id, str(cats.get(id, 0))])
	for id in ["buildings", "marriage", "train"]:
		_ok(not cats.has(id), "fake todo %s still listed" % id)
	_ok(cats.has("quests") == Todo.is_unlocked("quests"), "quests row ignores the lock")
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
	# #148/#385 eleven doors (+岁课) + castle view + territory ledger (P1-UX-04); locked entries stay visible
	_ok(labels.size() <= 13, "year-one buttons %s" % str(labels))
	_ok(labels.size() >= 6, "buttons %s" % str(labels))
	_ok(hub.find_child("Locked_forge", true, false) != null, "locked forge hidden")
	_ok(hub.find_child("Locked_estates", true, false) != null, "locked estates hidden")
	_ok(hub.find_child("Locked_ancestors", true, false) != null, "orphan ancestors not wired")
	var lk := hub.find_child("Locked_forge", true, false) as BaseButton
	if lk:
		lk.pressed.emit()
		await get_tree().process_frame
		_ok(hub.find_child("LockSheet", true, false) != null and hub.find_child("LockGo", true, false) != null, "lock sheet / take-me-there missing")
		_ok(CKNav.back() == "overlay", "back must close the lock sheet first")
		await get_tree().process_frame
	for sub in [Locale.t("btn_marriage"), Locale.t("btn_lineage"), Locale.t("btn_sui_year"), Locale.t("ux_hub_territory_btn"), "酒馆", "花名册", "岁月", "设置"]:
		var found := false
		for lb in labels:
			if str(lb).find(sub) >= 0:
				found = true
				break
		_ok(found, "missing %s in %s" % [sub, str(labels)])
	for title in ["主堡", "军务", "舆图", "家族", "内政"]:
		var node := hub.find_child("NavGroup_%s" % _group_id(title), true, false)
		_ok(node != null, "group %s" % title)
	var row := hub.find_child("TodoRow", true, false)
	_ok(row != null and row.get_child_count() >= 3, "todo row %s" % str(row))
	var now := hub.find_child("MainlineNow", true, false)
	_ok(now != null and str(now.text) != "", "mainline label missing")
	_ok(hub.find_child("ContinueMainline", true, false) != null, "continue missing")
	var guide := hub.find_child("OpenGuide", true, false) as BaseButton
	_ok(guide != null and str(guide.text).find(Locale.t("ux_help_open")) >= 0, "castle guide")
	hub.queue_free()
	await get_tree().process_frame

func _mainline() -> void:
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	var fresh: Dictionary = Todo.mainline_target()
	_ok(str(fresh.get("id", "")) == "ch0", "fresh id %s" % str(fresh.get("id", "")))
	_ok(not bool(fresh.get("done", true)), "fresh already done")
	_ok(StoryCatalog.request_chapter("ch0") == "res://scenes/story/chapter0.tscn", "ch0 scene")
	GameState.set_flag("chapter0_done")
	var nxt: Dictionary = Todo.mainline_target()
	_ok(str(nxt.get("id", "")) == "e1_01", "after prologue %s" % str(nxt.get("id", "")))
	_ok(StoryCatalog.request_chapter("e1_01") == "res://scenes/story/chapter_player.tscn", "player scene")
	_ok(str(GameState.get_meta("story_chapter_id", "")) == "e1_01", "chapter meta")
	var story: CKStoryState = GameState.story
	_ok(story != null, "story missing")
	if story == null:
		return
	_ok(story.current_chapter() == 0, "current %d" % story.current_chapter())
	story.set_beat(101, "open")
	_ok(story.current_chapter() == 101, "progress %d" % story.current_chapter())
	var mid: Dictionary = Todo.mainline_target()
	_ok(str(mid.get("id", "")) == "e1_01", "mid %s" % str(mid.get("id", "")))
	story.set_beat(101, "end")
	var after: Dictionary = Todo.mainline_target()
	_ok(str(after.get("id", "")) == "e1_02", "after end %s" % str(after.get("id", "")))
	for row in Todo.mainline_rows():
		var idx := int(row.get("index", 0))
		if str(row.get("id", "")) == "ch0" or idx >= CKStoryState.CHAPTER_COUNT:
			continue
		story.set_beat(idx, str(row.get("last_beat", "")))
	# Audit P1-6: e4/e5 (legacy 301–316) fit in CKStoryState, so every chapter can finish.
	var parked: Dictionary = Todo.mainline_target()
	_ok(bool(parked.get("done", false)), "past stored beats %s" % str(parked.get("id", "")))
	_ok(story.current_chapter() < CKStoryState.CHAPTER_COUNT, "current out of range")
	story.set_beat(301, "end")
	_ok(story.beat(301) == "end", "e4_01 beat not stored")

func _group_id(title: String) -> String:
	match title:
		"军务":
			return "military"
		"内政":
			return "civil"
		"家族":
			return "family"
		"主堡":
			return "home"
		_:
			return "atlas"
