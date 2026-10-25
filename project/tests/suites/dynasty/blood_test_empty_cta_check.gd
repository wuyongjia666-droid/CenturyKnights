extends Node
## Y1-B: blood_test all-verified queue → EmptyHost + how + ToMarriage under QueueList.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL blood empty cta: ", err)
		get_tree().quit(1)
	else:
		print("BLOOD EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Force all-done queue path (same filter as blood_test._queue).
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
	var queue := page.find_child("QueueList", true, false)
	if queue == null:
		return "QueueList missing"
	var host := queue.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under QueueList"
	var done_zh := Locale.t("lb_bt_all_done")
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(done_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_bt_all_done) missing"
	var how_zh := Locale.t("lb_bt_all_done_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (lb_bt_all_done_how) missing"
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
	print("blood-empty ok ToMarriage how=1 under_EmptyHost=1")
	return ""
