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
	var answers := page.find_child("Answers", true, false)
	var to_heir: Button = page.find_child("ToHeirRivalry", true, false) as Button
	var to_rivals: Button = page.find_child("ToRivals", true, false) as Button
	var zh := str(GameState.house_mods.get("inherit_answer_zh", ""))
	var err := ""
	if body == null:
		err = "InheritText missing"
	elif body.text.find(zh) < 0:
		err = "InheritText missing done zh (%s)" % zh
	elif answers == null:
		err = "Answers missing"
	elif to_heir == null:
		err = "ToHeirRivalry missing"
	elif not to_heir.visible or not to_heir.is_visible_in_tree() or to_heir.disabled:
		err = "ToHeirRivalry not usable"
	elif not answers.is_ancestor_of(to_heir):
		err = "ToHeirRivalry not under Answers"
	elif to_heir.text != Locale.t("lb_inh_to_heir"):
		err = "ToHeirRivalry text want=%s got=%s" % [Locale.t("lb_inh_to_heir"), to_heir.text]
	elif to_rivals == null:
		err = "ToRivals missing"
	elif not to_rivals.visible or not to_rivals.is_visible_in_tree() or to_rivals.disabled:
		err = "ToRivals not usable"
	elif not answers.is_ancestor_of(to_rivals):
		err = "ToRivals not under Answers"
	elif to_rivals.text != Locale.t("lb_inh_to_rivals"):
		err = "ToRivals text want=%s got=%s" % [Locale.t("lb_inh_to_rivals"), to_rivals.text]
	else:
		for k in ["steel", "soft", "delay"]:
			if page.find_child("Answer_" + k, true, false) != null:
				err = "Answer_%s present in done year" % k
				break
			if page.find_child("Pick_" + k, true, false) != null:
				err = "Pick_%s present in done year" % k
				break
	if err == "":
		print("inherit-done ok ToHeirRivalry+ToRivals under_Answers=1")
	return err
