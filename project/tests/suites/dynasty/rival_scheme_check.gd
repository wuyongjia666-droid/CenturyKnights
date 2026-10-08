extends Node
## DYN-03: ten rival houses, each with an original creed, and at least one scheme in forty years.

const FORBID := ["精灵", "尖耳", "金瞳", "金发", "蓝胎记", "青胎记", "冠冕", "pointed ear", "elf", "golden eye", "blond", "crown", "tiara"]

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_houses(fails)
	_sim(fails)
	_counter(fails)
	if fails.is_empty():
		print("RIVAL SCHEME PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL rival scheme: ", f)
	get_tree().quit(1)

func _houses(fails: Array) -> void:
	var rows: Array = CKSchemes.houses()
	if rows.size() != 10:
		fails.append("expected 10 houses, got %d" % rows.size())
	var nations := {}
	for h in rows:
		var id := str(h.get("id", ""))
		var nid := str(h.get("nation", ""))
		if id == "" or nid == "" or id != nid:
			fails.append("house id must be its nation id (%s / %s)" % [id, nid])
		if nations.has(nid):
			fails.append("duplicate nation %s" % nid)
		nations[nid] = true
		if str(h.get("name", "")) == "" or str(h.get("creed", "")) == "":
			fails.append("%s missing name or creed" % id)
		var blob := "%s %s %s" % [h.get("name", ""), h.get("creed", ""), h.get("desc", "")]
		for w in FORBID:
			if blob.find(w) >= 0:
				fails.append("%s hits anti-trope %s" % [id, w])
		var band := CKSchemes.band_of(CKSchemes.opening_relation(id))
		if band != str(h.get("stance", "")) and str(h.get("stance", "")) != "sworn":
			fails.append("%s opening band %s != stance %s" % [id, band, h.get("stance", "")])
	for nid in CKBloodline.nation_ids():
		if not nations.has(str(nid)):
			fails.append("no rival house for %s" % nid)

func _sim(fails: Array) -> void:
	var st: Dictionary = CKCourt.simulate(40, 7)
	var nations: Dictionary = st.get("nations", {})
	if nations.size() != 10:
		fails.append("court sim nations %d" % nations.size())
	for nid in nations.keys():
		var house: Dictionary = nations[nid]
		var n := 0
		for ev in house.get("schemes", []):
			if typeof(ev) == TYPE_DICTIONARY and not bool(ev.get("foiled", false)):
				n += 1
		if n < 1:
			fails.append("%s fired no scheme in 40 years" % nid)
		if typeof(house.get("log")) == TYPE_ARRAY:
			for ev2 in house.get("log", []):
				if typeof(ev2) == TYPE_DICTIONARY and str(ev2.get("kind", "")) in CKSchemes.KINDS:
					fails.append("scheme kind leaked into the court log")
					return

func _counter(fails: Array) -> void:
	var house := {"relation": -40, "schemes": []}
	var ev := {"year": 3, "house": "shuoying", "kind": "probe", "relation_delta": -4, "foiled": false, "text": "刺探。"}
	house["relation"] = -40 + int(ev["relation_delta"])
	var fixed: Dictionary = CKSchemes.apply_counter(house, ev)
	if not bool(fixed.get("foiled", false)):
		fails.append("counter did not foil the scheme")
	if str(fixed.get("counter", "")) != "embassy":
		fails.append("counter is not the embassy hook")
	if int(house.get("relation", 0)) != -36:
		fails.append("embassy counter relation %s (want -36)" % str(house.get("relation")))
	if CKSchemes.band_of(80) != "sworn" or CKSchemes.band_of(-40) != "hostile":
		fails.append("relation bands drifted")
