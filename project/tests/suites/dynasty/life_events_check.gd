extends Node
## DYN-04: sixty life cards, one consequence per option, no repeat for the same person.

const Life := preload("res://scripts/characters/life_events.gd")
const LintScript := preload("res://scripts/narrative/dialogue_lint.gd")
const BANDS := ["birth", "childhood", "education", "adulthood", "marriage", "deathbed", "succession"]

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_catalog(fails)
	_options(fails)
	_years(fails)
	_lint(fails)
	if fails.is_empty():
		print("LIFE EVENTS PASS cards=%d" % Life.events().size())
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL life: ", f)
	get_tree().quit(1)


func _catalog(fails: Array) -> void:
	var rows: Array = Life.events()
	if rows.size() < 60:
		fails.append("count %d" % rows.size())
	var bands := {}
	for event in rows:
		var band := str(event.get("band", ""))
		bands[band] = int(bands.get(band, 0)) + 1
		var options: Array = event.get("options", [])
		if options.size() < 2:
			fails.append("%s options" % str(event.get("id", "")))
		for opt in options:
			if typeof(opt) != TYPE_DICTIONARY or (opt.get("effects", []) as Array).is_empty():
				fails.append("%s effect" % str(event.get("id", "")))
	for band in BANDS:
		if int(bands.get(band, 0)) < 8:
			fails.append("band %s = %s" % [band, str(bands.get(band, 0))])


func _options(fails: Array) -> void:
	for event in Life.events():
		for opt in event.get("options", []):
			GameState.new_game("Ash", "Banner", "frost")
			var leader := GameState.get_leader()
			leader.traits.clear()
			var silver := GameState.silver
			var food := GameState.food
			if not Life.apply_option(leader, opt):
				fails.append("%s/%s no delta" % [str(event.get("id", "")), str(opt.get("id", ""))])
			if GameState.silver != silver or GameState.food != food:
				fails.append("%s moved resources" % str(event.get("id", "")))


func _years(fails: Array) -> void:
	GameState.new_game("Ash", "Banner", "frost")
	_cohort()
	var seen := {}
	for i in 240:
		Calendar.year = 1 + int(i / 12)
		Calendar.month = (i % 12) + 1
		Life.on_month({})
		var pending: Array = (GameState.house_mods.get("life_pending", []) as Array).duplicate()
		for item in pending:
			var cid := str(item.get("cid", ""))
			var eid := str(item.get("id", ""))
			var key := cid + "|" + eid
			seen[key] = int(seen.get(key, 0)) + 1
			if not Life.resolve(cid, eid, "a"):
				fails.append("resolve %s" % key)
	for key in seen.keys():
		if int(seen[key]) != 1:
			fails.append("repeat %s x%s" % [key, str(seen[key])])
	var before := seen.size()
	Life.on_month({})
	var extra: Array = GameState.house_mods.get("life_pending", [])
	if not extra.is_empty() or seen.size() != before:
		# A new card after the pools are dry would be a repeat or an overflow.
		for item in extra:
			var key2 := str(item.get("cid", "")) + "|" + str(item.get("id", ""))
			if seen.has(key2):
				fails.append("requeued %s" % key2)
	var hit := {}
	for key in seen.keys():
		var eid := str(key).split("|")[-1]
		var band := str(Life.find(eid).get("band", ""))
		hit[band] = int(hit.get(band, 0)) + 1
	for band in BANDS:
		if int(hit.get(band, 0)) < 8:
			fails.append("20y band %s = %s" % [band, str(hit.get(band, 0))])


func _lint(fails: Array) -> void:
	var lint = LintScript.new()
	var err := str(lint.load_rules())
	if err != "":
		fails.append(err)
		return
	var report: Dictionary = lint.scan_file("res://data/life_events.json")
	var bad: Array = report.get("violations", [])
	if bad.size() != 0:
		fails.append("lint %s %s" % [str(bad[0].get("rule", "")), str(bad[0].get("detail", ""))])
	if int(report.get("lines", 0)) < 60:
		fails.append("lint lines %s" % str(report.get("lines", 0)))


func _cohort() -> void:
	var parent := GameState.get_leader()
	parent.age = 34
	var spouse := _make("spouse", 28, "lt_filament")
	parent.spouse_id = spouse.id
	spouse.spouse_id = parent.id
	var infant := _make("infant", 0, "ash_chart")
	infant.parent_ids = [parent.id]
	var child := _make("child", 4, "ash_chart")
	child.parent_ids = [parent.id]
	var student := _make("student", 10, "ash_chart")
	student.parent_ids = [parent.id]
	var kin := _make("kin", 12, "ash_chart")
	kin.parent_ids = [parent.id]
	var elder := _make("elder", 64, "ash_chart")


func _make(id: String, age: int, line: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.age = age
	c.alive = true
	c.in_roster = false
	c.blood_mix = {line: 1.0}
	GameState.characters[id] = c
	return c
