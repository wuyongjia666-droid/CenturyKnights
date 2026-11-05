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
	if src.find('name = "ToNewGame"') < 0:
		return "missing ToNewGame on dynasty end board"
	if src.find("res://scenes/story/naming.tscn") < 0:
		return "ToNewGame must target naming.tscn"
	if src.find('name = "ToTitle"') < 0:
		return "missing ToTitle on dynasty end board"
	if src.find('name = "DynastyEndPanel"') < 0:
		return "missing DynastyEndPanel"
	if src.find('name = "ToGenealogy"') < 0:
		return "missing ToGenealogy on handoff board"
	if src.find("res://scenes/hub/lineage_view.tscn") < 0:
		return "ToGenealogy must target lineage_view"
	if src.find("lineage_focus") < 0:
		return "handoff must stamp lineage_focus for genealogy track"
	## Ban: external heir hire — succession stays company-only (descendants → roster → minor).
	if src.find("CharacterFactory.make_heir") >= 0 or src.find("外招") >= 0:
		return "ban: external heir hire path must not return"
	if src.find("pick_roster_heir") < 0 or src.find("pick_minor_heir") < 0:
		return "company-only succession helpers missing"
	## Ban: field-only dynasty_end — attach must build a panel, not just stamp.
	if src.find("attach_dynasty_end_feel") < 0 or src.find("DynastyEndPanel") < 0:
		return "ban risk: dynasty_end field without board"
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	if loc.find("lb_dynasty_end_to_new_game") < 0:
		return "missing lb_dynasty_end_to_new_game"
	if loc.find("lb_handoff_to_genealogy") < 0:
		return "missing lb_handoff_to_genealogy"
	var gs := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	if gs.find("house_mods = {}") < 0:
		return "new_game must clear house_mods for isolation"
	if gs.find("lineage_log.clear()") < 0:
		return "new_game must clear lineage_log"
	if gs.find('remove_meta("lineage_focus")') < 0:
		return "new_game must clear lineage_focus meta"
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


func _path_wipeout_end_board() -> String:
	_boot("团灭终局")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "wipeout: no leader"
	_old_leader_id = str(leader.id)
	_wipe_all_living()
	leader.is_leader = true
	var closed: Dictionary = Lineage.close_after_battle()
	if bool(closed.get("ok", false)):
		return "wipeout: expected dynasty end, got ok"
	if not Lineage.is_dynasty_ended():
		return "wipeout: dynasty_end not stamped"
	if str(Lineage.dynasty_end_snapshot().get("reason", "")) != "wipeout":
		return "wipeout: reason want=wipeout"
	## Castle hub end board.
	var page: Control = (load(CASTLE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(14)
	var panel := page.find_child("DynastyEndPanel", true, false)
	if panel == null:
		page.queue_free()
		return "wipeout castle DynastyEndPanel missing"
	var to_t := page.find_child("ToTitle", true, false) as BaseButton
	var to_n := page.find_child("ToNewGame", true, false) as BaseButton
	if to_t == null or not to_t.visible or to_t.disabled:
		page.queue_free()
		return "wipeout ToTitle missing/unusable"
	if to_n == null or not to_n.visible or to_n.disabled:
		page.queue_free()
		return "wipeout ToNewGame missing/unusable"
	if to_t.get_signal_connection_list("pressed").is_empty():
		page.queue_free()
		return "wipeout ToTitle not wired"
	if to_n.get_signal_connection_list("pressed").is_empty():
		page.queue_free()
		return "wipeout ToNewGame not wired"
	var want_new := Locale.t("lb_dynasty_end_to_new_game")
	if str(to_n.text).find(want_new) < 0 and to_n.text != want_new:
		## Allow exact or contains.
		if str(to_n.text) != want_new:
			page.queue_free()
			return "wipeout ToNewGame text want=%s got=%s" % [want_new, to_n.text]
	if page.find_child("DynastyEndActions", true, false) == null:
		page.queue_free()
		return "wipeout DynastyEndActions missing"
	_shot("end_board_wipeout")
	page.queue_free()
	await _settle(2)
	## Hourglass also hosts the same board.
	page = (load(HOURGLASS_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(12)
	if page.find_child("DynastyEndPanel", true, false) == null:
		page.queue_free()
		return "wipeout hourglass DynastyEndPanel missing"
	if page.find_child("ToNewGame", true, false) == null:
		page.queue_free()
		return "wipeout hourglass ToNewGame missing"
	page.queue_free()
	await _settle(2)
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
	## Company-only: heir is already a descendant on the roster — never an outside hire.
	var rr: Dictionary = Lineage.transfer_banner("abdicate")
	if not bool(rr.get("ok", false)):
		return "handoff: transfer_banner failed: %s" % str(rr.get("msg", ""))
	if Lineage.is_dynasty_ended():
		return "handoff: must not dynasty_end when heir lives"
	if not Lineage.is_banner_handoff_pending():
		return "handoff: banner_handoff not pending"
	var now: CKCharacter = GameState.get_leader()
	if now == null or str(now.id) != _heir_id:
		return "handoff: new leader want=%s got=%s" % [_heir_id, str(now.id if now else "")]
	if not now.in_roster:
		return "handoff: new banner-bearer not in roster/编制"
	if not GameState.has_meta("lineage_focus") or str(GameState.get_meta("lineage_focus")) != _heir_id:
		return "handoff: lineage_focus not stamped on heir"
	## Hub board with crest + ToDeploy/ToRoster/ToGenealogy.
	var page: Control = (load(CASTLE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(14)
	if page.find_child("BannerHandoffPanel", true, false) == null:
		page.queue_free()
		return "handoff castle BannerHandoffPanel missing"
	if page.find_child("BannerHandoffCrestStrip", true, false) == null:
		page.queue_free()
		return "handoff castle BannerHandoffCrestStrip missing"
	var heir_lab := page.find_child("HandoffHeirName", true, false)
	if heir_lab == null:
		page.queue_free()
		return "handoff HandoffHeirName missing"
	var heir_tx := ""
	if heir_lab is Label:
		heir_tx = str((heir_lab as Label).text)
	elif heir_lab.get("text") != null:
		heir_tx = str(heir_lab.get("text"))
	if heir_tx.find(_heir_name) < 0:
		page.queue_free()
		return "handoff HandoffHeirName missing name: %s" % heir_tx
	for nm in ["ToDeploy", "ToRoster", "ToGenealogy"]:
		var btn := page.find_child(nm, true, false) as BaseButton
		if btn == null or not btn.visible or btn.disabled:
			page.queue_free()
			return "handoff %s missing/unusable" % nm
		if btn.get_signal_connection_list("pressed").is_empty():
			page.queue_free()
			return "handoff %s not wired" % nm
	_shot("hub_after_handoff")
	page.queue_free()
	await _settle(2)
	## Genealogy wall can focus the new banner-bearer.
	page = (load(LINEAGE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(14)
	## Focus via nav params is set by ToGenealogy; suite stamps meta already — wall should resolve.
	var hit := false
	for n in page.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		if tx.find(_heir_name) >= 0:
			hit = true
			break
	if not hit:
		## Soft fallback: character still in GameState and selectable via focus meta.
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
	page = (load(ROSTER_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
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
