extends SceneTree
## Status overlay ids follow traits and injury records. Missing art draws nothing.

class Dummy extends RefCounted:
	var traits: Array = []
	var blood_meta: Dictionary = {}
	var injured: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var err := _check()
	if err != "":
		print("FAIL portrait status: ", err)
		quit(1)
	else:
		print("PORTRAIT STATUS PASS")
		quit(0)


func _check() -> String:
	var fed := Dummy.new()
	fed.traits = ["brave", "malnourished"]
	var fed_ids := CKPortraitStatus.active_ids(fed)
	if fed_ids.size() != 1 or fed_ids[0] != "malnourished":
		return "malnourished %s" % str(fed_ids)
	var limp := Dummy.new()
	limp.blood_meta = {"injury": {"tier": "lasting", "id": "limp", "months_left": 4}}
	var limp_ids := CKPortraitStatus.active_ids(limp)
	if limp_ids.size() != 1 or limp_ids[0] != "limp":
		return "limp %s" % str(limp_ids)
	var grave := Dummy.new()
	grave.traits = ["malnourished"]
	grave.blood_meta = {"injury": {"tier": "grave", "id": "", "months_left": 3}}
	var grave_ids := CKPortraitStatus.active_ids(grave)
	if grave_ids.size() != 2 or grave_ids[0] != "malnourished" or grave_ids[1] != "wound_grave":
		return "stack %s" % str(grave_ids)
	var flag := Dummy.new()
	flag.injured = true
	var flag_ids := CKPortraitStatus.active_ids(flag)
	if flag_ids.size() != 1 or flag_ids[0] != "wound_light":
		return "flag %s" % str(flag_ids)
	if CKArtPaths.exists(CKPortraitStatus.overlay_path("malnourished")):
		return "overlay art must not be invented"
	if load("res://scripts/battle/ui/battle_info_panel.gd") == null:
		return "battle info panel"
	if load("res://scripts/ui/unit_card.gd") == null:
		return "unit card"
	var host := Control.new()
	host.size = Vector2(64, 80)
	CKPortraitStatus.attach(host, fed, host.size)
	var drew := host.get_child_count()
	CKPortraitStatus.attach(host, null)
	host.free()
	if drew != 0:
		return "attach drew a missing overlay"
	return ""
