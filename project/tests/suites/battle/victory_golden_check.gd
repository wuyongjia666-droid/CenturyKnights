extends Node
## BTL-01: 400-map victory snapshot must match the pre-refactor ladder.
## Also loads res://data/maps/btl01_probe.json and starts that battle.

const FIXTURE := "res://tests/suites/battle/fixtures/victory_golden.json"

func _ready() -> void:
	await get_tree().process_frame
	var err := _run_tables()
	if err != "":
		_fail(err)
		return
	err = await _run_battle()
	if err != "":
		_fail(err)
		return
	print("VICTORY GOLDEN PASS")
	get_tree().quit(0)

func _fail(err: String) -> void:
	print("FAIL victory golden: ", err)
	get_tree().quit(1)

func _run_tables() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var lines := src.split("\n").size()
	if lines > 3000:
		return "battle_controller.gd lines %d > 3000" % lines
	if src.split('map_id == "').size() - 1 > 10:
		return "map_id == count %d" % (src.split('map_id == "').size() - 1)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "fixture unreadable"
	var maps: Dictionary = parsed.get("maps", {})
	if int(parsed.get("count", 0)) != 400 or maps.size() != 400:
		return "fixture count %s/%s" % [parsed.get("count"), maps.size()]
	var mismatches := 0
	var sample := ""
	for map_id in maps.keys():
		var want: Dictionary = maps[map_id]
		var got := BattleVictory.describe(str(map_id), {})
		var diff := _diff(str(map_id), want, got)
		if diff != "":
			mismatches += 1
			if sample == "":
				sample = diff
	if mismatches > 0:
		return "%d maps differ; first %s" % [mismatches, sample]
	for case in parsed.get("silver_cases", []):
		var mods: Dictionary = case.get("mods", {})
		var tutorial := bool(case.get("tutorial", false))
		if BattleVictory.base_purse(mods) != int(case.get("base_purse", -1)):
			return "base purse %s" % mods
		if BattleVictory.memory_bonus(mods) != int(case.get("memory_bonus", -1)):
			return "memory %s" % mods
		if BattleVictory.silver_total(mods) != int(case.get("silver", -1)):
			return "silver %s" % mods
		if BattleVictory.skill_points(tutorial) != int(case.get("skill_points", -1)):
			return "skill points tutorial=%s" % tutorial
	var banter = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_banter.json"))
	var themes: Dictionary = banter.get("themes", {})
	if themes.size() < 21:
		return "banter themes %d" % themes.size()
	var escort: Dictionary = themes.get("escort", {})
	if escort.get("turn", []).size() != 4 or str(escort.get("start_sfx", "")) != "escort_horn":
		return "escort banter drifted"
	if str(themes.get("porcelain", {}).get("kill_sfx", "")) != "porcelain_chime":
		return "porcelain sfx drifted"
	var probe := BattleMaps.get_map("btl01_probe")
	if str(probe.get("name", "")) != "加载探针":
		return "probe map not loaded: %s" % probe.get("name", "")
	if int(probe.get("w", 0)) != 6:
		return "probe size"
	var described := BattleVictory.describe("btl01_probe", {})
	var pflags: Array = described.get("flags", [])
	if not pflags.has("battle_done") or not pflags.has("btl01_probe_done"):
		return "probe flags %s" % pflags
	print("golden tables OK lines=%d maps=400 probe=%s" % [lines, probe.get("name")])
	return ""

func _diff(map_id: String, want: Dictionary, got: Dictionary) -> String:
	if not _same_list(want.get("flags", []), got.get("flags", [])):
		return "%s flags want %s got %s" % [map_id, want.get("flags"), got.get("flags")]
	if int(want.get("silver", -1)) != int(got.get("silver", -2)):
		return "%s silver %s vs %s" % [map_id, want.get("silver"), got.get("silver")]
	if int(want.get("skill_points", -1)) != int(got.get("skill_points", -2)):
		return "%s sp %s vs %s" % [map_id, want.get("skill_points"), got.get("skill_points")]
	if not _same_list(want.get("actions", []), got.get("actions", [])):
		return "%s actions %s vs %s" % [map_id, want.get("actions"), got.get("actions")]
	if not _same_list(want.get("unlocks", []), got.get("unlocks", [])):
		return "%s unlocks" % map_id
	var wrep: Dictionary = want.get("rep", {})
	var grep: Dictionary = got.get("rep", {})
	if int(wrep.get("ashland", -1)) != int(grep.get("ashland", -2)):
		return "%s rep" % map_id
	return ""

func _same_list(a, b) -> bool:
	if typeof(a) != TYPE_ARRAY or typeof(b) != TYPE_ARRAY:
		return false
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true

func _run_battle() -> String:
	GameState.new_game("探针", "灰旗", GameState.crest_color)
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader"
	leader.hp = 3
	GameState.set_meta("heir_clash_a", leader.id)
	var silver0 := int(GameState.silver)
	var sp0 := int(GameState.skill_points)
	BattleVictory.apply("ch_heir_clash")
	if leader.hp != leader.max_hp or not leader.alive:
		return "heir clash hp not restored"
	if GameState.has_meta("heir_clash_a"):
		return "heir clash meta left behind"
	if not GameState.flag("ch_heir_clash_done") or not GameState.flag("battle_done"):
		return "heir clash flags"
	if int(GameState.silver) != silver0:
		return "apply should not grant silver by itself"
	GameState.set_meta("battle_map", "btl01_probe")
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle = packed.instantiate()
	add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	if str(battle.map_id) != "btl01_probe":
		return "battle did not start on probe, map=%s" % battle.map_id
	if battle.units.size() < 2:
		return "probe deploy units=%d" % battle.units.size()
	if not battle.has_signal("unit_downed") or not battle.has_signal("battle_finished"):
		return "missing battle signals"
	var heard: Array = []
	battle.unit_downed.connect(func(who, info): heard.append(info))
	var foe = null
	for u in battle.units:
		if u.team == "enemy":
			foe = u
			break
	if foe == null:
		return "probe has no enemy"
	foe.char.hp = 0
	battle._note_unit_downed(foe, leader)
	if heard.size() != 1 or str(heard[0].get("team", "")) != "enemy":
		return "unit_downed %s" % heard
	battle.map_id = "ch112_yard"
	battle._banter_idx = 0
	battle._banter_kill = 0
	battle._banter_played = {}
	battle._theme_banter("start")
	battle._theme_banter("kill")
	var banter_log := str(battle.log_label.text)
	if banter_log.find("【镖行】") < 0:
		return "banter json did not play: %s" % banter_log.substr(0, 80)
	var finished_box: Array = [{}]
	battle.battle_finished.connect(func(result): finished_box[0] = result)
	battle.map_id = "ch1_hill"
	battle.map_name = "石垒坡"
	var before_silver := int(GameState.silver)
	var before_sp := int(GameState.skill_points)
	battle._finish(true)
	if not GameState.flag("ch1_hill_done"):
		return "finish did not set ch1_hill_done"
	if int(GameState.silver) - before_silver != 35:
		return "finish silver delta %d" % (int(GameState.silver) - before_silver)
	if int(GameState.skill_points) - before_sp != 1:
		return "finish skill delta %d (start %d)" % [int(GameState.skill_points) - before_sp, sp0]
	var finished: Dictionary = finished_box[0]
	if not bool(finished.get("win", false)) or str(finished.get("map_id", "")) != "ch1_hill":
		return "battle_finished %s" % finished
	if int(GameState.reputation.get("ashland", 0)) < 8:
		return "rep not applied"
	battle.queue_free()
	return ""
