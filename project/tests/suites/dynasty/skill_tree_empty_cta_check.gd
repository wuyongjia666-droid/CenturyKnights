extends Node
## Y1-B: skill_tree empty roster exposes named ToTavern under People
## (empty box already has why-text; this knife adds the tap CTA).

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
	## Force empty roster path.
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
	var none_zh := Locale.t("lb_sk_nobody")
	var found_empty := false
	for n in people.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_sk_nobody) missing"

	var cta: Button = page.find_child("ToTavern", true, false) as Button
	if cta == null:
		return "ToTavern missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToTavern not visible"
	if cta.disabled:
		return "ToTavern disabled"
	var want := Locale.t("lb_sk_to_tavern")
	if cta.text != want:
		return "ToTavern text want=%s got=%s" % [want, cta.text]
	if not people.is_ancestor_of(cta):
		return "ToTavern not under People"
	cta.pressed.emit()
	print("skill-empty ok ToTavern under_people=1")
	return ""
