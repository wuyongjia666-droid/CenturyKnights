extends Node
## Y1-B: support_viewer empty unlocked bonds exposes EmptyHost + named ToRoster
## under BondList (heir #30). Does not emit CTA (CKNav.go swaps page).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL support empty cta: ", err)
		get_tree().quit(1)
	else:
		print("SUPPORT EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Fresh run: Bonds.available() empty (no adjacent ranks yet).

	var page: Control = load("res://scenes/story/support_viewer.tscn").instantiate()
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
	var list := page.find_child("BondList", true, false)
	if list == null:
		return "BondList missing"
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	if not list.is_ancestor_of(host):
		return "EmptyHost not under BondList"
	var title_zh := Locale.t("nar04_empty")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_zh) >= 0:
			found = true
			break
	if not found:
		return "empty box (nar04_empty) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToRoster", true, false) as Button
	if cta == null:
		return "ToRoster missing"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToRoster not usable"
	if not acts.is_ancestor_of(cta):
		return "ToRoster not under EmptyActions"
	var want := Locale.t("nar04_to_roster")
	if cta.text != want:
		return "ToRoster text want=%s got=%s" % [want, cta.text]
	print("support-empty ok ToRoster under_EmptyHost=1")
	return ""
