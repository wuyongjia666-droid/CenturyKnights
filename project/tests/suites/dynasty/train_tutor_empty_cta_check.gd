extends Node
## Y1-B: train (旗塾) no-eligible-tutor exposes named ToTavern under DynTutors
## (empty box already has why-text; this knife adds the tap CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL train tutor empty cta: ", err)
		get_tree().quit(1)
	else:
		print("TRAIN TUTOR EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Need a pupil selected, but zero eligible tutors.
	var pupils: Array = []
	for ch in GameState.characters.values():
		if CKTutor.can_be_pupil(ch):
			pupils.append(ch)
	if pupils.is_empty():
		## Seed one eligible child if new_game has none.
		var kid: CKCharacter = GameState.characters.values()[0]
		for ch in GameState.characters.values():
			kid = ch
			break
		kid.alive = true
		kid.in_roster = false
		kid.is_child = true
		kid.age = 8
		kid.injured = false
		pupils.append(kid)
	for ch in GameState.roster():
		ch.injured = true

	var page: Control = load("res://scenes/hub/train.tscn").instantiate()
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
	var tutors := page.find_child("DynTutors", true, false)
	if tutors == null:
		return "DynTutors missing"
	var none_zh := Locale.t("lb_train_no_tutor_title")
	var found_empty := false
	for n in tutors.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_train_no_tutor_title) missing"

	var cta: Button = page.find_child("ToTavern", true, false) as Button
	if cta == null:
		return "ToTavern missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToTavern not visible"
	if cta.disabled:
		return "ToTavern disabled"
	var want := Locale.t("lb_train_to_tavern")
	if cta.text != want:
		return "ToTavern text want=%s got=%s" % [want, cta.text]
	if not tutors.is_ancestor_of(cta):
		return "ToTavern not under DynTutors"
	cta.pressed.emit()
	print("train-tutor-empty ok ToTavern under_tutors=1")
	return ""
