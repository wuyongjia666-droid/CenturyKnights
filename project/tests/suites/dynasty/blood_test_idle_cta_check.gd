extends Node
## Y1-B: blood_test idle reveal pane (all verified) exposes EmptyHost + how
## + named ToMarriage under RevealCards (align queue #369 CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL blood idle cta: ", err)
		get_tree().quit(1)
	else:
		print("BLOOD IDLE CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Force idle_done path (same filter as blood_test._queue).
	for ch in GameState.characters.values():
		if typeof(ch.blood_meta) != TYPE_DICTIONARY:
			ch.blood_meta = {}
		ch.blood_meta["verified"] = true

	var page: Control = load("res://scenes/hub/blood_test.tscn").instantiate()
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
	var stage := page.find_child("RevealCards", true, false)
	if stage == null:
		return "RevealCards missing"
	var host := stage.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under RevealCards"
	var title_zh := Locale.t("lb_bt_result")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_zh) >= 0:
			found = true
			break
	if not found:
		return "idle empty box (lb_bt_result) missing"
	var how_zh := Locale.t("lb_bt_idle_done_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "idle how (lb_bt_idle_done_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToMarriage", true, false) as Button
	if cta == null:
		return "ToMarriage missing under EmptyHost"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToMarriage not usable"
	if not acts.is_ancestor_of(cta):
		return "ToMarriage not under EmptyActions"
	var want := Locale.t("lb_bt_to_marriage")
	if cta.text != want:
		return "ToMarriage text want=%s got=%s" % [want, cta.text]
	print("blood-idle ok ToMarriage under_RevealCards_EmptyHost=1")
	return ""
