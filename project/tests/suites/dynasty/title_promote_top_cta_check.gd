extends Node
## Y1-B: title_promote top-of-ladder empty exposes EmptyHost + named ToCity
## under ReqGrid (heir #30 / roster empty CTA pattern; 职印 → city).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL title top cta: ", err)
		get_tree().quit(1)
	else:
		print("TITLE TOP CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	var lead: CKCharacter = GameState.get_leader()
	if lead == null:
		return "no leader"
	## Force top of CKCourt.LADDER so requirement_rows is empty.
	lead.rank = "duke"
	if typeof(lead.blood_meta) != TYPE_DICTIONARY:
		lead.blood_meta = {}
	lead.blood_meta["title"] = "duke"

	var page: Control = load("res://scenes/hub/title_promote.tscn").instantiate()
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
	var err := _audit_host(page)
	if err != "":
		return err
	err = _audit_cta(page)
	if err != "":
		return err
	print("title-top ok ToCity under_EmptyHost=1")
	return ""


func _audit_host(page: Control) -> String:
	var grid := page.find_child("ReqGrid", true, false)
	if grid == null:
		return "ReqGrid missing"
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not grid.is_ancestor_of(host):
		return "EmptyHost not under ReqGrid"
	var none_zh := Locale.t("lb_title_top")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found = true
			break
	if not found:
		return "empty box (lb_title_top) missing"
	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	if not host.is_ancestor_of(acts):
		return "EmptyActions not under EmptyHost"
	return ""


func _audit_cta(page: Control) -> String:
	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = page.find_child("ToCity", true, false) as Button
	if cta == null:
		return "ToCity missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToCity not usable"
	if not acts.is_ancestor_of(cta):
		return "ToCity not under EmptyActions"
	var want := Locale.t("lb_title_to_city")
	if cta.text != want:
		return "ToCity text want=%s got=%s" % [want, cta.text]
	cta.pressed.emit()
	return ""
