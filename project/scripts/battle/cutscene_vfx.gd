class_name CutsceneVfx
extends RefCounted
## Procedural projectiles and the ten royal skill signatures.
## Ember stays on kiln sparks only. Fills stay cool.

const FROST := Color8(110, 212, 255)
const FROST_WHITE := Color8(244, 247, 251)
const MINT := Color8(94, 224, 181)
const SLATE := Color8(154, 166, 184)
const CORAL := Color8(255, 122, 112)
const INK := Color8(22, 27, 36)
const EMBER := Color8(255, 138, 61)

## Ten royal skills. Ember is only the kiln spark accent; every fill stays cool.
const SIG := {
	"chart_rally": {"tint": FROST, "shape": "banner", "sparks": false},
	"eclipse_gaze": {"tint": SLATE, "shape": "eclipse", "sparks": false},
	"jade_clarity": {"tint": MINT, "shape": "arc", "sparks": false},
	"lamp_feint": {"tint": FROST, "shape": "lamp", "sparks": false},
	"bell_hush": {"tint": FROST_WHITE, "shape": "bell", "sparks": false},
	"kiln_reforge": {"tint": FROST, "shape": "kiln", "sparks": true},
	"tide_edict": {"tint": MINT, "shape": "tide", "sparks": false},
	"gorge_breaker": {"tint": CORAL, "shape": "slash", "sparks": false},
	"dipper_fix": {"tint": FROST_WHITE, "shape": "dipper", "sparks": false},
	"firefly_ferry": {"tint": MINT, "shape": "ferry", "sparks": false},
}

static func royal_ids() -> Array:
	return SIG.keys()

static func signature_for(skill_id: String, skill_name: String = "") -> Dictionary:
	if SIG.has(skill_id):
		var hit: Dictionary = (SIG[skill_id] as Dictionary).duplicate()
		hit["id"] = skill_id
		return hit
	var table := CutsceneTimeline.royal_table()
	for id in table.keys():
		var row: Dictionary = table[id]
		if str(id) == skill_name or str(row.get("name", "")) == skill_name:
			if not SIG.has(str(id)):
				return {}
			var named: Dictionary = (SIG[str(id)] as Dictionary).duplicate()
			named["id"] = str(id)
			return named
	return {}

static func spawn_projectile(parent: Node, from: Vector3, to: Vector3, kind: String, color: Color, particle_scale: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.set_meta("vfx_kind", kind)
	root.position = from
	var dir := to - from
	if dir.length() > 0.001:
		root.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	if kind == "bolt":
		_build_bolt(root, color)
	else:
		_build_arrow(root, color)
	if particle_scale > 0.01:
		_cpu_trail(root, color, particle_scale)
	return root

static func spawn_signature(parent: Node, at: Vector3, skill_id: String, skill_name: String, particle_scale: float) -> Node3D:
	var spec := signature_for(skill_id, skill_name)
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.set_meta("vfx_kind", "signature")
	root.set_meta("vfx_id", str(spec.get("id", "")))
	if spec.is_empty():
		return root
	var tint: Color = spec.get("tint", FROST)
	match str(spec.get("shape", "")):
		"banner":
			_add_box(root, Vector3(0.04, 0.7, 0.02), tint, Vector3(-0.22, 0, 0))
			_add_box(root, Vector3(0.04, 0.7, 0.02), tint, Vector3(0.22, 0, 0))
			_add_box(root, Vector3(0.46, 0.28, 0.02), tint, Vector3(0, 0.12, 0))
		"eclipse":
			_add_sphere(root, 0.22, INK, Vector3.ZERO)
			_add_torus(root, 0.34, 0.03, tint, Vector3.ZERO)
		"arc":
			for i in 5:
				var ang := deg_to_rad(-70.0 + float(i) * 35.0)
				_add_sphere(root, 0.07, tint, Vector3(sin(ang) * 0.42, cos(ang) * 0.28, 0))
		"lamp":
			_add_box(root, Vector3(0.36, 0.04, 0.04), tint, Vector3(0, 0.22, 0))
			_add_box(root, Vector3(0.36, 0.04, 0.04), tint, Vector3(0, -0.22, 0))
			_add_box(root, Vector3(0.04, 0.44, 0.04), tint, Vector3(-0.16, 0, 0))
			_add_box(root, Vector3(0.04, 0.44, 0.04), tint, Vector3(0.16, 0, 0))
			_add_sphere(root, 0.08, FROST_WHITE, Vector3.ZERO)
		"bell":
			_add_torus(root, 0.28, 0.025, tint, Vector3(0, 0.2, 0))
			for i in 3:
				_add_box(root, Vector3(0.03, 0.42, 0.03), tint, Vector3(-0.16 + float(i) * 0.16, -0.08, 0))
		"kiln":
			_add_box(root, Vector3(0.5, 0.04, 0.04), tint, Vector3(0, 0.12, 0), Vector3(0, 0, 18))
			_add_box(root, Vector3(0.42, 0.04, 0.04), tint, Vector3(0.04, -0.08, 0), Vector3(0, 0, -24))
			_add_box(root, Vector3(0.28, 0.04, 0.04), tint, Vector3(-0.08, 0.0, 0), Vector3(0, 0, 70))
			if particle_scale > 0.01 and bool(spec.get("sparks", false)):
				_ember_sparks(root, particle_scale)
		"tide":
			for i in 3:
				_add_box(root, Vector3(0.7, 0.035, 0.03), tint, Vector3(0, 0.16 - float(i) * 0.14, float(i) * 0.05))
		"slash":
			_add_box(root, Vector3(0.86, 0.05, 0.03), tint, Vector3.ZERO, Vector3(0, 0, -8))
		"dipper":
			var pts := [
				Vector3(-0.42, 0.28, 0), Vector3(-0.24, 0.16, 0.02), Vector3(-0.06, 0.22, 0),
				Vector3(0.1, 0.06, 0), Vector3(0.24, -0.06, 0.02), Vector3(0.4, 0.04, 0),
				Vector3(0.56, 0.18, 0),
			]
			for pnt in pts:
				_add_sphere(root, 0.045, tint, pnt)
		"ferry":
			for i in 6:
				var ang2 := float(i) / 6.0 * TAU
				_add_sphere(root, 0.05, tint, Vector3(cos(ang2) * 0.32, sin(ang2) * 0.16, sin(ang2) * 0.08))
			if particle_scale > 0.01:
				_cpu_trail(root, tint, particle_scale)
	return root

static func _build_arrow(root: Node3D, color: Color) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.012
	shaft.bottom_radius = 0.014
	shaft.height = 0.52
	_add_mesh(root, shaft, color, Vector3(0, 0, 0.05), Vector3(90, 0, 0))
	var head := PrismMesh.new()
	head.size = Vector3(0.07, 0.16, 0.025)
	_add_mesh(root, head, FROST_WHITE, Vector3(0, 0, -0.32), Vector3(90, 0, 0))
	var fletch := BoxMesh.new()
	fletch.size = Vector3(0.08, 0.012, 0.14)
	_add_mesh(root, fletch, color, Vector3(0, 0.02, 0.32), Vector3(0, 0, 40))
	var trail := BoxMesh.new()
	trail.size = Vector3(0.02, 0.012, 0.42)
	_add_mesh(root, trail, color, Vector3(0, 0, 0.58), Vector3.ZERO, 0.45)

static func _build_bolt(root: Node3D, color: Color) -> void:
	_add_sphere(root, 0.09, color, Vector3(0, 0, -0.05))
	_add_torus(root, 0.16, 0.018, FROST_WHITE, Vector3(0, 0, 0.08))
	var trail := BoxMesh.new()
	trail.size = Vector3(0.03, 0.03, 0.48)
	_add_mesh(root, trail, color, Vector3(0, 0, 0.36), Vector3.ZERO, 0.4)

static func _cpu_trail(root: Node3D, color: Color, scale: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, int(round(10.0 * scale)))
	p.lifetime = 0.28
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 8.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	mesh.material = m
	p.mesh = mesh
	root.add_child(p)
	p.emitting = true

static func _ember_sparks(root: Node3D, scale: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(3, int(round(6.0 * scale)))
	p.lifetime = 0.35
	p.explosiveness = 0.85
	p.direction = Vector3(0, 1, 0)
	p.spread = 28.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, -1.2, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = EMBER
	m.emission_enabled = true
	m.emission = EMBER
	mesh.material = m
	p.mesh = mesh
	root.add_child(p)
	p.emitting = true

static func _add_box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, alpha: float = 1.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(parent, mesh, color, pos, rot, alpha)

static func _add_sphere(parent: Node3D, radius: float, color: Color, pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_add_mesh(parent, mesh, color, pos, Vector3.ZERO)

static func _add_torus(parent: Node3D, radius: float, tube: float, color: Color, pos: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.02, radius - tube)
	mesh.outer_radius = radius + tube
	_add_mesh(parent, mesh, color, pos, Vector3(90, 0, 0))

static func _add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3, alpha: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	parent.add_child(mi)
