extends Node
## Automated e2e: simulate board clicks — select → move → attack; fail CI if broken.
## Instantiates battle as child (does not change_scene) so this runner survives.

func _ready() -> void:
	await get_tree().process_frame
	var errors: Array = []
	print("=== CenturyKnights tactics e2e start ===")

	GameState.new_game("烬行", "灰旗", "#c9a227")
	var leader = GameState.get_leader()
	if leader == null:
		_fail(["no leader"])
		return

	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	if packed == null:
		_fail(["failed to load battle.tscn"])
		return
	var battle = packed.instantiate()
	# Full-rect control needs a size for local mouse coords; match project window
	add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame

	if battle == null or not battle.has_method("simulate_board_click"):
		_fail(["battle scene missing simulate_board_click"])
		return

	# Guard: background must not swallow clicks
	var bg_ok := false
	for c in battle.get_children():
		if c is ColorRect:
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				bg_ok = true
			else:
				errors.append("ColorRect mouse_filter=%s (want IGNORE)" % c.mouse_filter)
	if not bg_ok:
		errors.append("no IGNORE ColorRect background")

	# Deterministic board: one player at (2,2), one enemy at (4,2)
	var player_i := -1
	var enemy_i := -1
	for i in battle.units.size():
		var u = battle.units[i]
		if u.team == "player" and player_i < 0:
			player_i = i
			u.pos = Vector2i(2, 2)
			u.done = false
			u.char.hp = u.char.max_hp
		elif u.team == "enemy" and enemy_i < 0:
			enemy_i = i
			u.pos = Vector2i(4, 2)
			u.char.hp = u.char.max_hp
		elif u.team == "player":
			u.pos = Vector2i(0, 5)
			u.done = true
		else:
			u.pos = Vector2i(7, 0)
			u.char.hp = 0
	if player_i < 0 or enemy_i < 0:
		_fail(["deploy missing player/enemy player_i=%s enemy_i=%s units=%s" % [player_i, enemy_i, battle.units.size()]])
		return
	battle.selected = -1
	battle.move_cells.clear()
	battle.attack_mode = false
	battle.moved_this_select = false
	battle.turn_team = "player"
	battle.battle_over = false
	if battle.map_draw:
		battle.map_draw.queue_redraw()
	if battle.overlay:
		battle.overlay.queue_redraw()
	await get_tree().process_frame

	var p0: Vector2i = battle.units[player_i].pos
	var dest := Vector2i(3, 2)
	var enemy_pos: Vector2i = battle.units[enemy_i].pos
	var enemy_hp_before: int = battle.units[enemy_i].char.hp

	print("E2E positions player=%s dest=%s enemy=%s" % [p0, dest, enemy_pos])

	# 1) Select unit via simulated click
	battle.simulate_board_click(p0)
	await get_tree().process_frame
	if battle.selected != player_i:
		errors.append("select failed: selected=%s want=%s" % [battle.selected, player_i])
	if battle.move_cells.is_empty():
		errors.append("select did not populate move_cells")
	else:
		print("E2E select OK move_cells=", battle.move_cells.size())

	# 2) Click destination tile, verify position
	battle.simulate_board_click(dest)
	await get_tree().process_frame
	var pos_after: Vector2i = battle.units[player_i].pos
	if pos_after != dest:
		errors.append("move failed: pos=%s want=%s move_cells_has=%s" % [pos_after, dest, battle.move_cells.has(dest) if battle.move_cells else false])
	else:
		print("E2E move OK -> ", pos_after)
	if not battle.moved_this_select:
		errors.append("moved_this_select not set after move")
	if battle.units[player_i].done:
		errors.append("unit should not be done after move-only")

	# 3) Toggle attack mode, click enemy, verify combat
	battle._enter_attack_mode()
	await get_tree().process_frame
	if not battle.attack_mode:
		errors.append("attack_mode not enabled")
	# Out-of-range / empty click must NOT steal selection
	battle.simulate_board_click(Vector2i(7, 5))
	await get_tree().process_frame
	if battle.selected != player_i:
		errors.append("attack_mode empty click stole selection -> %s" % battle.selected)

	battle.simulate_board_click(enemy_pos)
	await get_tree().process_frame
	if not battle.units[player_i].done:
		errors.append("attack did not mark unit done selected=%s attack_mode=%s" % [battle.selected, battle.attack_mode])
	else:
		print("E2E attack OK unit.done=true")
	var log_txt: String = str(battle.log_label.text) if battle.log_label else ""
	if log_txt.find("→") < 0:
		errors.append("combat log missing arrow: %s" % log_txt.substr(0, 80))
	var enemy_hp_after: int = battle.units[enemy_i].char.hp
	var combat_ok = enemy_hp_after < enemy_hp_before or log_txt.find("未命中") >= 0 or log_txt.find("命中") >= 0
	if not combat_ok:
		errors.append("no combat evidence hp %s->%s log=%s" % [enemy_hp_before, enemy_hp_after, log_txt.substr(0, 120)])
	else:
		print("E2E combat OK hp %s -> %s" % [enemy_hp_before, enemy_hp_after])

	# 4) Second ready unit can still select→move
	var second := -1
	for i in battle.units.size():
		if battle.units[i].team == "player" and not battle.units[i].done and battle.units[i].char.hp > 0:
			second = i
			break
	if second >= 0:
		battle.units[second].pos = Vector2i(1, 1)
		battle.units[second].done = false
		battle.selected = -1
		battle.attack_mode = false
		battle.moved_this_select = false
		battle.move_cells.clear()
		battle.simulate_board_click(Vector2i(1, 1))
		await get_tree().process_frame
		var cells_before_second = battle.move_cells.duplicate()
		battle.simulate_board_click(Vector2i(1, 2))
		await get_tree().process_frame
		if battle.units[second].pos != Vector2i(1, 2):
			errors.append("second unit move failed pos=%s cells=%s" % [battle.units[second].pos, cells_before_second.size()])
		else:
			print("E2E second move OK")

	if errors.is_empty():
		print("=== TACTICS E2E PASS ===")
		get_tree().quit(0)
	else:
		_fail(errors)

func _fail(errors: Array) -> void:
	print("=== TACTICS E2E FAIL ===")
	for e in errors:
		print("ERR: ", e)
	get_tree().quit(1)
