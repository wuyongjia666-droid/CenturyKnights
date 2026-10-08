extends Node
## Visual samples for the shots CI job. Headless suite runs skip the pixels and still print PASS.
## Real frames are taken under xvfb with the opengl3 driver. No hex color literals in this file.

const SCREENS := [
	["main_menu", "res://scenes/ui/main_menu.tscn"],
	["castle", "res://scenes/hub/castle_hub.tscn"],
	["roster", "res://scenes/hub/roster.tscn"],
	["tavern", "res://scenes/hub/tavern.tscn"],
	["marriage", "res://scenes/hub/marriage.tscn"],
	["lineage", "res://scenes/hub/lineage_view.tscn"],
	["atlas", "res://scenes/hub/atlas_view.tscn"],
	["city", "res://scenes/hub/city.tscn"],
	["battle", "res://scenes/battle/battle.tscn"],
	["settings", "res://scenes/ui/settings.tscn"],
	["codex", "res://scenes/hub/bloodline_codex.tscn"],
]
const RATIOS := [Vector2i(1280, 720), Vector2i(1080, 2400)]

var _out := "/tmp/ck_shots"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if DisplayServer.get_name() == "headless":
		print("CAPTURE PASS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var crest := "#%02x%02x%02x" % [110, 212, 255]
	GameState.new_game("Ash", "Banner", crest)
	for ratio in RATIOS:
		await _apply_ratio(ratio)
		for pair in SCREENS:
			await _shoot_scene(str(pair[1]), str(pair[0]), ratio)
		await _shoot_cutscene(ratio)
	print("CAPTURE PASS")
	get_tree().quit(0)

func _apply_ratio(ratio: Vector2i) -> void:
	get_window().size = ratio
	get_tree().root.size = ratio
	await get_tree().process_frame

func _shoot_scene(path: String, screen: String, ratio: Vector2i) -> void:
	var packed = load(path)
	if packed == null:
		push_error("missing " + path)
		return
	var node = packed.instantiate()
	add_child(node)
	if node is Control:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.size = Vector2(ratio)
	await get_tree().create_timer(0.4).timeout
	await _snap("%s_%dx%d" % [screen, ratio.x, ratio.y])
	node.queue_free()
	await get_tree().process_frame

func _shoot_cutscene(ratio: Vector2i) -> void:
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	if battle is Control:
		battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		battle.size = Vector2(ratio)
	await get_tree().create_timer(0.6).timeout
	var hero = null
	var foe = null
	for u in battle.units:
		if u.team == "player" and hero == null:
			hero = u
		elif u.team == "enemy" and foe == null:
			foe = u
	if hero != null and foe != null and battle.has_method("play_cutscene_record"):
		var hp := int(hero.char.hp)
		var ehp := int(foe.char.max_hp)
		var rec := {
			"right": {"char": hero.char, "team": "player", "hp0": hp, "hit": 86, "dmg": 9, "crit": 4},
			"left": {"char": foe.char, "team": "enemy", "template": str(foe.get("template", "")), "hp0": ehp, "hit": 64, "dmg": 6, "crit": 3},
			"strikes": [{"from": "right", "hit": true, "crit": false, "dmg": 7, "killed": false, "skill": "", "hp_after": max(ehp - 7, 0)}],
			"ground": "dust",
			"grade": Color(0.97, 0.98, 1.02),
			"backdrop": "res://assets/art/battle/v8_battle_biome_pass.png",
			"title": "pass",
		}
		battle.play_cutscene_record(rec)
		await get_tree().create_timer(0.45).timeout
	await _snap("cutscene_%dx%d" % [ratio.x, ratio.y])
	battle.queue_free()
	await get_tree().process_frame

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)
