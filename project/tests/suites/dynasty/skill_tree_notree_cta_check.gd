extends Node
## Y1-B: skill_tree no-skills-for-job exposes named ToTitlePromote under Columns
## (empty box already has why-text; this knife adds the tap CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL skill notree cta: ", err)
		get_tree().quit(1)
	else:
		print("SKILL NOTREE CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Keep roster, force selected job with no skill trees.
	var roster: Array = GameState.roster()
	if roster.is_empty():
		return "roster empty after new_game"
	for ch in roster:
		ch.job_id = "no_such_job"

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
	var cols := page.find_child("Columns", true, false)
	if cols == null:
		return "Columns missing"
	var none_zh := Locale.t("lb_sk_no_tree")
	var found_empty := false
	for n in cols.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_sk_no_tree) missing"

	var cta: Button = page.find_child("ToTitlePromote", true, false) as Button
	if cta == null:
		return "ToTitlePromote missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToTitlePromote not visible"
	if cta.disabled:
		return "ToTitlePromote disabled"
	var want := Locale.t("lb_sk_to_title_promote")
	if cta.text != want:
		return "ToTitlePromote text want=%s got=%s" % [want, cta.text]
	if not cols.is_ancestor_of(cta):
		return "ToTitlePromote not under Columns"
	cta.pressed.emit()
	print("skill-notree ok ToTitlePromote under_cols=1")
	return ""
