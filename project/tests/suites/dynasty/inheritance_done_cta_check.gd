extends Node
## Y1-B / audit #29↔#30: inheritance done-year exposes ToHeirRivalry (+ ToRivals)
## so the succession clash pairs back to heir trials.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL inherit done cta: ", err)
		get_tree().quit(1)
	else:
		print("INHERIT DONE CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Skip ambition offer so done-year path is the body.
	GameState.house_mods["dyn_amb"] = "skip_offer"
	GameState.house_mods["inherit_answer_year"] = Calendar.year
	GameState.house_mods["inherit_answer_zh"] = Locale.t("lb_inh_steel")

	var page: Control = load("res://scenes/hub/inheritance.tscn").instantiate()
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
	var body: Label = page.find_child("InheritText", true, false) as Label
	if body == null:
		return "InheritText missing"
	var zh := str(GameState.house_mods.get("inherit_answer_zh", ""))
	if body.text.find(zh) < 0:
		return "InheritText missing done zh (%s)" % zh

	var answers := page.find_child("Answers", true, false)
	if answers == null:
		return "Answers missing"

	var to_heir: Button = page.find_child("ToHeirRivalry", true, false) as Button
	if to_heir == null:
		return "ToHeirRivalry missing"
	if not to_heir.visible or not to_heir.is_visible_in_tree() or to_heir.disabled:
		return "ToHeirRivalry not usable"
	if not answers.is_ancestor_of(to_heir):
		return "ToHeirRivalry not under Answers"
	var want_heir := Locale.t("lb_inh_to_heir")
	if to_heir.text != want_heir:
		return "ToHeirRivalry text want=%s got=%s" % [want_heir, to_heir.text]

	var to_rivals: Button = page.find_child("ToRivals", true, false) as Button
	if to_rivals == null:
		return "ToRivals missing"
	if not to_rivals.visible or not to_rivals.is_visible_in_tree() or to_rivals.disabled:
		return "ToRivals not usable"
	if not answers.is_ancestor_of(to_rivals):
		return "ToRivals not under Answers"
	var want_r := Locale.t("lb_inh_to_rivals")
	if to_rivals.text != want_r:
		return "ToRivals text want=%s got=%s" % [want_r, to_rivals.text]

	## Open-year answer cards must stay off in done year.
	for k in ["steel", "soft", "delay"]:
		if page.find_child("Answer_" + k, true, false) != null:
			return "Answer_%s present in done year" % k
		if page.find_child("Pick_" + k, true, false) != null:
			return "Pick_%s present in done year" % k

	print("inherit-done ok ToHeirRivalry+ToRivals under_Answers=1")
	return ""
