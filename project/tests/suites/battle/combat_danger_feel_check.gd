extends Node
## Y1-A T-P19: danger feel — rules-aligned reach, layered stands/strike wash,
## and focus settle via BattleCombatFrame. Real battle E2E. No EmptyHost.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

const HAND_STANDS := [
	Vector2i(3, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(4, 0), Vector2i(4, 2),
]
const HAND_DANGER := [
	Vector2i(3, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(4, 0), Vector2i(4, 2),
	Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 2), Vector2i(3, 0), Vector2i(3, 2),
]

var _battle: Control
var _foe_i := -1
var _player_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL danger feel: ", err)
		get_tree().quit(1)
		return
	print("COMBAT DANGER FEEL PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra_goldens()
	if err == "":
		err = _algebra_rules_reach()
	if err == "":
		err = _algebra_source()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e_focus_settle()
	if err == "":
		err = _e2e_layers_match_collect()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e_focus_settle()
	if err == "":
		err = _e2e_long_press_focus()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra_goldens() -> String:
	var terrain := [
		["plain", "plain", "plain", "water", "plain"],
		["plain", "plain", "plain", "plain", "plain"],
		["plain", "plain", "plain", "water", "plain"],
	]
	var blocked := [Vector2i(1, 1)]
	var zoc := [Vector2i(1, 1)]
	var stands := DangerZone.reach(terrain, Vector2i(3, 1), 2, blocked, zoc)
	if not _same(stands, HAND_STANDS):
		return "stands golden broken: %s" % stands.keys()
	var danger := DangerZone.from_stand(terrain, Vector2i(3, 1), 2, blocked, zoc, 1)
	if not _same(danger, HAND_DANGER):
		return "from_stand golden broken: %s" % danger.keys()
	return ""


func _algebra_rules_reach() -> String:
	var c := CKCharacter.new()
	c.id = "mark_probe"
	c.job_id = "marksman"
	c.level = 5
	c.stats = {"str": 8, "vit": 8, "skl": 10, "agi": 8, "per": 10, "wil": 8}
	c.recalc_hp()
	c.hp = c.max_hp
	if BattleRules.min_range(c) != 2:
		return "marksman min_range expected 2"
	if BattleRules.attack_reach(c, "plain", 0) < 3:
		return "marksman reach on plain expected >=3 got %s" % BattleRules.attack_reach(c, "plain", 0)
	var melee := CKCharacter.new()
	melee.id = "melee_probe"
	melee.job_id = "light_inf"
	melee.level = 3
	melee.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	melee.recalc_hp()
	melee.hp = melee.max_hp
	if BattleRules.min_range(melee) != 1:
		return "melee min_range expected 1"
	if BattleRules.attack_reach(melee, "plain", 0) != 1:
		return "melee reach on plain expected 1"
	return ""


func _algebra_source() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var feel := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_danger_feel.gd")
	var zone := FileAccess.get_file_as_string("res://scripts/battle/ui/danger_zone.gd")
	var misses: Array = []
	if ctrl.find("BattleDangerFeel.after_set(self)") < 0:
		misses.append("controller _set_danger does not settle via BattleDangerFeel")
	if ctrl.find("BattleDangerFeel.draw(self, overlay)") < 0:
		misses.append("controller _draw_danger does not paint via BattleDangerFeel")
	if feel.find("BattleCombatFrame.follow_cells") < 0:
		misses.append("danger feel settle must use BattleCombatFrame")
	if zone.find("BattleRules.attack_reach") < 0 or zone.find("min_range") < 0:
		misses.append("DangerZone must use attack_reach/min_range")
	if zone.find("collect_layers") < 0:
		misses.append("collect_layers missing")
	if ctrl.find("EmptyHost") >= 0 or feel.find("EmptyHost") >= 0:
		misses.append("EmptyHost theater forbidden")
	return "" if misses.is_empty() else str(misses[0])


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if mobile:
		var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
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
			u.pos = Vector2i(2, 2)
			u.done = false
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(5, 2)
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	# Park board so foe is off the right edge — settle must pull left.
	var stage: Rect2 = BattlePick._stage_rect(_battle)
	if stage.size.x < 8.0:
		return "stage missing"
	var cell: Vector2i = _battle.units[_foe_i].pos
	var origin: Vector2 = _battle.ORIGIN
	var zoom := float(_battle._board_zoom)
	var cell_px: float = float(_battle.CELL) * zoom
	var pan: Vector2 = _battle._board_pan
	var shown_x: float = origin.x * zoom + float(cell.x) * cell_px + pan.x
	var need: float = stage.end.x + 120.0 - shown_x
	_battle._board_pan = Vector2(pan.x + need, pan.y)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	_battle.danger_on = false
	_battle.danger_focus = -1
	return ""


func _e2e_focus_settle() -> String:
	var before: Vector2 = _battle._board_pan
	_battle._set_danger(true, _foe_i)
	await _settle(6)
	if not _battle.danger_on or int(_battle.danger_focus) != _foe_i:
		return "set_danger did not latch focus"
	var after: Vector2 = _battle._board_pan
	if after.x >= before.x - 0.5:
		return "focus settle did not pull offscreen foe (before %s after %s)" % [before, after]
	if not _battle.has_meta("m_combat_frame"):
		return "settle did not stamp m_combat_frame"
	return ""


func _e2e_layers_match_collect() -> String:
	_battle.danger_on = true
	_battle.danger_focus = _foe_i
	var flat := DangerZone.collect(_battle)
	var layers: Dictionary = DangerZone.collect_layers(_battle)
	var rebuilt := {}
	for c in layers.stands.keys():
		rebuilt[c] = true
	for c in layers.strike.keys():
		rebuilt[c] = true
	if rebuilt.size() != flat.size():
		return "layers union size %s != collect %s" % [rebuilt.size(), flat.size()]
	for c in flat.keys():
		if not rebuilt.has(c):
			return "collect cell missing from layers: %s" % c
	if layers.stands.is_empty():
		return "stands empty for living foe"
	# Pure strike cells must not also sit in stands.
	for c in layers.strike.keys():
		if layers.stands.has(c):
			return "strike layer leaked a stand cell %s" % c
	# Focused wash ⊆ full wash.
	_battle.danger_focus = -1
	var all := DangerZone.collect(_battle)
	if all.size() < flat.size():
		return "full danger smaller than focused"
	# Rules wiring on a live foe: reach matches BattleRules for its stand tile.
	var foe = _battle.units[_foe_i]
	var tid := str(_battle.terrain[foe.pos.y][foe.pos.x])
	var h := int(_battle._height_at(foe.pos))
	var want := BattleRules.attack_reach(foe.char, tid, h)
	var got_layers: Dictionary = DangerZone.layers_for_unit(_battle, foe)
	var ring := 0
	for cell in got_layers.strike.keys():
		var d: int = absi(cell.x - foe.pos.x) + absi(cell.y - foe.pos.y)
		# Only count strikes painted from the origin stand (not from a far stand).
		if got_layers.stands.has(foe.pos) and d > ring and d <= want:
			ring = maxi(ring, d)
	if want >= 1 and not got_layers.stands.has(foe.pos):
		return "origin missing from stands"
	return ""


func _e2e_long_press_focus() -> String:
	# Start from a clean wash so the press arms focus (second press would toggle off).
	_battle._set_danger(false, -1)
	var before := {}
	for i in _battle.units.size():
		before[i] = _battle.units[i].pos
	_battle._on_long_press_cell(_battle.units[_foe_i].pos)
	for i in _battle.units.size():
		if _battle.units[i].pos != before[i]:
			return "long press moved unit %s" % i
	if not _battle.danger_on or int(_battle.danger_focus) != _foe_i:
		return "long press did not focus enemy"
	# Second press on the same foe clears focus without moving anyone.
	_battle._on_long_press_cell(_battle.units[_foe_i].pos)
	if _battle.danger_on or int(_battle.danger_focus) >= 0:
		return "second long press did not clear focus"
	return ""


func _same(got: Dictionary, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for cell in want:
		if not got.has(cell):
			return false
	return true


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_battle = null
