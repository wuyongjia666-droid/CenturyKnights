extends Node
## DYN-02: every dynasty ambition has a decidable condition, and each scripted generation can finish one.

const Amb := preload("res://scripts/characters/ambitions.gd")

const FORBID := ["精灵", "尖耳", "金瞳", "金发", "羊皮纸", "鎏金", "elf", "elven", "blond", "golden eye", "pointed ear"]

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_catalog(fails)
	_each(fails)
	_generations(fails)
	_idle_month(fails)
	if fails.is_empty():
		print("AMBITION PASS count=%d" % Amb.rows().size())
		print("AMBITION HANDOFF company: call CKAmbitions.generation_probe() after each succession. It records a stele title and does not touch silver, food, traits, or roster.")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL ambition: ", f)
	get_tree().quit(1)


func _catalog(fails: Array) -> void:
	var rows: Array = Amb.rows()
	if rows.size() < 15:
		fails.append("count %d" % rows.size())
	var seen := {}
	for item in rows:
		var id := str(item.get("id", ""))
		if id == "" or seen.has(id):
			fails.append("bad id %s" % id)
			continue
		seen[id] = true
		if str(item.get("metric", "")) == "":
			fails.append("%s missing metric" % id)
		var name := Locale.t("amb_" + id + "_name")
		var blurb := Locale.t("amb_" + id + "_blurb")
		var title := Locale.t("amb_" + id + "_title")
		if name == "amb_" + id + "_name" or blurb.begins_with("amb_") or title.begins_with("amb_"):
			fails.append("%s missing locale" % id)
		var blob := "%s %s %s" % [name, blurb, title]
		for word in FORBID:
			if blob.find(word) >= 0:
				fails.append("%s anti-trope %s" % [id, word])
	var leader := _boot()
	var offer: Array = Amb.open_offer(leader)
	if offer.size() != 3:
		fails.append("offer %d" % offer.size())


func _each(fails: Array) -> void:
	for item in Amb.rows():
		var id := str(item.get("id", ""))
		var leader := _boot()
		_satisfy(item)
		var silver := GameState.silver
		var food := GameState.food
		GameState.house_mods["dyn_leader"] = leader.id
		GameState.house_mods["dyn_offers"] = id
		if not Amb.choose(id):
			fails.append("%s choose" % id)
			continue
		if not Amb.met(item):
			fails.append("%s not met" % id)
			continue
		Amb.on_month({})
		if Amb.title_of(id) not in leader.honors:
			fails.append("%s stele" % id)
		if int(Amb.honor_bonus().get("stele", 0)) < 1:
			fails.append("%s honor" % id)
		if GameState.silver != silver or GameState.food != food:
			fails.append("%s moved resources" % id)
		if str(GameState.house_mods.get("dyn_gen_done", "")) != leader.id:
			fails.append("%s generation" % id)


func _generations(fails: Array) -> void:
	_boot()
	var silver := GameState.silver
	for gen in 4:
		var leader := GameState.get_leader()
		leader.id = "gen_%d" % gen
		GameState.characters[leader.id] = leader
		Amb.on_banner(leader)
		var offer: Array = Amb.open_offer(leader)
		if offer.is_empty():
			fails.append("gen %d no offer" % gen)
			break
		_satisfy(Amb.row(str(offer[0])))
		if not Amb.generation_probe():
			fails.append("gen %d probe" % gen)
		if str(GameState.house_mods.get("dyn_gen_done", "")) != leader.id:
			fails.append("gen %d done" % gen)
	if GameState.silver != silver:
		fails.append("probe moved silver")


func _idle_month(fails: Array) -> void:
	_boot()
	var silver := GameState.silver
	var food := GameState.food
	var morale := GameState.morale
	Amb.on_month({})
	if GameState.silver != silver or GameState.food != food or GameState.morale != morale:
		fails.append("idle month moved the house")


func _boot() -> CKCharacter:
	GameState.new_game("Ash", "Banner", "frost")
	return GameState.get_leader()


func _person(id: String, line: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.alive = true
	c.in_roster = true
	c.age = 20
	c.blood_mix = {line: 1.0}
	GameState.characters[id] = c
	return c


func _satisfy(spec: Dictionary) -> void:
	var metric := str(spec.get("metric", ""))
	var leader := GameState.get_leader()
	match metric:
		"blood":
			leader.blood_mix[str(spec.get("line", ""))] = float(spec.get("min", 0.55))
		"lamp":
			leader.blood_meta["lamp_seat"] = "baron"
		"spouse_nations":
			var lines := ["lt_filament", "qh_jade", "sy_eclipse"]
			for i in lines.size():
				var spouse := _person("sp_%d" % i, lines[i])
				var holder := _person("holder_%d" % i, "ash_chart")
				holder.spouse_id = spouse.id
				spouse.spouse_id = holder.id
		"academy":
			Amb.note_academy(int(spec.get("min", 3)))
		"masters":
			for i in int(spec.get("min", 3)):
				var c := _person("master_%d" % i, "ash_chart")
				c.job_id = "warrior"
				c.level = int(spec.get("level", 3))
		"children":
			var child := _person("child_one", "ash_chart")
			child.is_child = true
			leader.children_ids.append(child.id)
		"rank":
			leader.rank = "baron"
		"year":
			Calendar.year = int(spec.get("min", 10))
		"rep":
			GameState.reputation[str(spec.get("realm", "ashland"))] = 80
		"paths":
			GameState.lineage_path["p_a"] = "martial"
			GameState.lineage_path["p_b"] = "scholar"
		"roster":
			for i in int(spec.get("min", 4)):
				_person("roster_%d" % i, "ash_chart")
		"food":
			GameState.food = int(spec.get("min", 80))
		"building":
			GameState.buildings[str(spec.get("building", "shrine"))] = int(spec.get("min", 2))
		"holding":
			GameState.holdings[str(spec.get("holding", "reed_ford"))] = {"level": int(spec.get("min", 2)), "steward_id": ""}
		"trait":
			leader.traits.append(str(spec.get("trait", "heir_mark")))
		"friendly":
			GameState.reputation["ashland"] = 30
			GameState.reputation["riverland"] = 30
			GameState.reputation["qinghe"] = 30
