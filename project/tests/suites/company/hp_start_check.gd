extends Node
## Audit P1-2: everyone starts at full hp, the unwounded heal between battles, old saves top up once.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL hp start: ", err)
		get_tree().quit(1)
	else:
		print("HP START PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.refresh_tavern()
	var people: Array = GameState.roster()
	people.append_array(GameState.tavern_candidates)
	for c in people:
		if c.hp != c.max_hp:
			return "%s starts %d/%d" % [c.name, c.hp, c.max_hp]
	var leader: CKCharacter = GameState.get_leader()
	leader.hp = 1
	CKInjury.tick_month(GameState)
	var want := mini(leader.max_hp, 1 + ceili(leader.max_hp * CKInjury.MONTHLY_REGEN))
	if leader.hp != want:
		return "monthly regen %d want %d" % [leader.hp, want]
	leader.hp = 5
	var blob: Dictionary = GameState.build_save_data()
	if not bool(blob.get("hp_fill_v921", false)):
		return "save lacks hp_fill_v921"
	blob.erase("hp_fill_v921")
	GameState.apply_save_data(blob)
	var again: CKCharacter = GameState.get_leader()
	if again.hp != again.max_hp:
		return "old save not topped up %d/%d" % [again.hp, again.max_hp]
	print("OK hp start roster=", people.size())
	return ""
