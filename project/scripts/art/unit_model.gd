class_name UnitModel
extends RefCounted
## v8.7 3D unit models for combat cutscenes (docs/art/character-system-v87.md section 3).
## Resolution order:
##   1. cast_<cast_key>.glb           — named heroes: bespoke Hunyuan3D body from the bust-referenced turnaround
##   2. enemy themes (res://data/enemy_themes.json) — reuse an existing GLB per faction role,
##      then recolor palette / outfit / weapon. Dedicated enemy_<template>.glb still wins when it exists.
##   3. outfit_<job>_t1_<g>.glb       — MODULAR: shared-skeleton outfit body + genome head modules (hair/ears/marks/
##                                      honours) + genome height/build; one outfit serves every recruit of that job
##   4. look_<job>_<hair>_<g>.glb / archetype stand-in (tools/models/build_standins_v86.py)
## All GLBs share the build_standins_v86 armature + NLA actions (rig_mesh_v87 re-poses farmed meshes onto it).
## Every GLB uses the shared armature + actions: idle advance attack skill hit dodge crit death.
const DIR := "res://assets/models/units/"
const IMPACT := {"attack": 0.458, "skill": 0.792, "crit": 0.5}

static func archetype_for(c, team: String, tmpl: String = "") -> String:
	var role := str(BattleRules.job_role(c.job_id))
	if team == "enemy":
		var t := str(tmpl)
		# prefer dedicated enemy_<tmpl>.glb via model_path; archetype is last-resort stand-in
		if t.ends_with("_archer") or role in ["ranger", "mage"]:
			return "bandit_bow"
		return "bandit_axe"
	var ck := str(c.cast_key) if "cast_key" in c else ""
	if ck == "leader":
		return "knight_sword"
	if ck == "dengying":
		return "ranger_bow"
	if ck == "militia_a":
		return "militia_spear"
	if ck == "militia_b":
		return "militia_shield"
	match role:
		"ranger", "mage":
			return "ranger_bow"
		"tank":
			return "militia_shield"
		"cavalry":
			return "knight_sword"
	return "militia_spear"

static func is_ranged(c) -> bool:
	return str(BattleRules.job_role(c.job_id)) in ["ranger", "mage"]

const TOON_BODY := preload("res://shaders/toon_body_v87.gdshader")
## Mobile low-end cutscenes set this so textured bodies skip the toon shader and outline.
static var prefer_simple_shading := false

static func _unshaded_tex(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = tex
	sm.albedo_color = tint
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return sm

static var _theme_data: Dictionary = {}

static func enemy_themes() -> Dictionary:
	if not _theme_data.is_empty():
		return _theme_data
	var f := FileAccess.open("res://data/enemy_themes.json", FileAccess.READ)
	if f == null:
		push_warning("Missing res://data/enemy_themes.json")
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_theme_data = parsed
	return _theme_data

static func parse_enemy_template(tmpl: String) -> Dictionary:
	var data := enemy_themes()
	var roles: Dictionary = data.get("roles", {})
	var themes: Dictionary = data.get("themes", {})
	var t := str(tmpl).strip_edges()
	if t == "":
		return {"theme": "bandit", "role": "melee"}
	var cut := t.rfind("_")
	if cut > 0:
		var suf := t.substr(cut + 1)
		var pref := t.substr(0, cut)
		if roles.has(suf) and themes.has(pref):
			return {"theme": pref, "role": str(roles[suf])}
	if themes.has(t):
		return {"theme": t, "role": "melee"}
	return {"theme": "bandit", "role": "melee"}

static func _library_path(key: String, gender: String) -> String:
	var lib: Dictionary = enemy_themes().get("library", {})
	var path := str(lib.get(key, ""))
	if path == "":
		return ""
	if gender == "f" and path.ends_with("_m.glb"):
		var alt := path.substr(0, path.length() - 6) + "_f.glb"
		if ResourceLoader.exists(alt):
			return alt
	if ResourceLoader.exists(path):
		return path
	return ""

static func _palette_of(theme: Dictionary) -> Dictionary:
	var src: Dictionary = theme.get("palette", {})
	var out := {}
	for k in ["armor", "cloth", "leather", "weapon", "trim", "skin", "body_tint"]:
		var hex := str(src.get(k, ""))
		if hex != "":
			out[k] = Color(hex)
	if not out.has("trim"):
		out["trim"] = UIKit.DANGER
	if not out.has("body_tint"):
		out["body_tint"] = Color.WHITE
	if not out.has("skin"):
		out["skin"] = Color(0.78, 0.62, 0.52)
	return out

## Data-driven enemy kit: theme + role -> existing GLB, palette, weapon slot. No new meshes.
static func _enemy_spec(c, tmpl: String) -> Dictionary:
	var parsed := parse_enemy_template(tmpl)
	var theme_id := str(parsed.get("theme", "bandit"))
	var role := str(parsed.get("role", "melee"))
	var themes: Dictionary = enemy_themes().get("themes", {})
	var theme: Dictionary = themes.get(theme_id, themes.get("bandit", {}))
	var slots: Dictionary = theme.get("slots", {})
	var slot_key := str(slots.get(role, slots.get("melee", "bandit_axe")))
	var gender := "f" if str(c.gender) == "f" else "m"
	var path := _library_path(slot_key, gender)
	var weapon := slot_key
	if str(tmpl) != "":
		var dedicated := DIR + "enemy_%s.glb" % str(tmpl)
		if ResourceLoader.exists(dedicated):
			path = dedicated
			weapon = "dedicated:%s" % str(tmpl)
	var ck := str(c.cast_key) if "cast_key" in c else ""
	if ck != "":
		var cp := DIR + "cast_%s.glb" % ck
		if ResourceLoader.exists(cp):
			path = cp
			weapon = "cast:%s" % ck
	if path == "" or not ResourceLoader.exists(path):
		path = DIR + archetype_for(c, "enemy", tmpl) + ".glb"
		weapon = "archetype"
		if not ResourceLoader.exists(path):
			path = ""
	var pal := _palette_of(theme)
	return {
		"path": path,
		"theme": theme_id,
		"role": role,
		"weapon": weapon,
		"outfit": str(theme.get("outfit", slot_key)),
		"palette": pal,
		"trim": pal.get("trim", UIKit.DANGER),
		"body_tint": pal.get("body_tint", Color.WHITE),
	}

static func resolve(c, team: String, tmpl: String = "") -> Dictionary:
	if str(team) == "enemy":
		return _enemy_spec(c, tmpl)
	return {
		"path": model_path(c, team, tmpl),
		"theme": "",
		"role": "",
		"weapon": "",
		"outfit": "",
		"palette": {},
		"trim": UIKit.ACCENT,
		"body_tint": Color.WHITE,
	}

static func model_path(c, team: String, tmpl: String = "") -> String:
	if str(team) == "enemy":
		return str(_enemy_spec(c, tmpl).get("path", ""))
	var ck := str(c.cast_key) if "cast_key" in c else ""
	var cands: Array = []
	if ck != "":
		cands.append(DIR + "cast_%s.glb" % ck)
	cands.append(DIR + "outfit_%s_t1_%s.glb" % [c.job_id, "f" if str(c.gender) == "f" else "m"])
	var hair := str(c.appearance.get("hair", "")) if c.appearance is Dictionary else ""
	cands.append(DIR + "look_%s_%s_%s.glb" % [c.job_id, hair, c.gender])
	cands.append(DIR + archetype_for(c, team, tmpl) + ".glb")
	for p in cands:
		if ResourceLoader.exists(p):
			return p
	return ""

static func _hair_tint(c) -> Color:
	var h := str(c.appearance.get("hair", "")) if c.appearance is Dictionary else ""
	return {"ash_brown": Color(0.22, 0.18, 0.16), "ink_black": Color(0.08, 0.09, 0.12), "silver": Color(0.55, 0.58, 0.64),
		"auburn": Color(0.30, 0.14, 0.10), "flax": Color(0.45, 0.38, 0.24)}.get(h, Color(0.12, 0.15, 0.20))

static func instantiate(c, team: String, tmpl: String = "") -> Node3D:
	var spec := resolve(c, team, tmpl)
	var p := str(spec.get("path", ""))
	if p == "":
		return null
	var ps: PackedScene = load(p)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	recolor(n, c, team, tmpl, spec)
	if p.get_file().begins_with("outfit_"):
		attach_modules(n, c, team)
	n.set_meta("ck_theme", str(spec.get("theme", "")))
	n.set_meta("ck_model", p)
	n.set_meta("ck_role", str(spec.get("role", "")))
	n.set_meta("ck_weapon", str(spec.get("weapon", "")))
	var ap := find_anim(n)
	if ap:
		for an in ["idle", "advance"]:
			if ap.has_animation(an):
				ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		for an in ["death"]:
			if ap.has_animation(an):
				ap.get_animation(an).loop_mode = Animation.LOOP_NONE
	return n

static func find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for ch in n.get_children():
		var a := find_anim(ch)
		if a:
			return a
	return null


static func recolor(n: Node, c, team: String, tmpl: String = "", spec: Dictionary = {}) -> void:
	## frosted chrome allies (mint trim; leader frost) · theme palette for enemies
	## Headless CI has no mesh server; the themed GLB is still selected by resolve/instantiate.
	if DisplayServer.get_name() == "headless":
		return
	if spec.is_empty():
		spec = resolve(c, team, tmpl)
	var enemy := team == "enemy"
	var leader: bool = ("cast_key" in c) and str(c.cast_key) == "leader"
	var trim: Color = spec.get("trim", UIKit.DANGER) if enemy else (UIKit.ACCENT if leader else UIKit.OK)
	var pal := {
		"armor": [Color(0.46, 0.47, 0.52) if enemy else Color(0.80, 0.85, 0.92), 0.85, 0.30],
		"cloth": [Color(0.16, 0.13, 0.16) if enemy else (Color(0.08, 0.11, 0.19) if leader else _hair_tint(c).lerp(Color(0.12, 0.16, 0.22), 0.5)), 0.0, 0.85],
		"leather": [Color(0.24, 0.19, 0.17) if enemy else Color(0.20, 0.17, 0.15), 0.0, 0.7],
		"weapon": [Color(0.70, 0.72, 0.76) if enemy else Color(0.88, 0.93, 0.98), 1.0, 0.16],
		"skin": [Color(0.78, 0.62, 0.52), 0.0, 0.55],
	}
	if enemy:
		var tp: Dictionary = spec.get("palette", {})
		for slot in ["armor", "cloth", "leather", "weapon", "skin"]:
			if tp.has(slot):
				pal[slot][0] = tp[slot]
	var tint: Color = spec.get("body_tint", Color.WHITE) if enemy else Color.WHITE
	var rim: Color = trim if enemy else Color("#6ED4FF")
	_walk_recolor(n, pal, trim, tint, rim)

const MOD_DIR := "res://assets/models/modules/"
const HEAD_LEN := 0.249  # canonical head bone length (rig_mesh_v87 rest)

## genome-driven modular dressing for outfit bodies: hair (style by id, colour by genome incl. ageing), crest ear tips,
## honour circlet, bloodline mark glow; height/build from the polygenic body genes.
static func attach_modules(n: Node3D, c, team: String) -> void:
	if not c.has_method("ensure_genome"):
		return
	c.ensure_genome()
	var ph := CKGenome.phenotype(c)
	var body: Dictionary = ph.get("body", {})
	var hgt := 1.0 + 0.06 * float(body.get("height", 0.0))
	var bld := 1.0 + 0.05 * float(body.get("build", 0.0))
	n.scale = Vector3(bld, hgt, bld)
	var sk := _find_skeleton(n)
	if sk == null:
		return
	var hb := sk.find_bone("head")
	if hb < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	sk.add_child(att)
	# farmed hair caps are authored for the canonical head; 0.92 shrink + tiny lift keeps volume off the collar/scalp
	var s := 0.90
	var style := CKPortraitDoll._style(c)
	var mods: Array = [["hair_%s" % style, ph["hair_color"]]]
	if ph["loci"]["ears"]["id"] == "crest":
		mods.append(["ears_crest", ph["skin_color"]])
	if "rime_circlet" in c.honors:
		mods.append(["honor_rime_circlet", Color(0, 0, 0, 0)])
	for m in mods:
		var path: String = MOD_DIR + str(m[0]) + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var ps: PackedScene = load(path)
		var inst: Node3D = ps.instantiate()
		inst.scale = Vector3.ONE * s
		inst.position = Vector3(0, 0.018, 0)  # lift off the bald scalp / high collar (v8.8 clip polish)
		att.add_child(inst)
		var col: Color = m[1]
		if col.a > 0.0:
			_tint_all(inst, col)
	var mk := str(ph["loci"]["mark"]["id"])
	if mk != "none":
		var glow := OmniLight3D.new()
		glow.light_color = Color("#6ED4FF") if mk == "crown_rime" else Color("#FF8A3D")
		glow.light_energy = 0.6 * float(ph["loci"]["mark"]["strength"])
		glow.omni_range = 0.18
		glow.position = Vector3(0.07, 0.12, -0.08)
		att.add_child(glow)

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for ch in n.get_children():
		var s := _find_skeleton(ch)
		if s:
			return s
	return null

static func _tint_all(n: Node, col: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			for ch in n.get_children():
				_tint_all(ch, col)
			return
		for si in mi.mesh.get_surface_count():
			var sm := StandardMaterial3D.new()
			sm.albedo_color = col
			sm.roughness = 0.55
			# farmed modules carry a neutral greyscale strand texture: the genome colour multiplies it
			var om = mi.mesh.surface_get_material(si)
			if om is BaseMaterial3D and (om as BaseMaterial3D).albedo_texture != null:
				sm.albedo_texture = (om as BaseMaterial3D).albedo_texture
			sm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			sm.specular_mode = BaseMaterial3D.SPECULAR_TOON
			sm.rim_enabled = true
			sm.rim = 0.3
			sm.next_pass = _outline_mat()
			mi.set_surface_override_material(si, sm)
	for ch in n.get_children():
		_tint_all(ch, col)

static var _outline: StandardMaterial3D = null
## style lock section 8: inverted-hull outline #0A0E14
static func _outline_mat() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.006
		_outline.albedo_color = Color("#0A0E14")
	return _outline

static func _walk_recolor(n: Node, pal: Dictionary, trim: Color, body_tint: Color = Color.WHITE, rim_color: Color = Color("#6ED4FF")) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			for ch in n.get_children():
				_walk_recolor(ch, pal, trim, body_tint, rim_color)
			return
		for si in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(si)
			var nm := str(m.resource_name) if m else ""
			var base := nm.split(".")[0]
			if base == "body" and m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
				if prefer_simple_shading:
					mi.set_surface_override_material(si, _unshaded_tex((m as BaseMaterial3D).albedo_texture, body_tint))
					continue
				var tm := ShaderMaterial.new()
				tm.shader = TOON_BODY
				tm.set_shader_parameter("albedo_tex", (m as BaseMaterial3D).albedo_texture)
				tm.set_shader_parameter("tint", body_tint)
				tm.set_shader_parameter("rim_color", rim_color)
				tm.next_pass = _outline_mat()
				mi.set_surface_override_material(si, tm)
				continue
			if base == "body":
				base = "cloth"
			var sm := StandardMaterial3D.new()
			if pal.has(base):
				var e: Array = pal[base]
				sm.albedo_color = e[0]
				sm.metallic = e[1]
				sm.roughness = e[2]
				sm.metallic_specular = 0.6
			elif base in ["trim", "visor"]:
				sm.albedo_color = trim
				sm.emission_enabled = true
				sm.emission = trim
				sm.emission_energy_multiplier = 2.4 if base == "visor" else 1.6
				sm.roughness = 0.3
			elif m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
				if prefer_simple_shading:
					mi.set_surface_override_material(si, _unshaded_tex((m as BaseMaterial3D).albedo_texture, body_tint))
					continue
				var tm2 := ShaderMaterial.new()
				tm2.shader = TOON_BODY
				tm2.set_shader_parameter("albedo_tex", (m as BaseMaterial3D).albedo_texture)
				tm2.set_shader_parameter("tint", body_tint)
				tm2.set_shader_parameter("rim_color", rim_color)
				tm2.next_pass = _outline_mat()
				mi.set_surface_override_material(si, tm2)
				continue
			if not prefer_simple_shading:
				sm.rim_enabled = true
				sm.rim = 0.35
				sm.rim_tint = 0.6
			mi.set_surface_override_material(si, sm)
	for ch in n.get_children():
		_walk_recolor(ch, pal, trim, body_tint, rim_color)
