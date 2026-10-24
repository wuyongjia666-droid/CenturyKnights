extends Node
## Y1-B: skill_tree no-skills-for-job → EmptyHost + how + ToTitlePromote under Columns.

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
	var host := cols.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under Columns"
	var none_zh := Locale.t("lb_sk_no_tree")
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_sk_no_tree) missing"
	var how_zh := Locale.t("lb_sk_no_tree_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (lb_sk_no_tree_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToTitlePromote", true, false) as Button
	if cta == null:
		return "ToTitlePromote missing under EmptyHost"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToTitlePromote not usable"
	if not acts.is_ancestor_of(cta):
		return "ToTitlePromote not under EmptyActions"
	var want := Locale.t("lb_sk_to_title_promote")
	if cta.text != want:
		return "ToTitlePromote text want=%s got=%s" % [want, cta.text]
	print("skill-notree ok ToTitlePromote how=1 under_EmptyHost=1")
	return ""
