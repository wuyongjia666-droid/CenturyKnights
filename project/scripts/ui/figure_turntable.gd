class_name CKFigureTurntable
extends SubViewportContainer
## P3: dossier turntable — the unit's live 3D board figure (same rig, P0 dye, P3 silhouette
## parts), idling and slowly turning; drag to spin. Falls back to the 2D token when headless.

var character: CKCharacter
var team := "player"
var _pivot: Node3D
var _drag := false
var _spin := 0.0

static func make(c: CKCharacter, sz: Vector2) -> Control:
	if not CKUnitLayer3D.enabled():  # same switch as the board (off on mobile until P4)
		var tr := TextureRect.new()
		tr.texture = UnitArt.token(c, "player", 64, false)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = sz
		tr.size = sz
		return tr
	var t := CKFigureTurntable.new()
	t.character = c
	t.custom_minimum_size = sz
	t.size = sz
	return t

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = tr("figure_turntable_tip")
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.86)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.3
	w.add_child(sun)
	_pivot = Node3D.new()
	w.add_child(_pivot)
	var n := UnitModel.instantiate(character, team, "")
	if n:
		_pivot.add_child(n)
		CKUnitSilhouette.apply(n, character, team)
		var ap := UnitModel.find_anim(n)
		if ap and ap.has_animation("idle"):
			ap.play("idle")
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.02
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.36, 0.90, 0.78, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dm
	w.add_child(disc)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.25
	cam.position = Vector3(0, 1.45, 4.0)
	w.add_child(cam)
	cam.look_at(Vector3(0, 0.98, 0), Vector3.UP)
	cam.current = true
	_pivot.rotation_degrees.y = 25.0

func _process(delta: float) -> void:
	if _pivot and not _drag:
		_pivot.rotation_degrees.y += delta * 24.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (e as InputEventMouseButton).pressed
		accept_event()
	elif e is InputEventScreenTouch:
		_drag = (e as InputEventScreenTouch).pressed
		accept_event()
	elif (e is InputEventMouseMotion and _drag) or e is InputEventScreenDrag:
		var dx: float = e.relative.x
		_pivot.rotation_degrees.y += dx * 0.8
		accept_event()
