extends Node
## CUT-02 + P2: ten weapon archetypes, eight actions, attack impact matches the timeline.

const ARCHETYPES := ["sword", "spear", "bow", "staff", "shield", "heavy", "axe", "banner", "dagger", "book"]

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL anim archetype: ", err)
		get_tree().quit(1)
	else:
		print("ANIM ARCHETYPE PASS")
		get_tree().quit(0)

func _run() -> String:
	var poses := {}
	for arch in ARCHETYPES:
		var lib := load("res://assets/models/anim/%s.res" % arch) as AnimationLibrary
		if lib == null:
			return "missing " + arch
		for action in CutsceneTimeline.ACTIONS:
			if not lib.has_animation(action):
				return "%s missing %s" % [arch, action]
		var attack := lib.get_animation("attack")
		if not attack.has_meta("impact"):
			return arch + " attack has no impact"
		var marked := float(attack.get_meta("impact"))
		if not is_equal_approx(marked, CutsceneTimeline.action_impact("attack")):
			return "%s impact %.4f" % [arch, marked]
		if attack.length <= marked:
			return arch + " attack ends before impact"
		var skill := lib.get_animation("skill")
		var crit := lib.get_animation("crit")
		if not is_equal_approx(float(skill.get_meta("impact")), CutsceneTimeline.action_impact("skill")):
			return arch + " skill impact"
		if not is_equal_approx(float(crit.get_meta("impact")), CutsceneTimeline.action_impact("crit")):
			return arch + " crit impact"
		poses[arch] = _arm(attack, marked)
	var sword_q: Quaternion = poses["sword"]
	for arch in ARCHETYPES:
		if arch == "sword":
			continue
		var other: Quaternion = poses[arch]
		if sword_q.is_equal_approx(other):
			return arch + " attack matches sword"
	var jobs := _job_ids()
	if jobs.is_empty():
		return "no jobs"
	for job in jobs:
		var mapped := UnitModel.anim_archetype(job)
		if not ARCHETYPES.has(mapped):
			return "unmapped " + job
	var ap := AnimationPlayer.new()
	ap.add_animation_library("", AnimationLibrary.new())
	if UnitModel.apply_anim_archetype(ap, "squire") != "sword":
		return "squire apply"
	if not ap.has_animation("attack"):
		return "applied attack missing"
	var applied := ap.get_animation("attack")
	if not is_equal_approx(float(applied.get_meta("impact")), CutsceneTimeline.action_impact("attack")):
		return "applied impact"
	if UnitModel.apply_anim_archetype(ap, "no_such_job") != "":
		return "unknown job applied"
	# P2 job remaps
	if UnitModel.anim_archetype("skirmisher") != "dagger":
		return "skirmisher not dagger"
	if UnitModel.anim_archetype("banner") != "banner":
		return "banner job"
	if UnitModel.anim_archetype("cantor") != "book":
		return "cantor not book"
	if UnitModel.anim_archetype("forge_brow") != "axe":
		return "forge_brow not axe"
	# P2 READY chest lean 0°
	var idle := (load("res://assets/models/anim/sword.res") as AnimationLibrary).get_animation("idle")
	for i in idle.get_track_count():
		if str(idle.track_get_path(i)).ends_with(":chest"):
			var q: Quaternion = idle.rotation_track_interpolate(i, 0.0)
			var e := q.get_euler()
			if absf(rad_to_deg(e.x)) > 1.0:
				return "READY chest lean %.2f (want 0)" % rad_to_deg(e.x)
			break
	return ""

func _arm(anim: Animation, t: float) -> Quaternion:
	for i in anim.get_track_count():
		if str(anim.track_get_path(i)).ends_with(":upper_arm.R"):
			return anim.rotation_track_interpolate(i, t)
	return Quaternion.IDENTITY

func _job_ids() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/jobs.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for row in parsed.get("jobs", []):
		if typeof(row) == TYPE_DICTIONARY:
			out.append(str(row.get("id", "")))
	return out
