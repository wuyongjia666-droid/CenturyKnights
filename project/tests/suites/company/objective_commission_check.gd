extends Node
## CMP-04 remainder: five objective contracts stamp BTL-02 victory rules.
## The original seven-kind board draw stays on its own RNG.

const KINDS := ["siege_aid", "bounty", "rescue", "convoy", "intel_race"]

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL objective commission: ", err)
		get_tree().quit(1)
		return
	print("OBJECTIVE COMMISSION PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _templates()
	if err != "":
		return err
	GameState.new_game("委托", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	err = _board_keeps_base_draw()
	if err != "":
		return err
	err = _labels()
	if err != "":
		return err
	var city := "ash_capital"
	World.rep_city[city] = 80
	for kind in KINDS:
		err = _walk(city, kind)
		if err != "":
			return err
	err = _loss_and_retry(city)
	if err != "":
		return err
	return ""

func _templates() -> String:
	var have := {}
	for row in World.data.get("commissions", []):
		have[str(row.get("kind", ""))] = true
	var all := ["deliver", "escort", "hunt", "clear", "defend", "gather", "scout"]
	all.append_array(KINDS)
	if all.size() != 12:
		return "kind list %d" % all.size()
	for kind in all:
		if not have.has(kind):
			return "missing template " + kind
	for kind in KINDS:
		if str(World.OBJECTIVE_VICTORY.get(kind, "")) == "":
			return "no victory for " + kind
	return ""

func _board_keeps_base_draw() -> String:
	var city := "ash_capital"
	World.boards.erase(city)
	var offers: Array = World.board(city)
	var base := 0
	var extra := 0
	for q in offers:
		if str(q.get("id", "")).begins_with("wq_obj_"):
			extra += 1
			if not KINDS.has(str(q.get("kind", ""))):
				return "objective offer kind " + str(q.get("kind", ""))
		elif not bool(q.get("sig", false)) and not bool(q.get("chain", false)):
			base += 1
			if KINDS.has(str(q.get("kind", ""))):
				return "base draw included " + str(q.get("kind", ""))
	if base != World.board_size(city):
		return "base offers %d != %d" % [base, World.board_size(city)]
	if extra != 1:
		return "objective offers %d" % extra
	return ""

func _labels() -> String:
	for kind in KINDS:
		var key := ""
		match kind:
			"siege_aid":
				key = "quest_siege_aid"
			"bounty":
				key = "quest_bounty"
			"rescue":
				key = "quest_rescue"
			"convoy":
				key = "quest_convoy"
			"intel_race":
				key = "quest_intel_race"
		if World.quest_kind_label(kind) != Locale.t(key) or World.quest_kind_label(kind) == key:
			return "label " + kind
	if World.quest_kind_label("deliver") == "":
		return "deliver label"
	return ""

func _walk(city: String, kind: String) -> String:
	GameState.food = 800
	GameState.silver = 8000
	World.pos = city
	World.active.clear()
	World.encounter = {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("objwalk:" + kind)
	var q: Dictionary = World._make_quest(city, kind, 1, r)
	if q.is_empty():
		return kind + " empty"
	if str(q.get("victory", "")) != str(World.OBJECTIVE_VICTORY[kind]):
		return kind + " victory field"
	if str(q.get("desc", "")) == "":
		return kind + " brief"
	World.boards[city].offers.append(q)
	var acc: Dictionary = World.accept_quest(city, str(q.id))
	if not bool(acc.get("ok", false)):
		return "%s accept %s" % [kind, str(acc.get("msg", ""))]
	World.travel_to(str(q.target))
	if World.encounter.is_empty():
		return kind + " no encounter"
	var mp: Dictionary = World.encounter.get("map", {})
	var spec := BattleObjectives.spec(mp)
	if str(spec.get("type", "")) != str(World.OBJECTIVE_VICTORY[kind]):
		return "%s stamped %s" % [kind, str(spec.get("type", ""))]
	var shape := _shape(kind, mp, spec)
	if shape != "":
		return shape
	var rnd := 3 if kind == "siege_aid" else 1
	var won := BattleObjectives.outcome(mp, _win_units(spec), rnd)
	if str(won.get("result", "")) != "win" or str(won.get("reason", "")) != str(spec.get("type", "")):
		return "%s outcome %s" % [kind, str(won)]
	if kind == "bounty":
		var crowded: Array = _win_units(spec)
		crowded.append(_unit("enemy", "", Vector2i(2, 2), 9))
		var still := BattleObjectives.outcome(mp, crowded, 1)
		if str(still.get("result", "")) != "win":
			return "bounty required a rout"
		var alive := BattleObjectives.outcome(mp, [_unit("enemy", "mark", Vector2i(2, 2), 9)], 1)
		if str(alive.get("result", "")) == "win":
			return "bounty won while the mark lived"
	World.on_battle_end(true)
	var live := World.quest_by_id(str(q.id))
	if str(live.get("state", "")) != "ready":
		return kind + " not ready"
	var where := World.turn_in_city(live)
	if World.pos != where:
		World.travel_to(where)
	if World.pos != where:
		return kind + " turn-in city"
	var turned: Dictionary = World.turn_in(str(q.id))
	if not bool(turned.get("ok", false)):
		return "%s turn-in %s" % [kind, str(turned.get("msg", ""))]
	return ""

func _shape(kind: String, mp: Dictionary, spec: Dictionary) -> String:
	match kind:
		"siege_aid":
			if int(spec.get("turns", 0)) != 3:
				return "siege turns"
			var waves: Array = mp.get("reinforcements", [])
			if waves.is_empty() or int(waves[0].get("turn", 0)) != 2:
				return "siege reinforcement"
			var players: Array = mp.get("player_spots", [])
			var tiles: Array = spec.get("tiles", [])
			if players.is_empty() or tiles.is_empty():
				return "siege tiles"
			if int(players[0][0]) != int(tiles[0][0]) or int(players[0][1]) != int(tiles[0][1]):
				return "siege tile is not the deployment square"
		"intel_race":
			var players2: Array = mp.get("player_spots", [])
			var tile = spec.get("tile", [])
			for s in players2:
				if int(s[0]) == int(tile[0]) and int(s[1]) == int(tile[1]):
					return "intel tile is a deployment square"
		"convoy":
			var npcs: Array = mp.get("npcs", [])
			if npcs.is_empty() or str(npcs[0].get("team", "")) != "player":
				return "convoy wagon is not player-controlled"
			var spot: Array = npcs[0].get("spot", [])
			var exit_tile = spec.get("exit_tile", [])
			if int(spot[0]) == int(exit_tile[0]) and int(spot[1]) == int(exit_tile[1]):
				return "convoy already stands on the exit"
		"rescue":
			var captives: Array = mp.get("npcs", [])
			if captives.is_empty() or str(captives[0].get("team", "")) != "ally":
				return "rescue captive"
			if str(captives[0].get("tag", "")) != str(spec.get("unit_tag", "")):
				return "rescue tag"
		"bounty":
			var tags: Array = mp.get("enemy_tags", [])
			if tags.is_empty() or str(tags[0]) != "mark":
				return "bounty tag"
	return ""

func _loss_and_retry(city: String) -> String:
	for kind in ["rescue", "convoy"]:
		var err := _lose_once(city, kind, true)
		if err != "":
			return err
	var kept := _lose_once(city, "bounty", false)
	if kept != "":
		return kept
	World.pos = city
	var qid := ""
	for q in World.active:
		if str(q.get("kind", "")) == "bounty":
			qid = str(q.id)
			World.pos = str(q.target)
	if qid == "":
		return "bounty was erased on defeat"
	var again: Dictionary = World.quest_engage(qid)
	if again.is_empty():
		return "bounty retry did not engage"
	if str(BattleObjectives.spec(again.get("map", {})).get("type", "")) != "boss":
		return "bounty retry map"
	World.on_battle_end(true)
	return ""

func _lose_once(city: String, kind: String, erased: bool) -> String:
	GameState.food = 800
	World.pos = city
	World.active.clear()
	World.encounter = {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("objloss:" + kind)
	var q: Dictionary = World._make_quest(city, kind, 1, r)
	World.boards[city].offers.append(q)
	var acc: Dictionary = World.accept_quest(city, str(q.id))
	if not bool(acc.get("ok", false)):
		return "%s loss accept" % kind
	World.travel_to(str(q.target))
	if World.encounter.is_empty():
		return "%s loss encounter" % kind
	World.on_battle_end(false)
	var live := World.quest_by_id(str(q.id))
	if erased and not live.is_empty():
		return kind + " survived a loss"
	if not erased and live.is_empty():
		return kind + " was erased on a loss"
	return ""

func _win_units(spec: Dictionary) -> Array:
	var kind := str(spec.get("type", ""))
	match kind:
		"defend":
			var units: Array = []
			for tile in spec.get("tiles", []):
				units.append(_unit("player", "", _cell(tile), 8))
			return units
		"seize":
			return [_unit("player", "", _cell(spec.get("tile", [0, 0])), 8)]
		"boss":
			return [_unit("enemy", str(spec.get("unit_tag", "")), Vector2i(1, 1), 0)]
		"protect":
			return [_unit("ally", str(spec.get("unit_tag", "")), Vector2i.ZERO, 8)]
		"escort":
			return [_unit("player", str(spec.get("npc", "")), _cell(spec.get("exit_tile", [0, 0])), 8)]
	return []

func _unit(team: String, tag: String, pos: Vector2i, hp: int) -> Dictionary:
	var who := CKCharacter.new()
	who.hp = hp
	who.max_hp = 10
	return {"char": who, "team": team, "pos": pos, "tag": tag}

func _cell(value) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
