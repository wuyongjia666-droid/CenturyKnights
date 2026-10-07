extends Control
## 灰旗战棋：8x6 教程图，移动/攻击/待命，敌 AI，规则透视
## 输入 FSM：IDLE → SELECTED → (MOVE) → ATTACK_AIM → 单位 done

const CELL := 56
const ORIGIN := Vector2(40, 80)
const MAP_W := 8
const MAP_H := 6

var terrain: Array = []  # [y][x]
var units: Array = []  # {char, pos: Vector2i, team, done}
var turn_team: String = "player"
var selected: int = -1
var move_cells: Dictionary = {}
var attack_mode: bool = false
var moved_this_select: bool = false
var log_label: Label
var info_label: RichTextLabel
var phase_label: Label
var overlay: Node2D
var map_draw: Node2D
var rng := RandomNumberGenerator.new()
var battle_over: bool = false
var _bg: ColorRect

func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_init_map()
	_deploy()
	_start_player_turn()
	queue_redraw()

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = UIKit.BG
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	# CRITICAL: must IGNORE so board clicks reach this Control._gui_input
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	phase_label = UIKit.make_label("玩家回合", true)
	phase_label.position = Vector2(40, 16)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(phase_label)

	var tip = UIKit.make_label("左键选中/移动 · 攻击模式后点敌军 · 右键取消 · 地形：绿林/褐丘/灰平")
	tip.position = Vector2(280, 24)
	tip.add_theme_font_size_override("font_size", 13)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip)

	map_draw = Node2D.new()
	map_draw.draw.connect(_draw_map)
	add_child(map_draw)

	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	info_label = RichTextLabel.new()
	info_label.position = Vector2(520, 80)
	info_label.custom_minimum_size = Vector2(720, 200)
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_label)

	log_label = UIKit.make_label("")
	log_label.position = Vector2(520, 300)
	log_label.custom_minimum_size = Vector2(700, 200)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_label)

	var row := HBoxContainer.new()
	row.position = Vector2(520, 520)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var b_atk = UIKit.make_button("攻击模式", 120)
	b_atk.pressed.connect(_enter_attack_mode)
	row.add_child(b_atk)
	var b_wait = UIKit.make_button(Locale.t("wait"), 100)
	b_wait.pressed.connect(_wait_selected)
	row.add_child(b_wait)
	var b_end = UIKit.make_button(Locale.t("end_turn"), 120)
	b_end.pressed.connect(_end_player_turn)
	row.add_child(b_end)
	var b_prev = CheckButton.new()
	b_prev.text = Locale.t("rules_preview")
	b_prev.button_pressed = BattleRules.preview_enabled
	b_prev.toggled.connect(func(on): BattleRules.preview_enabled = on)
	row.add_child(b_prev)

func _enter_attack_mode() -> void:
	if selected < 0 or selected >= units.size():
		_log("请先选中己方单位再进入攻击模式")
		return
	var su = units[selected]
	if su.team != "player" or su.done:
		_log("当前选中单位无法攻击")
		return
	attack_mode = true
	move_cells.clear()
	overlay.queue_redraw()
	_refresh_info()
	_log("攻击模式：点击射程内敌人")

func _init_map() -> void:
	# 8x6：平地为主，左林右丘
	terrain.clear()
	for y in MAP_H:
		var row: Array = []
		for x in MAP_W:
			var t = "plain"
			if x <= 1 and y >= 2 and y <= 4:
				t = "forest"
			elif x >= 5 and y <= 2:
				t = "hill"
			elif x == 3 and y == 3:
				t = "forest"
			row.append(t)
		terrain.append(row)

func _deploy() -> void:
	units.clear()
	var ids: Array = GameState.deploy_ids.duplicate()
	if ids.is_empty():
		for c in GameState.roster():
			ids.append(c.id)
			if ids.size() >= 4:
				break
	var spots = [Vector2i(1, 4), Vector2i(2, 5), Vector2i(0, 5), Vector2i(3, 4)]
	var i = 0
	for cid in ids:
		if i >= 4:
			break
		var c: CKCharacter = GameState.characters.get(cid)
		if c == null or not c.alive:
			continue
		# 战斗用副本 HP
		units.append({"char": c, "pos": spots[i], "team": "player", "done": false})
		i += 1
	# 敌人
	var enemies = [
		[CharacterFactory.make_enemy("bandit", rng), Vector2i(6, 1)],
		[CharacterFactory.make_enemy("bandit_archer", rng), Vector2i(7, 2)],
		[CharacterFactory.make_enemy("bandit", rng), Vector2i(5, 0)],
		[CharacterFactory.make_enemy("bandit_chief", rng), Vector2i(7, 0)],
	]
	for e in enemies:
		units.append({"char": e[0], "pos": e[1], "team": "enemy", "done": false})

func _draw() -> void:
	pass

func _draw_map() -> void:
	for y in MAP_H:
		for x in MAP_W:
			var tid = terrain[y][x]
			var info = BattleRules.terrain_info(tid)
			var r = Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL - 2, CELL - 2))
			map_draw.draw_rect(r, info["color"])
			# 纹样区分（色弱友好）
			if tid == "forest":
				map_draw.draw_circle(r.get_center(), 6, Color(0.15, 0.3, 0.18))
			elif tid == "hill":
				map_draw.draw_colored_polygon(
					PackedVector2Array([r.get_center() + Vector2(0, -10), r.get_center() + Vector2(10, 8), r.get_center() + Vector2(-10, 8)]),
					Color(0.4, 0.35, 0.25)
				)
			map_draw.draw_rect(r, Color(0.1, 0.1, 0.12), false, 1.0)
	# units
	for u in units:
		if u.char.hp <= 0:
			continue
		var p: Vector2i = u.pos
		var center = ORIGIN + Vector2(p) * CELL + Vector2(CELL / 2, CELL / 2)
		var col = Color(0.3, 0.55, 0.85) if u.team == "player" else Color(0.75, 0.3, 0.3)
		if u.done:
			col = col.darkened(0.35)
		map_draw.draw_circle(center, 18, col)
		map_draw.draw_string(ThemeDB.fallback_font, center + Vector2(-10, 4), str(u.char.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _draw_overlay() -> void:
	if not attack_mode:
		for pos in move_cells.keys():
			var r = Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
			overlay.draw_rect(r, Color(0.2, 0.5, 0.9, 0.35))
	if selected >= 0 and selected < units.size():
		var u = units[selected]
		if u.team == "player" and not u.done:
			var max_r = 1 if _is_melee(u.char) else 2
			for y in MAP_H:
				for x in MAP_W:
					var ap = Vector2i(x, y)
					var d = _manhattan(u.pos, ap)
					if d < 1 or d > max_r:
						continue
					var ui = _unit_at(ap)
					if ui < 0:
						continue
					var ou = units[ui]
					if ou.team != "player" and ou.char.hp > 0:
						var r2 = Rect2(ORIGIN + Vector2(ap) * CELL, Vector2(CELL - 2, CELL - 2))
						overlay.draw_rect(r2, Color(0.9, 0.2, 0.2, 0.4))

func _gui_input(event: InputEvent) -> void:
	if battle_over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_selection()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if turn_team != "player":
			return
		var cell = _mouse_to_cell(event.position)
		if cell.x < 0:
			return
		_click_cell(cell)

## E2E / 调试：模拟棋盘格左键点击（本地坐标走 _gui_input）
func simulate_board_click(cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = cell_to_local(cell)
	_gui_input(ev)

func cell_to_local(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2(CELL * 0.5, CELL * 0.5)

func _cancel_selection() -> void:
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	_refresh_info()
	overlay.queue_redraw()

func _mouse_to_cell(pos: Vector2) -> Vector2i:
	var local = pos - ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var c = Vector2i(int(local.x / CELL), int(local.y / CELL))
	if not _in_bounds(c):
		return Vector2i(-1, -1)
	return c

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < MAP_W and c.y < MAP_H

func _unit_at(pos: Vector2i) -> int:
	for i in units.size():
		if units[i].char.hp > 0 and units[i].pos == pos:
			return i
	return -1

func _select_player(ui: int) -> void:
	selected = ui
	attack_mode = false
	moved_this_select = false
	var mv = units[ui].char.derived_move()
	move_cells = BattleRules.move_costs(terrain, units[ui].pos, mv)
	# remove occupied (keep own tile)
	for u in units:
		if u.char.hp > 0 and u.pos != units[ui].pos:
			move_cells.erase(u.pos)
	_refresh_info()
	overlay.queue_redraw()

func _can_attack_from(su: Dictionary, cell: Vector2i) -> bool:
	var d = _manhattan(su.pos, cell)
	if d < 1:
		return false
	if _is_melee(su.char):
		return d == 1
	return d <= 2

func _click_cell(cell: Vector2i) -> void:
	var ui = _unit_at(cell)

	# --- acting with a selected player unit ---
	if selected >= 0 and selected < units.size():
		var su = units[selected]
		if su.team == "player" and not su.done:
			# Attack: enemy tile (require 攻击模式 so left-click alone does not auto-fire)
			if ui >= 0 and units[ui].team == "enemy" and units[ui].char.hp > 0:
				if attack_mode:
					if _can_attack_from(su, cell):
						_do_attack(selected, ui)
						return
					_log("目标超出攻击范围")
					return
				# Not attack mode: show enemy info; keep player selection
				_refresh_info_for(ui)
				return

			# Move: empty reachable tile (blocked while attack_mode or after move)
			if ui < 0 and not attack_mode and not moved_this_select and move_cells.has(cell):
				su.pos = cell
				moved_this_select = true
				move_cells.clear()
				_refresh_info()
				map_draw.queue_redraw()
				overlay.queue_redraw()
				_log("%s 移动至 (%d,%d)" % [su.char.name, cell.x, cell.y])
				return

			# Switch to another ready player unit
			if ui >= 0 and units[ui].team == "player" and not units[ui].done and ui != selected:
				_select_player(ui)
				return

			# Same unit / empty non-move / blocked — stay in state
			if attack_mode and ui < 0:
				_log("攻击模式中：请点击敌人或右键取消")
			return

	# --- fresh select / inspect ---
	if ui >= 0 and units[ui].team == "player" and not units[ui].done:
		_select_player(ui)
	elif ui >= 0:
		# Inspect only (enemy or spent ally) — do not treat as acting selection
		selected = ui
		move_cells.clear()
		attack_mode = false
		moved_this_select = false
		_refresh_info()
		overlay.queue_redraw()

func _is_melee(c: CKCharacter) -> bool:
	return str(GameState.get_job(c.job_id).get("atk_type", "melee")) == "melee"

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _do_attack(ai: int, di: int) -> void:
	var atk = units[ai]
	var def = units[di]
	var tid = terrain[def.pos.y][def.pos.x]
	var result = BattleRules.roll_attack(atk.char, def.char, tid, rng)
	var msg = "%s → %s：" % [atk.char.name, def.char.name]
	if result.hit:
		msg += "命中 %d%s" % [result.damage, "（暴击）" if result.crit else ""]
		if result.killed:
			msg += " · 击退！"
			if def.team == "player":
				def.char.injured = true
	else:
		msg += "未命中（命中率 %d%%）" % result.hit_chance
	_log(msg)
	atk.done = true
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	_refresh_info()
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_check_end()

func _wait_selected() -> void:
	if selected < 0:
		return
	var u = units[selected]
	if u.team != "player" or u.done:
		return
	u.done = true
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	_log("%s 待命" % u.char.name)
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_refresh_info()

func _start_player_turn() -> void:
	turn_team = "player"
	phase_label.text = "玩家回合"
	for u in units:
		if u.team == "player":
			u.done = false
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	map_draw.queue_redraw()
	overlay.queue_redraw()

func _end_player_turn() -> void:
	if battle_over:
		return
	turn_team = "enemy"
	phase_label.text = "敌方回合"
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	overlay.queue_redraw()
	await get_tree().create_timer(0.35).timeout
	_enemy_ai()
	if not battle_over:
		_start_player_turn()

func _enemy_ai() -> void:
	for i in units.size():
		var u = units[i]
		if u.team != "enemy" or u.char.hp <= 0:
			continue
		# find nearest player
		var best := -1
		var best_d := 999
		for j in units.size():
			var t = units[j]
			if t.team == "player" and t.char.hp > 0:
				var d = _manhattan(u.pos, t.pos)
				if d < best_d:
					best_d = d
					best = j
		if best < 0:
			continue
		var target = units[best]
		# if in range, attack
		var range_ok = best_d == 1 or (not _is_melee(u.char) and best_d <= 2)
		if range_ok:
			_do_attack(i, best)
			await get_tree().create_timer(0.25).timeout
			if battle_over:
				return
			continue
		# move closer
		var mv = BattleRules.move_costs(terrain, u.pos, u.char.derived_move())
		for ou in units:
			if ou.char.hp > 0 and ou.pos != u.pos:
				mv.erase(ou.pos)
		var best_pos = u.pos
		var best_score = best_d
		for pos in mv.keys():
			var d = _manhattan(pos, target.pos)
			if d < best_score:
				best_score = d
				best_pos = pos
		u.pos = best_pos
		_log("%s 推进至 (%d,%d)" % [u.char.name, best_pos.x, best_pos.y])
		# try attack after move
		best_d = _manhattan(u.pos, target.pos)
		range_ok = best_d == 1 or (not _is_melee(u.char) and best_d <= 2)
		if range_ok:
			_do_attack(i, best)
		map_draw.queue_redraw()
		await get_tree().create_timer(0.2).timeout
		if battle_over:
			return

func _check_end() -> void:
	var pc = 0
	var ec = 0
	for u in units:
		if u.char.hp <= 0:
			continue
		if u.team == "player":
			pc += 1
		else:
			ec += 1
	if ec == 0:
		_finish(true)
	elif pc == 0:
		_finish(false)

func _finish(win: bool) -> void:
	if battle_over:
		return
	battle_over = true
	if win:
		GameState.set_flag("battle_done")
		GameState.silver += 35
		GameState.add_rep("ashland", 8)
		for u in units:
			if u.team == "player" and u.char.hp > 0:
				u.char.exp += 15
				# sync hp back
				pass
			elif u.team == "player":
				u.char.hp = maxi(1, int(u.char.max_hp * 0.3))
				u.char.injured = true
		_log("【胜利】隘口肃清。+35 银。可返回章节。")
		phase_label.text = Locale.t("battle_win")
	else:
		_log("【败北】可重试，第零章进度旗标保留。")
		phase_label.text = Locale.t("battle_lose")
		for u in units:
			if u.team == "player":
				u.char.hp = u.char.max_hp
	GameState.save_game()
	var row := HBoxContainer.new()
	row.position = Vector2(520, 580)
	add_child(row)
	if win:
		var b = UIKit.make_button("返回章节", 160)
		b.pressed.connect(func():
			var path = str(GameState.get_meta("battle_return", "res://scenes/story/chapter0.tscn"))
			get_tree().change_scene_to_file(path)
		)
		row.add_child(b)
	else:
		var r = UIKit.make_button("重新挑战", 160)
		r.pressed.connect(func(): get_tree().reload_current_scene())
		row.add_child(r)
		var b = UIKit.make_button("返回章节", 160)
		b.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
		)
		row.add_child(b)

func _refresh_info_for(ui: int) -> void:
	if ui < 0 or ui >= units.size():
		_refresh_info()
		return
	var u = units[ui]
	var c: CKCharacter = u.char
	var tid = terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	info_label.text = "[b]%s[/b]（%s） HP %d/%d\n攻 %d 防 %d\n地形：%s\n（仍选中我军，可继续移动/攻击）" % [
		c.name, "我军" if u.team == "player" else "敌军",
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(),
		tinfo["name"],
	]

func _refresh_info() -> void:
	if selected < 0 or selected >= units.size():
		info_label.text = "选择己方单位开始行动。\n目标：歼灭全部敌人。"
		return
	var u = units[selected]
	var c: CKCharacter = u.char
	var tid = terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var mode = ""
	if u.team == "player" and not u.done:
		if attack_mode:
			mode = "【攻击模式】点击红格敌人\n"
		elif moved_this_select:
			mode = "【已移动】可攻击 / 待命 / 攻击模式\n"
		else:
			mode = "【已选中】点击蓝格移动，或开攻击模式\n"
	var txt = mode + "[b]%s[/b]（%s） HP %d/%d\n攻 %d 防 %d 命中 %d 回避 %d 移动 %d\n地形：%s（回避+%d）\n" % [
		c.name, "我军" if u.team == "player" else "敌军",
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(), c.derived_hit(), c.derived_avo(), c.derived_move(),
		tinfo["name"], tinfo["avo_bonus"],
	]
	if BattleRules.preview_enabled and u.team == "player":
		for j in units.size():
			var e = units[j]
			if e.team == "enemy" and e.char.hp > 0 and _manhattan(u.pos, e.pos) <= 2:
				var pv = BattleRules.preview(c, e.char, terrain[e.pos.y][e.pos.x])
				txt += "透视→%s：命中 %d%% 伤害 %d–%d 暴击 %d%%\n" % [
					e.char.name, pv.hit, pv.dmg.x, pv.dmg.y, pv.crit
				]
	info_label.text = txt

func _log(t: String) -> void:
	log_label.text = t + "\n" + log_label.text
