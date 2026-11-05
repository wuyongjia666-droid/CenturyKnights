extends Node
## Fat knife #8: 酒馆编制上阵情感闭环 —
## hire → roster face/name → deploy selectable → battle units.
## Mercenary stays marriage-suitor. No EmptyHost/how brush; no ToTavern-only CTA.

const TAVERN_SCN := "res://scenes/hub/tavern.tscn"
const ROSTER_SCN := "res://scenes/hub/roster.tscn"
const DEPLOY_SCN := "res://scenes/hub/deploy.tscn"
const BATTLE_SCN := "res://scenes/battle/battle.tscn"
const MARKER := "TAVERN ROSTER DEPLOY FEEL FAT PASS"
const SHOT_DIR := "user://tavern_roster_deploy_feel_shots"
const DESK := Vector2i(1600, 900)

var _shot_n := 0
var _hire_id := ""
var _hire_name := ""


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL tavern roster deploy feel fat: ", err)
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
	err = await _chain_hire_roster_deploy_battle()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var feel := FileAccess.get_file_as_string("res://scripts/company/hire_feel.gd")
	if feel.find("class_name CKHireFeel") < 0:
		return "missing CKHireFeel"
	if feel.find("HireFeelPanel") < 0:
		return "missing HireFeelPanel"
	if feel.find("ToRoster") < 0 or feel.find("ToDeploy") < 0:
		return "HireFeel missing ToRoster/ToDeploy"
	if feel.find('name = "EmptyHost"') >= 0 or feel.find("CKPageKit.empty") >= 0:
		return "ban: HireFeel must not add EmptyHost/how"
	var gs := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	if gs.find("CKHireFeel.stamp") < 0:
		return "recruit must stamp CKHireFeel"
	var tv := FileAccess.get_file_as_string("res://scripts/hub/tavern.gd")
	if tv.find("_show_hire_feel") < 0 or tv.find("HireFeelPanel") < 0:
		return "tavern missing hire feel handoff"
	## Ban: must not be ToTavern-only empty CTA polish.
	if tv.find("lb_hire_feel") < 0 and tv.find("CKHireFeel.attach_panel") < 0:
		return "tavern hire feel not wired"
	var rost := FileAccess.get_file_as_string("res://scripts/hub/roster.gd")
	if rost.find("CKHireFeel") < 0 or rost.find("NewHireChip") < 0 and rost.find("new_chip") < 0:
		return "roster missing last_hire readback"
	var dep := FileAccess.get_file_as_string("res://scripts/hub/deploy.gd")
	if dep.find("CKHireFeel") < 0:
		return "deploy missing last_hire focus"
	if dep.find("NewHireCard") < 0 and dep.find("DeployFocusTag") < 0:
		return "deploy missing NewHire affordance"
	var fam := FileAccess.get_file_as_string("res://scripts/characters/family_state.gd")
	if fam.find("c.is_leader or c.in_roster") < 0:
		return "marriage suitor in_roster path regress risk"
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
	GameState.house_mods.erase("last_hire")
	GameState.house_mods.erase("banner_handoff")
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = maxi(int(GameState.silver), 5000)
	GameState.deploy_ids.clear()
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		GameState.deploy_ids = [lead.id]
	var face := CKCharacter.new()
	face.id = "feel_hire_merc"
	face.name = "编成刃"
	face.age = 26
	face.alive = true
	face.in_roster = false
	face.is_leader = false
	face.family_id = ""
	face.job_id = "light_inf"
	face.rank = "knight"
	face.gender = "m"
	face.salary = 12
	face.stats = {"str": 10, "vit": 9, "skl": 8, "agi": 9, "per": 7, "wil": 8}
	face.recalc_hp()
	GameState.tavern_candidates = [face]


func _open(path: String, size: Vector2 = Vector2(1600, 900)) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = size
	page.set_meta("no_nav", true)
	get_tree().root.add_child(page)
	return page


func _chain_hire_roster_deploy_battle() -> String:
	_boot("编制闭环")
	var err := await _ui_tavern_hire()
	if err != "":
		return err
	err = await _ui_roster_readback()
	if err != "":
		return err
	err = await _ui_deploy_field()
	if err != "":
		return err
	err = await _ui_battle_units()
	if err != "":
		return err
	print("chain hire→roster→deploy→battle ok id=%s" % _hire_id)
	return ""


func _ui_tavern_hire() -> String:
	var face: CKCharacter = GameState.tavern_candidates[0]
	_hire_name = str(face.name)
	var page := _open(TAVERN_SCN)
	await _settle(10)
	var hire_btn := page.find_child("HireFocus", true, false) as Button
	if hire_btn == null:
		page.queue_free()
		return "tavern missing HireFocus"
	hire_btn.pressed.emit()
	await _settle(12)
	if not CKHireFeel.pending():
		page.queue_free()
		return "hire did not stamp last_hire"
	var hired := CKHireFeel.character()
	if hired == null or not bool(hired.in_roster):
		page.queue_free()
		return "hired face not in roster after hire"
	_hire_id = str(hired.id)
	if not CKFamilyState.is_marriage_suitor(hired):
		page.queue_free()
		return "merc must stay marriage-suitor (in_roster)"
	if page.find_child("HireFeelPanel", true, false) == null:
		page.queue_free()
		return "tavern missing HireFeelPanel after hire"
	if page.find_child("HireFeelName", true, false) == null:
		page.queue_free()
		return "HireFeel missing name"
	if page.find_child("HireFeelPortrait", true, false) == null:
		page.queue_free()
		return "HireFeel missing portrait"
	if page.find_child("ToRoster", true, false) == null:
		page.queue_free()
		return "HireFeel missing ToRoster"
	if page.find_child("ToDeploy", true, false) == null:
		page.queue_free()
		return "HireFeel missing ToDeploy"
	if page.find_child("EmptyHost", true, false) != null and page.find_child("HireFeelPanel", true, false) == null:
		page.queue_free()
		return "ban: EmptyHost-only with no HireFeelPanel"
	_shot("tavern_hire_feel")
	page.queue_free()
	await _settle(2)
	return ""


func _ui_roster_readback() -> String:
	var page := _open(ROSTER_SCN)
	await _settle(12)
	if page.find_child("EmptyHost", true, false) != null:
		page.queue_free()
		return "roster EmptyHost with hired face present"
	if page.find_child("NewHireChip", true, false) == null:
		page.queue_free()
		return "roster missing NewHireChip for last hire"
	var sel = page.get("_selected")
	if sel == null or str(sel.id) != _hire_id:
		page.queue_free()
		return "roster did not auto-select last hire"
	var found_name := false
	for n in page.find_children("*", "Label", true, false):
		if str(n.text).find(_hire_name) >= 0:
			found_name = true
			break
	if not found_name:
		page.queue_free()
		return "roster UI missing hire name"
	_shot("roster_new_hire")
	page.queue_free()
	await _settle(2)
	return ""


func _ui_deploy_field() -> String:
	var page := _open(DEPLOY_SCN)
	await _settle(12)
	var focus = page.get("_focus")
	if focus == null or str(focus.id) != _hire_id:
		page.queue_free()
		return "deploy did not focus last hire"
	if page.find_child("DeployFocusTag", true, false) == null and page.find_child("NewHireCard", true, false) == null:
		page.queue_free()
		return "deploy missing NewHire affordance"
	if not (_hire_id in GameState.deploy_ids):
		page.call("_toggle", GameState.characters[_hire_id])
		await _settle(4)
	if not (_hire_id in GameState.deploy_ids):
		page.queue_free()
		return "could not put hire into deploy_ids"
	_shot("deploy_new_hire")
	page.queue_free()
	await _settle(2)
	return ""


func _ui_battle_units() -> String:
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	GameState.set_meta("battle_map", "quest_bandit")
	var battle = (load(BATTLE_SCN) as PackedScene).instantiate()
	get_tree().root.add_child(battle)
	await _settle(16)
	var saw := false
	var hire_ui := -1
	for i in range(battle.units.size()):
		var u = battle.units[i]
		if str(u.get("team", "")) != "player":
			continue
		var ch = u.get("char", null)
		if ch != null and str(ch.id) == _hire_id:
			saw = true
			hire_ui = i
			break
	if not saw:
		battle.queue_free()
		return "battle units missing hired face"
	if hire_ui >= 0 and battle.has_method("_refresh_info_for"):
		battle.call("_refresh_info_for", hire_ui)
		await _settle(4)
	if battle.find_child("UnitInfoPanel", true, false) == null:
		battle.queue_free()
		return "battle missing UnitInfoPanel sidebar"
	_shot("battle_sidebar_hire")
	battle.queue_free()
	await _settle(2)
	return ""
