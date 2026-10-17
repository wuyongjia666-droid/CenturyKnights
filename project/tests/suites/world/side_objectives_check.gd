extends Node
## Review 2026-10-17 P1: side battles (road encounters, hunt/clear/defend commissions) roll one of
## the eight story objectives. Checks the weights, determinism, every base map x every objective
## (tiles in bounds, on foot from the player start, no overlaps) and that a staged win resolves.

const KINDS := ["rout", "seize", "defend", "survive", "escort", "boss", "escape", "protect"]
const ROLLS := 8000

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL side objectives: ", err)
		get_tree().quit(1)
	else:
		print("SIDE OBJECTIVES PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = false
	var err := _weights()
	if err == "":
		err = _all_maps()
	if err == "":
		err = _encounters()
	return err

func _weights() -> String:
	for pool_key in World.SIDE_OBJECTIVE_WEIGHTS.keys():
		var rows: Array = World.SIDE_OBJECTIVE_WEIGHTS[pool_key]
		var total := 0
		for row in rows:
			total += int(row[1])
		var seen := {}
		for i in ROLLS:
			var salt := "%s|w|%d" % [pool_key, i]
			var pick := World.side_objective_roll(pool_key, salt)
			if pick != World.side_objective_roll(pool_key, salt):
				return "roll not deterministic for %s" % salt
			seen[pick] = int(seen.get(pick, 0)) + 1
		for row in rows:
			var share := float(seen.get(str(row[0]), 0)) / ROLLS
			var want := float(row[1]) / total
			if absf(share - want) > 0.03:
				return "%s/%s share %.3f want %.3f" % [pool_key, str(row[0]), share, want]
	var road := {}
	for row in World.SIDE_OBJECTIVE_WEIGHTS["road"]:
		road[str(row[0])] = true
	for k in KINDS:
		if not road.has(k):
			return "road pool misses " + k
	return ""

## A salt that rolls `want` from the road pool.
func _salt_for(want: String) -> String:
	for i in 5000:
		var salt := "force|%s|%d" % [want, i]
		if World.side_objective_roll("road", salt) == want:
			return salt
	return ""

func _all_maps() -> String:
	var ids: Array = []
	for b in World._biome_maps.keys():
		ids.append_array(World._biome_maps[b])
	if ids.size() < 300:
		return "only %d side base maps" % ids.size()
	var counted := 0
	for want in KINDS:
		var salt := _salt_for(want)
		if salt == "":
			return "no salt rolls " + want
		for mid in ids:
			var base: Dictionary = BattleMaps.get_map(str(mid)).duplicate(true)
			if base.has("objective"):
				continue
			var spots: Array = base.get("enemy_spots", [])
			World._stamp_side_objective(base, "road", {}, salt, spots)
			var why := _valid(base, want)
			if why != "":
				return "%s/%s: %s" % [str(mid), want, why]
			counted += 1
	return "" if counted >= 300 * KINDS.size() else "only %d stamped" % counted

func _walkable(base: Dictionary, reach: Dictionary, raw) -> bool:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
		return false
	var c := Vector2i(int(raw[0]), int(raw[1]))
	if c.x < 0 or c.y < 0 or c.x >= int(base.w) or c.y >= int(base.h):
		return false
	return reach.has(c)

func _valid(base: Dictionary, want: String) -> String:
	if want == "rout":
		return "" if not base.has("objective") else "rout stamped an objective"
	var obj: Dictionary = BattleObjectives.spec(base)
	if str(obj.type) != want or str(base.get("side_objective", "")) != want:
		return "type %s" % str(obj.type)
	var reach: Dictionary = World._reach(base)
	var taken: Array = base.get("player_spots", []).duplicate()
	taken.append_array(base.get("enemy_spots", []))
	var tiles: Array = []
	match want:
		"seize":
			tiles = [obj.get("tile")]
		"defend":
			tiles = obj.get("tiles", [])
		"escape":
			tiles = obj.get("exit_tiles", [])
			if tiles.size() < 2 or str(tiles[0]) == str(tiles[1]) or int(obj.n) < 1 or int(obj.n) > tiles.size():
				return "escape tiles %s" % str(tiles)
		"escort":
			tiles = [obj.get("exit_tile")]
		"survive":
			return "" if int(obj.get("turns", 0)) > 0 else "survive turns"
		"boss":
			return "" if base.get("enemy_tags", []).has(str(obj.unit_tag)) else "boss tag missing"
	for t in tiles:
		if not _walkable(base, reach, t):
			return "objective tile %s not reachable" % str(t)
	if want == "protect" or want == "escort":
		var npc: Dictionary = base.get("npcs", [{}])[0]
		if not _walkable(base, reach, npc.get("spot")) or World._spot_taken(taken, int(npc.spot[0]), int(npc.spot[1])):
			return "npc spot %s" % str(npc.get("spot"))
		if str(npc.get("name", "")).begins_with("side_npc"):
			return "npc name not localised"
	return ""

## Real encounters: same state replays the same objective, and a staged win resolves as a win.
func _encounters() -> String:
	var seen := {}
	for i in 60:
		World._enc_seq = i
		var a: Dictionary = World.start_encounter("road", {"node": World.pos, "from": World.pos}).get("map", {})
		World._enc_seq = i
		var b: Dictionary = World.start_encounter("road", {"node": World.pos, "from": World.pos}).get("map", {})
		if str(a.get("objective", {})) != str(b.get("objective", {})):
			return "encounter %d not deterministic" % i
		var kind := str(BattleObjectives.spec(a).type)
		seen[kind] = true
		if BattleObjectives.summary(a, [], 1).title == BattleObjectives.text("obj_unknown"):
			return "no objective title for " + kind
		var why := _staged_win(a)
		if why != "":
			return "encounter %d %s: %s" % [i, kind, why]
	World.encounter = {}
	return "" if seen.size() >= 4 else "only %s in 60 road encounters" % str(seen.keys())

func _unit(team: String, pos, tag: String = "") -> Dictionary:
	var c := CKCharacter.new()
	c.hp = 10
	c.is_leader = false
	return {"char": c, "pos": Vector2i(int(pos[0]), int(pos[1])), "team": team, "tag": tag}

func _staged_win(m: Dictionary) -> String:
	var obj: Dictionary = BattleObjectives.spec(m)
	var units: Array = [_unit("player", m.player_spots[0]), _unit("player", m.player_spots[1 % m.player_spots.size()])]
	var round_no := 1
	match str(obj.type):
		"seize":
			units[0].pos = Vector2i(int(obj.tile[0]), int(obj.tile[1]))
			units.append(_unit("enemy", m.enemy_spots[0]))
		"defend":
			round_no = int(obj.turns)
		"survive":
			round_no = int(obj.turns)
			units.append(_unit("enemy", m.enemy_spots[0]))
		"escape":
			units[0].pos = Vector2i(int(obj.exit_tiles[0][0]), int(obj.exit_tiles[0][1]))
			units[1].pos = Vector2i(int(obj.exit_tiles[1][0]), int(obj.exit_tiles[1][1]))
			units.append(_unit("enemy", m.enemy_spots[0]))
		"escort":
			units.append(_unit("player", obj.exit_tile, str(obj.npc)))
		"protect":
			units.append(_unit("ally", m.npcs[0].spot, str(obj.unit_tag)))
		"boss":
			var dead := _unit("enemy", m.enemy_spots[0], str(obj.unit_tag))
			dead.char.hp = 0
			units.append(dead)
	var res: Dictionary = BattleObjectives.outcome(m, units, round_no)
	return "" if str(res.result) == "win" else "staged win gave %s" % str(res)
