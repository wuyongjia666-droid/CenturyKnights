extends Node
## Full year-card catalogues: ill/mishap/seen/shame/near/yao + rival seats.

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	CKSuiKe.reload_for_tests()
	_catalog_sizes(fails)
	_ill_draw(fails)
	_yao_gates(fails)
	_near_survivor(fails)
	_rival_sibling(fails)
	if fails.is_empty():
		print("SUI KE CATALOG PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL catalog: ", f)
	get_tree().quit(1)


func _catalog_sizes(fails: Array) -> void:
	CKSuiKe.reload_for_tests()
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://data/sui_ke.json"))
	var bands: Array = [["ill", 8], ["mishap", 8], ["seen", 6], ["shame", 6], ["near", 8], ["yao", 8]]
	bands.append_array([["rival_sibling", 12], ["rival_cousin", 6], ["rival_sibling_adult", 4], ["rival_uncle", 7]])
	for pair in bands:
		var n = doc.get(pair[0], [])
		if typeof(n) != TYPE_ARRAY or n.size() != pair[1]:
			fails.append("%s size %s" % [pair[0], str(n.size() if typeof(n)==TYPE_ARRAY else n)])


func _ill_draw(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	CKSuiKe.ensure()
	var kid := _kid("kid_ill", 8)
	kid.birthday_month = Calendar.month
	GameState.characters[kid.id] = kid
	# Force winter month for cough card gate
	Calendar.month = 12
	var card := CKSuiKe._draw_catalog(kid, "ill", RandomNumberGenerator.new())
	if card.is_empty() or str(card.get("band", "")) != "ill":
		fails.append("ill draw empty")
	elif card.get("options", []).size() < 2:
		fails.append("ill options")


func _yao_gates(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	var kid := _kid("kid_yao", 3)
	GameState.characters[kid.id] = kid
	kid.blood_meta["purse"] = 20
	var card := CKSuiKe._draw_yao(kid, RandomNumberGenerator.new())
	if str(card.get("band", "")) != "yao":
		fails.append("yao band")
	# fever contest should be in pool for age 3
	var ids: Array = []
	# resolve a dawn end if present in pending path
	GameState.house_mods["sui_pending"] = [card]
	if str(card.get("id", "")).begins_with("yao_"):
		var opt = card.get("options", [])[0]
		var r = CKSuiKe.resolve(kid.id, str(card.get("id")), str(opt.get("id")))
		if not bool(r.get("ok", false)):
			fails.append("yao resolve %s" % str(r))


func _near_survivor(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	var kid := _kid("kid_near", 5)
	GameState.characters[kid.id] = kid
	var card := CKSuiKe._draw_catalog(kid, "near", RandomNumberGenerator.new())
	if card.is_empty():
		fails.append("near empty")
		return
	GameState.house_mods["sui_pending"] = [card]
	var opt = card.get("options", [])[0]
	var r = CKSuiKe.resolve(kid.id, str(card.get("id")), str(opt.get("id")))
	if not bool(r.get("ok", false)):
		fails.append("near resolve")
	if not kid.alive:
		fails.append("near killed")


func _rival_sibling(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	var leader := GameState.get_leader()
	var a := _kid("sib_a", 9)
	var b := _kid("sib_b", 11)
	a.parent_ids = [leader.id, "mo"]
	b.parent_ids = [leader.id, "mo"]
	a.in_roster = false
	b.in_roster = false
	var mo := _kid("mo", 30)
	mo.is_child = false
	mo.in_roster = true
	mo.alive = true
	GameState.characters[a.id] = a
	GameState.characters[b.id] = b
	GameState.characters[mo.id] = mo
	var seats := CKSuiKe.open_seats(a)
	if not seats.has("sibling"):
		fails.append("sibling seat %s deg=%s" % [str(seats.keys()), str(CKBloodline.kinship_degree(a, b, GameState.characters))])
		return
	var card := CKSuiKe._draw_seat_card(a, b, "sibling", RandomNumberGenerator.new())
	if str(card.get("band", "")) != "rival" and str(card.get("band", "")) != "daily":
		fails.append("sib card %s" % str(card.get("id")))


func _kid(id: String, age: int) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.alive = true
	c.is_child = true
	c.age = age
	c.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	c.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.blood_meta = {}
	c.traits = []
	c.in_roster = false
	return c
