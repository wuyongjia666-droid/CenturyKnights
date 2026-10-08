extends Node
## CORE-02: GameState forwarders and the domain modules return the same values.

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = run()
	_finish(fails)

static func run() -> Array:
	var fails: Array = []
	_lines(fails)
	GameState.new_game("烬行", "灰旗", str(GameState.crest_color))
	var leader = GameState.get_leader()
	if leader == null:
		fails.append("no leader")
		return fails
	var job := str(leader.job_id)
	_eq(fails, "building_level", GameState.building_level("hall"), CKEconomyState.building_level(GameState, "hall"))
	_eq(fails, "max_deploy", GameState.max_deploy(), CKEconomyState.max_deploy(GameState))
	_eq(fails, "train_cost", GameState.train_cost(), CKEconomyState.train_cost(GameState))
	_eq(fails, "forge_craft_cost", GameState.forge_craft_cost(), CKEconomyState.forge_craft_cost(GameState))
	_eq(fails, "market_buy_prices", GameState.market_buy_prices(), CKEconomyState.market_buy_prices(GameState))
	_eq(fails, "market_sell_prices", GameState.market_sell_prices(), CKEconomyState.market_sell_prices(GameState))
	_eq(fails, "_all_buildings_at_least", GameState._all_buildings_at_least(1), CKEconomyState._all_buildings_at_least(GameState, 1))
	_eq(fails, "_enlisted_children_count", GameState._enlisted_children_count(), CKEconomyState._enlisted_children_count(GameState))
	_eq(fails, "holding_unlocked", GameState.holding_unlocked("reed_ford"), CKEconomyState.holding_unlocked(GameState, "reed_ford"))
	_eq(fails, "holding_level", GameState.holding_level("reed_ford"), CKEconomyState.holding_level(GameState, "reed_ford"))
	_eq(fails, "holding_patrol_boost", GameState.holding_patrol_boost("reed_ford"), CKEconomyState.holding_patrol_boost(GameState, "reed_ford"))
	_eq(fails, "holding_patrol_cd", GameState.holding_patrol_cd("reed_ford"), CKEconomyState.holding_patrol_cd(GameState, "reed_ford"))
	_eq(fails, "holding_focus", GameState.holding_focus("reed_ford"), CKEconomyState.holding_focus(GameState, "reed_ford"))
	_eq(fails, "holding_yield_preview", GameState.holding_yield_preview("reed_ford"), CKEconomyState.holding_yield_preview(GameState, "reed_ford"))
	_eq(fails, "unlocked_holdings_count", GameState.unlocked_holdings_count(), CKEconomyState.unlocked_holdings_count(GameState))
	_eq(fails, "total_holding_levels", GameState.total_holding_levels(), CKEconomyState.total_holding_levels(GameState))
	_eq(fails, "ambition_list", GameState.ambition_list(), CKEconomyState.ambition_list(GameState))
	_eq(fails, "building_summary", GameState.building_summary(), CKEconomyState.building_summary(GameState))
	_eq(fails, "family_members", _ids(GameState.family_members()), _ids(CKFamilyState.family_members(GameState)))
	_eq(fails, "get_skill", GameState.get_skill("chart_rally"), CKEnemyLoadout.get_skill(GameState, "chart_rally"))
	_eq(fails, "skills_for_job", GameState.skills_for_job(job), CKEnemyLoadout.skills_for_job(GameState, job))
	_eq(fails, "battle_difficulty_from_map", GameState.battle_difficulty_from_map("ch3_forge"), CKEnemyLoadout.battle_difficulty_from_map(GameState, "ch3_forge"))
	_eq(fails, "enemy_skill_table_for", GameState.enemy_skill_table_for("ch3_forge"), CKEnemyLoadout.enemy_skill_table_for(GameState, "ch3_forge"))
	_eq(fails, "_skills_from_table_entry", GameState._skills_from_table_entry({"skills": ["a"], "elite_skills": ["b"]}), CKEnemyLoadout._skills_from_table_entry(GameState, {"skills": ["a"], "elite_skills": ["b"]}))
	_eq(fails, "_elite_from_table_entry", GameState._elite_from_table_entry({"elite_skills": ["b"]}), CKEnemyLoadout._elite_from_table_entry(GameState, {"elite_skills": ["b"]}))
	_eq(fails, "steward_of", GameState.steward_of("reed_ford"), CKEconomyState.steward_of(GameState, "reed_ford"))
	_skills(fails, job)
	if GameState.HOLDING_DEFS.keys().size() != CKEconomyState.HOLDING_DEFS.keys().size():
		fails.append("HOLDING_DEFS alias")
	return fails

static func _lines(fails: Array) -> void:
	var n := FileAccess.get_file_as_string("res://autoload/game_state.gd").count("\n")
	if n > 1500:
		fails.append("game_state lines %d" % n)

static func _ids(chars: Array) -> Array:
	var out: Array = []
	for c in chars:
		out.append(str(c.id))
	out.sort()
	return out

static func _eq(fails: Array, name: String, a, b) -> void:
	if JSON.stringify(a) != JSON.stringify(b):
		fails.append("%s wrapper %s module %s" % [name, JSON.stringify(a), JSON.stringify(b)])

static func _blank(job: String, tag: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "facade_" + tag
	c.job_id = job
	c.skills = []
	c.unlocked_skills = []
	return c

static func _skills(fails: Array, job: String) -> void:
	var granted_a: Array = []
	var granted_b: Array = []
	GameState._grant_theme_skill(_blank(job, "theme_a"), false, "", granted_a)
	CKEnemyLoadout._grant_theme_skill(GameState, _blank(job, "theme_b"), false, "", granted_b)
	_eq(fails, "_grant_theme_skill", granted_a, granted_b)
	var ca := _blank(job, "list")
	var cb := _blank(job, "list")
	GameState._apply_skill_list(ca, ["chart_rally"])
	CKEnemyLoadout._apply_skill_list(GameState, cb, ["chart_rally"])
	_eq(fails, "_apply_skill_list", ca.skills, cb.skills)
	var ja := _blank(job, "job")
	var jb := _blank(job, "job")
	GameState.grant_job_skills(ja)
	CKEnemyLoadout.grant_job_skills(GameState, jb)
	_eq(fails, "grant_job_skills", ja.skills, jb.skills)
	var ea := _blank(job, "enemy")
	var eb := _blank(job, "enemy")
	GameState.grant_battle_enemy_skills(ea, false, 2, "ch3_forge", "")
	CKEnemyLoadout.grant_battle_enemy_skills(GameState, eb, false, 2, "ch3_forge", "")
	_eq(fails, "grant_battle_enemy_skills", ea.skills, eb.skills)

func _finish(fails: Array) -> void:
	if fails.is_empty():
		print("FACADE PASS apis=30")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL facade: ", f)
	get_tree().quit(1)
