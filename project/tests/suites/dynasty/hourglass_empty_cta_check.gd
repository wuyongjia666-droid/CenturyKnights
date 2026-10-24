extends Node
## Y1-B: hourglass empty result log (no month echo) exposes EmptyHost + how
## + named ToCourtNews under Result (advance stays on-page).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL hourglass empty cta: ", err)
		get_tree().quit(1)
	else:
		print("HOURGLASS EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Fresh run: no month echo → empty Result path.

	var page: Control = load("res://scenes/hub/hourglass.tscn").instantiate()
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
	var log := page.find_child("Result", true, false)
	if log == null:
		return "Result list missing"
	var host := log.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under Result"
	var title_zh := Locale.t("lb_hg_empty")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_zh) >= 0:
			found = true
			break
	if not found:
		return "empty box (lb_hg_empty) missing"
	var how_zh := Locale.t("lb_hg_empty_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (lb_hg_empty_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToCourtNews", true, false) as Button
	if cta == null:
		return "ToCourtNews missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToCourtNews not usable"
	if not acts.is_ancestor_of(cta):
		return "ToCourtNews not under EmptyActions"
	var want := Locale.t("lb_hg_to_court_news")
	if cta.text != want:
		return "ToCourtNews text want=%s got=%s" % [want, cta.text]
	## Advance stays on-page for the primary empty nudge.
	var adv := page.find_child("AdvanceMonth", true, false) as BaseButton
	if adv == null or not adv.visible:
		return "AdvanceMonth missing on page"
	print("hourglass-empty ok ToCourtNews under_Result_EmptyHost=1")
	return ""
