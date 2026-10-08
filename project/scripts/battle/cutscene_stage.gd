class_name CutsceneStage
extends RefCounted
## Procedural foreground / midground / background for the 14 battle biomes.
## Low tier keeps a single far layer so the prop count stays small.

const BIOMES := [
	"fog", "ford", "harbor", "snow", "marsh", "forge",
	"shrine", "archive", "fort", "nightcamp", "hill", "plain", "pass", "urban",
]

const FROST := Color8(110, 212, 255)
const MINT := Color8(94, 224, 181)
const WHITE := Color8(244, 247, 251)
const SLATE := Color8(154, 166, 184)
const INK := Color8(22, 27, 36)
const SHADOW := Color8(42, 52, 66)

const LOOK := {
	"fog": {"fog": Color8(138, 160, 181), "density": 0.055, "a": SLATE, "b": SHADOW},
	"ford": {"fog": FROST, "density": 0.028, "a": FROST, "b": INK},
	"harbor": {"fog": FROST, "density": 0.032, "a": MINT, "b": SHADOW},
	"snow": {"fog": Color8(197, 212, 228), "density": 0.03, "a": WHITE, "b": FROST},
	"marsh": {"fog": MINT, "density": 0.04, "a": Color8(28, 58, 52), "b": MINT},
	"forge": {"fog": SLATE, "density": 0.038, "a": SHADOW, "b": FROST},
	"shrine": {"fog": Color8(201, 214, 234), "density": 0.026, "a": WHITE, "b": FROST},
	"archive": {"fog": Color8(142, 155, 176), "density": 0.034, "a": INK, "b": SLATE},
	"fort": {"fog": Color8(126, 141, 163), "density": 0.03, "a": SHADOW, "b": SLATE},
	"nightcamp": {"fog": Color8(26, 36, 51), "density": 0.045, "a": INK, "b": FROST},
	"hill": {"fog": Color8(143, 163, 184), "density": 0.028, "a": Color8(58, 74, 92), "b": MINT},
	"plain": {"fog": Color8(169, 188, 204), "density": 0.022, "a": MINT, "b": SHADOW},
	"pass": {"fog": Color8(138, 160, 184), "density": 0.036, "a": SHADOW, "b": Color8(197, 208, 220)},
	"urban": {"fog": Color8(110, 124, 144), "density": 0.03, "a": INK, "b": FROST},
}

static func biome_ids() -> Array:
	return BIOMES.duplicate()

static func has_biome(biome: String) -> bool:
	return biome in BIOMES

static func biome_from_record(rec: Dictionary) -> String:
	var raw := str(rec.get("biome", "")).strip_edges()
	if has_biome(raw):
		return raw
	var bb := str(rec.get("backdrop", ""))
	var ground := str(rec.get("ground", ""))
	for id in BIOMES:
		if bb.find(id) >= 0 or ground == id:
			return id
	return "plain"

static func fog_for(biome: String) -> Dictionary:
	var look := _look(biome)
	var fog: Color = look.get("fog", Color8(16, 19, 26))
	return {
		"color": fog,
		"density": float(look.get("density", 0.035)),
	}

static func build(parent: Node, biome: String, low_tier: bool) -> Node3D:
	var id := biome if has_biome(biome) else "plain"
	var root := Node3D.new()
	root.name = "CutsceneStage"
	root.set_meta("biome", id)
	parent.add_child(root)
	var layers: Array = ["far"] if low_tier else ["far", "mid", "near"]
	for layer in layers:
		var holder := Node3D.new()
		holder.name = str(layer)
		var depth := -8.0
		var factor := 0.05
		var count := 6
		if str(layer) == "mid":
			depth = -3.2
			factor = 0.14
			count = 8
		elif str(layer) == "near":
			depth = 1.6
			factor = 0.26
			count = 6
		holder.position = Vector3(0, 0, depth)
		holder.set_meta("layer", str(layer))
		holder.set_meta("parallax", factor)
		holder.set_meta("base_x", 0.0)
		root.add_child(holder)
		_fill(holder, id, str(layer), count)
	return root

static func prop_count(root: Node) -> int:
	return _meshes(root)

static func parallax(root: Node3D, cam_x: float) -> void:
	if root == null:
		return
	for ch in root.get_children():
		if not ch.has_meta("parallax"):
			continue
		var k := float(ch.get_meta("parallax"))
		ch.position.x = float(ch.get_meta("base_x")) + cam_x * k

static func _look(biome: String) -> Dictionary:
	if LOOK.has(biome):
		return LOOK[biome]
	return LOOK["plain"]

static func _fill(holder: Node3D, biome: String, layer: String, count: int) -> void:
	var look := _look(biome)
	var tint_a: Color = look.get("a", FROST)
	var tint_b: Color = look.get("b", SHADOW)
	var h := _hash(biome + ":" + layer)
	for i in count:
		h = _next(h)
		var u := float(h % 1000) / 1000.0
		h = _next(h)
		var v := float(h % 1000) / 1000.0
		var x := lerpf(-7.5, 7.5, u)
		if layer == "near" and absf(x) < 2.4:
			x = 3.2 if x >= 0.0 else -3.2
		var y := _height(biome, layer, v)
		var size := _size(biome, layer, i)
		var pos := Vector3(x, y, lerpf(-0.4, 0.4, v))
		var color: Color = tint_a if i % 2 == 0 else tint_b
		_place(holder, biome, size, pos, color, float((h % 50) - 25))

static func _height(biome: String, layer: String, v: float) -> float:
	var base := 0.4
	if layer == "far":
		base = 1.6
	elif layer == "mid":
		base = 0.9
	if biome in ["pass", "fort", "urban", "archive", "shrine"]:
		base += 0.8
	elif biome in ["marsh", "ford", "plain"]:
		base *= 0.45
	return base * lerpf(0.65, 1.15, v)

static func _size(biome: String, layer: String, index: int) -> Vector3:
	var tall := 1.4 if layer == "far" else 0.9
	if biome in ["harbor", "shrine", "archive"]:
		return Vector3(0.18, tall, 0.18)
	if biome in ["snow", "marsh", "plain", "ford"]:
		return Vector3(1.1, 0.28 + 0.08 * float(index % 3), 0.5)
	if biome == "pass":
		return Vector3(0.7, tall * 1.6, 0.45)
	if biome in ["urban", "fort", "forge"]:
		return Vector3(0.7, tall, 0.45)
	return Vector3(0.45, tall * 0.7, 0.35)

static func _place(parent: Node3D, biome: String, size: Vector3, pos: Vector3, color: Color, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	if biome in ["harbor", "shrine"] and size.x < 0.3:
		var cyl := CylinderMesh.new()
		cyl.top_radius = size.x
		cyl.bottom_radius = size.x
		cyl.height = size.y
		mi.mesh = cyl
		pos.y = size.y * 0.5
	elif biome == "hill":
		var prism := PrismMesh.new()
		prism.size = size
		mi.mesh = prism
		pos.y = size.y * 0.35
	else:
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
		pos.y = size.y * 0.5
	mi.position = pos
	mi.rotation_degrees = Vector3(0, rot_y, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	if biome == "shrine" and size.x < 0.3:
		var lintel := MeshInstance3D.new()
		var cap := BoxMesh.new()
		cap.size = Vector3(0.7, 0.08, 0.16)
		lintel.mesh = cap
		lintel.position = pos + Vector3(0.2, size.y * 0.5, 0)
		var cap_mat := StandardMaterial3D.new()
		cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cap_mat.albedo_color = color
		lintel.material_override = cap_mat
		parent.add_child(lintel)

static func _meshes(n: Node) -> int:
	var found := 0
	if n is MeshInstance3D:
		found += 1
	for ch in n.get_children():
		found += _meshes(ch)
	return found

static func _hash(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = int((int(h) ^ s.unicode_at(i)) * 16777619) & 0x7fffffff
	return h

static func _next(h: int) -> int:
	return int((h * 1103515245 + 12345) & 0x7fffffff)
