extends Node
## Y1-B: battle wipe / no living heirable roster → house_mods.dynasty_end
## reason=wipeout; hourglass reuses DynastyEndPanel + ToTitle.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL dynasty wipeout: ", err)
		get_tree().quit(1)
	else:
		print("DYNASTY WIPEOUT PASS")
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
	err = _audit_handoff_survives()
	if err != "":
		return err
	err = _audit_deferred_kill_settle()
	if err != "":
		return err
	return ""


func _wipe_all_living() -> void:
	for c in GameState.characters.values():
		if c == null:
			continue
		c.alive = false
		c.in_roster = false
		c.is_child = false
		c.retired = true


func _audit_stamp() -> String:
	## Simulate post-battle: every house member dead, banner not yet handed.
	## close_after_battle (not transfer_banner) stamps wipeout.
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader after new_game"
	_wipe_all_living()
	## Keep is_leader on the corpse so pick_heir still has an anchor.
	leader.is_leader = true
	var closed: Dictionary = Lineage.close_after_battle()
	if bool(closed.get("ok", false)):
		return "expected wipeout close, got ok leader=%s" % str(closed.get("leader", ""))
	if not Lineage.is_dynasty_ended():
		return "dynasty_end not stamped: %s" % str(GameState.house_mods.get("dynasty_end", {}))
	var snap: Dictionary = Lineage.dynasty_end_snapshot()
	if str(snap.get("reason", "")) != "wipeout":
		return "reason want=wipeout got=%s" % str(snap.get("reason", ""))
	var want := Locale.t("lineage_wipeout")
	if str(snap.get("msg", "")) != want and str(closed.get("msg", "")) != want:
		return "msg want=%s snap=%s closed=%s" % [want, snap.get("msg", ""), closed.get("msg", "")]
	if not bool(closed.get("dynasty_end", false)):
		return "closed missing dynasty_end flag"
	Lineage.close_after_battle()
	Lineage.note_dynasty_end("no_heir", "x")
	if str(Lineage.dynasty_end_snapshot().get("reason", "")) != "wipeout":
		return "idempotent stamp broken"
	print("dynasty-wipeout stamp ok reason=wipeout msg=%s" % want)
	return ""


func _audit_handoff_survives() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("dynasty_end")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "handoff: no leader"
	var heir: CKCharacter = null
	for c in GameState.characters.values():
		if c == null or c == leader:
			continue
		if c.alive and c.in_roster and int(c.age) >= Calendar.ADULT_AGE:
			heir = c
			break
	if heir == null:
		heir = CKCharacter.new()
		heir.id = "wipe_heir"
		heir.name = "候补"
		heir.alive = true
		heir.in_roster = true
		heir.retired = false
		heir.is_child = false
		heir.is_leader = false
		heir.age = Calendar.ADULT_AGE + 2
		heir.faction = "player"
		heir.stats = {"skl": 5, "str": 5, "end": 5, "ldr": 5}
		GameState.characters[heir.id] = heir
	leader.alive = false
	leader.in_roster = false
	leader.is_leader = true
	var closed: Dictionary = Lineage.close_after_battle()
	if not bool(closed.get("ok", false)):
		return "handoff: living roster should take banner, got %s" % str(closed)
	if Lineage.is_dynasty_ended():
		return "handoff: should not dynasty_end when heir lives"
	var now: CKCharacter = GameState.get_leader()
	if now == null or not now.alive:
		return "handoff: no living leader after close"
	if now.id == leader.id:
		return "handoff: corpse still captain"
	print("dynasty-wipeout handoff ok new_leader=%s" % now.id)
	return ""


func _audit_deferred_kill_settle() -> String:
	## Injury battle path: _kill(..., defer_banner=true) then close_after_battle.
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("dynasty_end")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var any := false
	for c in GameState.characters.values():
		if c == null or not c.alive:
			continue
		CKInjury._kill(c, rng, "suite", true)
		any = true
	if not any:
		return "deferred: nobody to kill"
	if Lineage.is_dynasty_ended():
		return "deferred: stamp must wait for close_after_battle"
	var closed: Dictionary = Lineage.close_after_battle()
	if not Lineage.is_dynasty_ended():
		return "deferred: close did not stamp: %s" % str(closed)
	if str(Lineage.dynasty_end_snapshot().get("reason", "")) != "wipeout":
		return "deferred: reason want=wipeout got=%s" % Lineage.dynasty_end_snapshot().get("reason", "")
	var battle := Node.new()
	battle.set_meta("_ck_downs", [])
	add_child(battle)
	CKInjury._settle(battle)
	battle.queue_free()
	if str(Lineage.dynasty_end_snapshot().get("reason", "")) != "wipeout":
		return "deferred: settle clobbered stamp"
	print("dynasty-wipeout deferred-kill ok")
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
	if not cta.visible or cta.disabled:
		page.queue_free()
		return "%s ToTitle not usable" % path
	var why_bit := Locale.t("lb_dynasty_end_why_wipeout")
	var hit := false
	for n in panel.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		if tx.find(why_bit) >= 0 or tx.find(Locale.t("lb_dynasty_end_title")) >= 0:
			hit = true
			break
	if not hit:
		page.queue_free()
		return "%s wipeout feel text missing" % path
	if check_advance:
		var m1 := page.find_child("AdvanceMonth", true, false) as BaseButton
		if m1 == null or not m1.disabled:
			page.queue_free()
			return "AdvanceMonth should be disabled when dynasty ended"
	print("dynasty-wipeout feel ok path=%s" % path.get_file())
	page.queue_free()
	await get_tree().process_frame
	return ""
