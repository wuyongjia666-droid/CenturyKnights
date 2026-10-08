extends Node
## CMP-01: classic deaths reach the stele, casual never kills, grave wounds cannot deploy.

const DEATH_SEED := 1
const GRAVE_SEED := 1
const LASTING_SEED := 17

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL injury: ", err)
		get_tree().quit(1)
		return
	print("INJURY PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _classic_death()
	if err != "":
		return err
	err = _casual_thousand()
	if err != "":
		return err
	err = _grave_blocks_deploy()
	if err != "":
		return err
	err = _lasting_and_mitigate()
	if err != "":
		return err
	err = _signal_settle()
	if err != "":
		return err
	return ""

func _ally() -> CKCharacter:
	for c in GameState.roster():
		if not c.is_leader:
			return c
	return null

func _classic_death() -> String:
	GameState.new_game("伤病", "灰旗", GameState.crest_color)
	CKInjury.set_mode("classic")
	var ally := _ally()
	if ally == null:
		return "no ally"
	var found := -1
	for seed_i in range(1, 40):
		var chance := CKInjury.death_chance(4, 24)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		if rng.randf() < chance:
			found = seed_i
			break
	if found != DEATH_SEED:
		return "classic death seed drifted, first lethal is %d" % found
	var name := ally.name
	var before: int = int(ally.stats.get("skl", 0))
	var got := CKInjury.resolve(ally, 4, 24, DEATH_SEED, "探针")
	if str(got.get("outcome", "")) != "death":
		return "classic seed %d outcome %s" % [DEATH_SEED, got]
	if ally.alive or ally.in_roster:
		return "dead ally still on the roster"
	if GameState.roster().has(ally):
		return "roster() still lists the dead"
	if not GameState.characters.has(ally.id):
		return "dead ally erased from the family"
	var stele: Dictionary = ally.blood_meta.get("stele", {})
	if str(stele.get("words", "")) == "" or str(stele.get("cause", "")) != "battle":
		return "stele %s" % stele
	var logged := false
	for row in GameState.lineage_log:
		var text := str(row.get("text", ""))
		if text.find(name) >= 0 and text.find("阵亡") >= 0 and text.find(str(stele.get("words", ""))) >= 0:
			logged = true
	if not logged:
		return "lineage log missed the death"
	if int(ally.stats.get("skl", 0)) != int(before):
		return "death changed skl"
	return ""

func _casual_thousand() -> String:
	GameState.new_game("伤病", "灰旗", GameState.crest_color)
	CKInjury.set_mode("casual")
	var ally := _ally()
	if ally == null:
		return "no ally for casual"
	for seed_i in range(1, 1001):
		if not ally.alive:
			return "casual died early at %d" % seed_i
		ally.alive = true
		ally.in_roster = true
		var got := CKInjury.resolve(ally, 4, 40, seed_i, "探针")
		if str(got.get("outcome", "")) == "death" or not ally.alive:
			return "casual death at seed %d" % seed_i
	return ""

func _grave_blocks_deploy() -> String:
	GameState.new_game("伤病", "灰旗", GameState.crest_color)
	CKInjury.set_mode("casual")
	var ally := _ally()
	var found := -1
	for seed_i in range(1, 80):
		GameState.new_game("伤病", "灰旗", GameState.crest_color)
		CKInjury.set_mode("casual")
		ally = _ally()
		var got := CKInjury.resolve(ally, 4, 0, seed_i)
		if str(got.get("outcome", "")) == "grave":
			found = seed_i
			break
	if found != GRAVE_SEED:
		return "grave seed drifted, first is %d" % found
	var reason := CKInjury.deploy_block_reason(ally)
	if reason == "" or reason.find("重伤") < 0:
		return "grave deploy reason '%s'" % reason
	var months := int(CKInjury.record(ally).get("months_left", 0))
	if months < 3 or months > 6:
		return "grave months %d" % months
	CKInjury.tick_month(GameState)
	if int(CKInjury.record(ally).get("months_left", 0)) != months - 1:
		return "month tick did not shorten the grave wound"
	if CKInjury.on_harvest(ally):
		return "harvest cleared a grave wound"
	return ""

func _lasting_and_mitigate() -> String:
	GameState.new_game("伤病", "灰旗", GameState.crest_color)
	CKInjury.set_mode("casual")
	var found := -1
	var ally: CKCharacter
	for seed_i in range(1, 80):
		GameState.new_game("伤病", "灰旗", GameState.crest_color)
		CKInjury.set_mode("casual")
		ally = _ally()
		var got := CKInjury.resolve(ally, 0, 0, seed_i)
		if str(got.get("outcome", "")) == "lasting":
			found = seed_i
			break
	if found != LASTING_SEED:
		return "lasting seed drifted, first is %d" % found
	var rec := CKInjury.record(ally)
	if str(rec.get("id", "")) == "lost_finger" and int(CKInjury.combat_mods(ally).get("skl", 0)) != -2:
		return "lost finger mods %s" % CKInjury.combat_mods(ally)
	if str(rec.get("id", "")) == "limp" and CKInjury.move_mod(ally) != -1:
		return "limp move %d" % CKInjury.move_mod(ally)
	if str(rec.get("id", "")) != "lost_finger" and str(rec.get("id", "")) != "limp":
		return "unknown lasting %s" % rec
	var skl_before := int(ally.stats.get("skl", 0))
	GameState.herb = 1
	var eased: Dictionary = CKInjury.mitigate(ally, "clinic")
	if not bool(eased.get("ok", false)):
		return "mitigate %s" % eased
	if not CKInjury.record(ally).is_empty() or ally.injured:
		return "lasting record remained"
	if str(rec.get("id", "")) == "lost_finger" and int(ally.stats.get("skl", 0)) != skl_before + 2:
		return "skl not restored"
	if GameState.herb != 0:
		return "herb not spent"
	return ""

func _signal_settle() -> String:
	GameState.new_game("伤病", "灰旗", GameState.crest_color)
	CKInjury.set_mode("classic")
	var ally := _ally()
	var battle := Node.new()
	battle.add_user_signal("unit_downed", [
		{"name": "who", "type": TYPE_OBJECT},
		{"name": "info", "type": TYPE_DICTIONARY},
	])
	battle.add_user_signal("battle_finished", [
		{"name": "result", "type": TYPE_DICTIONARY},
	])
	add_child(battle)
	CKInjury.attach(battle)
	battle.emit_signal("unit_downed", ally, {
		"team": "player", "map_id": "ch12_yard", "killer": "探针",
		"overflow": 24, "seed": DEATH_SEED,
	})
	battle.emit_signal("battle_finished", {"win": false, "map_id": "ch12_yard"})
	if ally.alive:
		return "signal path did not kill on classic seed"
	var stele: Dictionary = ally.blood_meta.get("stele", {})
	if str(stele.get("killer", "")) != "探针":
		return "signal stele %s" % stele
	battle.queue_free()
	return ""
