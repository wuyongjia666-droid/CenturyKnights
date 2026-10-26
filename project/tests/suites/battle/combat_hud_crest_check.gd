extends Node
## Y1-A T-P8: battle HUD 双方纹章条 — PlayerArms left + EnemyArms right.
## Field owns place + sync + foe resolve; Chrome keeps layout + thin shims. Real sync E2E.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("COMBAT HUD FIELD CREST PASS")
		print("COMBAT HUD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL combat hud crest: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("战旗", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false


func _run() -> void:
	_boot()
	_algebra_layout()
	_foe_nation_resolve()
	await _place_desktop()
	await _place_mobile()
	await _sync_field_route()
	_source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")


func _algebra_layout() -> void:
	var desk: Dictionary = CKHeraldryChrome.battle_hud_crest_layout(Vector2(1280, 720), {}, false, false)
	var mob: Dictionary = CKHeraldryChrome.battle_hud_crest_layout(Vector2(720, 1280), {"top": 40.0, "left": 0.0, "right": 0.0}, true, false)
	var land: Dictionary = CKHeraldryChrome.battle_hud_crest_layout(Vector2(1280, 600), {"top": 20.0, "left": 10.0, "right": 10.0}, true, true)
	var dp: Vector2 = desk["player_at"]
	var de: Vector2 = desk["enemy_at"]
	_ok(dp.x < de.x, "desktop player left of enemy")
	_ok(de.x + desk["shield"].x <= 1280.0 + 0.5, "desktop enemy inside vp")
	var mp: Vector2 = mob["player_at"]
	_ok(mp.y >= 40.0, "mobile portrait respects top inset")
	var lp: Vector2 = land["player_at"]
	var le: Vector2 = land["enemy_at"]
	_ok(lp.x >= 10.0, "landscape left inset")
	_ok(le.x > lp.x, "landscape player left of enemy")
	_ok(land["shield"].x >= desk["shield"].x - 0.1, "landscape shield not smaller than desk")


func _foe_nation_resolve() -> void:
	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")
	World.encounter = {}
	var host := _FakeBattleHost.new()
	host.map_id = "ch0_pass"
	_ok(CKHeraldryField.battle_foe_nation_for(host) == "", "empty foe when no meta/encounter/map nation")
	_ok(CKHeraldryChrome.battle_foe_nation_for(host) == "", "chrome shim matches empty")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	_ok(CKHeraldryField.battle_foe_nation_for(host) == "ashbanner", "meta battle_foe_nation wins")
	_ok(CKHeraldryChrome.battle_foe_nation_for(host) == "ashbanner", "chrome shim mirrors meta")
	GameState.remove_meta("battle_foe_nation")
	World.encounter = {"nation": "frostvale", "id": "enc1"}
	_ok(CKHeraldryField.battle_foe_nation_for(host) == "frostvale", "World.encounter nation")
	World.encounter = {}
	# Map nation / foe_nation path (ephemeral register; do not touch production maps.json)
	BattleMaps.register_map("ck_foe_e2e_map", {"nation": "ironmarch", "w": 8, "h": 6})
	host.map_id = "ck_foe_e2e_map"
	_ok(CKHeraldryField.battle_foe_nation_for(host) == "ironmarch", "map.nation via Field")
	BattleMaps.register_map("ck_foe_e2e_map2", {"foe_nation": "goldreach", "w": 8, "h": 6})
	host.map_id = "ck_foe_e2e_map2"
	_ok(CKHeraldryField.battle_foe_nation_for(host) == "goldreach", "map.foe_nation via Field")
	# meta still wins over map
	GameState.set_meta("battle_foe_nation", "ashbanner")
	_ok(CKHeraldryField.battle_foe_nation_for(host) == "ashbanner", "meta beats map nation")
	GameState.remove_meta("battle_foe_nation")
	host.map_id = "ch0_pass"


func _place_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var root := Control.new()
	root.name = "BattleRoot"
	root.size = Vector2(1280, 720)
	add_child(root)
	await _settle(2)
	var strip: Control = CKHeraldryField.place_battle_hud_crest_strips(
		root, "ashbanner", Vector2(1280, 720), {}, false, false
	)
	_ok(strip != null and strip.name == "BattleHudCrestStrip", "desk BattleHudCrestStrip")
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "battle_hud_strip", "desk field_route")
	var pa := strip.find_child("PlayerArms", true, false)
	var ea := strip.find_child("EnemyArms", true, false)
	_ok(pa != null and str(pa.get_meta("arms_kind", "")) == "gen2_36", "desk PlayerArms 团徽")
	_ok(ea != null and ea is TextureRect, "desk EnemyArms")
	_ok(pa.position.x < ea.position.x, "desk PlayerArms left of EnemyArms")
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "strip ignores mouse")
	_ok(pa.mouse_filter == Control.MOUSE_FILTER_IGNORE, "PlayerArms ignores mouse")
	# Re-place replaces
	var strip2: Control = CKHeraldryField.place_battle_hud_crest_strips(
		root, "ashbanner", Vector2(1280, 720), {}, false, false
	)
	await _settle(2)
	_ok(root.get_node_or_null("BattleHudCrestStrip") == strip2, "re-place replaces strip")
	_ok(root.find_child("BattleHudCrestStrip", true, false) != null, "one live strip")
	root.queue_free()
	await _settle(2)


func _place_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var root := Control.new()
	root.name = "BattleRootMob"
	root.size = Vector2(720, 1280)
	add_child(root)
	await _settle(2)
	var host := _FakeBattleHost.new()
	host.map_id = "ch0_pass"
	# Attach strip onto root via sync using fake host fields — call place directly with insets
	var strip: Control = CKHeraldryField.place_battle_hud_crest_strips(
		root, CKHeraldryField.battle_foe_nation_for(host), Vector2(720, 1280),
		{"top": 48.0, "left": 0.0, "right": 0.0}, true, false
	)
	_ok(strip != null, "mob BattleHudCrestStrip")
	var pa := strip.find_child("PlayerArms", true, false)
	var ea := strip.find_child("EnemyArms", true, false)
	_ok(pa != null and ea != null, "mob both arms")
	_ok(pa.position.y >= 48.0, "mob top inset")
	_ok(pa.position.x < ea.position.x, "mob player left of enemy")
	# No foe → player only
	var strip_solo: Control = CKHeraldryField.place_battle_hud_crest_strips(
		root, "", Vector2(720, 1280), {"top": 48.0}, true, false
	)
	await _settle(2)
	_ok(strip_solo.find_child("PlayerArms", true, false) != null, "solo PlayerArms")
	_ok(strip_solo.find_child("EnemyArms", true, false) == null, "solo no EnemyArms")
	_ok(bool(strip_solo.get_meta("has_enemy")) == false, "has_enemy meta false")
	root.queue_free()
	await _settle(2)
	GameState.remove_meta("battle_foe_nation")


func _sync_field_route() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var root := Control.new()
	root.name = "BattleSyncRoot"
	root.size = Vector2(1280, 720)
	root.set_meta("m_safe_insets", {"top": 12.0, "left": 4.0, "right": 4.0})
	add_child(root)
	await _settle(2)
	CKHeraldryField.sync_battle_hud_crests(root)
	await _settle(4)
	var strip := root.get_node_or_null("BattleHudCrestStrip")
	_ok(strip != null, "sync places BattleHudCrestStrip")
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "battle_hud_strip", "sync field_route")
	_ok(strip != null and str(strip.get_meta("foe_nation", "")) == "ashbanner", "sync foe_nation meta")
	var pa := strip.find_child("PlayerArms", true, false) if strip else null
	var ea := strip.find_child("EnemyArms", true, false) if strip else null
	_ok(pa != null and ea != null, "sync both arms")
	_ok(pa != null and pa.position.y >= 12.0, "sync respects m_safe_insets top")
	_ok(pa != null and pa.position.x >= 4.0, "sync respects m_safe_insets left")
	# Chrome shim still works
	CKHeraldryChrome.sync_battle_hud_crests(root)
	await _settle(4)
	_ok(root.get_node_or_null("BattleHudCrestStrip") != null, "chrome shim re-sync live")
	root.queue_free()
	await _settle(2)
	GameState.remove_meta("battle_foe_nation")


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("static func place_battle_hud_crest_strips") >= 0, "field owns place_battle_hud")
	_ok(field.find("static func sync_battle_hud_crests") >= 0, "field owns sync_battle_hud")
	_ok(field.find("field_route") >= 0 and field.find("battle_hud_strip") >= 0, "field battle_hud_strip route")
	_ok(field.find("static func battle_foe_nation_for") >= 0, "field owns battle_foe_nation_for")
	_ok(field.find("CKHeraldryChrome.battle_foe_nation_for") < 0, "field no Chrome foe call")
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("battle_hud_crest_layout") >= 0, "chrome layout pure")
	_ok(chrome.find("CKHeraldryField.sync_battle_hud_crests") >= 0, "chrome sync shim → Field")
	_ok(chrome.find("CKHeraldryField.place_battle_hud_crest_strips") >= 0, "chrome place shim → Field")
	_ok(chrome.find("CKHeraldryField.battle_foe_nation_for") >= 0, "chrome foe shim → Field")
	# Chrome body must not re-own resolve (no GameState meta read in chrome foe)
	var chrome_foe_idx := chrome.find("static func battle_foe_nation_for")
	var chrome_next := chrome.find("\nstatic func ", chrome_foe_idx + 10) if chrome_foe_idx >= 0 else -1
	var chrome_foe_body := chrome.substr(chrome_foe_idx, chrome_next - chrome_foe_idx) if chrome_foe_idx >= 0 and chrome_next > chrome_foe_idx else ""
	_ok(chrome_foe_body.find("GameState.get_meta") < 0, "chrome foe shim has no GameState resolve")
	var report := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_report.gd")
	_ok(report.find("CKHeraldryField.battle_foe_nation_for") >= 0, "report foe → Field")
	_ok(report.find("CKHeraldryChrome.battle_foe_nation_for") < 0, "report no Chrome foe")
	var info := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_info_panel.gd")
	_ok(info.find("CKHeraldryField.battle_foe_nation_for") >= 0, "info panel foe → Field")
	var forecast := FileAccess.get_file_as_string("res://scripts/battle/ui/forecast_panel.gd")
	_ok(forecast.find("CKHeraldryField.battle_foe_nation_for") >= 0, "forecast foe → Field")
	var card := FileAccess.get_file_as_string("res://scripts/ui/unit_card.gd")
	_ok(card.find("CKHeraldryField.battle_foe_nation_for") >= 0, "unit_card foe → Field")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	_ok(ctrl.find("CKHeraldryField.sync_battle_hud_crests") >= 0, "controller sync → Field")
	_ok(ctrl.find("CKHeraldryChrome.sync_battle_hud_crests") < 0, "controller no Chrome sync")
	var n: int = ctrl.split("\n").size()
	_ok(n <= 3000, "controller under 3000 (%d)" % n)


class _FakeBattleHost:
	var map_id: String = "ch0_pass"
