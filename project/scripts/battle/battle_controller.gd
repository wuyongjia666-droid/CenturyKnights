extends Control

signal unit_downed(char, info)
signal battle_finished(result)
## 灰旗战棋：8x6 教程图，移动/攻击/待命，敌 AI，规则透视
## 输入 FSM：IDLE → SELECTED → (MOVE) → ATTACK_AIM → 单位 done

var CELL: int = 56
var ORIGIN: Vector2 = Vector2(40, 80)
## v8.6: the board is the hero — cell size fits the map into the left stage (max 104px)
const BOARD_AREA := Rect2(24, 76, 856, 620)
const RAIL_X := 904.0
const RAIL_W := 352.0
var _ground: ColorRect
## v8.6 3D combat cutscenes: pure recorder (tactics logic untouched) -> queued overlay playback
const CombatCutsceneScript = preload("res://scripts/battle/combat_cutscene.gd")
var _combat_rec: Array = []
var _cut_queue: Array = []
var _cut_playing := false
const TERRAIN_IDS := {"plain": 0, "forest": 1, "hill": 2, "water": 3, "fort": 4, "bridge": 5}
var MAP_W: int = 8
var MAP_H: int = 6
var map_id: String = "ch0_pass"
var map_name: String = "隘口之夜"

var terrain: Array = []
var height_grid: Array = []
var weather: String = "clear"
var scout_map: bool = false
var interactives: Array = []
var _fx_marks: Array = []
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
var _zoc_hover_kind: String = ""  # "", "lock3", "leave2", "zoc"
var _banner_tex: TextureRect
var _unit_panel: PanelContainer
var _portrait: TextureRect
const UnitCardScript = preload("res://scripts/ui/unit_card.gd")
var _unit_card: Control
## v8.5 authored FX draw sizes (px) — 56px cells; 128px sources downsampled for crisp reads
const FX_SIZE := {"slash": 80.0, "heal": 84.0, "crit": 108.0, "lock": 80.0, "shield": 80.0, "spark": 76.0}
var _info_traits: HBoxContainer
var _dmg_fx: Array = []  # {pos, text, age, col}
var _turn_flash: float = 0.0
var _round_no: int = 0
var _round_label: Label
var _phase_chip: Label
var _sel_pulse: float = 0.0
var _btn_atk: Button
var _btn_wait: Button
var _btn_end: Button
var _slash_fx: Array = []  # {pos, age, frame}
var _lock_burst_fx: Array = []  # {pos, age}
var _move_dust_fx: Array = []  # {pos, age}
var _shake: float = 0.0
var _trauma: float = 0.0  # game-feel trauma 0..1
var _shake_t: float = 0.0
var skill_mode: bool = false
var active_skill_id: String = ""
var _banter_idx: int = 0
var _banter_pack: Dictionary = {}
var _banter_kill: int = 0
var _banter_played: Dictionary = {}
var _btn_skill: Button
var _skill_hint: Label
var _board_router := InputRouter.new()
var _board_xform: Node2D
var _board_pan := Vector2.ZERO
var _board_zoom := 1.0
var _mobile_layer: CanvasLayer
var _mobile_bar: PanelContainer
var danger_on := false
var danger_focus := -1
var _btn_danger: CheckButton
var _lamp_charges := 0
var _lamp_max := 0
var _lamp_refill := false
var _lamps_armed := false
var _lamp_stack: Array = []
var _turn_snap: Dictionary = {}
var _move_undo: Dictionary = {}


func _map_theme() -> String:
	return str(BattleMaps.get_map(map_id).get("theme", ""))

func _is_escort_map() -> bool:
	return _map_theme() == "escort"

func _is_harbor_map() -> bool:
	return _map_theme() == "harbor"

func _banter_table() -> Dictionary:
	if not _banter_pack.is_empty():
		return _banter_pack
	var f := FileAccess.open("res://data/battle_banter.json", FileAccess.READ)
	if f == null:
		return _banter_pack
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_banter_pack = parsed
	return _banter_pack

func _play_banter_sfx(method: String) -> void:
	if method == "" or not Sfx.has_method(method):
		return
	Sfx.call(method)

func _theme_banter(kind: String) -> void:
	var theme := _map_theme()
	var themes: Dictionary = _banter_table().get("themes", {})
	if not themes.has(theme):
		return
	var key := theme + kind + str(_banter_idx if kind == "turn" else _banter_kill)
	if _banter_played.has(key):
		return
	var pack: Dictionary = themes[theme]
	var pool: Array = pack.get(kind, [])
	if pool.is_empty():
		return
	var line := ""
	if kind == "turn":
		line = str(pool[_banter_idx % pool.size()])
		_banter_idx += 1
	elif kind == "kill":
		line = str(pool[_banter_kill % pool.size()])
		_banter_kill += 1
		_play_banter_sfx(str(pack.get("kill_sfx", "")))
	else:
		line = str(pool[0] if _banter_idx == 0 else pool[mini(1, pool.size() - 1)])
		_play_banter_sfx(str(pack.get("start_sfx", "")))
	_banter_played[key] = true
	_log(line)


func _escort_banter(kind: String) -> void:
	_theme_banter(kind)

func _ready() -> void:
	CKAutosave.before_battle()
	rng.randomize()
	Music.play_battle()
	# v8 biome battle plate (fallback legacy backdrop)
	var _AtlasArt = preload("res://scripts/art/atlas_art.gd")
	var _bb_path: String = str(_AtlasArt.battle_backdrop_for_map(str(GameState.get_meta("battle_map", map_id))))
	if _bb_path != "":
		var bbg := TextureRect.new()
		bbg.texture = load(_bb_path)
		bbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bbg.stretch_mode = TextureRect.STRETCH_SCALE
		bbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bbg.z_index = -8
		bbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bbg.modulate = Color(0.55, 0.62, 0.72, 0.30)
		add_child(bbg)
		move_child(bbg, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_init_map()
	Sfx.play_ambience(AtlasArt.biome_for_map(map_id))
	_deploy()
	_start_player_turn()
	queue_redraw()
	set_process(true)

func _ui_origin() -> Vector2:
	if has_meta("mobile_origin"):
		return get_meta("mobile_origin")
	return Vector2.ZERO

func _process(delta: float) -> void:
	if _board_router:
		for g in _board_router.poll(Time.get_ticks_msec()):
			_apply_board_gesture(g)
	UnitArt.tick(delta)
	_sel_pulse += delta
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
		if s.age < 0.48:
			alive_s.append(s)
	_slash_fx = alive_s
	var alive_lb: Array = []
	for lb in _lock_burst_fx:
		lb.age += delta
		if lb.age < 0.55:
			alive_lb.append(lb)
	_lock_burst_fx = alive_lb
	var alive_md: Array = []
	for md in _move_dust_fx:
		md.age += delta
		if md.age < 0.4:
			alive_md.append(md)
	_move_dust_fx = alive_md
	# Trauma shake（二次曲线，非每帧乱抖）
	if _shake > 0.0:
		_trauma = clampf(_trauma + _shake * 0.08, 0.0, 1.0)
		_shake = 0.0
	var origin := _ui_origin()
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.35)
		var shake = _trauma * _trauma * UIKit.shake_gain()
		_shake_t += delta * 30.0
		position = origin + Vector2(10.0 * shake * sin(_shake_t * 1.7), 7.0 * shake * sin(_shake_t * 2.3))
	else:
		position = origin
	if overlay:
		overlay.queue_redraw()
	if map_draw and _sel_pulse:
		map_draw.queue_redraw()
	_sync_faction_marks()

## v8.5: texture cache. A texture load()ed for the first time inside _draw records as a
## white placeholder on the GL renderer (seen in real renders) — warm FX here, cache everything.
var _tex_cache: Dictionary = {}

func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

func _warm_fx_cache() -> void:
	var kinds := ["hit", "slash", "heal", "crit", "lock", "shield", "spark", "dmg_pop", "turn_flash", "zoc_pulse", "select"]
	for k in kinds:
		for i in range(8):
			_tex("res://assets/art/fx/%s_dense_%d.png" % [k, i])
			_tex("res://assets/art/fx/%s_%d.png" % [k, i])
	for i in range(6):
		_tex("res://assets/art/fx/hit_spark_%d.png" % i)
		_tex("res://assets/art/fx/move_dust_%d.png" % i)
	for w in ["select_wash", "move_wash", "attack_wash"]:
		_tex("res://assets/art/fx/%s.png" % w)
	for u in ["zoc_hatch_safe", "zoc_hatch_zoc", "zoc_hatch_leave", "zoc_hatch_lock", "zoc_chip_lock3", "zoc_chip_leave2", "zoc_leave_legend"]:
		_tex("res://assets/art/ui/%s.png" % u)

func _k() -> float:
	return float(CELL) / 56.0

func _build_ui() -> void:
	## v8.6 layout (Stitch 06 战棋战斗 HUD): board stage left (hero), thin turn bar on top,
	## right rail = selected-unit card · intel · compact log · command console. Nothing floats on the board.
	_warm_fx_cache()
	_bg = ColorRect.new()
	_bg.color = Color(UIKit.BG, 0.72)
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	add_child(UIKit._vignette())

	# v8.6 Stitch 06 turn pill: ◉ 第 N 回合 │ PHASE 01 │ map · 我方行动 — then controls hint
	var pill := PanelContainer.new()
	var pst := UIKit.flat_box(Color(0.04, 0.05, 0.07, 0.88), Color(1, 1, 1, 0.14), 20)
	pst.content_margin_left = 14
	pst.content_margin_right = 18
	pst.content_margin_top = 6
	pst.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", pst)
	pill.position = Vector2(24, 14)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(top)
	var dot := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = UIKit.ACCENT
	dsb.set_corner_radius_all(4)
	dsb.shadow_color = Color(UIKit.ACCENT, 0.6)
	dsb.shadow_size = 5
	dot.add_theme_stylebox_override("panel", dsb)
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(dot)
	UIFX.breathe(dot, 0.2, 1.6)
	_round_label = Label.new()
	_round_label.text = Locale.t("shell_593b489a")
	_round_label.add_theme_font_override("font", UIKit.font("bold"))
	_round_label.add_theme_font_size_override("font_size", 16)
	_round_label.add_theme_color_override("font_color", UIKit.TEXT)
	top.add_child(_round_label)
	var vs := ColorRect.new()
	vs.color = Color(1, 1, 1, 0.14)
	vs.custom_minimum_size = Vector2(1, 18)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(vs)
	_phase_chip = UIKit.tag_chip("PHASE 01", UIKit.ACCENT)
	top.add_child(_phase_chip)
	phase_label = Label.new()
	phase_label.text = Locale.t("shell_d95adbd6")
	phase_label.add_theme_font_size_override("font_size", 16)
	phase_label.add_theme_color_override("font_color", UIKit.TEXT)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(phase_label)
	var tip_text := Locale.t("shell_8ed10247")
	if DeviceProfile.is_mobile():
		tip_text = Locale.t("shell_f4b70638")
	var tip = UIKit.mono(tip_text, 9, UIKit.TEXT_FAINT, false)
	tip.position = Vector2(26, 58)
	tip.name = "ControlsTip"
	add_child(tip)

	_board_xform = Node2D.new()
	_board_xform.name = "BoardXform"
	add_child(_board_xform)
	_ground = ColorRect.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_xform.add_child(_ground)

	map_draw = Node2D.new()
	map_draw.draw.connect(_draw_map)
	_board_xform.add_child(map_draw)

	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	_board_xform.add_child(overlay)

	# --- right rail
	_unit_panel = UIKit.make_panel()
	_unit_panel.position = Vector2(RAIL_X, 76)
	_unit_panel.custom_minimum_size = Vector2(RAIL_W, 0)
	_unit_panel.size = Vector2(RAIL_W, 0)
	add_child(_unit_panel)
	var left_info := VBoxContainer.new()
	left_info.add_theme_constant_override("separation", 12)
	_unit_panel.add_child(left_info)
	_unit_card = UnitCardScript.new(RAIL_W - 44.0)
	left_info.add_child(_unit_card)
	_portrait = _unit_card.portrait
	_info_traits = HBoxContainer.new()
	_info_traits.add_theme_constant_override("separation", 4)
	left_info.add_child(_info_traits)
	left_info.add_child(UIKit.hairline())
	info_label = RichTextLabel.new()
	info_label.custom_minimum_size = Vector2(RAIL_W - 44.0, 0)
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_color_override("default_color", UIKit.TEXT_DIM)
	info_label.add_theme_font_size_override("normal_font_size", 12)
	info_label.add_theme_font_size_override("bold_font_size", 13)
	left_info.add_child(info_label)

	var log_panel = UIKit.make_glass(12, 0.55)
	log_panel.name = "LogPanel"
	log_panel.position = Vector2(RAIL_X, 470)
	log_panel.custom_minimum_size = Vector2(RAIL_W, 96)
	log_panel.size = Vector2(RAIL_W, 96)
	log_panel.clip_contents = true
	add_child(log_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	log_panel.add_child(lv)
	lv.add_child(UIKit.eyebrow(Locale.t("shell_9ca5135f"), UIKit.TEXT_FAINT))
	log_label = Label.new()
	log_label.custom_minimum_size = Vector2(RAIL_W - 44, 44)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.clip_text = true
	log_label.max_lines_visible = 3
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	lv.add_child(log_label)

	# command console
	_skill_hint = UIKit.make_dim_label("")
	_skill_hint.position = Vector2(RAIL_X + 2, 578)
	_skill_hint.custom_minimum_size = Vector2(RAIL_W, 18)
	_skill_hint.size = Vector2(RAIL_W, 18)
	_skill_hint.clip_text = true
	_skill_hint.add_theme_font_size_override("font_size", 12)
	add_child(_skill_hint)
	var row := HBoxContainer.new()
	row.name = "CommandRow"
	row.position = Vector2(RAIL_X, 602)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_btn_atk = UIKit.make_button(Locale.t("shell_atk_q"), 112)
	_btn_atk.pressed.connect(_enter_attack_mode)
	row.add_child(_btn_atk)
	_btn_skill = UIKit.make_button(Locale.t("shell_art_w"), 112)
	_btn_skill.pressed.connect(_cycle_skill)
	row.add_child(_btn_skill)
	_btn_wait = UIKit.make_button("%s   E" % Locale.t("wait"), 112)
	_btn_wait.pressed.connect(_wait_selected)
	row.add_child(_btn_wait)
	var row2 := HBoxContainer.new()
	row2.name = "CommandRow2"
	row2.position = Vector2(RAIL_X, 648)
	row2.add_theme_constant_override("separation", 8)
	add_child(row2)
	_btn_end = UIKit.make_accent_button("%s   ⏎\nEND PLAYER TURN" % Locale.t("end_turn"), 232)
	_btn_end.custom_minimum_size = Vector2(232, 52)
	_btn_end.add_theme_font_size_override("font_size", 14)
	UIKit.compact(_btn_end, 30)
	var eglow: StyleBoxFlat = (_btn_end.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	eglow.shadow_color = Color(UIKit.ACCENT, 0.35)
	eglow.shadow_size = 14
	_btn_end.add_theme_stylebox_override("normal", eglow)
	_btn_end.pressed.connect(_end_player_turn)
	row2.add_child(_btn_end)
	var toggles := VBoxContainer.new()
	toggles.name = "RuleToggles"
	toggles.add_theme_constant_override("separation", 0)
	toggles.custom_minimum_size = Vector2(112, 52)
	row2.add_child(toggles)
	var b_prev = CheckButton.new()
	b_prev.text = Locale.t("rules_preview")
	b_prev.clip_text = true
	b_prev.custom_minimum_size = Vector2(112, 24)
	b_prev.add_theme_font_size_override("font_size", 11)
	b_prev.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	b_prev.button_pressed = BattleRules.preview_enabled
	b_prev.toggled.connect(func(on): BattleRules.preview_enabled = on)
	toggles.add_child(b_prev)
	_btn_danger = CheckButton.new()
	_btn_danger.text = BattleObjectives.text("danger_toggle")
	_btn_danger.clip_text = true
	_btn_danger.custom_minimum_size = Vector2(112, 24)
	_btn_danger.add_theme_font_size_override("font_size", 11)
	_btn_danger.add_theme_color_override("font_color", UIKit.DANGER)
	_btn_danger.toggled.connect(_on_danger_toggled)
	toggles.add_child(_btn_danger)
	if DeviceProfile.is_mobile():
		row.visible = false
		row2.visible = false
	_build_mobile_bar()
	_apply_board_xform()
	ObjectiveHud.attach(self)
	ForecastPanel.attach(self)
	RewindBar.attach(self)

func _command_bar_px() -> float:
	if not DeviceProfile.is_mobile():
		return 0.0
	return DeviceProfile.hit_px() + 16.0

func _layout_board() -> void:
	var area := BOARD_AREA
	if DeviceProfile.is_mobile() and is_inside_tree():
		var vp := get_viewport().get_visible_rect().size
		var sy := scale.y if scale.y > 0.01 else 1.0
		var bottom_inset := 0.0
		if has_meta("mobile_insets"):
			bottom_inset = float((get_meta("mobile_insets") as Dictionary).get("bottom", 0.0))
		var bar_top_local := (vp.y - bottom_inset - _command_bar_px() - global_position.y) / sy
		if bar_top_local < area.end.y:
			area.size.y = maxf(280.0, bar_top_local - area.position.y - 8.0)
	CELL = int(clampf(floorf(minf(area.size.x / float(MAP_W), area.size.y / float(MAP_H))), 44.0, 104.0))
	var bs := Vector2(MAP_W, MAP_H) * CELL
	ORIGIN = (area.position + (area.size - bs) * 0.5).floor()
	_build_ground()

func _biome_ground() -> Array:
	## [base texture id, grade]
	var _AtlasArt = preload("res://scripts/art/atlas_art.gd")
	var bio := str(_AtlasArt.biome_for_map(map_id))
	match bio:
		"snow":
			return ["snow", Vector3(0.92, 0.97, 1.04)]
		"archive", "forge", "fort", "urban", "shrine":
			return ["stone", Vector3(0.96, 0.98, 1.03)]
		"harbor":
			return ["stone", Vector3(0.90, 0.98, 1.05)]
		"pass", "hill":
			return ["dust", Vector3(0.97, 0.98, 1.02)]
		"nightcamp":
			return ["dust", Vector3(0.74, 0.80, 0.96)]
		"fog":
			return ["grass", Vector3(0.88, 0.94, 1.02)]
		"marsh":
			return ["grass", Vector3(0.90, 1.0, 0.96)]
	return ["grass", Vector3(0.96, 1.0, 1.02)]

func _build_ground() -> void:
	if _ground == null:
		return
	var sh = load("res://shaders/board_ground.gdshader")
	if sh == null:
		return
	var img := Image.create(MAP_W, MAP_H, false, Image.FORMAT_R8)
	for y in MAP_H:
		for x in MAP_W:
			var tid := str(terrain[y][x]) if y < terrain.size() and x < terrain[y].size() else "plain"
			img.set_pixel(x, y, Color(float(int(TERRAIN_IDS.get(tid, 0)) * 32) / 255.0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var bg: Array = _biome_ground()
	var tdir := "res://assets/art/terrain_v86/"
	mat.set_shader_parameter("t_base", load(tdir + str(bg[0]) + ".png"))
	mat.set_shader_parameter("t_forest", load(tdir + "forest.png"))
	mat.set_shader_parameter("t_hill", load(tdir + "hill.png"))
	mat.set_shader_parameter("t_water", load(tdir + "water.png"))
	mat.set_shader_parameter("t_fort", load(tdir + "fort.png"))
	mat.set_shader_parameter("t_bridge", load(tdir + "bridge.png"))
	mat.set_shader_parameter("t_noise", load(tdir + "noise.png"))
	mat.set_shader_parameter("idmap", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("grid", Vector2(MAP_W, MAP_H))
	mat.set_shader_parameter("cell_px", float(CELL))
	mat.set_shader_parameter("grade", bg[1])
	_ground.material = mat
	_ground.position = ORIGIN
	_ground.size = Vector2(MAP_W, MAP_H) * CELL
	# soft drop shadow + 1px stroke around the board stage
	var host: Node = _board_xform if _board_xform else self
	var sh_node := host.get_node_or_null("BoardFrame")
	if sh_node:
		sh_node.queue_free()
	var frame := Panel.new()
	frame.name = "BoardFrame"
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = UIKit.STROKE
	fs.set_border_width_all(1)
	fs.set_corner_radius_all(4)
	fs.shadow_color = Color(0, 0, 0, 0.55)
	fs.shadow_size = 28
	fs.shadow_offset = Vector2(0, 12)
	fs.expand_margin_left = 1
	fs.expand_margin_right = 1
	fs.expand_margin_top = 1
	fs.expand_margin_bottom = 1
	frame.add_theme_stylebox_override("panel", fs)
	frame.position = ORIGIN
	frame.size = _ground.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	host.move_child(frame, _ground.get_index())

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
	if sk.get("ignore_zoc"):
		su.char.temp_ignore_zoc = true
		if not moved_this_select:
			move_cells = _compute_move_cells(selected)
			attack_mode = false
			_log("破控冲锋就绪：可无视控制地带移动后再攻击 — %s" % sk.get("desc", ""))
		else:
			move_cells.clear()
			_log("战技已就绪：%s — %s" % [sk.get("name", ""), sk.get("desc", "")])
	else:
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
		_skill_hint.text = Locale.t("shell_94db6f97")

func _consume_skill(c: CKCharacter, sid: String) -> void:
	var left = int(c.skill_uses.get(sid, 0))
	c.skill_uses[sid] = maxi(0, left - 1)
	var sk = GameState.get_skill(sid)
	c.skill_cd[sid] = int(sk.get("cooldown", 1))
	skill_mode = false
	active_skill_id = ""
	_update_skill_hint()

func _cast_support_skill(ui: int, sid: String) -> void:
	_push_lamp()
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
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
		_spawn_dmg(u.pos, "圣域", Color(0.7, 0.85, 1.0))
	_consume_skill(u.char, sid)
	u.done = true
	selected = -1
	Sfx.confirm()
	_log("%s 释放「%s」，治疗 %d 人" % [u.char.name, sk.get("name", ""), healed])
	map_draw.queue_redraw()
	_refresh_info()
	_check_end()

func _cast_buff_skill(ui: int, sid: String) -> void:
	_push_lamp()
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	if sk.get("def_buff"):
		u.char.temp_def_buff = int(sk.get("def_buff"))
	if sk.get("next_hit_bonus"):
		u.char.temp_hit_bonus = int(sk.get("next_hit_bonus"))
	if sk.get("next_crit_bonus"):
		u.char.temp_crit_bonus = int(sk.get("next_crit_bonus"))
	if sk.get("zoc_aura"):
		u.char.temp_zoc_aura = int(sk.get("zoc_aura"))
	if sk.get("ignore_zoc"):
		u.char.temp_ignore_zoc = true
	if sk.get("leave_free"):
		u.char.temp_leave_free = true
	if sk.get("clear_combat_lock"):
		u.char.temp_combat_lock = 0
		_spawn_dmg(u.pos, "拆锁", Color(0.5, 0.85, 1.0))
		_spawn_slash(u.pos, "spark")
	if sk.get("terrain_ward"):
		u.char.temp_terrain_ward = true
		_spawn_dmg(u.pos, "地利", Color(0.55, 0.9, 0.55))
		_spawn_slash(u.pos, "shield")
	if sk.get("leave_free") or sk.get("clear_combat_lock") or sk.get("ignore_zoc"):
		# 立刻刷新移动：可支付脱离 / 拆锁后重算
		if ui == selected:
			move_cells = _compute_move_cells(ui)
			attack_mode = false
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	if sk.get("self_def_penalty"):
		u.char.temp_def_buff = maxi(-99, u.char.temp_def_buff - int(sk.get("self_def_penalty")))
	_consume_skill(u.char, sid)
	var note = ""
	if sk.get("zoc_aura"):
		note = "（控带强化）"
	_log("%s 释放「%s」%s" % [u.char.name, sk.get("name", ""), note])
	Sfx.confirm()
	Sfx.skill()
	_refresh_info()
	map_draw.queue_redraw()
	overlay.queue_redraw()

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
	ForecastPanel.refresh(self)
	_log("攻击模式：点击射程内敌人")

func _init_map() -> void:
	map_id = str(GameState.get_meta("battle_map", "ch0_pass"))
	var m: Dictionary = BattleMaps.get_map(map_id)
	map_name = Locale.latin(str(m.get("name", map_id)), str(map_id))
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
	_load_terrain_fx(m)
	_layout_board()
	if phase_label:
		phase_label.text = Locale.t("shell_a63e5b28") % map_name

func _load_terrain_fx(m: Dictionary) -> void:
	height_grid.clear()
	var grid: Array = m.get("height", [])
	for y in grid.size():
		var src: Array = grid[y]
		var row: Array = []
		for x in src.size():
			row.append(TerrainFx.clamp_height(int(src[x])))
		height_grid.append(row)
	weather = str(m.get("weather", "clear"))
	scout_map = bool(m.get("scout", false))
	interactives.clear()
	for raw in m.get("interactives", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var spot: Array = raw.get("cell", [0, 0])
		interactives.append({
			"cell": Vector2i(int(spot[0]), int(spot[1])),
			"kind": str(raw.get("kind", "")),
			"state": str(raw.get("state", "")),
		})
	_rebuild_fx_marks()

func _height_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= height_grid.size():
		return 0
	var row: Array = height_grid[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return 0
	return int(row[cell.x])

func _interactive_index(cell: Vector2i) -> int:
	for i in interactives.size():
		if interactives[i].get("cell", Vector2i(-9, -9)) == cell:
			return i
	return -1

func _terrain_blocked() -> Array:
	var out: Array = []
	for item in interactives:
		if TerrainFx.blocks(str(item.get("kind", "")), str(item.get("state", ""))):
			out.append(item.get("cell"))
	return out

func _rebuild_fx_marks() -> void:
	_fx_marks.clear()
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			var h := _height_at(cell)
			var kind := ""
			var state := ""
			var idx := _interactive_index(cell)
			if idx >= 0:
				kind = str(interactives[idx].get("kind", ""))
				state = str(interactives[idx].get("state", ""))
			if h <= 0 and kind == "":
				continue
			_fx_marks.append({"cell": cell, "h": h, "kind": kind, "state": state})

func _paint_terrain_fx() -> void:
	for mark in _fx_marks:
		var cell: Vector2i = mark["cell"]
		var h := int(mark.get("h", 0))
		var rect := Rect2(ORIGIN + Vector2(cell) * CELL, Vector2(CELL, CELL))
		if h > 0:
			var drop := Vector2(float(h) * 2.0, float(h) * 1.5)
			map_draw.draw_rect(Rect2(rect.position + drop, rect.size), Color(0, 0, 0, 0.05 * h))
			map_draw.draw_rect(rect.grow(-1.0), Color(UIKit.ACCENT, 0.18 + 0.1 * h), false, 1.0)
		if str(mark.get("kind", "")) != "":
			var col := UIKit.OK
			if TerrainFx.blocks(str(mark.get("kind", "")), str(mark.get("state", ""))):
				col = UIKit.DANGER
			map_draw.draw_rect(rect.grow(-8.0), Color(col, 0.55), false, 1.5)

func _atk_type(c: CKCharacter) -> String:
	return str(GameState.get_job(c.job_id).get("atk_type", "melee"))

func _players_see(cell: Vector2i) -> bool:
	var watchers: Array = []
	for u in units:
		if u.char.hp <= 0:
			continue
		var team := str(u.team)
		if team != "player" and team != "ally":
			continue
		watchers.append(u.pos)
	return TerrainFx.seen_by(watchers, cell, TerrainFx.vision_range(scout_map, weather))

func _log_enemy_move(u: Dictionary, cell: Vector2i) -> void:
	if not _players_see(cell):
		return
	_log("%s 机动至 (%d,%d)" % [u.char.name, cell.x, cell.y])

func _try_interact(actor: Dictionary, cell: Vector2i) -> bool:
	if _manhattan(actor.pos, cell) != 1:
		return false
	var idx := _interactive_index(cell)
	if idx < 0:
		return false
	var item: Dictionary = interactives[idx]
	var kind := str(item.get("kind", ""))
	var state := str(item.get("state", ""))
	if not TerrainFx.can_use(kind, state):
		return false
	item["state"] = TerrainFx.interact(kind, state)
	interactives[idx] = item
	_rebuild_fx_marks()
	_log(BattleObjectives.text("terrain_used") % [BattleObjectives.text("terrain_" + kind), cell.x, cell.y])
	if map_draw:
		map_draw.queue_redraw()
	if overlay:
		overlay.queue_redraw()
	return true

func _deploy() -> void:
	units.clear()
	var m: Dictionary = BattleMaps.get_map(map_id)
	var ids: Array = GameState.deploy_ids.duplicate()
	if ids.is_empty():
		for c in GameState.roster():
			if DeployBrief.bench_reason(c) != "":
				continue
			ids.append(c.id)
			if ids.size() >= GameState.max_deploy():
				break
	# 双嗣校场：真人子嗣分列双方
	var heir_a_id = str(GameState.get_meta("heir_clash_a", ""))
	var heir_b_id = str(GameState.get_meta("heir_clash_b", ""))
	var is_heir_clash = bool(m.get("heir_clash", false))
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
			if ids.size() >= GameState.max_deploy():
				break
	var spots: Array = []
	for s in m.get("player_spots", [[1,4],[2,5],[0,5],[3,4]]):
		spots.append(Vector2i(int(s[0]), int(s[1])))
	var i = 0
	for cid in ids:
		if i >= spots.size():
			break
		var c: CKCharacter = GameState.characters.get(cid)
		if c == null or not c.alive or DeployBrief.bench_reason(c) != "":
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
			var tmpl = str(templates[ti])
			var e = CharacterFactory.make_enemy(tmpl, rng)
			if e.appearance.get("hair","") == "" or e.faction == "enemy":
				e.appearance = {"hair": "ink_black", "eyes": "dusk", "brow": "thick", "scar": "cheek"}
			var tag := ""
			var tag_list: Array = m.get("enemy_tags", [])
			if ti < tag_list.size():
				tag = str(tag_list[ti])
			units.append({"char": e, "pos": enemy_spots[ei], "team": "enemy", "done": false, "template": tmpl, "tag": tag})
			ei += 1
	BattleObjectives.deploy_npcs(m, units)
	_log(Locale.t("shell_battle_deploy") % [map_name, i, ei])
	_theme_banter("start")
	if _is_escort_map():
		Sfx.cart_rattle()
	elif _is_harbor_map():
		Sfx.wave_splash()
	var chars: Array = []
	for u in units:
		if u.team == "enemy":
			CKEnemyLoadout.stamp_enemy(u.char, CKEnemyLoadout.mode_of(GameState))
			var elite = u.char.is_leader or str(u.char.name).find("首") >= 0 or str(u.char.name).find("头目") >= 0 or str(u.char.name).find("匪首") >= 0 or u.char.level >= 4
			var diff = GameState.battle_difficulty_from_map(map_id)
			var tmpl = str(u.get("template", ""))
			GameState.grant_battle_enemy_skills(u.char, elite, diff, map_id, tmpl)
		else:
			GameState.grant_job_skills(u.char)
			World.grant_gear_skills(u.char)  # v8.7 signature arms grant battle skills while equipped
		chars.append(u.char)
	GameState.reset_battle_skills(chars)
	_show_lock_tip_once()
	if _lock_practice_pending():
		_show_lock_practice_banner()
	var _diff = GameState.battle_difficulty_from_map(map_id)
	_log("敌军战技档：%d（地图 %s）" % [_diff, map_id])
	_log(BattleObjectives.text("diff_now") % BattleObjectives.text("diff_" + CKEnemyLoadout.mode_of(GameState)))
	if weather != "clear":
		_log(BattleObjectives.text("terrain_weather") % BattleObjectives.text("terrain_" + weather))
	_refresh_info()

func _draw_map() -> void:
	## v8.6: ground is the shader (_ground). Here: hover cell outline, token shadows, tokens, HP, CD pips, names.
	_paint_terrain_fx()
	var k := _k()
	if _in_bounds(_hover_cell):
		var hr = Rect2(ORIGIN + Vector2(_hover_cell) * CELL, Vector2(CELL, CELL))
		map_draw.draw_rect(hr, Color(1, 1, 1, 0.07))
		map_draw.draw_rect(hr.grow(-0.5), Color(0.85, 0.95, 1.0, 0.55), false, 1.0)
	var fnt := UIKit.font("regular")
	var fb := UIKit.font("bold")
	# units
	for i in units.size():
		var u = units[i]
		if u.char.hp <= 0:
			continue
		var p: Vector2i = u.pos
		if str(u.team) == "enemy" and not _players_see(p):
			continue
		var center = ORIGIN + Vector2(p) * CELL + Vector2(CELL / 2, CELL / 2)
		var tr := 20.0 * k
		# soft contact shadow (3 stacked ellipses)
		for si in range(3):
			var sr := tr * (1.05 + 0.16 * si)
			var pts := PackedVector2Array()
			for a in range(20):
				var ang := TAU * a / 20.0
				pts.append(center + Vector2(cos(ang) * sr, sin(ang) * sr * 0.42 + tr * 0.78))
			map_draw.draw_colored_polygon(pts, Color(0, 0, 0, 0.20 - 0.05 * si))
		UnitArt.draw_token_on(map_draw, center, u.char, u.team, tr, u.done)
		if int(u.char.temp_combat_lock) > 0:
			UnitArt.draw_lock_ring(map_draw, center, 22.0 * k)
		# HP bar (slim token bar)
		var hp_ratio = float(u.char.hp) / float(maxi(1, u.char.max_hp))
		var bar_w = 36.0 * k
		var bar_pos = center + Vector2(-bar_w * 0.5, tr + 6.0 * k)
		map_draw.draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2, 6)), Color(0.02, 0.03, 0.05, 0.85))
		var hp_col = UIKit.faction_color(str(u.team))
		map_draw.draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, 4)), hp_col)
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
				var cd_y = bar_pos.y + 7.0
				var pip_w = 12.0
				var gap = 2.0
				var total_w = cd_items.size() * (pip_w + gap) - gap
				var sx0 = center.x - total_w * 0.5
				for ci in cd_items.size():
					var it = cd_items[ci]
					var sx = sx0 + ci * (pip_w + gap)
					var ready = bool(it["ready"])
					var fill = 1.0 if ready else clampf(1.0 - float(it["cd"]) / float(it["max"]), 0.0, 1.0)
					map_draw.draw_rect(Rect2(Vector2(sx, cd_y), Vector2(pip_w, 12)), Color(0.03, 0.04, 0.06, 0.88))
					var col = Color(UIKit.OK, 0.9) if ready else Color(UIKit.ACCENT, 0.75)
					map_draw.draw_rect(Rect2(Vector2(sx, cd_y + 12 * (1.0 - fill)), Vector2(pip_w, 12 * fill)), Color(col, 0.35))
					var tcol = UIKit.TEXT if ready else UIKit.TEXT_DIM
					map_draw.draw_string(fnt, Vector2(sx + 1, cd_y + 10), str(it["ch"]), HORIZONTAL_ALIGNMENT_CENTER, pip_w - 2, 9, tcol)
		# name pill above token — only for selected / hovered (unit card carries the rest; keeps the board clean)
		if i != selected and p != _hover_cell:
			continue
		var nm2 = str(u.char.name)
		if nm2.length() > 4:
			nm2 = nm2.substr(0, 4)
		var fsz := 12
		var tw := fb.get_string_size(nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var np: Vector2 = center + Vector2(-tw * 0.5, -tr - 10.0 * k)
		map_draw.draw_rect(Rect2(np + Vector2(-6, -13), Vector2(tw + 12, 18)), Color(0.03, 0.04, 0.06, 0.62))
		map_draw.draw_rect(Rect2(np + Vector2(-6, 4), Vector2(tw + 12, 1)), Color(UIKit.faction_color(str(u.team)), 0.8))
		map_draw.draw_string(fb, np, nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UIKit.TEXT)
		# 选中脉冲环
		if i == selected:
			var pulse = 0.5 + 0.5 * sin(_sel_pulse * 6.0)
			map_draw.draw_arc(center, tr + 4.0 + pulse * 2.0, 0, TAU, 40, Color(UIKit.ACCENT, 0.9), 1.5, true)

func _draw_overlay() -> void:
	_draw_danger()
	# 敌军控制地带（ZoC）浅红提示
	if turn_team == "player":
		var zcells = BattleRules.zoc_cells(MAP_W, MAP_H, _enemy_positions("player"))
		for pos in zcells.keys():
			var rz = Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
			overlay.draw_rect(rz, Color(UIKit.DANGER, 0.09))
	if not attack_mode:
		var foes_ov = _enemy_positions("player")
		var locked_ov = false
		var start_eng = false
		if selected >= 0 and selected < units.size():
			var su = units[selected]
			if su.team == "player":
				locked_ov = int(su.char.temp_combat_lock) > 0
				start_eng = locked_ov or BattleRules.is_engaged(su.pos, foes_ov)
		for pos in move_cells.keys():
			var r = Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
			var in_z = BattleRules.in_zoc(pos, foes_ov)
			var leaving = start_eng and (not in_z) and selected >= 0 and pos != units[selected].pos
			var col: Color
			var edge: Color
			var tag := ""
			if locked_ov and leaving:
				col = Color(0.85, 0.25, 0.75, 0.48)   # 锁定脱离 cost3
				edge = Color(1.0, 0.55, 0.95, 0.95)
				tag = "锁3"
			elif leaving:
				col = Color(0.95, 0.65, 0.20, 0.48)   # 控带脱离 cost2
				edge = Color(1.0, 0.85, 0.35, 0.95)
				tag = "脱2"
			elif in_z:
				col = Color(0.95, 0.45, 0.25, 0.42)
				edge = Color(1.0, 0.65, 0.30, 0.75)
				tag = "控"
			else:
				col = Color(0.25, 0.55, 0.95, 0.38)
				edge = Color(0.4, 0.7, 1.0, 0.55)
			var hovered = (pos == _hover_cell)
			var pulse = 0.55 + 0.45 * sin(_sel_pulse * (7.0 if hovered else 4.0))
			col.a = clampf(col.a * (1.15 if hovered else 1.0) * (0.85 + 0.25 * pulse), 0.2, 0.85)
			edge.a = clampf((0.95 if hovered else edge.a) * (0.75 + 0.35 * pulse), 0.4, 1.0)
			overlay.draw_rect(r, col)
			var ew = 3.5 if hovered else 2.0
			overlay.draw_rect(r, edge, false, ew)
			# 色觉友好：高对比 hatch + 悬停脉冲透明度
			var hatch := ""
			if locked_ov and leaving:
				hatch = "res://assets/art/ui/zoc_hatch_lock3.png"
			elif leaving:
				hatch = "res://assets/art/ui/zoc_hatch_leave2.png"
			elif in_z:
				hatch = "res://assets/art/ui/zoc_hatch_zoc.png"
			else:
				hatch = "res://assets/art/ui/zoc_hatch_safe.png"
			if hatch != "" and ResourceLoader.exists(hatch):
				var ht: Texture2D = _tex(hatch)
				var ha = (0.55 + 0.45 * pulse) if hovered else (0.75 + 0.25 * pulse)
				overlay.draw_texture_rect(ht, r, false, Color(1, 1, 1, clampf(ha, 0.4, 1.0)))
				if hovered and tag != "":
					var pf = "res://assets/art/fx/zoc_pulse_%d.png" % (int(_sel_pulse * 10.0) % 6)
					if ResourceLoader.exists(pf):
						overlay.draw_texture_rect(_tex(pf), r.grow(4.0), false, Color(1, 1, 1, 0.55 + 0.35 * pulse))
			overlay.draw_string(UIKit.font("mono"), r.position + Vector2(4, 16), str(int(move_cells[pos])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.TEXT)
			if tag != "":
				var chip_path = ""
				if tag == "锁3":
					chip_path = "res://assets/art/ui/zoc_chip_lock3.png"
				elif tag == "脱2":
					chip_path = "res://assets/art/ui/zoc_chip_leave2.png"
				elif tag == "控":
					chip_path = "res://assets/art/ui/zoc_chip_zoc.png"
				var tp = ORIGIN + Vector2(pos) * CELL + Vector2(CELL - 22, 2)
				var csz = 20.0 if hovered else 18.0
				if chip_path != "" and ResourceLoader.exists(chip_path):
					overlay.draw_texture_rect(_tex(chip_path), Rect2(tp, Vector2(csz, csz)), false)
				else:
					overlay.draw_rect(Rect2(tp, Vector2(18, 14)), Color(0.05, 0.05, 0.08, 0.75))
		# 图例：纯图标芯片（无长文字）
		if not move_cells.is_empty():
			var lx = ORIGIN.x + 10.0
			var ly = ORIGIN.y + MAP_H * CELL - 58.0
			if ResourceLoader.exists("res://assets/art/ui/zoc_leave_legend.png"):
				var ltex = _tex("res://assets/art/ui/zoc_leave_legend.png")
				overlay.draw_texture(ltex, Vector2(lx, ly))
	if selected >= 0 and selected < units.size():
		var u = units[selected]
		if u.team == "player" and not u.done:
			var stand_tid := str(terrain[u.pos.y][u.pos.x]) if _in_bounds(u.pos) else "plain"
			var max_r = BattleRules.attack_reach(u.char, stand_tid)
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
	# v8.5 选中准星（authored select_dense 8帧循环）
	if selected >= 0 and selected < units.size() and units[selected].char.hp > 0:
		var sfi = int(_sel_pulse * 12.0) % 8
		var sp = "res://assets/art/fx/select_dense_%d.png" % sfi
		if ResourceLoader.exists(sp):
			var cpos = ORIGIN + Vector2(units[selected].pos) * CELL + Vector2(CELL, CELL) * 0.5 - Vector2(1, 1)
			var rs := float(CELL) * 1.32
			var scol = Color(1, 1, 1, 0.95) if units[selected].team == "player" else Color(1.0, 0.62, 0.62, 0.95)
			overlay.draw_texture_rect(_tex(sp), Rect2(cpos - Vector2(rs, rs) * 0.5, Vector2(rs, rs)), false, scol)
	# slash + hit_spark 分层（game-feel）
	for s in _slash_fx:
		var fi = mini(5, int(s.age / 0.08))
		var kind = str(s.get("kind", "slash"))
		# v8.4 dense 128px frames first, then legacy 64px
		var path = "res://assets/art/fx/%s_dense_%d.png" % [kind, fi]
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/%s_%d.png" % [kind, fi]
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/slash_dense_%d.png" % fi
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/slash_%d.png" % fi
		if ResourceLoader.exists(path):
			var fs: float = float(FX_SIZE.get(kind, 84.0)) * _k()
			overlay.draw_texture_rect(_tex(path), Rect2(s.pos - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false)
		if kind in ["slash", "crit", "spark"]:
			var spark = "res://assets/art/fx/hit_dense_%d.png" % fi
			if not ResourceLoader.exists(spark):
				spark = "res://assets/art/fx/hit_spark_%d.png" % fi
			if ResourceLoader.exists(spark):
				var hs := 72.0 * _k()
				overlay.draw_texture_rect(_tex(spark), Rect2(s.pos - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false, Color(1, 1, 1, 0.9))
	# 交战锁定爆发环
	for lb in _lock_burst_fx:
		var fi3 = mini(5, int(lb.age / 0.09))
		var lp = "res://assets/art/fx/lock_dense_%d.png" % fi3
		if not ResourceLoader.exists(lp):
			lp = "res://assets/art/fx/lock_%d.png" % fi3
		if ResourceLoader.exists(lp):
			var a3 = clampf(1.0 - lb.age / 0.55, 0.0, 1.0)
			overlay.draw_texture_rect(_tex(lp), Rect2(lb.pos - Vector2(40, 40) * _k(), Vector2(80, 80) * _k()), false, Color(1, 1, 1, a3))
	# 伤害飘字 + dmg_pop 底板
	for fx in _dmg_fx:
		var a = clampf(1.0 - fx.age / 1.1, 0.0, 1.0)
		var yoff = -fx.age * 36.0
		var col: Color = fx.col
		col.a = a
		var fi2 = mini(5, int(fx.age / 0.12))
		var pop = "res://assets/art/fx/dmg_pop_dense_%d.png" % fi2
		if not ResourceLoader.exists(pop):
			pop = "res://assets/art/fx/dmg_pop_%d.png" % fi2
		if ResourceLoader.exists(pop):
			overlay.draw_texture_rect(_tex(pop), Rect2(fx.pos + Vector2(-24, yoff - 32) * _k(), Vector2(48, 48) * _k()), false, Color(1, 1, 1, a * 0.9))
		overlay.draw_string(UIKit.font("bold"), fx.pos + Vector2(-12, yoff) * _k(), fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * sqrt(_k())), col)
	# 回合横幅
	if _turn_flash > 0.0:
		var a2 = clampf(_turn_flash / 0.9, 0.0, 1.0)
		var txt = Locale.t("shell_turn_player") if turn_team == "player" else Locale.t("shell_turn_enemy")
		var tfi = mini(5, int((0.9 - _turn_flash) / 0.15))
		var tfp = "res://assets/art/fx/turn_flash_dense_%d.png" % tfi
		if not ResourceLoader.exists(tfp):
			tfp = "res://assets/art/fx/turn_flash_%d.png" % tfi
		var bc := ORIGIN + Vector2(MAP_W, MAP_H) * CELL * 0.5
		var bandc: Color = UIKit.ACCENT if turn_team == "player" else UIKit.DANGER
		overlay.draw_rect(Rect2(Vector2(ORIGIN.x, bc.y - 34), Vector2(MAP_W * CELL, 68)), Color(0.03, 0.04, 0.06, 0.72 * a2))
		overlay.draw_rect(Rect2(Vector2(ORIGIN.x, bc.y - 34), Vector2(MAP_W * CELL, 1)), Color(bandc, 0.6 * a2))
		overlay.draw_rect(Rect2(Vector2(ORIGIN.x, bc.y + 33), Vector2(MAP_W * CELL, 1)), Color(bandc, 0.6 * a2))
		if ResourceLoader.exists(tfp):
			overlay.draw_texture_rect(_tex(tfp), Rect2(bc - Vector2(150, 48), Vector2(96, 96)), false, Color(1, 1, 1, a2 * 0.9))
		var tf := UIKit.font("regular")
		var tsz := tf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		overlay.draw_string(tf, bc + Vector2(-tsz.x * 0.5, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(UIKit.TEXT, a2))
	# 地形悬停提示
	if _in_bounds(_hover_cell):
		var sw = "res://assets/art/fx/attack_wash.png" if attack_mode else ("res://assets/art/fx/move_wash.png" if ResourceLoader.exists("res://assets/art/fx/move_wash.png") else "res://assets/art/fx/select_wash.png")
		if ResourceLoader.exists(sw):
			var hr = Rect2(ORIGIN + Vector2(_hover_cell) * CELL, Vector2(CELL - 2, CELL - 2))
			overlay.draw_texture_rect(_tex(sw), hr.grow(2.0), false, Color(1, 1, 1, 0.55 + 0.25 * sin(_sel_pulse * 6.0)))
		var tid = terrain[_hover_cell.y][_hover_cell.x]
		var ti = BattleRules.terrain_info(tid)
		var tname := Locale.latin(str(ti.name), str(tid))
		var tip = Locale.t("shell_terrain_tip") % [tname, ti.avo_bonus, ti.get("def_bonus", 0), ti.move_cost]
		var tfont := UIKit.font("regular")
		var tws := tfont.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tip_pos = ORIGIN + Vector2(_hover_cell.x * CELL, _hover_cell.y * CELL) + Vector2(10, -10)
		tip_pos.x = clampf(tip_pos.x, ORIGIN.x + 6, ORIGIN.x + MAP_W * CELL - tws - 16)
		tip_pos.y = maxf(tip_pos.y, ORIGIN.y + 18)
		overlay.draw_rect(Rect2(tip_pos + Vector2(-8, -15), Vector2(tws + 16, 22)), Color(0.06, 0.08, 0.11, 0.9))
		overlay.draw_rect(Rect2(tip_pos + Vector2(-8, -15), Vector2(tws + 16, 22)), Color(1, 1, 1, 0.14), false, 1.0)
		overlay.draw_string(tfont, tip_pos, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIKit.TEXT)


func _zoc_cell_kind(pos: Vector2i) -> String:
	## 悬停格的控带代价类型（用于音效电报）
	if attack_mode or move_cells.is_empty():
		return ""
	if not move_cells.has(pos):
		return ""
	var foes_ov = _enemy_positions("player")
	var locked_ov = false
	var start_eng = false
	if selected >= 0 and selected < units.size():
		var su = units[selected]
		if su.team == "player":
			locked_ov = int(su.char.temp_combat_lock) > 0
			start_eng = locked_ov or BattleRules.is_engaged(su.pos, foes_ov)
	var in_z = BattleRules.in_zoc(pos, foes_ov)
	var leaving = start_eng and (not in_z) and selected >= 0 and pos != units[selected].pos
	if locked_ov and leaving:
		return "lock3"
	if leaving:
		return "leave2"
	if in_z:
		return "zoc"
	return ""

func _zoc_hover_audio(cell: Vector2i) -> void:
	var kind = _zoc_cell_kind(cell)
	if kind == _zoc_hover_kind:
		return
	_zoc_hover_kind = kind
	if kind == "":
		return
	# 空间感：距选中单位越远音量越低（前端式距离衰减，非短 tick 一律）
	var dist := 1.0
	if selected >= 0 and selected < units.size():
		dist = float(_manhattan(units[selected].pos, cell))
	var vol = clampf(-3.0 - dist * 2.2, -18.0, -2.0)
	var world = ORIGIN + Vector2(cell) * CELL + Vector2(CELL * 0.5, CELL * 0.5)
	if selected >= 0 and selected < units.size():
		var lp = ORIGIN + Vector2(units[selected].pos) * CELL + Vector2(CELL * 0.5, CELL * 0.5)
		Sfx.set_listener_origin(lp)
	if kind == "lock3":
		vol = clampf(vol + 2.0, -16.0, -1.0)  # 锁脱更响
		Sfx.play_spatial("zoc_pulse", world, vol)
	elif kind == "leave2":
		Sfx.play_spatial("zoc_leave", world, vol)
	elif kind == "zoc":
		Sfx.play_spatial("zoc_leave", world, vol - 1.5)

func _unhandled_key_input(event: InputEvent) -> void:
	## v8.6 Stitch 06 keycaps: Q 攻击 · W 战技 · E 待命 · Enter 结束回合 (08/09 report: ESC 返回章节)
	if battle_over and has_meta("result_back") and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(str(get_meta("result_back")))
		return
	if battle_over or turn_team != "player" or _cut_playing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				if _btn_atk and not _btn_atk.disabled: _enter_attack_mode()
			KEY_W:
				if _btn_skill and not _btn_skill.disabled: _cycle_skill()
			KEY_E:
				if _btn_wait and not _btn_wait.disabled: _wait_selected()
			KEY_ENTER, KEY_KP_ENTER:
				if _btn_end and not _btn_end.disabled: _end_player_turn()
			_:
				return
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if battle_over:
		return
	for g in CKPauseMenu.board_events(_board_router, event, Time.get_ticks_msec()):
		_apply_board_gesture(g)

func apply_mobile_layout() -> void:
	_place_mobile_bar()
	if terrain.size() > 0:
		_layout_board()

func _screen_to_local(screen_pos: Vector2) -> Vector2:
	## Viewport pixels → this control. Identity on the desktop 1280×720 root.
	if not is_inside_tree():
		return screen_pos
	return get_global_transform().affine_inverse() * screen_pos

func _screen_delta_to_local(delta: Vector2) -> Vector2:
	return _screen_to_local(delta) - _screen_to_local(Vector2.ZERO)

func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
	var z := _board_zoom if _board_zoom > 0.001 else 1.0
	return _mouse_to_cell((_screen_to_local(screen_pos) - _board_pan) / z)

func _apply_board_xform() -> void:
	if _board_xform == null:
		return
	_board_xform.position = _board_pan
	_board_xform.scale = Vector2(_board_zoom, _board_zoom)

func _clamp_board_pan() -> void:
	var z := _board_zoom
	var board := Vector2(MAP_W, MAP_H) * float(CELL) * z
	var origin := ORIGIN * z
	var min_keep := 64.0
	_board_pan.x = clampf(_board_pan.x, BOARD_AREA.position.x + min_keep - origin.x - board.x, BOARD_AREA.end.x - min_keep - origin.x)
	_board_pan.y = clampf(_board_pan.y, BOARD_AREA.position.y + min_keep - origin.y - board.y, BOARD_AREA.end.y - min_keep - origin.y)

func _zoom_board_at(focal: Vector2, factor: float) -> void:
	var old := _board_zoom
	var next := clampf(old * factor, 0.65, 2.4)
	if is_equal_approx(next, old) or old <= 0.001:
		return
	_board_zoom = next
	_board_pan = focal - (focal - _board_pan) * (next / old)
	_clamp_board_pan()
	_apply_board_xform()

func _hover_at(screen_pos: Vector2) -> void:
	var cell := _pointer_to_cell(screen_pos)
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_zoc_hover_audio(cell)
	if map_draw:
		map_draw.queue_redraw()
	if overlay:
		overlay.queue_redraw()
	ForecastPanel.refresh(self)

func _on_danger_toggled(on: bool) -> void:
	danger_on = on
	if not on:
		danger_focus = -1
	if overlay:
		overlay.queue_redraw()


func _set_danger(on: bool, focus: int) -> void:
	danger_on = on
	danger_focus = focus
	if _btn_danger:
		_btn_danger.set_pressed_no_signal(on)
	if overlay:
		overlay.queue_redraw()


func _draw_danger() -> void:
	if not danger_on or overlay == null:
		return
	var cells := DangerZone.collect(self)
	var hatch := bool(GameState.settings.get("colorblind", false))
	for pos in cells.keys():
		var r := Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
		overlay.draw_rect(r, Color(UIKit.DANGER, 0.28))
		if hatch:
			overlay.draw_line(r.position, r.position + r.size, Color(UIKit.DANGER, 0.9), 1.5)
			overlay.draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0), Color(UIKit.DANGER, 0.9), 1.5)


func _on_long_press_cell(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	var ui := _unit_at(cell)
	if ui >= 0 and str(units[ui].team) == "enemy" and units[ui].char.hp > 0:
		if danger_on and danger_focus == ui:
			_set_danger(false, -1)
		else:
			_set_danger(true, ui)
		_refresh_info_for(ui)
		return
	_inspect_cell(cell)


func _inspect_cell(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	var ui := _unit_at(cell)
	if ui >= 0:
		_refresh_info_for(ui)
		_log("长按查看 %s" % units[ui].char.name)
		return
	var tid = terrain[cell.y][cell.x]
	var tinfo = BattleRules.terrain_info(tid)
	info_label.text = "[b]地形 · %s[/b]\n回避 +%d　防御 +%d\n（长按看情报，点按仍是选中/确认）" % [
		tinfo.get("name", tid), int(tinfo.get("avo_bonus", 0)), int(tinfo.get("def_bonus", 0)),
	]

func _apply_board_gesture(g: Dictionary) -> void:
	var kind := str(g.get("kind", ""))
	var pos: Vector2 = g.get("pos", Vector2.ZERO)
	match kind:
		"hover":
			_hover_at(pos)
		"tap":
			if turn_team != "player" or _cut_playing:
				return
			var cell := _pointer_to_cell(pos)
			if cell.x < 0:
				return
			_click_cell(cell)
		"long_press":
			_on_long_press_cell(_pointer_to_cell(pos))
		"cancel":
			_cancel_selection()
		"pan":
			_board_pan += _screen_delta_to_local(g.get("delta", Vector2.ZERO))
			_clamp_board_pan()
			_apply_board_xform()
			_hover_at(pos)
		"pinch", "wheel":
			_zoom_board_at(_screen_to_local(pos), float(g.get("factor", 1.0)))
			_hover_at(pos)

func _build_mobile_bar() -> void:
	BattleMobileBar.build(self)


func _mobile_cmd(row: HBoxContainer, text: String, h: int, accent: bool, cb: Callable) -> Button:
	return BattleMobileBar.command(row, text, h, accent, cb)


func _place_mobile_bar() -> void:
	BattleMobileBar.place(self)


func _on_viewport_resized() -> void:
	if not DeviceProfile.is_mobile():
		return
	_place_mobile_bar()
	if terrain.size() > 0:
		_layout_board()

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
	move_cells = _compute_move_cells(ui)
	_refresh_info()
	_update_skill_hint()
	overlay.queue_redraw()
	map_draw.queue_redraw()

func _can_attack_from(su: Dictionary, cell: Vector2i) -> bool:
	var d = _manhattan(su.pos, cell)
	if d < 1:
		return false
	var tid := "plain"
	if _in_bounds(su.pos):
		tid = str(terrain[su.pos.y][su.pos.x])
	return d <= BattleRules.attack_reach(su.char, tid, _height_at(su.pos))

func _click_cell(cell: Vector2i) -> void:
	var ui = _unit_at(cell)
	if selected >= 0 and selected < units.size():
		var su = units[selected]
		if su.team == "player" and not su.done:
			if ui >= 0 and units[ui].team == "enemy" and units[ui].char.hp > 0:
				if attack_mode:
					if _can_attack_from(su, cell):
						var extras = _combat_extras(selected, ui)
						var pv = BattleRules.preview(su.char, units[ui].char, terrain[cell.y][cell.x], extras)
						_spawn_dmg(cell, "命中%d%%" % int(pv.hit), Color(0.9, 0.92, 1.0))
						_log("预判：命中 %d%%　伤 %d–%d%s" % [int(pv.hit), int(pv.dmg.x), int(pv.dmg.y), (" · " + "·".join(pv.tags)) if pv.tags else ""])
						_do_attack(selected, ui)
						return
					_log("目标超出攻击范围")
					return
				_refresh_info_for(ui)
				return
			if ui < 0 and not attack_mode and _try_interact(su, cell):
				return
			if ui < 0 and not attack_mode and not moved_this_select and move_cells.has(cell):
				_move_undo = BattleSnapshot.capture(self)
				var origin_cell: Vector2i = su.pos
				su.pos = cell
				_spend_zoc(su, origin_cell, cell)
				moved_this_select = true
				Sfx.play_footstep(str(terrain[cell.y][cell.x]))
				move_cells.clear()
				_spawn_move_dust(cell)
				_refresh_info()
				map_draw.queue_redraw()
				overlay.queue_redraw()
				_log("%s 移动至 (%d,%d)" % [su.char.name, cell.x, cell.y])
				_sync_objectives()
				RewindBar.refresh(self)
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

func _same_side(a: String, b: String) -> bool:
	if a == b:
		return true
	return (a == "player" and b == "ally") or (a == "ally" and b == "player")


func _enemy_positions(for_team: String) -> Array:
	var out: Array = []
	for u in units:
		if u.char.hp <= 0:
			continue
		if _same_side(for_team, str(u.team)):
			continue
		out.append(u.pos)
	return out

func _ally_zoc_extra(for_team: String) -> int:
	# 方阵锁喉：己方单位提供的控带额外耗
	var extra = 0
	for u in units:
		if u.team == for_team and u.char.hp > 0:
			extra = maxi(extra, int(u.char.temp_zoc_aura))
	return extra

func _compute_move_cells(ui: int) -> Dictionary:
	var u = units[ui]
	var foes = _enemy_positions(u.team)
	var ignore = bool(u.char.temp_ignore_zoc) or int(u.get("zoc_used", 0)) < BattleRules.zoc_charges(u.char)
	var leave_free = bool(u.char.temp_leave_free)
	var zoc_extra = 0
	# 敌方移动时吃我方方阵/钉地
	if u.team == "enemy":
		zoc_extra = _ally_zoc_extra("player")
	elif u.team == "player":
		zoc_extra = _ally_zoc_extra("enemy")  # 敌军若有强化控带（少见）
	var leave_cost := BattleRules.leave_cost_for(int(u.char.temp_combat_lock) > 0, BattleRules.is_engaged(u.pos, foes))
	var blocked: Array = foes.duplicate()
	for cell in _terrain_blocked():
		if cell != u.pos:
			blocked.append(cell)
	var move_extra := TerrainFx.weather_move_extra(weather)
	var mv = BattleRules.move_costs(terrain, u.pos, u.char.derived_move(), blocked, foes, ignore, zoc_extra, leave_cost, leave_free, move_extra)
	for ou in units:
		if ou.char.hp > 0 and ou.pos != u.pos:
			mv.erase(ou.pos)
	return mv

func _spawn_dmg(cell: Vector2i, text: String, col: Color) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_dmg_fx.append({"pos": center, "text": text, "age": 0.0, "col": col})


func _spawn_move_dust(cell: Vector2i) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_move_dust_fx.append({"pos": center, "age": 0.0})

func _spawn_lock_burst(cell: Vector2i) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_lock_burst_fx.append({"pos": center, "age": 0.0})
	_shake = maxf(_shake, 2.2)

func _spawn_slash(cell: Vector2i, kind: String = "slash") -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_slash_fx.append({"pos": center, "age": 0.0, "kind": kind})
	_shake = 3.5

func _do_attack(ai: int, di: int) -> void:
	if str(units[ai].team) == "player":
		_push_lamp()
	_combat_rec = []
	var _hp0a: int = int(units[ai].char.hp)
	var _hp0d: int = int(units[di].char.hp)
	_resolve_strike(ai, di, true)
	var atk = units[ai]
	var def = units[di]
	# 交战锁定：攻/受击双方咬住（脱离代价加重，反击优先）
	_apply_combat_lock(ai, di)
	_spawn_lock_burst(atk.pos)
	_spawn_lock_burst(def.pos)
	# 连击：敏差足够且目标仍存活
	if def.char.hp > 0 and BattleRules.can_follow_up(atk.char, def.char):
		_log("连击！敏差触发第二击")
		_spawn_dmg(def.pos, "连击", Color(0.95, 0.75, 0.35))
		_resolve_strike(ai, di, false)
	# 反击：存活且射程覆盖——锁定单位反击命中+10
	if def.char.hp > 0 and BattleRules.can_counter(atk.char, def.char, atk.pos, def.pos, _height_at(def.pos)):
		var bonus = 0
		if int(def.char.temp_combat_lock) > 0:
			def.char.temp_hit_bonus += 10
			bonus = 10
			_log("%s 交战锁定反击！" % def.char.name)
			_spawn_dmg(atk.pos, "锁反", Color(1.0, 0.45, 0.35))
		else:
			_log("%s 反击！" % def.char.name)
			_spawn_dmg(atk.pos, "反击", Color(0.85, 0.55, 0.95))
		_resolve_strike(di, ai, false, true)
		if bonus > 0:
			def.char.temp_hit_bonus = maxi(0, def.char.temp_hit_bonus - bonus)
	atk.done = true
	selected = -1
	move_cells.clear()
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	_refresh_info()
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_queue_cutscene(ai, di, _hp0a, _hp0d)
	_check_end()

func _cutscenes_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and bool(GameState.get_meta("cutscenes_on", true)) and bool(GameState.settings.get("cutscenes", true))

func _queue_cutscene(ai: int, di: int, hp0a: int, hp0d: int) -> void:
	if not _cutscenes_enabled() or _combat_rec.is_empty():
		_combat_rec = []
		return
	var atk = units[ai]
	var def = units[di]
	var a_side := "right" if atk.team == "player" else "left"   # FE convention: our side on the right
	var d_side := "left" if a_side == "right" else "right"
	var strikes: Array = []
	var fc := {a_side: {}, d_side: {}}
	for r in _combat_rec:
		var from: String = a_side if int(r.a) == ai else d_side
		strikes.append({"from": from, "hit": r.hit, "crit": r.crit, "dmg": r.dmg, "killed": r.killed, "skill": r.skill, "hp_after": r.hp_after})
		if fc[from].is_empty():
			fc[from] = {"hit": r.hit_chance, "dmg": r.dmg if r.hit else "—"}
	var tid := str(terrain[def.pos.y][def.pos.x])
	var bg: Array = _biome_ground()
	var ground: String = tid if tid in ["forest", "hill", "fort", "bridge"] else str(bg[0])
	var gv: Vector3 = bg[1]
	var _AtlasArt = preload("res://scripts/art/atlas_art.gd")
	var rec := {
		a_side: {"char": atk.char, "team": atk.team, "template": str(atk.get("template", "")), "hp0": hp0a,
			"hit": fc[a_side].get("hit", "—"), "dmg": fc[a_side].get("dmg", "—"), "crit": atk.char.derived_crit()},
		d_side: {"char": def.char, "team": def.team, "template": str(def.get("template", "")), "hp0": hp0d,
			"hit": fc[d_side].get("hit", "—"), "dmg": fc[d_side].get("dmg", "—"), "crit": def.char.derived_crit()},
		"strikes": strikes, "ground": ground, "grade": Color(gv.x, gv.y, gv.z),
		"backdrop": str(_AtlasArt.battle_backdrop_for_map(map_id)),
		"title": "%s · %s" % [map_name, str(BattleRules.terrain_info(tid).get("name", tid))],
	}
	_combat_rec = []
	_cut_queue.append(rec)
	if not _cut_playing:
		_drain_cutscenes()

func play_cutscene_record(rec: Dictionary) -> void:
	_cut_queue.append(rec)
	if not _cut_playing:
		_drain_cutscenes()

func _drain_cutscenes() -> void:
	_cut_playing = true
	while not _cut_queue.is_empty():
		var r: Dictionary = _cut_queue.pop_front()
		var cs = CombatCutsceneScript.new()
		cs.setup(r)
		add_child(cs)
		await cs.finished
	_cut_playing = false

func _combat_extras(ai: int, di: int) -> Dictionary:
	var atk = units[ai]
	var def = units[di]
	var flank = BattleRules.has_flank(atk.pos, def.pos, units, atk.team, ai)
	var extras = {"flank": flank}
	# 占地利：防守方地形加成翻倍感（via def_bonus_mul）
	if def.char.temp_terrain_ward:
		extras["terrain_mul"] = 2.0
		var tid = terrain[def.pos.y][def.pos.x]
		if tid in ["fort", "forest"]:
			extras["flat_def"] = 2
	# 交战锁定中的防守：堡垒格额外硬抗
	if int(def.char.temp_combat_lock) > 0:
		var tid2 = terrain[def.pos.y][def.pos.x]
		if tid2 == "fort":
			extras["flat_def"] = int(extras.get("flat_def", 0)) + 1
	extras["night"] = _battle_night()
	extras["opening"] = not bool(atk.get("has_struck", false))
	extras["foe_opening"] = not bool(def.get("has_struck", false))
	extras["height_hit"] = TerrainFx.height_delta_hit(_height_at(atk.pos), _height_at(def.pos))
	extras["weather_hit"] = TerrainFx.weather_hit(weather, _atk_type(atk.char))
	extras["weather"] = weather
	return extras


func _battle_night() -> bool:
	if map_id.to_lower().find("night") >= 0:
		return true
	return AtlasArt.biome_for_map(map_id) == "nightcamp"


func _spend_zoc(u, origin: Vector2i, dest: Vector2i) -> void:
	if int(u.get("zoc_used", 0)) >= BattleRules.zoc_charges(u.char):
		return
	var foes := _enemy_positions(str(u.team))
	if BattleRules.in_zoc(origin, foes) or BattleRules.in_zoc(dest, foes):
		u["zoc_used"] = int(u.get("zoc_used", 0)) + 1


func _pulse_heal(team: String) -> void:
	for u in units:
		if str(u.team) != team or u.char.hp <= 0:
			continue
		var amt := BattleRules.heal_pulse(u.char)
		if amt <= 0:
			continue
		u.char.hp = mini(u.char.max_hp, u.char.hp + amt)


func _sync_faction_marks() -> void:
	var layer := get_node_or_null("FactionMarks") as Control
	if layer == null:
		layer = Control.new()
		layer.name = "FactionMarks"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(layer)
	while layer.get_child_count() < units.size():
		layer.add_child(UIKit.faction_mark("player"))
	for i in layer.get_child_count():
		var mark := layer.get_child(i) as Control
		if i >= units.size() or units[i].char.hp <= 0:
			mark.visible = false
			continue
		var u = units[i]
		mark.visible = true
		mark.team = "enemy" if str(u.team) == "enemy" else "player"
		mark.queue_redraw()
		var center := ORIGIN + Vector2(u.pos) * CELL + Vector2(CELL * 0.5, CELL * 0.5)
		var side := 22.0
		mark.size = Vector2(side, side)
		mark.position = center + Vector2(-side * 0.5, 8.0)


func _apply_combat_lock(ai: int, di: int) -> void:
	# 双方进入交战锁定（再交战刷新至 2）
	for idx in [ai, di]:
		if idx < 0 or idx >= units.size():
			continue
		var u = units[idx]
		if u.char.hp <= 0:
			continue
		u.char.temp_combat_lock = maxi(u.char.temp_combat_lock, 3)  # 再交战刷新锁定（三回合感）
		_spawn_dmg(u.pos, "锁定", Color(1.0, 0.4, 0.35))
		_spawn_slash(u.pos, "lock")
	if not has_meta("lock_beat_fired") and _is_lock_tutorial_map():
		set_meta("lock_beat_fired", true)
		_log("〔教学拍〕锁定已触发——看棋子外圈红环；脱离将更贵，反击更准。练习完成，可以结束回合。")
		_spawn_dmg(units[ai].pos if ai >= 0 else units[di].pos, "教学·锁定", Color(1.0, 0.7, 0.4))
		_clear_lock_practice_banner()
		_show_lock_tip_panel("练习完成", "交战锁定已体验。之后正式对局也会出现此效果。", 2, 4.0)

func _weapon_for(c: CKCharacter) -> String:
	var at := str(GameState.get_job(c.job_id).get("atk_type", "melee"))
	if at == "ranged":
		return "bow"
	if at == "magic":
		return "spell"
	var role := BattleRules.job_role(c.job_id)
	if role == "cavalry":
		return "lance"
	if role == "tank":
		return "axe"
	return "sword"


func _bark(c: CKCharacter, kind: String) -> void:
	if c == null:
		return
	Sfx.play_bark(str(c.gender), int(c.age), kind)


func _is_boss_map() -> bool:
	if map_id.to_lower().find("boss") >= 0:
		return true
	var obj = BattleMaps.get_map(map_id).get("objective", {})
	return typeof(obj) == TYPE_DICTIONARY and str(obj.get("type", "")) == "boss"


func _tension_value() -> float:
	var hp := 0
	var mx := 0
	for u in units:
		if str(u.team) != "player":
			continue
		hp += maxi(0, int(u.char.hp))
		mx += maxi(1, int(u.char.max_hp))
	if mx <= 0:
		return 0.0
	return clampf(1.0 - float(hp) / float(mx), 0.0, 1.0)


func _sync_battle_music() -> void:
	if battle_over:
		return
	if _is_boss_map():
		Music.play_boss()
	elif turn_team == "enemy":
		Music.play_enemy_turn()
	else:
		Music.play_player_turn(Music.era_from_year(int(Calendar.year)))
	Music.set_tension(_tension_value())


func _resolve_strike(ai: int, di: int, allow_skill: bool, is_counter: bool = false) -> void:

	var atk = units[ai]
	var def = units[di]
	if atk.char.hp <= 0 or def.char.hp <= 0:
		return
	var _hp_before: int = int(def.char.hp)
	var tid = terrain[def.pos.y][def.pos.x]
	var extras = _combat_extras(ai, di)
	if is_counter:
		extras["counter"] = true
	var skill_id = ""
	var sk = {}
	if allow_skill and skill_mode and active_skill_id != "" and (atk.team == "player" or atk.team == "enemy"):
		skill_id = active_skill_id
		sk = GameState.get_skill(skill_id)
		if sk.get("ignore_terrain_avo"):
			tid = "plain"
		extras["hit_mod"] = int(sk.get("hit_mod", 0))
	var result = BattleRules.roll_attack(atk.char, def.char, tid, rng, extras)
	if skill_id != "" and sk.get("type") == "offense":
		# 战技：撤销普通掷骰伤害后，按技能倍率重掷
		if result.hit:
			def.char.hp = mini(def.char.max_hp, def.char.hp + int(result.damage))
		var hit_chance = BattleRules.calc_hit(atk.char, def.char, tid, extras) + int(sk.get("hit_mod", 0))
		hit_chance = clampi(hit_chance, 5, 99)
		var hit = rng.randi_range(1, 100) <= hit_chance
		var dmg_range = BattleRules.calc_damage_range(atk.char, def.char, tid, extras)
		var dmg = 0
		var crit = false
		if hit:
			dmg = rng.randi_range(dmg_range.x, dmg_range.y)
			dmg = int(round(dmg * float(sk.get("dmg_mul", 1.0))))
			if int(sk.get("vs_tank_bonus", 0)) > 0 and BattleRules.job_role(def.char.job_id) == "tank":
				dmg += int(sk.get("vs_tank_bonus", 0))
			dmg = BattleRules.royal_damage(atk.char, str(sk.get("blood_sig", "")), dmg)
			if rng.randi_range(1, 100) <= atk.char.derived_crit():
				crit = true
				Sfx.crit()
				_spawn_slash(def.pos, "crit")
				if _unit_panel:
					UIFX.flash_modulate(_unit_panel, Color(1.35, 1.15, 0.7), 0.2)
					UIFX.shake_control(_unit_panel, 5.0 * UIKit.shake_gain(), 0.2)
				dmg = int(dmg * 1.5)
			def.char.hp = maxi(0, def.char.hp - dmg)
		result = {"hit": hit, "crit": crit, "damage": dmg, "hit_chance": hit_chance, "dmg_range": dmg_range, "killed": def.char.hp <= 0, "flank": extras.get("flank", false), "role_label": str(BattleRules.role_mods(atk.char, def.char).get("label", "")), "terrain_def": int(BattleRules.terrain_info(tid).get("def_bonus", 0))}
		_consume_skill(atk.char, skill_id)
		_log("战技「%s」！" % sk.get("name", skill_id))
		if int(sk.get("self_def_penalty", 0)) > 0:
			atk.char.temp_def_buff = -int(sk.get("self_def_penalty", 0))
	if atk.char.temp_hit_bonus != 0:
		atk.char.temp_hit_bonus = 0
	var tags: Array = []
	if result.get("flank", false):
		tags.append("夹击")
		_spawn_dmg(def.pos, "夹击", Color(1.0, 0.55, 0.2))
	if str(result.get("role_label", "")) != "":
		tags.append(str(result.role_label))
	if int(result.get("terrain_def", 0)) > 0:
		tags.append("垒防" if tid == "fort" else "地形防")
	var tag_s = ("〔" + "·".join(tags) + "〕") if tags else ""
	var msg = "%s → %s%s：" % [atk.char.name, def.char.name, tag_s]
	if result.hit:
		Sfx.play_weapon(_weapon_for(atk.char))
		_bark(atk.char, "shout")
		_spawn_slash(def.pos, "crit" if result.crit else "slash")
		if result.crit:
			_spawn_slash(def.pos, "spark")
		if _unit_panel:
			UIFX.punch(_unit_panel, 0.04)
		msg += "命中 %d%s（掷骰相对命中率 %d%%）" % [result.damage, "（暴击）" if result.crit else "", int(result.hit_chance)]
		var col = Color(1.0, 0.85, 0.3) if result.crit else Color(1.0, 0.45, 0.35)
		_spawn_dmg(def.pos, ("暴%d" % result.damage) if result.crit else ("-%d" % result.damage), col)
		_shake = maxf(_shake, 0.28 if result.crit else 0.12)
		if result.killed:
			msg += " · 击退！"
			_spawn_dmg(def.pos, "击破", Color(1.0, 0.9, 0.5))
			if def.team == "enemy":
				_theme_banter("kill")
			if def.team == "player":
				def.char.injured = true
			_bark(def.char, "shout")
			_note_unit_downed(def, atk.char)
		elif int(def.char.hp) < _hp_before:
			_bark(def.char, "breath")
	else:
		Sfx.miss()
		msg += "未命中（命中率 %d%%）" % result.hit_chance
		_spawn_dmg(def.pos, "未中", Color(0.7, 0.75, 0.85))
	_combat_rec.append({"a": ai, "d": di, "hit": bool(result.hit), "crit": bool(result.get("crit", false)), "dmg": int(result.get("damage", 0)),
		"killed": def.char.hp <= 0, "skill": str(sk.get("name", skill_id)) if skill_id != "" else "", "hp_before": _hp_before,
		"hp_after": int(def.char.hp), "hit_chance": int(result.get("hit_chance", 0))})
	if result.hit and skill_id != "" and sk.get("type") == "offense":
		if float(sk.get("drain_pct", 0)) > 0:
			var heal = maxi(1, int(result.damage * float(sk.get("drain_pct", 0))))
			atk.char.hp = mini(atk.char.max_hp, atk.char.hp + heal)
			_spawn_dmg(atk.pos, "+%d" % heal, Color(0.9, 0.4, 0.55))
			msg += " · 吸血%d" % heal
		if int(sk.get("expose", 0)) > 0:
			def.char.temp_exposed = maxi(def.char.temp_exposed, int(sk.get("expose", 0)))
			_spawn_dmg(def.pos, "破防", Color(0.9, 0.6, 0.3))
			msg += " · 破防"
		if float(sk.get("cleave_pct", 0)) > 0:
			var cleave_dmg = maxi(1, int(result.damage * float(sk.get("cleave_pct", 0))))
			for j in units.size():
				if j == di:
					continue
				var o = units[j]
				if o.team == def.team and o.char.hp > 0 and _manhattan(def.pos, o.pos) == 1:
					o.char.hp = maxi(0, o.char.hp - cleave_dmg)
					_spawn_dmg(o.pos, "溅-%d" % cleave_dmg, Color(1.0, 0.5, 0.25))
					_spawn_slash(o.pos)
					msg += " · 溅射%s" % o.char.name
					if o.char.hp <= 0:
						_bark(o.char, "shout")
						_note_unit_downed(o, atk.char)
						if o.team == "player":
							o.char.injured = true
					else:
						_bark(o.char, "breath")
					break
	if atk.char.temp_crit_bonus != 0 and allow_skill:
		atk.char.temp_crit_bonus = 0
	var skill_push := int(sk.get("push", 0)) if skill_id != "" and str(sk.get("type", "")) == "offense" else 0
	var push_n := BattleRules.push_tiles(atk.char, skill_push) if result.hit else 0
	if push_n > 0:
		var pushed := 0
		for _step in push_n:
			if not _try_push(ai, di):
				break
			pushed += 1
		if pushed > 0:
			msg += " · 击退"
			_spawn_dmg(def.pos, "击退", Color(0.7, 0.8, 1.0))
	units[ai]["has_struck"] = true
	_sync_battle_music()
	_log(msg)

func _try_push(ai: int, di: int) -> bool:
	var atk = units[ai]
	var def = units[di]
	var dx = signi(def.pos.x - atk.pos.x)
	var dy = signi(def.pos.y - atk.pos.y)
	if dx == 0 and dy == 0:
		return false
	var np = def.pos + Vector2i(dx, dy)
	if not _in_bounds(np):
		return false
	if _unit_at(np) >= 0:
		return false
	def.pos = np
	map_draw.queue_redraw()
	return true

func _wait_selected() -> void:
	if selected < 0:
		return
	var u = units[selected]
	if u.team != "player" or u.done:
		return
	_push_lamp()
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
	_arm_lamps()
	turn_team = "player"
	_round_no += 1
	if _round_label:
		_round_label.text = Locale.t("shell_4b1b8d2e") % _round_no
	if _phase_chip:
		_phase_chip.text = "PHASE 01"
		_phase_chip.add_theme_color_override("font_color", UIKit.ACCENT)
	phase_label.text = Locale.t("shell_742d7d53") % map_name
	phase_label.add_theme_color_override("font_color", UIKit.TEXT)
	_turn_flash = 0.9
	Sfx.turn()
	_sync_battle_music()
	var pcs: Array = []
	for u in units:
		if u.team == "player":
			u.done = false
			# 铁壁姿态持续到己方下回合开始时清除
			u.char.temp_def_buff = 0
			u.char.temp_exposed = 0
			u.char.temp_zoc_aura = 0
			u.char.temp_ignore_zoc = false
			u.char.temp_leave_free = false
			u.char.temp_terrain_ward = false
			if u.char.temp_combat_lock > 0:
				u.char.temp_combat_lock -= 1
			pcs.append(u.char)
	_pulse_heal("player")
	GameState.tick_skill_cooldowns(pcs)
	selected = -1
	move_cells.clear()
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	_theme_banter("turn")
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_update_skill_hint()
	_sync_objectives()
	_seal_turn()

func _end_player_turn() -> void:
	if battle_over:
		return
	if _lock_practice_pending():
		_log("〔强制练习〕请先攻击一名敌人，体验交战锁定——尚未可结束回合。")
		_show_lock_practice_banner()
		Sfx.miss()
		return
	turn_team = "enemy"
	phase_label.text = Locale.t("shell_2a6d5eac") % map_name
	if _phase_chip:
		_phase_chip.text = "PHASE 02"
		_phase_chip.add_theme_color_override("font_color", UIKit.DANGER)
	phase_label.add_theme_color_override("font_color", UIKit.DANGER)
	_turn_flash = 0.9
	_pulse_heal("enemy")
	_sync_battle_music()
	for u in units:
		if u.team == "enemy":
			u.char.temp_exposed = 0
			if u.char.temp_combat_lock > 0:
				u.char.temp_combat_lock -= 1
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	overlay.queue_redraw()
	await get_tree().create_timer(0.35).timeout
	_enemy_ai()
	if not battle_over:
		_start_player_turn()


func _show_lock_tip_once() -> void:
	if has_meta("lock_tip_shown"):
		return
	set_meta("lock_tip_shown", true)
	var tutorial = bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)) or map_id.begins_with("ch0")
	if tutorial:
		_run_lock_tutorial_sequence()
	else:
		_show_lock_tip_panel(
			"交战锁定",
			"攻/受击后双方进入锁定：脱离+%d移，锁定反击命中+10。抽身/拆锁可解。" % BattleRules.LEAVE_COST_LOCK,
			0,
			8.0
		)

func _show_lock_tip_panel(title: String, body: String, step: int, auto_sec: float) -> Control:
	var panel = UIKit.make_panel()
	panel.position = Vector2(RAIL_X, 462)  # v8.6: rail slot over the log — never on the board
	panel.custom_minimum_size = Vector2(RAIL_W, 96)
	panel.add_theme_stylebox_override("panel", UIKit.glass(12, 0.94, true))
	panel.z_index = 20
	panel.name = "LockTipPanel"
	add_child(panel)
	# v8.5: legacy gold lock_tip_step plates retired (off-vibe, stretched) -> design-system chrome:
	# frosted panel + authored coral lock glyph + step pips
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	panel.add_child(hrow)
	var glyph := TextureRect.new()
	glyph.texture = _tex("res://assets/art/fx/lock_dense_3.png")
	glyph.custom_minimum_size = Vector2(44, 44)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(glyph)
	UIFX.breathe(glyph, 0.04, 1.6)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	hrow.add_child(vb)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	for pi in range(3):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22 if pi == step else 10, 4)
		pip.color = UIKit.DANGER if pi == step else Color(UIKit.TEXT_DIM, 0.5)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	vb.add_child(pips)
	var t = UIKit.make_label(title, true)
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", UIKit.DANGER)
	vb.add_child(t)
	var d = UIKit.make_dim_label(body)
	d.add_theme_font_size_override("font_size", 12)
	d.custom_minimum_size = Vector2(RAIL_W - 110, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	if auto_sec > 0.0:
		get_tree().create_timer(auto_sec).timeout.connect(func():
			if is_instance_valid(panel):
				panel.queue_free()
		)
	return panel

func _run_lock_tutorial_sequence() -> void:
	## 教学三拍：咬住 → 脱离代价 → 拆锁/反击
	var steps: Array = [
		{"t": Locale.t("shell_lock_1t"), "b": Locale.t("shell_lock_1b")},
		{"t": Locale.t("shell_lock_2t"), "b": Locale.t("shell_lock_2b") % [BattleRules.LEAVE_COST_LOCK, BattleRules.LEAVE_COST_ENGAGED]},
		{"t": Locale.t("shell_lock_3t"), "b": Locale.t("shell_lock_3b")},
	]
	_show_lock_tip_panel(str(steps[0].t), str(steps[0].b), 0, 0.0)
	get_tree().create_timer(3.2).timeout.connect(func():
		var old = get_node_or_null("LockTipPanel")
		if old: old.queue_free()
		_show_lock_tip_panel(str(steps[1].t), str(steps[1].b), 1, 0.0)
	)
	get_tree().create_timer(6.4).timeout.connect(func():
		var old2 = get_node_or_null("LockTipPanel")
		if old2: old2.queue_free()
		var p = _show_lock_tip_panel(str(steps[2].t), str(steps[2].b), 2, 0.0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var host: Node = p.get_child(0).get_child(1) if p.get_child_count() > 0 and p.get_child(0).get_child_count() > 1 else p
		host.add_child(row)
		var dismiss = UIKit.make_accent_button(Locale.t("shell_lock_start"), 140)
		dismiss.pressed.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
		row.add_child(dismiss)
		get_tree().create_timer(10.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
	)
	_log("教学：交战锁定三拍提示已展开")



func _is_lock_tutorial_map() -> bool:
	var md = BattleMaps.get_map(map_id)
	if bool(md.get("tutorial_militia", false)) or map_id.begins_with("ch0"):
		return true
	# 中盘二次强制锁定演练（如 ch2_night）
	return bool(md.get("lock_drill", false))

func _lock_practice_pending() -> bool:
	return _is_lock_tutorial_map() and not has_meta("lock_beat_fired")

func _show_lock_practice_banner() -> void:
	if has_meta("lock_practice_banner"):
		return
	set_meta("lock_practice_banner", true)
	## v8.6: slim coral pill in the turn bar — the board stays clear
	var panel = UIKit.make_glass(18, 0.82)
	var pst: StyleBoxFlat = UIKit.glass(18, 0.82)
	pst.border_color = Color(UIKit.DANGER, 0.55)
	pst.content_margin_top = 4
	pst.content_margin_bottom = 4
	pst.content_margin_left = 14
	pst.content_margin_right = 14
	pst.shadow_size = 0
	panel.add_theme_stylebox_override("panel", pst)
	panel.position = Vector2(RAIL_X, 4)
	panel.custom_minimum_size = Vector2(RAIL_W, 0)
	panel.z_index = 18
	var ct := find_child("ControlsTip", true, false)
	if ct:
		ct.visible = false
	panel.name = "LockPracticeBanner"
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)
	var title = Locale.t("shell_lock_drill")
	var tip = Locale.t("shell_lock_drill_tip")
	if bool(BattleMaps.get_map(map_id).get("lock_drill", false)) and not map_id.begins_with("ch0"):
		if map_id.begins_with("ch6"):
			title = Locale.t("shell_lock_final")
			tip = Locale.t("shell_lock_final_tip")
		elif map_id.begins_with("ch5") or map_id.begins_with("ch4"):
			title = Locale.t("shell_lock_late")
			tip = Locale.t("shell_lock_late_tip")
		else:
			title = Locale.t("shell_lock_mid")
			tip = Locale.t("shell_lock_mid_tip")
	var t = UIKit.make_label(title)
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", UIKit.DANGER)
	vb.add_child(t)
	var tl = UIKit.make_dim_label(tip)
	tl.add_theme_font_size_override("font_size", 10)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(RAIL_W - 28, 0)
	vb.add_child(tl)
	panel.tooltip_text = tip

func _clear_lock_practice_banner() -> void:
	var p = get_node_or_null("LockPracticeBanner")
	if p:
		p.queue_free()
	var ct := find_child("ControlsTip", true, false)
	if ct:
		ct.visible = true

func _unit_theme(u) -> String:
	return str(UnitModel.parse_enemy_template(str(u.get("template", ""))).get("theme", "bandit"))

func _enemy_situation(ui: int, foe_i: int = -1) -> Dictionary:
	var u = units[ui]
	var allies_near := 0
	var ally_hurt := false
	var foe_near := false
	for ou in units:
		if ou == u or ou.char.hp <= 0:
			continue
		var d := _manhattan(u.pos, ou.pos)
		if ou.team == u.team and d <= 2:
			allies_near += 1
			if float(ou.char.hp) < float(ou.char.max_hp) * 0.65:
				ally_hurt = true
		elif ou.team != u.team and d <= 2:
			foe_near = true
	var foe_hp := 1.0
	var cover := false
	if foe_i >= 0 and foe_i < units.size():
		var foe = units[foe_i]
		foe_hp = float(foe.char.hp) / float(maxi(1, foe.char.max_hp))
		var tid := str(terrain[foe.pos.y][foe.pos.x])
		cover = tid in ["fort", "forest", "hill"]
		foe_near = true
	var stand := str(terrain[u.pos.y][u.pos.x])
	return {
		"hp_frac": float(u.char.hp) / float(maxi(1, u.char.max_hp)),
		"locked": int(u.char.temp_combat_lock) > 0,
		"on_ground": stand in ["fort", "forest", "hill"],
		"ally_hurt": ally_hurt,
		"allies_near": allies_near,
		"foe_near": foe_near,
		"foe_hp_frac": foe_hp,
		"foe_on_cover": cover,
	}

func _enemy_known_skills(c: CKCharacter) -> Array:
	var out: Array = []
	for sid in c.skills:
		if sid not in out:
			out.append(sid)
	for sid in c.unlocked_skills:
		if sid not in out:
			out.append(sid)
	return out

func _enemy_skill_ready(c: CKCharacter, sid: String) -> bool:
	if int(c.skill_uses.get(sid, 0)) <= 0:
		return false
	if int(c.skill_cd.get(sid, 0)) > 0:
		return false
	return true

func _enemy_try_skills(ui: int) -> void:
	var u = units[ui]
	var c: CKCharacter = u.char
	var beh := CKTacticsAI.behavior_for(_unit_theme(u))
	var sit := _enemy_situation(ui)
	var gate := 1.55 - float(beh.get("skill", 0.5))
	if bool(sit.get("locked", false)) and float(sit.get("hp_frac", 1.0)) < 0.55:
		gate = 0.35
	var ready := func(sid: String) -> bool:
		return _enemy_skill_ready(c, sid)
	var picked := CKTacticsAI.best_skill(_enemy_known_skills(c), ready, sit, "prep", gate)
	if picked != "":
		var skp := GameState.get_skill(picked)
		if str(skp.get("type", "")) == "support":
			_cast_support_skill_for_team(ui, picked, u.team)
		else:
			_cast_buff_skill_for_team(ui, picked)
			_log("%s 敌技「%s」" % [c.name, skp.get("name", picked)])
		await get_tree().create_timer(0.18).timeout
		return
	# 1) 残血被锁 → 抽身/拆锁
	if int(c.temp_combat_lock) > 0 and float(c.hp) / float(maxi(1, c.max_hp)) < 0.85:
		for sid in ["disengage_step", "lock_breaker"]:
			if sid in _enemy_known_skills(c) and _enemy_skill_ready(c, sid):
				_cast_buff_skill_for_team(ui, sid)
				_log("%s 敌技「%s」" % [c.name, GameState.get_skill(sid).get("name", sid)])
				await get_tree().create_timer(0.2).timeout
				return
	# 2) 站在林/垒 → 占地利
	var tid = terrain[u.pos.y][u.pos.x]
	if tid in ["fort", "forest", "hill"]:
		if "terrain_ward" in _enemy_known_skills(c) and _enemy_skill_ready(c, "terrain_ward"):
			_cast_buff_skill_for_team(ui, "terrain_ward")
			_log("%s 敌技「占地利」" % c.name)
			await get_tree().create_timer(0.18).timeout
			return
	# 3) 铁壁 / 锁定猎物
	for sid in ["guard_stance", "mark_prey", "hold_phalanx", "anchor_guard", "iron_wall", "ember_seal", "mark_death", "terrain_ward"]:
		if sid in _enemy_known_skills(c) and _enemy_skill_ready(c, sid):
			# 仅当附近有玩家时浪费增益不值
			var near = false
			for ou in units:
				if ou.team == "player" and ou.char.hp > 0 and _manhattan(u.pos, ou.pos) <= 3:
					near = true
					break
			if near:
				_cast_buff_skill_for_team(ui, sid)
				_log("%s 敌技「%s」" % [c.name, GameState.get_skill(sid).get("name", sid)])
				await get_tree().create_timer(0.18).timeout
				return
	# 4) 治疗类：友军残血
	for sid in _enemy_known_skills(c):
		var sk = GameState.get_skill(sid)
		if str(sk.get("type", "")) != "support":
			continue
		if not _enemy_skill_ready(c, sid):
			continue
		var need = false
		for ou in units:
			if ou.team == "enemy" and ou.char.hp > 0 and ou.char.hp < ou.char.max_hp * 0.6:
				if _manhattan(u.pos, ou.pos) <= 1:
					need = true
					break
		if need:
			_cast_support_skill_for_team(ui, sid, "enemy")
			await get_tree().create_timer(0.22).timeout
			return

func _cast_buff_skill_for_team(ui: int, sid: String) -> void:
	# 复用玩家增益逻辑（不依赖 selected）
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	if sk.get("def_buff"):
		u.char.temp_def_buff = int(sk.get("def_buff"))
	if sk.get("next_hit_bonus"):
		u.char.temp_hit_bonus = int(sk.get("next_hit_bonus"))
	if sk.get("next_crit_bonus"):
		u.char.temp_crit_bonus = int(sk.get("next_crit_bonus"))
	if sk.get("zoc_aura"):
		u.char.temp_zoc_aura = int(sk.get("zoc_aura"))
	if sk.get("ignore_zoc"):
		u.char.temp_ignore_zoc = true
	if sk.get("leave_free"):
		u.char.temp_leave_free = true
	if sk.get("clear_combat_lock"):
		u.char.temp_combat_lock = 0
		_spawn_dmg(u.pos, "拆锁", Color(0.5, 0.85, 1.0))
		_spawn_slash(u.pos, "spark")
	if sk.get("terrain_ward"):
		u.char.temp_terrain_ward = true
		_spawn_dmg(u.pos, "地利", Color(0.55, 0.9, 0.55))
		_spawn_slash(u.pos, "shield")
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		var team = u.team
		for ou in units:
			if ou.team == team and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	_consume_skill(u.char, sid)
	_spawn_slash(u.pos, "shield")
	Sfx.skill()
	map_draw.queue_redraw()

func _cast_support_skill_for_team(ui: int, sid: String, team: String) -> void:
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	var healed = 0
	for j in units.size():
		var o = units[j]
		if o.team != team or o.char.hp <= 0:
			continue
		if _manhattan(u.pos, o.pos) <= 1:
			var amt = rng.randi_range(int(sk.get("heal_min", 8)), int(sk.get("heal_max", 12)))
			o.char.hp = mini(o.char.max_hp, o.char.hp + amt)
			healed += 1
			_spawn_dmg(o.pos, "+%d" % amt, Color(0.4, 0.9, 0.5))
			_spawn_slash(o.pos, "heal")
	if sk.get("party_def_buff"):
		var add := int(sk.get("party_def_buff"))
		for ou in units:
			if ou.team == team and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	_consume_skill(u.char, sid)
	_log("%s 敌疗「%s」×%d" % [u.char.name, sk.get("name", ""), healed])
	Sfx.skill()
	map_draw.queue_redraw()


func _enemy_arm_offense(ai: int, di: int) -> void:
	var u = units[ai]
	var beh := CKTacticsAI.behavior_for(_unit_theme(u))
	var sit := _enemy_situation(ai, di)
	var ready := func(sid: String) -> bool:
		return _enemy_skill_ready(u.char, sid)
	var best_sid := CKTacticsAI.best_skill(_enemy_known_skills(u.char), ready, sit, "offense", 0.7)
	if best_sid != "" and rng.randf() < CKTacticsAI.cast_gate(float(beh.get("skill", 0.5))):
		skill_mode = true
		active_skill_id = best_sid
		_log("%s 蓄力「%s」" % [u.char.name, GameState.get_skill(best_sid).get("name", best_sid)])
		_spawn_dmg(u.pos, "技", Color(0.95, 0.7, 0.4))


func _tick_skill_cds(team: String) -> void:
	for u in units:
		if u.team != team or u.char.hp <= 0:
			continue
		for sid in u.char.skill_cd.keys():
			var v = int(u.char.skill_cd[sid])
			if v > 0:
				u.char.skill_cd[sid] = v - 1

func _planner_board() -> Dictionary:
	var rows: Array = []
	for u in units:
		var tid := "plain"
		if _in_bounds(u.pos):
			tid = str(terrain[u.pos.y][u.pos.x])
		var reach := BattleRules.attack_reach(u.char, tid, _height_at(u.pos))
		rows.append({
			"id": str(u.char.id),
			"team": str(u.team),
			"pos": [int(u.pos.x), int(u.pos.y)],
			"hp": int(u.char.hp),
			"max_hp": int(u.char.max_hp),
			"move": int(u.char.derived_move()),
			"reach": reach,
			"power": int(u.char.derived_atk()),
			"boss": bool(u.get("boss", false)),
			"tag": str(u.get("tag", "")),
		})
	return {
		"w": MAP_W,
		"h": MAP_H,
		"tier": AIPlanner.tier_of(GameState),
		"objective": BattleObjectives.spec(BattleMaps.get_map(map_id)),
		"units": rows,
		"round": _round_no,
		"summoned": bool(get_meta("ai_summoned", false)),
	}


func _enemy_ai() -> void:
	var ecs: Array = []
	for u in units:
		if u.team == "enemy" and u.char.hp > 0:
			ecs.append(u.char)
	GameState.tick_skill_cooldowns(ecs)
	var ai_plan := {}
	for act in AIPlanner.plan(_planner_board()):
		ai_plan[str(act.get("id", ""))] = act
	for i in units.size():
		var u = units[i]
		if u.team != "enemy" or u.char.hp <= 0:
			continue
		# 敌方自动释放战技（增益优先，再进攻）
		await _enemy_try_skills(i)
		if battle_over:
			return
		if units[i].char.hp <= 0:
			continue
		u = units[i]
		var planned: Dictionary = ai_plan.get(str(u.char.id), {})
		if str(planned.get("action", "")) == "summon" and not has_meta("ai_summoned"):
			set_meta("ai_summoned", true)
			_sync_objectives()
		# 被锁且残血：优先抽身到高防格（不主动贴战）
		var locked_self = int(u.char.temp_combat_lock) > 0
		var mv = _compute_move_cells(i)
		if not mv.has(u.pos):
			mv[u.pos] = 0
		var best_score := -9999.0
		var best_pos: Vector2i = u.pos
		var best_target := -1
		var melee = _is_melee(u.char)
		var beh := CKTacticsAI.behavior_for(_unit_theme(u))
		var foes_player = _enemy_positions("enemy")  # player positions as ZoC sources for enemy
		for pos in mv.keys():
			var stand_tid = terrain[pos.y][pos.x]
			var tinfo = BattleRules.terrain_info(stand_tid)
			var stand_bonus = float(tinfo.get("def_bonus", 0)) * 2.6 + float(tinfo.get("avo_bonus", 0)) * 0.12
			stand_bonus *= 0.65 + float(beh.get("hold", 0.4))
			if stand_tid in ["fort", "forest", "hill"]:
				stand_bonus += 2.0 * (0.45 + float(beh.get("hold", 0.4)))
			# 占位卡住敌方 Cont：邻格有残血玩家则加分
			for j2 in units.size():
				var tj = units[j2]
				if _same_side("player", str(tj.team)) and tj.char.hp > 0 and _manhattan(pos, tj.pos) == 1:
					if float(tj.char.hp) / float(maxi(1, tj.char.max_hp)) < 0.55:
						stand_bonus += 2.4
					break
			# 脱离锁定惩罚：离开交战格更贵，AI 更不愿无意义挪动
			if locked_self and pos != u.pos:
				var still_eng = BattleRules.is_engaged(pos, foes_player)
				if not still_eng:
					var hp_ok = float(u.char.hp) / float(maxi(1, u.char.max_hp))
					stand_bonus -= 5.0 if hp_ok < 0.5 else 6.5  # 血厚时更不愿浪费锁脱
				elif stand_tid == "fort":
					stand_bonus += 5.5  # 锁住时占垒
				elif stand_tid in ["forest", "hill"]:
					stand_bonus += 2.2
			elif (not locked_self) and BattleRules.is_engaged(u.pos, foes_player) and pos != u.pos:
				if not BattleRules.is_engaged(pos, foes_player):
					stand_bonus -= 2.4  # 控带脱离 leave_cost=2 对齐
			for j in units.size():
				var t = units[j]
				if not _same_side("player", str(t.team)) or t.char.hp <= 0:
					continue
				var d = _manhattan(pos, t.pos)
				var reach := BattleRules.attack_reach(u.char, str(stand_tid), _height_at(pos))
				var can_hit = d >= 1 and d <= reach
				if not can_hit:
					var approach = -float(d) * 2.0
					if not melee and d == 1:
						approach -= 4.0
					# 残血被锁：偏向高防撤退格
					if locked_self and float(u.char.hp) / float(maxi(1, u.char.max_hp)) < 0.55:
						approach = stand_bonus * 3.0 - float(d) * 0.25
					var sc2 = approach + stand_bonus
					if str(planned.get("action", "")) == "move":
						var want: Vector2i = planned.get("cell", u.pos)
						if pos == want:
							sc2 += 30.0
					if sc2 > best_score and best_target < 0:
						best_score = sc2
						best_pos = pos
					continue
				var old = u.pos
				u.pos = pos
				var extras = {
					"flank": BattleRules.has_flank(pos, t.pos, units, "enemy", i),
					"height_hit": TerrainFx.height_delta_hit(_height_at(pos), _height_at(t.pos)),
					"weather_hit": TerrainFx.weather_hit(weather, _atk_type(u.char)),
				}
				u.pos = old
				var tid = terrain[t.pos.y][t.pos.x]
				var expect = BattleRules.expected_damage(u.char, t.char, tid, extras)
				if str(planned.get("action", "")) == "attack" and str(t.char.id) == str(planned.get("target", "")):
					expect += 80.0
				if expect >= t.char.hp:
					expect += 20.0
					if locked_self and pos == u.pos:
						expect += 3.0  # 锁定中原地击杀更优
				var hp_frac = float(t.char.hp) / float(maxi(1, t.char.max_hp))
				expect += (1.0 - hp_frac) * 4.5
				if extras.get("flank", false):
					expect += 4.8 * (0.35 + float(beh.get("flank", 0.4)))
				if not melee and d == 2:
					expect += 2.5 * (0.4 + float(beh.get("skirmish", 0.4)))
				elif melee and d == 1 and float(beh.get("skirmish", 0.4)) > 0.72:
					expect -= 1.6
				# 优先咬住已锁定的目标（延长交战）
				if int(t.char.temp_combat_lock) > 0:
					expect += 4.2
				# 已与自己交战相邻：续咬
				if locked_self and _manhattan(u.pos, t.pos) == 1:
					expect += 2.0
				# 威胁残血友军的敌人优先压住
				var threat = false
				for ou in units:
					if ou.team == "enemy" and ou.char.hp > 0 and float(ou.char.hp)/float(maxi(1,ou.char.max_hp)) < 0.50:
						if _manhattan(t.pos, ou.pos) <= 3:
							threat = true
							break
				if threat:
					expect += 4.2 * (0.35 + float(beh.get("protect", 0.4)))
					if BattleRules.is_engaged(pos, foes_player):
						expect += 2.0  # 占控带压残血
				expect *= 0.55 + 0.9 * float(beh.get("aggression", 0.5))
				# 攻击会刷新己方锁定——残血时略减
				if locked_self and float(u.char.hp) / float(maxi(1, u.char.max_hp)) < 0.35:
					expect -= 2.5
				expect += stand_bonus
				if expect > best_score:
					best_score = expect
					best_pos = pos
					best_target = j
		if best_pos != u.pos:
			var origin_ai: Vector2i = u.pos
			u.pos = best_pos
			_spend_zoc(u, origin_ai, best_pos)
			Sfx.play_footstep(str(terrain[best_pos.y][best_pos.x]))
			_spawn_move_dust(best_pos)
			_log_enemy_move(u, best_pos)
			map_draw.queue_redraw()
		if best_target >= 0:
			var d2 = _manhattan(u.pos, units[best_target].pos)
			var reach2 := BattleRules.attack_reach(u.char, str(terrain[u.pos.y][u.pos.x]), _height_at(u.pos))
			var ok = d2 >= 1 and d2 <= reach2
			if ok:
				var tgt = units[best_target]
				# 敌方进攻战技
				_enemy_arm_offense(i, best_target)
				var pv = BattleRules.preview(u.char, tgt.char, terrain[tgt.pos.y][tgt.pos.x], _combat_extras(i, best_target))
				_spawn_dmg(tgt.pos, "%d%%" % int(pv.hit), Color(0.85, 0.85, 0.95))
				_do_attack(i, best_target)
				skill_mode = false
				active_skill_id = ""
				await get_tree().create_timer(0.28).timeout
				if battle_over:
					return
				continue
		map_draw.queue_redraw()
		await get_tree().create_timer(0.18).timeout
		if battle_over:
			return

func _sync_objectives() -> void:
	if battle_over:
		return
	var fresh: Array = BattleObjectives.spawn_due(self, BattleMaps.get_map(map_id), _round_no)
	for u in fresh:
		_arm_spawned(u)
	if not fresh.is_empty() and map_draw:
		map_draw.queue_redraw()
	ObjectiveHud.refresh(self)
	_check_end()


func _arm_spawned(u: Dictionary) -> void:
	if str(u.get("team", "")) == "enemy":
		CKEnemyLoadout.stamp_enemy(u.char, CKEnemyLoadout.mode_of(GameState))
		var elite = u.char.is_leader or str(u.char.name).find("首") >= 0 or u.char.level >= 4
		var diff = GameState.battle_difficulty_from_map(map_id)
		GameState.grant_battle_enemy_skills(u.char, elite, diff, map_id, str(u.get("template", "")))
	else:
		GameState.grant_job_skills(u.char)
		World.grant_gear_skills(u.char)
	GameState.reset_battle_skills([u.char])


func _check_end() -> void:
	if battle_over:
		return
	ObjectiveHud.refresh(self)
	var verdict := BattleObjectives.outcome(BattleMaps.get_map(map_id), units, _round_no)
	var result := str(verdict.get("result", "continue"))
	if result == "continue":
		return
	set_meta("battle_verdict", verdict)
	_finish(result == "win")

var _world_enc := false

func _finish(win: bool) -> void:
	if battle_over:
		return
	battle_over = true
	_world_enc = GameState.has_meta("world_encounter")
	var purse := 0
	var sp_gain := 0
	var exp_before := {}
	for u in units:
		if u.team == "player":
			exp_before[u.char.id] = [int(u.char.exp), int(u.char.hp) <= 0]
	if win:
		GameState.set_flag("battle_done")
		purse = BattleVictory.base_purse(GameState.house_mods)
		GameState.silver += purse
		GameState.add_rep("ashland", 8)
		for u in units:
			if u.team == "player" and u.char.hp > 0:
				u.char.exp += 15
				_bark(u.char, "shout")
			elif u.team == "player":
				u.char.hp = maxi(1, int(u.char.max_hp * 0.3))
				u.char.injured = true
		Music.play_victory()
		Sfx.win()
		if not bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)):
			Sfx.fanfare()
		_log("【胜利】%s肃清。+%d 银。" % [map_name, purse])
		_mark_map_victory()
		GameState.on_battle_quest_victory()
		sp_gain = BattleVictory.skill_points(bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)))
		if sp_gain > 0:
			GameState.add_skill_point(sp_gain)
			_log("获得战技点 +1（当前 %d）" % GameState.skill_points)
		# 战勋旁注微奖
		var memory_bonus := BattleVictory.memory_bonus(GameState.house_mods)
		if memory_bonus > 0:
			GameState.silver += memory_bonus
		phase_label.text = "★ " + Locale.t("battle_win") + " ★"
		phase_label.add_theme_color_override("font_color", UIKit.ACCENT)
	else:
		Music.play_defeat()
		Sfx.lose()
		_log("【败北】可重试，进度旗标保留。")
		var why := BattleObjectives.defeat_line(str(get_meta("battle_verdict", {}).get("reason", "")))
		if why != "":
			_log(why)
		phase_label.text = Locale.t("battle_lose")
		phase_label.add_theme_color_override("font_color", UIKit.DANGER)
		CKEnemyLoadout.apply_defeat(units, CKEnemyLoadout.mode_of(GameState))
	if _world_enc:
		var wr: Dictionary = World.on_battle_end(win)  # v8.7 overworld encounter → loot / quest objective / retreat
		if not wr.is_empty():
			_log(str(wr.get("msg", "")))
	for u in units:
		CKEnemyLoadout.unstamp(u.char)
	GameState.save_game()
	CKAutosave.after_battle()
	var finished := {
		"win": win,
		"map_id": map_id,
		"silver": purse if win else 0,
		"skill_points": sp_gain,
		"flags": BattleVictory.spec(map_id).flags if win else [],
		"reason": str(get_meta("battle_verdict", {}).get("reason", "")),
	}
	battle_finished.emit(finished)
	_show_report(win, purse, sp_gain, exp_before)

func _show_report(win: bool, purse: int, sp_gain: int, exp_before: Dictionary) -> void:
	BattleReport.present(self, win, purse, sp_gain, exp_before)



func _mark_map_victory() -> void:
	BattleVictory.apply(map_id)


func _refresh_info_for(ui: int) -> void:
	BattleInfoPanel.refresh_for(self, ui)


func _fill_info_traits(c: CKCharacter) -> void:
	BattleInfoPanel.fill_traits(self, c)


func _refresh_info() -> void:
	BattleInfoPanel.refresh(self)


func _note_unit_downed(u, killer) -> void:
	if u == null or u.char == null or int(u.char.hp) > 0:
		return
	var info := {
		"team": str(u.team),
		"map_id": map_id,
		"name": str(u.char.name),
		"pos": [int(u.pos.x), int(u.pos.y)],
		"killer": str(killer.name) if killer != null else "",
	}
	unit_downed.emit(u.char, info)

func _arm_lamps() -> void:
	if _lamps_armed:
		return
	_lamps_armed = true
	var diff := int(GameState.battle_difficulty_from_map(map_id))
	var rule := CKEnemyLoadout.lamp_rule(diff, CKEnemyLoadout.mode_of(GameState))
	_lamp_max = int(rule.get("charges", 0))
	_lamp_charges = _lamp_max
	_lamp_refill = bool(rule.get("refill", false))
	set_meta("ai_tier", int(rule.get("ai_tier", 1)))


func _seal_turn() -> void:
	BattleSnapshot.seal_turn(self)


func _push_lamp() -> void:
	BattleSnapshot.push_lamp(self)


func _undo_move() -> void:
	BattleSnapshot.undo_move(self)


func _rewind_lamp() -> void:
	BattleSnapshot.rewind_lamp(self)


func _log(t: String) -> void:
	var line := t
	if Locale.is_en() and Locale.has_cjk(line):
		line = Locale.latin(line, "")
		if line == "":
			return
	var lines := (line + "\n" + log_label.text).split("\n")
	log_label.text = "\n".join(lines.slice(0, mini(lines.size(), 12)))


func _restore_heir_clash_hp() -> void:
	BattleVictory.restore_heir_clash()

