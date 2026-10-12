class_name CutsceneStage
extends RefCounted
## Foreground / midground / background for the 14 battle biomes.
## WS-D #49: layers are painted art, not grey blocks. Far = the biome plate, mid = nation banners
## on poles (parallax), near = darkened side framing from the same plate. Nation banners
## (assets/art/banners, colour matched to the enemy trim) stand in the mid layer.
## Low tier keeps a single far layer so the prop count stays small.

const PLATE := "res://assets/art/battle/v8_battle_biome_%s.png"
const BANNER_DIR := "res://assets/art/banners"

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

static func build(parent: Node, biome: String, low_tier: bool, nation_tint = null) -> Node3D:
	var id := biome if has_biome(biome) else "plain"
	var root := Node3D.new()
	root.name = "CutsceneStage"
	root.set_meta("biome", id)
	root.set_meta("nation_tint", nation_tint)
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
		if not _paint(holder, id, str(layer), nation_tint):
			_fill(holder, id, str(layer), count)
	return root


## Biome from the defender's tile when it is distinctive, else the map biome.
static func biome_for_tile(tile_id: String, map_biome: String) -> String:
	match tile_id:
		"forest":
			return "marsh" if map_biome == "marsh" else ("fog" if map_biome == "fog" else "hill")
		"hill", "mountain":
			return "pass" if map_biome == "pass" else "hill"
		"fort", "wall", "gate":
			return "fort"
		"water", "river", "bridge", "shallows":
			return "harbor" if map_biome == "harbor" else "ford"
		"snow", "ice":
			return "snow"
	return map_biome if has_biome(map_biome) else "plain"


static func plate_path(biome: String) -> String:
	var p := CKArtPaths.resolve(PLATE % (biome if has_biome(biome) else "plain"))
	return p if CKArtPaths.exists(p) else ""


static func _card(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, uv_off: Vector2, uv_scale: Vector2, tint: Color, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_offset = Vector3(uv_off.x, uv_off.y, 0)
	m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
	if tint.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _paint(holder: Node3D, biome: String, layer: String, nation_tint) -> bool:
	var path := plate_path(biome)
	if path == "":
		return false
	var tex: Texture2D = CKArtPaths.load_texture(path)
	if tex == null:
		return false
	match layer:
		"far":
			_card(holder, tex, Vector2(96, 54), Vector3(0, 16.0, -10), Vector2.ZERO, Vector2.ONE, Color(0.86, 0.9, 0.96), "plate").material_override.disable_fog = true
		"mid":
			var banner := nation_banner(nation_tint)
			if banner != "":
				var btex: Texture2D = CKArtPaths.load_texture(banner)
				if btex != null:
					for x in [-4.6, 4.6]:
						_card(holder, btex, Vector2(0.9, 1.8), Vector3(x + 0.47, 2.3, 0.2), Vector2.ZERO, Vector2.ONE, Color(1, 1, 1, 0.95), "banner")
						var pole := MeshInstance3D.new()
						var pm := CylinderMesh.new()
						pm.top_radius = 0.035
						pm.bottom_radius = 0.045
						pm.height = 3.4
						pole.mesh = pm
						var pmat := StandardMaterial3D.new()
						pmat.albedo_color = INK
						pmat.roughness = 0.8
						pole.material_override = pmat
						pole.position = Vector3(x, 1.7, 0.2)
						holder.add_child(pole)
		"near":
			# out-of-focus framing at both edges, kept clear of the fighters in the middle
			for side in [-1.0, 1.0]:
				_card(holder, tex, Vector2(3.4, 3.0), Vector3(side * 5.4, 1.1, 0.0), Vector2(0.0 if side < 0 else 0.8, 0.7), Vector2(0.2, 0.3), Color(0.28, 0.31, 0.36, 0.95), "frame")
	return true


## Banner art whose colour (encoded in the file name) is nearest to the nation tint.
static func nation_banner(tint) -> String:
	if not (tint is Color):
		return ""
	var best := ""
	var best_d := INF
	var d := DirAccess.open(BANNER_DIR)
	if d == null:
		return ""
	for f in d.get_files():
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if not name.begins_with("banner_") or not name.ends_with("_w0.png"):
			continue
		var hex := name.get_slice("_", 1)
		if hex.length() != 6:
			continue
		var c := Color("#" + hex)
		var dist := Vector3(c.r - tint.r, c.g - tint.g, c.b - tint.b).length()
		if dist < best_d:
			best_d = dist
			best = "%s/%s" % [BANNER_DIR, name]
	return best

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
