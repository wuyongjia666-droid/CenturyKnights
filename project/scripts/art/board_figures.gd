class_name CKBoardFigures
extends Node
## Board pieces v2: the SAME 3D models used by the combat cutscene (UnitModel),
## rendered once per unit in idle pose into a small transparent sprite and cached.
## Genome tint / job weapon / enemy theme all come from UnitModel.instantiate.

const SPRITE := Vector2i(192, 240)
static var _tex: Dictionary = {}
static var active: CKBoardFigures = null
var _pending: Dictionary = {}

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
	env.ambient_light_energy = 0.30
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color(0.95, 0.96, 1.0)
	key.light_energy = 1.0
	w.add_child(key)
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
	_tex[k] = ImageTexture.create_from_image(img)
	_pending.erase(k)
	var p := get_parent()
	if p and p.has_method("_board_figures_ready"):
		p._board_figures_ready()
