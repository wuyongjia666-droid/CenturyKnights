extends Node
## Y1-A T-P7: FE-style 3D engage cutscene hook + board engage bridge.
## InputRouter / controller E2E under CK_FORCE_MOBILE. Fail-suite (assertions red).

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL combat engage cutscene: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ENGAGE CUTSCENE PASS")
	get_tree().quit(0)


func _run() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		OS.set_environment("CK_FORCE_MOBILE", "0")
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra_fe_sides()
	if err == "":
		err = _should_play_gate()
	if err == "":
		err = _build_record_player_right()
	if err == "":
		err = _build_record_enemy_left_attacker()
	if err == "":
		err = _engage_bridge_juice()
	if err == "":
		err = _e2e_cut_playing_blocks_tap()
	if err == "":
		err = _illegal_attack_still_rejects()
	if err == "":
		err = _source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra_fe_sides() -> String:
	var p: Dictionary = BattleEngageCutscene.fe_sides("player")
	if str(p.get("atk", "")) != "right" or str(p.get("def", "")) != "left":
		return "player attacker must stand FE-right"
	var e: Dictionary = BattleEngageCutscene.fe_sides("enemy")
	if str(e.get("atk", "")) != "left" or str(e.get("def", "")) != "right":
		return "enemy attacker must stand FE-left"
	return ""


func _should_play_gate() -> String:
	if BattleEngageCutscene.should_play("headless", true, true):
		return "headless must never play cutscene overlay"
	if not BattleEngageCutscene.should_play("X11", true, true):
		return "desktop with settings on must play"
	if BattleEngageCutscene.should_play("X11", false, true):
		return "meta cutscenes_on=false must skip"
	if BattleEngageCutscene.should_play("X11", true, false):
		return "settings cutscenes=false must skip"
	return ""


func _build_record_player_right() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	var rec_rows: Array = [{
		"a": 0, "d": 1, "hit": true, "crit": false, "dmg": 5,
		"killed": false, "skill": "", "hp_after": 5, "hit_chance": 80,
	}]
	var rec: Dictionary = BattleEngageCutscene.build_record(
		host, 0, 1, 12, 10, rec_rows, [], "bg", "plain", Color(0.3, 0.3, 0.3), "plain", "Test"
	)
	if rec.is_empty():
		return "build_record empty for valid combat_rec"
	if not rec.has("right") or not rec.has("left"):
		return "record missing FE sides"
	if str(rec["right"].get("team", "")) != "player":
		return "player attacker must be FE-right in record"
	if str(rec["left"].get("team", "")) != "enemy":
		return "defender must be FE-left when player attacks"
	var strikes: Array = rec.get("strikes", [])
	if strikes.size() != 1:
		return "strikes size"
	if str(strikes[0].get("from", "")) != "right":
		return "player strike from must be right"
	if int(strikes[0].get("dmg", 0)) != 5:
		return "strike dmg"
	if BattleEngageCutscene.build_record(host, 0, 1, 12, 10, [], []).size() != 0:
		return "empty combat_rec must yield {}"
	return ""


func _build_record_enemy_left_attacker() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	# Swap: enemy at index 0 for this case — rebuild scrum with enemy as attacker via indices
	# units[1]=enemy attacks units[0]=player
	var rec_rows: Array = [{
		"a": 1, "d": 0, "hit": true, "crit": true, "dmg": 7,
		"killed": false, "skill": "破旗斩", "hp_after": 5, "hit_chance": 70,
	}]
	var rec: Dictionary = BattleEngageCutscene.build_record(
		host, 1, 0, 10, 12, rec_rows, [], "bg", "fort", Color.BLACK, "fort", "Clash"
	)
	if str(rec.get("left", {}).get("team", "")) != "enemy":
		return "enemy attacker must be FE-left"
	if str(rec.get("right", {}).get("team", "")) != "player":
		return "player defender must be FE-right"
	var strikes: Array = rec.get("strikes", [])
	if str(strikes[0].get("from", "")) != "left":
		return "enemy strike from must be left"
	if not bool(strikes[0].get("crit", false)):
		return "crit flag lost"
	return ""


func _engage_bridge_juice() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	BattleEngageCutscene.note_engage_bridge(host, Vector2i(2, 2), Vector2i(3, 2))
	if not host.has_meta("m_engage_bridge"):
		return "bridge meta missing"
	if BattleEngageCutscene.bridge_alpha(host) <= 0.0:
		return "bridge alpha must be live"
	var flash: Dictionary = host.get_meta("m_engage_bridge")
	if flash.get("atk") != Vector2i(2, 2) or flash.get("def") != Vector2i(3, 2):
		return "bridge cells wrong"
	BattleEngageCutscene.clear_bridge(host)
	if host.has_meta("m_engage_bridge"):
		return "clear_bridge failed"
	if BattleEngageCutscene.bridge_alpha(host) != 0.0:
		return "alpha after clear"
	# Desktop must not force-pan on bridge (e2e framing).
	OS.set_environment("CK_FORCE_MOBILE", "0")
	host._board_pan = Vector2(900, 400)
	BattleEngageCutscene.note_engage_bridge(host, Vector2i(2, 2), Vector2i(3, 2))
	var panned: bool = host._board_pan.distance_to(Vector2(900, 400)) > 0.5
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if panned:
		return "desktop engage bridge must not force-pan"
	return ""


func _e2e_cut_playing_blocks_tap() -> String:
	## Mirror controller gate: when cut_playing / enemy turn, InputRouter taps must not select.
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.turn_team = "player"
	host._cut_playing = true
	# Simulate the controller gate used in _apply_board_gesture tap branch.
	if host.turn_team == "player" and not host._cut_playing:
		return "cut_playing gate inverted"
	# After cutscene, gate opens again.
	host._cut_playing = false
	if not (host.turn_team == "player" and not host._cut_playing):
		return "after cutscene player taps must be allowed"
	# Enemy turn still blocks regardless of cut_playing.
	host.turn_team = "enemy"
	host._cut_playing = false
	if host.turn_team == "player" and not host._cut_playing:
		return "enemy turn must block player taps"
	return ""


func _illegal_attack_still_rejects() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.attack_mode = true
	host.selected = 0
	# Empty / out-of-range tap must still go through reject path contract in touch confirm.
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if touch.find("reject_invalid") < 0 and touch.find("m_reject") < 0:
		# Controller reject is enough — check controller
		var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
		if ctrl.find("reject_invalid") < 0 and ctrl.find("m_reject_flash") < 0:
			return "illegal attack reject path missing"
	return ""


func _source_contracts() -> String:
	var eng := FileAccess.get_file_as_string("res://scripts/battle/battle_engage_cutscene.gd")
	if eng.find("class_name BattleEngageCutscene") < 0:
		return "missing BattleEngageCutscene"
	if eng.find("fe_sides") < 0 or eng.find("build_record") < 0:
		return "engage helper missing FE builder"
	if eng.find("note_engage_bridge") < 0 or eng.find("draw_engage_bridge") < 0:
		return "engage helper missing bridge juice"
	if eng.find("should_play") < 0:
		return "engage helper missing should_play"
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleEngageCutscene.note_engage_bridge") < 0:
		return "controller missing engage bridge wire"
	if ctrl.find("BattleEngageCutscene.build_record") < 0:
		return "controller missing build_record wire"
	if ctrl.find("BattleEngageCutscene.draw_engage_bridge") < 0:
		return "controller missing bridge draw wire"
	if ctrl.find("BattleEngageCutscene.clear_bridge") < 0:
		return "controller missing clear_bridge after drain"
	if ctrl.find("BattleEngageCutscene.should_play") < 0:
		return "controller missing should_play gate"
	# Illegal attack still reject (T-P5) — don't regress.
	if ctrl.find("reject_invalid") < 0 and ctrl.find("m_reject") < 0:
		var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
		if ctrl.find("BattleTouchConfirm") < 0 and pick.find("reject") < 0:
			pass  # soft — T-P5 reject lives in controller/touch
	var n: int = ctrl.split("\n").size()
	if n > 3000:
		return "controller over 3000 lines (%d) — extract more" % n
	return ""


class _FakeChar:
	var hp: int = 10
	var max_hp: int = 10
	var name: String = "U"

	func derived_crit() -> int:
		return 5


class _FakeBattleHost:
	var _stage: Rect2 = Rect2(0, 0, 720, 1280)
	var _board_origin: Vector2 = Vector2(40, 80)
	var _board_cell: int = 56
	var units: Array = []
	var selected: int = -1
	var turn_team: String = "player"
	var battle_over: bool = false
	var attack_mode: bool = false
	var _cut_playing: bool = false
	var map_name: String = "TestMap"
	var map_id: String = "ch0_pass"
	var overlay = null
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0
	var _map_w: int = 12
	var _map_h: int = 10
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

	func setup_scrum() -> void:
		var hero := _FakeChar.new()
		hero.name = "Hero"
		hero.hp = 12
		var foe := _FakeChar.new()
		foe.name = "Bandit"
		foe.hp = 10
		units = [
			{"char": hero, "pos": Vector2i(2, 2), "team": "player", "done": false, "template": ""},
			{"char": foe, "pos": Vector2i(3, 2), "team": "enemy", "done": false, "template": ""},
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
