class_name CKBoardFigures
extends Node
## Board pieces v2: the SAME 3D models used by the combat cutscene (UnitModel),
## pre-rendered into small transparent frame strips per unit and cached.
## Strips (facing right; draw flipped for left): idle / advance (walk) / attack / hit.
## Genome tint / job weapon / enemy theme all come from UnitModel.instantiate.
## Headless (CI) renders nothing → callers fall back to the procedural token.

const SPRITE := Vector2i(160, 200)
## Frames per clip — kept small for mobile memory (≈19 × 160×200 RGBA ≈ 2.4 MB / unit).
const CLIPS := {"idle": 4, "advance": 6, "attack": 6, "hit": 3}
const FPS := {"idle": 5.0, "advance": 12.0, "attack": 14.0, "hit": 12.0}
static var _tex: Dictionary = {}      # key -> idle frame 0 (first, fast)
static var _strips: Dictionary = {}   # key -> {clip: [Texture2D]}
static var active: CKBoardFigures = null
var _pending: Dictionary = {}
signal figure_ready(key: String, tex: Texture2D)

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
	_strips.clear()

## Idle frame 0, or null while the render is in flight.
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

## Frame of `clip` at time t (seconds). Loops unless once; falls back to idle frame 0.
func frame(c, team: String, tmpl: String, clip: String, t: float, once: bool = false) -> Texture2D:
	var base := figure(c, team, tmpl)
	if base == null:
		return null
	var st: Dictionary = _strips.get(key_of(c, team, tmpl), {})
	var fr: Array = st.get(clip, [])
	if fr.is_empty():
		fr = st.get("idle", [])
		clip = "idle"
	if fr.is_empty():
		return base
	var i := int(t * float(FPS.get(clip, 8.0)))
	i = mini(i, fr.size() - 1) if once else i % fr.size()
	return fr[i]

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
	env.ambient_light_energy = 0.32
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color(0.95, 0.96, 1.0)
	key.light_energy = 1.05
	w.add_child(key)
	var back := DirectionalLight3D.new()  # rim: back light outlines the silhouette
	back.rotation_degrees = Vector3(-20, 160, 0)
	back.light_color = Color(0.70, 1.0, 0.92) if team != "enemy" else Color(1.0, 0.62, 0.55)
	back.light_energy = 1.2
	w.add_child(back)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 40, 0)
	fill.light_color = Color(1.0, 0.92, 0.82)
	fill.light_energy = 0.45
	w.add_child(fill)
	var n := UnitModel.instantiate(c, team, tmpl)
	if n == null:
		vp.queue_free()
		return
	w.add_child(n)
	n.rotation_degrees = Vector3(0, 50, 0)  # 3/4 view, facing screen-right
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0, 2.2, 4.6)
	w.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	cam.current = true
	var ap := UnitModel.find_anim(n)
	var strips := {}
	var first := true
	for clip in ["idle", "advance", "attack", "hit"]:
		if ap == null or not ap.has_animation(clip):
			if clip == "idle":
				_chibi(n)
				var img0 := await _grab(vp)
				if img0 != null:
					strips["idle"] = [ImageTexture.create_from_image(img0)]
			continue
		var anim := ap.get_animation(clip)
		var cnt: int = CLIPS[clip]
		var frames: Array = []
		ap.play(clip)
		for f in cnt:
			var span := anim.length * (0.92 if clip == "idle" else 0.98)
			ap.seek(span * float(f) / float(maxi(1, cnt - (0 if clip == "idle" else 1))), true)
			ap.pause()
			n.position = Vector3.ZERO  # strip root motion: the board moves the piece
			_chibi(n)
			var img := await _grab(vp)
			if img == null:
				continue
			var tex := ImageTexture.create_from_image(img)
			frames.append(tex)
			if first:
				first = false
				_tex[k] = tex
				_strips[k] = strips
				figure_ready.emit(k, tex)
				var p := get_parent()
				if p and p.has_method("_board_figures_ready"):
					p._board_figures_ready()
		strips[clip] = frames
	if first and strips.has("idle") and not strips["idle"].is_empty():
		_tex[k] = strips["idle"][0]
		figure_ready.emit(k, _tex[k])
	_strips[k] = strips
	_pending.erase(k)
	vp.queue_free()

func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	if img.get_used_rect().size.x < 4:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(0.98, 1.10, 1.6)  # richer colour so figures pop on the dark board
	return _outline(img)

## Board readability: slightly bigger head/hands (bone scale) like a tabletop mini.
static func _chibi(n: Node) -> void:
	var sk := UnitModel._find_skeleton(n)
	if sk == null:
		return
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i).to_lower()
		if bn == "head" or bn.ends_with(".head") or bn.ends_with("_head"):
			sk.set_bone_pose_scale(i, Vector3.ONE * 1.22)
		elif bn.contains("hand") and not bn.contains("handle"):
			sk.set_bone_pose_scale(i, Vector3.ONE * 1.15)

## Thin dark outline (native blits, cheap): silhouette stamped at 8 offsets under the figure.
static func _outline(img: Image) -> Image:
	var sz := img.get_size()
	var ink := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	ink.fill(Color(0.03, 0.03, 0.05, 0.92))
	var out := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var r := Rect2i(Vector2i.ZERO, sz)
	for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		out.blend_rect_mask(ink, img, r, d)
	out.blend_rect(img, r, Vector2i.ZERO)
	return out
