extends Node
## BTL-05: three difficulty ranks, monotonic threat, save keeps the pick.

var _picker_root: Control


func _ready() -> void:
	var err := _table()
	if err == "":
		err = _monotonic()
	if err == "":
		err = _choose_and_save()
	if err == "":
		err = _defeat()
	if err == "":
		err = await _lamps()
	if err == "":
		await _shots()
	if err != "":
		print("FAIL difficulty: ", err)
		get_tree().quit(1)
		return
	print("DIFFICULTY PASS")
	get_tree().quit(0)


func _table() -> String:
	var order := ["casual", "standard", "classic"]
	var prev := -1
	for mode in order:
		var rank := CKEnemyLoadout.rank_of(mode)
		if rank <= prev:
			return "ranks not rising %s" % mode
		prev = rank
		var flat := int(CKEnemyLoadout.profile(mode).get("stat_flat", 0))
		if mode == "standard" and flat != 0:
			return "standard flat %d" % flat
	var std := CKEnemyLoadout.lamp_rule(1, "standard")
	if int(std.charges) != 2 or bool(std.refill):
		return "standard lamps drifted %s" % std
	var cas := CKEnemyLoadout.lamp_rule(1, "casual")
	if int(cas.charges) != int(std.charges) + 2 or not bool(cas.refill):
		return "casual lamps %s" % cas
	var cls := CKEnemyLoadout.lamp_rule(1, "classic")
	if int(cls.charges) != maxi(0, int(std.charges) - 1) or bool(cls.refill):
		return "classic lamps %s" % cls
	if int(cas.ai_tier) >= int(std.ai_tier) or int(std.ai_tier) >= int(cls.ai_tier):
		return "ai tiers"
	return ""


func _fighter(seed_value: int) -> CKCharacter:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CharacterFactory.make_enemy("bandit", rng)


func _player() -> CKCharacter:
	var c := CKCharacter.new()
	c.job_id = "light_inf"
	c.level = 1
	c.stats = {"str": 10, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.hp = 40
	c.max_hp = 40
	return c


func _threat(mode: String) -> float:
	var foe := _fighter(91)
	var before := int(foe.stats.get("str", 0))
	CKEnemyLoadout.stamp_enemy(foe, mode)
	var expect := BattleRules.expected_damage(foe, _player(), "plain", {})
	if mode == "standard" and int(foe.stats.get("str", 0)) != before:
		return -1.0
	return expect


func _monotonic() -> String:
	var casual := _threat("casual")
	var standard := _threat("standard")
	var classic := _threat("classic")
	if standard < 0.0:
		return "standard stamp changed str"
	if not (casual < standard and standard < classic):
		return "threat %s < %s < %s" % [casual, standard, classic]
	return ""


func _choose_and_save() -> String:
	CKEnemyLoadout.unlock_for_new_game(GameState)
	if not CKEnemyLoadout.choose(GameState, "classic"):
		return "first classic pick rejected"
	if CKEnemyLoadout.choose(GameState, "classic") == false and CKEnemyLoadout.rank_of("classic") > CKEnemyLoadout.rank_of("standard"):
		pass
	if CKEnemyLoadout.choose(GameState, "casual") == false:
		return "step down rejected"
	if CKEnemyLoadout.choose(GameState, "classic"):
		return "step up allowed"
	if CKEnemyLoadout.mode_of(GameState) != "casual":
		return "mode %s" % CKEnemyLoadout.mode_of(GameState)
	var path := GameState.SAVE_PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had else ""
	if not GameState.save_game():
		return "save failed"
	GameState.settings["battle_mode"] = "classic"
	if not GameState.load_game():
		_restore_save(path, had, backup)
		return "load failed"
	var kept := CKEnemyLoadout.mode_of(GameState)
	_restore_save(path, had, backup)
	if kept != "casual":
		return "loaded %s" % kept
	return ""


func _restore_save(path: String, had: bool, backup: String) -> void:
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(backup)
	else:
		var abs := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(abs)


func _defeat() -> String:
	var c := _player()
	c.hp = 5
	var units := [{"char": c, "team": "player"}]
	CKEnemyLoadout.apply_defeat(units, "casual")
	if c.hp != c.max_hp or c.injured:
		return "casual retreat"
	c.hp = c.max_hp
	CKEnemyLoadout.apply_defeat(units, "standard")
	if not c.injured or c.hp != maxi(1, int(c.max_hp * 0.3)):
		return "standard injury %s" % c.hp
	CKEnemyLoadout.apply_defeat(units, "classic")
	if c.hp != 0 or not c.has_meta("classic_down"):
		return "classic hook"
	return ""


func _lamps() -> String:
	CKEnemyLoadout.unlock_for_new_game(GameState)
	CKEnemyLoadout.choose(GameState, "casual")
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.settings["battle_mode"] = "casual"
	GameState.set_meta("battle_map", "obj_rout")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var diff := int(GameState.battle_difficulty_from_map(battle.map_id))
	var rule: Dictionary = CKEnemyLoadout.lamp_rule(diff, "casual")
	if int(battle._lamp_charges) != int(rule.charges) or not bool(battle._lamp_refill):
		battle.queue_free()
		return "battle lamps %s vs %s" % [battle._lamp_charges, rule]
	if int(battle.get_meta("ai_tier", -1)) != int(rule.ai_tier):
		battle.queue_free()
		return "ai tier meta"
	var foe_str := -1
	for u in battle.units:
		if str(u.team) == "enemy":
			foe_str = int(u.char.stats.get("str", 0))
			break
	battle.queue_free()
	if foe_str < 0:
		return "no enemy"
	return ""


func _shots() -> void:
	_picker_root = Control.new()
	_picker_root.size = Vector2(1280, 720)
	add_child(_picker_root)
	CKEnemyLoadout.unlock_for_new_game(GameState)
	CKEnemyLoadout.choose(GameState, "standard")
	DifficultyPicker.attach(_picker_root)
	await get_tree().process_frame
	await _grab(_picker_root, Vector2i(1280, 720), "/opt/cursor/artifacts/btl05_difficulty_desktop.png")
	_picker_root.queue_free()
	_picker_root = Control.new()
	_picker_root.size = Vector2(1080, 2400)
	add_child(_picker_root)
	DifficultyPicker.attach(_picker_root)
	var panel := _picker_root.get_node("DifficultyPicker") as Control
	panel.position = Vector2(24, 120)
	panel.size = Vector2(420, 320)
	await get_tree().process_frame
	await _grab(_picker_root, Vector2i(1080, 2400), "/opt/cursor/artifacts/btl05_difficulty_phone.png")


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
