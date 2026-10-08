class_name Bonds
extends RefCounted
## NAR-04：同伴羁绊。BTL-09 读 rank()，不要在战斗公式里复写阈值。
##
## Bonds.rank(a, b) -> String
##   返回 "C"、"B"、"A"，或尚未结阶时的空字符串。
##   a、b 可以是同伴 id、cast_key，或名册上的名字。
## Bonds.points(a, b) -> int
##   累计点数。相邻一场 +1，事件用 note_event 另加。
##   C 要 2 点，B 要 5 点，A 要 9 点。
## Bonds.note_adjacent(a, b) -> String
##   记一场相邻作战，返回升阶后的 rank()。
## Bonds.note_battle(units) -> int
##   战斗结束时调用。units 与 BattleController.units 同形：
##   {char, pos, team}。只统计存活的己方同伴，切比雪夫距离为 1 算相邻。
##   每对每场最多 +1。返回本场记上的对数。
## Bonds.note_event(a, b, amount) -> String
##   剧情事件加点。amount 默认 1。

const DIR := "res://data/story/supports"
const CAST := "res://data/cast/companions_v92.json"
const NEED := {"C": 2, "B": 5, "A": 9}
const VIEWER_SCENE := "res://scenes/story/support_viewer.tscn"

static var _cast: Dictionary = {}
static var _convos: Array = []


static func rank(a, b) -> String:
	var pts := points(a, b)
	if pts >= int(NEED["A"]):
		return "A"
	if pts >= int(NEED["B"]):
		return "B"
	if pts >= int(NEED["C"]):
		return "C"
	return ""


static func points(a, b) -> int:
	var key := _key(a, b)
	if key == "":
		return 0
	return int(GameState.story.flags.get(key, 0))


static func note_adjacent(a, b) -> String:
	var key := _key(a, b)
	if key == "":
		return ""
	var next := points(a, b) + 1
	GameState.story.flags[key] = next
	GameState.mark_dirty()
	return rank(a, b)


static func note_event(a, b, amount: int = 1) -> String:
	var key := _key(a, b)
	if key == "" or amount == 0:
		return rank(a, b)
	var next := maxi(0, points(a, b) + amount)
	GameState.story.flags[key] = next
	GameState.mark_dirty()
	return rank(a, b)


static func note_battle(units: Array) -> int:
	var pals: Array = []
	for unit in units:
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("team", "")) != "player":
			continue
		var who = unit.get("char", null)
		if who == null or int(who.hp) <= 0:
			continue
		var cid := resolve(str(who.cast_key))
		if cid == "":
			cid = resolve(str(who.name))
		if cid == "":
			continue
		pals.append({"id": cid, "pos": unit.get("pos", Vector2i.ZERO)})
	var n := 0
	for i in pals.size():
		for j in range(i + 1, pals.size()):
			if not _adjacent(pals[i]["pos"], pals[j]["pos"]):
				continue
			note_adjacent(pals[i]["id"], pals[j]["id"])
			n += 1
	return n


static func available() -> Array:
	var out: Array = []
	for convo in conversations():
		var have := rank(str(convo.get("a", "")), str(convo.get("b", "")))
		if _rank_value(have) >= _rank_value(str(convo.get("rank", ""))):
			out.append(convo)
	return out


static func conversations() -> Array:
	if not _convos.is_empty():
		return _convos
	var dir := DirAccess.open(DIR)
	if dir == null:
		return _convos
	var file_names: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()
	for support_file in file_names:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(str(support_file))))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var rows = parsed.get("conversations", [])
		if typeof(rows) != TYPE_ARRAY:
			continue
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY:
				_convos.append(row)
	return _convos


static func resolve(token: String) -> String:
	_ensure_cast()
	var raw := token.strip_edges()
	if raw == "":
		return ""
	if _cast.has(raw):
		return str(_cast[raw])
	return ""


static func pair_names(convo: Dictionary) -> String:
	_ensure_cast()
	var left := str(_cast.get("name:" + str(convo.get("a", "")), convo.get("a", "")))
	var right := str(_cast.get("name:" + str(convo.get("b", "")), convo.get("b", "")))
	return "%s · %s  %s" % [left, right, str(convo.get("rank", ""))]


static func _key(a, b) -> String:
	var left := resolve(str(a))
	var right := resolve(str(b))
	if left == "" or right == "" or left == right:
		return ""
	if left > right:
		var swap := left
		left = right
		right = swap
	return "bond:%s|%s" % [left, right]


static func _rank_value(rank_id: String) -> int:
	match rank_id:
		"C":
			return 1
		"B":
			return 2
		"A":
			return 3
		_:
			return 0


static func _adjacent(p1, p2) -> bool:
	var a := _cell(p1)
	var b := _cell(p2)
	if a == b:
		return false
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1


static func _cell(value) -> Vector2i:
	if value is Vector2i:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(int(value.x), int(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


static func _ensure_cast() -> void:
	if not _cast.is_empty():
		return
	if not FileAccess.file_exists(CAST):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAST))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for row in parsed.get("companions", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var cid := str(row.get("id", ""))
		if cid == "":
			continue
		_cast[cid] = cid
		_cast[str(row.get("cast_key", ""))] = cid
		_cast[str(row.get("name", ""))] = cid
		_cast["name:" + cid] = str(row.get("name", cid))
