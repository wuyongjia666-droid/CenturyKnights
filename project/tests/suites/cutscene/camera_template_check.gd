extends Node
## CUT-03: camera choice is deterministic and every template stays inside FOV 28–34.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL camera template: ", err)
		get_tree().quit(1)
	else:
		print("CAMERA TEMPLATE PASS")
		get_tree().quit(0)

func _strike(extra: Dictionary = {}) -> Dictionary:
	var s := {
		"from": "right",
		"hit": true,
		"crit": false,
		"killed": false,
		"skill": "",
		"ranged": false,
		"dmg": 4,
		"hp_after": 10,
	}
	for k in extra.keys():
		s[k] = extra[k]
	return s

func _run() -> String:
	if CutsceneCameras.TEMPLATES.size() != 6:
		return "template count"
	var melee := _strike()
	if CutsceneCameras.select(melee, 0) != "over_shoulder":
		return "melee 0"
	if CutsceneCameras.select(melee, 1) != "side_follow":
		return "melee 1"
	if CutsceneCameras.select(melee, 4) != "over_shoulder":
		return "melee repeat"
	var ranged := _strike({"ranged": true})
	if CutsceneCameras.select(ranged, 0) != "projectile_follow":
		return "ranged 0"
	if CutsceneCameras.select(ranged, 1) != "side_follow":
		return "ranged 1"
	var crit := _strike({"crit": true})
	if CutsceneCameras.select(crit, 0) != "crit_push":
		return "crit 0"
	if CutsceneCameras.select(crit, 1) != "over_shoulder":
		return "crit 1"
	var kill := _strike({"killed": true})
	if CutsceneCameras.select(kill, 0) != "low_hero":
		return "kill 0"
	if CutsceneCameras.select(kill, 1) != "crit_push":
		return "kill 1"
	var royals := CutsceneTimeline.royal_table()
	if royals.is_empty():
		return "no royals"
	var royal_name := ""
	for id in royals.keys():
		royal_name = str(royals[id].get("name", ""))
		break
	var royal := _strike({"skill": royal_name})
	if CutsceneCameras.select(royal, 0) != "skill_orbit":
		return "royal 0 %s" % royal_name
	if CutsceneCameras.select(royal, 1) != "low_hero":
		return "royal 1"
	if CutsceneCameras.select(royal, 0) != CutsceneCameras.select(royal, 0):
		return "not stable"
	var seen := {}
	for tmpl in CutsceneCameras.TEMPLATES:
		seen[tmpl] = false
	for index in 2:
		seen[CutsceneCameras.select(melee, index)] = true
		seen[CutsceneCameras.select(ranged, index)] = true
		seen[CutsceneCameras.select(crit, index)] = true
		seen[CutsceneCameras.select(kill, index)] = true
		seen[CutsceneCameras.select(royal, index)] = true
	for tmpl in CutsceneCameras.TEMPLATES:
		if not bool(seen[tmpl]):
			return "template never chosen %s" % tmpl
		for dir in [1.0, -1.0]:
			for step in 5:
				var pose: Dictionary = CutsceneCameras.sample(tmpl, float(step) / 4.0, {"dir": dir})
				var fov := float(pose.get("fov", 0.0))
				if fov < CutsceneCameras.FOV_MIN - 0.001 or fov > CutsceneCameras.FOV_MAX + 0.001:
					return "%s fov %s" % [tmpl, fov]
				var pos: Vector3 = pose.get("pos", Vector3.ZERO)
				var look: Vector3 = pose.get("look", Vector3.ZERO)
				if tmpl == "low_hero":
					if pos.y >= CutsceneCameras.EYE_Y - 0.05:
						return "low hero not low"
					if not is_equal_approx(look.y, CutsceneCameras.EYE_Y):
						return "low hero look"
				elif not is_equal_approx(pos.y, CutsceneCameras.EYE_Y):
					return "%s eye %s" % [tmpl, pos.y]
	print("cameras %d fov %s-%s eye %.2f" % [CutsceneCameras.TEMPLATES.size(), CutsceneCameras.FOV_MIN, CutsceneCameras.FOV_MAX, CutsceneCameras.EYE_Y])
	return ""
