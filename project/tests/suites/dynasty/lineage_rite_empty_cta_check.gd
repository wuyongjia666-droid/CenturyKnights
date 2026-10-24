extends Node
## Y1-B: lineage_rite empty kids list exposes named ToMarriage under RiteActions
## (empty box already has how-text; this knife adds the tap CTA, heir #30 pattern).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL rite empty cta: ", err)
		get_tree().quit(1)
	else:
		print("RITE EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Guarantee empty kids list (alive is_child only).
	for ch in GameState.characters.values():
		if ch.is_child:
			ch.alive = false

	var page: Control = load("res://scenes/hub/lineage_rite.tscn").instantiate()
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
	var kids := page.find_child("Kids", true, false)
	if kids == null:
		return "Kids list missing"
	## Empty box present (title from lb_rite_none).
	var none_zh := Locale.t("lb_rite_none")
	var found_empty := false
	for n in kids.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_rite_none) missing"

	var cta: Button = page.find_child("ToMarriage", true, false) as Button
	if cta == null:
		return "ToMarriage missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToMarriage not visible"
	if cta.disabled:
		return "ToMarriage disabled"
	var want := Locale.t("lb_rite_to_marriage")
	if cta.text != want:
		return "ToMarriage text want=%s got=%s" % [want, cta.text]
	var actions := page.find_child("RiteActions", true, false) as Node
	if actions == null:
		return "RiteActions missing"
	if not actions.is_ancestor_of(cta):
		return "ToMarriage not under RiteActions"
	## Smoke: press does not error (nav may no-op in headless).
	cta.pressed.emit()
	print("rite-empty ok ToMarriage under_actions=1")
	return ""
