extends Node
## BTL-07: height, weather, interactive cells, and scout fog.

var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := _formulas()
	if err == "":
		err = await _scenes()
	if err == "":
		err = _perf()
	if err != "":
		print("FAIL terrain: ", err)
		get_tree().quit(1)
		return
	print("TERRAIN PASS")
	get_tree().quit(0)


func _unit(job: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.job_id = job
	c.level = 1
	c.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.hp = 30
	c.max_hp = 30
	c.weapon_id = ""
	return c


func _formulas() -> String:
	if TerrainFx.clamp_height(9) != 3 or TerrainFx.clamp_height(-4) != 0:
		return "height clamp"
	if TerrainFx.height_delta_hit(3, 0) != 18:
		return "high ground hit"
	if TerrainFx.height_delta_hit(0, 3) != -18:
		return "low ground hit"
	if TerrainFx.height_delta_hit(2, 2) != 0:
		return "even ground hit"
	if TerrainFx.height_delta_hit(9, -2) != 18:
		return "clamped delta"
	if TerrainFx.range_bonus(0) != 0 or TerrainFx.range_bonus(1) != 0:
		return "low range"
	if TerrainFx.range_bonus(2) != 1 or TerrainFx.range_bonus(3) != 1:
		return "high range"
	if TerrainFx.weather_hit("rain", "ranged") != -12:
		return "rain archer"
	if TerrainFx.weather_hit("rain", "melee") != 0 or TerrainFx.weather_hit("rain", "magic") != 0:
		return "rain should spare melee and magic"
	if TerrainFx.weather_hit("snow", "ranged") != 0 or TerrainFx.weather_hit("fog", "ranged") != 0:
		return "non-rain hit"
	if TerrainFx.weather_move_extra("snow") != 1 or TerrainFx.weather_move_extra("rain") != 0:
		return "snow move"
	if TerrainFx.vision_range(false, "fog") != 99:
		return "fog without scout is not war fog"
	if TerrainFx.vision_range(true, "fog") != 2 or TerrainFx.vision_range(true, "clear") != 4:
		return "scout vision"
	if not TerrainFx.sees(Vector2i(0, 0), Vector2i(2, 0), 2):
		return "sees edge"
	if TerrainFx.sees(Vector2i(0, 0), Vector2i(2, 1), 2):
		return "sees past radius"
	if TerrainFx.seen_by([Vector2i(0, 5)], Vector2i(7, 0), 2):
		return "far enemy should be hidden"
	if not TerrainFx.seen_by([Vector2i(0, 5)], Vector2i(0, 4), 2):
		return "adjacent ally should be seen"
	if TerrainFx.interact("door", "closed") != "open" or TerrainFx.interact("door", "open") != "closed":
		return "door toggle"
	if TerrainFx.interact("bridge", "up") != "down" or TerrainFx.interact("bridge", "down") != "up":
		return "bridge toggle"
	if TerrainFx.interact("fire", "lit") != "out" or TerrainFx.interact("fire", "out") != "out":
		return "fire destroy"
	if TerrainFx.interact("fence", "up") != "broken" or TerrainFx.interact("fence", "broken") != "broken":
		return "fence destroy"
	if not TerrainFx.blocks("door", "closed") or TerrainFx.blocks("door", "open"):
		return "door block"
	if not TerrainFx.blocks("bridge", "up") or TerrainFx.blocks("bridge", "down"):
		return "bridge block"
	if not TerrainFx.blocks("fence", "up") or TerrainFx.blocks("fence", "broken"):
		return "fence block"
	if TerrainFx.blocks("fire", "lit"):
		return "fire should not block"
	var atk := _unit("light_inf")
	var defender := _unit("light_inf")
	var base := BattleRules.calc_hit(atk, defender, "plain", {})
	var high := BattleRules.calc_hit(atk, defender, "plain", {"height_hit": 18})
	var low := BattleRules.calc_hit(atk, defender, "plain", {"height_hit": -18})
	var rain := BattleRules.calc_hit(atk, defender, "plain", {"weather_hit": -12})
	if high != base + 18 or low != base - 18 or rain != base - 12:
		return "calc_hit wiring %d %d %d %d" % [base, high, low, rain]
	var melee := _unit("light_inf")
	var flat := BattleRules.attack_reach(melee, "plain", 0)
	var raised := BattleRules.attack_reach(melee, "plain", 2)
	if raised != flat + 1:
		return "attack_reach height %d %d" % [flat, raised]
	if BattleRules.attack_reach(melee, "plain", 1) != flat:
		return "height 1 adds no range"
	if not BattleRules.can_counter(atk, defender, Vector2i(0, 0), Vector2i(0, 2), 2):
		return "high counter dist 2"
	if BattleRules.can_counter(atk, defender, Vector2i(0, 0), Vector2i(0, 2), 0):
		return "flat counter dist 2"
	var row := [["plain", "plain", "plain"]]
	var snow: Dictionary = BattleRules.move_costs(row, Vector2i(0, 0), 3, [], [], false, 0, 1, false, 1)
	var dry: Dictionary = BattleRules.move_costs(row, Vector2i(0, 0), 3, [], [], false, 0, 1, false, 0)
	if int(snow.get(Vector2i(1, 0), -1)) != 2 or int(dry.get(Vector2i(1, 0), -1)) != 1:
		return "move extra %s vs %s" % [snow, dry]
	if snow.has(Vector2i(2, 0)):
		return "snow should stop the third plain"
	return ""


func _scenes() -> String:
	var err := await _boot("test_terrain_height")
	if err != "":
		return err
	err = _scene_height()
	if err != "":
		return err
	err = _scene_interact()
	if err != "":
		return err
	err = await _boot("test_terrain_rain")
	if err != "":
		return err
	err = _scene_rain()
	if err != "":
		return err
	err = await _boot("test_terrain_snow")
	if err != "":
		return err
	err = _scene_snow()
	if err != "":
		return err
	err = await _boot("test_terrain_fog")
	if err != "":
		return err
	err = await _scene_fog()
	return err


func _boot(map_id: String) -> String:
	if _battle == null:
		GameState.new_game("Probe", "Ash", "#" + "6ED4FF")
	for c in GameState.roster():
		c.injured = false
		c.hp = c.max_hp
	GameState.set_meta("battle_map", map_id)
	if _battle == null:
		var packed: PackedScene = load("res://scenes/battle/battle.tscn")
		_battle = packed.instantiate()
		add_child(_battle)
		_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_battle.size = Vector2(1280, 720)
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		_battle.battle_over = false
		_battle._round_no = 0
		if _battle.has_meta("battle_verdict"):
			_battle.remove_meta("battle_verdict")
		_battle._init_map()
		_battle._deploy()
		_battle._start_player_turn()
	if str(_battle.map_id) != map_id:
		return "loaded %s" % _battle.map_id
	if _battle.battle_over:
		return "%s ended at deploy" % map_id
	return ""


func _index(team: String) -> int:
	for i in _battle.units.size():
		if str(_battle.units[i].team) == team and int(_battle.units[i].char.hp) > 0:
			return i
	return -1


func _state(cell: Vector2i) -> String:
	for item in _battle.interactives:
		if item.get("cell", Vector2i(-9, -9)) == cell:
			return str(item.get("state", ""))
	return ""


func _scene_height() -> String:
	var pi := _index("player")
	var ei := _index("enemy")
	if pi < 0 or ei < 0:
		return "height roster"
	if int(_battle._height_at(_battle.units[pi].pos)) != 3:
		return "player not on height 3"
	if int(_battle._height_at(_battle.units[ei].pos)) != 0:
		return "enemy not on low ground"
	var extras: Dictionary = _battle._combat_extras(pi, ei)
	if int(extras.get("height_hit", 0)) != 18:
		return "scene high hit %s" % extras
	var pp: Vector2i = _battle.units[pi].pos
	var ep: Vector2i = _battle.units[ei].pos
	_battle.units[pi].pos = ep
	_battle.units[ei].pos = pp
	extras = _battle._combat_extras(pi, ei)
	if int(extras.get("height_hit", 0)) != -18:
		return "scene low hit %s" % extras
	var saved_job := str(_battle.units[pi].char.job_id)
	_battle.units[pi].char.job_id = "light_inf"
	_battle.units[pi].pos = Vector2i(1, 0)
	_battle.units[ei].pos = Vector2i(1, 2)
	if not _battle._can_attack_from(_battle.units[pi], Vector2i(1, 2)):
		_battle.units[pi].char.job_id = saved_job
		return "height 2 melee should reach dist 2"
	_battle.units[pi].pos = Vector2i(0, 0)
	if _battle._can_attack_from(_battle.units[pi], Vector2i(0, 2)):
		_battle.units[pi].char.job_id = saved_job
		return "flat melee reached dist 2"
	_battle.units[pi].char.job_id = saved_job
	if _battle._fx_marks.is_empty():
		return "board drew no height marks"
	_battle.units[pi].pos = Vector2i(1, 1)
	return ""


func _scene_interact() -> String:
	var pi := _index("player")
	if pi < 0:
		return "interact roster"
	_battle.units[pi].pos = Vector2i(1, 1)
	_battle.attack_mode = false
	_battle._select_player(pi)
	if _battle.move_cells.has(Vector2i(2, 1)):
		return "closed door was walkable"
	_battle._click_cell(Vector2i(2, 1))
	if _state(Vector2i(2, 1)) != "open":
		return "door stayed %s" % _state(Vector2i(2, 1))
	_battle._click_cell(Vector2i(1, 0))
	if _state(Vector2i(1, 0)) != "down":
		return "bridge stayed %s" % _state(Vector2i(1, 0))
	_battle._click_cell(Vector2i(0, 1))
	if _state(Vector2i(0, 1)) != "out":
		return "fire stayed %s" % _state(Vector2i(0, 1))
	_battle._click_cell(Vector2i(1, 2))
	if _state(Vector2i(1, 2)) != "broken":
		return "fence stayed %s" % _state(Vector2i(1, 2))
	_battle._click_cell(Vector2i(2, 1))
	if _state(Vector2i(2, 1)) != "closed":
		return "door did not close"
	_battle._click_cell(Vector2i(0, 1))
	if _state(Vector2i(0, 1)) != "out":
		return "fire relit"
	return ""


func _scene_rain() -> String:
	if str(_battle.weather) != "rain":
		return "weather %s" % _battle.weather
	var pi := _index("player")
	var ei := _index("enemy")
	if pi < 0 or ei < 0:
		return "rain roster"
	var saved := str(_battle.units[pi].char.job_id)
	_battle.units[pi].char.job_id = "hunter"
	var extras: Dictionary = _battle._combat_extras(pi, ei)
	_battle.units[pi].char.job_id = saved
	if int(extras.get("weather_hit", 0)) != -12:
		return "rain scene %s" % extras
	extras = _battle._combat_extras(pi, ei)
	if int(extras.get("weather_hit", 0)) != 0:
		return "rain melee %s" % extras
	return ""


func _scene_snow() -> String:
	if str(_battle.weather) != "snow":
		return "weather %s" % _battle.weather
	var pi := _index("player")
	if pi < 0:
		return "snow roster"
	if _battle.units[pi].pos != Vector2i(0, 0):
		return "snow start %s" % _battle.units[pi].pos
	_battle._select_player(pi)
	if int(_battle.move_cells.get(Vector2i(1, 0), -1)) != 2:
		return "snow step %s" % _battle.move_cells
	_battle.weather = "clear"
	var dry: Dictionary = _battle._compute_move_cells(pi)
	_battle.weather = "snow"
	if int(dry.get(Vector2i(1, 0), -1)) != 1:
		return "dry step %s" % dry
	return ""


func _scene_fog() -> String:
	if not _battle.scout_map or str(_battle.weather) != "fog":
		return "fog flags"
	if TerrainFx.vision_range(_battle.scout_map, _battle.weather) != 2:
		return "fog radius"
	var ei := _index("enemy")
	var pi := _index("player")
	if ei < 0 or pi < 0:
		return "fog roster"
	var hidden: Vector2i = _battle.units[ei].pos
	if _battle._players_see(hidden):
		return "enemy start visible %s" % hidden
	_battle.log_label.text = ""
	_battle._log_enemy_move(_battle.units[ei], Vector2i(7, 1))
	if _battle.log_label.text.find("(7,1)") >= 0:
		return "hidden step logged"
	_battle._log_enemy_move(_battle.units[pi], Vector2i(0, 4))
	if _battle.log_label.text.find("(0,4)") < 0:
		return "visible step missing"
	_battle.log_label.text = ""
	await _battle._enemy_ai()
	var log := str(_battle.log_label.text)
	var re := RegEx.new()
	re.compile("\\((\\d+),(\\d+)\\)")
	for match in re.search_all(log):
		var cell := Vector2i(int(match.get_string(1)), int(match.get_string(2)))
		if not _battle._players_see(cell):
			return "fog leaked %s in %s" % [cell, log]
	return ""


func _perf() -> String:
	var base := _median(false)
	var feat := _median(true)
	var ratio := float(feat) / float(maxi(base, 1))
	print("terrain perf ratio %.3f base=%d feat=%d" % [ratio, base, feat])
	if ratio > 1.2:
		return "perf %.3f > 1.2" % ratio
	return ""


func _median(with_fx: bool) -> int:
	var samples: Array = []
	for _trial in 5:
		samples.append(_once(with_fx))
	samples.sort()
	return int(samples[2])


func _once(with_fx: bool) -> int:
	var t0 := Time.get_ticks_usec()
	for _n in 80:
		for u in _battle.units:
			if int(u.char.hp) <= 0:
				continue
			var center := Vector2(u.pos) * float(_battle.CELL)
			var tr := 20.0
			for si in range(3):
				var sr := tr * (1.05 + 0.16 * float(si))
				for a in range(20):
					var ang := TAU * float(a) / 20.0
					var _p := center + Vector2(cos(ang) * sr, sin(ang) * sr * 0.42 + tr * 0.78)
		if with_fx:
			for mark in _battle._fx_marks:
				var h := int(mark.get("h", 0))
				var _drop := Vector2(float(h) * 2.0, float(h) * 1.5)
	return Time.get_ticks_usec() - t0
