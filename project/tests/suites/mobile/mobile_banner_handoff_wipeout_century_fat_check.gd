extends Node
## Mobile twin fat #9: wipeout end board + handoff hub under CK_FORCE_MOBILE.

const CASTLE_SCN := "res://scenes/hub/castle_hub.tscn"
const LINEAGE_SCN := "res://scenes/hub/lineage_view.tscn"
const MARKER := "MOBILE BANNER HANDOFF WIPEOUT CENTURY FAT PASS"
const SHOT_DIR := "user://mobile_banner_handoff_wipeout_century_shots"
const PHONE := Vector2i(2400, 1080)

var _shot_n := 0
var _heir_name := "承旗嗣九"


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile banner handoff wipeout century fat: ", err)
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
	var err := await _path_wipeout()
	if err != "":
		return err
	err = await _path_handoff()
	if err != "":
		return err
	err = _path_isolation()
	if err != "":
		return err
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


func _path_wipeout() -> String:
	_boot("手游团灭")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "mobile wipeout: no leader"
	for c in GameState.characters.values():
		if c == null:
			continue
		c.alive = false
		c.in_roster = false
		c.is_child = false
		c.retired = true
	leader.is_leader = true
	var closed: Dictionary = Lineage.close_after_battle()
	if bool(closed.get("ok", false)) or not Lineage.is_dynasty_ended():
		return "mobile wipeout stamp failed: %s" % str(closed)
	var page: Control = (load(CASTLE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(PHONE)
	get_tree().root.add_child(page)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	await _settle(14)
	if page.find_child("DynastyEndPanel", true, false) == null:
		page.queue_free()
		return "mobile DynastyEndPanel missing"
	var to_n := page.find_child("ToNewGame", true, false) as BaseButton
	var to_t := page.find_child("ToTitle", true, false) as BaseButton
	if to_n == null or to_t == null:
		page.queue_free()
		return "mobile ToTitle/ToNewGame missing"
	if not to_n.visible or to_n.disabled or not to_t.visible:
		page.queue_free()
		return "mobile end CTAs not usable"
	_shot("mobile_end_board")
	page.queue_free()
	await _settle(2)
	print("mobile wipeout end board ok")
	return ""


func _path_handoff() -> String:
	_boot("手游承旗")
	var lead: CKCharacter = GameState.get_leader()
	lead.age = 50
	var heir := CKCharacter.new()
	heir.id = "m_century_heir_9"
	heir.name = _heir_name
	heir.age = 21
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
	if not heir.id in lead.children_ids:
		lead.children_ids.append(heir.id)
	var rr: Dictionary = Lineage.transfer_banner("abdicate")
	if not bool(rr.get("ok", false)):
		return "mobile handoff failed: %s" % str(rr)
	var page: Control = (load(CASTLE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(PHONE)
	get_tree().root.add_child(page)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	await _settle(14)
	if page.find_child("BannerHandoffPanel", true, false) == null:
		page.queue_free()
		return "mobile BannerHandoffPanel missing"
	for nm in ["ToDeploy", "ToRoster", "ToGenealogy"]:
		if page.find_child(nm, true, false) == null:
			page.queue_free()
			return "mobile %s missing" % nm
	_shot("mobile_hub_after_handoff")
	page.queue_free()
	await _settle(2)
	page = (load(LINEAGE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(PHONE)
	get_tree().root.add_child(page)
	await _settle(12)
	_shot("mobile_genealogy_after_handoff")
	page.queue_free()
	await _settle(2)
	print("mobile handoff hub+genealogy ok")
	return ""


func _path_isolation() -> String:
	_boot("手游隔离")
	var old_id := str(GameState.get_leader().id)
	GameState.house_mods["dynasty_end"] = {"reason": "wipeout", "msg": "x", "last_id": old_id}
	GameState.silver = 7777
	GameState.add_lineage_event("mobile dirty")
	GameState.new_game("手游新局", "灰旗", GameState.crest_color)
	if Lineage.is_dynasty_ended():
		return "mobile isolation: dynasty_end leaked"
	if not GameState.house_mods.is_empty():
		return "mobile isolation: house_mods leaked"
	if GameState.characters.has(old_id):
		return "mobile isolation: old leader leaked"
	if int(GameState.silver) != 120:
		return "mobile isolation: silver leaked"
	print("mobile new_game isolation ok")
	return ""
