class_name CKBoardFigure
extends RefCounted
## Formal modular board figures (docs/design/pawn-redesign-opus.md §3 / §5 / 附录 A/B).
## Board figures: scale 演出 UnitModel GLBs onto the board + plate_palette shader.
## Prefer board/pathc_ship/<stem>.glb, then units/*.glb (UnitModel.resolve). farm_cast / kit compose only if resolve fails.
## Path C LOOK (user-approved 2026-10-16): data/board_figure_pathc.json → docs/.../pathc_native/ (not loaded at runtime; export budget).
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
	var unit: Node3D = UnitModel.instantiate(c, team, tmpl, true)
	if unit != null:
		unit.name = "Unit"
		root.add_child(unit)
		var ship := bool(unit.get_meta("ck_pathc_ship", false))
		if not ship:
			_ensure_unit_hair(unit, c, team)
		_ground_and_fit(unit)
		if ship:
			# Path C ship piece: baked master albedo (no palette/decal/extras) + faction rim + job weapon.
			root.set_meta("ck_pathc_ship", true)
			_apply_ship_rim(unit, enemy)
			_attach_ship_weapon(unit, parts, pal, face, enemy)
		else:
			_apply_board_palette(unit, pal, face, enemy)
			_apply_face_decal(unit, c, team, tmpl)
			_attach_outfit_extras(unit, c, team, pal)
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
	# Board layer always owns idle/attack clips (UnitModel GLBs may lack them).
	var ap := _make_anim(root)
	root.add_child(ap)
	_lru_put(h, true)
	return root



const SHIP_SHADER_PATH := "res://shaders/board_figure_ship.gdshader"
static var _ship_shader: Shader

## Ship pieces keep their albedo; enemies get the red faction rim (UIKit.DANGER) like the kit shader.
static func _apply_ship_rim(n: Node, enemy: bool) -> void:
	if _ship_shader == null:
		_ship_shader = load(SHIP_SHADER_PATH) as Shader
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and not str(mi.name).begins_with("ShipWeapon"):
			for si in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(si)
				var tex: Texture2D = null
				if m is BaseMaterial3D:
					tex = (m as BaseMaterial3D).albedo_texture
				if tex == null:
					continue
				var sm := ShaderMaterial.new()
				sm.shader = _ship_shader
				sm.set_shader_parameter("albedo_tex", tex)
				sm.set_shader_parameter("rim_col", UIKit.DANGER if enemy else UIKit.ACCENT)
				sm.set_shader_parameter("rim_amt", 1.6 if enemy else 0.0)
				mi.set_surface_override_material(si, sm)
	for ch in n.get_children():
		_apply_ship_rim(ch, enemy)


## Job weapon from the board kit, moved from the kit hand to the ship piece's measured hand
## (board_figures.json pathc_ship.hands, GLB/Godot units). Bow goes to the left hand.
static func _attach_ship_weapon(unit: Node3D, parts: Dictionary, pal: Dictionary, face: float, enemy: bool) -> void:
	var wn := str(parts.get("weapon", ""))
	if wn == "":
		return
	_ensure_kit()
	_ensure_map()
	var mesh: Mesh = _kit_meshes.get(wn, null)
	if mesh == null:
		return
	var cfg: Dictionary = _map.get("pathc_ship", {})
	var stem := str(unit.get_meta("ck_load_path", "")).get_file().get_basename()
	var hands: Dictionary = (cfg.get("hands", {}) as Dictionary).get(stem, {})
	if hands.is_empty():
		return
	var left := wn == "weapon_bow"
	var hv: Array = hands.get("l" if left else "r", [])
	if hv.size() < 3:
		return
	var kit_hand: Array = (cfg.get("kit_hand_l" if left else "kit_hand_r", [0.33 if left else -0.33, 0.86, 0.04]) as Array)
	var mi := MeshInstance3D.new()
	mi.name = "ShipWeapon"
	mi.mesh = mesh
	mi.position = Vector3(float(hv[0]) - float(kit_hand[0]), float(hv[1]) - float(kit_hand[1]), float(hv[2]) - float(kit_hand[2]))
	var wm := _palette_mat(pal, face, enemy)
	wm.set_shader_parameter("rim_amt", 0.85 if enemy else 0.0)
	mi.material_override = wm
	unit.add_child(mi)
	unit.set_meta("ck_ship_weapon", wn)


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
			var board_tex: Texture2D = _board_albedo(mi)
			for si in mi.mesh.get_surface_count():
				var tex: Texture2D = _extract_albedo(mi, si)
				var sm := _palette_mat(pal, face, enemy)
				sm.set_shader_parameter("force_slot", -1.0)
				var mat_name := _surface_mat_name(mi, si)
				var named_slot := _force_slot_for(nlow, mat_name)
				if "weapon" in nlow or mat_name.begins_with("weapon"):
					sm.set_shader_parameter("use_albedo", 0.0)
					sm.set_shader_parameter("force_slot", 8.0)
				elif hair_mesh or "hair" in mat_name:
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
				# P1: cleaned atlas + soft portrait grade (keeps painted face detail,
				# kills mip-bleed blotches and hard slot edges).
				if board_tex != null and float(sm.get_shader_parameter("force_slot")) < 0.0:
					sm.set_shader_parameter("use_albedo", 1.0)
					sm.set_shader_parameter("albedo_tex", board_tex)
					sm.set_shader_parameter("grade_mode", 1.0)
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


static func _board_albedo(mi: MeshInstance3D) -> Texture2D:
	var mp := _model_filename(mi)
	if mp == "" or not mp.ends_with(".glb"):
		return null
	var ap := "res://assets/models/units/" + mp.replace(".glb", "__albedo_board.png")
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
			return Color(0.165, 0.184, 0.220)  # eye-dark
		"coat":
			return Color(0.376, 0.416, 0.467) if enemy else Color(0.55, 0.58, 0.62)  # enemy-coat
		"coat_dark":
			return Color(0.110, 0.137, 0.188)  # coat-dark
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
			return Color(0.784, 0.337, 0.306) if enemy else UIKit.ACCENT  # cape-coral
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
		# #310 P1: bandit portrait (art/portraits/bandit.webp) wears a brown hood/coat
		# over dark leather — match it instead of generic slate. Hue ~20° stays outside
		# ally gamut; red rim keeps faction read.
		if tmpl.begins_with("bandit") or tmpl == "":
			pal["coat"] = Color8(118, 80, 58)
			pal["coat_dark"] = Color8(52, 34, 26)
			pal["hair"] = Color8(64, 40, 28)
			pal["skin"] = Color8(178, 137, 111)
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
		if not pal.has("coat") or (_chroma(pal["coat"]) < 0.05 and not bool(pal.get("coat_from_portrait", false))):
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
	# Named cast (non-leader): palette straight from their own v8 bust plate.
	if not bool(c.is_leader) and str(c.cast_key) != "":
		var pimg := decal_portrait_image(c, "player", "")
		if pimg != null:
			_sample_from_image(out, pimg)
			out["plate_stem"] = "cast_" + str(c.cast_key)
			return out
	var row := palette_row_for_stem(stem)
	if not row.is_empty():
		_apply_plate_row(out, row)
	# Leader: garment colours from the portrait the player actually sees (plate rows can
	# key on a scarf/background and go navy while the painted coat is grey).
	if bool(c.is_leader):
		var limg := decal_portrait_image(c, "player", "")
		if limg != null:
			var tmp := out.duplicate()
			_sample_from_image(tmp, limg)
			for k in ["coat", "coat_dark"]:
				if tmp.has(k):
					var cc: Color = tmp[k]
					# portrait grey reads cool under the board's cyan rim: halve chroma
					var g := (cc.r + cc.g + cc.b) / 3.0
					# neutral grey coat (portrait suit is a true mid grey; any hue here came
					# from background/necklace bleed and reads teal under the cyan rim)
					out[k] = Color(g * 1.01, g, g * 0.99)
			out["coat_from_portrait"] = true
		return out
	if not row.is_empty():
		return out
	return out


static func _sample_from_image(out: Dictionary, img: Image) -> void:
	var sm: Image = img.duplicate()
	sm.resize(48, 60, Image.INTERPOLATE_BILINEAR)
	var skin := Color(0, 0, 0)
	var ns := 0
	var hair := Color(0, 0, 0)
	var nh := 0
	var coat := Color(0, 0, 0)
	var nc := 0
	var dark := Color(0, 0, 0)
	var nd := 0
	var skin_w := 0.0
	var skin_list: Array[Color] = []
	for y in 60:
		for x in range(6, 42):
			var col := sm.get_pixel(x, y)
			var lum := 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
			if y < 33 and _is_skin(col):
				# lit-side weighting: shadowed cheeks/neck dragged pale skins to mauve-grey
				var w := lum * lum * 4.0
				skin += col * w
				ns += 1
				skin_w += w
				skin_list.append(col)
			elif y < 22 and lum < 0.32:
				hair += col
				nh += 1
			elif y > 40:
				if lum < 0.22:
					dark += col
					nd += 1
				else:
					coat += col
					nc += 1
	if ns > 0 and skin_w > 0.0:
		out["skin"] = skin / skin_w
	if skin_list.size() > 6:
		skin_list.sort_custom(func(a, b): return a.get_luminance() > b.get_luminance())
		var acc := Color(0, 0, 0)
		var m := maxi(1, int(skin_list.size() * 0.3))
		for i in m:
			acc += skin_list[i]
		out["skin"] = acc / m
	if nh > 0:
		out["hair"] = hair / nh
	if nc > 0:
		out["coat"] = coat / nc
	if nd > 4:
		out["coat_dark"] = dark / nd
	elif nc > 0:
		out["coat_dark"] = (coat / nc).darkened(0.45)
	for k in ["skin", "hair", "coat", "coat_dark"]:
		if out.has(k):
			var cc: Color = out[k]
			cc.a = 1.0
			out[k] = cc


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _enemy_coat() -> Color:
	return Color(0.376, 0.416, 0.467)  # enemy-coat prototype


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


# ----- #310 P1b: portrait face decal + outfit extras -----

static var _head_cache: Dictionary = {}  # model path -> head box Dictionary
static var _decal_cache: Dictionary = {}  # portrait key -> ImageTexture


static func _find_body_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and str(n.name).to_lower() == "body":
		return n as MeshInstance3D
	for ch in n.get_children():
		var f := _find_body_mesh(ch)
		if f != null:
			return f
	return null


## Head / chest box in Body-mesh local space (bind pose), cached per model.
static func head_box(mi: MeshInstance3D, key: String) -> Dictionary:
	if _head_cache.has(key):
		return _head_cache[key]
	var out := {}
	var aabb := mi.mesh.get_aabb()
	var H := aabb.size.y
	var ytop := aabb.position.y + H
	var ymin := aabb.position.y
	var hx: Array[float] = []
	var hz_max := -1e9
	var hz_min := 1e9
	var xs_min := 1e9
	var xs_max := -1e9
	var chest_z := -1e9
	var neck_z := -1e9
	var verts_all: Array = []
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		verts_all.append(arr[Mesh.ARRAY_VERTEX])
	var sumx := 0.0
	var cnt := 0
	for verts in verts_all:
		for v in (verts as PackedVector3Array):
			if v.y > ytop - 0.125 * H:
				sumx += v.x
				cnt += 1
	var cx := sumx / maxf(1.0, cnt)
	for verts in verts_all:
		for v in (verts as PackedVector3Array):
			var hy := (v.y - ymin) / H
			if hy > 0.885 and hy < 0.97:
				if v.z > hz_max:
					out["nose_x"] = v.x
					out["nose_y"] = v.y
				xs_min = minf(xs_min, v.x)
				xs_max = maxf(xs_max, v.x)
				hz_max = maxf(hz_max, v.z)
				hz_min = minf(hz_min, v.z)
			if absf(v.x - cx) < 0.045 * H:
				if hy > 0.66 and hy < 0.78:
					chest_z = maxf(chest_z, v.z)
				if hy > 0.82 and hy < 0.86:
					neck_z = maxf(neck_z, v.z)
	out["cx"] = cx
	out["H"] = H
	out["ymin"] = ymin
	out["ytop"] = ytop
	out["head_w"] = clampf(xs_max - xs_min, 0.06 * H, 0.16 * H)
	out["head_zmax"] = hz_max
	out["head_zc"] = 0.5 * (hz_max + hz_min)
	out["chest_z"] = chest_z if chest_z > -1e8 else 0.08 * H
	out["neck_z"] = neck_z if neck_z > -1e8 else out["chest_z"]
	# head yaw from nose tip offset (cast rigs often bake a head turn)
	var nx := float(out.get("nose_x", cx))
	var depth := maxf(0.01 * H, hz_max - out["head_zc"])
	out["yaw"] = clampf(atan2(nx - cx, depth), -0.9, 0.9)
	_head_cache[key] = out
	return out


## Portrait the player actually sees for this unit (same mapping as the comparison cards).
static func decal_portrait_image(c, team: String, tmpl: String) -> Image:
	var tex: Texture2D = null
	if str(team) == "enemy":
		for p in ["res://assets/art/portraits/%s.webp" % tmpl, "res://assets/art/portraits/bandit.webp"]:
			if ResourceLoader.exists(p):
				tex = load(p) as Texture2D
				break
	elif c != null and not bool(c.is_leader) and str(c.cast_key) != "":
		var g := "f" if str(c.gender) == "f" else "m"
		var nm: String = {"dengying": "hunter", "militia_a": "spear", "militia_b": "guard"}.get(str(c.cast_key), "")
		var pth := "res://assets/art/portraits/v8_bust_%s_%s.webp" % [g, nm]
		if nm != "" and ResourceLoader.exists(pth):
			tex = load(pth) as Texture2D
	if tex == null and c != null:
		tex = UnitArt.portrait(c, 256, "large")
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _is_skin(col: Color) -> bool:
	var lum := 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
	# warm faces (r>g>b) and pale/cool painted faces (hunter: r≈b>g) both qualify;
	# blue-grey sky / white fur fail on r-g.
	return (col.r - col.g) > 0.03 and (col.r - col.b) > -0.04 and (col.r - col.b) < 0.45 \
		and lum > 0.28 and lum < 0.93


## Crop the face (brow line → chin) from a portrait by skin-row histogram, feather to alpha.
static func face_decal_image(img: Image) -> Image:
	var sw := 96
	var sh := int(round(96.0 * img.get_height() / maxf(1.0, img.get_width())))
	var small: Image = img.duplicate()
	small.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	var rows: Array[int] = []
	var x0s: Array[int] = []
	var x1s: Array[int] = []
	for y in range(int(sh * 0.70)):
		var n := 0
		var a := sw
		var b := -1
		for x in range(int(sw * 0.12), int(sw * 0.88)):
			if _is_skin(small.get_pixel(x, y)):
				n += 1
				a = mini(a, x)
				b = maxi(b, x)
		rows.append(n)
		x0s.append(a)
		x1s.append(b)
	var top := -1
	for y in rows.size():
		if rows[y] >= 4:
			top = y
			break
	if top < 0:
		top = int(sh * 0.16)  # fallback: standard bust framing
	# widest row in the next ~face height = cheekbones
	var best := top
	for y in range(top, mini(rows.size(), top + int(sw * 0.30))):
		if rows[y] > rows[best]:
			best = y
	var fw := float(maxi(8, x1s[best] - x0s[best] + 1))
	var fcx := 0.5 * (x0s[best] + x1s[best])
	# forehead often hidden by fringe: extend crop upward a little, chin ≈ 1.30 × width
	# anchor on the widest skin row (cheekbones, just under the eyes) — robust to
	# fringes/circlets hiding the forehead
	var fy0 := float(best) - fw * 0.62
	var fh := fw * 1.38
	var sc := float(img.get_width()) / sw
	var r := Rect2i(int((fcx - fw * 0.55) * sc), int(fy0 * sc), int(fw * 1.10 * sc), int(fh * sc))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x < 8 or r.size.y < 8:
		return null
	var crop := img.get_region(r)
	crop.resize(96, 120, Image.INTERPOLATE_LANCZOS)
	# Feathered oval alpha; also fade non-skin (hair) texels so the 3D hair stays the hair.
	for y in 120:
		for x in 96:
			var nx := (x - 47.5) / 48.0
			var ny := (y - 62.0) / 62.0
			var d := sqrt(nx * nx + ny * ny)
			var a := clampf((1.0 - d) / 0.28, 0.0, 1.0)
			var col := crop.get_pixel(x, y)
			var lum := 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
			if y < 20 and not _is_skin(col) and lum < 0.30:
				a *= 0.25  # fringe over forehead: let shader hair show
			# portrait hair falling beside the cheek (hunter crop: dark locks on his left):
			# drop it so the 3D hair / skin base shows instead of a painted dark patch
			var sidex := absf(x - 47.5) / 48.0
			if y >= 20 and sidex > 0.40 and not _is_skin(col) and lum < 0.42:
				a *= clampf((0.40 - (sidex - 0.40) * 4.0), 0.0, 0.4)
			col.a = a
			crop.set_pixel(x, y, col)
	crop.generate_mipmaps()
	return crop


static func _apply_face_decal(unit: Node3D, c, team: String, tmpl: String) -> void:
	var mi := _find_body_mesh(unit)
	if mi == null or mi.mesh == null:
		return
	_enlarge_head(unit)
	if str(team) == "enemy":
		# Bandits: no portrait decal (placeholder cartoon) — keep the model's own painted,
		# hood-shadowed face.
		for si0 in mi.mesh.get_surface_count():
			var m0 = mi.get_surface_override_material(si0)
			if m0 is ShaderMaterial:
				(m0 as ShaderMaterial).set_shader_parameter("head_raw", 1.0)
		return
	var mp := str(unit.get_meta("ck_model", ""))
	var hb := head_box(mi, mp)
	var pimg := decal_portrait_image(c, team, tmpl)
	if pimg == null:
		return
	var dk := "%s|%d|%d" % [mp, pimg.get_width(), hash(pimg.get_data().slice(0, 4096))]
	var dtex: ImageTexture = _decal_cache.get(dk)
	if dtex == null:
		var dimg := face_decal_image(pimg)
		if dimg == null:
			return
		dtex = ImageTexture.create_from_image(dimg)
		if _decal_cache.size() > CACHE_CAP:
			_decal_cache.clear()
		_decal_cache[dk] = dtex
	var H: float = hb["H"]
	var hh := 0.125 * H
	var box := Vector4(float(hb["cx"]), float(hb["ytop"]) - 0.16 * hh, float(hb["ytop"]) - 1.02 * hh, 0.088 * H)
	_bake_bind_custom0(mi, mp)
	var clear := 1.0 if (c != null and str(c.cast_key) == "dengying") else 0.0
	var collar := 0.0  # leader collar now cleaned in mesh (cast_leader__board.glb)
	for si1 in mi.mesh.get_surface_count():
		var m1 = mi.get_surface_override_material(si1)
		if m1 is ShaderMaterial:
			(m1 as ShaderMaterial).set_shader_parameter("face_clear", clear)
			(m1 as ShaderMaterial).set_shader_parameter("collar_dark", collar)
	for si in mi.mesh.get_surface_count():
		var m = mi.get_surface_override_material(si)
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("face_tex", dtex)
			(m as ShaderMaterial).set_shader_parameter("face_box", box)
			(m as ShaderMaterial).set_shader_parameter("face_zc", float(hb["head_zc"]))
			(m as ShaderMaterial).set_shader_parameter("face_yaw", float(hb["yaw"]))
			(m as ShaderMaterial).set_shader_parameter("use_face", 1.0)
	unit.set_meta("ck_face_decal", true)


## Captain: suit-style lapels + key necklace (portrait `v8_hero_leader` / leader genome plate).
static var _bind_mesh_cache: Dictionary = {}

const HEAD_SCALE := 1.10  # board read: +10 % head, still within realistic 7.5-head budget


static func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for ch in n.get_children():
		var f := _find_skel(ch)
		if f != null:
			return f
	return null


static func _enlarge_head(unit: Node3D) -> void:
	var sk := _find_skel(unit)
	if sk == null:
		return
	var hi := sk.find_bone("head")
	if hi < 0:
		return
	var rest := sk.get_bone_rest(hi)
	rest.basis = rest.basis.scaled(Vector3.ONE * HEAD_SCALE)
	sk.set_bone_rest(hi, rest)
	sk.set_bone_pose_scale(hi, Vector3.ONE * HEAD_SCALE)
	unit.set_meta("ck_head_scale", HEAD_SCALE)


static func _bone_attach(mi: MeshInstance3D, bone: String, nodes: Array) -> void:
	var parent := mi.get_parent()
	var skel := parent as Skeleton3D
	if skel != null and skel.find_bone(bone) >= 0:
		var ba := BoneAttachment3D.new()
		ba.bone_name = bone
		skel.add_child(ba)
		var bg: Transform3D = skel.get_bone_global_rest(skel.find_bone(bone))
		var off: Transform3D = bg.affine_inverse() * mi.transform
		for m2 in nodes:
			(m2 as Node3D).transform = off
			ba.add_child(m2)
	else:
		for m3 in nodes:
			(m3 as Node3D).transform = mi.transform
			parent.add_child(m3)


static func _slot_mat(pal: Dictionary, col: Color, metal: float, rim: float = 0.3) -> ShaderMaterial:
	var p2 := pal.duplicate()
	p2["coat"] = col
	var m := _palette_mat(p2, 1.0, false)
	m.set_shader_parameter("force_slot", 3.0)
	m.set_shader_parameter("force_metal", metal)
	m.set_shader_parameter("rim_amt", rim)
	return m


## Lumpy ellipse tube (fur roll / circlet). tilt_y: front-back height offset.
static func _add_ring(st: SurfaceTool, c: Vector3, rx: float, rz: float, tube: float, segs: int, tsegs: int, lump: float, front_dy: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 310
	var bumps: Array[float] = []
	for i in segs * tsegs:
		bumps.append(1.0 + lump * (rng.randf() * 2.0 - 1.0))
	for i in segs:
		for j in tsegs:
			var quad := []
			for di in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var ii: int = (i + int(di[0])) % segs
				var jj: int = (j + int(di[1])) % tsegs
				var a: float = ii * TAU / segs
				var b: float = jj * TAU / tsegs
				var rr := tube * bumps[ii * tsegs + jj]
				var ctr := c + Vector3(sin(a) * rx, front_dy * cos(a), cos(a) * rz)
				var outw := Vector3(sin(a), 0, cos(a))
				var nrm := (outw * cos(b) + Vector3.UP * sin(b)).normalized()
				quad.append([ctr + nrm * rr, nrm])
			for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
				st.set_normal(quad[idx][1])
				st.add_vertex(quad[idx][0])


## Flattened dome (armour plate), opening downward-outward.
## Angular ice-armour shard: kite-shaped plate with a raised keel, flat-shaded facets,
## tipped outward/down over the shoulder.
static func _add_shard(st: SurfaceTool, c: Vector3, w: float, h: float, keel: float, side: float, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var tilt := Basis(Vector3(0, 0, 1), -side * 0.55)
	var rim: Array[Vector3] = []
	var n := 7
	for i in n:
		var a := TAU * i / n
		var rr := 1.0 + 0.22 * (rng.randf() * 2.0 - 1.0)
		# pointed outer tip
		if i == 0:
			rr = 1.45
		rim.append(Vector3(cos(a) * w * 0.5 * rr * side, sin(a) * h * 0.30 * rr, sin(a) * h * 0.5 * rr))
	var top := Vector3(0, keel, 0)
	var bot := Vector3(0, -keel * 0.35, 0)
	for i in n:
		var a0: Vector3 = tilt * rim[i] + c
		var a1: Vector3 = tilt * rim[(i + 1) % n] + c
		for tri in [[tilt * top + c, a0, a1], [tilt * bot + c, a1, a0]]:
			var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in [tri[0], tri[1], tri[2], tri[0], tri[2], tri[1]]:
				st.set_normal(nrm)
				st.add_vertex(v)


## Tapered flat-ish ribbon lock through 3 points, thickness for volume.
static func _add_lock(st: SurfaceTool, pts: Array, w0: float, w1: float, outw: Vector3) -> void:
	var side := outw.cross(Vector3.UP).normalized()
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var wa := lerpf(w0, w1, float(k) / (pts.size() - 1))
		var wb := lerpf(w0, w1, float(k + 1) / (pts.size() - 1))
		var th := outw * 0.008 * (1.0 - float(k) / pts.size())
		var q := [a - side * wa, a + side * wa, b + side * wb, b - side * wb]
		for off in [Vector3.ZERO, -outw * 0.01]:
			var nrm := outw if off == Vector3.ZERO else -outw
			for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
				st.set_normal(nrm)
				st.add_vertex(q[idx] + off + th)


## Hair card ribbon with UVs (u across, v root→tip); twist rotates the card plane.
static func _add_card(st: SurfaceTool, pts: Array, w: float, outw: Vector3, twist: float) -> void:
	var side := outw.cross(Vector3.UP).normalized()
	side = (side * cos(twist) + outw * sin(twist)).normalized()
	var nrm := side.cross(Vector3.DOWN).normalized()
	var n := pts.size()
	for k in n - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var va := float(k) / (n - 1)
		var vb := float(k + 1) / (n - 1)
		var q := [[a - side * w * 0.5, Vector2(0, va)], [a + side * w * 0.5, Vector2(1, va)],
			[b + side * w * 0.5, Vector2(1, vb)], [b - side * w * 0.5, Vector2(0, vb)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(q[idx][1])
			st.add_vertex(q[idx][0])


static func _add_dome(st: SurfaceTool, c: Vector3, r: float, ry: float, segs: int) -> void:
	for i in segs:
		for j in segs / 2:
			var quad := []
			for di in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var a: float = (i + int(di[0])) * TAU / segs
				var b: float = (j + int(di[1])) * (PI * 0.5) / (segs / 2)
				var nrm := Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b))
				quad.append([c + Vector3(nrm.x * r, nrm.y * ry, nrm.z * r), nrm])
			for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
				st.set_normal(quad[idx][1])
				st.add_vertex(quad[idx][0])


## Hunter (v8_bust_m_hunter): white fur collar, silver circlet w/ brow jewel, ice-armour pauldrons.
static func _attach_hunter_extras(unit: Node3D, mi: MeshInstance3D, pal: Dictionary) -> void:
	var hb := head_box(mi, str(unit.get_meta("ck_model", "")))
	var H: float = hb["H"]
	var y0: float = hb["ymin"]
	var cx: float = hb["cx"]
	var nz: float = hb["neck_z"]
	var hzc: float = hb["head_zc"]
	# fur collar
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_ring(st, Vector3(cx, y0 + 0.830 * H, hzc), 0.082 * H, 0.070 * H, 0.024 * H, 26, 7, 0.45, -0.010 * H)
	_add_ring(st, Vector3(cx, y0 + 0.808 * H, hzc), 0.100 * H, 0.084 * H, 0.020 * H, 26, 6, 0.45, -0.012 * H)
	var fur := MeshInstance3D.new()
	fur.name = "FurCollarExtra"
	fur.mesh = st.commit()
	fur.material_override = _slot_mat(pal, Color8(232, 236, 242), 0.0, 0.15)
	# circlet (head bone)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hr: float = float(hb["head_w"]) * 0.36
	var cy := float(hb["ytop"]) - 0.024 * H
	_add_ring(st2, Vector3(cx, cy, hzc + 0.004 * H), hr, hr * 1.08, 0.0035 * H, 28, 4, 0.0, -0.012 * H)
	var gem_c := Vector3(cx, cy - 0.010 * H, hzc + hr * 1.08 + 0.002 * H)
	_add_dome(st2, gem_c, 0.006 * H, 0.009 * H, 8)
	var circ := MeshInstance3D.new()
	circ.name = "CircletExtra"
	circ.mesh = st2.commit()
	circ.material_override = _slot_mat(pal, Color8(214, 222, 235), 1.0, 0.25)
	# ice pauldrons (two stacked plates each side)
	var sx_max := -1e9
	var sx_min := 1e9
	for v in _verts_of(mi):
		var hy := (v.y - y0) / H
		if hy > 0.78 and hy < 0.81:
			sx_max = maxf(sx_max, v.x)
			sx_min = minf(sx_min, v.x)
	var plates: Array = []
	for side in [1.0, -1.0]:
		var sxe := sx_max if side > 0.0 else sx_min
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		# outside the fur roll (outer radius ≈0.12H): sit on the shoulder cap, proud of the fur
		var pc := Vector3(cx + side * maxf(absf(sxe - cx) - 0.004 * H, 0.128 * H), y0 + 0.792 * H, hzc + 0.012 * H)
		# three overlapping faceted shards stepping down the shoulder (ice lamellae)
		for k in 3:
			var c3 := pc + Vector3(side * (0.012 * k) * H, -0.026 * k * H, 0.004 * H * k)
			_add_shard(st3, c3, 0.072 * H - 0.006 * k * H, 0.050 * H, 0.020 * H, side, 310 + k + (0 if side > 0.0 else 7))
		var pm := MeshInstance3D.new()
		pm.name = "IcePauldronExtra"
		pm.mesh = st3.commit()
		var im := _slot_mat(pal, Color8(196, 220, 240), 1.0, 0.70)
		im.set_shader_parameter("rim_col", Color(0.92, 0.97, 1.0))  # frosty fresnel edge
		im.set_shader_parameter("shadow_mul", Vector3(0.50, 0.62, 0.80))  # cold blue in shade
		pm.material_override = im
		plates.append([pm, "upper_arm.L" if side > 0.0 else "upper_arm.R"])
	# long voluminous hair (portrait: blue-black, past the shoulders, side locks framing face)
	var st4 := SurfaceTool.new()
	st4.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hcx := cx
	var hcy := float(hb["ytop"]) - 0.060 * H
	var hrad: float = float(hb["head_w"]) * 0.40
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3101
	# crown volume shell (low, so the circlet sits on top of it)
	_add_dome(st4, Vector3(hcx, hcy + 0.010 * H, hzc - 0.010 * H), hrad * 1.04, 0.058 * H, 14)
	# clumped hair cards (soft-alpha strands) — commit shell first, cards in their own mesh
	var stc := SurfaceTool.new()
	stc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clumps := 20
	for i in clumps:
		var ang := deg_to_rad(lerpf(72.0, 288.0, float(i) / (clumps - 1)) + (rng2.randf() - 0.5) * 16.0)
		var root := Vector3(hcx + sin(ang) * hrad * 0.95, hcy + (0.026 + 0.03 * rng2.randf()) * H, hzc - 0.008 * H + cos(ang) * hrad * 0.95)
		var outw := Vector3(sin(ang), 0, cos(ang))
		var len := 0.25 * H * (0.55 + 0.75 * rng2.randf())  # strong length variation
		var side_v := outw.cross(Vector3.UP).normalized()
		var phase := rng2.randf() * TAU
		var amp := (0.010 + 0.012 * rng2.randf()) * H
		var pts: Array = []
		for k in 6:
			var t := float(k) / 5.0
			var bulge := sin(t * PI) * (0.050 + 0.02 * rng2.randf()) * H  # puff out then fall
			var wave := side_v * sin(t * 3.2 * PI + phase) * amp * t  # light waves toward the tips
			pts.append(root + outw * (0.010 * H + bulge) + Vector3(0, -len * t, 0) + wave)
		var wid := (0.030 + 0.026 * rng2.randf()) * H
		_add_card(stc, pts, wid, outw, (rng2.randf() - 0.5) * 0.5)
		_add_card(stc, pts, wid * 0.75, outw, 0.5 + rng2.randf() * 0.4)
	# crown volume: short lifted clumps on top, swept back
	for i2 in 9:
		var ca := rng2.randf() * TAU
		var cr := hrad * (0.25 + 0.55 * rng2.randf())
		var r1 := Vector3(hcx + sin(ca) * cr, hcy + 0.060 * H, hzc + cos(ca) * cr * 0.8)
		var bw := Vector3(sin(ca) * 0.6, 0.0, -0.8).normalized()
		# lie on the crown: small lift, then roll back/down over the skull
		_add_card(stc, [r1, r1 + Vector3(0, 0.008 * H, 0) + bw * 0.022 * H, r1 + Vector3(0, -0.006 * H, 0) + bw * 0.050 * H], 0.040 * H, Vector3.UP, 0.0)
	# side locks framing the face
	for sgn3 in [-1.0, 1.0]:
		# sit behind the cheek line (was 66°, crossed his left cheek in 3/4 view)
		var ang2 := deg_to_rad(sgn3 * 88.0)
		var r0 := Vector3(hcx + sin(ang2) * hrad * 1.04, hcy + 0.030 * H, hzc + cos(ang2) * hrad * 0.92 - 0.010 * H)
		var ow := Vector3(sin(ang2), 0, cos(ang2) * 0.35).normalized()
		_add_card(stc, [r0, r0 + ow * 0.012 * H + Vector3(0, -0.07 * H, 0), r0 + ow * 0.022 * H + Vector3(0, -0.15 * H, 0.004 * H)], 0.026 * H, ow, 0.0)
	# clump bangs swept to his right (portrait), wide roots
	for f in 4:
		var fa := deg_to_rad(lerpf(-30.0, 26.0, f / 3.0))
		var fr0 := Vector3(hcx + sin(fa) * hrad * 0.85, hcy + 0.058 * H, hzc + cos(fa) * hrad * 0.88)
		var fw := Vector3(sin(fa) * 0.4, 0.15, 1).normalized()
		var sweep := Vector3(-0.022 * H, 0, 0)
		_add_card(stc, [fr0, fr0 + fw * 0.024 * H + Vector3(0, -0.022 * H, 0) + sweep * 0.5, fr0 + fw * 0.030 * H + Vector3(0, -0.050 * H, 0) + sweep], 0.034 * H, fw, 0.0)
	var cards := MeshInstance3D.new()
	cards.name = "HairCardsExtra"
	cards.mesh = stc.commit()
	var hm := ShaderMaterial.new()
	hm.shader = load("res://shaders/board_hair.gdshader") as Shader
	hm.set_shader_parameter("hair_col", (pal.get("hair", Color8(39, 50, 75)) as Color).lightened(0.08))
	hm.set_shader_parameter("rim_col", UIKit.ACCENT)
	cards.material_override = hm
	cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hair := MeshInstance3D.new()
	hair.name = "LongHairExtra"
	hair.mesh = st4.commit()
	var hp := pal.get("hair", Color8(39, 50, 75)) as Color
	hair.material_override = _slot_mat(pal, hp.lightened(0.06), 0.0, 0.35)
	_bone_attach(mi, "chest", [fur])
	_bone_attach(mi, "head", [circ, hair, cards])
	for pr in plates:
		_bone_attach(mi, str(pr[1]), [pr[0]])
	unit.set_meta("ck_outfit_extras", ["fur_collar", "circlet", "ice_pauldrons", "long_hair"])


## Bake bind-pose position + normal.z into CUSTOM0 so the face decal projects in bind
## space and rides the head through skinning/idle anim (VERTEX is post-skin).
static func _bake_bind_custom0(mi: MeshInstance3D, key: String) -> void:
	var overrides: Array = []
	for si in mi.mesh.get_surface_count():
		overrides.append(mi.get_surface_override_material(si))
	var nm: ArrayMesh = _bind_mesh_cache.get(key)
	if nm == null:
		var src := mi.mesh
		nm = ArrayMesh.new()
		for si in src.get_surface_count():
			var arr := src.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var cu := PackedFloat32Array()
			cu.resize(verts.size() * 4)
			for i in verts.size():
				cu[i * 4] = verts[i].x
				cu[i * 4 + 1] = verts[i].y
				cu[i * 4 + 2] = verts[i].z
				cu[i * 4 + 3] = norms[i].z if i < norms.size() else 0.0
			arr[Mesh.ARRAY_CUSTOM0] = cu
			var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			var bs: Array = src.surface_get_blend_shape_arrays(si) if src is ArrayMesh else []
			nm.add_surface_from_arrays(src.surface_get_primitive_type(si), arr, bs, {}, fmt)
			nm.surface_set_material(si, src.surface_get_material(si))
		_bind_mesh_cache[key] = nm
	mi.mesh = nm
	for si in overrides.size():
		mi.set_surface_override_material(si, overrides[si])


static func _attach_outfit_extras(unit: Node3D, c, team: String, pal: Dictionary) -> void:
	if c != null and str(team) != "enemy" and not bool(c.is_leader) and str(c.cast_key) == "dengying":
		var hmi := _find_body_mesh(unit)
		if hmi != null:
			_attach_hunter_extras(unit, hmi, pal)
		return
	if c == null or str(team) == "enemy" or not bool(c.is_leader):
		return
	var mi := _find_body_mesh(unit)
	if mi == null:
		return
	var hb := head_box(mi, str(unit.get_meta("ck_model", "")))
	var H: float = hb["H"]
	var y0: float = hb["ymin"]
	var cx: float = hb["cx"]
	var cz: float = float(hb["chest_z"]) + 0.006 * H
	var nz: float = float(hb["neck_z"]) + 0.004 * H
	var coat: Color = pal.get("coat", Color(0.55, 0.57, 0.62))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Lapel = notched V panel each side (collar → button point), slightly proud of chest.
	for sgn in [-1.0, 1.0]:
		var pts := [
			Vector3(cx + sgn * 0.034 * H, y0 + 0.848 * H, nz),   # 0 collar inner
			Vector3(cx + sgn * 0.068 * H, y0 + 0.842 * H, nz),   # 1 collar outer
			Vector3(cx + sgn * 0.092 * H, y0 + 0.772 * H, cz),   # 2 peak
			Vector3(cx + sgn * 0.074 * H, y0 + 0.756 * H, cz),   # 3 notch
			Vector3(cx + sgn * 0.046 * H, y0 + 0.640 * H, cz),   # 4 lower outer
			Vector3(cx + sgn * 0.040 * H, y0 + 0.790 * H, cz),   # 5 inner edge
			Vector3(cx + sgn * 0.022 * H, y0 + 0.615 * H, cz),   # 6 button
		]
		for pi in pts.size():
			var pp: Vector3 = pts[pi]
			# roll line (inner edge 0-5-6) stands proud; outer edge lies on the coat → real fold
			var lift := 0.020 * H if pi in [0, 5, 6] else 0.006 * H
			pts[pi] = Vector3(pp.x, pp.y, _front_z(mi, pp.x, pp.y, 0.03 * H, pp.z) + lift)
		var tris := [[0, 5, 1], [1, 5, 2], [2, 5, 3], [3, 5, 4], [5, 6, 4]]
		for t in tris:
			var a: Vector3 = pts[t[0]]
			var b: Vector3 = pts[t[1]]
			var d: Vector3 = pts[t[2]]
			if sgn < 0.0:
				var tmp := b
				b = d
				d = tmp
			var nrm := (b - a).cross(d - a).normalized()
			if nrm.z < 0.0:
				nrm = -nrm
			for v in [a, b, d, a, d, b]:  # both windings (shader is cull_back)
				st.set_normal(nrm)
				st.set_color(Color(3.0 / 255.0, 1.0, 0.0))
				st.add_vertex(v)
		# thickness: side walls down to the coat along the lapel outline
		var ring := [0, 1, 2, 3, 4, 6, 5]
		var th := Vector3(0, 0, -0.010 * H)
		for ri in ring.size():
			var p0: Vector3 = pts[ring[ri]]
			var p1: Vector3 = pts[ring[(ri + 1) % ring.size()]]
			var wn: Vector3 = (p1 - p0).cross(Vector3(0, 0, 1)).normalized() * -float(sgn)
			for v3 in [p0, p1, p1 + th, p0, p1 + th, p0 + th, p0, p1 + th, p1, p0, p0 + th, p1 + th]:
				st.set_normal(wn)
				st.set_color(Color(3.0 / 255.0, 0.92, 0.0))  # walls = coat (were the dark "edge")
				st.add_vertex(v3)
		# edge line (stitched roll edge) along the inner + notch edges
		var lip := Vector3(0, 0, 0.0012 * H)
		for e in [[0, 5], [5, 6], [2, 3], [3, 4], [1, 2]]:
			_add_bar(st, pts[e[0]] + lip, pts[e[1]] + lip, 0.0008 * H, 5)
	# dark inner shirt V between lapels (portrait: black high-neck shirt)
	var sv := [Vector3(cx - 0.036 * H, y0 + 0.850 * H, 0), Vector3(cx + 0.036 * H, y0 + 0.850 * H, 0), Vector3(cx, y0 + 0.612 * H, 0)]
	for qi in 3:
		var q: Vector3 = sv[qi]
		sv[qi] = Vector3(q.x, q.y, _front_z(mi, q.x, q.y, 0.03 * H, cz) + 0.006 * H)
	for v2 in [sv[0], sv[1], sv[2], sv[0], sv[2], sv[1]]:
		st.set_normal(Vector3(0, 0, 1))
		st.set_color(Color(4.0 / 255.0, 1.0, 0.0))
		st.add_vertex(v2)
	var lapel := MeshInstance3D.new()
	lapel.name = "LapelExtra"
	lapel.mesh = st.commit()
	var lm := ShaderMaterial.new()
	lm.shader = _sh()
	var lpal := pal.duplicate()  # (unused: lapels use vertex slots)
	lpal["coat"] = coat.lightened(0.10)
	lm = _palette_mat(lpal, float(unit.get_parent().get_meta("ck_face", 1.0)) if unit.get_parent() else 1.0, false)
	lm.set_shader_parameter("force_slot", -1.0)
	lm.set_shader_parameter("use_albedo", 0.0)
	var larr: Array = lm.get_shader_parameter("palette")
	larr[5] = coat.darkened(0.12)  # lapel roll-edge: a shade under the coat, not black
	lm.set_shader_parameter("palette", larr)
	lm.set_shader_parameter("rim_amt", 0.35)
	lapel.material_override = lm
	lapel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Key necklace: V chain + key pendant (metal slot).
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pend := Vector3(cx + 0.004 * H, y0 + 0.700 * H, 0.0)
	pend.z = _front_z(mi, pend.x, pend.y, 0.02 * H, cz) + 0.014 * H
	for sgn2 in [-1.0, 1.0]:
		var top := Vector3(cx + sgn2 * 0.028 * H, y0 + 0.845 * H, 0.0)
		top.z = _front_z(mi, top.x, top.y, 0.02 * H, nz) + 0.010 * H
		_add_bar(st2, top, pend + Vector3(0, 0.014 * H, 0), 0.0018 * H)
	_add_bar(st2, pend + Vector3(0, 0.014 * H, 0), pend - Vector3(0, 0.026 * H, 0), 0.0040 * H)  # key shaft
	_add_bar(st2, pend + Vector3(-0.007 * H, 0.008 * H, 0), pend + Vector3(0.007 * H, 0.008 * H, 0), 0.0045 * H)  # bow
	_add_bar(st2, pend - Vector3(0, 0.022 * H, 0), pend - Vector3(-0.008 * H, 0.022 * H, 0), 0.0028 * H)  # bit
	# Sleeve emblem (portrait: silver compass-star on his left upper arm), front-outer face.
	var best_v := Vector3(-1e9, 0, 0)
	for v in _verts_of(mi):
		var hy := (v.y - y0) / H
		if hy > 0.68 and hy < 0.74 and v.x > cx + 0.10 * H:
			if v.z + 0.5 * v.x > best_v.z + 0.5 * best_v.x:
				best_v = v
	if best_v.x > -1e8:
		var nrm2 := Vector3(0.55, 0, 0.83).normalized()
		var up := Vector3.UP
		var rt := up.cross(nrm2).normalized()
		var ac := best_v + nrm2 * 0.006 * H
		var rr := 0.024 * H
		# dark round backing
		for k3 in 14:
			var b0 := k3 * TAU / 14.0
			var b1 := (k3 + 1) * TAU / 14.0
			var p0 := ac - nrm2 * 0.001 * H + (rt * cos(b0) + up * sin(b0)) * rr * 1.05
			var p1 := ac - nrm2 * 0.001 * H + (rt * cos(b1) + up * sin(b1)) * rr * 1.05
			for vv in [ac - nrm2 * 0.001 * H, p0, p1, ac - nrm2 * 0.001 * H, p1, p0]:
				st2.set_normal(nrm2)
				st2.set_color(Color(4.0 / 255.0, 1.0, 0.0))
				st2.add_vertex(vv)
		# 8-point compass star (4 long + 4 short)
		for k in 8:
			var ang := k * PI * 0.25
			var ln := rr * (0.95 if k % 2 == 0 else 0.55)
			var tip := ac + (rt * cos(ang) + up * sin(ang)) * ln
			var l := ac + (rt * cos(ang - 0.30) + up * sin(ang - 0.30)) * rr * 0.22
			var r2 := ac + (rt * cos(ang + 0.30) + up * sin(ang + 0.30)) * rr * 0.22
			for vv in [ac, tip, r2, ac, r2, tip, ac, l, tip, ac, tip, l]:
				st2.set_normal(nrm2)
				st2.set_color(Color(8.0 / 255.0, 1.0, 0.0, 0.6))
				st2.add_vertex(vv)
	var neck := MeshInstance3D.new()
	neck.name = "KeyNecklaceExtra"
	neck.mesh = st2.commit()
	var nmm := _palette_mat(pal, 1.0, false)
	nmm.set_shader_parameter("force_slot", -1.0)  # vertex slots: 8 silver, 4 band
	nmm.set_shader_parameter("rim_amt", 0.2)
	neck.material_override = nmm
	var parent := mi.get_parent()
	var skel := parent as Skeleton3D
	if skel != null and skel.find_bone("chest") >= 0:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "chest"
		skel.add_child(ba)
		var bg: Transform3D = skel.get_bone_global_rest(skel.find_bone("chest"))
		var off: Transform3D = bg.affine_inverse() * mi.transform
		for m2 in [lapel, neck]:
			(m2 as Node3D).transform = off
			ba.add_child(m2)
	else:
		for m3 in [lapel, neck]:
			(m3 as Node3D).transform = mi.transform
			parent.add_child(m3)
	unit.set_meta("ck_outfit_extras", ["lapels", "key_necklace"])


static var _vert_cache: Dictionary = {}


static func _verts_of(mi: MeshInstance3D) -> PackedVector3Array:
	_front_z(mi, 0.0, 0.0, 0.0, 0.0)
	return _vert_cache.get(str(mi.mesh.get_instance_id()), PackedVector3Array())


static func _front_z(mi: MeshInstance3D, x: float, y: float, r: float, fallback: float) -> float:
	var key := str(mi.mesh.get_instance_id())
	var verts: PackedVector3Array = _vert_cache.get(key, PackedVector3Array())
	if verts.is_empty():
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			if not arr.is_empty() and arr[Mesh.ARRAY_VERTEX] != null:
				verts.append_array(arr[Mesh.ARRAY_VERTEX])
		_vert_cache[key] = verts
	var best := -1e9
	var r2 := r * r
	for v in verts:
		var dx := v.x - x
		var dy := v.y - y
		if dx * dx + dy * dy < r2 and v.z > best:
			best = v.z
	return best if best > -1e8 else fallback


static func _add_bar(st: SurfaceTool, a: Vector3, b: Vector3, r: float, slot: int = 8) -> void:
	var d := (b - a)
	var side := d.cross(Vector3(0, 0, 1)).normalized() * r
	var fwd := Vector3(0, 0, r * 0.8)
	var quads := [[a - side, a + side, b + side, b - side], [a - side + fwd, a + side + fwd, b + side + fwd, b - side + fwd]]
	for q in quads:
		var n := Vector3(0, 0, 1)
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_color(Color(float(slot) / 255.0, 1.0, 0.0))
			st.add_vertex(q[idx])
