extends Control
## 灰旗战棋：8x6 教程图，移动/攻击/待命，敌 AI，规则透视
## 输入 FSM：IDLE → SELECTED → (MOVE) → ATTACK_AIM → 单位 done

const CELL := 56
const ORIGIN := Vector2(40, 80)
var MAP_W: int = 8
var MAP_H: int = 6
var map_id: String = "ch0_pass"
var map_name: String = "隘口之夜"

var terrain: Array = []
var units: Array = []
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
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _banner_tex: TextureRect
var _unit_panel: PanelContainer
var _portrait: TextureRect
var _dmg_fx: Array = []  # {pos, text, age, col}
var _turn_flash: float = 0.0
var _sel_pulse: float = 0.0
var _btn_atk: Button
var _btn_wait: Button
var _btn_end: Button
var _slash_fx: Array = []  # {pos, age, frame}
var _shake: float = 0.0

func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_init_map()
	_deploy()
	_start_player_turn()
	queue_redraw()
	set_process(true)

func _process(delta: float) -> void:
	UnitArt.tick(delta)
	_sel_pulse += delta
	if int(_sel_pulse * 10) % 5 == 0 and _banner_tex:
		_banner_tex.texture = UnitArt.banner(56, 80, false)
	if _turn_flash > 0.0:
		_turn_flash = maxf(0.0, _turn_flash - delta)
	var alive_fx: Array = []
	for fx in _dmg_fx:
		fx.age += delta
		if fx.age < 1.1:
			alive_fx.append(fx)
	_dmg_fx = alive_fx
	var alive_s: Array = []
	for s in _slash_fx:
		s.age += delta
		if s.age < 0.35:
			alive_s.append(s)
	_slash_fx = alive_s
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 8.0)
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		position = Vector2.ZERO
	if overlay:
		overlay.queue_redraw()
	if map_draw and _sel_pulse:
		map_draw.queue_redraw()

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = UIKit.BG
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 顶栏
	var topbar := ColorRect.new()
	topbar.color = UIKit.BG_DEEP
	topbar.position = Vector2(0, 0)
	topbar.size = Vector2(1280, 64)
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topbar)
	var accent := ColorRect.new()
	accent.color = UnitArt.crest_color()
	accent.position = Vector2(0, 0)
	accent.size = Vector2(1280, 3)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	_banner_tex = TextureRect.new()
	_banner_tex.texture = UnitArt.banner(56, 80, false)
	_banner_tex.position = Vector2(16, 8)
	_banner_tex.custom_minimum_size = Vector2(40, 56)
	_banner_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_tex)

	phase_label = UIKit.make_label("玩家回合", true)
	phase_label.position = Vector2(70, 12)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(phase_label)

	var tip = UIKit.make_dim_label("左键选中/移动 · 攻击模式后点敌军 · 右键取消 · 绿林/褐丘/灰平")
	tip.position = Vector2(280, 22)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip)

	map_draw = Node2D.new()
	map_draw.draw.connect(_draw_map)
	add_child(map_draw)

	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	# 右侧信息卡
	_unit_panel = UIKit.make_panel()
	_unit_panel.position = Vector2(520, 80)
	_unit_panel.custom_minimum_size = Vector2(720, 210)
	add_child(_unit_panel)
	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", 12)
	_unit_panel.add_child(phb)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	phb.add_child(_portrait)
	info_label = RichTextLabel.new()
	info_label.custom_minimum_size = Vector2(580, 180)
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_color_override("default_color", UIKit.TEXT)
	phb.add_child(info_label)

	var log_panel = UIKit.make_panel()
	log_panel.position = Vector2(520, 310)
	log_panel.custom_minimum_size = Vector2(720, 180)
	add_child(log_panel)
	log_label = UIKit.make_label("")
	log_label.custom_minimum_size = Vector2(690, 160)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 13)
	log_panel.add_child(log_label)

	var row := HBoxContainer.new()
	row.position = Vector2(520, 520)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_btn_atk = UIKit.make_accent_button("攻击模式", 130)
	_btn_atk.pressed.connect(_enter_attack_mode)
	row.add_child(_btn_atk)
	_btn_wait = UIKit.make_button(Locale.t("wait"), 100)
	_btn_wait.pressed.connect(_wait_selected)
	row.add_child(_btn_wait)
	_btn_end = UIKit.make_button(Locale.t("end_turn"), 120)
	_btn_end.pressed.connect(_end_player_turn)
	row.add_child(_btn_end)
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
	map_id = str(GameState.get_meta("battle_map", "ch0_pass"))
	var m: Dictionary = BattleMaps.get_map(map_id)
	map_name = str(m.get("name", map_id))
	MAP_W = int(m.get("w", 8))
	MAP_H = int(m.get("h", 6))
	terrain.clear()
	var grid: Array = m.get("terrain", [])
	if grid.is_empty():
		for y in MAP_H:
			var row: Array = []
			for x in MAP_W:
				row.append("plain")
			terrain.append(row)
	else:
		for y in grid.size():
			terrain.append(grid[y].duplicate())
	if phase_label:
		phase_label.text = "%s · 玩家回合" % map_name

func _deploy() -> void:
	units.clear()
	var m: Dictionary = BattleMaps.get_map(map_id)
	var ids: Array = GameState.deploy_ids.duplicate()
	if ids.is_empty():
		for c in GameState.roster():
			ids.append(c.id)
			if ids.size() >= 4:
				break
	var spots: Array = []
	for s in m.get("player_spots", [[1,4],[2,5],[0,5],[3,4]]):
		spots.append(Vector2i(int(s[0]), int(s[1])))
	var i = 0
	for cid in ids:
		if i >= spots.size():
			break
		var c: CKCharacter = GameState.characters.get(cid)
		if c == null or not c.alive:
			continue
		units.append({"char": c, "pos": spots[i], "team": "player", "done": false})
		i += 1
	# tutorial militia pad to 4 for ch0_pass only
	if bool(m.get("tutorial_militia", false)):
		var militia_slot := 0
		while i < mini(4, spots.size()):
			units.append({
				"char": CharacterFactory.make_tutorial_militia(militia_slot),
				"pos": spots[i],
				"team": "player",
				"done": false,
			})
			militia_slot += 1
			i += 1
	var enemy_spots: Array = []
	for s in m.get("enemy_spots", [[6,1],[5,2]]):
		enemy_spots.append(Vector2i(int(s[0]), int(s[1])))
	var templates: Array = m.get("enemy_templates", ["bandit_weak","bandit_weak"])
	var ei = 0
	for ti in templates.size():
		if ei >= enemy_spots.size():
			break
		var e = CharacterFactory.make_enemy(str(templates[ti]), rng)
		if e.appearance.get("hair","") == "" or e.faction == "enemy":
			e.appearance = {"hair": "ink_black", "eyes": "dusk", "brow": "thick", "scar": "cheek"}
		units.append({"char": e, "pos": enemy_spots[ei], "team": "enemy", "done": false})
		ei += 1
	_log("%s：我军 %d · 敌军 %d" % [map_name, i, ei])
	_refresh_info()

func _draw_map() -> void:
	# 棋盘阴影底板
	map_draw.draw_rect(Rect2(ORIGIN - Vector2(6, 6), Vector2(MAP_W * CELL + 10, MAP_H * CELL + 10)), Color(0.05, 0.06, 0.08, 0.8))
	for y in MAP_H:
		for x in MAP_W:
			var tid = terrain[y][x]
			var info = BattleRules.terrain_info(tid)
			var r = Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL - 2, CELL - 2))
			var col: Color = info["color"]
			# 棋盘格轻微交错
			if (x + y) % 2 == 0:
				col = col.lightened(0.04)
			map_draw.draw_rect(r, col)
			if tid == "forest":
				map_draw.draw_circle(r.get_center() + Vector2(-6, 4), 5, Color(0.15, 0.32, 0.18))
				map_draw.draw_circle(r.get_center() + Vector2(6, -2), 4, Color(0.18, 0.36, 0.20))
				map_draw.draw_circle(r.get_center() + Vector2(0, -6), 5, Color(0.12, 0.28, 0.16))
			elif tid == "hill":
				map_draw.draw_colored_polygon(
					PackedVector2Array([r.get_center() + Vector2(0, -12), r.get_center() + Vector2(12, 8), r.get_center() + Vector2(-12, 8)]),
					Color(0.42, 0.36, 0.26)
				)
			# 格线
			map_draw.draw_rect(r, Color(0.08, 0.09, 0.11, 0.85), false, 1.0)
			# 悬停高亮
			if _hover_cell == Vector2i(x, y):
				map_draw.draw_rect(r, Color(1, 1, 1, 0.10))

	# units
	for i in units.size():
		var u = units[i]
		if u.char.hp <= 0:
			continue
		var p: Vector2i = u.pos
		var center = ORIGIN + Vector2(p) * CELL + Vector2(CELL / 2, CELL / 2)
		UnitArt.draw_token_on(map_draw, center, u.char, u.team, 20.0, u.done)
		# HP 条
		var hp_ratio = float(u.char.hp) / float(maxi(1, u.char.max_hp))
		var bar_w = 36.0
		var bar_pos = center + Vector2(-bar_w * 0.5, 18)
		map_draw.draw_rect(Rect2(bar_pos, Vector2(bar_w, 5)), Color(0.1, 0.1, 0.12, 0.85))
		var hp_col = Color(0.35, 0.75, 0.45) if u.team == "player" else Color(0.85, 0.35, 0.30)
		map_draw.draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, 5)), hp_col)
		# 名称短签
		var nm = str(u.char.name)
		if nm.length() > 4:
			nm = nm.substr(0, 4)
		map_draw.draw_string(ThemeDB.fallback_font, center + Vector2(-16, -26), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.93, 0.88))
		# 选中脉冲环
		if i == selected:
			var pulse = 0.5 + 0.5 * sin(_sel_pulse * 6.0)
			map_draw.draw_arc(center, 24.0 + pulse * 2.0, 0, TAU, 32, UnitArt.crest_color(), 2.0)

func _draw_overlay() -> void:
	if not attack_mode:
		for pos in move_cells.keys():
			var r = Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
			overlay.draw_rect(r, Color(0.25, 0.55, 0.95, 0.38))
			overlay.draw_rect(r, Color(0.4, 0.7, 1.0, 0.55), false, 2.0)
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
						var a = 0.45 if attack_mode else 0.25
						overlay.draw_rect(r2, Color(0.95, 0.2, 0.2, a))
						overlay.draw_rect(r2, Color(1.0, 0.4, 0.3, 0.8), false, 2.0)
	# slash
	for s in _slash_fx:
		var fi = mini(3, int(s.age / 0.08))
		var path = "res://assets/art/fx/slash_%d.png" % fi
		if ResourceLoader.exists(path):
			var tex = load(path)
			overlay.draw_texture(tex, s.pos - Vector2(32, 32))
	# 伤害飘字
	for fx in _dmg_fx:
		var a = clampf(1.0 - fx.age / 1.1, 0.0, 1.0)
		var yoff = -fx.age * 36.0
		var col: Color = fx.col
		col.a = a
		overlay.draw_string(ThemeDB.fallback_font, fx.pos + Vector2(-10, yoff), fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	# 回合横幅
	if _turn_flash > 0.0:
		var a2 = clampf(_turn_flash / 0.9, 0.0, 1.0)
		var txt = "—— 玩家回合 ——" if turn_team == "player" else "—— 敌方回合 ——"
		overlay.draw_rect(Rect2(80, 300, 360, 50), Color(0.05, 0.06, 0.08, 0.75 * a2))
		overlay.draw_string(ThemeDB.fallback_font, Vector2(120, 332), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UnitArt.crest_color(), a2))

func _gui_input(event: InputEvent) -> void:
	if battle_over:
		return
	if event is InputEventMouseMotion:
		var cell = _mouse_to_cell(event.position)
		if cell != _hover_cell:
			_hover_cell = cell
			map_draw.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_selection()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if turn_team != "player":
			return
		var cell2 = _mouse_to_cell(event.position)
		if cell2.x < 0:
			return
		_click_cell(cell2)

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
	map_draw.queue_redraw()

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
	for u in units:
		if u.char.hp > 0 and u.pos != units[ui].pos:
			move_cells.erase(u.pos)
	_refresh_info()
	overlay.queue_redraw()
	map_draw.queue_redraw()

func _can_attack_from(su: Dictionary, cell: Vector2i) -> bool:
	var d = _manhattan(su.pos, cell)
	if d < 1:
		return false
	if _is_melee(su.char):
		return d == 1
	return d <= 2

func _click_cell(cell: Vector2i) -> void:
	var ui = _unit_at(cell)
	if selected >= 0 and selected < units.size():
		var su = units[selected]
		if su.team == "player" and not su.done:
			if ui >= 0 and units[ui].team == "enemy" and units[ui].char.hp > 0:
				if attack_mode:
					if _can_attack_from(su, cell):
						_do_attack(selected, ui)
						return
					_log("目标超出攻击范围")
					return
				_refresh_info_for(ui)
				return
			if ui < 0 and not attack_mode and not moved_this_select and move_cells.has(cell):
				su.pos = cell
				moved_this_select = true
				move_cells.clear()
				_refresh_info()
				map_draw.queue_redraw()
				overlay.queue_redraw()
				Sfx.move()
				_log("%s 移动至 (%d,%d)" % [su.char.name, cell.x, cell.y])
				return
			if ui >= 0 and units[ui].team == "player" and not units[ui].done and ui != selected:
				_select_player(ui)
				return
			if attack_mode and ui < 0:
				_log("攻击模式中：请点击敌人或右键取消")
			return
	if ui >= 0 and units[ui].team == "player" and not units[ui].done:
		_select_player(ui)
	elif ui >= 0:
		selected = ui
		move_cells.clear()
		attack_mode = false
		moved_this_select = false
		_refresh_info()
		overlay.queue_redraw()
		map_draw.queue_redraw()

func _is_melee(c: CKCharacter) -> bool:
	return str(GameState.get_job(c.job_id).get("atk_type", "melee")) == "melee"

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _spawn_dmg(cell: Vector2i, text: String, col: Color) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_dmg_fx.append({"pos": center, "text": text, "age": 0.0, "col": col})

func _spawn_slash(cell: Vector2i) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_slash_fx.append({"pos": center, "age": 0.0})
	_shake = 3.5

func _do_attack(ai: int, di: int) -> void:
	var atk = units[ai]
	var def = units[di]
	var tid = terrain[def.pos.y][def.pos.x]
	var result = BattleRules.roll_attack(atk.char, def.char, tid, rng)
	var msg = "%s → %s：" % [atk.char.name, def.char.name]
	if result.hit:
		Sfx.hit()
		_spawn_slash(def.pos)
		msg += "命中 %d%s" % [result.damage, "（暴击）" if result.crit else ""]
		var col = Color(1.0, 0.85, 0.3) if result.crit else Color(1.0, 0.45, 0.35)
		_spawn_dmg(def.pos, ("暴%d" % result.damage) if result.crit else ("-%d" % result.damage), col)
		if result.killed:
			msg += " · 击退！"
			_spawn_dmg(def.pos, "击破", Color(1.0, 0.9, 0.5))
			if def.team == "player":
				def.char.injured = true
	else:
		Sfx.miss()
		msg += "未命中（命中率 %d%%）" % result.hit_chance
		_spawn_dmg(def.pos, "未中", Color(0.7, 0.75, 0.85))
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
	phase_label.add_theme_color_override("font_color", UnitArt.crest_color())
	_turn_flash = 0.9
	Sfx.turn()
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
	phase_label.add_theme_color_override("font_color", UIKit.DANGER)
	_turn_flash = 0.9
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
		var range_ok = best_d == 1 or (not _is_melee(u.char) and best_d <= 2)
		if range_ok:
			_do_attack(i, best)
			await get_tree().create_timer(0.25).timeout
			if battle_over:
				return
			continue
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
			elif u.team == "player":
				u.char.hp = maxi(1, int(u.char.max_hp * 0.3))
				u.char.injured = true
		Sfx.win()
		_log("【胜利】%s肃清。+35 银。" % map_name)
		_mark_map_victory()
		phase_label.text = "★ " + Locale.t("battle_win") + " ★"
		phase_label.add_theme_color_override("font_color", UIKit.ACCENT)
	else:
		Sfx.lose()
		_log("【败北】可重试，进度旗标保留。")
		phase_label.text = Locale.t("battle_lose")
		phase_label.add_theme_color_override("font_color", UIKit.DANGER)
		for u in units:
			if u.team == "player":
				u.char.hp = u.char.max_hp
	GameState.save_game()
	# 胜负大面板
	var end_panel = UIKit.make_panel()
	end_panel.position = Vector2(520, 560)
	end_panel.custom_minimum_size = Vector2(720, 100)
	add_child(end_panel)
	var vb := VBoxContainer.new()
	end_panel.add_child(vb)
	var result_l = UIKit.make_label("胜利 — 灰旗仍在风里。" if win else "败北 — 旗可再举。", true)
	result_l.add_theme_font_size_override("font_size", 22)
	result_l.add_theme_color_override("font_color", UIKit.ACCENT if win else UIKit.DANGER)
	vb.add_child(result_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	if win:
		var b = UIKit.make_accent_button("返回章节", 160)
		b.pressed.connect(func():
			var path = str(GameState.get_meta("battle_return", "res://scenes/story/chapter0.tscn"))
			get_tree().change_scene_to_file(path)
		)
		row.add_child(b)
	else:
		var r = UIKit.make_accent_button("重新挑战", 160)
		r.pressed.connect(func(): get_tree().reload_current_scene())
		row.add_child(r)
		var b = UIKit.make_button("返回章节", 160)
		b.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
		)
		row.add_child(b)


func _mark_map_victory() -> void:
	if map_id == "ch0_pass":
		GameState.set_flag("battle_done")
	elif map_id == "ch1_hill":
		GameState.set_flag("ch1_hill_done")
	elif map_id == "ch1_ford":
		GameState.set_flag("ch1_ford_done")
	elif map_id == "ch1_fog":
		GameState.set_flag("ch1_fog_done")
	elif map_id == "ch2_night":
		GameState.set_flag("ch2_night_done")
	# quest maps also count as battle_done for generic chains
	if map_id.begins_with("quest"):
		GameState.set_flag("battle_done")

func _refresh_info_for(ui: int) -> void:
	if ui < 0 or ui >= units.size():
		_refresh_info()
		return
	var u = units[ui]
	var c: CKCharacter = u.char
	_portrait.texture = UnitArt.portrait(c, 96)
	var tid = terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	info_label.text = "[b]%s[/b]（%s） HP %d/%d\n攻 %d 防 %d\n地形：%s\n（仍选中我军，可继续移动/攻击）" % [
		c.name, "我军" if u.team == "player" else "敌军",
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(),
		tinfo["name"],
	]

func _refresh_info() -> void:
	if selected < 0 or selected >= units.size():
		info_label.text = "[b]选择己方单位开始行动[/b]\n目标：歼灭全部敌人。\n蓝格可移动 · 红格为可攻目标 · 攻击模式后点敌。"
		if GameState.get_leader():
			_portrait.texture = UnitArt.portrait(GameState.get_leader(), 96)
		else:
			_portrait.texture = UnitArt.banner(96, 96, false)
		return
	var u = units[selected]
	var c: CKCharacter = u.char
	_portrait.texture = UnitArt.portrait(c, 96)
	var tid = terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var mode = ""
	if u.team == "player" and not u.done:
		if attack_mode:
			mode = "[color=#e07070]【攻击模式】点击红格敌人[/color]\n"
		elif moved_this_select:
			mode = "[color=#c9a227]【已移动】可攻击 / 待命[/color]\n"
		else:
			mode = "[color=#6db0e0]【已选中】点击蓝格移动，或开攻击模式[/color]\n"
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
