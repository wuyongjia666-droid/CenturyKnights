extends Node
## §9: dossier always opens; bloodline panel + codex stay locked until e2_06_fought.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL dossier bloodline lock: ", err)
		get_tree().quit(1)
	else:
		print("DOSSIER BLOODLINE LOCK PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.remove_meta("dossier_id")
	var ps := load("res://scenes/hub/unit_dossier.tscn") as PackedScene
	var hub: Control = ps.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	if hub.find_child("PortraitColumn", true, false) == null:
		return "dossier itself locked"
	if hub.find_child("BloodlineLock", true, false) == null:
		return "bloodline panel not locked before e2_06"
	var codex := hub.find_child("OpenCodex", true, false) as BaseButton
	if codex == null or not codex.disabled:
		return "codex open before e2_06"
	hub.queue_free()
	await get_tree().process_frame
	GameState.set_flag("e2_06_fought", true)
	hub = ps.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	if hub.find_child("BloodlineLock", true, false) != null:
		return "bloodline still locked after e2_06"
	codex = hub.find_child("OpenCodex", true, false) as BaseButton
	if codex == null or codex.disabled:
		return "codex still locked after e2_06"
	return ""
