class_name CKUnitLayer3D
extends Control
## Route C live 3D unit layer over the 2D board (pawn-redesign-opus §3.8 P3).
## The 2D board keeps terrain, overlays and input; this transparent layer only draws units.
## Orthographic camera pitched PITCH°; ground Z stretched by 1/sin(pitch) so a 3D foot
## lands on its 2D cell centre. 2D token fallback: CI / headless / setting off / over max_units.
## P3: idle SubViewport refresh 12–15Hz; walk/attack/FX full frame; mobile halo blits with refresh.

const PITCH := 38.0
const PX := 100.0          # screen px per world unit
const FIG_CELLS := 1.30    # figure height ≈ 1.3 cells on screen
const MODEL_H := 1.85      # rig height in metres
var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _nodes: Dictionary = {}   # char id -> {node, anim, face, yaw, cell, path, dead_t, cur}
const WALK_CELLS_S := 5.0     # walk speed (cells / s)
const HIT_STOP := 0.075       # freeze both rigs on the impact frame
const FLASH_S := 0.08  # P2 design 80ms; runtime floors to ≥2 frames so low FPS still sees it
var path_fn: Callable         # (u, from: Vector2i, to: Vector2i) -> Array[Vector2i]
var cell_px_fn: Callable      # (cell) -> container-local feet point
var _sparks: Array = []

## Absolute ceiling (desktop). Prefer max_units() — mobile is lower (§3.8 P3).
const MAX_UNITS := 32
const IDLE_HZ := 14.0  # mid of 12–15Hz idle refresh (aligns with battle ~12Hz pulse)

var _idle_accum := 0.0
var _display: TextureRect = null  # shows VP (or halo-blit) texture
var _blit_vp: SubViewport = null  # mobile: 2D pass applying board_halo at refresh rate
var _halo_mat: ShaderMaterial = null

## Default: desktop + mid/high Android on; low-end off (baked stand-ins). Settings override.
static func default_on() -> bool:
	return DeviceProfile.board_3d_default()

static func max_units() -> int:
	return DeviceProfile.max_board_units_3d()

static func enabled(unit_count: int = 0) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if unit_count > max_units():
		return false
	# Respect user toggle when set; otherwise device-tier default (low-end → stand-ins).
	return bool(GameState.settings.get("board_units_3d", default_on()))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.handle_input_locally = false
	# Transparent SubViewport + MSAA yields mid-alpha coverage samples → ghost silhouettes
	# when composited over the 2D board (Godot MSAA/transparent-bg). Keep MSAA off here.
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	if DeviceProfile.is_mobile():
		_vp.scaling_3d_scale = 0.8
	else:
		# #310 P1: 2× supersample (bilinear SSAA) instead of MSAA — anti-aliases
		# figure edges without MSAA's mid-alpha ghosting on the transparent layer.
		_vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_vp.scaling_3d_scale = 2.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.86)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	# Cool white key (style lock); figure shader also mirrors key with facing.
	sun.light_color = Color(0.92, 0.95, 1.0)
	sun.light_energy = 0.85
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.rotation_degrees = Vector3(-PITCH, 0, 0)
	_cam.near = 0.05
	_cam.far = 200.0
	_world.add_child(_cam)
	_cam.current = true
	_setup_display_and_halo()
	resized.connect(_sync_vp_size)
	_sync_vp_size()



func _halo_material() -> ShaderMaterial:
	var halo := ShaderMaterial.new()
	halo.shader = load("res://shaders/board_halo.gdshader") as Shader
	halo.set_shader_parameter("px", 1.0)
	halo.set_shader_parameter("halo_a", 0.95)
	return halo

func _setup_display_and_halo() -> void:
	## 1px dark silhouette (board_halo default) (board_halo.gdshader).
	## Desktop: TextureRect + halo material (composites every frame; cheap on PC).
	## Mobile P3: 3D VP → blit SubViewport (halo material, updates with idle/busy refresh)
	## → display TextureRect with no material. Halo 9-tap only runs when the blit updates.
	_halo_mat = _halo_material()
	_display = TextureRect.new()
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_display)
	if DeviceProfile.prefer_halo_in_viewport():
		_blit_vp = SubViewport.new()
		_blit_vp.transparent_bg = true
		_blit_vp.handle_input_locally = false
		_blit_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_blit_vp)
		var src := TextureRect.new()
		src.mouse_filter = Control.MOUSE_FILTER_IGNORE
		src.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		src.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		src.stretch_mode = TextureRect.STRETCH_SCALE
		src.texture = _vp.get_texture()
		src.material = _halo_mat
		_blit_vp.add_child(src)
		_display.texture = _blit_vp.get_texture()
		_display.material = null
	else:
		_display.texture = _vp.get_texture()
		_display.material = _halo_mat

func _sync_vp_size() -> void:
	var px := Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	if _vp:
		_vp.size = px
	if _blit_vp:
		_blit_vp.size = px

func _layer_busy() -> bool:
	for st in _nodes.values():
		if not (st.get("path", []) as Array).is_empty():
			return true
		if float(st.get("lock_t", 0.0)) > 0.0:
			return true
		if float(st.get("flash_t", 0.0)) > 0.0:  # P2 hit flash is live FX → full frame
			return true
		var cur := str(st.get("cur", ""))
		if cur in ["advance", "attack", "hit", "skill", "crit", "dodge", "death"]:
			return true
		if not (st.get("pending", []) as Array).is_empty():
			return true
	return false

func _set_vp_mode(mode: int) -> void:
	_vp.render_target_update_mode = mode
	if _blit_vp:
		_blit_vp.render_target_update_mode = mode

func _refresh_update_mode(delta: float) -> void:
	## Idle: 12–15Hz SubViewport refresh. Walk / attack / FX: full frame.
	## When halo blits through _blit_vp, it shares this cadence (P3 mobile fill-rate).
	if _layer_busy():
		_idle_accum = 0.0
		_set_vp_mode(SubViewport.UPDATE_ALWAYS)
		return
	_idle_accum += delta
	if _idle_accum >= (1.0 / IDLE_HZ):
		_idle_accum = 0.0
		_set_vp_mode(SubViewport.UPDATE_ONCE)
	else:
		_set_vp_mode(SubViewport.UPDATE_DISABLED)

## P1 formal kit uses board_figure.gdshader (no board_compact / farm flatten).
func _solidify_board(_n: Node) -> void:
	pass

## Screen px (container-local) → world point on the ground plane.
func _to_world(p: Vector2) -> Vector3:
	var sz := size
	var sp := sin(deg_to_rad(PITCH))
	return Vector3((p.x - sz.x * 0.5) / PX, 0.0, (p.y - sz.y * 0.5) / PX / sp)

func _update_cam() -> void:
	_cam.size = size.y / PX
	var back := Vector3(0, sin(deg_to_rad(PITCH)), cos(deg_to_rad(PITCH))) * 50.0
	_cam.position = back

func has_unit(c) -> bool:
	return _nodes.has(str(c.id))

## Per frame: entries = [{u, px (container-local feet point), cell_px, visible}]
func sync(entries: Array, delta: float) -> void:
	_refresh_update_mode(delta)
	_update_cam()
	var seen := {}
	for e in entries:
		var u = e.u
		var id := str(u.char.id)
		seen[id] = true
		var st: Dictionary = _nodes.get(id, {})
		if st.is_empty():
			var n := CKBoardFigure.build(u.char, str(u.team), str(u.get("template", "")))
			if n == null:
				continue
			_world.add_child(n)
			_board_lift(n, str(u.team) != "enemy")
			# formal kit: no farm solidify
			n.set_meta("ck_base_scale", Vector3.ONE)
			var ap := CKBoardFigure.find_anim(n)
			var f0 := 1.0 if str(u.team) != "enemy" else -1.0
			# Idle yaw ±35° toward camera (design §3.2); was 62° on cutscene rigs.
			st = {"node": n, "anim": ap, "face": f0, "yaw": 35.0 * f0, "dead_t": -1.0, "cur": "", "lock_t": 0.0, "pending": []}
			n.rotation_degrees.y = 35.0 * f0
			_nodes[id] = st
			_play(st, "idle")
		var n2: Node3D = st.node
		var target := _to_world(e.px)
		var cell_px: float = e.cell_px
		var s := FIG_CELLS * cell_px / PX / (MODEL_H * cos(deg_to_rad(PITCH)))
		n2.scale = (n2.get_meta("ck_base_scale", Vector3.ONE) as Vector3) * s
		if u.char.hp <= 0:
			if float(st.dead_t) < 0.0:
				st.dead_t = 0.0
				_play(st, "death", true)
			st.dead_t = float(st.dead_t) + delta
			n2.visible = float(st.dead_t) < 1.4
			if not n2.visible and st.anim:
				(st.anim as AnimationPlayer).active = false
			continue
		n2.visible = bool(e.visible)
		var apv: AnimationPlayer = st.anim
		if apv:  # P4: rigs hidden by fog do not tick
			apv.active = n2.visible
		# P2: walk the real path cell by cell (host BFS), turning on every corner
		var cell: Vector2i = e.cell
		if not st.has("cell"):
			st.cell = cell
			n2.position = target
		elif st.cell != cell:
			var pts: Array = path_fn.call(u, st.cell, cell) if path_fn.is_valid() else [cell]
			var q: Array = []
			for pc in pts:
				q.append(_to_world(cell_px_fn.call(pc)))
			if q.is_empty() or (q.back() as Vector3).distance_to(target) > 0.01:
				q.append(target)
			st.path = q
			st.cell = cell
		var path: Array = st.get("path", [])
		if not path.is_empty():
			var wp: Vector3 = path[0]
			var d := wp - n2.position
			var speed := delta * WALK_CELLS_S * cell_px / PX
			if d.length() <= speed:
				n2.position = wp
				path.pop_front()
			else:
				n2.position += d.normalized() * speed
				st.yaw = rad_to_deg(atan2(d.x, d.z))
			if str(st.cur) != "advance" and float(st.lock_t) <= 0.0:
				_play(st, "advance")
		else:
			if n2.position.distance_to(target) > 0.01 and n2.position.distance_to(target) < 0.5:
				n2.position = target
			if str(st.cur) == "advance":
				_play(st, "idle")
		st.lock_t = maxf(0.0, float(st.lock_t) - delta)
		if float(st.lock_t) <= 0.0 and str(st.cur) in ["attack", "hit", "skill", "crit", "dodge"]:
			_play(st, "idle")
		var want: float = float(st.get("yaw", 35.0 * float(st.face)))
		n2.rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(n2.rotation_degrees.y), deg_to_rad(want), minf(1.0, delta * 14.0)))
		_tick_pending(st, delta)
		var dimmed := bool(u.done)
		n2.set_meta("ck_dim", dimmed)
		var flash_left := float(st.get("flash_t", 0.0))
		if flash_left > 0.0:
			flash_left = maxf(0.0, flash_left - delta)
			st.flash_t = flash_left
		var flash_amt := (flash_left / FLASH_S) if FLASH_S > 0.0 else 0.0
		# Only push shader params when dim/flash bucket changes (avoid per-frame mat walk).
		var flash_bucket := int(ceil(flash_amt * 8.0))
		var prev_d = st.get("fb_dim", null)
		var prev_b = st.get("fb_flash_b", null)
		if prev_d != dimmed or prev_b != flash_bucket:
			st.fb_dim = dimmed
			st.fb_flash_b = flash_bucket
			CKBoardFigure.apply_feedback(n2, dimmed, flash_amt)
	for id in _nodes.keys():
		if not seen.has(id):
			(_nodes[id].node as Node3D).queue_free()
			_nodes.erase(id)

func _play(st: Dictionary, anim: String, once: bool = false) -> void:
	var ap: AnimationPlayer = st.anim
	st.cur = anim
	if ap == null or not ap.has_animation(anim):
		return
	ap.play(anim, 0.12)
	if anim in ["attack", "hit", "skill", "crit", "dodge"]:
		st.lock_t = ap.get_animation(anim).length
	# P2 §3.9: white flash 80ms on hit / crit receive
	if anim in ["hit", "crit"]:
		var fps := maxf(1.0, float(Engine.get_frames_per_second()))
		st.flash_t = maxf(FLASH_S, 2.0 / fps)
		st.fb_flash_b = -1  # force feedback refresh
		if st.get("node") != null:
			CKBoardFigure.apply_feedback(st.node, bool((st.node as Node).get_meta("ck_dim", false)), 1.0)

## Seconds from swing start to the impact frame (UnitModel.IMPACT), for syncing 2D fx.
func impact_delay(u, anim: String = "attack") -> float:
	var st: Dictionary = _nodes.get(str(u.char.id), {})
	var ap: AnimationPlayer = st.get("anim", null)
	if ap == null or not ap.has_animation(anim):
		return 0.0
	return ap.get_animation(anim).length * float(UnitModel.IMPACT.get(anim, 0.45))

## Combat hooks (battle controller): face the target and play the clip.
## delay > 0 queues the clip (defender reacts on the attacker's impact frame, with hit-stop).
func act(u, anim: String, toward_px: Vector2 = Vector2.INF, from_px: Vector2 = Vector2.INF, delay: float = 0.0) -> void:
	var st: Dictionary = _nodes.get(str(u.char.id), {})
	if st.is_empty():
		return
	if toward_px != Vector2.INF and from_px != Vector2.INF and toward_px.distance_to(from_px) > 1.0:
		var w := _to_world(toward_px) - _to_world(from_px)
		st.yaw = rad_to_deg(atan2(w.x, w.z))
	if delay > 0.0:
		(st.pending as Array).append({"t": delay, "anim": anim})
		return
	_play(st, anim)

func _tick_pending(st: Dictionary, delta: float) -> void:
	var keep: Array = []
	for p in st.pending:
		p.t = float(p.t) - delta
		if float(p.t) <= 0.0:
			_play(st, str(p.anim))
			if str(p.anim) in ["hit", "crit"]:
				_impact(st)
		else:
			keep.append(p)
	st.pending = keep

## Impact: brief hit-stop on every rig + a burst of sparks at the defender's chest.
func _impact(st: Dictionary) -> void:
	for o in _nodes.values():
		var ap: AnimationPlayer = o.anim
		if ap:
			ap.speed_scale = 0.0
	get_tree().create_timer(HIT_STOP).timeout.connect(func():
		for o in _nodes.values():
			var ap2: AnimationPlayer = o.anim
			if ap2:
				ap2.speed_scale = 1.0)
	var n: Node3D = st.node
	var chest := n.position + Vector3(0, MODEL_H * 0.55 * n.scale.y, 0)
	for i in 10:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.16) * n.scale.y * 2.0
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.85 - 0.04 * i, 0.45, 1.0)
		q.material_override = m
		q.position = chest
		_world.add_child(q)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-0.6, 0.6)).normalized()
		var tw := q.create_tween()
		tw.set_parallel(true)
		tw.tween_property(q, "position", chest + dir * 0.9 * n.scale.y * 2.0, 0.28).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.28)
		tw.chain().tween_callback(q.queue_free)


## #310 P1b: top-down board camera sees less of the key light than the cards do, and the
## battlefield is dark — lift exposure and rim a bit (allies more), clamp so coats don't bleach.
static func _board_lift(n: Node, ally: bool) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var mats: Array = []
		if gi.material_override is ShaderMaterial:
			mats.append(gi.material_override)
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mi := gi as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				var m = mi.get_surface_override_material(si)
				if m is ShaderMaterial:
					mats.append(m)
		for m2 in mats:
			var sm := m2 as ShaderMaterial
			# bright coats (hunter's ice/fur) bleach on the dark board — scale exposure by coat luma
			var pal_arr = sm.get_shader_parameter("palette")
			var coat_l := 0.3
			if pal_arr is Array and (pal_arr as Array).size() > 3:
				var cc: Color = pal_arr[3]
				coat_l = cc.get_luminance()
			var ex := clampf(1.15 - maxf(0.0, coat_l - 0.32) * 1.2, 0.92, 1.15)
			sm.set_shader_parameter("exposure", ex if ally else 1.10)
			# top-down camera puts most of the figure in the wrap shadow: lift shadow floor
			sm.set_shader_parameter("shadow_mul", Vector3(0.66, 0.66, 0.68) if ally else Vector3(0.55, 0.57, 0.64))
			var r = sm.get_shader_parameter("rim_amt")
			sm.set_shader_parameter("rim_amt", minf(0.9, (float(r) if r != null else 0.55) + (0.15 if ally else 0.05)))
	for ch in n.get_children():
		_board_lift(ch, ally)
