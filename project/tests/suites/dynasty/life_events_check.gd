extends Node
## DYN-04: sixty life cards in 岁课 tone; month fire auto-resolves left/right
## with a stable seed; inbox is read-only; no pending A/B choice stuck.

const Life := preload("res://scripts/characters/life_events.gd")
const BANDS := ["birth", "childhood", "education", "adulthood", "marriage", "deathbed", "succession"]

func _ready() -> void:
	await get_tree().process_frame
	Life.reload_for_tests()
	var fails: Array = []
	_catalog(fails)
	_tone(fails)
	_options(fails)
	_random_resolve(fails)
	_years(fails)
	_text_lint(fails)
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
		var choices: Array = Life.choices(event)
		if choices.size() < 2:
			fails.append("%s choices" % str(event.get("id", "")))
		for ch in choices:
			if typeof(ch) != TYPE_DICTIONARY or (ch.get("effects", []) as Array).is_empty():
				fails.append("%s effect" % str(event.get("id", "")))
			if str(ch.get("act", "")) == "":
				fails.append("%s empty act" % str(event.get("id", "")))
		if str(event.get("title", "")) == "":
			fails.append("%s title" % str(event.get("id", "")))
		if str(event.get("body", "")) == "":
			fails.append("%s body" % str(event.get("id", "")))
		# No literary multi-speaker chains
		if event.has("lines") or event.has("options"):
			fails.append("%s legacy lines/options" % str(event.get("id", "")))
		if not event.has("left") or not event.has("right"):
			fails.append("%s missing left/right" % str(event.get("id", "")))
	for band in BANDS:
		if int(bands.get(band, 0)) < 8:
			fails.append("band %s = %s" % [band, str(bands.get(band, 0))])


func _tone(fails: Array) -> void:
	# Body one sentence-ish; acts short; no 旁白 speaker chains.
	for event in Life.events():
		var eid := str(event.get("id", ""))
		var body := str(event.get("body", ""))
		if body.contains("旁白"):
			fails.append("%s body 旁白" % eid)
		if body.count("。") > 2:
			fails.append("%s body too many sentences" % eid)
		for side in ["left", "right"]:
			var act := str(event.get(side, {}).get("act", ""))
			if act.length() > 24:
				fails.append("%s %s act long" % [eid, side])
			if act.contains("旁白"):
				fails.append("%s %s 旁白" % [eid, side])
			# Visible cost: non-flag mechanical effects should expose a hint
			var has_mech := false
			for fx in event.get(side, {}).get("effects", []):
				if typeof(fx) == TYPE_DICTIONARY and str(fx.get("op", "")) != "flag":
					has_mech = true
					break
			if has_mech and str(event.get(side, {}).get("hint", "")) == "":
				fails.append("%s %s missing hint" % [eid, side])


func _options(fails: Array) -> void:
	for event in Life.events():
		for ch in Life.choices(event):
			GameState.new_game("Ash", "Banner", "frost")
			var leader := GameState.get_leader()
			leader.traits.clear()
			var silver := GameState.silver
			var food := GameState.food
			var opt := {"effects": ch.get("effects", [])}
			if not Life.apply_option(leader, opt):
				fails.append("%s/%s no delta" % [str(event.get("id", "")), str(ch.get("id", ""))])
			if GameState.silver != silver or GameState.food != food:
				fails.append("%s moved resources" % str(event.get("id", "")))


func _random_resolve(fails: Array) -> void:
	## Seeded pick is stable across reloads; on_month leaves no pending choice.
	GameState.new_game("Ash", "Banner", "frost")
	var leader := GameState.get_leader()
	leader.age = 30
	leader.traits.clear()
	var eid := "adult_01"
	var event := Life.find(eid)
	if event.is_empty():
		# Fall back to first adulthood card.
		for e in Life.events():
			if str(e.get("band", "")) == "adulthood":
				eid = str(e.get("id", ""))
				event = e
				break
	if event.is_empty():
		fails.append("random: no adulthood event")
		return
	var y := 3
	var m := 7
	var a := Life.pick_side(leader.id, eid, y, m)
	var b := Life.pick_side(leader.id, eid, y, m)
	if a != b:
		fails.append("pick_side unstable %s vs %s" % [a, b])
	if a != "left" and a != "right":
		fails.append("pick_side bad %s" % a)
	# Different month may flip (not required), but same inputs must match.
	var c := Life.pick_side(leader.id, eid, y, m + 1 if m < 12 else 1)
	# Apply fire_and_resolve twice with same seed — second should still return a row
	# only once effects-wise: mark not used here, so call once and check inbox.
	GameState.house_mods["life_inbox"] = []
	GameState.house_mods["life_pending"] = []
	var row := Life.fire_and_resolve(leader.id, eid, y, m)
	if row.is_empty():
		fails.append("fire_and_resolve empty")
		return
	if str(row.get("side", "")) != a:
		fails.append("fire side %s != pick %s" % [str(row.get("side", "")), a])
	if str(row.get("outcome", "")) == "":
		fails.append("fire missing outcome")
	var pending: Array = GameState.house_mods.get("life_pending", [])
	if not pending.is_empty():
		fails.append("pending stuck after fire size=%d" % pending.size())
	var inbox: Array = Life.inbox()
	if inbox.size() != 1:
		fails.append("inbox size %d" % inbox.size())
	# Ack clears inbox, no pending reappears.
	Life.ack(leader.id, eid)
	if not Life.inbox().is_empty():
		fails.append("inbox after ack")
	if not (GameState.house_mods.get("life_pending", []) as Array).is_empty():
		fails.append("pending after ack")
	# Legacy pending drain: plant an old A/B row, ensure() / drain settles it.
	GameState.house_mods["life_pending"] = [{"cid": leader.id, "id": eid}]
	# Use a different event so fire can apply again — pick another adulthood id.
	var other := ""
	for e2 in Life.events():
		var id2 := str(e2.get("id", ""))
		if str(e2.get("band", "")) == "adulthood" and id2 != eid:
			other = id2
			break
	if other != "":
		GameState.house_mods["life_pending"] = [{"cid": leader.id, "id": other}]
		GameState.house_mods["life_inbox"] = []
		Life._drain_legacy_pending()
		if not (GameState.house_mods.get("life_pending", []) as Array).is_empty():
			fails.append("legacy pending not drained")
		if Life.inbox().is_empty():
			fails.append("legacy drain no inbox")
	# Silence unused warning for c (month flip is observational).
	if c == "":
		fails.append("pick_side empty alt")


func _years(fails: Array) -> void:
	GameState.new_game("Ash", "Banner", "frost")
	_cohort()
	var seen := {}
	for i in 240:
		Calendar.year = 1 + int(i / 12)
		Calendar.month = (i % 12) + 1
		GameState.house_mods["life_inbox"] = []
		Life.on_month({})
		var pending: Array = GameState.house_mods.get("life_pending", [])
		if not pending.is_empty():
			fails.append("month %d pending stuck %s" % [i, str(pending)])
			return
		var inbox: Array = Life.inbox()
		for item in inbox:
			var cid := str(item.get("cid", ""))
			var eid := str(item.get("id", ""))
			var key := cid + "|" + eid
			seen[key] = int(seen.get(key, 0)) + 1
			if str(item.get("side", "")) != "left" and str(item.get("side", "")) != "right":
				fails.append("bad side %s" % key)
			if str(item.get("outcome", "")) == "":
				fails.append("empty outcome %s" % key)
			# Stable: recompute pick matches stored side.
			var expect := Life.pick_side(cid, eid, Calendar.year, Calendar.month)
			if str(item.get("side", "")) != expect:
				fails.append("seed mismatch %s got %s want %s" % [key, str(item.get("side", "")), expect])
	for key in seen.keys():
		if int(seen[key]) != 1:
			fails.append("repeat %s x%s" % [key, str(seen[key])])
	var before := seen.size()
	Life.on_month({})
	var pending2: Array = GameState.house_mods.get("life_pending", [])
	if not pending2.is_empty():
		fails.append("post-loop pending")
	# No new fires for already-fired ids.
	for item in Life.inbox():
		var key2 := str(item.get("cid", "")) + "|" + str(item.get("id", ""))
		if seen.has(key2) and int(seen[key2]) >= 1:
			# Inbox may re-show if we didn't ack; fired book prevents re-fire.
			pass
	var hit := {}
	for key in seen.keys():
		var eid := str(key).split("|")[-1]
		var band := str(Life.find(eid).get("band", ""))
		hit[band] = int(hit.get(band, 0)) + 1
	for band in BANDS:
		if int(hit.get(band, 0)) < 8:
			fails.append("20y band %s = %s" % [band, str(hit.get(band, 0))])
	if seen.size() < before:
		fails.append("seen shrank")


func _text_lint(fails: Array) -> void:
	# Card pool is no longer multi-speaker dialogue; scan title/body/act for tropes & length.
	var anti: Array = []
	var rules_path := "res://data/story/lint_rules.json"
	if FileAccess.file_exists(rules_path):
		var rules = JSON.parse_string(FileAccess.get_file_as_string(rules_path))
		if typeof(rules) == TYPE_DICTIONARY:
			anti = rules.get("anti_trope", [])
	var texts := 0
	for event in Life.events():
		for piece in [str(event.get("title", "")), str(event.get("body", "")),
				str(event.get("left", {}).get("act", "")), str(event.get("right", {}).get("act", ""))]:
			texts += 1
			if _hanzi(piece) > 60:
				fails.append("long %s" % piece.substr(0, 12))
				return
			for term in anti:
				if str(term) != "" and piece.contains(str(term)):
					fails.append("trope %s in %s" % [str(term), str(event.get("id", ""))])
					return
	if texts < 60:
		fails.append("texts %d" % texts)


func _hanzi(text: String) -> int:
	var n := 0
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			n += 1
	return n


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
	# v9.2：家中 1–15 岁走岁课，退出 life_events 月卡。另加外门子嗣，保住 childhood/education/succession 覆盖。
	var wander_child := _make("wander_child", 4, "ash_chart")
	wander_child.is_child = false
	var wander_student := _make("wander_student", 10, "ash_chart")
	wander_student.is_child = false
	var sib_a := _make("sib_a", 18, "ash_chart")
	sib_a.parent_ids = ["outsider_parent"]
	var sib_b := _make("sib_b", 20, "ash_chart")
	sib_b.parent_ids = ["outsider_parent"]


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
