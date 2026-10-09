extends Node
## CORE-07: a 3-year new game saves at most 40% of the main baseline.

const MAIN_CHARS := 299128

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_old_save()
	_three_years()
	if _fails.is_empty():
		print("SAVE SIZE PASS")
		get_tree().quit(0)
		return
	for f in _fails:
		print("FAIL save size: ", f)
	get_tree().quit(1)

func _old_save() -> void:
	var courts: Dictionary = CKCourt.blank_courts(91)
	var nid := str((courts.get("nations", {}) as Dictionary).keys()[0])
	var member: Dictionary = courts["nations"][nid]["members"][0]
	var genome := JSON.stringify(member.get("genome", {}))
	var good := str(World.goods.keys()[0])
	var bumped := World._target_stock("hq", good) + 9
	var data := {
		"schema": "v9.2",
		"version": 1,
		"started": true,
		"surname": "Ash",
		"year": 3,
		"month": 4,
		"characters": {},
		"world_v87": {
			"pos": "hq",
			"day": 2,
			"nodes": [{"id": "fake_static"}],
			"roads": [{"a": "hq", "b": "hq"}],
			"nations": {"fake": {"name": "nope"}},
			"goods": {"fake": {"base": 1}},
			"rules": {"nope": 1},
			"items": [{"id": "fake"}],
			"market": {"hq": {good: bumped}},
			"royal_courts": courts,
		},
	}
	var migrated: Dictionary = GameState.migrate_save_data(data)
	var world: Dictionary = migrated.get("world_v87", {})
	for key in ["nodes", "roads", "nations", "goods", "rules", "items"]:
		if world.has(key):
			_fails.append("static %s survived migrate" % key)
	if int(world.get("market", {}).get("hq", {}).get(good, 0)) != bumped:
		_fails.append("market delta dropped")
	var kept: Dictionary = world.get("royal_courts", {}).get("nations", {}).get(nid, {}).get("members", [{}])[0]
	if JSON.stringify(kept.get("genome", {})) != genome:
		_fails.append("old court genome dropped")
	if not GameState.apply_save_data(migrated):
		_fails.append("old save apply")
		return
	if World.nodes.has("fake_static") or not World.nodes.has("hq"):
		_fails.append("static nodes replaced the atlas")
	if World.stock("hq", good) != bumped:
		_fails.append("market delta did not load")
	if World.pos != "hq" or World.day != 2:
		_fails.append("travel position drifted")
	var back: Dictionary = World.royal_courts.get("nations", {}).get(nid, {}).get("members", [{}])[0]
	if JSON.stringify(back.get("genome", {})) != genome:
		_fails.append("old court genome changed on load")

func _three_years() -> void:
	GameState.rng.seed = 91
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	Calendar.advance(36)
	var built: Dictionary = GameState.build_save_data()
	var text := JSON.stringify(built)
	var chars := text.length()
	var limit := int(MAIN_CHARS * 0.4)
	print("SAVE SIZE chars=%d baseline=%d limit=%d" % [chars, MAIN_CHARS, limit])
	if chars > limit:
		_fails.append("save chars %d above %d" % [chars, limit])
	var world: Dictionary = built.get("world_v87", {})
	for key in ["nodes", "roads", "nations", "goods", "rules", "items", "market"]:
		if world.has(key):
			_fails.append("embedded %s" % key)
	if str(world.get("court_genomes", "")) != "derived":
		_fails.append("court genomes not derived")
	if _has_genome(world.get("royal_courts", {})):
		_fails.append("court genome still embedded")
	var genomes := _genome_map()
	var good := str(World.goods.keys()[0])
	World.market["hq"][good] = World._target_stock("hq", good) + 4
	var stocks := _stocks()
	var rep := JSON.stringify(World.rep_city)
	var intel := JSON.stringify(World.intel)
	if genomes.is_empty():
		_fails.append("no court genomes in memory")
	if not GameState.save_game():
		_fails.append("save_game")
		return
	World.reset()
	if not GameState.load_game():
		_fails.append("load_game")
		return
	var again := _genome_map()
	if again.size() != genomes.size():
		_fails.append("court members %d vs %d" % [again.size(), genomes.size()])
	for cid in genomes.keys():
		if str(again.get(cid, "")) != str(genomes[cid]):
			_fails.append("genome drifted %s" % cid)
			break
	var loaded := _stocks()
	if loaded.size() != stocks.size():
		_fails.append("market cells %d vs %d" % [loaded.size(), stocks.size()])
	for cell in stocks.keys():
		if int(loaded.get(cell, -1)) != int(stocks[cell]):
			_fails.append("stock drifted %s" % cell)
			break
	if JSON.stringify(World.rep_city) != rep or JSON.stringify(World.intel) != intel:
		_fails.append("reputation or intel drifted")
	if World.stock("hq", good) != World._target_stock("hq", good) + 4:
		_fails.append("market delta did not round-trip")

func _genome_map() -> Dictionary:
	var out := {}
	var nations: Dictionary = World.royal_courts.get("nations", {}) if typeof(World.royal_courts) == TYPE_DICTIONARY else {}
	for nid in nations.keys():
		var house: Dictionary = nations[nid] if typeof(nations[nid]) == TYPE_DICTIONARY else {}
		for member in house.get("members", []):
			if typeof(member) != TYPE_DICTIONARY:
				continue
			out[str(member.get("id", ""))] = JSON.stringify(member.get("genome", {}))
	return out

func _stocks() -> Dictionary:
	var out := {}
	for city in World.market.keys():
		var row: Dictionary = World.market[city]
		for g in row.keys():
			out["%s|%s" % [str(city), str(g)]] = int(row[g])
	return out

func _has_genome(node) -> bool:
	if typeof(node) == TYPE_DICTIONARY:
		var row: Dictionary = node
		if row.has("genome"):
			return true
		for key in row.keys():
			if _has_genome(row[key]):
				return true
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			if _has_genome(item):
				return true
	return false
