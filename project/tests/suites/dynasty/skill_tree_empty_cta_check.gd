extends Node
## Y1-B: skill_tree empty roster → EmptyHost + how + ToTavern under People.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL skill empty cta: ", err)
		get_tree().quit(1)
	else:
		print("SKILL EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	for ch in GameState.characters.values():
		ch.in_roster = false

	var page: Control = load("res://scenes/hub/skill_tree.tscn").instantiate()
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
	var people := page.find_child("People", true, false)
	if people == null:
		return "People list missing"
	var host := people.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under People"
	var none_zh := Locale.t("lb_sk_nobody")
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_sk_nobody) missing"
	var how_zh := Locale.t("lb_sk_nobody_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (lb_sk_nobody_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToTavern", true, false) as Button
	if cta == null:
		return "ToTavern missing under EmptyHost"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToTavern not usable"
	if not acts.is_ancestor_of(cta):
		return "ToTavern not under EmptyActions"
	var want := Locale.t("lb_sk_to_tavern")
	if cta.text != want:
		return "ToTavern text want=%s got=%s" % [want, cta.text]
	print("skill-empty ok ToTavern how=1 under_EmptyHost=1")
	return ""
