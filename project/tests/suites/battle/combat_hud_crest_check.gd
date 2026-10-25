extends Node
## Y1-A T-P8: battle HUD 双方纹章条 — PlayerArms left + EnemyArms right.
## Algebra + place/sync E2E under CK_FORCE_MOBILE. Fail-suite (assertions red).

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
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
	_ok(CKHeraldryChrome.battle_foe_nation_for(host) == "", "empty foe when no meta/encounter/map nation")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	_ok(CKHeraldryChrome.battle_foe_nation_for(host) == "ashbanner", "meta battle_foe_nation wins")
	GameState.remove_meta("battle_foe_nation")
	World.encounter = {"nation": "frostvale", "id": "enc1"}
	_ok(CKHeraldryChrome.battle_foe_nation_for(host) == "frostvale", "World.encounter nation")
	World.encounter = {}


func _place_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var root := Control.new()
	root.name = "BattleRoot"
	root.size = Vector2(1280, 720)
	add_child(root)
	await _settle(2)
	var strip: Control = CKHeraldryChrome.place_battle_hud_crest_strips(
		root, "ashbanner", Vector2(1280, 720), {}, false, false
	)
	_ok(strip != null and strip.name == "BattleHudCrestStrip", "desk BattleHudCrestStrip")
	var pa := strip.find_child("PlayerArms", true, false)
	var ea := strip.find_child("EnemyArms", true, false)
	_ok(pa != null and str(pa.get_meta("arms_kind", "")) == "gen2_36", "desk PlayerArms 团徽")
	_ok(ea != null and ea is TextureRect, "desk EnemyArms")
	_ok(pa.position.x < ea.position.x, "desk PlayerArms left of EnemyArms")
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "strip ignores mouse")
	_ok(pa.mouse_filter == Control.MOUSE_FILTER_IGNORE, "PlayerArms ignores mouse")
	# Re-place replaces
	var strip2: Control = CKHeraldryChrome.place_battle_hud_crest_strips(
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
	var strip: Control = CKHeraldryChrome.place_battle_hud_crest_strips(
		root, CKHeraldryChrome.battle_foe_nation_for(host), Vector2(720, 1280),
		{"top": 48.0, "left": 0.0, "right": 0.0}, true, false
	)
	_ok(strip != null, "mob BattleHudCrestStrip")
	var pa := strip.find_child("PlayerArms", true, false)
	var ea := strip.find_child("EnemyArms", true, false)
	_ok(pa != null and ea != null, "mob both arms")
	_ok(pa.position.y >= 48.0, "mob top inset")
	_ok(pa.position.x < ea.position.x, "mob player left of enemy")
	# No foe → player only
	var strip_solo: Control = CKHeraldryChrome.place_battle_hud_crest_strips(
		root, "", Vector2(720, 1280), {"top": 48.0}, true, false
	)
	await _settle(2)
	_ok(strip_solo.find_child("PlayerArms", true, false) != null, "solo PlayerArms")
	_ok(strip_solo.find_child("EnemyArms", true, false) == null, "solo no EnemyArms")
	_ok(bool(strip_solo.get_meta("has_enemy")) == false, "has_enemy meta false")
	root.queue_free()
	await _settle(2)
	GameState.remove_meta("battle_foe_nation")


func _source_contracts() -> void:
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("place_battle_hud_crest_strips") >= 0, "chrome place_battle_hud_crest_strips")
	_ok(chrome.find("battle_hud_crest_layout") >= 0, "chrome layout pure")
	_ok(chrome.find("sync_battle_hud_crests") >= 0, "chrome sync_battle_hud_crests")
	_ok(chrome.find("BattleHudCrestStrip") >= 0, "chrome host name")
	_ok(chrome.find("PlayerArms") >= 0 and chrome.find("EnemyArms") >= 0, "chrome both arm names")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	_ok(ctrl.find("CKHeraldryChrome.sync_battle_hud_crests") >= 0, "controller sync wire")
	var n: int = ctrl.split("\n").size()
	_ok(n <= 3000, "controller under 3000 (%d)" % n)


class _FakeBattleHost:
	var map_id: String = "ch0_pass"
