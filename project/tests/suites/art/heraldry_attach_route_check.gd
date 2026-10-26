extends Node
## Field attach_* field_route coverage — card/forecast/report/annex/forge/wall/tree/house/train + E2E.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("HERALDRY ATTACH ROUTE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry attach route: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("战旗", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false


func _run() -> void:
	_boot()
	var leader = GameState.get_leader()
	_ok(leader != null, "leader for attach E2E")
	await _card_and_forecast(leader)
	await _report_annex_forge(leader)
	await _wall_tree_house_train(leader)
	_source_contracts()


func _card_and_forecast(leader) -> void:
	var card := Control.new()
	card.name = "UnitCardHost"
	card.size = Vector2(200, 120)
	add_child(card)
	CKHeraldryField.attach_card_arms(card, leader, "player", "")
	await _settle()
	var ca := card.get_node_or_null("CardArms")
	_ok(ca != null, "CardArms present")
	_ok(ca != null and str(ca.get_meta("field_route", "")) == "card_arms", "card_arms field_route")
	# Enemy card → 敌徽 route still card_arms
	CKHeraldryField.attach_card_arms(card, leader, "enemy", "ashbanner")
	await _settle()
	ca = card.get_node_or_null("CardArms")
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) != "gen2_36", "enemy card not 团徽")
	_ok(ca != null and str(ca.get_meta("field_route", "")) == "card_arms", "enemy card_arms route")
	card.queue_free()
	await _settle()

	var panel := Control.new()
	panel.name = "ForecastHost"
	panel.size = Vector2(360, 80)
	add_child(panel)
	CKHeraldryField.pin_forecast_arms(panel, leader, "player", "ashbanner")
	await _settle()
	var ours := panel.get_node_or_null("ForecastOursArms")
	var foe := panel.get_node_or_null("ForecastFoeArms")
	_ok(ours != null and str(ours.get_meta("field_route", "")) == "forecast_ours", "forecast_ours route")
	_ok(foe != null and str(foe.get_meta("field_route", "")) == "forecast_foe", "forecast_foe route")
	_ok(bool(panel.get_meta("forecast_has_foe", false)), "forecast_has_foe meta")
	panel.queue_free()
	await _settle()


func _report_annex_forge(leader) -> void:
	var root := Control.new()
	root.name = "ReportHost"
	add_child(root)
	var row := CKHeraldryField.attach_report_row_arms(root, leader, Vector2(4, 4))
	_ok(row != null and str(row.get_meta("field_route", "")) == "report_row", "report_row route")
	var annex := Control.new()
	annex.name = "AnnexRow"
	root.add_child(annex)
	var aa := CKHeraldryField.attach_annex_row_arms(annex, "person", leader)
	_ok(aa != null and str(aa.get_meta("field_route", "")) == "annex_row", "annex_row route")
	var forge := Control.new()
	forge.name = "ForgeRow"
	forge.size = Vector2(320, 48)
	root.add_child(forge)
	var fa := CKHeraldryField.attach_forge_slot_arms(forge, leader)
	_ok(fa != null and str(fa.get_meta("field_route", "")) == "forge_slot", "forge_slot route")
	var seal := Control.new()
	seal.name = "SealRow"
	root.add_child(seal)
	var sa := CKHeraldryField.attach_affairs_seal_arms(seal, leader)
	_ok(sa != null and str(sa.get_meta("field_route", "")) == "affairs_seal", "affairs_seal route")
	root.queue_free()
	await _settle()


func _wall_tree_house_train(leader) -> void:
	var wall := Control.new()
	wall.name = "WallTile"
	wall.size = Vector2(120, 160)
	add_child(wall)
	CKHeraldryField.attach_wall_tile_arms(wall, leader, Vector2(120, 160))
	await _settle()
	var cell := wall.get_node_or_null("CellArms")
	_ok(cell != null and str(cell.get_meta("field_route", "")) == "wall_tile", "wall_tile route")
	_ok(wall.get_node_or_null("CellBadge") != null, "wall CellBadge")
	wall.queue_free()
	await _settle()

	var tree := Control.new()
	tree.name = "TreeNode"
	tree.size = Vector2(80, 60)
	add_child(tree)
	CKHeraldryField.attach_tree_node_arms(tree, leader, Vector2(80, 60))
	await _settle()
	var node := tree.get_node_or_null("NodeArms")
	_ok(node != null and str(node.get_meta("field_route", "")) == "tree_node", "tree_node route")
	tree.queue_free()
	await _settle()

	var house := Control.new()
	house.name = "HouseCard"
	house.size = Vector2(200, 160)
	add_child(house)
	var ha := CKHeraldryField.attach_house_card_arms(house, leader, Rect2(10, 10, 180, 140))
	_ok(ha != null and str(ha.get_meta("field_route", "")) == "house_card", "house_card route")
	house.queue_free()
	await _settle()

	var train := HBoxContainer.new()
	train.name = "TrainRow"
	add_child(train)
	var ta := CKHeraldryField.attach_train_row_arms(train, leader)
	_ok(ta != null and str(ta.get_meta("field_route", "")) == "train_row", "train_row route")
	train.queue_free()
	await _settle()


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	for pair in [
		["card_arms", "CardArms"],
		["forecast_ours", "ForecastOursArms"],
		["forecast_foe", "ForecastFoeArms"],
		["report_row", "ReportRowArms"],
		["annex_row", "AnnexRowArms"],
		["forge_slot", "ForgeSlotArms"],
		["affairs_seal", "AffairSealArms"],
		["wall_tile", "CellArms"],
		["tree_node", "NodeArms"],
		["house_card", "HouseArms"],
		["train_row", "TrainRowArms"],
	]:
		var route: String = pair[0]
		_ok(field.find('set_meta("field_route", "%s")' % route) >= 0, "field source route %s" % route)
