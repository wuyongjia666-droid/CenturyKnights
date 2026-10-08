extends Node
## NAR-01：故事脊柱、十二同伴、反套路专名。失败 quit(1)。

const CAMPAIGN := "res://data/story/campaign_v92.json"
const COMPANIONS := "res://data/cast/companions_v92.json"
const GUARD := "res://data/story/name_guard.json"
const CAST_DIR := "res://data/cast"
const OBJECTIVES := ["rout", "seize", "defend", "survive", "escort", "boss", "escape", "protect"]
const UNLOCKS := [
	"deploy", "roster", "tavern", "market", "shrine", "forge", "marriage", "lineage",
	"atlas", "quests", "train", "skills", "works", "hourglass", "rite", "estates",
	"dossier", "blood_test", "titles", "court_news", "settings",
]
const NAME_KEYS := ["name", "title", "place", "surname", "given", "hook", "brief", "motive", "contradiction", "beat", "label", "prompt"]

var _fails: Array = []

func _ready() -> void:
	_run()
	if _fails.is_empty():
		print("CAMPAIGN SCHEMA PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL campaign: ", f)
		get_tree().quit(1)

func _run() -> void:
	var camp = _load(CAMPAIGN)
	var cast = _load(COMPANIONS)
	var guard = _load(GUARD)
	if camp == null or cast == null or guard == null:
		return
	if typeof(camp) != TYPE_DICTIONARY or typeof(cast) != TYPE_DICTIONARY:
		_fails.append("root json")
		return
	var chapters: Array = camp.get("chapters", [])
	var comps: Array = cast.get("companions", [])
	var sides: Array = camp.get("side_stories", [])
	var eras: Array = camp.get("eras", [])
	_ok(chapters.size() >= 38 and chapters.size() <= 45, "chapter count %d" % chapters.size())
	_ok(comps.size() == 12, "companion count %d" % comps.size())
	_ok(sides.size() == 20, "side story count %d" % sides.size())
	_ok(eras.size() == 5, "era count %d" % eras.size())

	var by_id := {}
	var era_counts := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var objectives := {}
	var option_at := {}
	var prologue: Array = camp.get("prologue_flags", [])
	var finale := int(camp.get("finale_year", 76))

	for c in chapters:
		if typeof(c) != TYPE_DICTIONARY:
			_fails.append("chapter not object")
			continue
		var id := str(c.get("id", ""))
		_ok(id != "" and not by_id.has(id), "dup or empty chapter " + id)
		by_id[id] = c
		var era := int(c.get("era", 0))
		_ok(era >= 1 and era <= 5, id + " era")
		if era_counts.has(era):
			era_counts[era] = int(era_counts[era]) + 1
		var obj := str(c.get("objective_type", ""))
		_ok(OBJECTIVES.has(obj), id + " objective " + obj)
		objectives[obj] = true
		_ok(str(c.get("title", "")) != "", id + " title")
		_ok(str(c.get("place", "")) != "", id + " place")
		_ok(int(c.get("year", -1)) >= 0, id + " year")
		_ban_system_voice(id, str(c.get("title", "")))
		for u in c.get("unlocks", []):
			_ok(UNLOCKS.has(str(u)), id + " unlock " + str(u))
		var choice = c.get("choice", {})
		var opts: Array = choice.get("options", []) if typeof(choice) == TYPE_DICTIONARY else []
		_ok(opts.size() >= 2, id + " choice")
		for opt in opts:
			_keep_option(id, c, opt, option_at, finale)
		if c.has("lamp"):
			var lamp = c.get("lamp", {})
			_ok(typeof(lamp) == TYPE_DICTIONARY, id + " lamp")
			for opt in lamp.get("options", []):
				_keep_option(id, c, opt, option_at, finale)

	_ok(objectives.size() >= 6, "objective kinds %d" % objectives.size())
	for era in era_counts.keys():
		_ok(int(era_counts[era]) >= 6, "era %s chapters %s" % [str(era), str(era_counts[era])])

	for era in eras:
		var eid := int(era.get("id", 0))
		var turn := str(era.get("turn_chapter", ""))
		_ok(by_id.has(turn), "turn " + turn)
		if by_id.has(turn):
			_ok(int(by_id[turn].get("era", -1)) == eid, "turn era " + turn)

	var comp_ids := {}
	for comp in comps:
		var cid := str(comp.get("id", ""))
		_ok(cid != "" and not comp_ids.has(cid), "dup companion " + cid)
		comp_ids[cid] = comp
		_ok(str(comp.get("name", "")) != "", cid + " name")
		_ok(str(comp.get("motive", "")) != "", cid + " motive")
		var beats: Array = comp.get("arc_beats", [])
		_ok(beats.size() == 3, cid + " beats %d" % beats.size())
		var join := str(comp.get("join_chapter", ""))
		_ok(by_id.has(join), cid + " join " + join)
		if not by_id.has(join):
			continue
		var join_year := int(by_id[join].get("year", 0))
		var death := join_year + (70 - int(comp.get("age_at_join", 0)))
		var debut: Array = by_id[join].get("companions", [])
		_ok(debut.has(cid), cid + " not on stage at join")
		for beat in beats:
			var bid := str(beat.get("chapter", ""))
			_ok(by_id.has(bid), cid + " beat chapter " + bid)
			_ok(str(beat.get("beat", "")) != "", cid + " empty beat")
			if by_id.has(bid):
				var y := int(by_id[bid].get("year", 0))
				_ok(y >= join_year and y < death, "%s beat %s outside life (y=%d join=%d death=%d)" % [cid, bid, y, join_year, death])

	for c in chapters:
		var id := str(c.get("id", ""))
		var year := int(c.get("year", 0))
		for cid in c.get("companions", []):
			_ok(comp_ids.has(str(cid)), id + " unknown " + str(cid))
			if comp_ids.has(str(cid)):
				var comp = comp_ids[str(cid)]
				var join := str(comp.get("join_chapter", ""))
				if by_id.has(join):
					var join_year := int(by_id[join].get("year", 0))
					var death := join_year + (70 - int(comp.get("age_at_join", 0)))
					_ok(year >= join_year and year < death, "%s on stage in %s outside life" % [str(cid), id])
		for cid in c.get("echo", []):
			_ok(comp_ids.has(str(cid)), id + " echo " + str(cid))
		for rid in c.get("reads", []):
			var rs := str(rid)
			if prologue.has(rs) or rs.begins_with("s"):
				continue
			_ok(option_at.has(rs), id + " reads unknown " + rs)
			if option_at.has(rs):
				_ok(int(option_at[rs]) < year, id + " reads future " + rs)
		_check_payoff(c, "choice", by_id, year, finale)
		if c.has("lamp"):
			_check_payoff(c, "lamp", by_id, year, finale)

	var side_flags := {}
	for s in sides:
		var sid := str(s.get("id", ""))
		var flag := str(s.get("flag", ""))
		_ok(sid != "" and flag != "" and not side_flags.has(flag), "side flag " + flag)
		side_flags[flag] = true
		_ok(str(s.get("title", "")) != "" and str(s.get("place", "")) != "" and str(s.get("hook", "")).length() >= 12, sid + " fields")
		var pay := str(s.get("payoff_chapter", ""))
		_ok(by_id.has(pay), sid + " payoff " + pay)
		if by_id.has(pay):
			var reads: Array = by_id[pay].get("reads", [])
			_ok(reads.has(flag), sid + " flag not read by " + pay)
		_ok(int(s.get("era", 0)) >= 1 and int(s.get("era", 0)) <= 5, sid + " era")

	_scan_names(guard)

func _keep_option(chapter_id: String, chapter: Dictionary, opt, option_at: Dictionary, finale: int) -> void:
	if typeof(opt) != TYPE_DICTIONARY:
		_fails.append(chapter_id + " bad option")
		return
	var oid := str(opt.get("id", ""))
	_ok(oid != "" and not option_at.has(oid), "dup option " + oid)
	option_at[oid] = int(chapter.get("year", 0))
	var pay := str(opt.get("payoff_chapter", ""))
	if pay == "ending":
		_ok(int(chapter.get("year", 0)) == finale, oid + " ending too early")
	else:
		_ok(pay != "", oid + " payoff")

func _check_payoff(chapter: Dictionary, key: String, by_id: Dictionary, year: int, finale: int) -> void:
	var block = chapter.get(key, {})
	if typeof(block) != TYPE_DICTIONARY:
		return
	var id := str(chapter.get("id", ""))
	for opt in block.get("options", []):
		var pay := str(opt.get("payoff_chapter", ""))
		var oid := str(opt.get("id", ""))
		if pay == "ending":
			continue
		_ok(by_id.has(pay), oid + " missing payoff " + pay)
		if by_id.has(pay):
			var py := int(by_id[pay].get("year", 0))
			_ok(py > year, oid + " payoff not later")
			var reads: Array = by_id[pay].get("reads", [])
			_ok(reads.has(oid), oid + " not read by " + pay)

func _ban_system_voice(id: String, title: String) -> void:
	var re := RegEx.new()
	re.compile("第[0-9一二三四五六七八九十百千]+章完成|第[0-9一二三四五六七八九十百千]+卷|[vV]\\d+\\.\\d+|卷中段")
	_ok(re.search(title) == null, id + " system voice in title")

func _scan_names(guard: Dictionary) -> void:
	var han: Array = guard.get("han", [])
	var latin: Array = guard.get("latin", [])
	var files: Array = [CAMPAIGN, COMPANIONS]
	var dir := DirAccess.open(CAST_DIR)
	if dir:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if fn.ends_with(".json"):
				var p := CAST_DIR + "/" + fn
				if not files.has(p):
					files.append(p)
			fn = dir.get_next()
	for path in files:
		var data = _load(str(path))
		if data == null:
			continue
		_walk_names(data, han, latin, str(path))

func _walk_names(node, han: Array, latin: Array, path: String) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k in node.keys():
			var v = node[k]
			if NAME_KEYS.has(str(k)) and typeof(v) == TYPE_STRING:
				_check_text(str(v), han, latin, path + ":" + str(k))
			else:
				_walk_names(v, han, latin, path)
	elif typeof(node) == TYPE_ARRAY:
		for v in node:
			_walk_names(v, han, latin, path)

func _check_text(text: String, han: Array, latin: Array, where: String) -> void:
	for h in han:
		_ok(not text.contains(str(h)), where + " contains " + str(h))
	var low := text.to_lower()
	for lat in latin:
		var re := RegEx.new()
		re.compile("\\b" + str(lat).to_lower() + "\\b")
		_ok(re.search(low) == null, where + " contains " + str(lat))

func _load(path: String):
	if not FileAccess.file_exists(path):
		_fails.append("missing " + path)
		return null
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data == null:
		_fails.append("json " + path)
	return data

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
