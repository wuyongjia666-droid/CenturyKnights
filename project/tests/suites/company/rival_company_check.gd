extends Node
## CMP-04 world-internal: rival companies steal offers and raise prices;
## one scripted contract chain per nation can be walked to the end.
## Objective-typed commissions wait on BTL-02.

const NATIONS := [
	"ashbanner", "shuoying", "qinghe", "lantern", "frostcrown",
	"emberold", "saltmarsh", "irongorge", "starriver", "southzephyr",
]

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL rival company: ", err)
		get_tree().quit(1)
		return
	print("RIVAL COMPANY PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _static_checks()
	if err != "":
		return err
	GameState.new_game("委托", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = true
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	err = _price_and_clash()
	if err != "":
		return err
	err = _year_of_theft()
	if err != "":
		return err
	World.rivals_enabled = false
	World.on_battle_end(true)
	for chain in World.scripted_chains():
		err = _walk_chain(str(chain.get("id", "")))
		if err != "":
			return err
	return ""

func _static_checks() -> String:
	var chains: Array = World.data.get("contract_chains", [])
	if chains.size() < 10:
		return "chains %d < 10" % chains.size()
	var seen := {}
	for chain in chains:
		var nid := str(chain.get("nation", ""))
		if seen.has(nid):
			return "duplicate chain for " + nid
		seen[nid] = true
		var steps: Array = chain.get("steps", [])
		if steps.size() < 3 or steps.size() > 5:
			return "%s step count %d" % [str(chain.get("id", "")), steps.size()]
	for nid in NATIONS:
		if not seen.has(nid):
			return "missing chain for " + nid
	var rivals: Array = World.data.get("rival_companies", [])
	if rivals.size() < 3 or rivals.size() > 5:
		return "rival count %d" % rivals.size()
	var words := _forbid_words()
	if words.is_empty():
		return "anti-trope word list missing"
	var blob := ""
	for chain in chains:
		blob += str(chain.get("title", "")) + "\n"
		for step in chain.get("steps", []):
			blob += str(step.get("title", "")) + "\n" + str(step.get("brief", "")) + "\n"
	for rv in rivals:
		blob += str(rv.get("name", "")) + "\n" + str(rv.get("blurb", "")) + "\n"
	var hit := _forbidden(blob, words)
	if hit != "":
		return "forbidden trope '%s'" % hit
	return ""

func _price_and_clash() -> String:
	var city := "lt_capital"
	World.rivals_enabled = false
	var base := World.price(city, "silk", "buy")
	World.rivals_enabled = true
	var marked := World.price(city, "silk", "buy")
	if marked <= base:
		return "rival price %d did not rise above %d at %s" % [marked, base, city]
	World.pos = city
	var enc: Dictionary = World.rival_clash()
	if enc.is_empty():
		return "rival clash did not start at " + city
	World.on_battle_end(true)
	if not World.encounter.is_empty():
		return "rival clash encounter was not cleared"
	return ""

func _year_of_theft() -> String:
	var keys: Array = World.nodes.keys()
	keys.sort()
	for id in keys:
		if str(World.node(str(id)).get("kind", "")) == "castle":
			continue
		World.board(str(id))
	var stolen := 0
	for _i in 12:
		var beat: Dictionary = World.tick_rivals()
		stolen += int(beat.get("stolen", 0))
	if stolen < 1:
		return "rivals stole %d offers in 12 beats" % stolen
	print("OK rivals stole ", stolen, " offers")
	return ""

func _walk_chain(chain_id: String) -> String:
	GameState.food = 800
	GameState.silver = 8000
	var started: Dictionary = World.start_scripted_chain(chain_id)
	if not bool(started.get("ok", false)):
		return "%s start: %s" % [chain_id, str(started.get("msg", ""))]
	var guard := 0
	while not World.chain_done(chain_id):
		guard += 1
		if guard > 8:
			return chain_id + " did not finish"
		var st: Dictionary = World.chain_status(chain_id)
		var qid := str(st.get("quest_id", ""))
		var issuer := str(st.get("issuer", ""))
		if qid == "" or issuer == "":
			return "%s lost its current step" % chain_id
		World.pos = issuer
		if bool(st.get("on_board", false)):
			var acc: Dictionary = World.accept_quest(issuer, qid)
			if not bool(acc.get("ok", false)):
				return "%s accept: %s" % [chain_id, str(acc.get("msg", ""))]
		var q := World.quest_by_id(qid)
		if q.is_empty():
			return "%s quest missing after accept" % chain_id
		var dest := str(q.get("target", ""))
		var trip: Dictionary = World.travel_to(dest)
		if World.pos != dest:
			return "%s travel to %s stopped at %s (%s)" % [chain_id, dest, World.pos, str(trip)]
		if str(q.get("state", "")) != "ready":
			return "%s step not ready at %s" % [chain_id, dest]
		var where := World.turn_in_city(q)
		if World.pos != where:
			World.travel_to(where)
		if World.pos != where:
			return "%s could not reach turn-in %s" % [chain_id, where]
		var turned: Dictionary = World.turn_in(qid)
		if not bool(turned.get("ok", false)):
			return "%s turn-in: %s" % [chain_id, str(turned.get("msg", ""))]
	print("OK chain ", chain_id)
	return ""

func _forbid_words() -> Array:
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/art/style-lock-v89.json")
	if not FileAccess.file_exists(path):
		path = ProjectSettings.globalize_path("res://../docs/art/style-lock-v89.json")
	if not FileAccess.file_exists(path):
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
