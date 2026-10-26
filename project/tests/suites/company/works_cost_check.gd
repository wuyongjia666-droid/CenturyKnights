extends Node
## Audit #18: buildings no longer share one price; the page shows the price it charges.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL works cost: ", err)
		get_tree().quit(1)
	else:
		print("WORKS COST PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var seen := {}
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		var c: Dictionary = CKEconomyState.building_cost(GameState, id, 2)
		seen[str(c)] = true
		if int(c.silver) <= 0 or int(c.food) <= 0:
			return "%s cost %s" % [id, str(c)]
	if seen.size() < 5:
		return "costs still shared: %s" % str(seen.keys())
	var page = load("res://scenes/hub/works.tscn").instantiate()
	add_child(page)
	await get_tree().process_frame
	var ys := {}
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		var b := page.find_child("WorksUpgrade_%s" % id, true, false) as Button
		if b == null:
			b = page.find_child("up_%s" % id, true, false) as Button
		if b == null or b.size.y < 48 or b.size.x > 120:
			return "button %s" % id
		ys[b.position.x] = true
		if page.find_child("next_%s" % id, true, false) == null:
			return "no next-level effect for %s" % id
	if ys.size() != 1:
		return "upgrade buttons not aligned"
	var want: Dictionary = CKEconomyState.building_cost(GameState, "forge", 2)
	GameState.silver = int(want.silver)
	GameState.iron = int(want.iron)
	GameState.food = int(want.food)
	var r: Dictionary = GameState.upgrade_building("forge")
	if not bool(r.ok) or GameState.silver != 0 or GameState.iron != 0:
		return "charged differently than shown %s" % str(r)
	if bool(GameState.upgrade_building("hall").ok):
		return "broke but upgraded"
	return ""
