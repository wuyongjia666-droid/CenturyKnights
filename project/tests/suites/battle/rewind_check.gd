extends Node
## BTL-04: free move undo matches the pre-move hash; 回灯 restores RNG.

var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := _rules()
	if err == "":
		err = await _play()
	if err != "":
		print("FAIL rewind: ", err)
		get_tree().quit(1)
		return
	print("REWIND PASS")
	get_tree().quit(0)


func _rules() -> String:
	if FileAccess.get_file_as_string("res://scripts/battle/ui/rewind_bar.gd").find("天刻") >= 0:
		return "rewind copy used a borrowed name"
	for diff in [0, 1, 2, 3, 4]:
		var rule: Dictionary = BattleSnapshot.rule(diff)
		var want := int([3, 2, 1, 0, 0][diff])
		if int(rule.charges) != want or bool(rule.refill):
			return "rule %d -> %s" % [diff, rule]
	return ""


func _play() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("battle_map", "obj_rout")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var diff := int(GameState.battle_difficulty_from_map(_battle.map_id))
	if int(_battle._lamp_charges) != int(BattleSnapshot.rule(diff).charges):
		return "opening wicks %s" % _battle._lamp_charges
	var undo_btn := _battle.get_node("RewindBar/Row/UndoMove") as Button
	if undo_btn == null or not undo_btn.disabled:
		return "undo should start disabled"
	var err := _undo_moves()
	if err != "":
		return err
	err = _replay()
	if err != "":
		return err
	err = _charges()
	if err != "":
		return err
	await _shots()
	return ""


func _player() -> int:
	for i in _battle.units.size():
		if str(_battle.units[i].team) == "player" and _battle.units[i].char.hp > 0:
			return i
	return -1


func _enemy() -> int:
	for i in _battle.units.size():
		if str(_battle.units[i].team) == "enemy" and _battle.units[i].char.hp > 0:
			return i
	return -1


func _undo_moves() -> String:
	var pi := _player()
	if pi < 0:
		return "no player"
	var before_charges := int(_battle._lamp_charges)
	_battle._select_player(pi)
	var origin: Vector2i = _battle.units[pi].pos
	var dest := Vector2i(-1, -1)
	for cell in _battle.move_cells.keys():
		if cell != origin:
			dest = cell
			break
	if dest.x < 0:
		return "no step"
	for _n in 3:
		var before := BattleSnapshot.hash_of(BattleSnapshot.capture(_battle))
		_battle._click_cell(dest)
		if _battle.units[pi].pos != dest:
			return "move failed %s" % _battle.units[pi].pos
		_battle._undo_move()
		if _battle.units[pi].pos != origin:
			return "undo left %s" % _battle.units[pi].pos
		var after := BattleSnapshot.hash_of(BattleSnapshot.capture(_battle))
		if after != before:
			return "undo hash %s != %s" % [after, before]
	if int(_battle._lamp_charges) != before_charges:
		return "undo spent a wick"
	return ""


func _replay() -> String:
	var pi := _player()
	var ei := _enemy()
	if pi < 0 or ei < 0:
		return "need both sides"
	_battle.units[pi].pos = Vector2i(4, 0)
	_battle.units[ei].pos = Vector2i(5, 0)
	_battle.units[pi].char.hp = 800
	_battle.units[pi].char.max_hp = 800
	_battle.units[ei].char.hp = 800
	_battle.units[ei].char.max_hp = 800
	_battle.rng.seed = 4242
	var state0 := int(_battle.rng.state)
	_battle._seal_turn()
	_battle._lamp_charges = 2
	RewindBar.refresh(_battle)
	_battle._do_attack(pi, ei)
	var hp1 := int(_battle.units[ei].char.hp)
	var state1 := int(_battle.rng.state)
	if hp1 == 800 and state1 == state0:
		return "attack did not roll"
	_battle._rewind_lamp()
	if int(_battle.units[ei].char.hp) != 800 or int(_battle.rng.state) != state0:
		return "rewind missed hp %s rng %s" % [_battle.units[ei].char.hp, _battle.rng.state]
	if int(_battle._lamp_charges) != 1:
		return "wick not spent"
	_battle._do_attack(pi, ei)
	if int(_battle.units[ei].char.hp) != hp1 or int(_battle.rng.state) != state1:
		return "replay drifted hp %s/%s rng %s/%s" % [_battle.units[ei].char.hp, hp1, _battle.rng.state, state1]
	return ""


func _charges() -> String:
	_battle._lamp_charges = 1
	_battle._lamp_max = 1
	_battle._lamp_refill = false
	var pi := _player()
	_battle.units[pi].done = false
	_battle._select_player(pi)
	_battle._wait_selected()
	if not _battle.units[pi].done:
		return "wait did not commit"
	_battle._rewind_lamp()
	if _battle.units[pi].done or int(_battle._lamp_charges) != 0:
		return "rewind wait charges=%s done=%s" % [_battle._lamp_charges, _battle.units[pi].done]
	var lamp := _battle.get_node("RewindBar/Row/Lamp") as Button
	if lamp == null or not lamp.disabled:
		return "lamp stays enabled at 0"
	var frozen := BattleSnapshot.hash_of(BattleSnapshot.capture(_battle))
	_battle._rewind_lamp()
	if int(_battle._lamp_charges) != 0:
		return "spent below zero"
	if BattleSnapshot.hash_of(BattleSnapshot.capture(_battle)) != frozen:
		return "empty rewind moved state"
	_battle._start_player_turn()
	if int(_battle._lamp_charges) != 0:
		return "new turn refilled wicks"
	if not lamp.disabled:
		return "new turn reenabled the lamp"
	_battle._lamp_refill = true
	_battle._lamp_max = 2
	_battle._start_player_turn()
	if int(_battle._lamp_charges) != 2 or lamp.disabled:
		return "refill rule did not restore wicks"
	return ""


func _shots() -> void:
	_battle._lamp_charges = 2
	_battle.battle_over = false
	_battle.turn_team = "player"
	var pi := _player()
	if pi >= 0:
		_battle.units[pi].done = false
		_battle._select_player(pi)
		for cell in _battle.move_cells.keys():
			if cell != _battle.units[pi].pos:
				_battle._click_cell(cell)
				break
	_battle._slash_fx.clear()
	_battle._dmg_fx.clear()
	_battle._lock_burst_fx.clear()
	_battle._move_dust_fx.clear()
	RewindBar.refresh(_battle)
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	if _battle.map_draw:
		_battle.map_draw.queue_redraw()
	await get_tree().process_frame
	await _grab(_battle, Vector2i(1280, 720), "/opt/cursor/artifacts/btl04_rewind_desktop.png")
	var fitted: Dictionary = MobileLayout.fit(Vector2(1080, 2400), {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	_battle.set_meta("mobile_insets", {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
	_battle.scale = Vector2(float(fitted.scale), float(fitted.scale))
	await get_tree().process_frame
	await _grab(_battle, Vector2i(1080, 2400), "/opt/cursor/artifacts/btl04_rewind_phone.png")


func _grab(node: Node, size: Vector2i, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = Vector2(size)
	vp.add_child(bg)
	var parent := node.get_parent()
	node.reparent(vp)
	for _i in 3:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	if parent:
		node.reparent(parent)
	vp.queue_free()
	if img == null:
		print("shot skipped ", path)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	print("shot %s %s err=%s" % [path, img.get_size(), img.save_png(path)])
