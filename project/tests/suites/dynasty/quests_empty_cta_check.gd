extends Node
## Y1-B: quests empty boards expose EmptyHostActive→ToAtlas and EmptyHostBoard→ToHourglass
## under QuestList (heir #30 / tavern empty CTA pattern).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL quests empty cta: ", err)
		get_tree().quit(1)
	else:
		print("QUESTS EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## new_game seeds castle board; force both sections empty.
	World.active.clear()
	GameState.quests.clear()

	var page: Control = load("res://scenes/hub/quests.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame

	var err := _audit(page)
	page.queue_free()
	return err


func _audit(page: Control) -> String:
	var err := _audit_list(page)
	if err != "":
		return err
	err = _audit_active(page)
	if err != "":
		return err
	err = _audit_board(page)
	if err != "":
		return err
	print("quests-empty ok ToAtlas+ToHourglass under_QuestList=1")
	return ""


func _audit_list(page: Control) -> String:
	var list := page.find_child("QuestList", true, false)
	if list == null:
		return "QuestList missing"
	return ""


func _audit_active(page: Control) -> String:
	var list := page.find_child("QuestList", true, false)
	var host := page.find_child("EmptyHostActive", true, false)
	if host == null:
		return "EmptyHostActive missing"
	if not list.is_ancestor_of(host):
		return "EmptyHostActive not under QuestList"
	var title_zh := Locale.t("lb_quests_active_empty")
	if not _host_has_text(host, title_zh):
		return "active empty title missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing under EmptyHostActive"
	var cta: Button = host.find_child("ToAtlas", true, false) as Button
	if cta == null:
		return "ToAtlas missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToAtlas not usable"
	if not acts.is_ancestor_of(cta):
		return "ToAtlas not under EmptyActions"
	var want := Locale.t("lb_quests_to_atlas")
	if cta.text != want:
		return "ToAtlas text want=%s got=%s" % [want, cta.text]
	cta.pressed.emit()
	return ""


func _audit_board(page: Control) -> String:
	var list := page.find_child("QuestList", true, false)
	var host := page.find_child("EmptyHostBoard", true, false)
	if host == null:
		return "EmptyHostBoard missing"
	if not list.is_ancestor_of(host):
		return "EmptyHostBoard not under QuestList"
	var title_zh := Locale.t("lb_quests_board_empty")
	if not _host_has_text(host, title_zh):
		return "board empty title missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing under EmptyHostBoard"
	var cta: Button = host.find_child("ToHourglass", true, false) as Button
	if cta == null:
		return "ToHourglass missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToHourglass not usable"
	if not acts.is_ancestor_of(cta):
		return "ToHourglass not under EmptyActions"
	var want := Locale.t("lb_quests_to_hourglass")
	if cta.text != want:
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	cta.pressed.emit()
	return ""


func _host_has_text(host: Node, needle: String) -> bool:
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(needle) >= 0:
			return true
	return false
