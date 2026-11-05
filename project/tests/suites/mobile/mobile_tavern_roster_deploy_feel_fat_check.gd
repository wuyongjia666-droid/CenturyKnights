extends Node
## Mobile twin fat #8: hire→roster→deploy→battle under CK_FORCE_MOBILE.

const TAVERN_SCN := "res://scenes/hub/tavern.tscn"
const ROSTER_SCN := "res://scenes/hub/roster.tscn"
const DEPLOY_SCN := "res://scenes/hub/deploy.tscn"
const BATTLE_SCN := "res://scenes/battle/battle.tscn"
const MARKER := "MOBILE TAVERN ROSTER DEPLOY FEEL FAT PASS"
const SHOT_DIR := "user://mobile_tavern_roster_deploy_feel_shots"
const PHONE := Vector2i(2400, 1080)

var _shot_n := 0
var _hire_id := ""
var _hire_name := ""


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile tavern roster deploy feel fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	DisplayServer.window_set_size(PHONE)
	await _settle(2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	return await _chain()


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
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = maxi(int(GameState.silver), 5000)
	GameState.deploy_ids.clear()
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		GameState.deploy_ids = [lead.id]
	var face := CKCharacter.new()
	face.id = "m_feel_hire_merc"
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


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(PHONE)
	page.set_meta("no_nav", true)
	get_tree().root.add_child(page)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	return page


func _chain() -> String:
	_boot("手游编制闭环")
	_hire_name = str(GameState.tavern_candidates[0].name)
	var page := _open(TAVERN_SCN)
	await _settle(14)
	## Mobile landscape uses HireFocus when focus card exists; else hire via API + refresh feel.
	var hire_btn := page.find_child("HireFocus", true, false) as Button
	if hire_btn != null:
		hire_btn.pressed.emit()
	else:
		var face: CKCharacter = GameState.tavern_candidates[0]
		page.set("_selected", face)
		page.call("_hire")
	await _settle(14)
	if not CKHireFeel.pending():
		page.queue_free()
		return "mobile hire missing last_hire stamp"
	var hired := CKHireFeel.character()
	if hired == null:
		page.queue_free()
		return "mobile hired face missing"
	_hire_id = str(hired.id)
	if not CKFamilyState.is_marriage_suitor(hired):
		page.queue_free()
		return "mobile merc marriage-suitor regress"
	if page.find_child("HireFeelPanel", true, false) == null:
		## API path may need explicit show when button missing.
		page.call("_show_hire_feel")
		await _settle(6)
	if page.find_child("HireFeelPanel", true, false) == null:
		page.queue_free()
		return "mobile tavern missing HireFeelPanel"
	if page.find_child("ToRoster", true, false) == null or page.find_child("ToDeploy", true, false) == null:
		page.queue_free()
		return "mobile HireFeel missing CTAs"
	_shot("mobile_tavern_hire_feel")
	page.queue_free()
	await _settle(2)

	page = _open(ROSTER_SCN)
	await _settle(14)
	var sel = page.get("_selected")
	if sel == null or str(sel.id) != _hire_id:
		page.queue_free()
		return "mobile roster did not select last hire"
	var chip := page.find_child("NewHireChip", true, false)
	var nrow := page.find_child("NewHireRow", true, false)
	if chip == null and nrow == null:
		page.queue_free()
		return "mobile roster missing NewHire mark"
	_shot("mobile_roster_new_hire")
	page.queue_free()
	await _settle(2)

	page = _open(DEPLOY_SCN)
	await _settle(14)
	var focus = page.get("_focus")
	if focus == null or str(focus.id) != _hire_id:
		page.queue_free()
		return "mobile deploy did not focus last hire"
	if not (_hire_id in GameState.deploy_ids):
		page.call("_toggle", GameState.characters[_hire_id])
		await _settle(4)
	if not (_hire_id in GameState.deploy_ids):
		page.queue_free()
		return "mobile could not deploy hire"
	_shot("mobile_deploy_new_hire")
	page.queue_free()
	await _settle(2)

	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	GameState.set_meta("battle_map", "quest_bandit")
	var battle = (load(BATTLE_SCN) as PackedScene).instantiate()
	get_tree().root.add_child(battle)
	await _settle(18)
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
		return "mobile battle units missing hire"
	if hire_ui >= 0 and battle.has_method("_refresh_info_for"):
		battle.call("_refresh_info_for", hire_ui)
		await _settle(4)
	_shot("mobile_battle_sidebar_hire")
	battle.queue_free()
	print("mobile chain hire→roster→deploy→battle ok")
	return ""
