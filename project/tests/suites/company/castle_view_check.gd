extends Node

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL castle view: ", err)
		get_tree().quit(1)
	else:
		print("CASTLE VIEW PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var view := (load("res://scenes/hub/castle_view.tscn") as PackedScene).instantiate()
	add_child(view)
	view.refresh()
	if not view.layer_visible("hall", 1):
		return "hall tier 1 hidden"
	if view.layer_visible("hall", 2) or view.layer_visible("hall", 3):
		return "hall showed the wrong tier"
	if view.layer_visible("infirmary", 1):
		return "unbuilt infirmary visible"
	GameState.buildings["hall"] = 5
	view.refresh()
	if not view.layer_visible("hall", 3) or view.layer_visible("hall", 1):
		return "hall tier 3"
	GameState.buildings["market"] = 2
	view.refresh()
	if not view.layer_visible("market", 2):
		return "market tier 2"
	if CKCastleServices.recovery_months(GameState, 4) != 4:
		return "infirmary baseline"
	GameState.buildings["infirmary"] = 2
	view.refresh()
	if not view.layer_visible("infirmary", 2):
		return "infirmary layer"
	if CKCastleServices.recovery_months(GameState, 4) != 2:
		return "infirmary rate"
	var child := CKCharacter.new()
	child.alive = true
	child.is_child = true
	child.stats = {"wil": 8}
	child.apt_max = {"wil": 20}
	if CKCastleServices.educate(GameState, child) != 0:
		return "academy should be dark"
	GameState.buildings["academy"] = 2
	if CKCastleServices.educate(GameState, child) != 2 or int(child.stats.wil) != 10:
		return "academy tutor"
	if CKCastleServices.treasury_slots(GameState) != 0:
		return "treasury empty"
	GameState.buildings["treasury"] = 3
	if CKCastleServices.treasury_slots(GameState) != 3:
		return "treasury slots"
	if CKCastleServices.can_counter(GameState):
		return "embassy before it is built"
	GameState.buildings["embassy"] = 1
	if not CKCastleServices.can_counter(GameState):
		return "embassy counter"
	var court := {"relation": 20, "schemes": []}
	var ev := {"house": "ashbanner", "kind": "probe", "relation_delta": -4, "text": "probe", "foiled": false}
	var fixed: Dictionary = CKSchemes.apply_counter(court, ev)
	if not bool(fixed.get("foiled", false)) or int(fixed.get("relation_delta", 0)) != 4:
		return "embassy scheme %s" % str(fixed)
	GameState.silver = 500
	GameState.iron = 20
	GameState.food = 40
	GameState.buildings.erase("infirmary")
	var up: Dictionary = CKCastleServices.upgrade_annex(GameState, "infirmary")
	if not bool(up.get("ok", false)) or CKCastleServices.annex_level(GameState, "infirmary") != 1:
		return "upgrade %s" % str(up)
	return ""
