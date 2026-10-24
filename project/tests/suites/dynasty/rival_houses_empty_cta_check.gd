extends Node
## Y1-B: rival_houses empty list exposes EmptyHost + named ToCourtNews under Houses
## (heir #30; schemes live on the court gazette). Does not emit CTA (CKNav.go swaps page).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL rival houses empty cta: ", err)
		get_tree().quit(1)
	else:
		print("RIVAL HOUSES EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## JSON normally seeds houses; force empty list.
	GameState.data_rivals = {"houses": []}

	var page: Control = load("res://scenes/hub/rival_houses.tscn").instantiate()
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
	var houses := page.find_child("Houses", true, false)
	if houses == null:
		return "Houses missing"
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not houses.is_ancestor_of(host):
		return "EmptyHost not under Houses"
	var title_zh := Locale.t("lb_rv_none")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_zh) >= 0:
			found = true
			break
	if not found:
		return "empty box (lb_rv_none) missing"
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
	var want := Locale.t("lb_rv_to_court_news")
	if cta.text != want:
		return "ToCourtNews text want=%s got=%s" % [want, cta.text]
	print("rival-houses-empty ok ToCourtNews under_EmptyHost=1")
	return ""
