extends Node
## CMP-09: road events expanded to >= 48, three exclusive beats per nation,
## every option has an observable consequence, anti-trope words rejected.

const NATIONS := [
	"ashbanner", "shuoying", "qinghe", "lantern", "frostcrown",
	"emberold", "saltmarsh", "irongorge", "starriver", "southzephyr", "landbridge",
]

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL travel events: ", err)
		get_tree().quit(1)
		return
	print("TRAVEL EVENTS PASS")
	get_tree().quit(0)

func _run() -> String:
	GameState.new_game("路遇", "灰旗", "#6ED4FF")
	var events: Array = World.data.get("events", [])
	if events.size() < 48:
		return "event count %d < 48" % events.size()
	var exclusive := {}
	var sea_only := 0
	var saw := {"resource": false, "rep": false, "personnel": false, "flag": false}
	var words := _forbid_words()
	if words.is_empty():
		return "anti-trope word list missing"
	var voice := RegEx.new()
	if voice.compile("第\\d+章|第\\d+卷|v\\d+\\.\\d+") != OK:
		return "voice regex failed"
	for ev in events:
		var id := str(ev.get("id", ""))
		var opts: Array = ev.get("options", [])
		if opts.size() < 2 or opts.size() > 3:
			return "%s option count %d" % [id, opts.size()]
		var blob := str(ev.get("title", "")) + "\n" + str(ev.get("text", ""))
		for o in opts:
			if typeof(o) != TYPE_DICTIONARY:
				return "%s option not dict" % id
			var fx: Dictionary = o.get("fx", {})
			if fx.is_empty():
				return "%s option '%s' has no effect" % [id, str(o.get("label", ""))]
			blob += "\n" + str(o.get("label", ""))
			for k in fx.keys():
				var key := str(k)
				if key in ["silver", "food", "herb", "iron", "lose_cargo", "gain_good", "buy_deal", "days"]:
					saw["resource"] = true
				elif key in ["rep_nation", "rep_dest", "patrol"]:
					saw["rep"] = true
				elif key in ["recruit", "heal", "morale"]:
					saw["personnel"] = true
				elif key == "flag":
					saw["flag"] = true
		var hit := _forbidden(blob, words)
		if hit != "":
			return "%s uses forbidden trope '%s'" % [id, hit]
		if voice.search(blob) != null:
			return "%s uses system-voice phrasing" % id
		var nations: Array = ev.get("nations", [])
		if nations.size() == 1:
			var nid := str(nations[0])
			exclusive[nid] = int(exclusive.get(nid, 0)) + 1
		var kinds: Array = ev.get("kinds", [])
		if kinds.size() == 1 and str(kinds[0]) == "sea":
			sea_only += 1
	for nid in NATIONS:
		if int(exclusive.get(nid, 0)) < 3:
			return "%s exclusive events %d < 3" % [nid, int(exclusive.get(nid, 0))]
	if sea_only < 4:
		return "sea-only events %d < 4" % sea_only
	for cat in saw.keys():
		if not bool(saw[cat]):
			return "catalog missing %s consequence" % cat
	var triggered := 0
	for ev in events:
		var id := str(ev.get("id", ""))
		var pair := _pair(ev)
		var opts: Array = ev.get("options", [])
		for i in opts.size():
			_baseline()
			var made: Dictionary = World.make_event(id, pair[0], pair[1])
			if made.is_empty():
				return "make_event failed for " + id
			var before := _fp()
			var result: Dictionary = World.choose_event(i)
			if not bool(result.get("ok", false)):
				return "%s option %d rejected: %s" % [id, i, str(result.get("msg", ""))]
			var after := _fp()
			if before == after:
				return "%s option %d '%s' had no observable consequence (%s)" % [id, i, str(opts[i].get("label", "")), str(result.get("msg", ""))]
			triggered += 1
		print("OK ", id, " x", opts.size())
	print("triggered ", triggered, " options across ", events.size(), " events")
	return ""

func _baseline() -> void:
	World.rng.seed = 91
	GameState.silver = 8000
	GameState.food = 80
	GameState.herb = 10
	GameState.iron = 8
	GameState.morale = 50
	GameState.skill_points = 1
	World.day = 1
	World.days_total = 5
	World.cargo = {"silk": 8}
	World.tips.clear()
	World.fairs.clear()
	World.intel.clear()
	World.road_flags.clear()
	World.encounter = {}
	World.pending_event = {}
	World.travel = {}
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 20
	for id in World.nodes.keys():
		World.rep_city[str(id)] = 10
	for c in GameState.roster():
		c.hp = 1
		c.injured = true

func _pair(ev: Dictionary) -> PackedStringArray:
	var nid := "ashbanner"
	var nations: Array = ev.get("nations", [])
	if nations.size() > 0:
		nid = str(nations[0])
	var ids := _nodes_of(nid)
	if ids.is_empty():
		return PackedStringArray(["hq", "hq"])
	return PackedStringArray([ids[0], ids[0]])

func _nodes_of(nid: String) -> PackedStringArray:
	var out := PackedStringArray()
	var keys: Array = World.nodes.keys()
	keys.sort()
	for id in keys:
		if World.nation_of(str(id)) == nid:
			out.append(str(id))
	return out

func _fp() -> String:
	var hp := PackedStringArray()
	for c in GameState.roster():
		hp.append("%s:%d:%s" % [str(c.id), int(c.hp), str(c.injured)])
	return "%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%d|%s|%s" % [
		GameState.silver, GameState.food, GameState.herb, GameState.iron, GameState.morale, GameState.skill_points,
		World.days_total, World.day,
		JSON.stringify(World.cargo), JSON.stringify(World.rep_nation), JSON.stringify(World.rep_city),
		JSON.stringify(World.road_flags), JSON.stringify(World.tips), JSON.stringify(World.fairs), JSON.stringify(World.intel),
		GameState.roster().size(), "|".join(hp), str(World.encounter.is_empty()),
	]

func _forbid_words() -> Array:
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/art/style-lock-v89.json")
	if not FileAccess.file_exists(path):
		path = ProjectSettings.globalize_path("res://../docs/art/style-lock-v89.json")
	if not FileAccess.file_exists(path):
		push_error("style lock not found")
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return parsed.get("anti_trope", {}).get("forbid_in_positive", [])

func _forbidden(text: String, words: Array) -> String:
	var low := text.to_lower()
	for w in words:
		var word := str(w).to_lower()
		if word == "":
			continue
		var start := 0
		while true:
			var i := low.find(word, start)
			if i < 0:
				break
			var before_ok := i == 0 or not _is_word_char(low.unicode_at(i - 1))
			var after_i := i + word.length()
			var after_ok := after_i >= low.length() or not _is_word_char(low.unicode_at(after_i))
			if before_ok and after_ok:
				return word
			start = i + 1
	return ""

func _is_word_char(c: int) -> bool:
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
