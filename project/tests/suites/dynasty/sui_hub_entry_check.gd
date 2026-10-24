extends Node

const HUB := "res://scenes/hub/castle_hub.tscn"
## Y1-B: castle hub family nav exposes named ToSuiYear → yearcard;
## unread inbox paints a count on the entry + family todo badge.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL sui hub entry: ", err)
		get_tree().quit(1)
	else:
		print("SUI HUB ENTRY PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods["sui_inbox"] = []
	GameState.house_mods["sui_yeartrace"] = []

	var err := await _audit_empty_hub()
	if err != "":
		return err
	err = await _audit_unread_badge()
	if err != "":
		return err
	err = _audit_todo_family()
	if err != "":
		return err
	err = _audit_unlock()
	if err != "":
		return err
	return ""


func _audit_empty_hub() -> String:
	var page: Control = load(HUB).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var btn: Button = page.find_child("ToSuiYear", true, false) as Button
	if btn == null:
		page.queue_free()
		return "ToSuiYear missing on empty inbox"
	if not btn.visible or not btn.is_visible_in_tree():
		page.queue_free()
		return "ToSuiYear not visible"
	if btn.disabled:
		page.queue_free()
		return "ToSuiYear disabled"
	if str(btn.get_meta("hub_entry", "")) != "sui_ke":
		page.queue_free()
		return "hub_entry want=sui_ke got=%s" % str(btn.get_meta("hub_entry", ""))
	var fam := page.find_child("NavGroup_family", true, false)
	if fam == null or not fam.is_ancestor_of(btn):
		page.queue_free()
		return "ToSuiYear not under NavGroup_family"
	var label := Locale.t("btn_sui_year")
	if btn.text.find(label) < 0:
		page.queue_free()
		return "ToSuiYear text missing label want=%s got=%s" % [label, btn.text]
	var tail := btn.text.split(label, true, 1)
	if tail.size() > 1 and str(tail[1]).strip_edges() != "":
		page.queue_free()
		return "empty inbox should not badge ToSuiYear got=%s" % btn.text
	print("sui-hub empty ok ToSuiYear under_family=1")
	page.queue_free()
	await get_tree().process_frame
	return ""


func _audit_unread_badge() -> String:
	GameState.house_mods["sui_inbox"] = [
		{"cid": "leader", "id": "probe", "title": "试", "body": "", "side": "left", "outcome": "稳", "band": "sui", "year": 1, "month": 1},
		{"cid": "leader", "id": "probe2", "title": "试二", "body": "", "side": "right", "outcome": "胆", "band": "sui", "year": 1, "month": 2},
	]
	if CKSuiKe.inbox_count() != 2:
		return "seed inbox_count want=2 got=%d" % CKSuiKe.inbox_count()

	var page: Control = load(HUB).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame

	var btn: Button = page.find_child("ToSuiYear", true, false) as Button
	if btn == null:
		page.queue_free()
		return "ToSuiYear missing with unread"
	if btn.text.find("2") < 0:
		page.queue_free()
		return "unread badge missing on ToSuiYear got=%s" % btn.text
	var chip: Button = page.find_child("Todo_sui_ke", true, false) as Button
	if chip == null:
		page.queue_free()
		return "Todo_sui_ke chip missing"
	if chip.text.find("2") < 0:
		page.queue_free()
		return "Todo_sui_ke count missing got=%s" % chip.text
	## Smoke: press does not error (nav may no-op / hang if we follow replace — do not await go).
	if btn.disabled:
		page.queue_free()
		return "ToSuiYear disabled with unread"
	print("sui-hub unread ok badge=2 todo_chip=1")
	page.queue_free()
	await get_tree().process_frame
	return ""


func _audit_todo_family() -> String:
	var hit := false
	for item in CKTodoCenter.snapshot():
		if str(item.get("category", "")) != "sui_ke":
			continue
		hit = true
		if str(item.get("group", "")) != "family":
			return "sui_ke todo group want=family got=%s" % str(item.get("group", ""))
		if str(item.get("link", "")) != "res://scenes/hub/sui_yearcard.tscn":
			return "sui_ke link bad %s" % str(item.get("link", ""))
		if int(item.get("count", 0)) != 2:
			return "sui_ke count want=2 got=%d" % int(item.get("count", 0))
	if not hit:
		return "sui_ke todo row missing"
	if CKTodoCenter.count_for("family") < 2:
		return "family badge count < 2 got=%d" % CKTodoCenter.count_for("family")
	print("sui-hub todo family ok")
	return ""


func _audit_unlock() -> String:
	UnlockSchedule.install()
	if not UnlockSchedule.allows("sui_ke"):
		return "sui_ke not in year_one unlock"
	var st: Dictionary = UnlockSchedule.state("sui_ke")
	if not bool(st.get("open", false)):
		return "sui_ke state not open"
	print("sui-hub unlock ok")
	return ""
