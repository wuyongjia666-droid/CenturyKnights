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
var _nodes: Dictionary = {}   # char id -> {node, anim, face, pos, dead_t, cur}

static func enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return bool(GameState.settings.get("board_units_3d", true))

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
			var ap := UnitModel.find_anim(n)
			st = {"node": n, "anim": ap, "face": 1.0 if str(u.team) != "enemy" else -1.0, "dead_t": -1.0, "cur": "", "lock_t": 0.0}
			_nodes[id] = st
			_play(st, "idle")
		var n2: Node3D = st.node
		var target := _to_world(e.px)
		var cell_px: float = e.cell_px
		var s := FIG_CELLS * cell_px / PX / (MODEL_H * cos(deg_to_rad(PITCH)))
		n2.scale = Vector3.ONE * s
		if u.char.hp <= 0:
			if float(st.dead_t) < 0.0:
				st.dead_t = 0.0
				_play(st, "death", true)
			st.dead_t = float(st.dead_t) + delta
			n2.visible = float(st.dead_t) < 1.4
			continue
		n2.visible = bool(e.visible)
		# P1: glide toward the cell; P2 replaces this with step-by-step path walking
		var d := target - n2.position
		if d.length() > 0.01 and n2.position != Vector3.ZERO:
			if absf(d.x) > 0.02:
				st.face = signf(d.x)
			var step := minf(d.length(), delta * 3.2 * cell_px / PX)
			n2.position += d.normalized() * step
			if str(st.cur) != "advance" and float(st.lock_t) <= 0.0:
				_play(st, "advance")
		else:
			n2.position = target
			if str(st.cur) == "advance":
				_play(st, "idle")
		st.lock_t = maxf(0.0, float(st.lock_t) - delta)
		if float(st.lock_t) <= 0.0 and str(st.cur) in ["attack", "hit", "skill", "crit", "dodge"]:
			_play(st, "idle")
		n2.rotation_degrees.y = 62.0 * float(st.face)
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

## Combat hooks (battle controller): face the target and play the clip.
func act(u, anim: String, toward_px: Vector2 = Vector2.INF, from_px: Vector2 = Vector2.INF) -> void:
	var st: Dictionary = _nodes.get(str(u.char.id), {})
	if st.is_empty():
		return
	if toward_px != Vector2.INF and from_px != Vector2.INF and absf(toward_px.x - from_px.x) > 1.0:
		st.face = signf(toward_px.x - from_px.x)
	_play(st, anim)
