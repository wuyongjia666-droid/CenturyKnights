extends Node
## Y1-B: tavern empty bar exposes EmptyHost + named ToRoster under TavernCards
## (heir #30 / roster empty CTA pattern; refresh stays on page chrome).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL tavern empty cta: ", err)
		get_tree().quit(1)
	else:
		print("TAVERN EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## new_game fills tavern; force empty bar.
	GameState.tavern_candidates.clear()

	var page: Control = load("res://scenes/hub/tavern.tscn").instantiate()
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
	print("tavern-empty ok ToRoster under_EmptyHost=1")
	return ""


func _audit_host(page: Control) -> String:
	var cards := page.find_child("TavernCards", true, false)
	if cards == null:
		return "TavernCards missing"
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not cards.is_ancestor_of(host):
		return "EmptyHost not under TavernCards"
	var none_zh := Locale.t("lb_tavern_empty")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found = true
			break
	if not found:
		return "empty box (lb_tavern_empty) missing"
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
	var cta: Button = page.find_child("ToRoster", true, false) as Button
	if cta == null:
		return "ToRoster missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToRoster not usable"
	if not acts.is_ancestor_of(cta):
		return "ToRoster not under EmptyActions"
	var want := Locale.t("lb_tavern_to_roster")
	if cta.text != want:
		return "ToRoster text want=%s got=%s" % [want, cta.text]
	cta.pressed.emit()
	return ""
