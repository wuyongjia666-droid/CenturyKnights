class_name CKBoardFigures
extends Node
## Board pieces v2: the SAME 3D models used by the combat cutscene (UnitModel),
## rendered once per unit in idle pose into a small transparent sprite and cached.
## Genome tint / job weapon / enemy theme all come from UnitModel.instantiate.

const SPRITE := Vector2i(192, 240)
static var _tex: Dictionary = {}
static var active: CKBoardFigures = null
var _pending: Dictionary = {}
signal figure_ready(key: String, tex: Texture2D)

## Any screen (e.g. the roster dossier) can host the renderer when no battle is up.
static func ensure(host: Node) -> CKBoardFigures:
	if active != null and is_instance_valid(active):
		return active
	var f := CKBoardFigures.new()
	f.name = "BoardFigures"
	host.add_child(f)
	return f

## Sets tr.texture now if cached, else as soon as the render lands.
func bind(tr: TextureRect, c, team: String = "player", tmpl: String = "") -> void:
	var t := figure(c, team, tmpl)
	if t != null:
		tr.texture = t
		return
	var k := key_of(c, team, tmpl)
	figure_ready.connect(func(kk: String, tex: Texture2D):
		if kk == k and is_instance_valid(tr):
			tr.texture = tex)

static func key_of(c, team: String, tmpl: String) -> String:
	var ap: Dictionary = c.appearance if c != null and c.appearance is Dictionary else {}
	return "%s|%s|%s|%s|%s|%s" % [str(c.id), team, tmpl, str(c.job_id), str(c.gender), str(ap.hash())]

static func clear() -> void:
	_tex.clear()

## Returns a cached sprite, or null while the render is in flight (caller draws a fallback).
func figure(c, team: String, tmpl: String = "") -> Texture2D:
	if c == null:
		return null
	var k := key_of(c, team, tmpl)
	if _tex.has(k):
		return _tex[k]
	if not _pending.has(k):
		_pending[k] = true
		_render.call_deferred(k, c, team, tmpl)
	return null

func _enter_tree() -> void:
	active = self

func _exit_tree() -> void:
	if active == self:
		active = null

func _render(k: String, c, team: String, tmpl: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = SPRITE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.9)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color(0.95, 0.96, 1.0)
	key.light_energy = 1.35
	w.add_child(key)
	var back := DirectionalLight3D.new()  # rim: back light outlines the silhouette
	back.rotation_degrees = Vector3(-20, 160, 0)
	back.light_color = Color(0.70, 1.0, 0.92) if team != "enemy" else Color(1.0, 0.62, 0.55)
	back.light_energy = 1.6
	w.add_child(back)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 40, 0)
	fill.light_color = Color(1.0, 0.92, 0.82)
	fill.light_energy = 0.45
	w.add_child(fill)
	var rim := OmniLight3D.new()
	rim.light_color = UIKit.OK if team != "enemy" else UIKit.DANGER
	rim.light_energy = 1.8
	rim.omni_range = 4.0
	rim.position = Vector3(-1.6, 2.0, -1.4)
	w.add_child(rim)
	var n := UnitModel.instantiate(c, team, tmpl)
	if n == null:
		vp.queue_free()
		return
	w.add_child(n)
	n.rotation_degrees = Vector3(0, -25 if team != "enemy" else 25, 0)
	var ap := UnitModel.find_anim(n)
	if ap and ap.has_animation("idle"):
		ap.play("idle")
		ap.seek(0.0, true)
		ap.pause()
	_chibi(n)
	var cam := Camera3D.new()
	cam.fov = 25.0
	cam.position = Vector3(0, 2.2, 4.6)
	w.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	var used := img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return
	_vivid(img)
	_outline(img)
	_tex[k] = ImageTexture.create_from_image(img)
	_pending.erase(k)
	figure_ready.emit(k, _tex[k])
	var p := get_parent()
	if p and p.has_method("_board_figures_ready"):
		p._board_figures_ready()


## Lift saturation / value so the figures pop on the dark board (cutscene models are muted).
static func _vivid(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a < 0.02:
				continue
			var s := clampf(p.s * 1.7 + 0.08, 0.0, 1.0)
			var v := clampf(p.v * 1.18 + 0.04, 0.0, 1.0)
			img.set_pixel(x, y, Color.from_hsv(p.h, s, v, p.a))


## Board readability: slightly bigger head (bone scale) like a tabletop mini.
static func _chibi(n: Node) -> void:
	var sk := UnitModel._find_skeleton(n)
	if sk == null:
		return
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i).to_lower()
		if bn == "head" or bn.ends_with(".head") or bn.ends_with("_head") or bn == "neck.001":
			sk.set_bone_pose_scale(i, Vector3.ONE * 1.22)
		elif bn.contains("hand") and not bn.contains("handle"):
			sk.set_bone_pose_scale(i, Vector3.ONE * 1.15)

## Thin dark outline around the silhouette so figures read on the dark board.
static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var ink := Color(0.03, 0.03, 0.05, 0.92)
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.3:
				continue
			var hit := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0.5:
					hit = true
					break
			if hit:
				img.set_pixel(x, y, ink)
