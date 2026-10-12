extends Node
## Audit P1-4: tavern refresh is free once a month, then paid, then capped; walk-aways free their face slot.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL tavern refresh: ", err)
		get_tree().quit(1)
	else:
		print("TAVERN REFRESH PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.silver = 100
	var first: CKCharacter = GameState.tavern_candidates[0]
	UnitArt.portrait(first, 96)
	if not UnitArt._face_assign.has(first.id):
		return "candidate face not assigned"
	var r1: Dictionary = GameState.manual_refresh_tavern()
	if not bool(r1.get("ok", false)) or GameState.silver != 100:
		return "first refresh should be free"
	if UnitArt._face_assign.has(first.id):
		return "walk-away kept the face slot"
	var r2: Dictionary = GameState.manual_refresh_tavern()
	if GameState.silver != 100 - GameState.TAVERN_PAID_COST or int(r2.get("price", 0)) != GameState.TAVERN_PAID_COST:
		return "second refresh price %d silver %d" % [int(r2.get("price", 0)), GameState.silver]
	GameState.manual_refresh_tavern()
	var r4: Dictionary = GameState.manual_refresh_tavern()
	if bool(r4.get("ok", false)):
		return "fourth refresh in a month went through"
	if GameState.tavern_refresh_price() != -1:
		return "price after cap"
	var blob: Dictionary = GameState.build_save_data()
	GameState.apply_save_data(blob)
	if GameState.tavern_refresh_price() != -1:
		return "refresh count lost on reload"
	Calendar.advance(1)
	if GameState.tavern_refresh_price() != 0:
		return "new month should reset to free"
	print("OK tavern refresh")
	return ""
