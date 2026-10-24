extends Node
## Y1-B stub: transfer_banner no-heir → house_mods.dynasty_end;
## hourglass / estates / castle_hub show DynastyEndPanel + named ToTitle.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL dynasty end stub: ", err)
		get_tree().quit(1)
	else:
		print("DYNASTY END STUB PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("dynasty_end")

	var err := _audit_stamp()
	if err != "":
		return err
	err = await _audit_page("res://scenes/hub/hourglass.tscn", true)
	if err != "":
		return err
	err = await _audit_page("res://scenes/hub/estates.tscn", false)
	if err != "":
		return err
	err = await _audit_page("res://scenes/hub/castle_hub.tscn", false)
	if err != "":
		return err
	return ""


func _audit_stamp() -> String:
	## Wipe every non-leader so pick_heir / roster / minor all miss.
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader after new_game"
	for c in GameState.characters.values():
		if c == null or c == leader:
			continue
		c.alive = false
		c.in_roster = false
		c.is_child = false
		c.retired = true
	leader.alive = false
	leader.in_roster = false
	var handed: Dictionary = Lineage.transfer_banner("death")
	if bool(handed.get("ok", false)):
		return "expected succession fail, got ok heir=%s" % str(handed.get("heir", ""))
	if not Lineage.is_dynasty_ended():
		return "dynasty_end not stamped: %s" % str(GameState.house_mods.get("dynasty_end", {}))
	var snap: Dictionary = Lineage.dynasty_end_snapshot()
	if str(snap.get("reason", "")) != "no_heir":
		return "reason want=no_heir got=%s" % str(snap.get("reason", ""))
	var want := Locale.t("lineage_no_heir")
	if str(snap.get("msg", "")) != want and str(handed.get("msg", "")) != want:
		return "msg want=%s snap=%s handed=%s" % [want, snap.get("msg", ""), handed.get("msg", "")]
	if not bool(handed.get("dynasty_end", false)):
		return "handed missing dynasty_end flag"
	## Idempotent: second stamp keeps first reason.
	Lineage.note_dynasty_end("no_leader", "x")
	if str(Lineage.dynasty_end_snapshot().get("reason", "")) != "no_heir":
		return "idempotent stamp broken"
	print("dynasty-end stamp ok reason=no_heir msg=%s" % want)
	return ""


func _audit_page(path: String, check_advance: bool) -> String:
	var page: Control = load(path).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	var panel := page.find_child("DynastyEndPanel", true, false)
	if panel == null:
		page.queue_free()
		return "%s DynastyEndPanel missing" % path
	var cta: Button = page.find_child("ToTitle", true, false) as Button
	if cta == null:
		page.queue_free()
		return "%s ToTitle missing" % path
	if not cta.visible or not cta.is_visible_in_tree():
		page.queue_free()
		return "%s ToTitle not visible" % path
	if cta.disabled:
		page.queue_free()
		return "%s ToTitle disabled" % path
	var want := Locale.t("lb_dynasty_end_to_title")
	if cta.text != want:
		page.queue_free()
		return "%s ToTitle text want=%s got=%s" % [path, want, cta.text]
	if not panel.is_ancestor_of(cta):
		page.queue_free()
		return "%s ToTitle not under DynastyEndPanel" % path
	var title_bit := Locale.t("lb_dynasty_end_title")
	var hit := false
	for n in panel.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_bit) >= 0:
			hit = true
			break
	if not hit:
		page.queue_free()
		return "%s title text missing bit=%s" % [path, title_bit]
	if check_advance:
		var m1 := page.find_child("AdvanceMonth", true, false) as BaseButton
		var m3 := page.find_child("AdvanceSeason", true, false) as BaseButton
		if m1 == null or not m1.disabled:
			page.queue_free()
			return "AdvanceMonth should be disabled when dynasty ended"
		if m3 == null or not m3.disabled:
			page.queue_free()
			return "AdvanceSeason should be disabled when dynasty ended"
	## Do not emit ToTitle: CKNav.replace(TITLE) tears down the tree mid-suite.
	print("dynasty-end feel ok path=%s ToTitle=1" % path.get_file())
	page.queue_free()
	await get_tree().process_frame
	return ""
