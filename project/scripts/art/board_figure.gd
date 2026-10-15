class_name CKBoardFigure
extends RefCounted
## Portrait-matched board figures (docs/design/pawn-redesign-opus.md).
## Prototype-quality: Godot primitives + shared hair modules. Formal Blender GLB is later.
## ~5.45 head ratio, soft portrait lighting (board_figure.gdshader), 0 textures on body.

const SHADER_PATH := "res://shaders/board_figure.gdshader"
const MOD_DIR := "res://assets/models/modules/"
const FARM_CAST_DIR := "res://assets/models/board/farm_cast/"
const MODEL_H := 1.85
const HEAD_RATIO := 5.45
const CACHE_CAP := 64

static var _shader: Shader
static var _cache: Dictionary = {}  # hash -> Node3D packed scene? we cache built roots weakly by rebuilding cheaply
static var _pal_cache: Dictionary = {}  # identity -> palette dict

static func _sh() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader

## Build a board figure for character c on team. Returns a Node3D with AnimationPlayer child "Anim".
static func build(c, team: String, tmpl: String = "") -> Node3D:
	var enemy := str(team) == "enemy"
	var face := -1.0 if enemy else 1.0
	var pal: Dictionary = palette_for(c, team, tmpl)
	var root := Node3D.new()
	root.name = "BoardFigure"
	root.set_meta("ck_board_figure", true)
	root.set_meta("ck_face", face)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	if DisplayServer.get_name() != "headless":
		if not _assemble_farm_cast(body, c, pal, enemy, face, tmpl):
			_assemble(body, c, pal, enemy, face)
	var ap := _make_anim(root, face)
	root.add_child(ap)
	return root

static func find_anim(n: Node) -> AnimationPlayer:
	if n == null:
		return null
	var a := n.get_node_or_null("Anim") as AnimationPlayer
	if a:
		return a
	for ch in n.get_children():
		var f := find_anim(ch)
		if f:
			return f
	return null

## Spec used by gate tests: palette + role + triangle estimate.
static func spec_for(c, team: String, tmpl: String = "") -> Dictionary:
	var pal := palette_for(c, team, tmpl)
	var role := BattleRules.job_role(str(c.job_id)) if c != null else "skirmisher"
	return {
		"palette": pal,
		"role": role,
		"enemy": str(team) == "enemy",
		"tris_est": (5500 if _farm_cast_path(c, str(team) == "enemy", tmpl) != "" else 4200),
		"meshes": 1,
		"materials": 1,
		"textures": 0,
	}

static func palette_for(c, team: String, tmpl: String = "") -> Dictionary:
	var enemy := str(team) == "enemy"
	var key := _pal_key(c, team, tmpl)
	if _pal_cache.has(key):
		return (_pal_cache[key] as Dictionary).duplicate(true)
	var pal := _sample_portrait(c)
	if enemy:
		# Head/hair from portrait; cloth recolored by faction (coral), not portrait coat.
		pal["coat"] = _enemy_coat()
		pal["lining"] = Color(0.12, 0.10, 0.11)
		pal["scarf"] = UIKit.DANGER.darkened(0.15)
		pal["pants"] = Color(0.18, 0.15, 0.14)
		pal["boots"] = Color(0.14, 0.11, 0.10)
		_lift_enemy(pal)
	else:
		var house: Color = UnitArt.house_color() if Engine.get_main_loop() else UIKit.ACCENT
		# Soft house accent on cape/trim; coat stays portrait-sampled.
		pal["house"] = house
		if not pal.has("coat") or _chroma(pal["coat"]) < 0.05:
			pal["coat"] = Color.from_hsv(house.h, 0.35, 0.55)
	_protect(pal, enemy)
	if _pal_cache.size() > CACHE_CAP:
		_pal_cache.clear()
	_pal_cache[key] = pal.duplicate(true)
	return pal

static func _pal_key(c, team: String, tmpl: String) -> String:
	var id := str(c.id) if c != null and "id" in c else "x"
	return "%s|%s|%s" % [id, team, tmpl]

static func _sample_portrait(c) -> Dictionary:
	var out := {
		"hair": Color(0.25, 0.20, 0.18),
		"skin": Color(0.78, 0.62, 0.52),
		"coat": Color(0.55, 0.58, 0.62),
		"lining": Color(0.18, 0.16, 0.18),
		"scarf": Color(0.45, 0.48, 0.58),
		"pants": Color(0.16, 0.16, 0.18),
		"boots": Color(0.12, 0.11, 0.11),
		"metal": Color(0.78, 0.82, 0.88),
		"style": "crop",
	}
	if c == null:
		return out
	# Genome fallback first (works headless).
	if c.has_method("ensure_genome"):
		c.ensure_genome()
	if Engine.get_main_loop() != null and c.has_method("ensure_genome"):
		var ph: Dictionary = CKGenome.phenotype(c)
		if ph.has("hair_color"):
			out["hair"] = ph["hair_color"]
		if ph.has("skin_color"):
			out["skin"] = ph["skin_color"]
		out["style"] = CKPortraitDoll._style(c)
	# Prefer colours from the portrait that UnitArt actually shows.
	if DisplayServer.get_name() == "headless":
		return out
	var tex: Texture2D = UnitArt.portrait(c, 128, "large") if c is CKCharacter else null
	if tex == null:
		return out
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return out
	if img.is_compressed():
		img.decompress()
	_sample_image(img, out)
	return out

static func _sample_image(img: Image, out: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w < 8 or h < 8:
		return
	# Skin: mid face band.
	var skin_acc := Vector3.ZERO
	var skin_n := 0
	var y0 := int(h * 0.28)
	var y1 := int(h * 0.48)
	var x0 := int(w * 0.35)
	var x1 := int(w * 0.65)
	for y in range(y0, y1, maxi(1, (y1 - y0) / 12)):
		for x in range(x0, x1, maxi(1, (x1 - x0) / 12)):
			var px := img.get_pixel(x, y)
			if _looks_skin(px):
				skin_acc += Vector3(px.r, px.g, px.b)
				skin_n += 1
	if skin_n > 0:
		var s := skin_acc / float(skin_n)
		out["skin"] = Color(s.x, s.y, s.z).lightened(0.04)
	# Hair: top band, non-skin foreground-ish dark/mid.
	var hair_acc := Vector3.ZERO
	var hair_n := 0
	var hy1 := int(h * 0.22)
	for y in range(int(h * 0.04), hy1, maxi(1, hy1 / 10)):
		for x in range(int(w * 0.25), int(w * 0.75), maxi(1, w / 20)):
			var px2 := img.get_pixel(x, y)
			if px2.a < 0.4 or _looks_skin(px2) or _looks_bg(px2):
				continue
			hair_acc += Vector3(px2.r, px2.g, px2.b)
			hair_n += 1
	if hair_n > 0:
		var hv := hair_acc / float(hair_n)
		out["hair"] = Color(hv.x, hv.y, hv.z).lightened(0.08)
	# Coat: torso band below chin.
	var coat_acc := Vector3.ZERO
	var coat_n := 0
	var cy0 := int(h * 0.55)
	var cy1 := int(h * 0.82)
	for y in range(cy0, cy1, maxi(1, (cy1 - cy0) / 14)):
		for x in range(int(w * 0.28), int(w * 0.72), maxi(1, w / 18)):
			var px3 := img.get_pixel(x, y)
			if px3.a < 0.4 or _looks_skin(px3) or _looks_bg(px3):
				continue
			coat_acc += Vector3(px3.r, px3.g, px3.b)
			coat_n += 1
	if coat_n > 0:
		var cv := coat_acc / float(coat_n)
		out["coat"] = Color(cv.x, cv.y, cv.z).lightened(0.10)
		# Darker lining from darkest coat samples approximation.
		out["lining"] = Color(cv.x, cv.y, cv.z).darkened(0.45)

static func _looks_skin(px: Color) -> bool:
	var mx := maxf(px.r, maxf(px.g, px.b))
	var mn := minf(px.r, minf(px.g, px.b))
	var chroma := mx - mn
	return px.r > 0.35 and px.g > 0.25 and px.b > 0.18 and px.r >= px.g and chroma > 0.04 and chroma < 0.35 and mx < 0.95

static func _looks_bg(px: Color) -> bool:
	# Soft vignette / grey studio backs common in plates.
	var mx := maxf(px.r, maxf(px.g, px.b))
	var mn := minf(px.r, minf(px.g, px.b))
	return (mx - mn) < 0.06 and mx > 0.55

static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))

static func _enemy_coat() -> Color:
	# Coral faction wool, luminance floor ~0.40.
	return Color.from_hsv(UIKit.DANGER.h, 0.42, 0.48)

static func _lift_enemy(pal: Dictionary) -> void:
	for k in ["coat"]:
		pal[k] = _lift_lum(pal[k], 0.40)
	for k in ["pants", "boots"]:
		pal[k] = _lift_lum(pal[k], 0.26)
	pal["lining"] = _lift_lum(pal["lining"], 0.12)

static func _lift_lum(c: Color, floor_v: float) -> Color:
	var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	if lum >= floor_v:
		return c
	var out := c
	while lum < floor_v - 0.001:
		out = out.lightened(0.05)
		lum = 0.2126 * out.r + 0.7152 * out.g + 0.0722 * out.b
		if out.r >= 0.99 and out.g >= 0.99 and out.b >= 0.99:
			break
	return out

## §3.5 faction gamut guards (hue windows in degrees).
static func _protect(pal: Dictionary, enemy: bool) -> void:
	if enemy:
		for k in ["coat", "lining", "scarf", "pants", "boots", "house"]:
			if not pal.has(k):
				continue
			var col: Color = pal[k]
			if _in_ally_gamut(col):
				pal[k] = Color(0.16, 0.14, 0.15) if k != "coat" else _enemy_coat()
	else:
		for k in ["house", "scarf"]:
			if not pal.has(k):
				continue
			var col2: Color = pal[k]
			if _in_enemy_gamut(col2):
				pal[k] = Color(0.78, 0.82, 0.87)  # frost silver stand-in

static func _in_ally_gamut(c: Color) -> bool:
	if _chroma(c) <= 0.15:
		return false
	var deg := c.h * 360.0
	return deg >= 150.0 and deg <= 220.0

static func _in_enemy_gamut(c: Color) -> bool:
	if _chroma(c) <= 0.15:
		return false
	var deg := c.h * 360.0
	return deg <= 30.0 or deg >= 340.0

static func _mat(base: Color, face: float, enemy: bool, metal: float = 0.0, sheen: float = 0.0) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _sh()
	sm.set_shader_parameter("base", base)
	sm.set_shader_parameter("face", face)
	sm.set_shader_parameter("metal", metal)
	sm.set_shader_parameter("sheen", sheen)
	sm.set_shader_parameter("rim_col", UIKit.DANGER if enemy else UIKit.ACCENT)
	var rim := 0.85 if enemy or (0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b) < 0.36 else 0.55
	sm.set_shader_parameter("rim_amt", rim)
	sm.set_shader_parameter("use_bands", 0.0)
	sm.set_shader_parameter("board_compact", 0.0)
	return sm

## Whole-mesh farm cast: height bands (skin/coat/pants/hair) + board_compact so pieces are not grey clay.
static func _farm_mat(pal: Dictionary, face: float, enemy: bool) -> ShaderMaterial:
	var coat: Color = _lift_lum(pal.get("coat", Color(0.55, 0.58, 0.62)), 0.42)
	var skin: Color = _lift_lum(pal.get("skin", Color(0.78, 0.62, 0.52)), 0.55)
	var pants: Color = _lift_lum(pal.get("pants", Color(0.16, 0.16, 0.18)), 0.22)
	var boots: Color = pal.get("boots", Color(0.12, 0.11, 0.11))
	var hair: Color = pal.get("hair", Color(0.25, 0.20, 0.18))
	var sm := _mat(coat, face, enemy, 0.04, 0.08)
	sm.set_shader_parameter("use_bands", 1.0)
	sm.set_shader_parameter("board_compact", 1.0)
	sm.set_shader_parameter("model_h", MODEL_H)
	sm.set_shader_parameter("skin", skin)
	sm.set_shader_parameter("coat", coat)
	sm.set_shader_parameter("pants", pants)
	sm.set_shader_parameter("boots", boots)
	sm.set_shader_parameter("hair", hair)
	sm.set_shader_parameter("base", coat)
	sm.set_shader_parameter("rim_amt", 0.22)
	return sm

static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, scale: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi


## Whole-mesh farm Hunyuan casts (leader / hunter / bandit*). Prefer over Godot primitives.
## Not the rejected #301 modular kit — single MeshInstance3D + board_figure shader.
static func _farm_cast_path(c, enemy: bool, tmpl: String) -> String:
	## Temporary remap (until dedicated farm_cast GLBs): any 3D unit uses an existing cast
	## so opening/tutorial fights never mix Godot capsules with Hunyuan meshes.
	## leader_* ← is_leader / cast_key leader / captain / banner / tank|heavy_inf
	## hunter_* ← hunter|archer|ranger|light_inf|squire|apprentice|cavalry|mage|other ally
	## bandit*  ← enemy templates; unknown enemy → bandit
	if enemy:
		var t := tmpl if tmpl != "" else "bandit"
		if t in ["bandit", "bandit_archer", "bandit_chief", "bandit_weak"]:
			var own := FARM_CAST_DIR + t + ".glb"
			if ResourceLoader.exists(own):
				return own
		var fallback := FARM_CAST_DIR + "bandit.glb"
		return fallback if ResourceLoader.exists(fallback) else ""
	var role := "skirmisher"
	var jid := ""
	if c != null:
		jid = str(c.job_id)
		role = BattleRules.job_role(jid)
	var lead := false
	if c != null:
		lead = bool(c.is_leader) or str(c.cast_key) == "leader"
	lead = lead or role == "leader" or jid in ["captain", "banner"]
	# Bulkier ally jobs share leader silhouette until heavy_inf farm cast ships.
	if lead or role == "tank" or jid in ["heavy_inf", "warrior"]:
		return _farm_cast_gendered("leader", c)
	# Everyone else (incl. opening light_inf / squire non-leader / mage / cavalry) → hunter_*.
	return _farm_cast_gendered("hunter", c)

static func _farm_cast_gendered(stem: String, c) -> String:
	var g := "f" if c != null and str(c.gender) == "f" else "m"
	var cand := FARM_CAST_DIR + "%s_%s.glb" % [stem, g]
	if ResourceLoader.exists(cand):
		return cand
	var alt := FARM_CAST_DIR + ("%s_m.glb" % stem if g == "f" else "%s_f.glb" % stem)
	if ResourceLoader.exists(alt):
		return alt
	return ""

static func _assemble_farm_cast(body: Node3D, c, pal: Dictionary, enemy: bool, face: float, tmpl: String) -> bool:
	var path := _farm_cast_path(c, enemy, tmpl)
	if path == "":
		return false
	var packed = load(path)
	if packed == null:
		return false
	var inst: Node = packed.instantiate() if packed is PackedScene else null
	if inst == null:
		return false
	var mat := _farm_mat(pal, face, enemy)
	var added := 0
	for n in _gather_meshes(inst):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var clone := MeshInstance3D.new()
		clone.mesh = mi.mesh
		# Drop imported StandardMaterial; banded board_figure shader owns albedo.
		clone.material_override = mat
		if mi.mesh.get_surface_count() > 0:
			for si in range(mi.mesh.get_surface_count()):
				clone.set_surface_override_material(si, mat)
		clone.name = "FarmCast%d" % added
		# Keep authoring transform (retopo root may carry scale/offset).
		clone.transform = mi.transform
		body.add_child(clone)
		added += 1
	inst.free()
	if added == 0:
		return false
	body.set_meta("ck_farm_cast", path)
	return true

static func _gather_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_gather_meshes(ch))
	return out

static func _assemble(body: Node3D, c, pal: Dictionary, enemy: bool, face: float) -> void:
	var head_h := MODEL_H / HEAD_RATIO
	# Relative to real adult, head is enlarged ~1.35x inside the 5.45 ratio.
	var hip_y := 0.92
	var shoulder_y := 1.28
	var chin_y := MODEL_H - head_h * 0.95
	var crown_y := MODEL_H - head_h * 0.05
	var skin: Color = pal["skin"]
	var coat: Color = pal["coat"]
	var lining: Color = pal["lining"]
	var pants: Color = pal["pants"]
	var boots: Color = pal["boots"]
	var hair: Color = pal["hair"]
	var metal: Color = pal.get("metal", Color(0.78, 0.82, 0.88))
	var house: Color = pal.get("house", coat)
	var role := "skirmisher"
	if c != null:
		role = BattleRules.job_role(str(c.job_id))
	# Legs
	for side in [-1.0, 1.0]:
		var thigh := CylinderMesh.new()
		thigh.top_radius = 0.07
		thigh.bottom_radius = 0.08
		thigh.height = 0.42
		thigh.radial_segments = 8
		_mesh(body, thigh, Vector3(0.09 * side, hip_y - 0.22, 0.02), Vector3(6, 0, 4 * side), Vector3.ONE, _mat(pants, face, enemy))
		var shin := CylinderMesh.new()
		shin.top_radius = 0.055
		shin.bottom_radius = 0.06
		shin.height = 0.40
		shin.radial_segments = 8
		_mesh(body, shin, Vector3(0.10 * side, 0.28, 0.04), Vector3(4, 0, 2 * side), Vector3.ONE, _mat(boots, face, enemy))
	# Torso coat
	var torso := SphereMesh.new()
	torso.radius = 0.20
	torso.height = 0.55
	_mesh(body, torso, Vector3(0, shoulder_y - 0.12, 0.02), Vector3.ZERO, Vector3(1.15, 1.35, 0.85), _mat(coat, face, enemy))
	# Waist / lining peek
	var waist := CylinderMesh.new()
	waist.top_radius = 0.14
	waist.bottom_radius = 0.16
	waist.height = 0.18
	waist.radial_segments = 10
	_mesh(body, waist, Vector3(0, hip_y + 0.05, 0.02), Vector3.ZERO, Vector3.ONE, _mat(lining, face, enemy))
	# Arms
	for side in [-1.0, 1.0]:
		var upper := CylinderMesh.new()
		upper.top_radius = 0.045
		upper.bottom_radius = 0.05
		upper.height = 0.32
		upper.radial_segments = 7
		_mesh(body, upper, Vector3(0.24 * side, shoulder_y - 0.05, 0.02), Vector3(0, 0, 18 * side), Vector3.ONE, _mat(coat, face, enemy))
		var fore := CylinderMesh.new()
		fore.top_radius = 0.04
		fore.bottom_radius = 0.042
		fore.height = 0.30
		fore.radial_segments = 7
		_mesh(body, fore, Vector3(0.34 * side, shoulder_y - 0.32, 0.06), Vector3(12, 0, 8 * side), Vector3.ONE, _mat(coat.darkened(0.08), face, enemy))
		var hand := SphereMesh.new()
		hand.radius = 0.045
		hand.height = 0.09
		_mesh(body, hand, Vector3(0.38 * side, shoulder_y - 0.48, 0.08), Vector3.ZERO, Vector3.ONE, _mat(skin, face, enemy))
	# Head (chin tilt ~8°)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, chin_y + head_h * 0.35, 0.04)
	head.rotation_degrees = Vector3(-8.0, 0, 0)
	body.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = head_h * 0.42
	skull.height = head_h * 0.78
	_mesh(head, skull, Vector3(0, head_h * 0.08, 0), Vector3.ZERO, Vector3(1.0, 1.05, 0.95), _mat(skin, face, enemy))
	var jaw := SphereMesh.new()
	jaw.radius = head_h * 0.28
	jaw.height = head_h * 0.36
	_mesh(head, jaw, Vector3(0, -head_h * 0.18, 0.04), Vector3.ZERO, Vector3(0.95, 0.7, 0.85), _mat(skin.darkened(0.04), face, enemy))
	# Hair module (shared LOD) — scaled to board head.
	_attach_hair(head, str(pal.get("style", "crop")), hair, face, enemy, head_h)
	# Ally cape flash in house colour (small, readable).
	if not enemy:
		var cape := BoxMesh.new()
		cape.size = Vector3(0.28, 0.42, 0.04)
		_mesh(body, cape, Vector3(0, shoulder_y - 0.15, -0.12), Vector3(12, 0, 0), Vector3.ONE, _mat(house, face, enemy, 0.0, 0.15))
	# Weapon by role (slightly oversized swords ~1.15).
	_weapon(body, role, enemy, face, metal, shoulder_y)
	# Soft AO bake into darker lower parts already via colors; done.

static func _attach_hair(head: Node3D, style: String, col: Color, face: float, enemy: bool, head_h: float) -> void:
	var sid := style if style in ["bob", "crop", "crown", "long", "messy", "pony", "swept", "tied"] else "crop"
	var path := MOD_DIR + "hair_%s.glb" % sid
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(path):
		var bun := SphereMesh.new()
		bun.radius = head_h * 0.38
		bun.height = head_h * 0.55
		_mesh(head, bun, Vector3(0, head_h * 0.22, -0.02), Vector3.ZERO, Vector3(1.05, 0.7, 1.0), _mat(col, face, enemy))
		return
	var packed := load(path)
	if packed == null:
		return
	var inst: Node = packed.instantiate() if packed is PackedScene else null
	if inst == null:
		return
	inst.name = "Hair"
	inst.scale = Vector3.ONE * (head_h / 0.28)
	inst.position = Vector3(0, head_h * 0.05, 0)
	head.add_child(inst)
	_recolor_hair(inst, col, face, enemy)

static func _recolor_hair(n: Node, col: Color, face: float, enemy: bool) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = _mat(col, face, enemy, 0.0, 0.2)
	for ch in n.get_children():
		_recolor_hair(ch, col, face, enemy)

static func _weapon(body: Node3D, role: String, enemy: bool, face: float, metal: Color, shoulder_y: float) -> void:
	var hand_x := 0.42 * face  # camera-side; enemies face left so weapon on their left visually via face sign on yaw
	# Prefer right-hand screen side: +X for allies facing +yaw.
	hand_x = 0.40
	var blade_col := metal if not enemy else metal.darkened(0.1)
	match role:
		"ranger":
			var bow := TorusMesh.new()
			bow.inner_radius = 0.02
			bow.outer_radius = 0.22
			_mesh(body, bow, Vector3(-0.28, shoulder_y - 0.05, 0.05), Vector3(0, 0, 90), Vector3(0.35, 1.0, 1.0), _mat(Color(0.35, 0.22, 0.14), face, enemy))
		"mage":
			var staff := CylinderMesh.new()
			staff.top_radius = 0.018
			staff.bottom_radius = 0.022
			staff.height = 1.15
			staff.radial_segments = 6
			_mesh(body, staff, Vector3(hand_x, 0.85, 0.12), Vector3(8, 0, 0), Vector3.ONE, _mat(Color(0.30, 0.22, 0.16), face, enemy))
			var tip := SphereMesh.new()
			tip.radius = 0.05
			_mesh(body, tip, Vector3(hand_x, 1.42, 0.14), Vector3.ZERO, Vector3.ONE, _mat(UIKit.ACCENT if not enemy else UIKit.DANGER, face, enemy, 0.2, 0.4))
		"tank", "cavalry":
			var spear := CylinderMesh.new()
			spear.top_radius = 0.015
			spear.bottom_radius = 0.02
			spear.height = 1.25
			spear.radial_segments = 6
			_mesh(body, spear, Vector3(hand_x, 0.90, 0.10), Vector3(10, 0, 0), Vector3.ONE, _mat(Color(0.32, 0.24, 0.18), face, enemy))
			var tip2 := CylinderMesh.new()
			tip2.top_radius = 0.0
			tip2.bottom_radius = 0.04
			tip2.height = 0.14
			_mesh(body, tip2, Vector3(hand_x, 1.52, 0.16), Vector3(10, 0, 0), Vector3.ONE, _mat(blade_col, face, enemy, 1.0, 0.2))
		_:
			# Sword ~1.15 oversized.
			var blade := BoxMesh.new()
			blade.size = Vector3(0.045, 0.72, 0.012)
			_mesh(body, blade, Vector3(hand_x, 0.95, 0.12), Vector3(8, 0, 0), Vector3.ONE, _mat(blade_col, face, enemy, 1.0, 0.15))
			var guard := BoxMesh.new()
			guard.size = Vector3(0.14, 0.03, 0.04)
			_mesh(body, guard, Vector3(hand_x, 0.60, 0.10), Vector3.ZERO, Vector3.ONE, _mat(metal.darkened(0.15), face, enemy, 0.8, 0.1))
			var hilt := CylinderMesh.new()
			hilt.top_radius = 0.02
			hilt.bottom_radius = 0.02
			hilt.height = 0.16
			_mesh(body, hilt, Vector3(hand_x, 0.50, 0.10), Vector3.ZERO, Vector3.ONE, _mat(Color(0.25, 0.18, 0.14), face, enemy))

static func _make_anim(root: Node3D, _face: float) -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _clip_idle())
	lib.add_animation("advance", _clip_advance())
	lib.add_animation("attack", _clip_attack())
	lib.add_animation("skill", _clip_attack())
	lib.add_animation("crit", _clip_attack())
	lib.add_animation("hit", _clip_hit())
	lib.add_animation("dodge", _clip_hit())
	lib.add_animation("death", _clip_death())
	ap.add_animation_library("", lib)
	return ap

static func _clip_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Body"))
	a.position_track_insert_key(t, 0.0, Vector3(0, 0, 0))
	a.position_track_insert_key(t, 0.6, Vector3(0, 0.02, 0))
	a.position_track_insert_key(t, 1.2, Vector3(0, 0, 0))
	return a

static func _clip_advance() -> Animation:
	var a := Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_LINEAR
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Body"))
	a.position_track_insert_key(t, 0.0, Vector3(0, 0, 0))
	a.position_track_insert_key(t, 0.25, Vector3(0, 0.04, 0.02))
	a.position_track_insert_key(t, 0.5, Vector3(0, 0, 0))
	return a

static func _clip_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_NONE
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath("Body"))
	a.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(t, 0.25, Quaternion.from_euler(Vector3(deg_to_rad(-18), deg_to_rad(25), 0)))
	a.rotation_track_insert_key(t, 0.55, Quaternion.IDENTITY)
	return a

static func _clip_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Body"))
	a.position_track_insert_key(t, 0.0, Vector3(0, 0, 0))
	a.position_track_insert_key(t, 0.12, Vector3(0, 0.02, -0.06))
	a.position_track_insert_key(t, 0.35, Vector3(0, 0, 0))
	return a

static func _clip_death() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_NONE
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Body"))
	a.position_track_insert_key(t, 0.0, Vector3(0, 0, 0))
	a.position_track_insert_key(t, 1.0, Vector3(0, -0.15, 0.2))
	var r := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(r, NodePath("Body"))
	a.rotation_track_insert_key(r, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(r, 1.0, Quaternion.from_euler(Vector3(deg_to_rad(70), 0, deg_to_rad(20))))
	return a

## Static colour-slot checks for CI (no GPU).
static func assert_palette_rules(pal: Dictionary, enemy: bool) -> String:
	if enemy:
		for k in ["coat", "lining", "scarf", "pants", "boots"]:
			if pal.has(k) and _in_ally_gamut(pal[k]):
				return "enemy slot %s in ally gamut" % k
	else:
		for k in ["house", "scarf"]:
			if pal.has(k) and _in_enemy_gamut(pal[k]):
				return "ally slot %s in enemy gamut" % k
	return ""
