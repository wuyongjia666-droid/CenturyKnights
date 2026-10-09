extends Node
## NAR-09: seed 91 and constructed dynasty states land on different endings.

const LintScript := preload("res://scripts/narrative/dialogue_lint.gd")
const EndingsScript := preload("res://scripts/narrative/endings.gd")


func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL endings: ", err)
		get_tree().quit(1)
		return
	print("ENDINGS PASS")
	get_tree().quit(0)


func _run() -> String:
	var lint_err := _lint()
	if lint_err != "":
		return lint_err
	var report: Dictionary = CKCampaignSim.run(100, 91)
	var locked := _locked(report)
	if locked != "":
		return locked
	var seed: Dictionary = EndingsScript.resolve()
	var seed_err := _seed(report, seed)
	if seed_err != "":
		return seed_err
	var blobs := {}
	var forced := {
		"end_sign": Callable(self, "_sign_state"),
		"end_marry": Callable(self, "_marry_state"),
		"end_rite": Callable(self, "_rite_state"),
		"end_ledger": Callable(self, "_ledger_state"),
		"end_people": Callable(self, "_people_state"),
		"end_empty": Callable(self, "_empty_state"),
	}
	var away := 0
	for id in ["end_sign", "end_marry", "end_rite", "end_ledger", "end_people", "end_empty"]:
		forced[id].call()
		var got: Dictionary = EndingsScript.resolve()
		if str(got.get("id", "")) != id:
			return "%s resolved %s axes %s" % [id, str(got.get("id", "")), str(got.get("axes", {}))]
		var body := _body(got)
		if body != "":
			return id + " " + body
		blobs[id] = _blob(got)
		if id != str(seed.get("id", "")):
			away += 1
	if away < 3:
		return "seed %s collided with the constructed states" % str(seed.get("id", ""))
	if blobs.size() != 6:
		return "blobs %d" % blobs.size()
	var seen := {}
	for id in blobs.keys():
		if seen.has(blobs[id]):
			return "same text %s and %s" % [id, str(seen[blobs[id]])]
		seen[blobs[id]] = id
	return _details()


func _locked(report: Dictionary) -> String:
	if int(report.get("silver_end", -1)) != 5774:
		return "silver %s" % str(report.get("silver_end", ""))
	if int(report.get("food_end", -1)) != 280:
		return "food %s" % str(report.get("food_end", ""))
	if int(report.get("generations", -1)) != 5:
		return "generations %s" % str(report.get("generations", ""))
	if int(report.get("births", -1)) != 15:
		return "births %s" % str(report.get("births", ""))
	if int(report.get("successions", -1)) != 4:
		return "successions %s" % str(report.get("successions", ""))
	if str(report.get("title_end", "")) != "count":
		return "title %s" % str(report.get("title_end", ""))
	return ""


func _seed(report: Dictionary, seed: Dictionary) -> String:
	if int(GameState.silver) != int(report.get("silver_end", -1)):
		return "resolve moved silver"
	if str(seed.get("id", "")) != "end_rite":
		return "seed 91 ending %s axes %s" % [str(seed.get("id", "")), str(seed.get("axes", {}))]
	var axes: Dictionary = seed.get("axes", {})
	if bool(axes.get("sign", true)) or str(axes.get("married_house", "x")) != "":
		return "seed axes drifted %s" % str(axes)
	if not bool(axes.get("prestige", false)) or not bool(axes.get("faith", false)):
		return "seed prestige/faith %s" % str(axes)
	if int(axes.get("holdings", -1)) != 4 or int(axes.get("silver", -1)) != 5774:
		return "seed ledger axes %s" % str(axes)
	if int(axes.get("companions", -1)) != 0:
		return "seed companions %s" % str(axes)
	var closed := bool(axes.get("generation_closed", false))
	if closed != CKAmbitions.generation_probe():
		return "seed probe diverged"
	if str(seed.get("title", "")) == str(seed.get("title_key", "")):
		return "title key missing"
	var text := _texts(seed)
	if text.find("5774") < 0 or text.find("4处据点") < 0:
		return "rite ending hid the treasury"
	if closed:
		if text.find("声望没有替他们把这一行写完") < 0:
			return "closed stele missing"
		if text.find("志向那一栏空着") >= 0:
			return "open beat leaked"
	else:
		if text.find("志向那一栏空着") < 0:
			return "open generation missing"
		if text.find("声望没有替他们把这一行写完") >= 0:
			return "closed stele showed without a generation"
	return _body(seed)


func _details() -> String:
	_people_state()
	var people: Dictionary = EndingsScript.resolve()
	var ids := {}
	for line in people.get("lines", []):
		ids[str(line.get("id", ""))] = true
	if not ids.has("end_people_l001") or not ids.has("end_people_l002") or ids.has("end_people_l003"):
		return "companion lines %s" % str(ids.keys())
	var arm_err := _close_by_probe()
	if arm_err != "":
		return arm_err
	var closed: Dictionary = EndingsScript.resolve()
	if str(closed.get("id", "")) != "end_empty" or not bool(closed.get("axes", {}).get("generation_closed", false)):
		return "generation probe %s" % str(closed.get("axes", {}))
	if not CKAmbitions.generation_probe():
		return "probe did not stay closed"
	if _texts(closed).find("厅里还是没有人应声") < 0:
		return "stele beat missing"
	if _texts(closed).find("志向那一栏也是空的") >= 0:
		return "open beat leaked into a closed generation"
	GameState.set_flag("e5_lamp_speaks", true)
	var echoed: Dictionary = EndingsScript.resolve()
	var echo_ids := {}
	for line in echoed.get("lines", []):
		echo_ids[str(line.get("id", ""))] = true
	if not echo_ids.has("end_echo_lamp_on") or echo_ids.has("end_echo_lamp_off"):
		return "lamp echo %s" % str(echo_ids.keys())
	_marry_state()
	var resolved: Dictionary = EndingsScript.resolve()
	if str(resolved.get("axes", {}).get("married_house", "")) != "烬图氏":
		return "house %s" % str(resolved.get("axes", {}))
	if _texts(resolved).find("烬图氏") < 0:
		return "marriage ending omitted the house"
	return ""


func _marry_state() -> void:
	_fresh()
	var leader := GameState.get_leader()
	var spouse := CKCharacter.new()
	spouse.id = "end_spouse"
	spouse.name = "侧席"
	spouse.alive = true
	spouse.in_roster = false
	spouse.blood_mix = {"ash_chart": 1.0}
	spouse.spouse_id = leader.id
	leader.spouse_id = spouse.id
	GameState.characters[spouse.id] = spouse


func _sign_state() -> void:
	_fresh()
	var leader := GameState.get_leader()
	leader.blood_mix = {"ash_chart": 0.8, "common_ash": 0.2}


func _rite_state() -> void:
	_fresh()
	GameState.reputation["ashland"] = 80
	GameState.buildings["shrine"] = 3
	GameState.house_mods["doctrine"] = "mercy"
	GameState.doctrine_months = 12


func _ledger_state() -> void:
	_fresh()
	GameState.silver = 900
	GameState.reputation = {"ashland": 0, "riverland": 0}
	GameState.buildings["shrine"] = 1
	GameState.holdings["reed_ford"] = {"level": 1, "steward_id": ""}
	GameState.holdings["stone_slope"] = {"level": 1, "steward_id": ""}


func _people_state() -> void:
	_fresh()
	_companion("pingmei", "深镐·平眉")
	_companion("qiaowai", "东虹·桥外")


func _empty_state() -> void:
	_fresh()


func _close_by_probe() -> String:
	_empty_state()
	var leader := GameState.get_leader()
	if leader == null:
		return "no leader"
	var offers: Array = CKAmbitions.open_offer(leader)
	var armed := ""
	for id in offers:
		if str(id) == "purify_ash":
			continue
		if _arm_offer(str(id), leader):
			armed = str(id)
			break
	if armed == "":
		return "no armable offer %s" % str(offers)
	if not CKAmbitions.met(CKAmbitions.row(armed)):
		return "unmet " + armed
	return ""


func _arm_offer(id: String, leader: CKCharacter) -> bool:
	match id:
		"marked_heir":
			return "heir_mark" in leader.traits
		"decade":
			Calendar.year = 10
		"academy_three":
			GameState.house_mods["dyn_academy"] = 3
		"granary":
			GameState.food = 80
		"shrine_two":
			GameState.buildings["shrine"] = 2
		"lamp_seat":
			leader.blood_meta["lamp_seat"] = "kept"
		"two_paths":
			GameState.lineage_path["end_a"] = "martial"
			GameState.lineage_path["end_b"] = "scholar"
		"rank_baron":
			leader.rank = "baron"
		"heir_born":
			_child(leader)
		"ford_two":
			GameState.holdings["reed_ford"] = {"level": 2, "steward_id": ""}
		"roster_four":
			_extra("end_roster_a")
			_extra("end_roster_b")
		"three_masters":
			for person in [leader, _ally(), _extra("end_master")]:
				person.job_id = "warrior"
				person.level = 3
				person.in_roster = true
		"three_friends":
			GameState.reputation["ashland"] = 30
			GameState.reputation["riverland"] = 30
			GameState.reputation["northroad"] = 30
		"ash_respect":
			GameState.reputation["ashland"] = 80
		"three_marriages":
			_noble_pairs()
		_:
			return false
	return true


func _child(leader: CKCharacter) -> void:
	var child := CKCharacter.new()
	child.id = "end_child"
	child.alive = true
	child.in_roster = false
	child.parent_ids = [leader.id]
	child.blood_mix = {"common_ash": 1.0}
	leader.children_ids = [child.id]
	GameState.characters[child.id] = child


func _ally() -> CKCharacter:
	for person in GameState.characters.values():
		if str(person.cast_key) == "dengying":
			return person
	return _extra("end_ally")


func _extra(pid: String) -> CKCharacter:
	var person := CKCharacter.new()
	person.id = pid
	person.cast_key = pid
	person.alive = true
	person.in_roster = true
	person.blood_mix = {"common_ash": 1.0}
	GameState.characters[pid] = person
	return person


func _noble_pairs() -> void:
	var lines := ["banner_marshal", "sy_night", "river_ward"]
	for i in lines.size():
		var host := _extra("end_host_%d" % i)
		var spouse := _extra("end_noble_%d" % i)
		host.spouse_id = spouse.id
		spouse.spouse_id = host.id
		spouse.blood_mix = {lines[i]: 1.0}


func _fresh() -> void:
	GameState.new_game("烬行", "灰旗", "frost")


func _companion(key: String, display_name: String) -> void:
	var person := CKCharacter.new()
	person.id = "end_" + key
	person.cast_key = key
	person.name = display_name
	person.alive = true
	person.in_roster = true
	person.blood_mix = {"common_ash": 1.0}
	GameState.characters[person.id] = person


func _body(result: Dictionary) -> String:
	var lines: Array = result.get("lines", [])
	if lines.size() < 8:
		return "lines %d" % lines.size()
	var speakers := {}
	var hanzi := 0
	for line in lines:
		speakers[str(line.get("speaker", ""))] = true
		hanzi += _hanzi(str(line.get("text", "")))
	if speakers.size() < 2:
		return "speakers %d" % speakers.size()
	if hanzi < 120:
		return "hanzi %d" % hanzi
	return ""


func _blob(result: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line in result.get("lines", []):
		var id := str(line.get("id", ""))
		if id.begins_with("end_echo_"):
			continue
		parts.append(id + str(line.get("text", "")))
	return "|".join(parts)


func _texts(result: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line in result.get("lines", []):
		parts.append(str(line.get("text", "")))
	return "\n".join(parts)


func _hanzi(text: String) -> int:
	var n := 0
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			n += 1
	return n


func _lint() -> String:
	var lint = LintScript.new()
	var loaded := lint.load_rules()
	if loaded != "":
		return loaded
	var scanned: Dictionary = lint.scan_file("res://data/story/endings.json")
	var hits: Array = scanned.get("violations", [])
	if hits.size() != 0:
		return "lint %s" % str(hits[0])
	if int(scanned.get("lines", 0)) < 60:
		return "lint lines %s" % str(scanned.get("lines", 0))
	return ""
