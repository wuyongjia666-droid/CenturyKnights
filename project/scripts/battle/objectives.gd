class_name BattleObjectives
extends RefCounted
## Victory, defeat, and reinforcement rules. Maps without `objective` stay rout.

const CSV_PATH := "res://data/locale/battle.csv"

static var _csv: Dictionary = {}
static var _csv_loaded := false


static func text(key: String) -> String:
	# en lives in battle.csv. Locale.t returns it when the shell language is English
	# and keeps zh_CN otherwise, including when the English cell is empty.
	if Locale != null and (Locale._zh.has(key) or Locale._en.has(key)):
		return Locale.t(key)
	_load_csv()
	return str(_csv.get(key, key))


static func spec(map_data: Dictionary) -> Dictionary:
	var raw = map_data.get("objective", null)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"type": "rout"}
	var out: Dictionary = raw.duplicate(true)
	var kind := str(out.get("type", "rout"))
	if kind == "":
		kind = "rout"
	out["type"] = kind
	return out


static func failure(map_data: Dictionary) -> Dictionary:
	var raw = map_data.get("failure", null)
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw.duplicate(true)


static func next_stage(map_data: Dictionary) -> String:
	return str(map_data.get("next_stage", ""))


static func is_arena(map_data: Dictionary) -> bool:
	return bool(map_data.get("arena", false))


static func skills_allowed(map_data: Dictionary) -> bool:
	var rules = map_data.get("rules", {})
	if typeof(rules) != TYPE_DICTIONARY:
		return true
	return bool(rules.get("skills", true))


static func outcome(map_data: Dictionary, units: Array, round_no: int) -> Dictionary:
	var obj := spec(map_data)
	var fail := failure(map_data)
	var kind := str(obj.get("type", "rout"))
	if _victory_met(kind, obj, units, round_no):
		return {"result": "win", "reason": kind}
	var loss := _failure_reason(kind, obj, fail, units, round_no)
	if loss != "":
		return {"result": "lose", "reason": loss}
	return {"result": "continue", "reason": ""}


static func summary(map_data: Dictionary, units: Array, round_no: int) -> Dictionary:
	var obj := spec(map_data)
	var kind := str(obj.get("type", "rout"))
	var title := text("obj_" + kind)
	if title == "obj_" + kind:
		title = text("obj_unknown")
	var remain := _remain_line(kind, obj, units, round_no)
	var detail := "%s  %s" % [text("obj_round") % round_no, remain]
	return {"title": title, "detail": detail, "kind": kind, "remain": remain}


static func defeat_line(reason: String) -> String:
	match reason:
		"leader_down":
			return text("obj_lose_leader")
		"vip_down":
			return text("obj_lose_vip")
		"turn_limit":
			return text("obj_lose_turns")
		"wipe":
			return text("obj_lose_wipe")
		_:
			return ""


static func deploy_npcs(map_data: Dictionary, units: Array) -> void:
	var npcs = map_data.get("npcs", [])
	if typeof(npcs) != TYPE_ARRAY:
		return
	for npc in npcs:
		if typeof(npc) != TYPE_DICTIONARY:
			continue
		var tag := str(npc.get("tag", ""))
		var who := _make_ally(str(npc.get("name", text("obj_ally"))), tag)
		units.append({
			"char": who,
			"pos": _cell(npc.get("spot", [0, 0])),
			"team": str(npc.get("team", "ally")),
			"done": true,
			"template": "",
			"tag": tag,
		})


static func spawn_due(host, map_data: Dictionary, round_no: int) -> Array:
	var waves = map_data.get("reinforcements", [])
	if typeof(waves) != TYPE_ARRAY:
		return []
	var done = host.get_meta("reinf_done", {})
	if typeof(done) != TYPE_DICTIONARY:
		done = {}
	var spawned: Array = []
	var width := int(host.MAP_W)
	var height := int(host.MAP_H)
	for wave in waves:
		if typeof(wave) != TYPE_DICTIONARY:
			continue
		var wid := str(wave.get("id", ""))
		if wid == "" or done.has(wid):
			continue
		if not _wave_due(wave, round_no, host.units):
			continue
		done[wid] = true
		var spots: Array = wave.get("spots", [])
		var templates: Array = wave.get("templates", [])
		var tags: Array = wave.get("tags", [])
		var team := str(wave.get("team", "enemy"))
		for i in spots.size():
			var want := _cell(spots[i])
			var cell := _free_near(host.units, want, width, height)
			if cell.x < 0:
				continue
			var tmpl := str(templates[i]) if i < templates.size() else "bandit_weak"
			var tag := str(tags[i]) if i < tags.size() else ""
			var unit := _make_unit(team, tmpl, tag, cell, host.rng)
			host.units.append(unit)
			spawned.append(unit)
			if host.has_method("_log"):
				host._log(text("obj_reinf_log") % [cell.x, cell.y])
	host.set_meta("reinf_done", done)
	return spawned


static func _make_unit(team: String, tmpl: String, tag: String, cell: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var who: CKCharacter
	if team == "enemy":
		who = CharacterFactory.make_enemy(tmpl, rng)
	else:
		who = _make_ally(text("obj_ally"), tag)
	return {"char": who, "pos": cell, "team": team, "done": false, "template": tmpl, "tag": tag}


static func _make_ally(who_name: String, tag: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "ally_%s" % tag if tag != "" else "ally_npc"
	c.name = who_name
	c.faction = "ally"
	c.in_roster = false
	c.is_leader = false
	c.job_id = "light_inf"
	c.level = 1
	c.stats = {"str": 4, "vit": 6, "skl": 4, "agi": 5, "per": 4, "wil": 5}
	c.recalc_hp()
	c.hp = c.max_hp
	return c


static func _wave_due(wave: Dictionary, round_no: int, units: Array) -> bool:
	if wave.has("turn") and int(wave.get("turn", -1)) == round_no:
		return true
	if wave.has("trigger_tile"):
		var tile := _cell(wave.get("trigger_tile"))
		for u in units:
			if str(u.team) == "player" and u.char.hp > 0 and u.pos == tile:
				return true
	return false


static func _victory_met(kind: String, obj: Dictionary, units: Array, round_no: int) -> bool:
	match kind:
		"rout":
			return _living(units, "enemy") == 0
		"seize":
			return _occupied_by(units, _cell(obj.get("tile", [-1, -1])), "player")
		"defend":
			return round_no >= int(obj.get("turns", 1)) and _unowned_defend(obj, units) == 0
		"survive":
			return round_no >= int(obj.get("turns", 1)) and _living(units, "player") > 0
		"escort":
			return _tagged_on(units, str(obj.get("npc", "")), _cell(obj.get("exit_tile", [-1, -1])))
		"boss":
			return _tag_deployed(units, str(obj.get("unit_tag", ""))) and _living_tag(units, str(obj.get("unit_tag", ""))) == 0
		"escape":
			return _escaped(units, obj) >= int(obj.get("n", 1))
		"protect":
			var tag := str(obj.get("unit_tag", ""))
			return _tag_deployed(units, tag) and _living_tag(units, tag) > 0 and _living(units, "enemy") == 0
		_:
			return _living(units, "enemy") == 0


static func _failure_reason(kind: String, obj: Dictionary, fail: Dictionary, units: Array, round_no: int) -> String:
	if bool(fail.get("leader_down", false)) and _leader_down(units):
		return "leader_down"
	if kind == "protect" and _tag_deployed(units, str(obj.get("unit_tag", ""))) and _living_tag(units, str(obj.get("unit_tag", ""))) == 0:
		return "vip_down"
	if kind == "escort" and _tag_deployed(units, str(obj.get("npc", ""))) and _living_tag(units, str(obj.get("npc", ""))) == 0:
		return "vip_down"
	var vip := str(fail.get("vip_down", ""))
	if vip != "" and _tag_deployed(units, vip) and _living_tag(units, vip) == 0:
		return "vip_down"
	if fail.has("turn_limit") and round_no > int(fail.get("turn_limit", 0)):
		return "turn_limit"
	if _living(units, "player") == 0:
		return "wipe"
	return ""


static func _remain_line(kind: String, obj: Dictionary, units: Array, round_no: int) -> String:
	match kind:
		"rout", "protect":
			return text("obj_remain_enemies") % _living(units, "enemy")
		"seize":
			var on := _occupied_by(units, _cell(obj.get("tile", [-1, -1])), "player")
			return text("obj_remain_tiles") % (0 if on else 1)
		"defend":
			var left := maxi(0, int(obj.get("turns", 1)) - round_no)
			return "%s · %s" % [text("obj_remain_turns") % left, text("obj_remain_hold") % _unowned_defend(obj, units)]
		"survive":
			return text("obj_remain_turns") % maxi(0, int(obj.get("turns", 1)) - round_no)
		"escape":
			return text("obj_remain_escape") % maxi(0, int(obj.get("n", 1)) - _escaped(units, obj))
		"boss":
			var tag := str(obj.get("unit_tag", ""))
			if _tag_deployed(units, tag) and _living_tag(units, tag) == 0:
				return text("obj_remain_boss_down")
			return text("obj_remain_boss")
		"escort":
			if _tagged_on(units, str(obj.get("npc", "")), _cell(obj.get("exit_tile", [-1, -1]))):
				return text("obj_remain_escort_ok")
			return text("obj_remain_escort")
		_:
			return text("obj_remain_enemies") % _living(units, "enemy")


static func _unowned_defend(obj: Dictionary, units: Array) -> int:
	var tiles = obj.get("tiles", [])
	if typeof(tiles) != TYPE_ARRAY:
		return 0
	var open := 0
	for tile in tiles:
		if not _occupied_by(units, _cell(tile), "player"):
			open += 1
	return open


static func _escaped(units: Array, obj: Dictionary) -> int:
	var tiles = obj.get("exit_tiles", [])
	if typeof(tiles) != TYPE_ARRAY:
		return 0
	var exits: Array = []
	for tile in tiles:
		exits.append(_cell(tile))
	var n := 0
	for u in units:
		if str(u.team) != "player" or u.char.hp <= 0:
			continue
		if exits.has(u.pos):
			n += 1
	return n


static func _leader_down(units: Array) -> bool:
	for u in units:
		if str(u.team) == "player" and u.char.is_leader and u.char.hp <= 0:
			return true
	return false


static func _occupied_by(units: Array, cell: Vector2i, team: String) -> bool:
	for u in units:
		if u.char.hp > 0 and u.pos == cell and str(u.team) == team:
			return true
	return false


static func _tagged_on(units: Array, tag: String, cell: Vector2i) -> bool:
	if tag == "":
		return false
	for u in units:
		if u.char.hp > 0 and _tag_of(u) == tag and u.pos == cell:
			return true
	return false


static func _living(units: Array, team: String) -> int:
	var n := 0
	for u in units:
		if u.char.hp > 0 and str(u.team) == team:
			n += 1
	return n


static func _living_tag(units: Array, tag: String) -> int:
	var n := 0
	for u in units:
		if u.char.hp > 0 and _tag_of(u) == tag:
			n += 1
	return n


static func _tag_deployed(units: Array, tag: String) -> bool:
	if tag == "":
		return false
	for u in units:
		if _tag_of(u) == tag:
			return true
	return false


static func _tag_of(u) -> String:
	return str(u.get("tag", ""))


static func _cell(value) -> Vector2i:
	if value is Vector2i:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-999, -999)


static func _free_near(units: Array, origin: Vector2i, width: int, height: int) -> Vector2i:
	if _open(units, origin, width, height):
		return origin
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) + absi(dy) != radius:
					continue
				var cell := origin + Vector2i(dx, dy)
				if _open(units, cell, width, height):
					return cell
	return Vector2i(-1, -1)


static func _open(units: Array, cell: Vector2i, width: int, height: int) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	for u in units:
		if u.char.hp > 0 and u.pos == cell:
			return false
	return true


static func _load_csv() -> void:
	if _csv_loaded:
		return
	_csv_loaded = true
	if not FileAccess.file_exists(CSV_PATH):
		return
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return
	var first := true
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split(",")
		if parts.size() < 2:
			continue
		var key := parts[0].strip_edges()
		if first and key == "keys":
			first = false
			continue
		first = false
		_csv[key] = parts[1].strip_edges()
