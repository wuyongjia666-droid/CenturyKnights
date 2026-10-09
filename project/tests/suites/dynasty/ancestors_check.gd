extends Node
## DYN-06: battle deaths and old age both reach the stele, with years, words, deeds, and titles.

const DEATH_SEED := 1

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	var counted := _run(fails)
	CKInjury.set_mode("casual")
	if fails.is_empty():
		print("ANCESTORS PASS rows=%d honor=%d" % [counted.x, counted.y])
		get_tree().quit(0)
		return
	for item in fails:
		print("FAIL ancestors: ", item)
	get_tree().quit(1)

func _run(fails: Array) -> Vector2i:
	GameState.new_game("Stele", "Ash", GameState.crest_color)
	var silver := int(GameState.silver)
	var food := int(GameState.food)
	var morale := int(GameState.morale)
	if Lineage.honor_bonus() != 0:
		fails.append("honor before any death is %d" % Lineage.honor_bonus())
	var ally := _non_leader()
	if ally == null:
		fails.append("no living ally")
		return Vector2i.ZERO
	ally.honors = ["dyn:deep_ford", "dyn:ford_two", "frost_pin"]
	var battle_name := ally.name
	var battle_age := int(ally.age)
	GameState.add_lineage_event("%s held the ford" % battle_name)
	CKInjury.set_mode("classic")
	var got := CKInjury.resolve(ally, 4, 24, DEATH_SEED, "probe")
	if str(got.get("outcome", "")) != "death":
		fails.append("classic seed %d outcome %s" % [DEATH_SEED, str(got)])
		return Vector2i.ZERO
	var elder := CKCharacter.new()
	elder.id = "elder_ash"
	elder.name = "Elder Ash"
	elder.alive = false
	elder.in_roster = false
	elder.age = 70
	elder.honors = []
	GameState.characters[elder.id] = elder
	Lineage.note_deaths()
	if int(GameState.silver) != silver or int(GameState.food) != food or int(GameState.morale) != morale:
		fails.append("month inscription moved silver, food, or morale")
	var rows: Array = Lineage.ancestor_rows()
	var battle: Dictionary = {}
	var aged: Dictionary = {}
	for row in rows:
		if str(row.get("id", "")) == ally.id:
			battle = row
		if str(row.get("id", "")) == elder.id:
			aged = row
	if battle.is_empty() or aged.is_empty():
		fails.append("stele missing battle or age row, count %d" % rows.size())
		return Vector2i(rows.size(), Lineage.honor_bonus())
	_expect_battle(fails, battle, battle_name, battle_age)
	_expect_age(fails, aged, elder.age)
	if Lineage.honor_bonus() != 2:
		fails.append("honor %d, expected 2" % Lineage.honor_bonus())
	return Vector2i(rows.size(), Lineage.honor_bonus())

func _expect_battle(fails: Array, row: Dictionary, battle_name: String, battle_age: int) -> void:
	if str(row.get("cause", "")) != "battle":
		fails.append("battle cause %s" % str(row.get("cause", "")))
	if str(row.get("words", "")) == "":
		fails.append("battle words empty")
	if str(row.get("cause_zh", "")) != Locale.t("ancestor_cause_battle"):
		fails.append("battle cause label %s" % str(row.get("cause_zh", "")))
	if int(row.get("death_year", 0)) - int(row.get("born_year", 0)) != battle_age:
		fails.append("battle years %s age %d" % [str(row), battle_age])
	var titles := str(row.get("titles", ""))
	if titles.find("deep_ford") < 0 or titles.find(Locale.t("amb_ford_two_title")) < 0:
		fails.append("battle titles %s" % titles)
	if titles.find("frost_pin") >= 0:
		fails.append("non-dynasty honor leaked into titles")
	if str(row.get("deeds", "")).find(battle_name) < 0:
		fails.append("battle deeds missed the name")

func _expect_age(fails: Array, row: Dictionary, age: int) -> void:
	if str(row.get("cause", "")) != "age":
		fails.append("age cause %s" % str(row.get("cause", "")))
	if str(row.get("words", "")) != Locale.t("ancestor_age_words"):
		fails.append("age words %s" % str(row.get("words", "")))
	if str(row.get("cause_zh", "")) != Locale.t("ancestor_cause_age"):
		fails.append("age cause label %s" % str(row.get("cause_zh", "")))
	if not row.has("born_year") or not row.has("death_year"):
		fails.append("age years missing")
	if int(row.get("death_year", 0)) - int(row.get("born_year", 0)) != age:
		fails.append("age span %s" % str(row))
	if str(row.get("titles", "")) != Locale.t("ancestor_no_title"):
		fails.append("age titles %s" % str(row.get("titles", "")))
	if str(row.get("deeds", "")) != Locale.t("ancestor_no_deed"):
		fails.append("age deeds %s" % str(row.get("deeds", "")))

func _non_leader() -> CKCharacter:
	for c in GameState.roster():
		if not c.is_leader:
			return c
	return null
