extends Node
## Y1-B: sui_yearcard empty inbox exposes named ToHourglass under SuiRows
## (empty box already has why-text; this knife adds the tap CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL sui empty cta: ", err)
		get_tree().quit(1)
	else:
		print("SUI EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## new_game inbox is empty (no unread year-cards yet).

	var page: Control = load("res://scenes/hub/sui_yearcard.tscn").instantiate()
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
	var rows := page.find_child("SuiRows", true, false)
	if rows == null:
		return "SuiRows missing"
	var none_zh := Locale.t("sui_year_empty")
	var found_empty := false
	for n in rows.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (sui_year_empty) missing"

	var cta: Button = page.find_child("ToHourglass", true, false) as Button
	if cta == null:
		return "ToHourglass missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToHourglass not visible"
	if cta.disabled:
		return "ToHourglass disabled"
	var want := Locale.t("lb_sui_to_hourglass")
	if cta.text != want:
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	if not rows.is_ancestor_of(cta):
		return "ToHourglass not under SuiRows"
	cta.pressed.emit()
	print("sui-empty ok ToHourglass under_rows=1")
	return ""
