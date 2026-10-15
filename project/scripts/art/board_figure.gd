class_name CKBoardFigure
extends RefCounted
## Formal modular board figures (docs/design/pawn-redesign-opus.md §3 / §5 / 附录 A/B).
## Board figures: scale 演出 UnitModel GLBs onto the board + plate_palette shader.
## Prefer units/*.glb (UnitModel.resolve). farm_cast / kit compose only if resolve fails.
## Shader remaps albedo → hair/skin/coat/… slots (no board_compact solid fill).

const SHADER_PATH := "res://shaders/board_figure.gdshader"
const MAP_PATH := "res://data/board_figures.json"
const PLATE_PALETTES := "res://data/plate_palettes.json"
const PLATE_OVERRIDES := "res://data/plate_palette_overrides.json"
const MODEL_H := 1.85
const CACHE_CAP := 64
const STANDIN_W := 160
const STANDIN_H := 200

const PALETTE_KEYS: Array[String] = [
	"hair", "skin", "eye", "coat", "coat_dark", "apron", "sash", "metal",
	"blade", "house", "crest", "cape", "trousers", "boots", "leather", "wood", "accent",
]

static var _shader: Shader
static var _map: Dictionary = {}
static var _map_ready := false
static var _kit: PackedScene
static var _kit_meshes: Dictionary = {}  # name -> ArrayMesh
static var _kit_ready := false
static var _plate_table: Dictionary = {}
static var _plate_ovr: Dictionary = {}
static var _plate_ready := false
static var _lru: Dictionary = {}  # hash -> {mesh, mat_params...}  (built roots cloned)
static var _lru_order: Array[String] = []
static var _standin_mem: Dictionary = {}  # hash -> ImageTexture
static var _pal_cache: Dictionary = {}


static func _sh() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


static func _ensure_map() -> void:
	if _map_ready:
		return
	_map_ready = true
	var raw = _load_json(MAP_PATH)
	_map = raw if typeof(raw) == TYPE_DICTIONARY else {}


static func _ensure_kit() -> void:
	if _kit_ready:
		return
	_kit_ready = true
	_ensure_map()
	var path := str(_map.get("kit_glb", "res://assets/models/board/board_figures_v1.glb"))
	if not ResourceLoader.exists(path):
		push_warning("CKBoardFigure: missing kit %s" % path)
		return
	_kit = load(path) as PackedScene
	if _kit == null:
		return
	var inst: Node = _kit.instantiate()
	_collect_kit_meshes(inst)
	inst.free()


static func _collect_kit_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			# Duplicate so meshes survive after the kit instance is freed.
			_kit_meshes[str(mi.name)] = mi.mesh.duplicate()
	for ch in n.get_children():
		_collect_kit_meshes(ch)


static func _ensure_plate_table() -> void:
	if _plate_ready:
		return
	_plate_ready = true
	if ResourceLoader.exists(PLATE_PALETTES):
		var raw = _load_json(PLATE_PALETTES)
		if typeof(raw) == TYPE_DICTIONARY:
			var plates = raw.get("plates", raw)
			if typeof(plates) == TYPE_DICTIONARY:
				_plate_table = plates
	if ResourceLoader.exists(PLATE_OVERRIDES):
		var ovr = _load_json(PLATE_OVERRIDES)
		if typeof(ovr) == TYPE_DICTIONARY:
			_plate_ovr = ovr


static func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed != null else {}


static func _hex_color(hx: Variant, fallback: Color) -> Color:
	var s := str(hx)
	if s.begins_with("#") and s.length() >= 7:
		return Color.html(s)
	return fallback


## Resolve palette row for the plate stem try_texture actually loaded (no rematch).
static func palette_row_for_stem(stem: String) -> Dictionary:
	_ensure_plate_table()
	if stem == "" or not _plate_table.has(stem):
		return {}
	var row: Dictionary = (_plate_table[stem] as Dictionary).duplicate(true)
	if _plate_ovr.has(stem) and typeof(_plate_ovr[stem]) == TYPE_DICTIONARY:
		var o: Dictionary = _plate_ovr[stem]
		for k in o.keys():
			if str(k).begins_with("_"):
				continue
			row[k] = o[k]
	return row


## Spec: parts + palette + budgets (for gate / stand-in hash).
static func spec_for(c, team: String, tmpl: String = "") -> Dictionary:
	_ensure_map()
	var enemy := str(team) == "enemy"
	var pal := palette_for(c, team, tmpl)
	var parts := _parts_for(c, team, tmpl, pal)
	var tris := _estimate_tris(parts)
	return {
		"palette": pal,
		"parts": parts,
		"enemy": enemy,
		"role": BattleRules.job_role(str(c.job_id)) if c != null else "skirmisher",
		"tris_est": tris,
		"meshes": 1,
		"materials": 1,
		"textures": 0,
		"appearance_hash": appearance_hash(c, team, tmpl, pal, parts),
		"plate_stem": str(pal.get("plate_stem", "")),
		"scale": float(parts.get("scale", 1.0)),
	}


static func appearance_hash(c, team: String, tmpl: String, pal: Dictionary = {}, parts: Dictionary = {}) -> String:
	if pal.is_empty():
		pal = palette_for(c, team, tmpl)
	if parts.is_empty():
		parts = _parts_for(c, team, tmpl, pal)
	var id := str(c.id) if c != null and "id" in c else "x"
	var stem := str(pal.get("plate_stem", ""))
	var house := _color_key(pal.get("house", Color.WHITE))
	var mpath := ""
	if c != null:
		mpath = UnitModel.model_path(c, team, tmpl)
	return "%s|%s|%s|%s|%s|%s" % [id, team, tmpl, stem, mpath, house]


static func _color_key(c) -> String:
	if c is Color:
		return (c as Color).to_html(false)
	return str(c)


static func build(c, team: String, tmpl: String = "") -> Node3D:
	var enemy := str(team) == "enemy"
	var face := -1.0 if enemy else 1.0
	var pal: Dictionary = palette_for(c, team, tmpl)
	var parts: Dictionary = _parts_for(c, team, tmpl, pal)
	var h := appearance_hash(c, team, tmpl, pal, parts)
	var root := Node3D.new()
	root.name = "BoardFigure"
	root.set_meta("ck_board_figure", true)
	root.set_meta("ck_face", face)
	root.set_meta("ck_appearance_hash", h)
	root.set_meta("ck_plate_stem", str(pal.get("plate_stem", "")))
	# 演出整模优先
	var unit: Node3D = UnitModel.instantiate(c, team, tmpl)
	if unit != null:
		unit.name = "Unit"
		root.add_child(unit)
		_ensure_unit_hair(unit, c, team)
		_ground_and_fit(unit)
		_apply_board_palette(unit, pal, face, enemy)
		# Chin +8° (§3.2)
		unit.rotation_degrees.x = -8.0
		root.set_meta("ck_source", "unit_model")
		root.set_meta("ck_model", str(unit.get_meta("ck_model", "")))
	else:
		# 兜底：旧 kit compose / modular
		var body := Node3D.new()
		body.name = "Body"
		root.add_child(body)
		var scl := float(parts.get("scale", 1.0))
		if scl != 1.0:
			body.scale = Vector3.ONE * scl
		_assemble_kit(body, parts, pal, face, enemy)
		root.set_meta("ck_source", "kit_fallback")
		var ap := _make_anim(root)
		root.add_child(ap)
	_lru_put(h, true)
	return root



static func _unit_has_hair_mesh(n: Node) -> bool:
	if n is MeshInstance3D:
		var nm := str(n.name).to_lower()
		if "hair" in nm:
			return true
	for ch in n.get_children():
		if _unit_has_hair_mesh(ch):
			return true
	return false


static func _ensure_unit_hair(unit: Node3D, c, team: String) -> void:
	## Cast / enemy GLBs bake hair into the body albedo. Outfit path already attach_modules.
	## Archetype stand-ins may be bald — seat hair_* on the head bone before ground/fit.
	if unit == null or c == null:
		return
	var mp := str(unit.get_meta("ck_model", ""))
	var fn := mp.get_file() if mp != "" else ""
	if fn.begins_with("cast_") or fn.begins_with("enemy_") or fn.begins_with("outfit_"):
		return
	if _unit_has_hair_mesh(unit):
		return
	UnitModel.attach_modules(unit, c, team)


static func _ground_and_fit(n: Node3D) -> void:
	## Sit feet on y=0 and scale height ≈ MODEL_H (1.85).
	var aabb := _mesh_aabb_walk(n, Transform3D.IDENTITY)
	if aabb.size.y < 0.05:
		return
	n.position.y -= aabb.position.y
	var h := aabb.size.y
	if h > 0.05:
		n.scale *= (1.85 / h)


static func _mesh_aabb_walk(n: Node, xf: Transform3D) -> AABB:
	var acc := AABB()
	var any := false
	var x2 := xf
	if n is Node3D:
		x2 = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			acc = x2 * mi.mesh.get_aabb()
			any = true
	for ch in n.get_children():
		var ca := _mesh_aabb_walk(ch, x2)
		if ca.size.length_squared() > 1e-8:
			if not any:
				acc = ca
				any = true
			else:
				acc = acc.merge(ca)
	return acc if any else AABB()


static func _apply_board_palette(n: Node, pal: Dictionary, face: float, enemy: bool) -> void:
	## Replace materials with board_figure.gdshader; albedo → palette slots. Never board_compact.
	## outfit_* bodies are greyscale fill targets — use material-name slots, not albedo classify.
	var model_fn := _model_filename(n)
	var outfit_mode := model_fn.begins_with("outfit_")
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var y_min := aabb.position.y
			var y_span := maxf(0.05, aabb.size.y)
			var nlow := str(mi.name).to_lower()
			var hair_mesh := ("hair" in nlow) or nlow.begins_with("hair_")
			for si in mi.mesh.get_surface_count():
				var tex: Texture2D = _extract_albedo(mi, si)
				var sm := _palette_mat(pal, face, enemy)
				sm.set_shader_parameter("force_slot", -1.0)
				var mat_name := _surface_mat_name(mi, si)
				var named_slot := _force_slot_for(nlow, mat_name)
				if hair_mesh or "hair" in mat_name:
					sm.set_shader_parameter("use_albedo", 0.0)
					sm.set_shader_parameter("force_slot", 0.0)
				elif outfit_mode:
					# Named non-body parts keep solid slots; body uses height+albedo classify
					# so greyscale head band still reads as skin/hair.
					var base := mat_name.split(".")[0] if mat_name != "" else ""
					if base in ["skin", "hair", "weapon", "armor", "leather", "trim", "visor", "metal"] or "weapon" in nlow or "hair" in nlow:
						sm.set_shader_parameter("use_albedo", 0.0)
						sm.set_shader_parameter("force_slot", named_slot)
					elif tex != null:
						sm.set_shader_parameter("use_albedo", 1.0)
						sm.set_shader_parameter("albedo_tex", tex)
					else:
						sm.set_shader_parameter("use_albedo", 0.0)
						sm.set_shader_parameter("force_slot", named_slot)
				elif tex != null:
					# cast_/enemy_ painted albedo → classify hair/skin/coat zones.
					sm.set_shader_parameter("use_albedo", 1.0)
					sm.set_shader_parameter("albedo_tex", tex)
				else:
					sm.set_shader_parameter("use_albedo", 0.0)
					sm.set_shader_parameter("force_slot", named_slot)
				sm.set_shader_parameter("y_min", y_min)
				sm.set_shader_parameter("y_span", y_span)
				sm.set_shader_parameter("model_h", y_span)
				mi.set_surface_override_material(si, sm)
	for ch in n.get_children():
		_apply_board_palette(ch, pal, face, enemy)


static func _model_filename(n: Node) -> String:
	var cur: Node = n
	while cur != null:
		if cur.has_meta("ck_model"):
			return str(cur.get_meta("ck_model")).get_file()
		cur = cur.get_parent()
	return ""


static func _has_named_slot(nlow: String, mat_name: String) -> bool:
	var s := mat_name if mat_name != "" else nlow
	var base := s.split(".")[0]
	if base in ["armor", "cloth", "leather", "weapon", "skin", "hair", "trim", "visor", "body", "metal"]:
		return true
	for k in ["weapon", "blade", "sword", "hair", "skin", "leather", "armor", "cloth", "metal", "trim"]:
		if k in s:
			return true
	return false


static func _extract_albedo(mi: MeshInstance3D, si: int) -> Texture2D:
	var ov = mi.get_surface_override_material(si)
	var m = ov if ov != null else mi.mesh.surface_get_material(si)
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var t = sm.get_shader_parameter("albedo_tex")
		if t is Texture2D:
			return t as Texture2D
	if m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		if bm.albedo_texture != null:
			return bm.albedo_texture
	# External __albedo_v87.jpg next to model
	var root: Node = mi
	while root.get_parent() != null and not root.has_meta("ck_model"):
		root = root.get_parent()
	if root.has_meta("ck_model"):
		var mp := str(root.get_meta("ck_model"))
		if mp.ends_with(".glb"):
			var ap := mp.replace(".glb", "__albedo_v87.jpg")
			if ResourceLoader.exists(ap):
				return load(ap) as Texture2D
	return null


static func _surface_mat_name(mi: MeshInstance3D, si: int) -> String:
	var ov = mi.get_surface_override_material(si)
	var m = ov if ov != null else mi.mesh.surface_get_material(si)
	if m == null:
		return ""
	return str(m.resource_name).to_lower()


static func _force_slot_for(nlow: String, mat_name: String) -> float:
	var s := mat_name if mat_name != "" else nlow
	var base := s.split(".")[0]
	if "weapon" in s or "blade" in s or "sword" in s or "bow" in s or base == "weapon":
		return 8.0
	if base in ["metal", "trim", "visor", "armor"] or "metal" in s or "trim" in s or "armor" in s:
		return 7.0
	if "leather" in s or base == "leather":
		return 14.0
	if "skin" in s or base == "skin":
		return 1.0
	if "hair" in s or base == "hair":
		return 0.0
	if "cloth" in s or base == "cloth" or base == "body":
		return 3.0  # coat
	return 3.0

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


static func _parts_for(c, team: String, tmpl: String, pal: Dictionary) -> Dictionary:
	_ensure_map()
	var enemy := str(team) == "enemy"
	var gender := "f" if c != null and str(c.gender) == "f" else "m"
	var body := "body_%s" % gender
	var head := "head_%s" % gender
	var style := str(pal.get("style", "crop"))
	if style not in (_map.get("hair_styles", ["crop"]) as Array):
		style = "crop"
	var hair := "hair_%s" % style
	var outfit := str((_map.get("defaults", {}) as Dictionary).get("outfit", "outfit_light_inf"))
	var weapon := str((_map.get("defaults", {}) as Dictionary).get("weapon", "weapon_sword"))
	var signs: Array = []
	var scale := 1.0
	var compose := ""
	if enemy:
		var et: Dictionary = _map.get("enemy_templates", {})
		var key := tmpl if tmpl != "" else "bandit"
		if not et.has(key):
			key = "bandit"
		var row: Dictionary = et.get(key, {})
		outfit = str(row.get("outfit", "outfit_bandit_bandit"))
		weapon = str(row.get("weapon", "weapon_axe"))
		signs = row.get("signs", []) if typeof(row.get("signs")) == TYPE_ARRAY else []
		scale = float(row.get("scale", 1.0))
		compose = str(row.get("compose", ""))
	else:
		var jid := str(c.job_id) if c != null else "light_inf"
		var jobs: Dictionary = _map.get("jobs", {})
		var row2: Dictionary = jobs.get(jid, {}) if jobs.has(jid) else {}
		if c != null and bool(c.is_leader):
			row2 = _map.get("leader_job_override", row2)
		if not row2.is_empty():
			outfit = str(row2.get("outfit", outfit))
			weapon = str(row2.get("weapon", weapon))
			signs = row2.get("signs", []) if typeof(row2.get("signs")) == TYPE_ARRAY else []
			scale = float(row2.get("scale", 1.0))
			compose = str(row2.get("compose", ""))
			if str(row2.get("body", "")) == "heavy":
				body = "body_heavy"
	# Organic compose_* = full figure (head+hair+body). No extra head/hair modules —
	# source silhouette already carries hair; layering hair_* caused flat-hat float.
	if compose != "":
		return {
			"compose": compose,
			"body": "",
			"head": "",
			"hair": "",
			"outfit": "",
			"weapon": weapon,
			"signs": signs,
			"scale": scale,
			"gender": gender,
		}
	return {
		"body": body,
		"head": head,
		"hair": hair,
		"outfit": outfit,
		"weapon": weapon,
		"signs": signs,
		"scale": scale,
		"gender": gender,
	}


static func _estimate_tris(parts: Dictionary) -> int:
	_ensure_map()
	var man_path := str(_map.get("kit_manifest", "res://assets/models/board/board_figures_v1.json"))
	var man = _load_json(man_path) if ResourceLoader.exists(man_path) else {}
	var plist: Dictionary = man.get("parts", {}) if typeof(man) == TYPE_DICTIONARY else {}
	var total := 0
	if str(parts.get("compose", "")) != "":
		var cn := str(parts.get("compose"))
		if plist.has(cn):
			total += int((plist[cn] as Dictionary).get("tris", 5500))
		else:
			total += 5500
		var wn2 := str(parts.get("weapon", ""))
		if wn2 != "" and plist.has(wn2):
			total += int((plist[wn2] as Dictionary).get("tris", 200))
		for s in parts.get("signs", []):
			if plist.has(str(s)):
				total += int((plist[str(s)] as Dictionary).get("tris", 100))
		return total
	for k in ["body", "head", "hair", "outfit", "weapon"]:
		var pname := str(parts.get(k, ""))
		if pname == "":
			continue
		if plist.has(pname):
			total += int((plist[pname] as Dictionary).get("tris", 400))
		else:
			total += 400
	for s in parts.get("signs", []):
		if plist.has(str(s)):
			total += int((plist[str(s)] as Dictionary).get("tris", 100))
	return total


static func _assemble_kit(body: Node3D, parts: Dictionary, pal: Dictionary, face: float, enemy: bool) -> void:
	_ensure_kit()
	var names: Array[String] = []
	var compose_n := str(parts.get("compose", ""))
	if compose_n != "":
		names.append(compose_n)
		var wn := str(parts.get("weapon", ""))
		if wn != "":
			names.append(wn)
		for s in parts.get("signs", []):
			names.append(str(s))
	else:
		for k in ["body", "head", "hair", "outfit", "weapon"]:
			var n := str(parts.get(k, ""))
			if n != "":
				names.append(n)
		for s in parts.get("signs", []):
			names.append(str(s))
	var merged := _merge_parts(names)
	if merged == null:
		push_warning("CKBoardFigure: merge failed for %s" % str(names))
		return
	var mi := MeshInstance3D.new()
	mi.name = "Figure"
	mi.mesh = merged
	mi.material_override = _palette_mat(pal, face, enemy)
	# Chin +8° for board camera (§3.2) — tilt whole figure slightly; head already in mesh.
	mi.rotation_degrees = Vector3(-8.0, 0, 0)
	body.add_child(mi)
	body.set_meta("ck_kit_parts", names)
	body.set_meta("ck_tris", _estimate_tris(parts))


static func _merge_parts(names: Array) -> ArrayMesh:
	_ensure_kit()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for n in names:
		var mesh: Mesh = _kit_meshes.get(str(n)) as Mesh
		if mesh == null:
			continue
		var sc := 0
		# Headless dummy renderer can yield null RID briefly; guard surface queries.
		if mesh is ArrayMesh:
			sc = (mesh as ArrayMesh).get_surface_count()
		else:
			sc = mesh.get_surface_count()
		if sc <= 0:
			continue
		for si in range(sc):
			var arr := mesh.surface_get_arrays(si)
			if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				# Non-indexed: emit sequential tris
				var i := 0
				while i + 2 < verts.size():
					for k in 3:
						var vi := i + k
						if norms.size() > vi:
							st.set_normal(norms[vi])
						if cols.size() > vi:
							st.set_color(cols[vi])
						else:
							st.set_color(Color(3.0 / 255.0, 1.0, 0.0, 1.0))
						st.add_vertex(verts[vi])
					i += 3
					any = true
			else:
				for ii in idx:
					var vi2 := int(ii)
					if norms.size() > vi2:
						st.set_normal(norms[vi2])
					if cols.size() > vi2:
						st.set_color(cols[vi2])
					else:
						st.set_color(Color(3.0 / 255.0, 1.0, 0.0, 1.0))
					st.add_vertex(verts[vi2])
					any = true
	if not any:
		return null
	st.generate_normals()
	return st.commit()


static func _palette_mat(pal: Dictionary, face: float, enemy: bool) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _sh()
	var arr: Array = []
	arr.resize(20)
	for i in 20:
		arr[i] = Color(0.5, 0.5, 0.5, 1.0)
	for i in PALETTE_KEYS.size():
		var k: String = PALETTE_KEYS[i]
		var col: Color = pal.get(k, _default_slot(k, enemy)) as Color
		if not (col is Color):
			col = _hex_color(col, _default_slot(k, enemy))
		arr[i] = col
	sm.set_shader_parameter("palette", arr)
	sm.set_shader_parameter("face", face)
	sm.set_shader_parameter("use_albedo", 0.0)
	sm.set_shader_parameter("rim_col", UIKit.DANGER if enemy else UIKit.ACCENT)
	var coat: Color = pal.get("coat", Color(0.5, 0.5, 0.5)) as Color
	var lum := 0.2126 * coat.r + 0.7152 * coat.g + 0.0722 * coat.b
	var rim := 0.85 if enemy or lum < 0.36 else 0.55
	sm.set_shader_parameter("rim_amt", rim)
	return sm


static func _default_slot(k: String, enemy: bool) -> Color:
	match k:
		"hair":
			return Color(0.25, 0.20, 0.18)
		"skin":
			return Color(0.78, 0.62, 0.52)
		"eye":
			return Color(0.165, 0.184, 0.220)  # #2A2F38
		"coat":
			return Color(0.376, 0.416, 0.467) if enemy else Color(0.55, 0.58, 0.62)  # enemy #606A77
		"coat_dark":
			return Color(0.110, 0.137, 0.188)  # #1C2330
		"apron":
			return Color(0.216, 0.267, 0.337) if enemy else Color(0.45, 0.42, 0.40)
		"sash":
			return Color(0.45, 0.40, 0.55)
		"metal":
			return Color(0.604, 0.643, 0.698) if enemy else Color(0.788, 0.827, 0.871)  # gun / frost
		"blade":
			return Color(0.863, 0.898, 0.933)
		"house", "crest":
			return UIKit.DANGER if enemy else UIKit.ACCENT
		"cape":
			return Color(0.784, 0.337, 0.306) if enemy else UIKit.ACCENT  # #C8564E
		"trousers":
			return Color(0.125, 0.145, 0.176) if enemy else Color(0.133, 0.161, 0.212)
		"boots":
			return Color(0.125, 0.145, 0.176)
		"leather":
			return Color(0.180, 0.192, 0.220)
		"wood":
			return Color(0.478, 0.435, 0.400)
		"accent":
			return UIKit.DANGER if enemy else Color(0.369, 0.878, 0.710)  # mint
		_:
			return Color(0.5, 0.5, 0.5)


# ----- palette / protection (§3.5) -----

static func palette_for(c, team: String, tmpl: String = "") -> Dictionary:
	var enemy := str(team) == "enemy"
	var key := _pal_key(c, team, tmpl)
	if _pal_cache.has(key):
		return (_pal_cache[key] as Dictionary).duplicate(true)
	var pal := _sample_portrait(c)
	# Fill fixed slots
	pal["eye"] = Color(0.165, 0.184, 0.220)
	pal["blade"] = Color(0.863, 0.898, 0.933)
	pal["wood"] = Color(0.478, 0.435, 0.400)
	pal["leather"] = Color(0.180, 0.192, 0.220)
	pal["boots"] = Color(0.125, 0.145, 0.176)
	if enemy:
		pal["coat"] = _enemy_coat()
		pal["coat_dark"] = Color(0.110, 0.137, 0.188)
		pal["apron"] = Color(0.216, 0.267, 0.337)
		pal["trousers"] = Color(0.125, 0.145, 0.176)
		pal["metal"] = Color(0.604, 0.643, 0.698)
		pal["house"] = UIKit.DANGER
		pal["crest"] = UIKit.DANGER
		pal["cape"] = Color(0.784, 0.337, 0.306)
		pal["accent"] = UIKit.DANGER
		pal["sash"] = UIKit.DANGER.darkened(0.15)
		_lift_enemy(pal)
	else:
		var house: Color = UnitArt.house_color() if Engine.get_main_loop() else UIKit.ACCENT
		# Soft house: sat×0.80, value×0.92 (§3.5)
		var soft := Color.from_hsv(house.h, house.s * 0.80, house.v * 0.92)
		pal["house"] = soft
		pal["crest"] = house
		pal["cape"] = soft
		pal["accent"] = Color(0.369, 0.878, 0.710)
		pal["trousers"] = Color(0.133, 0.161, 0.212)
		if not pal.has("metal") or _chroma(pal["metal"]) < 0.02:
			pal["metal"] = Color(0.788, 0.827, 0.871)
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


static func _apply_plate_row(out: Dictionary, row: Dictionary) -> void:
	if row.is_empty():
		return
	out["hair"] = _hex_color(row.get("hair"), out["hair"])
	out["skin"] = _hex_color(row.get("skin"), out["skin"])
	out["coat"] = _hex_color(row.get("coat"), out["coat"])
	out["coat_dark"] = _hex_color(row.get("coat_dark"), out.get("coat_dark", Color(0.11, 0.14, 0.19)))
	out["lining"] = out["coat_dark"]  # alias
	if row.get("sash") != null:
		out["sash"] = _hex_color(row.get("sash"), out.get("sash", Color(0.45, 0.4, 0.55)))
	if row.get("apron") != null:
		out["apron"] = _hex_color(row.get("apron"), out.get("apron", Color(0.45, 0.42, 0.40)))
	if row.get("metal") != null:
		out["metal"] = _hex_color(row.get("metal"), out.get("metal", Color(0.79, 0.83, 0.87)))
	var st := str(row.get("style", out.get("style", "crop")))
	if st in ["bob", "crop", "crown", "long", "messy", "pony", "swept", "tied"]:
		out["style"] = st
	out["plate_stem"] = str(row.get("stem", out.get("plate_stem", "")))


static func _sample_portrait(c) -> Dictionary:
	var out := {
		"hair": Color(0.25, 0.20, 0.18),
		"skin": Color(0.78, 0.62, 0.52),
		"coat": Color(0.55, 0.58, 0.62),
		"coat_dark": Color(0.18, 0.16, 0.18),
		"lining": Color(0.18, 0.16, 0.18),
		"sash": Color(0.45, 0.48, 0.58),
		"apron": Color(0.45, 0.42, 0.40),
		"trousers": Color(0.16, 0.16, 0.18),
		"boots": Color(0.12, 0.11, 0.11),
		"metal": Color(0.78, 0.82, 0.88),
		"style": "crop",
		"plate_stem": "",
	}
	if c == null:
		return out
	if c.has_method("ensure_genome"):
		c.ensure_genome()
	if Engine.get_main_loop() != null and c.has_method("ensure_genome"):
		var ph: Dictionary = CKGenome.phenotype(c)
		if ph.has("hair_color"):
			out["hair"] = ph["hair_color"]
		if ph.has("skin_color"):
			out["skin"] = ph["skin_color"]
		out["style"] = CKPortraitDoll._style(c)
	var stem := ""
	if c != null and c.has_meta("ck_plate_stem"):
		stem = str(c.get_meta("ck_plate_stem"))
	if stem == "":
		var pack: Dictionary = CKPortraitBank.try_texture(c, "small")
		stem = str(pack.get("stem", ""))
		if c != null and stem != "":
			c.set_meta("ck_plate_stem", stem)
	out["plate_stem"] = stem
	var row := palette_row_for_stem(stem)
	if not row.is_empty():
		_apply_plate_row(out, row)
		return out
	return out


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _enemy_coat() -> Color:
	return Color(0.376, 0.416, 0.467)  # #606A77 prototype


static func _lift_enemy(pal: Dictionary) -> void:
	pal["coat"] = _lift_lum(pal["coat"], 0.40)
	for k in ["apron", "trousers", "boots", "leather"]:
		if pal.has(k):
			pal[k] = _lift_lum(pal[k], 0.26)
	pal["coat_dark"] = _lift_lum(pal["coat_dark"], 0.12)


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


## §3.5 faction gamut guards.
static func _protect(pal: Dictionary, enemy: bool) -> void:
	# Board hair lift: near-black hair vanishes on board/cards — raise luma floor.
	var hc: Color = pal.get("hair", Color(0.2, 0.15, 0.12))
	var hluma := 0.2126 * hc.r + 0.7152 * hc.g + 0.0722 * hc.b
	if hluma < 0.14:
		var scale: float = 0.22 / maxf(0.001, hluma)
		pal["hair"] = Color(min(1.0, hc.r * scale), min(1.0, hc.g * scale), min(1.0, hc.b * scale))
	# board hair lift end
	# Rule 1: head/torso separation — if hair/skin vs coat ΔE < 5, deepen coat_dark as collar.
	if not enemy:
		var head_c: Color = pal.get("hair", pal.get("skin", Color.WHITE))
		var torso: Color = pal.get("coat", Color.GRAY)
		if _approx_de(head_c, torso) < 5.0:
			pal["coat_dark"] = pal.get("coat_dark", Color(0.11, 0.14, 0.19)).darkened(0.15)
	# Rule 2: house rim if luminance gap to coat < 0.15 — handled by darker house soft already;
	# keep flag for shader consumers via meta not needed at palette level.
	if enemy:
		for k in ["coat", "coat_dark", "apron", "sash", "trousers", "boots", "cape", "house", "crest", "accent", "metal"]:
			if not pal.has(k):
				continue
			var col: Color = pal[k]
			if k in ["hair", "skin"]:
				continue
			if _in_ally_gamut(col):
				pal[k] = Color(0.16, 0.14, 0.15) if k != "coat" else _enemy_coat()
	else:
		for k in ["house", "cape", "accent"]:
			if not pal.has(k):
				continue
			var col2: Color = pal[k]
			if _in_enemy_gamut(col2):
				# frost silver; crest keeps small player colour
				if k == "accent":
					pal[k] = Color(0.369, 0.878, 0.710)
				else:
					pal[k] = Color(0.788, 0.827, 0.871)


static func _approx_de(a: Color, b: Color) -> float:
	# Cheap RGB distance scaled toward ΔE2000 magnitude for gate thresholds.
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db) * 100.0


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


static func assert_palette_rules(pal: Dictionary, enemy: bool) -> String:
	if enemy:
		for k in ["coat", "coat_dark", "apron", "sash", "trousers", "boots", "cape", "house", "accent"]:
			if pal.has(k) and _in_ally_gamut(pal[k]):
				return "enemy slot %s in ally gamut" % k
	else:
		for k in ["house", "cape", "accent"]:
			if pal.has(k) and _in_enemy_gamut(pal[k]):
				return "ally slot %s in enemy gamut" % k
	return ""


# ----- LRU -----

static func _lru_put(h: String, _built: bool) -> void:
	if _lru.has(h):
		_lru_order.erase(h)
	_lru[h] = true
	_lru_order.append(h)
	while _lru_order.size() > CACHE_CAP:
		var old: String = _lru_order.pop_front()
		_lru.erase(old)


# ----- Anim (lightweight P1; P2 re-poses skeleton) -----

static func _make_anim(_root: Node3D) -> AnimationPlayer:
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


# ----- Baked stand-in (replaces capsules when 3D off / low-end) -----

## Facing-right idle stand-in. Uses memory/user cache, else painted humanoid (not capsule).
## Battle boot should call bake_standin_async on a node to upgrade to SubViewport captures.
static func standin_texture(c, team: String, tmpl: String = "") -> Texture2D:
	var pal := palette_for(c, team, tmpl)
	var parts := _parts_for(c, team, tmpl, pal)
	var h := appearance_hash(c, team, tmpl, pal, parts) + "|standin"
	if _standin_mem.has(h):
		return _standin_mem[h]
	var path := "user://board_standin/%s.png" % h.sha256_text().substr(0, 24)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_standin_mem[h] = tex
			return tex
	var fb := _standin_fallback(pal, team)
	_standin_mem[h] = fb
	return fb


static func standin_hash(c, team: String, tmpl: String = "") -> String:
	var pal := palette_for(c, team, tmpl)
	var parts := _parts_for(c, team, tmpl, pal)
	return appearance_hash(c, team, tmpl, pal, parts) + "|standin"


## Store a baked ImageTexture under the stand-in hash (from async SubViewport bake).
static func store_standin(h: String, tex: Texture2D) -> void:
	if tex == null or h == "":
		return
	_standin_mem[h] = tex
	DirAccess.make_dir_recursive_absolute("user://board_standin")
	var img: Image = tex.get_image() if tex is ImageTexture else null
	if img != null:
		img.save_png("user://board_standin/%s.png" % h.sha256_text().substr(0, 24))


static func _standin_fallback(pal: Dictionary, team: String) -> ImageTexture:
	var img := Image.create(STANDIN_W, STANDIN_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var coat: Color = pal.get("coat", Color(0.5, 0.5, 0.5))
	var skin: Color = pal.get("skin", Color(0.78, 0.62, 0.52))
	var hair: Color = pal.get("hair", Color(0.25, 0.2, 0.18))
	var cx := STANDIN_W * 0.5
	# Body capsule replaced by soft silhouette blocks (not the old grey pill).
	_fill_ellipse(img, cx, STANDIN_H * 0.62, STANDIN_W * 0.22, STANDIN_H * 0.28, coat)
	_fill_ellipse(img, cx, STANDIN_H * 0.28, STANDIN_W * 0.16, STANDIN_H * 0.14, skin)
	_fill_ellipse(img, cx, STANDIN_H * 0.18, STANDIN_W * 0.17, STANDIN_H * 0.10, hair)
	var rim := UIKit.ACCENT if team != "enemy" else UIKit.DANGER
	# simple feet
	_fill_ellipse(img, cx - 10, STANDIN_H * 0.90, 10, 6, pal.get("boots", Color(0.12, 0.11, 0.11)))
	_fill_ellipse(img, cx + 10, STANDIN_H * 0.90, 10, 6, pal.get("boots", Color(0.12, 0.11, 0.11)))
	# rim pixels
	for x in range(STANDIN_W):
		img.set_pixel(x, STANDIN_H - 1, Color(rim.r, rim.g, rim.b, 0.6))
	return ImageTexture.create_from_image(img)


static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(cy - ry - 1)), mini(h, int(cy + ry + 2))):
		for x in range(maxi(0, int(cx - rx - 1)), mini(w, int(cx + rx + 2))):
			var nx := (x - cx) / rx
			var ny := (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, col)
