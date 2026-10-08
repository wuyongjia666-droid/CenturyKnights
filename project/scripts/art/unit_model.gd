class_name UnitModel
extends RefCounted
## v8.6 3D unit models for combat cutscenes.
## Resolution order (one model per character look):
##   1. res://assets/models/units/cast_<cast_key>.glb     — named heroes (Hunyuan3D from portrait, rigged)
##   2. res://assets/models/units/look_<job>_<hair>_<g>.glb — recruits by job + appearance (Hunyuan batch)
##   3. res://assets/models/units/enemy_<theme>_<role>.glb  — enemies by theme / role (Hunyuan batch)
##   4. archetype stand-in (tools/models/build_standins_v86.py, shared rig + action set) recolored per look/team
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

static func model_path(c, team: String, tmpl: String = "") -> String:
	var ck := str(c.cast_key) if "cast_key" in c else ""
	var cands: Array = []
	if ck != "":
		cands.append(DIR + "cast_%s.glb" % ck)
	if team == "enemy" and tmpl != "":
		cands.append(DIR + "enemy_%s.glb" % tmpl)
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
			elif m is BaseMaterial3D:
				sm = (m as BaseMaterial3D).duplicate()
			sm.rim_enabled = true
			sm.rim = 0.35
			sm.rim_tint = 0.6
			mi.set_surface_override_material(si, sm)
	for ch in n.get_children():
		_walk_recolor(ch, pal, trim)
