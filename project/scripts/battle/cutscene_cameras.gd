class_name CutsceneCameras
extends RefCounted
## Six cutscene cameras. Selection is a pure function of the strike and its index,
## so the same input always returns the same template. FOV stays inside 28–34.
## Eye line is 1.35 m. The low-hero template sits under that line and looks up at it.

const FOV_MIN := 28.0
const FOV_MAX := 34.0
const EYE_Y := 1.35

const TEMPLATES := [
	"over_shoulder",
	"side_follow",
	"low_hero",
	"crit_push",
	"projectile_follow",
	"skill_orbit",
]

## Priority: royal skill, then crit, then kill, then ranged, then melee.
## The two templates in a family alternate with the strike index.
static func select(strike: Dictionary, index: int) -> String:
	var slot := int(abs(index)) % 2
	var royal := CutsceneTimeline.is_royal_skill(str(strike.get("skill", ""))) or CutsceneTimeline.is_royal_skill(str(strike.get("skill_id", "")))
	if royal:
		return "skill_orbit" if slot == 0 else "low_hero"
	if bool(strike.get("crit", false)):
		return "crit_push" if slot == 0 else "over_shoulder"
	if bool(strike.get("killed", false)):
		return "low_hero" if slot == 0 else "crit_push"
	if bool(strike.get("ranged", false)):
		return "projectile_follow" if slot == 0 else "side_follow"
	return "over_shoulder" if slot == 0 else "side_follow"

static func sample(template: String, t: float, ctx: Dictionary = {}) -> Dictionary:
	var u := clampf(t, 0.0, 1.0)
	var dir := 1.0 if float(ctx.get("dir", 1.0)) >= 0.0 else -1.0
	var eye := EYE_Y
	var pos := Vector3(0, eye, 4.8)
	var look := Vector3(0, eye, 0)
	var fov := 32.0
	match template:
		"over_shoulder":
			pos = Vector3(-dir * lerpf(2.15, 1.35, u), eye, lerpf(3.8, 2.9, u))
			look = Vector3(dir * lerpf(0.15, 0.85, u), eye, 0.0)
			fov = lerpf(33.0, 30.0, u)
		"side_follow":
			pos = Vector3(lerpf(-dir * 2.4, dir * 0.4, u), eye, lerpf(4.4, 3.5, u))
			look = Vector3(lerpf(-dir * 0.4, dir * 0.2, u), eye, 0.0)
			fov = 32.5
		"low_hero":
			pos = Vector3(dir * lerpf(2.0, 1.15, u), lerpf(0.72, 0.92, u), lerpf(3.3, 2.45, u))
			look = Vector3(0.0, eye, 0.0)
			fov = lerpf(30.0, 28.5, u)
		"crit_push":
			pos = Vector3(-dir * lerpf(1.85, 0.72, u), eye, lerpf(3.7, 2.05, u))
			look = Vector3(dir * lerpf(0.35, 0.95, u), eye, 0.0)
			fov = lerpf(34.0, 28.0, u)
		"projectile_follow":
			var along := lerpf(-dir * 1.7, dir * 1.55, u)
			pos = Vector3(along, eye + 0.0, lerpf(2.15, 1.55, u))
			look = Vector3(along + dir * 0.35, eye, 0.0)
			fov = 31.0
		"skill_orbit":
			var ang := lerpf(-1.15, 1.15, u) * dir
			pos = Vector3(sin(ang) * 3.55, eye, cos(ang) * 3.35)
			look = Vector3(0.0, eye, 0.0)
			fov = lerpf(33.0, 30.5, u)
		_:
			pos = Vector3(0.0, eye, 4.8)
			fov = 32.0
	return {"pos": pos, "look": look, "fov": clampf(fov, FOV_MIN, FOV_MAX), "template": template}
