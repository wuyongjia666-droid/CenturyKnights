extends Node
## Y1-B: blood_test all-verified queue exposes named ToMarriage under QueueList
## (empty box already has why-text; this knife adds the tap CTA).

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
	var done_zh := Locale.t("lb_bt_all_done")
	var found_empty := false
	for n in queue.find_children("*", "Label", true, false):
		if str((n as Label).text).find(done_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_bt_all_done) missing"

	var cta: Button = page.find_child("ToMarriage", true, false) as Button
	if cta == null:
		return "ToMarriage missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToMarriage not visible"
	if cta.disabled:
		return "ToMarriage disabled"
	var want := Locale.t("lb_bt_to_marriage")
	if cta.text != want:
		return "ToMarriage text want=%s got=%s" % [want, cta.text]
	if not queue.is_ancestor_of(cta):
		return "ToMarriage not under QueueList"
	cta.pressed.emit()
	print("blood-empty ok ToMarriage under_queue=1")
	return ""
