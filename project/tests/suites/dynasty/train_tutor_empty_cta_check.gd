extends Node
## Y1-B: train no-eligible-tutor → EmptyHost + how + ToTavern under DynTutors.

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
	var pupils: Array = []
	for ch in GameState.characters.values():
		if CKTutor.can_be_pupil(ch):
			pupils.append(ch)
	if pupils.is_empty():
		var kid: CKCharacter = null
		for ch in GameState.characters.values():
			kid = ch
			break
		if kid == null:
			return "no characters"
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
	var host := tutors.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under DynTutors"
	var none_zh := Locale.t("lb_train_no_tutor_title")
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_train_no_tutor_title) missing"
	var how_zh := Locale.t("lb_train_no_tutor_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (lb_train_no_tutor_how) missing"
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
	var want := Locale.t("lb_train_to_tavern")
	if cta.text != want:
		return "ToTavern text want=%s got=%s" % [want, cta.text]
	print("train-tutor-empty ok ToTavern how=1 under_EmptyHost=1")
	return ""
