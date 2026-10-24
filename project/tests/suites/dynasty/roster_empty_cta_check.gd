extends Node
## Y1-B: roster empty cadre exposes EmptyHost + named ToTavern under RosterList
## (heir #30 / marriage empty CTA pattern).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL roster empty cta: ", err)
		get_tree().quit(1)
	else:
		print("ROSTER EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Guarantee empty roster() (alive + in_roster + not retired).
	for ch in GameState.characters.values():
		ch.in_roster = false

	var page: Control = load("res://scenes/hub/roster.tscn").instantiate()
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
	print("roster-empty ok ToTavern under_EmptyHost=1")
	return ""


func _audit_host(page: Control) -> String:
	var list := page.find_child("RosterList", true, false)
	if list == null:
		return "RosterList missing"
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not list.is_ancestor_of(host):
		return "EmptyHost not under RosterList"
	var none_zh := Locale.t("lb_roster_empty")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found = true
			break
	if not found:
		return "empty box (lb_roster_empty) missing"
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
	var cta: Button = page.find_child("ToTavern", true, false) as Button
	if cta == null:
		return "ToTavern missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToTavern not usable"
	if not acts.is_ancestor_of(cta):
		return "ToTavern not under EmptyActions"
	var want := Locale.t("lb_roster_to_tavern")
	if cta.text != want:
		return "ToTavern text want=%s got=%s" % [want, cta.text]
	cta.pressed.emit()
	return ""
