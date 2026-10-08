class_name UnitModel
extends RefCounted
## v8.7 3D unit models for combat cutscenes (docs/art/character-system-v87.md section 3).
## Resolution order:
##   1. cast_<cast_key>.glb           — named heroes: bespoke Hunyuan3D body from the bust-referenced turnaround
##   2. enemy_<template>.glb          — enemy templates (Hunyuan3D)
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
		return "bandit_bow" if role in ["ranger", "mage"] else "bandit_axe"
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

static func model_path(c, team: String, tmpl: String = "") -> String:
	var ck := str(c.cast_key) if "cast_key" in c else ""
	var cands: Array = []
	if ck != "":
		cands.append(DIR + "cast_%s.glb" % ck)
	if team == "enemy" and tmpl != "":
		cands.append(DIR + "enemy_%s.glb" % tmpl)
	if team != "enemy":
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
	var p := model_path(c, team, tmpl)
	if p == "":
		return null
	var ps: PackedScene = load(p)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	recolor(n, c, team)
	if p.get_file().begins_with("outfit_"):
		attach_modules(n, c, team)
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

static func recolor(n: Node, c, team: String) -> void:
	## frosted chrome allies (mint trim; leader frost) · gunmetal enemies (coral trim)
	var enemy := team == "enemy"
	var leader: bool = ("cast_key" in c) and str(c.cast_key) == "leader"
	var trim: Color = UIKit.DANGER if enemy else (UIKit.ACCENT if leader else UIKit.OK)
	var pal := {
		"armor": [Color(0.46, 0.47, 0.52) if enemy else Color(0.80, 0.85, 0.92), 0.85, 0.30],
		"cloth": [Color(0.30, 0.13, 0.13) if enemy else (Color(0.08, 0.11, 0.19) if leader else _hair_tint(c).lerp(Color(0.12, 0.16, 0.22), 0.5)), 0.0, 0.85],
		"leather": [Color(0.24, 0.19, 0.17) if enemy else Color(0.20, 0.17, 0.15), 0.0, 0.7],
		"weapon": [Color(0.70, 0.72, 0.76) if enemy else Color(0.88, 0.93, 0.98), 1.0, 0.16],
		"skin": [Color(0.78, 0.62, 0.52), 0.0, 0.55],
	}
	_walk_recolor(n, pal, trim)

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
	var s := 1.0  # modules are authored for the canonical head (rig_mesh_v87 normalises every body to 1.78 m)
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

static func _walk_recolor(n: Node, pal: Dictionary, trim: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(si)
			var nm := str(m.resource_name) if m else ""
			var base := nm.split(".")[0]
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
				# farmed textured body: projected albedo through the style-lock toon shader (+ team rim, outline)
				var tm := ShaderMaterial.new()
				tm.shader = TOON_BODY
				tm.set_shader_parameter("albedo_tex", (m as BaseMaterial3D).albedo_texture)
				tm.set_shader_parameter("rim_color", Color("#FF7A70") if trim == UIKit.DANGER else Color("#6ED4FF"))
				tm.next_pass = _outline_mat()
				mi.set_surface_override_material(si, tm)
				continue
			sm.rim_enabled = true
			sm.rim = 0.35
			sm.rim_tint = 0.6
			mi.set_surface_override_material(si, sm)
	for ch in n.get_children():
		_walk_recolor(ch, pal, trim)
