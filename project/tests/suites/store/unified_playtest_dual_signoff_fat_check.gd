extends Node
## Fat knife #10「统一试玩双端签发」
## Lever: 同 tip 双端包 + 签收对照清单底板（不代真机签字）。
## Box/CI path: 标题 → 创角 → 枢纽 → 一战 → 再战（desktop+mobile）。
## m173 APK：docs/playtest/m173-smoke-handoff.md（模拟器绿不等于真机过关）。

const MARKER := "UNIFIED PLAYTEST DUAL SIGNOFF FAT PASS"
const TIP8 := "35024036"
const TIP_FULL := "35024036f211ce4b9afd8a0745a21998584517db"
const MENU_SCN := "res://scenes/ui/main_menu.tscn"
const NAMING_SCN := "res://scenes/story/naming.tscn"
const HUB_SCN := "res://scenes/hub/castle_hub.tscn"
const BATTLE_SCN := preload("res://scenes/battle/battle.tscn")
const MAP_ID := "quest_bandit"
const SHOT_DIR := "user://unified_playtest_dual_signoff_shots"
const DESK := Vector2i(1600, 900)
const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"

var _shot_n := 0
var _battle: Control
var _surface := "desktop"
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	Engine.time_scale = 1.0
	if err != "":
		print("FAIL unified playtest dual signoff fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra_docs()
	if err != "":
		return err
	err = _algebra_release_and_rematch()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	for surface in ["desktop", "mobile"]:
		_surface = surface
		err = await _path_title_naming_hub_battle_rematch()
		if err != "":
			return "%s: %s" % [surface, err]
	return ""


func _repo_doc_text(rel: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var abs := project_root.get_base_dir().path_join(rel)
	if not FileAccess.file_exists(abs):
		return ""
	return FileAccess.get_file_as_string(abs)


func _algebra_docs() -> String:
	var err := _algebra_checklist_assets()
	if err == "":
		err = _algebra_checklist_y1a()
	if err == "":
		err = _algebra_checklist_fat_rows()
	if err == "":
		err = _algebra_checklist_signoff_box()
	if err == "":
		err = _algebra_m173_handoff()
	return err


func _algebra_checklist_assets() -> String:
	var body := _repo_doc_text("docs/playtest/unified-dual-signoff.md")
	if body == "":
		return "missing docs/playtest/unified-dual-signoff.md"
	if body.find(TIP8) < 0 or body.find(TIP_FULL) < 0:
		return "checklist must pin tip %s" % TIP8
	if body.find("CenturyKnights-android-%s.apk" % TIP8) < 0:
		return "checklist missing Android asset name"
	if body.find("CenturyKnights-windows-%s.zip" % TIP8) < 0:
		return "checklist missing Windows asset name"
	if body.find("SHA256-%s.txt" % TIP8) < 0:
		return "checklist missing SHA256 asset"
	return ""


func _algebra_checklist_y1a() -> String:
	var body := _repo_doc_text("docs/playtest/unified-dual-signoff.md")
	for sec in ["3.1", "3.2", "3.3", "3.4", "3.5", "3.6"]:
		if body.find(sec) < 0:
			return "checklist missing Y1-A sec %s" % sec
	for needle in ["不难选中", "安全区", "SpeakerPlate", "Forecast", "半身"]:
		if body.find(needle) < 0:
			return "checklist missing Y1-A needle %s" % needle
	return ""


func _algebra_checklist_fat_rows() -> String:
	var body := _repo_doc_text("docs/playtest/unified-dual-signoff.md")
	for n in range(1, 10):
		if body.find("| %d |" % n) < 0:
			return "checklist missing fat #%d smoke row" % n
	for suite in [
		"combat_rematch_juice_fat",
		"combat_sfx_layer_fat",
		"month_loop_playable_harden_fat",
		"territory_threat_siege_resolve_fat",
		"atlas_city_commission_supply_fat",
		"marriage_bloodline_readable_hook_fat",
		"content_season_s01_s10_playable_harden_fat",
		"tavern_roster_deploy_feel_fat",
		"banner_handoff_wipeout_century_fat",
	]:
		if body.find(suite) < 0:
			return "checklist missing suite %s" % suite
	return ""


func _algebra_checklist_signoff_box() -> String:
	var body := _repo_doc_text("docs/playtest/unified-dual-signoff.md")
	if body.find("签收：通过 / 打回") < 0:
		return "checklist missing user signoff box"
	if body.find("不替代用户签字") < 0 and body.find("不代真机") < 0:
		return "checklist must say it does not replace user signoff"
	if body.find("真机签收：通过") >= 0 or body.find("**已代签收通过**") >= 0:
		return "ban: must not claim 真机签收通过"
	return ""


func _algebra_m173_handoff() -> String:
	var hand := _repo_doc_text("docs/playtest/m173-smoke-handoff.md")
	if hand == "":
		return "missing docs/playtest/m173-smoke-handoff.md"
	for step in ["标题", "创角", "枢纽", "一战", "再战"]:
		if hand.find(step) < 0:
			return "m173 handoff missing step %s" % step
	if hand.find("模拟器绿") < 0 or hand.find("真机过关") < 0:
		return "m173 handoff must warn emulator != device"
	if hand.find(TIP8) < 0:
		return "m173 handoff must pin tip"
	return ""


func _algebra_release_and_rematch() -> String:
	var rel := _repo_doc_text(".github/workflows/release.yml")
	if rel == "":
		return "cannot read .github/workflows/release.yml"
	if rel.find("windows: true") < 0 or rel.find("android: true") < 0:
		return "release.yml must build windows+android"
	if rel.find("CenturyKnights-android-") < 0:
		return "release.yml must rename android apk with short sha"
	if rel.find("SHA256-") < 0:
		return "release.yml must emit SHA256 sums"
	var rep := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_report.gd")
	if rep.find("BattleRematchJuice.do_rematch") < 0:
		return "battle report rematch regress"
	if rep.find("RematchCta") < 0:
		return "RematchCta missing"
	if rep.find("HubCta") < 0:
		return "HubCta missing"
	return ""


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _set_window() -> void:
	if _surface == "mobile":
		DisplayServer.window_set_size(PHONE)
	else:
		DisplayServer.window_set_size(DESK)
	await _settle(2)


func _apply_surface_env() -> void:
	if _surface == "mobile":
		OS.set_environment("CK_FORCE_MOBILE", "1")
		OS.set_environment("CK_SAFE_INSETS", NOTCH)
	else:
		OS.set_environment("CK_FORCE_MOBILE", "0")
		OS.set_environment("CK_SAFE_INSETS", "")


func _shot(tag: String) -> void:
	_shot_n += 1
	var path := "%s/%02d_%s-%s.png" % [SHOT_DIR, _shot_n, _surface, tag]
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(path))
		print("SHOT ", path)


func _mount(path: String) -> Node:
	for child in get_children():
		child.queue_free()
	await _settle(2)
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	await _settle(8)
	return node


func _path_title_naming_hub_battle_rematch() -> String:
	_apply_surface_env()
	await _set_window()
	## 1) 标题
	var menu := await _mount(MENU_SCN)
	if menu == null:
		return "main_menu mount fail"
	await _shot("title")
	print("title ok ", _surface)
	## 2) 创角
	var naming := await _mount(NAMING_SCN)
	if naming == null:
		return "naming mount fail"
	await _shot("naming")
	GameState.new_game("签发十", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	var leader = GameState.get_leader()
	if leader == null or str(leader.name).find("签发十") < 0:
		return "new_game leader naming failed"
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.settings["touch_confirm"] = true
	GameState.settings["reduced_motion"] = false
	GameState.settings["cutscenes"] = false
	GameState.set_meta("cutscenes_on", false)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	print("naming/new_game ok leader=", leader.name)
	## 3) 枢纽
	var hub := await _mount(HUB_SCN)
	if hub == null:
		return "hub mount fail"
	if _surface == "mobile" and hub.has_method("apply_mobile_layout"):
		hub.apply_mobile_layout()
		await _settle(6)
	await _shot("hub")
	print("hub ok ", _surface)
	## 4–5) 一战 → 再战
	var err := await _boot_battle(MAP_ID)
	if err != "":
		return "battle boot: %s" % err
	await _shot("battle")
	print("battle ok map=", _battle.map_id)
	err = await _win_then_rematch()
	if err != "":
		return err
	await _free_battle()
	return ""


func _boot_battle(map_id: String) -> String:
	_apply_surface_env()
	await _set_window()
	if _surface == "mobile" and not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	if _surface == "desktop" and DeviceProfile.is_mobile():
		return "desktop surface still mobile"
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
	GameState.set_meta("battle_sortie", true)
	if GameState.has_meta("battle_return_chapter"):
		GameState.remove_meta("battle_return_chapter")
	_battle = BATTLE_SCN.instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	if _surface == "mobile":
		var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "battle did not enter landscape"
	else:
		await _settle(4)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	return _arrange()


func _boot_rematch(map_id: String) -> String:
	_apply_surface_env()
	await _set_window()
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
	if not GameState.has_meta("battle_sortie"):
		GameState.set_meta("battle_sortie", true)
	_battle = BATTLE_SCN.instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	if _surface == "mobile":
		var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "rematch landscape fail"
	else:
		await _settle(4)
	if str(_battle.map_id) != map_id:
		return "rematch map_id want %s got %s" % [map_id, _battle.map_id]
	return _arrange()


func _arrange() -> String:
	_player_i = -1
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
	if _player_i < 0 or _foe_i < 0:
		return "missing player/enemy units"
	return ""


func _find_report() -> Node:
	if _battle == null:
		return null
	var n := _battle.find_child("ResultReport", true, false)
	if n:
		return n
	return _battle.find_child("BattleReport", true, false)


func _win_then_rematch() -> String:
	_battle.battle_over = false
	for u in _battle.units:
		if str(u.team) == "enemy":
			u.char.hp = 0
	_battle._finish(true)
	await _settle(6)
	if not BattleRematchJuice.offers_rematch(_battle, true):
		return "practice should offer rematch"
	var layer := _find_report()
	if layer == null:
		return "ResultReport missing"
	var rematch := layer.find_child("RematchCta", true, false)
	var hub := layer.find_child("HubCta", true, false)
	if rematch == null:
		return "RematchCta missing"
	if hub == null:
		return "HubCta missing"
	if str(rematch.text).find("再战") < 0:
		return "rematch label want 再战 got %s" % rematch.text
	await _shot("settle")
	## Rematch without title / new_game — same as BattleRematchJuice.do_rematch.
	GameState.set_meta(BattleRematchJuice.META_ROUND, true)
	if not GameState.has_meta("battle_sortie"):
		GameState.set_meta("battle_sortie", true)
	GameState.set_meta("battle_map", MAP_ID)
	await _free_battle()
	var err := await _boot_rematch(MAP_ID)
	if err != "":
		return "rematch reenter: %s" % err
	if _battle.battle_over:
		return "rematch board should be live"
	if _player_i < 0 or _foe_i < 0:
		return "rematch board missing units"
	if not GameState.has_meta(BattleRematchJuice.META_ROUND):
		return "META_ROUND must survive rematch reload"
	if not BattleRematchJuice.claim_rematch_drill():
		return "rematch drill claim failed"
	await _shot("rematch")
	print("rematch ok ", _surface)
	return ""


func _free_battle() -> void:
	if is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	await _settle(4)
