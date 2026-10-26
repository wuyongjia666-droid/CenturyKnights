class_name BattleRetreatObjective
extends RefCounted
## Y1-A T-P18: pause retreat arm ↔ ObjectiveHud closed loop.
## When retreat is armed (first tap on PauseHub), the objective strip keeps the
## remaining objective and appends a retreat-confirm warning. Disarm on pause
## close without confirm. Never steals InputRouter taps (ObjectiveHud already IGNORE).

const META := "retreat_armed"


static func is_armed(host: Node) -> bool:
	return host != null and bool(host.get_meta(META, false))


static func arm(host: Node) -> void:
	if host == null:
		return
	host.set_meta(META, true)
	ObjectiveHud.refresh(host)


static func disarm(host: Node) -> void:
	if host == null:
		return
	if host.has_meta(META):
		host.remove_meta(META)
	ObjectiveHud.refresh(host)


## Compose ObjectiveHud detail: keep remaining objective, append warn when armed.
static func compose_detail(base_detail: String, armed: bool) -> String:
	if not armed:
		return base_detail
	var warn := BattleObjectives.text("obj_retreat_armed")
	var base := base_detail.strip_edges()
	if base.is_empty():
		return warn
	return "%s · %s" % [base, warn]


## Detail color: DANGER while armed, ACCENT otherwise.
static func detail_color(armed: bool) -> Color:
	return UIKit.DANGER if armed else UIKit.ACCENT
