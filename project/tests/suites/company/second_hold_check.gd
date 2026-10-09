extends Node

func _ready() -> void:
	var err: String = await _run()
	if err != "":
		print("FAIL second hold: ", err)
		get_tree().quit(1)
	else:
		print("SECOND HOLD PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var city := ""
	var ids: Array = World.nodes.keys()
	ids.sort()
	for id in ids:
		if str(id) != "hq" and str(World.node(str(id)).get("kind", "")) != "castle":
			city = str(id)
			break
	if city == "":
		return "no city"
	CKHoldings.note_chain("probe_chain")
	if str(World.second_hold_offer) != "probe_chain":
		return "offer"
	var claimed: Dictionary = CKHoldings.claim(GameState, city, "chain")
	if not bool(claimed.get("ok", false)) or not CKHoldings.owned(GameState):
		return "claim %s" % str(claimed)
	var silver := GameState.silver
	var food := GameState.food
	var note := CKHoldings.apply_month(GameState)
	if note == "" or GameState.silver != silver + 6 or GameState.food != food + 6:
		return "month %s silver %d food %d" % [note, GameState.silver, GameState.food]
	var moved: Dictionary = CKHoldings.transfer(GameState, 2, true)
	if not bool(moved.get("ok", false)) or int(moved.get("away", 0)) != 4 or int(moved.get("home", 0)) != 2:
		return "transfer %s" % str(moved)
	if not CKSaveService.save_slot(GameState, "manual_2"):
		return "save"
	GameState.holdings.erase(CKHoldings.SEAT)
	GameState.silver = 1
	if not CKSaveService.load_slot(GameState, "manual_2"):
		return "load"
	var seat: Dictionary = CKHoldings.seat(GameState)
	if not CKHoldings.owned(GameState) or str(seat.get("city", "")) != city or int(seat.get("garrison_away", 0)) != 4:
		return "roundtrip"
	var atlas := (load("res://scenes/hub/atlas_view.tscn") as PackedScene).instantiate()
	add_child(atlas)
	for _i in 4:
		await get_tree().process_frame
	var send := atlas.find_child("GarrisonToSeat", true, false) as Button
	if send == null:
		return "atlas has no garrison button"
	var away := int(CKHoldings.seat(GameState).get("garrison_away", 0))
	send.pressed.emit()
	if int(CKHoldings.seat(GameState).get("garrison_away", 0)) != away + 1:
		return "atlas send"
	return ""
