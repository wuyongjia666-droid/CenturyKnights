extends Node
## Y1-B: sui_yearcard empty inbox exposes EmptyHost + how + named ToHourglass
## under SuiRows (how knife on top of #374 CTA).

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
	var host := rows.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under SuiRows"
	var none_zh := Locale.t("sui_year_empty")
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (sui_year_empty) missing"
	var how_zh := Locale.t("sui_year_empty_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (sui_year_empty_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToHourglass", true, false) as Button
	if cta == null:
		return "ToHourglass missing under EmptyHost"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToHourglass not visible"
	if cta.disabled:
		return "ToHourglass disabled"
	var want := Locale.t("lb_sui_to_hourglass")
	if cta.text != want:
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	if not acts.is_ancestor_of(cta):
		return "ToHourglass not under EmptyActions"
	print("sui-empty ok ToHourglass how=1 under_EmptyHost=1")
	return ""
