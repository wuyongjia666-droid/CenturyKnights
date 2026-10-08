extends Node
## Pieces use faction marks and colors. Screen shake follows the UX gain.

var _battle


func _ready() -> void:
	var err := _source()
	if err == "":
		err = await _runtime()
	if err == "":
		await _shots()
	if err != "":
		print("FAIL faction mark: ", err)
		get_tree().quit(1)
		return
	print("FACTION MARK PASS")
	get_tree().quit(0)


func _source() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	for needle in ["faction_mark", "faction_color", "shake_gain"]:
		if src.find(needle) < 0:
			return "missing %s" % needle
	return ""


func _runtime() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("battle_map", "obj_rout")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	GameState.settings["screen_shake"] = 0
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var layer := _battle.get_node_or_null("FactionMarks") as Control
	if layer == null or layer.get_child_count() < 2:
		return "marks missing"
	var saw_enemy := false
	var saw_player := false
	for i in _battle.units.size():
		var mark := layer.get_child(i) as Control
		var want := "enemy" if str(_battle.units[i].team) == "enemy" else "player"
		if str(mark.team) != want:
			return "mark %s vs %s" % [mark.team, want]
		if want == "enemy":
			saw_enemy = true
		else:
			saw_player = true
		var col: Color = UIKit.faction_color(str(_battle.units[i].team))
		if want == "enemy" and col != UIKit.faction_color("enemy"):
			return "enemy color"
		if want == "player" and col != UIKit.faction_color("player"):
			return "player color"
	if not saw_enemy or not saw_player:
		return "sides"
	_battle._trauma = 1.0
	await get_tree().process_frame
	if _battle.position.distance_to(_battle._ui_origin()) > 0.01:
		return "shake ignored gain 0, offset %s" % _battle.position
	GameState.settings["screen_shake"] = 100
	_battle._trauma = 1.0
	_battle._shake_t = 0.4
	await get_tree().process_frame
	if _battle.position.distance_to(_battle._ui_origin()) <= 0.01:
		return "full shake did not move"
	GameState.settings["screen_shake"] = 0
	_battle._trauma = 0.0
	await get_tree().process_frame
	return ""


func _shots() -> void:
	_battle._slash_fx.clear()
	_battle._dmg_fx.clear()
	_battle._lock_burst_fx.clear()
	_battle._move_dust_fx.clear()
	await get_tree().process_frame
	await _grab(_battle, Vector2i(1280, 720), "/opt/cursor/artifacts/btl_faction_desktop.png")
	var fitted: Dictionary = MobileLayout.fit(Vector2(1080, 2400), {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	_battle.set_meta("mobile_insets", {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
	_battle.scale = Vector2(float(fitted.scale), float(fitted.scale))
	await get_tree().process_frame
	await _grab(_battle, Vector2i(1080, 2400), "/opt/cursor/artifacts/btl_faction_phone.png")


func _grab(node: Node, size: Vector2i, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = Vector2(size)
	vp.add_child(bg)
	var parent := node.get_parent()
	node.reparent(vp)
	for _i in 3:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	if parent:
		node.reparent(parent)
	vp.queue_free()
	if img == null:
		print("shot skipped ", path)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	print("shot %s %s err=%s" % [path, img.get_size(), img.save_png(path)])
