extends Node
## Audit P0-3: after a reload, newly made people never take an id a saved person holds.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL id seq: ", err)
		get_tree().quit(1)
	else:
		print("ID SEQ PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.silver = 99999
	GameState.refresh_tavern()
	var hired: CKCharacter = GameState.tavern_candidates[0]
	var res: Dictionary = GameState.recruit(hired, 0)
	if not bool(res.get("ok", false)):
		return "recruit failed"
	var hired_id := hired.id
	var hired_name := hired.name
	if not GameState.save_game():
		return "save"
	# A restart wipes the static counter.
	CharacterFactory._id_seq = 0
	if not GameState.load_game():
		return "load"
	if not GameState.characters.has(hired_id):
		return "hired person missing after load"
	var floor_seq := CharacterFactory.max_seq(GameState.characters.keys())
	if CharacterFactory._id_seq < floor_seq:
		return "seq %d below saved ids %d" % [CharacterFactory._id_seq, floor_seq]
	var before := GameState.characters.size()
	for i in 4:
		GameState.refresh_tavern()
		for c in GameState.tavern_candidates:
			if GameState.characters.has(c.id):
				return "fresh candidate %s reuses a saved id" % c.id
		GameState.recruit(GameState.tavern_candidates[0], 0)
	if GameState.characters.size() != before + 4:
		return "roster %d want %d (someone was overwritten)" % [GameState.characters.size(), before + 4]
	if GameState.characters[hired_id].name != hired_name:
		return "saved hire overwritten"
	# Old save without id_seq: recover from ids. Collision guard reassigns.
	CharacterFactory._id_seq = 0
	var dup := CKCharacter.new()
	dup.id = hired_id
	dup.name = "撞号者"
	GameState.claim_id(dup)
	if dup.id == hired_id:
		return "claim_id kept a held id"
	print("OK id seq=", CharacterFactory._id_seq)
	return ""
