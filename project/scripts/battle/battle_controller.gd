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
var skill_mode: bool = false
var active_skill_id: String = ""
var _btn_skill: Button
var _skill_hint: Label

func _ready() -> void:
	rng.randomize()
	Music.play_battle()
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
	_btn_skill = UIKit.make_accent_button("战技", 100)
	_btn_skill.pressed.connect(_cycle_skill)
	row.add_child(_btn_skill)
	_skill_hint = UIKit.make_dim_label("")
	_skill_hint.position = Vector2(520, 500)
	_skill_hint.custom_minimum_size = Vector2(700, 20)
	add_child(_skill_hint)
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


func _player_skills(ui: int) -> Array:
	if ui < 0 or ui >= units.size():
		return []
	var c: CKCharacter = units[ui].char
	var out: Array = []
	for sid in c.skills:
		var left = int(c.skill_uses.get(sid, 0))
		var cd = int(c.skill_cd.get(sid, 0))
		if left > 0 and cd <= 0:
			out.append(sid)
	return out

func _cycle_skill() -> void:
	if selected < 0 or selected >= units.size():
		_log("请先选中己方单位再选战技")
		return
	var su = units[selected]
	if su.team != "player" or su.done:
		_log("当前单位无法使用战技")
		return
	var avail = _player_skills(selected)
	if avail.is_empty():
		_log("本场战技已用尽或未学会——去演武场转职可解锁")
		skill_mode = false
		active_skill_id = ""
		_update_skill_hint()
		return
	# cycle
	if active_skill_id == "" or active_skill_id not in avail:
		active_skill_id = avail[0]
	else:
		var idx = avail.find(active_skill_id)
		idx = (idx + 1) % avail.size()
		active_skill_id = avail[idx]
	var sk = GameState.get_skill(active_skill_id)
	var typ = str(sk.get("type", "offense"))
	if typ == "support":
		# instant heal adjacent
		_cast_support_skill(selected, active_skill_id)
		return
	if typ == "buff":
		_cast_buff_skill(selected, active_skill_id)
		return
	# offense: arm for next attack
	skill_mode = true
	attack_mode = true
	move_cells.clear()
	_log("战技已就绪：%s — %s" % [sk.get("name", ""), sk.get("desc", "")])
	_update_skill_hint()
	overlay.queue_redraw()
	_refresh_info()

func _update_skill_hint() -> void:
	if _skill_hint == null:
		return
	if selected >= 0 and selected < units.size() and units[selected].team == "player":
		var parts: Array = []
		for sid in units[selected].char.skills:
			var sk = GameState.get_skill(sid)
			var left = int(units[selected].char.skill_uses.get(sid, 0))
			var cd = int(units[selected].char.skill_cd.get(sid, 0))
			if cd > 0:
				parts.append("%sCD%d" % [sk.get("name", sid), cd])
			else:
				parts.append("%s×%d" % [sk.get("name", sid), left])
		var armed = ""
		if active_skill_id != "":
			armed = "　【将释放：%s】" % GameState.get_skill(active_skill_id).get("name", active_skill_id)
		_skill_hint.text = ("战技：" + " · ".join(parts) if parts else "战技：无") + armed
	else:
		_skill_hint.text = "选中单位后点「战技」循环选择；进攻技在攻击时消耗。"

func _consume_skill(c: CKCharacter, sid: String) -> void:
	var left = int(c.skill_uses.get(sid, 0))
	c.skill_uses[sid] = maxi(0, left - 1)
	var sk = GameState.get_skill(sid)
	c.skill_cd[sid] = int(sk.get("cooldown", 1))
	skill_mode = false
	active_skill_id = ""
	_update_skill_hint()

func _cast_support_skill(ui: int, sid: String) -> void:
	Sfx.skill()
	if Sfx.has_method("heal"):
		Sfx.heal()
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	var healed = 0
	for j in units.size():
		var o = units[j]
		if o.team != "player" or o.char.hp <= 0:
			continue
		if _manhattan(u.pos, o.pos) <= 1:
			var amt = rng.randi_range(int(sk.get("heal_min", 8)), int(sk.get("heal_max", 12)))
			o.char.hp = mini(o.char.max_hp, o.char.hp + amt)
			healed += 1
			_spawn_dmg(o.pos, "+%d" % amt, Color(0.4, 0.9, 0.5))
			_spawn_slash(o.pos, "heal")
	_consume_skill(u.char, sid)
	u.done = true
	selected = -1
	Sfx.confirm()
	_log("%s 释放「%s」，治疗 %d 人" % [u.char.name, sk.get("name", ""), healed])
	map_draw.queue_redraw()
	_refresh_info()
	_check_end()

func _cast_buff_skill(ui: int, sid: String) -> void:
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	if sk.get("def_buff"):
		u.char.temp_def_buff = int(sk.get("def_buff"))
	if sk.get("next_hit_bonus"):
		u.char.temp_hit_bonus = int(sk.get("next_hit_bonus"))
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	if sk.get("self_def_penalty"):
		u.char.temp_def_buff = maxi(-99, u.char.temp_def_buff - int(sk.get("self_def_penalty")))
	_consume_skill(u.char, sid)
	_log("%s 释放「%s」" % [u.char.name, sk.get("name", "")])
	Sfx.confirm()
	_refresh_info()
	map_draw.queue_redraw()

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
	# 双嗣校场：真人子嗣分列双方
	var heir_a_id = str(GameState.get_meta("heir_clash_a", ""))
	var heir_b_id = str(GameState.get_meta("heir_clash_b", ""))
	var is_heir_clash = bool(m.get("heir_clash", false)) or map_id == "ch_heir_clash"
	if is_heir_clash and heir_a_id != "":
		ids = [heir_a_id]
		# 团长 + 花名册支援（最多凑满 player_spots）
		var leader = GameState.get_leader()
		if leader and leader.id != heir_a_id and leader.id != heir_b_id:
			ids.append(leader.id)
		for c in GameState.roster():
			if c.id == heir_a_id or c.id == heir_b_id:
				continue
			if leader and c.id == leader.id:
				continue
			if c.id not in ids:
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
		# 校场临时满血
		if is_heir_clash:
			c.hp = c.max_hp
		units.append({"char": c, "pos": spots[i], "team": "player", "done": false})
		i += 1
	# 双嗣校场：并席/中立敌宅可派援手填我方空位
	if is_heir_clash and i < spots.size():
		var ally_houses: Array = []
		for hid2 in ["qinghe", "lantern", "shuoying"]:
			var st2 = GameState.get_rival_stance(hid2)
			if st2 in ["cordial", "neutral"]:
				ally_houses.append(hid2)
		var ai = 0
		while i < spots.size() and ai < ally_houses.size():
			var ally = CharacterFactory.make_house_support(str(ally_houses[ai]), true, rng)
			units.append({"char": ally, "pos": spots[i], "team": "player", "done": false})
			i += 1
			ai += 1
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
	if is_heir_clash and heir_b_id != "":
		var hb: CKCharacter = GameState.characters.get(heir_b_id)
		if hb and hb.alive and ei < enemy_spots.size():
			hb.hp = hb.max_hp
			units.append({"char": hb, "pos": enemy_spots[ei], "team": "enemy", "done": false})
			ei += 1
		# 敌方支援：敌意/戒备敌宅膀臂优先，否则匪军
		var hostile_houses: Array = []
		for hid in ["shuoying", "qinghe", "lantern"]:
			var st = GameState.get_rival_stance(hid)
			if st in ["hostile", "wary"]:
				hostile_houses.append(hid)
		var si = 0
		var support_tmpls = ["bandit", "bandit_archer", "bandit_weak"]
		while ei < enemy_spots.size():
			var e2: CKCharacter
			if si < hostile_houses.size():
				e2 = CharacterFactory.make_house_support(str(hostile_houses[si]), false, rng)
			else:
				var ti = (si - hostile_houses.size()) % support_tmpls.size()
				e2 = CharacterFactory.make_enemy(str(support_tmpls[ti]), rng)
			units.append({"char": e2, "pos": enemy_spots[ei], "team": "enemy", "done": false})
			ei += 1
			si += 1
	else:
		for ti in templates.size():
			if ei >= enemy_spots.size():
				break
			var e = CharacterFactory.make_enemy(str(templates[ti]), rng)
			if e.appearance.get("hair","") == "" or e.faction == "enemy":
				e.appearance = {"hair": "ink_black", "eyes": "dusk", "brow": "thick", "scar": "cheek"}
			units.append({"char": e, "pos": enemy_spots[ei], "team": "enemy", "done": false})
			ei += 1
	_log("%s：我军 %d · 敌军 %d" % [map_name, i, ei])
	var chars: Array = []
	for u in units:
		if u.team == "player":
			GameState.grant_job_skills(u.char)
			chars.append(u.char)
	GameState.reset_battle_skills(chars)
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
		# CD meters: per-skill pip with initial + fill
		if u.team == "player":
			var cd_items: Array = []
			for sid in u.char.skills:
				var cdv = int(u.char.skill_cd.get(sid, 0))
				var sk = GameState.get_skill(sid)
				var nm = str(sk.get("name", sid))
				var initial = nm.substr(0, 1) if nm.length() > 0 else "?"
				var max_cd = maxf(1.0, float(sk.get("cooldown", 3)))
				cd_items.append({"cd": cdv, "max": max_cd, "ch": initial, "ready": cdv <= 0})
			if cd_items.size() > 0:
				var cd_y = bar_pos.y + 6.0
				var pip_w = 10.0
				var gap = 2.0
				var total_w = cd_items.size() * (pip_w + gap) - gap
				var sx0 = center.x - total_w * 0.5
				for ci in cd_items.size():
					var it = cd_items[ci]
					var sx = sx0 + ci * (pip_w + gap)
					var ready = bool(it["ready"])
					var fill = 1.0 if ready else clampf(1.0 - float(it["cd"]) / float(it["max"]), 0.0, 1.0)
					map_draw.draw_rect(Rect2(Vector2(sx, cd_y), Vector2(pip_w, 11)), Color(0.08, 0.09, 0.12, 0.92))
					var col = Color(0.45, 0.85, 0.55, 0.95) if ready else Color(0.45, 0.65, 0.95, 0.95)
					map_draw.draw_rect(Rect2(Vector2(sx, cd_y + 11 * (1.0 - fill)), Vector2(pip_w, 11 * fill)), col)
					var tcol = Color(0.95, 0.95, 0.9) if ready else Color(0.75, 0.8, 0.9)
					map_draw.draw_string(ThemeDB.fallback_font, Vector2(sx + 1, cd_y + 9), str(it["ch"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tcol)
					if not ready:
						map_draw.draw_string(ThemeDB.fallback_font, Vector2(sx + 2, cd_y - 1), str(int(it["cd"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.85, 0.4))
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
		var kind = str(s.get("kind", "slash"))
		var path = "res://assets/art/fx/%s_%d.png" % [kind, fi]
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/slash_%d.png" % fi
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
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	_refresh_info()
	_update_skill_hint()
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
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	var mv = units[ui].char.derived_move()
	move_cells = BattleRules.move_costs(terrain, units[ui].pos, mv)
	for u in units:
		if u.char.hp > 0 and u.pos != units[ui].pos:
			move_cells.erase(u.pos)
	_refresh_info()
	_update_skill_hint()
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

func _spawn_slash(cell: Vector2i, kind: String = "slash") -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_slash_fx.append({"pos": center, "age": 0.0, "kind": kind})
	_shake = 3.5

func _do_attack(ai: int, di: int) -> void:
	var atk = units[ai]
	var def = units[di]
	var tid = terrain[def.pos.y][def.pos.x]
	var skill_id = ""
	var sk = {}
	if atk.team == "player" and skill_mode and active_skill_id != "":
		skill_id = active_skill_id
		sk = GameState.get_skill(skill_id)
		if sk.get("ignore_terrain_avo"):
			tid = "plain"
	var result = BattleRules.roll_attack(atk.char, def.char, tid, rng)
	if skill_id != "" and sk.get("type") == "offense":
		# adjust hit/damage post-roll presentation; re-roll with mods if needed
		var hit_chance = BattleRules.calc_hit(atk.char, def.char, tid) + int(sk.get("hit_mod", 0))
		hit_chance = clampi(hit_chance, 5, 99)
		var hit = rng.randi_range(1, 100) <= hit_chance
		var dmg_range = BattleRules.calc_damage_range(atk.char, def.char)
		var dmg = 0
		var crit = false
		if hit:
			dmg = rng.randi_range(dmg_range.x, dmg_range.y)
			dmg = int(round(dmg * float(sk.get("dmg_mul", 1.0))))
			if rng.randi_range(1, 100) <= atk.char.derived_crit():
				crit = true
				Sfx.crit()
				_spawn_slash(def.pos, "crit")
				dmg = int(dmg * 1.5)
			# undo previous roll damage if any
			if result.hit:
				def.char.hp = mini(def.char.max_hp, def.char.hp + int(result.damage))
			def.char.hp = maxi(0, def.char.hp - dmg)
		elif result.hit:
			def.char.hp = mini(def.char.max_hp, def.char.hp + int(result.damage))
		result = {"hit": hit, "crit": crit, "damage": dmg, "hit_chance": hit_chance, "dmg_range": dmg_range, "killed": def.char.hp <= 0}
		_consume_skill(atk.char, skill_id)
		_log("战技「%s」！" % sk.get("name", skill_id))
	# clear one-shot hit bonus after any attack
	if atk.char.temp_hit_bonus != 0:
		atk.char.temp_hit_bonus = 0
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
	var pcs: Array = []
	for u in units:
		if u.team == "player":
			u.done = false
			# 铁壁姿态持续到己方下回合开始时清除
			u.char.temp_def_buff = 0
			pcs.append(u.char)
	GameState.tick_skill_cooldowns(pcs)
	selected = -1
	move_cells.clear()
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_update_skill_hint()

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
		if not bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)):
			Sfx.fanfare()
		_log("【胜利】%s肃清。+35 银。" % map_name)
		_mark_map_victory()
		if not bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)):
			GameState.add_skill_point(1)
			_log("获得战技点 +1（当前 %d）" % GameState.skill_points)
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
	elif map_id == "ch3_forge":
		GameState.set_flag("ch3_forge_done")
	elif map_id == "ch3_shrine":
		GameState.set_flag("ch3_shrine_done")
	elif map_id == "ch4_gate":
		GameState.set_flag("ch4_gate_done")
	elif map_id == "ch5_river":
		GameState.set_flag("ch5_river_done")
	elif map_id == "ch5_feast":
		GameState.set_flag("ch5_feast_done")
	elif map_id == "ch5_bridge":
		GameState.set_flag("ch5_bridge_done")
	elif map_id == "ch6_archive":
		GameState.set_flag("ch6_archive_done")
	elif map_id == "ch6_redoubt":
		GameState.set_flag("ch6_redoubt_done")
	elif map_id == "ch6_bloodseal":
		GameState.set_flag("ch6_bloodseal_done")
	elif map_id == "ch7_field":
		GameState.set_flag("ch7_field_done")
	elif map_id == "ch8_harbor":
		GameState.set_flag("ch8_harbor_done")
	elif map_id == "ch8_quay":
		GameState.set_flag("ch8_quay_done")
	elif map_id == "ch8_treaty":
		GameState.set_flag("ch8_treaty_done")
	elif map_id == "ch9_caravan":
		GameState.set_flag("ch9_caravan_done")
	elif map_id == "ch10_echo":
		GameState.set_flag("ch10_echo_done")
	elif map_id == "ch10_banner":
		GameState.set_flag("ch10_banner_done")
	elif map_id == "ch10_seal":
		GameState.set_flag("ch10_seal_done")
	elif map_id == "ch11_gate":
		GameState.set_flag("ch11_gate_done")
	elif map_id == "ch12_granary":
		GameState.set_flag("ch12_granary_done")
	elif map_id == "ch12_ambush":
		GameState.set_flag("ch12_ambush_done")
	elif map_id == "ch12_rival":
		GameState.set_flag("ch12_rival_done")
	elif map_id == "ch13_heir":
		GameState.set_flag("ch13_heir_done")
	elif map_id == "ch14_torch":
		GameState.set_flag("ch14_torch_done")
	elif map_id == "ch14_margin":
		GameState.set_flag("ch14_margin_done")
	elif map_id == "ch14_cohold":
		GameState.set_flag("ch14_cohold_done")
	elif map_id == "ch15_finale":
		GameState.set_flag("ch15_finale_done")
	elif map_id == "ch_heir_clash":
		GameState.set_flag("ch_heir_clash_done")
		_restore_heir_clash_hp()  # heir_clash_restore
	elif map_id == "ch16_sea":
		GameState.set_flag("ch16_sea_done")
	elif map_id == "ch16_grass":
		GameState.set_flag("ch16_grass_done")
	elif map_id == "ch16_beacon":
		GameState.set_flag("ch16_beacon_done")
	elif map_id == "ch17_ford":
		GameState.set_flag("ch17_ford_done")
	elif map_id == "ch17_keep":
		GameState.set_flag("ch17_keep_done")
	elif map_id == "ch18_gate":
		GameState.set_flag("ch18_gate_done")
	elif map_id == "ch19_shore":
		GameState.set_flag("ch19_shore_done")
	elif map_id == "ch19_reef":
		GameState.set_flag("ch19_reef_done")
	elif map_id == "ch19_isle":
		GameState.set_flag("ch19_isle_done")
	elif map_id == "ch20_wall":
		GameState.set_flag("ch20_wall_done")
	elif map_id == "ch20_spire":
		GameState.set_flag("ch20_spire_done")
	elif map_id == "ch21_finale":
		GameState.set_flag("ch21_finale_done")
	elif map_id == "ch22_pass":
		GameState.set_flag("ch22_pass_done")
	elif map_id == "ch22_camp":
		GameState.set_flag("ch22_camp_done")
	elif map_id == "ch23_frost":
		GameState.set_flag("ch23_frost_done")
	elif map_id == "ch23_watch":
		GameState.set_flag("ch23_watch_done")
	elif map_id == "ch24_seal":
		GameState.set_flag("ch24_seal_done")
	elif map_id == "ch25_plain":
		GameState.set_flag("ch25_plain_done")
	elif map_id == "ch25_ridge":
		GameState.set_flag("ch25_ridge_done")
	elif map_id == "ch26_snow":
		GameState.set_flag("ch26_snow_done")
	elif map_id == "ch26_peak":
		GameState.set_flag("ch26_peak_done")
	elif map_id == "ch27_finale":
		GameState.set_flag("ch27_finale_done")
	elif map_id == "ch28_marsh":
		GameState.set_flag("ch28_marsh_done")
	elif map_id == "ch28_ferry":
		GameState.set_flag("ch28_ferry_done")
	elif map_id == "ch29_field":
		GameState.set_flag("ch29_field_done")
	elif map_id == "ch29_barn":
		GameState.set_flag("ch29_barn_done")
	elif map_id == "ch30_seal":
		GameState.set_flag("ch30_seal_done")
	elif map_id == "ch31_gorge":
		GameState.set_flag("ch31_gorge_done")
	elif map_id == "ch31_forge":
		GameState.set_flag("ch31_forge_done")
	elif map_id == "ch32_star":
		GameState.set_flag("ch32_star_done")
	elif map_id == "ch32_tower":
		GameState.set_flag("ch32_tower_done")
	elif map_id == "ch33_finale":
		GameState.set_flag("ch33_finale_done")
	elif map_id == "ch34_dawn":
		GameState.set_flag("ch34_dawn_done")
	elif map_id == "ch34_cross":
		GameState.set_flag("ch34_cross_done")
	elif map_id == "ch35_bell":
		GameState.set_flag("ch35_bell_done")
	elif map_id == "ch35_keep":
		GameState.set_flag("ch35_keep_done")
	elif map_id == "ch36_seal":
		GameState.set_flag("ch36_seal_done")
	elif map_id == "ch37_plain":
		GameState.set_flag("ch37_plain_done")
	elif map_id == "ch37_ridge":
		GameState.set_flag("ch37_ridge_done")
	elif map_id == "ch38_gate":
		GameState.set_flag("ch38_gate_done")
	elif map_id == "ch38_hall":
		GameState.set_flag("ch38_hall_done")
	elif map_id == "ch39_finale":
		GameState.set_flag("ch39_finale_done")
	elif map_id == "ch40_mist":
		GameState.set_flag("ch40_mist_done")
	elif map_id == "ch40_ford":
		GameState.set_flag("ch40_ford_done")
	elif map_id == "ch41_cairn":
		GameState.set_flag("ch41_cairn_done")
	elif map_id == "ch41_vault":
		GameState.set_flag("ch41_vault_done")
	elif map_id == "ch42_seal":
		GameState.set_flag("ch42_seal_done")
	elif map_id == "ch43_tide":
		GameState.set_flag("ch43_tide_done")
	elif map_id == "ch43_reef":
		GameState.set_flag("ch43_reef_done")
	elif map_id == "ch44_tower":
		GameState.set_flag("ch44_tower_done")
	elif map_id == "ch44_spire":
		GameState.set_flag("ch44_spire_done")
	elif map_id == "ch45_finale":
		GameState.set_flag("ch45_finale_done")
	elif map_id == "ch46_ember":
		GameState.set_flag("ch46_ember_done")
	elif map_id == "ch46_ash":
		GameState.set_flag("ch46_ash_done")
	elif map_id == "ch47_crown":
		GameState.set_flag("ch47_crown_done")
	elif map_id == "ch47_hearth":
		GameState.set_flag("ch47_hearth_done")
	elif map_id == "ch48_seal":
		GameState.set_flag("ch48_seal_done")
	elif map_id == "ch49_cinder":
		GameState.set_flag("ch49_cinder_done")
	elif map_id == "ch49_kiln":
		GameState.set_flag("ch49_kiln_done")
	elif map_id == "ch50_gate":
		GameState.set_flag("ch50_gate_done")
	elif map_id == "ch50_hall":
		GameState.set_flag("ch50_hall_done")
	elif map_id == "ch51_finale":
		GameState.set_flag("ch51_finale_done")
	elif map_id == "ch52_dawn":
		GameState.set_flag("ch52_dawn_done")
	elif map_id == "ch52_bridge":
		GameState.set_flag("ch52_bridge_done")
	elif map_id == "ch53_mirror":
		GameState.set_flag("ch53_mirror_done")
	elif map_id == "ch53_isle":
		GameState.set_flag("ch53_isle_done")
	elif map_id == "ch54_seal":
		GameState.set_flag("ch54_seal_done")
	elif map_id == "ch55_gale":
		GameState.set_flag("ch55_gale_done")
	elif map_id == "ch55_pass":
		GameState.set_flag("ch55_pass_done")
	elif map_id == "ch56_court":
		GameState.set_flag("ch56_court_done")
	elif map_id == "ch56_throne":
		GameState.set_flag("ch56_throne_done")
	elif map_id == "ch57_finale":
		GameState.set_flag("ch57_finale_done")
	elif map_id == "ch58_ember":
		GameState.set_flag("ch58_ember_done")
	elif map_id == "ch58_tide":
		GameState.set_flag("ch58_tide_done")
	elif map_id == "ch59_frost":
		GameState.set_flag("ch59_frost_done")
	elif map_id == "ch59_night":
		GameState.set_flag("ch59_night_done")
	elif map_id == "ch60_seal":
		GameState.set_flag("ch60_seal_done")
	elif map_id == "ch61_ash":
		GameState.set_flag("ch61_ash_done")
	elif map_id == "ch61_banner":
		GameState.set_flag("ch61_banner_done")
	elif map_id == "ch62_court":
		GameState.set_flag("ch62_court_done")
	elif map_id == "ch62_throne":
		GameState.set_flag("ch62_throne_done")
	elif map_id == "ch63_finale":
		GameState.set_flag("ch63_finale_done")
	elif map_id == "ch64_canal":
		GameState.set_flag("ch64_canal_done")
	elif map_id == "ch64_bazaar":
		GameState.set_flag("ch64_bazaar_done")
	elif map_id == "ch65_bell":
		GameState.set_flag("ch65_bell_done")
	elif map_id == "ch65_mute":
		GameState.set_flag("ch65_mute_done")
	elif map_id == "ch66_wellseal":
		GameState.set_flag("ch66_wellseal_done")
	elif map_id == "ch67_salt":
		GameState.set_flag("ch67_salt_done")
	elif map_id == "ch67_wharf":
		GameState.set_flag("ch67_wharf_done")
	elif map_id == "ch68_paper":
		GameState.set_flag("ch68_paper_done")
	elif map_id == "ch68_ink":
		GameState.set_flag("ch68_ink_done")
	elif map_id == "ch69_finale":
		GameState.set_flag("ch69_finale_done")
	elif map_id == "ch70_kiln":
		GameState.set_flag("ch70_kiln_done")
	elif map_id == "ch70_sagger":
		GameState.set_flag("ch70_sagger_done")
	elif map_id == "ch71_glaze":
		GameState.set_flag("ch71_glaze_done")
	elif map_id == "ch71_bisque":
		GameState.set_flag("ch71_bisque_done")
	elif map_id == "ch72_kilnseal":
		GameState.set_flag("ch72_kilnseal_done")
	elif map_id == "ch73_chimney":
		GameState.set_flag("ch73_chimney_done")
	elif map_id == "ch73_kilngod":
		GameState.set_flag("ch73_kilngod_done")
	elif map_id == "ch74_hearth":
		GameState.set_flag("ch74_hearth_done")
	elif map_id == "ch74_cool":
		GameState.set_flag("ch74_cool_done")
	elif map_id == "ch75_finale":
		GameState.set_flag("ch75_finale_done")
	elif map_id == "ch76_stage":
		GameState.set_flag("ch76_stage_done")
	elif map_id == "ch76_gallery":
		GameState.set_flag("ch76_gallery_done")
	elif map_id == "ch77_check":
		GameState.set_flag("ch77_check_done")
	elif map_id == "ch77_drum":
		GameState.set_flag("ch77_drum_done")
	elif map_id == "ch78_playseal":
		GameState.set_flag("ch78_playseal_done")
	elif map_id == "ch79_backstage":
		GameState.set_flag("ch79_backstage_done")
	elif map_id == "ch79_mirror":
		GameState.set_flag("ch79_mirror_done")
	elif map_id == "ch80_lamps":
		GameState.set_flag("ch80_lamps_done")
	elif map_id == "ch80_curtain":
		GameState.set_flag("ch80_curtain_done")
	elif map_id == "ch81_finale":
		GameState.set_flag("ch81_finale_done")
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


func _restore_heir_clash_hp() -> void:
	for key in ["heir_clash_a", "heir_clash_b"]:
		var cid = str(GameState.get_meta(key, ""))
		if cid == "":
			continue
		var c: CKCharacter = GameState.characters.get(cid)
		if c:
			c.hp = c.max_hp
			c.alive = true
	GameState.add_lineage_event("双嗣校场终了：双方回堡养伤，名册旁注已更新。")
	GameState.clear_meta("heir_clash_a")
	GameState.clear_meta("heir_clash_b")
