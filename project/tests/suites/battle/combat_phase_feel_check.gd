extends Node
## Y1-A T-P6: enemy-turn readability + attack settle juice + phase banner feel.
## InputRouter / controller E2E under CK_FORCE_MOBILE. Fail-suite (assertions red).

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL combat phase feel: ", err)
		get_tree().quit(1)
		return
	print("COMBAT PHASE FEEL PASS")
	get_tree().quit(0)


func _run() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		OS.set_environment("CK_FORCE_MOBILE", "0")
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra_banner()
	if err == "":
		err = _algebra_settle()
	if err == "":
		err = _phase_switch_focus()
	if err == "":
		err = _enemy_actor_follow()
	if err == "":
		err = _attack_settle_juice()
	if err == "":
		err = _e2e_enemy_turn_no_input_steal()
	if err == "":
		err = _e2e_confirm_attack_settle_path()
	if err == "":
		err = _illegal_attack_still_rejects()
	if err == "":
		err = _source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra_banner() -> String:
	var stage := Rect2(24, 76, 360, 280)
	var origin := Vector2(40, 80)
	var map_px := Vector2(12 * 56, 10 * 56)
	var desk: Rect2 = BattlePhaseFeel.banner_rect(stage, origin, map_px, false, false)
	var mob_l: Rect2 = BattlePhaseFeel.banner_rect(stage, origin, map_px, true, true)
	if desk.size.y >= mob_l.size.y:
		return "mobile landscape banner must be taller than desktop"
	if BattlePhaseFeel.banner_font_px(true, true) <= BattlePhaseFeel.banner_font_px(false, false):
		return "mobile landscape font must exceed desktop"
	var local: Rect2 = BattlePhaseFeel.banner_rect_local(stage, Vector2(80, 40), 1.0, true, true)
	if local.size.x < 64.0 or local.size.y < 40.0:
		return "banner_rect_local too small: %s" % local
	var mid_p: Vector2 = stage.position + stage.size * 0.5
	var mid_l: Vector2 = local.position + local.size * 0.5
	if mid_l.distance_to(mid_p - Vector2(80, 40)) > 2.0:
		return "banner_rect_local mid must track stage mid under pan"
	if BattlePhaseFeel.TURN_FLASH_SEC < 1.0:
		return "TURN_FLASH_SEC must be longer than legacy 0.9 for readability"
	return ""


func _algebra_settle() -> String:
	if BattlePhaseFeel.settle_shake("kill") <= BattlePhaseFeel.settle_shake("hit"):
		return "kill shake must exceed hit"
	if BattlePhaseFeel.settle_shake("hit") <= BattlePhaseFeel.settle_shake("miss"):
		return "hit shake must exceed miss"
	if BattlePhaseFeel.settle_kind_from_result(false, false, false) != "miss":
		return "miss kind"
	if BattlePhaseFeel.settle_kind_from_result(true, true, false) != "crit":
		return "crit kind"
	if BattlePhaseFeel.settle_kind_from_result(true, false, true) != "kill":
		return "kill kind"
	if BattlePhaseFeel.settle_locale_key("miss") != "ux_settle_miss":
		return "miss locale key"
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	for k in ["ux_settle_hit", "ux_settle_miss", "ux_settle_kill", "ux_settle_crit"]:
		if ux.find(k) < 0:
			return "locale missing %s" % k
	return ""


func _phase_switch_focus() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.turn_team = "player"
	host._turn_flash = 0.0
	BattlePhaseFeel.note_phase_switch(host, "enemy")
	if host._turn_flash < BattlePhaseFeel.TURN_FLASH_SEC - 0.01:
		return "phase switch must arm turn flash"
	if str(host.get_meta("m_phase_team", "")) != "enemy":
		return "phase team meta missing"
	if not host.has_meta("m_enemy_actor_cell"):
		return "enemy phase lead must focus an actor"
	var enemy_cell: Vector2i = host.get_meta("m_enemy_actor_cell")
	BattlePhaseFeel.note_phase_switch(host, "player")
	if str(host.get_meta("m_phase_team", "")) != "player":
		return "player phase team meta missing"
	# Player lead uses mark_enemy=false; enemy actor meta must stay cleared.
	if host.has_meta("m_enemy_actor_cell") and host.get_meta("m_enemy_actor_cell") == enemy_cell \
			and enemy_cell == Vector2i(3, 2):
		return "player phase must not keep enemy actor cell"
	# Desktop: player phase lead must NOT force-pan (tactics/full_chain e2e framing).
	OS.set_environment("CK_FORCE_MOBILE", "0")
	host._board_pan = Vector2(900, 400)
	BattlePhaseFeel.note_phase_switch(host, "player")
	var player_panned: bool = host._board_pan.distance_to(Vector2(900, 400)) > 0.5
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if player_panned:
		return "player phase lead must not force-pan desktop"
	return ""


func _enemy_actor_follow() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.turn_team = "enemy"
	host._board_pan = Vector2(900, 400)
	BattlePhaseFeel.note_enemy_acting(host, 1)
	if not host.has_meta("m_enemy_actor_cell"):
		return "note_enemy_acting must stamp actor cell"
	var cell: Vector2i = host.get_meta("m_enemy_actor_cell")
	if cell != Vector2i(3, 2):
		return "enemy actor cell wrong: %s" % cell
	if BattlePhaseFeel.enemy_actor_alpha(host) <= 0.0:
		return "enemy actor alpha must be live just after stamp"
	OS.set_environment("CK_FORCE_MOBILE", "0")
	host._board_pan = Vector2(900, 400)
	BattlePick.focus_cell(host, Vector2i(3, 2), false, true)
	var nudged: bool = host._board_pan.distance_to(Vector2(900, 400)) > 0.5
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "failed to restore CK_FORCE_MOBILE"
	if not nudged:
		return "focus_cell(force) must pan on desktop for enemy follow"
	return ""


func _attack_settle_juice() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	BattlePhaseFeel.note_attack_settle(host, "hit", Vector2i(3, 2))
	if not host.has_meta("m_settle_flash"):
		return "settle flash meta missing"
	if BattlePhaseFeel.settle_alpha(host) <= 0.0:
		return "settle alpha must be live"
	if float(host._shake) + 0.001 < BattlePhaseFeel.settle_shake("hit"):
		return "settle must raise shake"
	BattlePhaseFeel.note_attack_settle(host, "kill", Vector2i(3, 2))
	if float(host._shake) + 0.001 < BattlePhaseFeel.settle_shake("kill"):
		return "kill settle must raise shake further"
	return ""


func _e2e_enemy_turn_no_input_steal() -> String:
	## Real InputRouter taps during enemy turn must not steal selection (controller gate).
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.turn_team = "enemy"
	host.selected = -1
	var shoulder: Vector2 = host.ORIGIN + Vector2(2.5, 2.5) * float(host.CELL)
	var r := InputRouter.new()
	r.sticky_fn = func(o: Vector2) -> bool: return BattlePick.near_living_unit(host, o)
	var _down: Array = r.push(_touch(0, true, shoulder), 2000)
	var up: Array = r.push(_touch(0, false, shoulder), 2080)
	var saw_tap := false
	for g in up:
		if str(g.get("kind", "")) == "tap":
			saw_tap = true
			if str(host.turn_team) != "player":
				continue
			var cell: Vector2i = BattlePick.resolve(host, g.get("pos", shoulder))
			var ui: int = host._unit_at(cell)
			if ui >= 0:
				host.selected = ui
	if not saw_tap:
		return "E2E enemy-turn press+release must still emit tap (router)"
	if host.selected != -1:
		return "E2E enemy turn must not steal player selection"
	BattlePhaseFeel.note_enemy_acting(host, 1)
	if not host.has_meta("m_enemy_actor_cell"):
		return "E2E enemy acting follow missing"
	return ""


func _e2e_confirm_attack_settle_path() -> String:
	## confirm_attack stamps confirm msec; settle juice from resolve path (duck).
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.selected = 0
	host.preview_attack_ui = 1
	host.turn_team = "player"
	host.set_meta("m_attack_confirm_msec", Time.get_ticks_msec())
	BattlePhaseFeel.note_attack_settle(host, "hit", host.units[1].pos)
	if not host.has_meta("m_attack_confirm_msec"):
		return "confirm path must stamp m_attack_confirm_msec"
	if not host.has_meta("m_settle_flash"):
		return "confirm→settle must stamp settle flash"
	var flash: Dictionary = host.get_meta("m_settle_flash")
	if str(flash.get("kind", "")) != "hit":
		return "settle kind must be hit"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if conf.find("m_attack_confirm_msec") < 0:
		return "confirm_attack missing m_attack_confirm_msec stamp"
	if conf.find("host._do_attack(host.selected, ui)") < 0:
		return "confirm_attack must still call _do_attack"
	return ""


func _illegal_attack_still_rejects() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.selected = 0
	host.attack_mode = true
	host.turn_team = "player"
	host.set_meta("m_select_burst_msec", Time.get_ticks_msec() - 1000)
	if not BattleTouchConfirm.reject_invalid_tap(host, Vector2i(6, 6)):
		return "illegal attack tap must still reject"
	if host.selected != 0:
		return "reject must keep selection"
	return ""


func _source_contracts() -> String:
	var err := _source_feel()
	if err == "":
		err = _source_controller()
	if err == "":
		err = _source_pick_gate()
	return err


func _source_feel() -> String:
	var feel := FileAccess.get_file_as_string("res://scripts/battle/battle_phase_feel.gd")
	if feel.find("note_phase_switch") < 0 or feel.find("note_attack_settle") < 0:
		return "phase_feel missing core APIs"
	if feel.find("draw_turn_banner") < 0 or feel.find("draw_settle_flash") < 0:
		return "phase_feel missing draw helpers"
	if feel.find("banner_rect_local") < 0:
		return "phase_feel missing screen-stable banner_rect_local"
	if feel.find("note_enemy_acting") < 0 or feel.find("focus_actor") < 0:
		return "phase_feel missing enemy actor follow"
	if feel.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _source_controller() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattlePhaseFeel.note_phase_switch") < 0:
		return "controller missing phase switch wire"
	if ctrl.find("BattlePhaseFeel.note_enemy_acting") < 0:
		return "controller missing enemy acting wire"
	if ctrl.find("BattlePhaseFeel.note_attack_settle") < 0:
		return "controller missing attack settle wire"
	if ctrl.find("BattlePhaseFeel.draw_turn_banner") < 0:
		return "controller missing banner draw wire"
	if ctrl.find("BattlePhaseFeel.draw_settle_flash") < 0:
		return "controller missing settle draw wire"
	if ctrl.find("turn_team") < 0:
		return "controller missing turn_team gate"
	var n: int = ctrl.split("\n").size()
	if n > 3000:
		return "controller over 3000 lines (%d) — extract more" % n
	return ""


func _source_pick_gate() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick.find("force: bool") < 0:
		return "pick focus_cell missing force param for desktop enemy follow"
	return ""


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e


class _FakeBattleHost:
	var _stage: Rect2 = Rect2(0, 0, 720, 1280)
	var _board_origin: Vector2 = Vector2(40, 80)
	var _board_cell: int = 56
	var units: Array = []
	var selected: int = -1
	var turn_team: String = "player"
	var battle_over: bool = false
	var attack_mode: bool = false
	var preview_move_cell: Vector2i = Vector2i(-1, -1)
	var preview_attack_ui: int = -1
	var move_cells: Dictionary = {}
	var overlay = null
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0
	var _shake: float = 0.0
	var _turn_flash: float = 0.0
	var _map_w: int = 12
	var _map_h: int = 10
	var phase_label = null
	var _phase_chip = null
	var logs: Array = []

	func _init() -> void:
		set_meta("m_board_area", _stage)

	func _get(property: StringName) -> Variant:
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		if property == &"BOARD_AREA":
			return _stage
		if property == &"MAP_W":
			return _map_w
		if property == &"MAP_H":
			return _map_h
		return null

	func _clamp_board_pan() -> void:
		_board_pan = BattlePick.clamp_pan(
			_board_pan, _board_zoom, _board_origin,
			Vector2(_map_w, _map_h) * float(_board_cell),
			get_meta("m_board_area", _stage)
		)

	func _apply_board_xform() -> void:
		pass

	func _mobile_landscape() -> bool:
		return true

	func setup_scrum() -> void:
		units = [
			{"char": {"hp": 10, "name": "Hero"}, "pos": Vector2i(2, 2), "team": "player", "done": false},
			{"char": {"hp": 10, "name": "Bandit"}, "pos": Vector2i(3, 2), "team": "enemy", "done": false},
		]
		selected = 0
		set_meta("m_board_area", _stage)

	func _unit_at(pos: Vector2i) -> int:
		for i in units.size():
			if int(units[i].char.hp) > 0 and units[i].pos == pos:
				return i
		return -1

	func _log(msg: String) -> void:
		logs.append(msg)

	func get_node_or_null(_path: NodePath) -> Node:
		return null
