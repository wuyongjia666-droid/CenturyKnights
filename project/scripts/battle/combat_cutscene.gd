extends CanvasLayer
## v8.6 Fire-Emblem-style 3D combat cutscene. Plays a RECORD of strikes that the tactics logic already
## resolved (logic is untouched and synchronous) on a biome-matched 3D stage:
## advance → attack / skill / crit → hit / dodge / death, damage numbers, HP bars, skip + speed toggle.
signal finished

const FPS_IMPACT := {"attack": 0.458, "skill": 0.792, "crit": 0.5}
static var speed: float = 1.0

var rec: Dictionary
var _vp: SubViewport
var _cam: Camera3D
var _units := {}        # side -> {"node","anim","home","char","team","ranged"}
var _hud := {}          # side -> {"hp","hp_txt","fill"}
var _root: Control
var _flash: ColorRect
var _skip := false
var _bars: Array = []
var _cam_base: Transform3D
var _shake := 0.0
var _spd_btn: Button

var _pop_stack: Dictionary = {}

func setup(record: Dictionary) -> void:
	rec = record

func _ready() -> void:
	speed = maxf(speed, float(GameState.settings.get("cutscene_speed", 1.0)))
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(1280, 720)
	svc.add_child(_vp)
	_build_stage()
	_build_hud()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)
	_run()

func _process(delta: float) -> void:
	if _cam and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.6)
		var s := _shake * _shake
		_cam.h_offset = sin(Time.get_ticks_msec() * 0.07) * 0.08 * s
		_cam.v_offset = cos(Time.get_ticks_msec() * 0.09) * 0.06 * s
	elif _cam:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			_do_skip()
		elif e.keycode in [KEY_TAB, KEY_S]:
			_toggle_speed()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- stage
func _build_stage() -> void:
	var w := Node3D.new()
	_vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#07080C")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.50, 0.64)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.13, 0.19)
	env.fog_density = 0.035
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	# biome vista (the painted biome plate, deep behind the duel)
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
		m.disable_fog = false
		q.material_override = m
		q.position = Vector3(0, 9.0, -15)
		w.add_child(q)
	# ground: the defender cell terrain (same authored terrain as the board)
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
	gm.albedo_color = rec.get("grade", Color(1, 1, 1))
	g.material_override = gm
	w.add_child(g)
	# lights: cool key + team rims
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color(0.88, 0.94, 1.0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	w.add_child(key)
	for side in ["left", "right"]:
		var o := OmniLight3D.new()
		var team := str(rec[side].team)
		var spec: Dictionary = UnitModel.resolve(rec[side].char, team, str(rec[side].get("template", "")))
		if team == "enemy" and spec.get("trim", null) is Color:
			o.light_color = spec["trim"]
		else:
			o.light_color = UIKit.OK
		o.light_energy = 3.0
		o.omni_range = 4.0
		o.position = Vector3(-2.6 if side == "left" else 2.6, 2.2, -1.6)
		w.add_child(o)
	# units — theme spec picks the reused GLB (palette / outfit / weapon) for this enemy
	for side in ["left", "right"]:
		var d: Dictionary = rec[side]
		var n := UnitModel.instantiate(d.char, str(d.team), str(d.get("template", "")))
		if n == null:
			n = Node3D.new()
		var x := -1.7 if side == "left" else 1.7
		n.position = Vector3(x, 0, 0)
		n.rotation_degrees = Vector3(0, 90 if side == "left" else -90, 0)
		w.add_child(n)
		var ap := UnitModel.find_anim(n)
		_units[side] = {"node": n, "anim": ap, "home": n.position, "char": d.char, "team": d.team, "ranged": UnitModel.is_ranged(d.char)}
		_play(side, "idle")
		if int(d.hp0) <= 0:
			n.visible = false
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.position = Vector3(0, 1.55, 6.2)
	_cam.look_at_from_position(_cam.position, Vector3(0, 1.05, 0), Vector3.UP)
	_cam.current = true
	w.add_child(_cam)
	_cam_base = _cam.transform

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.size = Vector2(1280, 0)
		bar.position = Vector2(0, 0 if i == 0 else 720)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
		_bars.append(bar)
		var tw := create_tween()
		tw.tween_property(bar, "size:y", 48.0, 0.25)
		if i == 1:
			create_tween().tween_property(bar, "position:y", 672.0, 0.25)
	for side in ["left", "right"]:
		var d: Dictionary = rec[side]
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
		v.add_child(UIKit.eyebrow("%s · %s · LV %d" % ["敌军" if enemy else "我军", role, int(d.char.level)], tc))
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
		hp.value = int(d.hp0)
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
		ht.text = "%d / %d" % [int(d.hp0), int(d.char.max_hp)]
		ht.add_theme_font_override("font", UIKit.font("mono"))
		ht.add_theme_font_size_override("font_size", 18)
		row.add_child(ht)
		var st := Label.new()
		st.text = "命中 %s　伤害 %s　暴击 %s" % [str(d.get("hit", "—")), str(d.get("dmg", "—")), str(d.get("crit", "—"))]
		st.add_theme_font_override("font", UIKit.font("mono"))
		st.add_theme_font_size_override("font_size", 12)
		st.add_theme_color_override("font_color", UIKit.TEXT_DIM)
		v.add_child(st)
		_hud[side] = {"hp": hp, "txt": ht, "max": int(d.char.max_hp)}
	var tr := HBoxContainer.new()
	tr.position = Vector2(1280 - 40 - 220, 6)
	tr.add_theme_constant_override("separation", 8)
	_root.add_child(tr)
	_spd_btn = UIKit.make_button("%d×" % int(speed), 64)
	_spd_btn.custom_minimum_size = Vector2(64, 36)
	_spd_btn.tooltip_text = "演出速度（Tab）"
	_spd_btn.pressed.connect(_toggle_speed)
	tr.add_child(_spd_btn)
	var sk := UIKit.make_button("跳过  ␣", 140)
	sk.custom_minimum_size = Vector2(140, 36)
	sk.tooltip_text = "跳过演出（Space / Esc）"
	sk.pressed.connect(_do_skip)
	tr.add_child(sk)
	var title := Label.new()
	title.text = str(rec.get("title", ""))
	title.position = Vector2(40, 12)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	_root.add_child(title)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

func _toggle_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0
	if _spd_btn:
		_spd_btn.text = "%d×" % int(speed)
	for side in _units.keys():
		var ap: AnimationPlayer = _units[side].anim
		if ap:
			ap.speed_scale = speed

func _do_skip() -> void:
	if _skip:
		return
	_skip = true
	_finish()

# ---------------------------------------------------------------- helpers
func _wait(t: float) -> void:
	if _skip:
		return
	await get_tree().create_timer(t / speed, true, false, true).timeout

func _play(side: String, an: String, blend: float = 0.12) -> void:
	var ap: AnimationPlayer = _units[side].anim
	if ap and ap.has_animation(an):
		ap.speed_scale = speed
		ap.play(an, blend)

func _tw() -> Tween:
	var t := create_tween()
	t.set_speed_scale(speed)
	return t

func _cam_to(pos: Vector3, look: Vector3, fov: float, dur: float) -> void:
	if _skip:
		return
	var target := Transform3D.IDENTITY.translated(pos).looking_at(look, Vector3.UP)
	var t := _tw()
	t.set_parallel(true)
	t.tween_property(_cam, "transform", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "fov", fov, dur).set_trans(Tween.TRANS_CUBIC)

func _popup(side: String, text: String, col: Color, big: bool) -> void:
	## v8.7: popups live inside the letterbox safe area (y 64..500) and stack per side, so 暴击 / -25 / 击破
	## never clip under the bars or overlap each other.
	var n: Node3D = _units[side].node
	var sp := _cam.unproject_position(n.global_position + Vector3(0, 1.95, 0))
	var k: int = int(_pop_stack.get(side, 0))
	_pop_stack[side] = k + 1
	var fs := 54 if big else 40
	if not (text.is_valid_int() or text.begins_with("-")):
		fs = 30 if not big else 40
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font("mono") if text.is_valid_int() or text.begins_with("-") else UIKit.font("bold"))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	var w := 360.0
	var h := float(fs) + 16.0
	var top := 64.0 + 52.0  # letterbox (48) + rise travel headroom
	var y := sp.y - h - k * (h + 4.0)
	if sp.y - h < top + float(k) * (h + 4.0) + 0.5:
		y = top + float(k) * (h + 4.0)  # anchored at the ceiling: grow the stack downward instead
	y = clampf(y, top, 500.0 - h)
	var x := clampf(sp.x - w * 0.5, 40.0, 1240.0 - w)
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(w * 0.5, h * 0.5)
	l.scale = Vector2(0.4, 0.4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("popup", true)
	_root.add_child(l)
	var t := _tw()
	t.tween_property(l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.08)
	t.tween_property(l, "position:y", l.position.y - 40, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.35)
	t.tween_callback(func():
		_pop_stack[side] = maxi(0, int(_pop_stack.get(side, 1)) - 1)
		l.queue_free())

func _sparks(side: String, col: Color, amount: int) -> void:
	var n: Node3D = _units[side].node
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 0.95
	p.direction = Vector3(0, 0.5, 0)
	p.spread = 70
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
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
	m.emission_energy_multiplier = 4.0
	mesh.material = m
	p.mesh = mesh
	p.position = n.position + Vector3(0, 1.2, 0)
	n.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _arrow(from_side: String, to_side: String, dur: float) -> void:
	var a: Node3D = _units[from_side].node
	var b: Node3D = _units[to_side].node
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.7
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col: Color = UIKit.DANGER if str(_units[from_side].team) == "enemy" else UIKit.ACCENT
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 5.0
	mi.material_override = m
	mi.rotation_degrees = Vector3(0, 0, 90)
	var p0 := a.position + Vector3(0, 1.35, 0)
	var p1 := b.position + Vector3(0, 1.25, 0)
	mi.position = p0
	a.get_parent().add_child(mi)
	var t := _tw()
	t.tween_property(mi, "position", p1, dur)
	t.tween_callback(mi.queue_free)

func _set_hp(side: String, v: int) -> void:
	var h: Dictionary = _hud[side]
	var pb: ProgressBar = h.hp
	if _skip:
		pb.value = v
	else:
		_tw().tween_property(pb, "value", float(v), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	h.txt.text = "%d / %d" % [v, int(h.max)]

# ---------------------------------------------------------------- choreography
func _run() -> void:
	await _wait(0.25)
	_cam_to(Vector3(0, 1.4, 4.7), Vector3(0, 1.05, 0), 36.0, 0.6)
	await _wait(0.45)
	for s in rec.get("strikes", []):
		if _skip:
			break
		await _strike(s)
		await _wait(0.25)
	await _wait(0.55)
	_finish()

func _strike(s: Dictionary) -> void:
	var a: String = s.from
	var d: String = "right" if a == "left" else "left"
	var au: Dictionary = _units[a]
	var du: Dictionary = _units[d]
	var an := "skill" if str(s.get("skill", "")) != "" else ("crit" if s.crit else "attack")
	var dir := 1.0 if a == "left" else -1.0
	var an_node: Node3D = au.node
	var dn_node: Node3D = du.node
	if str(s.get("skill", "")) != "":
		_popup(a, "「%s」" % str(s.skill), UIKit.ACCENT, false)
	# camera: over the attacker's shoulder toward the defender
	var melee := not bool(au.ranged)
	if melee:
		_cam_to(Vector3(-dir * 2.2, 1.5, 3.6), Vector3(dir * 0.5, 1.1, 0), 34.0, 0.45)
	else:
		_cam_to(Vector3(-dir * 0.8, 1.45, 4.3), Vector3(-dir * 0.3, 1.1, 0), 36.0, 0.45)
	if melee:
		_play(a, "advance")
		var t := _tw()
		t.tween_property(an_node, "position:x", dn_node.position.x - dir * 1.05, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await _wait(0.38)
	_play(a, an, 0.08)
	var imp: float = float(FPS_IMPACT.get(an, 0.46))
	if not melee:
		await _wait(imp * 0.8)
		_arrow(a, d, imp * 0.2 + 0.12)
		await _wait(imp * 0.2 + 0.12)
	else:
		if an == "crit":
			_cam_to(Vector3(dn_node.position.x - dir * 1.4, 1.45, 3.1), Vector3(dn_node.position.x - dir * 0.5, 1.1, 0), 30.0, imp * 0.9)
		await _wait(imp)
	if _skip:
		return
	# impact
	if s.hit:
		_play(d, "hit", 0.04)
		var crit := bool(s.crit)
		_shake = 1.0 if crit else 0.55
		_sparks(d, UIKit.EMBER if crit else Color(0.85, 0.95, 1.0), 48 if crit else 24)
		var ft := _tw()
		_flash.color = Color(1, 1, 1, 0.55 if crit else 0.18)
		ft.tween_property(_flash, "color:a", 0.0, 0.25)
		if crit:
			_popup(d, "暴击", UIKit.EMBER, false)
			Engine.time_scale = 0.35
			await get_tree().create_timer(0.09, true, false, true).timeout
			Engine.time_scale = 1.0
		_popup(d, "-%d" % int(s.dmg), UIKit.DANGER if str(du.team) != "enemy" else Color.WHITE, crit)
		var push := _tw()
		push.tween_property(dn_node, "position:x", dn_node.position.x + dir * 0.18, 0.08)
		push.tween_property(dn_node, "position:x", dn_node.position.x, 0.25)
		_set_hp(d, int(s.hp_after))
		if s.killed:
			await _wait(0.35)
			_play(d, "death", 0.06)
			_popup(d, "击破", UIKit.DANGER, false)
			_cam_to(Vector3(dn_node.position.x * 0.6, 1.3, 3.6), dn_node.position + Vector3(0, 0.6, 0), 34.0, 0.8)
			await _wait(1.25)
	else:
		_play(d, "dodge", 0.05)
		var dz := _tw()
		dz.tween_property(dn_node, "position:z", -0.55, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dz.tween_property(dn_node, "position:z", 0.0, 0.3).set_delay(0.18)
		_popup(d, "未中", UIKit.TEXT_DIM, false)
	await _wait(0.45)
	if not s.killed:
		_play(d, "idle", 0.2)
	if melee:
		_play(a, "advance")
		var back := _tw()
		back.tween_property(an_node, "position:x", float(au.home.x), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await _wait(0.34)
	_play(a, "idle", 0.2)
	_cam_to(Vector3(0, 1.4, 4.7), Vector3(0, 1.05, 0), 36.0, 0.4)
	await _wait(0.2)

var _done := false
func _finish() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = 1.0
	# final HP state (skip-safe)
	for s in rec.get("strikes", []):
		var d: String = "right" if s.from == "left" else "left"
		if _hud.has(d):
			_hud[d].hp.value = int(s.hp_after)
			_hud[d].txt.text = "%d / %d" % [int(s.hp_after), int(_hud[d].max)]
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		finished.emit()
		queue_free()
	)
