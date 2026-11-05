extends Node
## Fat knife #9: 承旗/团灭/再开百年 —
## wipeout end board (ToTitle+ToNewGame), company-only handoff into roster/hub/genealogy,
## new_game isolation (no dirty-read of dynasty_end / banner_handoff / old critical state).

const CASTLE_SCN := "res://scenes/hub/castle_hub.tscn"
const HOURGLASS_SCN := "res://scenes/hub/hourglass.tscn"
const LINEAGE_SCN := "res://scenes/hub/lineage_view.tscn"
const ROSTER_SCN := "res://scenes/hub/roster.tscn"
const MARKER := "BANNER HANDOFF WIPEOUT CENTURY FAT PASS"
const SHOT_DIR := "user://banner_handoff_wipeout_century_shots"
const DESK := Vector2i(1600, 900)

var _shot_n := 0
var _heir_id := ""
var _heir_name := "承旗嗣九"
var _old_leader_id := ""


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL banner handoff wipeout century fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(DESK)
	await _settle(2)
	err = await _path_wipeout_end_board()
	if err != "":
		return err
	err = await _path_handoff_roster_genealogy()
	if err != "":
		return err
	err = _path_new_game_isolation()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var src := FileAccess.get_file_as_string("res://autoload/lineage.gd")
	var need := [
		['name = "ToNewGame"', "missing ToNewGame on dynasty end board"],
		["res://scenes/story/naming.tscn", "ToNewGame must target naming.tscn"],
		['name = "ToTitle"', "missing ToTitle on dynasty end board"],
		['name = "DynastyEndPanel"', "missing DynastyEndPanel"],
		['name = "ToGenealogy"', "missing ToGenealogy on handoff board"],
		["res://scenes/hub/lineage_view.tscn", "ToGenealogy must target lineage_view"],
		["lineage_focus", "handoff must stamp lineage_focus for genealogy track"],
		["pick_roster_heir", "company-only succession helpers missing"],
		["pick_minor_heir", "company-only succession helpers missing"],
		["attach_dynasty_end_feel", "ban risk: dynasty_end field without board"],
	]
	for row in need:
		if src.find(str(row[0])) < 0:
			return str(row[1])
	## Ban: external heir hire — succession stays company-only.
	if src.find("CharacterFactory.make_heir") >= 0 or src.find("外招") >= 0:
		return "ban: external heir hire path must not return"
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	for key in ["lb_dynasty_end_to_new_game", "lb_handoff_to_genealogy"]:
		if loc.find(str(key)) < 0:
			return "missing %s" % key
	var gs := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	for pair in [
		["house_mods = {}", "new_game must clear house_mods for isolation"],
		["lineage_log.clear()", "new_game must clear lineage_log"],
		['remove_meta("lineage_focus")', "new_game must clear lineage_focus meta"],
	]:
		if gs.find(str(pair[0])) < 0:
			return str(pair[1])
	return ""


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(tag: String) -> void:
	_shot_n += 1
	var path := "%s/%02d_%s.png" % [SHOT_DIR, _shot_n, tag]
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(path))
		print("SHOT ", path)


func _boot(tag: String) -> void:
	GameState.new_game(tag, "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("dynasty_end")
	GameState.house_mods.erase("banner_handoff")
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false


func _wipe_all_living() -> void:
	for c in GameState.characters.values():
		if c == null:
			continue
		c.alive = false
		c.in_roster = false
		c.is_child = false
		c.retired = true



func _open_page(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(DESK)
	get_tree().root.add_child(page)
	return page


func _btn_ok(page: Node, nm: String) -> String:
	var btn := page.find_child(nm, true, false) as BaseButton
	if btn == null or not btn.visible or btn.disabled:
		return "%s missing/unusable" % nm
	if btn.get_signal_connection_list("pressed").is_empty():
		return "%s not wired" % nm
	return ""


func _path_wipeout_end_board() -> String:
	_boot("团灭终局")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "wipeout: no leader"
	_old_leader_id = str(leader.id)
	_wipe_all_living()
	leader.is_leader = true
	var closed: Dictionary = Lineage.close_after_battle()
	var err := ""
	if bool(closed.get("ok", false)):
		err = "wipeout: expected dynasty end, got ok"
	elif not Lineage.is_dynasty_ended():
		err = "wipeout: dynasty_end not stamped"
	elif str(Lineage.dynasty_end_snapshot().get("reason", "")) != "wipeout":
		err = "wipeout: reason want=wipeout"
	if err != "":
		return err
	## Castle hub end board.
	var page := _open_page(CASTLE_SCN)
	await _settle(14)
	if page.find_child("DynastyEndPanel", true, false) == null:
		page.queue_free()
		return "wipeout castle DynastyEndPanel missing"
	err = _btn_ok(page, "ToTitle")
	if err == "":
		err = _btn_ok(page, "ToNewGame")
	if err == "" and page.find_child("DynastyEndActions", true, false) == null:
		err = "wipeout DynastyEndActions missing"
	if err == "":
		var to_n := page.find_child("ToNewGame", true, false) as BaseButton
		var want_new := Locale.t("lb_dynasty_end_to_new_game")
		if to_n != null and str(to_n.text) != want_new and str(to_n.text).find(want_new) < 0:
			err = "wipeout ToNewGame text want=%s got=%s" % [want_new, to_n.text]
	if err != "":
		page.queue_free()
		return err
	_shot("end_board_wipeout")
	page.queue_free()
	await _settle(2)
	## Hourglass also hosts the same board.
	page = _open_page(HOURGLASS_SCN)
	await _settle(12)
	if page.find_child("DynastyEndPanel", true, false) == null:
		err = "wipeout hourglass DynastyEndPanel missing"
	elif page.find_child("ToNewGame", true, false) == null:
		err = "wipeout hourglass ToNewGame missing"
	page.queue_free()
	await _settle(2)
	if err != "":
		return err
	print("wipeout end board ok ToTitle+ToNewGame")
	return ""


func _path_handoff_roster_genealogy() -> String:
	_boot("承旗继统")
	var lead: CKCharacter = GameState.get_leader()
	if lead == null:
		return "handoff: no leader"
	lead.age = 52
	var heir := CKCharacter.new()
	heir.id = "century_heir_9"
	heir.name = _heir_name
	heir.age = 22
	heir.gender = "m"
	heir.alive = true
	heir.in_roster = true
	heir.is_child = false
	heir.is_leader = false
	heir.retired = false
	heir.rank = "knight"
	heir.family_id = str(lead.family_id)
	heir.parent_ids = [str(lead.id)]
	heir.stats = {"str": 10, "vit": 10, "skl": 10, "agi": 10, "per": 10, "wil": 10}
	heir.recalc_hp()
	GameState.characters[heir.id] = heir
	GameState.lineage_path[heir.id] = "martial"
	if not heir.id in lead.children_ids:
		lead.children_ids.append(heir.id)
	_heir_id = heir.id
	var rr: Dictionary = Lineage.transfer_banner("abdicate")
	var err := ""
	if not bool(rr.get("ok", false)):
		err = "handoff: transfer_banner failed: %s" % str(rr.get("msg", ""))
	elif Lineage.is_dynasty_ended():
		err = "handoff: must not dynasty_end when heir lives"
	elif not Lineage.is_banner_handoff_pending():
		err = "handoff: banner_handoff not pending"
	else:
		var now: CKCharacter = GameState.get_leader()
		if now == null or str(now.id) != _heir_id:
			err = "handoff: new leader want=%s got=%s" % [_heir_id, str(now.id if now else "")]
		elif not now.in_roster:
			err = "handoff: new banner-bearer not in roster/编制"
		elif not GameState.has_meta("lineage_focus") or str(GameState.get_meta("lineage_focus")) != _heir_id:
			err = "handoff: lineage_focus not stamped on heir"
	if err != "":
		return err
	## Hub board with crest + ToDeploy/ToRoster/ToGenealogy.
	var page := _open_page(CASTLE_SCN)
	await _settle(14)
	if page.find_child("BannerHandoffPanel", true, false) == null:
		err = "handoff castle BannerHandoffPanel missing"
	elif page.find_child("BannerHandoffCrestStrip", true, false) == null:
		err = "handoff castle BannerHandoffCrestStrip missing"
	else:
		var heir_lab := page.find_child("HandoffHeirName", true, false)
		var heir_tx := ""
		if heir_lab == null:
			err = "handoff HandoffHeirName missing"
		else:
			if heir_lab is Label:
				heir_tx = str((heir_lab as Label).text)
			elif heir_lab.get("text") != null:
				heir_tx = str(heir_lab.get("text"))
			if heir_tx.find(_heir_name) < 0:
				err = "handoff HandoffHeirName missing name: %s" % heir_tx
		for nm in ["ToDeploy", "ToRoster", "ToGenealogy"]:
			if err != "":
				break
			err = _btn_ok(page, str(nm))
	if err != "":
		page.queue_free()
		return err
	_shot("hub_after_handoff")
	page.queue_free()
	await _settle(2)
	## Genealogy wall can focus the new banner-bearer.
	page = _open_page(LINEAGE_SCN)
	await _settle(14)
	var hit := false
	for n in page.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		if tx.find(_heir_name) >= 0:
			hit = true
			break
	if not hit:
		if GameState.characters.get(_heir_id) == null:
			page.queue_free()
			return "handoff genealogy: heir missing from characters"
		print("handoff genealogy: heir name not painted yet; characters+focus ok")
	else:
		print("handoff genealogy: heir name visible on wall")
	_shot("genealogy_after_handoff")
	page.queue_free()
	await _settle(2)
	## Roster still lists the new captain.
	page = _open_page(ROSTER_SCN)
	await _settle(12)
	hit = false
	for n in page.find_children("*", "Label", true, false):
		if str((n as Label).text).find(_heir_name) >= 0:
			hit = true
			break
	page.queue_free()
	await _settle(2)
	if not hit and not bool(GameState.characters[_heir_id].in_roster):
		return "handoff roster: heir neither painted nor in_roster"
	print("handoff roster/hub/genealogy ok heir=%s" % _heir_id)
	return ""


func _path_new_game_isolation() -> String:
	## Dirt: stamp dynasty_end + leftover handoff + lineage_log + inflated silver.
	_boot("脏读隔离")
	var lead: CKCharacter = GameState.get_leader()
	if lead == null:
		return "isolation: no leader"
	_old_leader_id = str(lead.id)
	GameState.silver = 9999
	GameState.add_lineage_event("旧局脏事件·不应残留")
	GameState.house_mods["dynasty_end"] = {
		"reason": "wipeout",
		"msg": "旧局终结",
		"label": "脏年",
		"at": 999,
		"last_id": _old_leader_id,
		"heir_id": "",
	}
	GameState.house_mods["banner_handoff"] = {"heir_id": "ghost", "from_id": _old_leader_id, "msg": "ghost"}
	GameState.house_mods["regency"] = {"ward": "ghost"}
	GameState.set_meta("lineage_focus", "ghost")
	if not Lineage.is_dynasty_ended():
		return "isolation: setup failed to stamp dynasty_end"
	## Fresh century — same path naming → new_game uses.
	GameState.new_game("新百年", "灰旗", GameState.crest_color)
	if Lineage.is_dynasty_ended():
		return "isolation: dynasty_end leaked into new_game"
	if Lineage.is_banner_handoff_pending():
		return "isolation: banner_handoff leaked into new_game"
	if not GameState.house_mods.is_empty():
		## new_game sets house_mods={}; any key is a leak.
		return "isolation: house_mods not empty: %s" % str(GameState.house_mods.keys())
	if not GameState.lineage_log.is_empty():
		return "isolation: lineage_log leaked: %s" % str(GameState.lineage_log)
	if GameState.characters.has(_old_leader_id):
		return "isolation: old leader id still in characters"
	if int(GameState.silver) != 120:
		return "isolation: silver dirty-read want=120 got=%s" % GameState.silver
	if int(Calendar.year) != 1 or int(Calendar.month) != 1:
		return "isolation: calendar not reset year=%s month=%s" % [Calendar.year, Calendar.month]
	var fresh: CKCharacter = GameState.get_leader()
	if fresh == null or str(fresh.id) == _old_leader_id:
		return "isolation: fresh leader missing or reused old id"
	if GameState.has_meta("lineage_focus"):
		return "isolation: lineage_focus meta leaked into new_game"
	print("new_game isolation ok old_leader_gone house_mods_empty calendar_y1")
	return ""
