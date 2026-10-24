extends Node
## Y1-B: ancestors empty stele exposes named ToHourglass under SteleList
## (empty box already has why/how; this knife adds the tap CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL ancestors empty cta: ", err)
		get_tree().quit(1)
	else:
		print("ANCESTORS EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Ensure no dead family (empty stele path).
	for ch in GameState.characters.values():
		ch.alive = true

	var page: Control = load("res://scenes/hub/ancestors.tscn").instantiate()
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
	var stele := page.find_child("SteleList", true, false)
	if stele == null:
		return "SteleList missing"
	var none_zh := Locale.t("ancestor_empty")
	var found_empty := false
	for n in stele.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (ancestor_empty) missing"

	var cta: Button = page.find_child("ToHourglass", true, false) as Button
	if cta == null:
		return "ToHourglass missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToHourglass not visible"
	if cta.disabled:
		return "ToHourglass disabled"
	var want := Locale.t("lb_anc_to_hourglass")
	if cta.text != want:
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	if not stele.is_ancestor_of(cta):
		return "ToHourglass not under SteleList"
	cta.pressed.emit()
	print("ancestors-empty ok ToHourglass under_stele=1")
	return ""
