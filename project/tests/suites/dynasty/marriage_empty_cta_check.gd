extends Node
## Y1-B: marriage empty posts expose EmptyHost + named ToTavern / ToRoster
## under CandidateTabs (heir #30 / train empty CTA pattern).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL marriage empty cta: ", err)
		get_tree().quit(1)
	else:
		print("MARRIAGE EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false

	var page: Control = load("res://scenes/hub/marriage.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame

	## Force empty after ensure_posts (ready already drew candidates).
	GameState.marriage_candidates.clear()
	if page.has_method("_refresh"):
		page.call("_refresh")
	for _i in 6:
		await get_tree().process_frame

	var err := _audit(page)
	page.queue_free()
	return err


func _audit(page: Control) -> String:
	var err := _audit_host(page)
	if err != "":
		return err
	err = _audit_ctas(page)
	if err != "":
		return err
	print("marriage-empty ok ToTavern+ToRoster under_EmptyHost=1")
	return ""


func _audit_host(page: Control) -> String:
	var tabs := page.find_child("CandidateTabs", true, false)
	if tabs == null:
		return "CandidateTabs missing"
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not tabs.is_ancestor_of(host):
		return "EmptyHost not under CandidateTabs"
	var titles := [
		Locale.t("lb_marriage_empty"),
		Locale.t("ux_empty_hero_fixed"),
		Locale.t("ux_empty_hero_no_reroll"),
	]
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		for t in titles:
			if tx.find(str(t)) >= 0:
				found_empty = true
				break
		if found_empty:
			break
	if not found_empty:
		return "empty title label missing"
	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	if not host.is_ancestor_of(acts):
		return "EmptyActions not under EmptyHost"
	return ""


func _audit_ctas(page: Control) -> String:
	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var pairs := [
		["ToTavern", "lb_marriage_to_tavern"],
		["ToRoster", "lb_marriage_to_roster"],
	]
	for pair in pairs:
		var cta: Button = page.find_child(str(pair[0]), true, false) as Button
		if cta == null:
			return "%s missing" % pair[0]
		if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
			return "%s not usable" % pair[0]
		if not acts.is_ancestor_of(cta):
			return "%s not under EmptyActions" % pair[0]
		var want := Locale.t(str(pair[1]))
		if cta.text != want:
			return "%s text want=%s got=%s" % [pair[0], want, cta.text]
		cta.pressed.emit()
	return ""
