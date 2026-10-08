class_name CombatCutscene
extends CanvasLayer
## v8.6 / v9.2 combat cutscene. Tactics stay synchronous; this layer only plays a record.
## Timing comes from CutsceneTimeline so headless tests can read the duration without rendering.
signal finished

static var speed: float = 1.0
static var stages_built: int = 0

var rec: Dictionary
var _vp: SubViewport
var _cam: Camera3D
var _units := {}
var _hud := {}
var _root: Control
var _flash: ColorRect
var _skip := false
var _bars: Array = []
var _shake := 0.0
var _spd_btn: Button
var _budget: Dictionary = {}
var _pop_stack: Dictionary = {}
var _mode := CutsceneTimeline.MODE_FULL
var _stage: Node3D
var _holding_ff := false
var _keys_down := 0
var _key_down_msec := 0
var _pointer_down := false
var _pointer_down_msec := 0
var _done := false
var _world: Node3D

func setup(record: Dictionary) -> void:
	rec = record

func _ready() -> void:
	var settings: Dictionary = {}
	if GameState != null and typeof(GameState.settings) == TYPE_DICTIONARY:
		settings = GameState.settings
	_mode = CutsceneTimeline.resolve_mode(settings)
	speed = maxf(speed, float(settings.get("cutscene_speed", 1.0)))
	if not CutsceneTimeline.should_instantiate(rec, _mode):
		call_deferred("_finish")
		return
	_budget = DeviceProfile.cutscene_budget()
	UnitModel.prefer_simple_shading = bool(_budget.get("simple", false))
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui)
	add_child(_root)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = int(_budget.get("msaa", Viewport.MSAA_4X))
	_vp.size = _budget.get("size", Vector2i(1280, 720))
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	svc.add_child(_vp)
	_build_stage()
	_build_hud()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.12)
	_run()

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var key_hold := _keys_down > 0 and now - _key_down_msec >= CutsceneTimeline.HOLD_MSEC
	var ptr_hold := _pointer_down and now - _pointer_down_msec >= CutsceneTimeline.HOLD_MSEC
	if (key_hold or ptr_hold) and not _holding_ff and not _skip:
		_set_hold(true)
	if _cam and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.2)
		var s := _shake * _shake
		_cam.h_offset = sin(Time.get_ticks_msec() * 0.07) * 0.06 * s
		_cam.v_offset = cos(Time.get_ticks_msec() * 0.09) * 0.04 * s
	elif _cam:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	if _stage != null and is_instance_valid(_stage) and _cam != null:
		CutsceneStage.parallax(_stage, _cam.position.x)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey):
		return
	var k := e as InputEventKey
	if k.echo:
		get_viewport().set_input_as_handled()
		return
	if k.pressed:
		if _keys_down == 0:
			_key_down_msec = Time.get_ticks_msec()
		_keys_down += 1
	else:
		var held := Time.get_ticks_msec() - _key_down_msec
		_keys_down = maxi(0, _keys_down - 1)
		if _keys_down == 0 and _holding_ff and not _pointer_down:
			_set_hold(false)
		elif held < CutsceneTimeline.HOLD_MSEC and not _holding_ff:
			if k.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
				_do_skip()
			elif k.keycode in [KEY_TAB, KEY_S]:
				_toggle_speed()
	get_viewport().set_input_as_handled()

func _on_gui(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := e as InputEventMouseButton
		if m.pressed:
			_pointer_down = true
			_pointer_down_msec = Time.get_ticks_msec()
		else:
			_pointer_down = false
			if _holding_ff and _keys_down == 0:
				_set_hold(false)
	elif e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_pointer_down = true
			_pointer_down_msec = Time.get_ticks_msec()
		else:
			_pointer_down = false
			if _holding_ff and _keys_down == 0:
				_set_hold(false)

func _effective_speed() -> float:
	return CutsceneTimeline.effective_speed(speed, _holding_ff)

func _set_hold(on: bool) -> void:
	_holding_ff = on
	_refresh_speed_label()
	_sync_anim_speed()

func _refresh_speed_label() -> void:
	if _spd_btn:
		_spd_btn.text = "%d×" % int(round(_effective_speed()))

# ---------------------------------------------------------------- stage
func _build_stage() -> void:
	stages_built += 1
	var w := Node3D.new()
	_world = w
	_vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#07080C")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.50, 0.64)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	var biome := CutsceneStage.biome_from_record(rec)
	var fog_cfg := CutsceneStage.fog_for(biome)
	env.fog_enabled = bool(_budget.get("fog", true))
	env.fog_light_color = fog_cfg.get("color", Color(0.10, 0.13, 0.19))
	env.fog_density = float(fog_cfg.get("density", 0.035))
	env.glow_enabled = bool(_budget.get("glow", true))
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var bb := str(rec.get("backdrop", ""))
	if bb != "" and ResourceLoader.exists(bb):
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(72, 40)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(bb)
		m.albedo_color = Color(0.58, 0.64, 0.74)
		q.material_override = m
		q.position = Vector3(0, 9.0, -15)
		w.add_child(q)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 40)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	var gt := "res://assets/art/terrain_v86/%s.png" % str(rec.get("ground", "grass"))
	if ResourceLoader.exists(gt):
		gm.albedo_texture = load(gt)
	gm.uv1_scale = Vector3(30, 20, 1)
	gm.roughness = 0.92
	gm.albedo_color = rec.get("grade", Color(0.86, 0.90, 0.94))
	g.material_override = gm
	w.add_child(g)
	var low_tier := float(_budget.get("particles", 1.0)) <= 0.01
	_stage = CutsceneStage.build(w, biome, low_tier)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color(0.88, 0.94, 1.0)
	key.light_energy = 1.25
	key.shadow_enabled = bool(_budget.get("shadows", true))
	key.directional_shadow_max_distance = 30.0
	w.add_child(key)
	for side in ["left", "right"]:
		var pack = rec.get(side, {})
		if typeof(pack) != TYPE_DICTIONARY or pack.get("char") == null:
			continue
		var team := str(pack.get("team", "player"))
		var spec: Dictionary = UnitModel.resolve(pack.char, team, str(pack.get("template", "")))
		var o := OmniLight3D.new()
		if team == "enemy" and spec.get("trim", null) is Color:
			o.light_color = spec["trim"]
		else:
			o.light_color = UIKit.OK if team != "enemy" else UIKit.DANGER
		o.light_energy = 2.4
		o.omni_range = 4.0
		o.position = Vector3(-2.6 if side == "left" else 2.6, 2.2, -1.6)
		w.add_child(o)
	for side in ["left", "right"]:
		var d = rec.get(side, {})
		if typeof(d) != TYPE_DICTIONARY or d.get("char") == null:
			var empty := Node3D.new()
			var x0 := -1.7 if side == "left" else 1.7
			empty.position = Vector3(x0, 0, 0)
			w.add_child(empty)
			_units[side] = {"node": empty, "anim": null, "home": empty.position, "char": null, "team": "player", "ranged": false}
			continue
		var n := UnitModel.instantiate(d.char, str(d.team), str(d.get("template", "")))
		if n == null:
			n = Node3D.new()
		var x := -1.7 if side == "left" else 1.7
		n.position = Vector3(x, 0, 0)
		n.rotation_degrees = Vector3(0, 90 if side == "left" else -90, 0)
		w.add_child(n)
		var ap := UnitModel.find_anim(n)
		var ranged := UnitModel.is_ranged(d.char)
		_units[side] = {"node": n, "anim": ap, "home": n.position, "char": d.char, "team": d.team, "ranged": ranged}
		_play(side, "idle")
		if int(d.get("hp0", 1)) <= 0:
			n.visible = false
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_cam.position = Vector3(0, 1.35, 5.2)
	_cam.look_at_from_position(_cam.position, Vector3(0, 1.15, 0), Vector3.UP)
	_cam.current = true
	w.add_child(_cam)

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.027, 0.031, 0.047, 0.92)
		bar.size = Vector2(1280, 0)
		bar.position = Vector2(0, 0 if i == 0 else 720)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
		_bars.append(bar)
		var tw := create_tween()
		tw.tween_property(bar, "size:y", 48.0, 0.18)
		if i == 1:
			create_tween().tween_property(bar, "position:y", 672.0, 0.18)
	for side in ["left", "right"]:
		var d = rec.get(side, {})
		if typeof(d) != TYPE_DICTIONARY or d.get("char") == null:
			continue
		var enemy := str(d.team) == "enemy"
		var tc: Color = UIKit.DANGER if enemy else UIKit.OK
		var p := UIKit.make_glass(14, 0.82)
		p.position = Vector2(40 if side == "left" else 820, 548)
		p.custom_minimum_size = Vector2(420, 0)
		p.size = Vector2(420, 0)
		_root.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		var role := BattleRules.role_label(BattleRules.job_role(d.char.job_id))
		var who := CutsceneTimeline.line("cutscene.enemy") if enemy else CutsceneTimeline.line("cutscene.ally")
		v.add_child(UIKit.eyebrow("%s · %s · LV %d" % [who, role, int(d.char.level)], tc))
		var nm := Label.new()
		nm.text = str(d.char.name)
		nm.add_theme_font_size_override("font_size", 22)
		v.add_child(nm)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		var hp := ProgressBar.new()
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(290, 8)
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp.max_value = maxi(1, int(d.char.max_hp))
		hp.value = int(d.get("hp0", d.char.hp))
		var fill := StyleBoxFlat.new()
		fill.bg_color = tc
		fill.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		bg.set_corner_radius_all(4)
		hp.add_theme_stylebox_override("fill", fill)
		hp.add_theme_stylebox_override("background", bg)
		row.add_child(hp)
		var ht := Label.new()
		ht.text = "%d / %d" % [int(d.get("hp0", d.char.hp)), int(d.char.max_hp)]
		ht.add_theme_font_override("font", UIKit.font("mono"))
		ht.add_theme_font_size_override("font_size", 18)
		row.add_child(ht)
		var st := Label.new()
		st.text = CutsceneTimeline.line("cutscene.forecast") % [str(d.get("hit", "—")), str(d.get("dmg", "—")), str(d.get("crit", "—"))]
		st.add_theme_font_override("font", UIKit.font("mono"))
		st.add_theme_font_size_override("font_size", 12)
		st.add_theme_color_override("font_color", UIKit.TEXT_DIM)
		v.add_child(st)
		_hud[side] = {"hp": hp, "txt": ht, "max": int(d.char.max_hp)}
	var tr := HBoxContainer.new()
	tr.position = Vector2(1280 - 40 - 220, 6)
	tr.add_theme_constant_override("separation", 8)
	_root.add_child(tr)
	_spd_btn = UIKit.make_button("%d×" % int(round(speed)), 64)
	var hud_h := 36
	if DeviceProfile.is_mobile():
		hud_h = int(minf(64.0, maxf(44.0, DeviceProfile.hit_px())))
	_spd_btn.custom_minimum_size = Vector2(64 if hud_h <= 40 else 88, hud_h)
	_spd_btn.tooltip_text = CutsceneTimeline.line("cutscene.speed_tip")
	_spd_btn.pressed.connect(_toggle_speed)
	tr.add_child(_spd_btn)
	var sk := UIKit.make_button(CutsceneTimeline.line("cutscene.skip"), 140)
	sk.custom_minimum_size = Vector2(140 if hud_h <= 40 else 168, hud_h)
	sk.tooltip_text = CutsceneTimeline.line("cutscene.skip_tip")
	sk.pressed.connect(_do_skip)
	tr.add_child(sk)
	var title := Label.new()
	title.text = str(rec.get("title", ""))
	title.position = Vector2(40, 12)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	_root.add_child(title)
	_flash = ColorRect.new()
	_flash.color = Color(0.93, 0.96, 1.0, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

func _toggle_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0
	_refresh_speed_label()
	_sync_anim_speed()

func _do_skip() -> void:
	if _skip:
		return
	_skip = true
	_finish()

func _wait(t: float) -> void:
	## Wall-clock wait so hit-stop (Engine.time_scale) does not stretch the timeline.
	if _skip or t <= 0.0:
		return
	var left := t
	while left > 0.001 and not _skip:
		var slice := minf(left, 0.05)
		var need := int(ceil(slice / _effective_speed() * 1000.0))
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < need and not _skip:
			await get_tree().process_frame
		left -= slice

func _sync_anim_speed() -> void:
	var spd := _effective_speed()
	for side in _units.keys():
		var ap: AnimationPlayer = _units[side].anim
		if ap:
			ap.speed_scale = spd

func _play(side: String, an: String, blend: float = 0.08) -> void:
	if not _units.has(side):
		return
	var ap: AnimationPlayer = _units[side].anim
	if ap and ap.has_animation(an):
		ap.speed_scale = _effective_speed()
		ap.play(an, blend)

func _tw() -> Tween:
	var t := create_tween()
	t.set_speed_scale(_effective_speed())
	return t

func _cam_to(pos: Vector3, look: Vector3, fov: float, dur: float) -> void:
	if _skip or _cam == null:
		return
	fov = clampf(fov, 28.0, 34.0)
	var target := Transform3D.IDENTITY.translated(pos).looking_at(look, Vector3.UP)
	var t := _tw()
	t.set_parallel(true)
	t.tween_property(_cam, "transform", target, maxf(0.04, dur)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "fov", fov, maxf(0.04, dur)).set_trans(Tween.TRANS_CUBIC)

func _popup(side: String, text: String, col: Color, big: bool) -> void:
	if _cam == null or not _units.has(side):
		return
	var n: Node3D = _units[side].node
	var sp := _cam.unproject_position(n.global_position + Vector3(0, 1.85, 0))
	var k: int = int(_pop_stack.get(side, 0))
	_pop_stack[side] = k + 1
	var numeric := text.is_valid_int() or text.begins_with("-") or text.begins_with("+")
	var fs := 48 if big else 36
	if not numeric:
		fs = 28 if not big else 36
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font("mono") if numeric else UIKit.font("bold"))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.027, 0.031, 0.047, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	var w := 360.0
	var h := float(fs) + 16.0
	var top := 116.0
	var y := sp.y - h - k * (h + 4.0)
	if sp.y - h < top + float(k) * (h + 4.0) + 0.5:
		y = top + float(k) * (h + 4.0)
	y = clampf(y, top, 500.0 - h)
	var x := clampf(sp.x - w * 0.5, 40.0, 1240.0 - w)
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(w * 0.5, h * 0.5)
	l.scale = Vector2(0.4, 0.4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	var tw := _tw()
	tw.tween_property(l, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.06)
	tw.tween_property(l, "position:y", l.position.y - 28, 0.45)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.2)
	tw.tween_callback(func():
		_pop_stack[side] = maxi(0, int(_pop_stack.get(side, 1)) - 1)
		if is_instance_valid(l):
			l.queue_free())

func _sparks(side: String, col: Color, amount: int) -> void:
	var scale := float(_budget.get("particles", 1.0))
	if scale <= 0.01 or not _units.has(side):
		return
	var n: Node3D = _units[side].node
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(1, int(round(float(amount) * scale)))
	p.lifetime = 0.35
	p.explosiveness = 0.95
	p.direction = Vector3(0, 0.5, 0)
	p.spread = 70
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 4.8
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.045
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.2
	mesh.material = m
	p.mesh = mesh
	p.position = n.position + Vector3(0, 1.2, 0)
	n.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())

func _arrow(from_side: String, to_side: String, dur: float) -> void:
	if not _units.has(from_side) or not _units.has(to_side):
		return
	var a: Node3D = _units[from_side].node
	var b: Node3D = _units[to_side].node
	var ch = _units[from_side].get("char", null)
	var job := ""
	if ch != null:
		job = str(ch.job_id)
	var kind := "bolt" if job in ["apprentice", "priest"] else "arrow"
	var col: Color = UIKit.DANGER if str(_units[from_side].team) == "enemy" else UIKit.ACCENT
	var p0 := a.position + Vector3(0, 1.35, 0)
	var p1 := b.position + Vector3(0, 1.25, 0)
	var proj := CutsceneSignature.spawn_projectile(a.get_parent(), p0, p1, kind, col, float(_budget.get("particles", 1.0)))
	var t := _tw()
	t.tween_property(proj, "position", p1, maxf(0.05, dur))
	var holder: WeakRef = weakref(proj)
	t.tween_callback(func():
		var alive: Object = holder.get_ref()
		if alive != null:
			alive.call("queue_free"))

func _royal_vfx(side: String, strike: Dictionary) -> void:
	var n := _node(side)
	if n == null or n.get_parent() == null:
		return
	CutsceneSignature.spawn_signature(n.get_parent(), n.position + Vector3(0, 1.45, 0), str(strike.get("skill_id", "")), str(strike.get("skill", "")), float(_budget.get("particles", 1.0)))

func _set_hp(side: String, v: int) -> void:
	if not _hud.has(side):
		return
	var h: Dictionary = _hud[side]
	var pb: ProgressBar = h.hp
	if _skip:
		pb.value = v
	else:
		_tw().tween_property(pb, "value", float(v), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	h.txt.text = "%d / %d" % [v, int(h.max)]

func _prepared_record() -> Dictionary:
	var copy := rec.duplicate(false)
	var strikes: Array = []
	for s in rec.get("strikes", []):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = s.duplicate(false)
		if not bool(one.get("ranged", false)):
			var side := str(one.get("from", "left"))
			if _units.has(side):
				one["ranged"] = bool(_units[side].get("ranged", false))
		strikes.append(one)
	copy["strikes"] = strikes
	return copy

func _run() -> void:
	var tl := CutsceneTimeline.for_record(_prepared_record(), _mode)
	var index := int(rec.get("camera_index", 0))
	for built in tl.get("strikes", []):
		if _skip:
			break
		await _play_built(built, index)
		index += 1
	_finish()

func _play_built(built: Dictionary, index: int) -> void:
	var strike: Dictionary = built.get("strike", {})
	var a := str(strike.get("from", "left"))
	var d := "right" if a == "left" else "left"
	var action := str(built.get("action", "attack"))
	var ranged := bool(built.get("ranged", false))
	var dir := 1.0 if a == "left" else -1.0
	var template := CutsceneCameras.select(strike, index)
	var total := maxf(0.001, float(built.get("total", 1.0)))
	var elapsed := 0.0
	for seg in built.get("segments", []):
		if _skip:
			return
		var sid := str(seg.get("id", ""))
		var dur := float(seg.get("dur", 0.0))
		_aim_template(template, elapsed / total, dur, dir)
		_begin_segment(sid, dur, a, d, dir, action, ranged, strike)
		elapsed += dur
		if sid == "hitstop":
			Engine.time_scale = 0.4
			await _wait(dur)
			Engine.time_scale = 1.0
		else:
			await _wait(dur)

func _aim_template(template: String, t: float, dur: float, dir: float) -> void:
	var pose := CutsceneCameras.sample(template, t, {"dir": dir})
	_cam_to(pose.get("pos", Vector3(0, CutsceneCameras.EYE_Y, 4.8)), pose.get("look", Vector3(0, CutsceneCameras.EYE_Y, 0)), float(pose.get("fov", 32.0)), dur)

func _begin_segment(sid: String, dur: float, a: String, d: String, dir: float, action: String, ranged: bool, strike: Dictionary) -> void:
	_sync_anim_speed()
	var an := _node(a)
	var dn := _node(d)
	match sid:
		"outro":
			if an and not ranged and not bool(strike.get("killed", false)):
				_play(a, "advance")
				_tw().tween_property(an, "position:x", float(_units[a].home.x), dur)
			else:
				_play(a, "idle", 0.12)
			if not bool(strike.get("killed", false)):
				_play(d, "idle", 0.12)
		"approach", "aim":
			if not ranged:
				_play(a, "advance")
				if an and dn:
					_tw().tween_property(an, "position:x", dn.position.x - dir * 1.05, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		"name":
			if str(strike.get("skill", "")) != "":
				_popup(a, "「%s」" % str(strike.get("skill", "")), UIKit.ACCENT, false)
		"swing":
			_play(a, action, 0.05)
			if ranged:
				_arrow(a, d, dur)
			if CutsceneTimeline.is_royal_skill(str(strike.get("skill", ""))) or CutsceneTimeline.is_royal_skill(str(strike.get("skill_id", ""))):
				_royal_vfx(a, strike)
		"hitstop", "react":
			_apply_hit(a, d, dir, strike, sid == "hitstop")
		"whiff":
			_play(d, "dodge", 0.05)
			if dn:
				var dz := _tw()
				dz.tween_property(dn, "position:z", -0.42, minf(0.12, dur))
				dz.tween_property(dn, "position:z", 0.0, maxf(0.08, dur * 0.6))
			_popup(d, CutsceneTimeline.line("cutscene.miss"), UIKit.TEXT_DIM, false)
		"death":
			_play(d, "death", 0.05)
			_popup(d, CutsceneTimeline.line("cutscene.break"), UIKit.DANGER, false)
		"recover":
			if not bool(strike.get("killed", false)):
				_play(d, "idle", 0.12)

func _apply_hit(a: String, d: String, dir: float, strike: Dictionary, from_stop: bool) -> void:
	if not bool(strike.get("hit", false)):
		return
	if not from_stop and _segment_has_hitstop(strike):
		return
	_play(d, "hit", 0.04)
	var crit := bool(strike.get("crit", false))
	var reduced := bool(GameState.settings.get("reduced_motion", false)) if GameState != null else false
	_shake = 0.0 if reduced else (0.85 if crit else 0.4)
	var spark := UIKit.EMBER if crit else Color(0.85, 0.95, 1.0)
	_sparks(d, spark, 36 if crit else 16)
	if _flash:
		_flash.color = Color(0.93, 0.97, 1.0, 0.42 if crit else 0.14)
		_tw().tween_property(_flash, "color:a", 0.0, 0.16)
	if crit:
		_popup(d, CutsceneTimeline.line("cutscene.crit"), UIKit.ACCENT, false)
	var ally_hurt := str(_units[d].team) != "enemy" if _units.has(d) else false
	_popup(d, "-%d" % int(strike.get("dmg", 0)), UIKit.DANGER if ally_hurt else Color(0.96, 0.98, 1.0), crit)
	var dn := _node(d)
	if dn:
		var push := _tw()
		push.tween_property(dn, "position:x", dn.position.x + dir * 0.14, 0.06)
		push.tween_property(dn, "position:x", dn.position.x, 0.16)
	_set_hp(d, int(strike.get("hp_after", 0)))

func _segment_has_hitstop(strike: Dictionary) -> bool:
	return CutsceneTimeline.hit_stop_duration(strike) > 0.0

func _node(side: String) -> Node3D:
	if not _units.has(side):
		return null
	return _units[side].node

func _finish() -> void:
	if _done:
		return
	_done = true
	_holding_ff = false
	UnitModel.prefer_simple_shading = false
	Engine.time_scale = 1.0
	for s in rec.get("strikes", []):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var d: String = "right" if str(s.get("from", "")) == "left" else "left"
		if _hud.has(d):
			_hud[d].hp.value = int(s.get("hp_after", _hud[d].hp.value))
			_hud[d].txt.text = "%d / %d" % [int(s.get("hp_after", 0)), int(_hud[d].max)]
	if _root == null:
		finished.emit()
		queue_free()
		return
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.12)
	t.tween_callback(func():
		finished.emit()
		queue_free())
