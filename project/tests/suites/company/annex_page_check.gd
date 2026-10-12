extends Node
## Audit #1/#2: overview cards route to each building's own page; annex pages show
## unbuilt / built / maxed / failure / empty states.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL annex page: ", err)
		get_tree().quit(1)
	else:
		print("ANNEX PAGE PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var CV = load("res://scripts/hub/castle_view.gd")
	var seen := {}
	for id in ["hall", "barracks", "market", "forge", "shrine", "infirmary", "academy", "treasury", "embassy"]:
		var p: String = CV.page_for(id)
		if p == "" or not ResourceLoader.exists(p):
			return "no page for %s" % id
		if p.ends_with("works.tscn") and id != "hall":
			return "%s still routes to works" % id
		seen[id] = p
	var view := (load("res://scenes/hub/castle_view.tscn") as PackedScene).instantiate()
	add_child(view)
	await get_tree().process_frame
	for id in ["infirmary", "academy", "treasury", "embassy"]:
		var art := view.find_child("sil_%s_1" % id, true, false) as TextureRect
		if art == null or art.texture == null:
			return "no art for %s" % id
		var go := view.find_child("go_%s" % id, true, false) as Button
		if go == null or not go.disabled:
			return "unbuilt %s should not open" % id
		if (view.find_child("up_%s" % id, true, false) as Button).size.y < 48:
			return "upgrade target < 48"
	view.queue_free()
	for id in ["infirmary", "academy", "treasury", "embassy"]:
		GameState.buildings.erase(id)
		var page = (load("res://scenes/hub/annex.tscn") as PackedScene).instantiate()
		page.set_meta("annex", id)
		add_child(page)
		await get_tree().process_frame
		if page.id != id:
			return "page id %s != %s" % [page.id, id]
		var link := page.find_child("Link", true, false) as Button
		if link == null or not link.disabled:
			return "%s link should wait until built" % id
		GameState.silver = 0
		page._upgrade()
		var m := page.find_child("Msg", true, false) as Label
		if m == null or m.text == "" or page.level() != 0:
			return "%s failure state" % id
		GameState.silver = 999
		GameState.iron = 99
		GameState.food = 99
		for i in 3:
			page._upgrade()
		if page.level() != 3 or not (page.find_child("Upgrade", true, false) as Button).disabled:
			return "%s maxed state" % id
		page.queue_free()
	var acad = (load("res://scenes/hub/annex.tscn") as PackedScene).instantiate()
	acad.set_meta("annex", "academy")
	for c in GameState.characters.values():
		if c.is_child:
			c.alive = false
	add_child(acad)
	await get_tree().process_frame
	if acad.find_child("Empty", true, false) == null:
		return "academy empty state"
	return ""
