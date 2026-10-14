class_name CKUnitLayer3D
extends SubViewportContainer
## Route C (docs: /workspace/pawn_upgrade/plan.md): live 3D unit layer over the 2D board.
## The 2D board keeps terrain, overlays and input; this transparent layer only draws the
## units — the SAME UnitModel rigs as the combat cutscene, with real-time animation.
## Orthographic camera pitched PITCH°; ground Z is stretched by 1/sin(pitch) so a 3D foot
## position lands exactly on its 2D cell centre. 2D token fallback: CI / headless / setting off.

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
var path_fn: Callable         # (u, from: Vector2i, to: Vector2i) -> Array[Vector2i]
var cell_px_fn: Callable      # (cell) -> container-local feet point
var _sparks: Array = []

static func enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	# mobile: off by default until the P4 perf budget is verified (mobile-lag priority)
	return bool(GameState.settings.get("board_units_3d", not DeviceProfile.is_mobile()))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X if DeviceProfile.is_mobile() else Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.86)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.35
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.rotation_degrees = Vector3(-PITCH, 0, 0)
	_cam.near = 0.05
	_cam.far = 200.0
	_world.add_child(_cam)
	_cam.current = true

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
	_update_cam()
	var seen := {}
	for e in entries:
		var u = e.u
		var id := str(u.char.id)
		seen[id] = true
		var st: Dictionary = _nodes.get(id, {})
		if st.is_empty():
			var n := UnitModel.instantiate(u.char, str(u.team), str(u.get("template", "")))
			if n == null:
				continue
			_world.add_child(n)
			CKUnitSilhouette.apply(n, u.char, str(u.team))
			n.set_meta("ck_base_scale", n.scale)
			var ap := UnitModel.find_anim(n)
			var f0 := 1.0 if str(u.team) != "enemy" else -1.0
			st = {"node": n, "anim": ap, "face": f0, "yaw": 62.0 * f0, "dead_t": -1.0, "cur": "", "lock_t": 0.0, "pending": []}
			n.rotation_degrees.y = 62.0 * f0
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
			continue
		n2.visible = bool(e.visible)
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
		var want: float = float(st.get("yaw", 62.0 * float(st.face)))
		n2.rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(n2.rotation_degrees.y), deg_to_rad(want), minf(1.0, delta * 14.0)))
		_tick_pending(st, delta)
		n2.set_meta("ck_dim", bool(u.done))
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
