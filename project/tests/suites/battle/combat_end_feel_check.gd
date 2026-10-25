extends Node
## Y1-A T-P9: battle-end win/lose banner + crest pulse. Algebra + place E2E.
## Fail-suite (assertions red). No EmptyHost theater; no device gate.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("COMBAT END FEEL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL combat end feel: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("战旗", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false


func _run() -> void:
	_boot()
	_algebra()
	await _crest_pulse_place()
	_source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")


func _algebra() -> void:
	_ok(BattlePhaseFeel.end_locale_key(true) == "battle_win", "win locale key")
	_ok(BattlePhaseFeel.end_locale_key(false) == "battle_lose", "lose locale key")
	_ok(BattlePhaseFeel.END_FLASH_MSEC >= 1200, "end flash long enough to read")
	var win_p: Color = BattlePhaseFeel.crest_modulate_for_end(true, "player", 1.0)
	var win_e: Color = BattlePhaseFeel.crest_modulate_for_end(true, "enemy", 1.0)
	_ok(win_p.g >= win_e.g and win_p.a >= 0.99, "win: player crest brighter than foe")
	_ok(win_e.r < 0.75 and win_e.a < 0.95, "win: foe crest dimmed")
	var lose_p: Color = BattlePhaseFeel.crest_modulate_for_end(false, "player", 1.0)
	var lose_e: Color = BattlePhaseFeel.crest_modulate_for_end(false, "enemy", 1.0)
	_ok(lose_e.g >= lose_p.g, "lose: enemy crest brighter than player")
	_ok(lose_p.r < 0.75, "lose: player crest dimmed")
	# Alpha hold then decay
	var host := _FakeEndHost.new()
	host.set_meta("m_end_flash", {"win": true, "msec": 1000})
	_ok(is_equal_approx(BattlePhaseFeel.end_alpha(host, 1000), 1.0), "end_alpha t0 = 1")
	_ok(is_equal_approx(BattlePhaseFeel.end_alpha(host, 1000 + 200), 1.0), "end_alpha hold early")
	var mid: float = BattlePhaseFeel.end_alpha(host, 1000 + 1000)
	_ok(mid > 0.0 and mid < 1.0, "end_alpha mid decay")
	_ok(BattlePhaseFeel.end_alpha(host, 1000 + BattlePhaseFeel.END_FLASH_MSEC + 10) <= 0.0, "end_alpha done")
	# note_battle_end stamps meta
	var h2 := _FakeEndHost.new()
	h2._turn_flash = 0.0
	h2._shake = 0.0
	BattlePhaseFeel.note_battle_end(h2, true)
	_ok(h2.has_meta("m_end_flash"), "note_battle_end stamps m_end_flash")
	_ok(bool(h2.get_meta("m_end_flash").get("win", false)) == true, "note win flag")
	_ok(float(h2._shake) >= 0.5, "win settle shake")
	BattlePhaseFeel.note_battle_end(h2, false)
	_ok(bool(h2.get_meta("m_end_flash").get("win", true)) == false, "note lose flag")


func _crest_pulse_place() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE")
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var root := Control.new()
	root.name = "BattleRootEnd"
	root.size = Vector2(720, 1280)
	add_child(root)
	await _settle(2)
	var strip: Control = CKHeraldryChrome.place_battle_hud_crest_strips(
		root, "ashbanner", Vector2(720, 1280), {"top": 40.0}, true, false
	)
	_ok(strip != null, "placed strip")
	CKHeraldryChrome.apply_battle_end_crest_pulse(root, true, 1.0)
	var pa = strip.find_child("PlayerArms", true, false)
	var ea = strip.find_child("EnemyArms", true, false)
	_ok(pa != null and ea != null, "both arms present")
	_ok(pa.modulate.g > ea.modulate.g, "pulse win: player brighter")
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "strip still ignores mouse")
	_ok(bool(strip.get_meta("end_pulse_win", false)) == true, "end_pulse_win meta")
	CKHeraldryChrome.apply_battle_end_crest_pulse(root, false, 1.0)
	_ok(ea.modulate.g >= pa.modulate.g, "pulse lose: enemy brighter")
	_ok(bool(strip.get_meta("end_pulse_win", true)) == false, "end_pulse lose meta")
	root.queue_free()
	await _settle(2)
	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")


func _source_contracts() -> void:
	var phase := FileAccess.get_file_as_string("res://scripts/battle/battle_phase_feel.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var her := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(phase.find("note_battle_end") >= 0, "phase has note_battle_end")
	_ok(phase.find("draw_end_banner") >= 0, "phase has draw_end_banner")
	_ok(phase.find("crest_modulate_for_end") >= 0, "phase has crest_modulate_for_end")
	_ok(ctrl.find("BattlePhaseFeel.note_battle_end") >= 0, "controller notes battle end")
	_ok(ctrl.find("BattlePhaseFeel.draw_end_banner") >= 0, "controller draws end banner")
	_ok(ctrl.find("BattlePhaseFeel.end_alpha") >= 0, "controller fx_live end_alpha")
	_ok(her.find("apply_battle_end_crest_pulse") >= 0, "heraldry has end crest pulse")
	_ok(ctrl.find("EmptyHost") < 0, "no EmptyHost in controller patch surface")


class _FakeEndHost:
	var _turn_flash: float = 0.0
	var _shake: float = 0.0
	var _board_zoom: float = 1.0
	var _board_pan: Vector2 = Vector2.ZERO
	var units: Array = []
	var map_id: String = "ch0_pass"
	var _stage: Rect2 = Rect2(0, 0, 720, 400)
	var _board_origin: Vector2 = Vector2(0, 0)
	var _board_cell: int = 48

	func _get(property: StringName) -> Variant:
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		if property == &"BOARD_AREA":
			return _stage
		return null

	func get_node_or_null(_path) -> Node:
		return null
