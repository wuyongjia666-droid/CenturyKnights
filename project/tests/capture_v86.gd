extends Node
## v8.6 real-render capture (NOT headless): run under xvfb with opengl3.
## Saves battle FX / lineage / estates / marriage frames to OUT for art QA.

var OUT := "/workspace/shots_v86"
var only := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "#c9a227")
	if only == "" or only == "battle":
		await _battle()
	if only == "" or only == "lineage":
		await _scene("res://scenes/hub/lineage_view.tscn", "lineage", 1.2)
	if only == "" or only == "estates":
		_unlock_estates()
		await _scene("res://scenes/hub/estates.tscn", "estates", 1.2)
	if only == "" or only == "marriage":
		await _marriage()
	if only == "cutscene" or only == "cutscene_bow":
		await _cutscene(only == "cutscene_bow")
	for pair in [["castle","res://scenes/hub/castle_hub.tscn"],["roster","res://scenes/hub/roster.tscn"],["tavern","res://scenes/hub/tavern.tscn"],["menu","res://scenes/ui/main_menu.tscn"],["atlas","res://scenes/hub/atlas_view.tscn"]]:
		if only == pair[0] or (only == "" and pair[0] != ""):
			await _scene(pair[1], pair[0], 1.2)
	print("CAPTURE_DONE ", OUT)
	get_tree().quit(0)

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("SHOT ", name)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _battle() -> void:
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.size = Vector2(1280, 720)
	await _wait(1.2)
	var p := -1
	var e := -1
	var p2 := -1
	for i in battle.units.size():
		var u = battle.units[i]
		if u.team == "player" and p < 0:
			p = i; u.pos = Vector2i(3, 3); u.done = false
		elif u.team == "player" and p2 < 0:
			p2 = i; u.pos = Vector2i(2, 4); u.done = false
		elif u.team == "enemy" and e < 0:
			e = i; u.pos = Vector2i(5, 3)
	battle.selected = p
	battle._refresh_info()
	battle.queue_redraw()
	await _wait(0.5)
	await _snap("battle_select")
	# hit: slash + hit spark mid-flight + damage pop on the enemy
	battle._spawn_slash(battle.units[e].pos, "slash")
	battle._spawn_dmg(battle.units[e].pos, "-7", UIKit.DANGER)
	await _wait(0.13)
	await _snap("battle_hit")
	await _wait(0.6)
	battle._spawn_slash(battle.units[e].pos, "crit")
	await _wait(0.12)
	await _snap("battle_crit")
	await _wait(0.6)
	if p2 >= 0:
		battle._spawn_slash(battle.units[p2].pos, "heal")
	await _wait(0.17)
	await _snap("battle_heal")
	await _wait(0.6)
	# enemy card view
	battle._refresh_info_for(e)
	await _wait(0.4)
	await _snap("battle_enemy_card")
	battle.queue_free()
	await _wait(0.2)

func _scene(path: String, name: String, settle: float) -> void:
	var n = load(path).instantiate()
	add_child(n)
	if n is Control:
		n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		n.size = Vector2(1280, 720)
	await _wait(settle)
	await _snap(name)
	n.queue_free()
	await _wait(0.2)

func _unlock_estates() -> void:
	var foci := ["grain", "cash", "fortify", "grain"]
	var i := 0
	for hid in GameState.HOLDING_DEFS.keys():
		GameState.holdings[hid] = {"level": 1 + (i % 3), "steward_id": "", "focus": foci[i % 4], "focus_cd": 0}
		i += 1

func _marriage() -> void:
	var n = load("res://scenes/hub/marriage.tscn").instantiate()
	add_child(n)
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	n.size = Vector2(1280, 720)
	await _wait(1.0)
	await _snap("marriage")
	if n.has_method("play_seal_fx"):
		n.play_seal_fx(true)
	await _wait(0.5)
	await _snap("marriage_seal")
	n.queue_free()


func _cutscene(bow: bool) -> void:
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.size = Vector2(1280, 720)
	await _wait(1.0)
	var hero = null
	var foe = null
	for u in battle.units:
		var ck := str(u.char.cast_key)
		if u.team == "player" and ((bow and ck == "dengying") or (not bow and ck == "leader")):
			hero = u
		if u.team == "enemy" and foe == null:
			foe = u
	if hero == null:
		hero = battle.units[0]
	var hp: int = int(hero.char.hp)
	var ehp: int = int(foe.char.max_hp)
	var rec := {
		"right": {"char": hero.char, "team": "player", "hp0": hp, "hit": 86, "dmg": 9, "crit": hero.char.derived_crit()},
		"left": {"char": foe.char, "team": "enemy", "template": str(foe.get("template", "")), "hp0": ehp, "hit": 64, "dmg": 6, "crit": 3},
		"strikes": [
			{"from": "right", "hit": true, "crit": false, "dmg": 7, "killed": false, "skill": "", "hp_after": ehp - 7},
			{"from": "left", "hit": false, "crit": false, "dmg": 0, "killed": false, "skill": "", "hp_after": hp},
			{"from": "right", "hit": true, "crit": true, "dmg": ehp - 7, "killed": true, "skill": "", "hp_after": 0},
		],
		"ground": "dust", "grade": Color(0.97, 0.98, 1.02),
		"backdrop": "res://assets/art/battle/v8_battle_biome_pass.png", "title": "隘口之夜 · 平地",
	}
	battle.play_cutscene_record(rec)
	var t := 0.0
	var i := 0
	while t < 8.6:
		await _wait(0.3)
		t += 0.3
		await _snap("cut_%02d" % i)
		i += 1
	battle.queue_free()
