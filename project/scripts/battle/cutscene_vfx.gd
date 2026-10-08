class_name CutsceneVfx
extends RefCounted
## Hit-stop, camera punch, frost damage numerals, and the kill dissolve.
## Ember stays on sparks only. Shards are frost, never blood.

const HIT_STOP := {"light": 0.04, "mid": 0.07, "heavy": 0.11}
const HIT_SCALE := {"light": 0.62, "mid": 0.45, "heavy": 0.32}
const PUNCH := {"light": 0.035, "mid": 0.07, "heavy": 0.12}
const FROST := Color8(110, 212, 255)
const FROST_WHITE := Color8(244, 247, 251)
const DISSOLVE := preload("res://shaders/frost_dissolve.gdshader")

static func weight_of_job(job_id: String) -> String:
	if job_id in ["heavy_inf", "warrior"]:
		return "heavy"
	if job_id in ["hunter", "archer", "apprentice", "priest"]:
		return "light"
	return "mid"

static func hit_stop_seconds(weight: String) -> float:
	return float(HIT_STOP.get(weight, HIT_STOP["mid"]))

static func time_scale_for(weight: String) -> float:
	return float(HIT_SCALE.get(weight, HIT_SCALE["mid"]))

static func punch_strength(reduced_motion: bool, weight: String) -> float:
	if reduced_motion:
		return 0.0
	return float(PUNCH.get(weight, PUNCH["mid"]))

static func play_hit_stop(tree: SceneTree, weight: String, should_stop: Callable = Callable()) -> void:
	var dur := hit_stop_seconds(weight)
	Engine.time_scale = time_scale_for(weight)
	var need := int(round(dur * 1000.0))
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < need:
		if should_stop.is_valid() and bool(should_stop.call()):
			break
		if tree == null:
			break
		await tree.process_frame
	Engine.time_scale = 1.0

static func spawn_damage(parent: Node3D, at: Vector3, text: String, color: Color, font: Font) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.modulate = color
	label.font_size = 42
	label.outline_modulate = Color8(10, 14, 20)
	label.outline_size = 12
	label.pixel_size = 0.0032
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.top_level = true
	parent.add_child(label)
	label.global_position = parent.global_position + at + Vector3(0, 1.72, 0.2)
	return label

static func begin_frost_break(root: Node3D, reduced_motion: bool, particle_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE
	mat.set_shader_parameter("dissolve", 1.0 if reduced_motion else 0.0)
	_paint(root, mat)
	if not reduced_motion and particle_scale > 0.01 and root != null:
		_shards(root, particle_scale)
	return mat

static func _paint(n: Node, mat: ShaderMaterial) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for ch in n.get_children():
		_paint(ch, mat)

static func _shards(root: Node3D, scale: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(6, int(round(14.0 * scale)))
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 55
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -2.2, 0)
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.05, 0.11, 0.028)
	p.angular_velocity_min = -4.0
	p.angular_velocity_max = 4.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = FROST
	m.emission_enabled = true
	m.emission = FROST_WHITE
	m.emission_energy_multiplier = 1.4
	mesh.material = m
	p.mesh = mesh
	p.position = root.position + Vector3(0, 1.1, 0)
	var host := root.get_parent() if root.get_parent() else root
	host.add_child(p)
	p.emitting = true
