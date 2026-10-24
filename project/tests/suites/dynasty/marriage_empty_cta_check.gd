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
	var tabs := page.find_child("CandidateTabs", true, false)
	if tabs == null:
		return "CandidateTabs missing"

	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not tabs.is_ancestor_of(host):
		return "EmptyHost not under CandidateTabs"

	var none_zh := Locale.t("lb_marriage_empty")
	var found_empty := false
	for n in host.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		if tx.find(none_zh) >= 0 or tx.find(Locale.t("ux_empty_hero_fixed")) >= 0 or tx.find(Locale.t("ux_empty_hero_no_reroll")) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty title label missing"

	var to_t: Button = page.find_child("ToTavern", true, false) as Button
	if to_t == null:
		return "ToTavern missing"
	if not to_t.visible or not to_t.is_visible_in_tree():
		return "ToTavern not visible"
	if to_t.disabled:
		return "ToTavern disabled"
	var want_t := Locale.t("lb_marriage_to_tavern")
	if to_t.text != want_t:
		return "ToTavern text want=%s got=%s" % [want_t, to_t.text]
	if not host.is_ancestor_of(to_t):
		return "ToTavern not under EmptyHost"

	var to_r: Button = page.find_child("ToRoster", true, false) as Button
	if to_r == null:
		return "ToRoster missing"
	if not to_r.visible or not to_r.is_visible_in_tree():
		return "ToRoster not visible"
	if to_r.disabled:
		return "ToRoster disabled"
	var want_r := Locale.t("lb_marriage_to_roster")
	if to_r.text != want_r:
		return "ToRoster text want=%s got=%s" % [want_r, to_r.text]
	if not host.is_ancestor_of(to_r):
		return "ToRoster not under EmptyHost"

	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	if not acts.is_ancestor_of(to_t) or not acts.is_ancestor_of(to_r):
		return "CTAs not under EmptyActions"

	to_t.pressed.emit()
	to_r.pressed.emit()
	print("marriage-empty ok ToTavern+ToRoster under_EmptyHost=1")
	return ""
