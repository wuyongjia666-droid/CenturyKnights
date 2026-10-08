class_name StoryConditions
extends RefCounted
## NAR-02：旗标、血统、同伴在场。不挂 autoload。

static func met(cond, roster: Array = []) -> bool:
	if cond == null:
		return true
	if typeof(cond) != TYPE_DICTIONARY or (cond as Dictionary).is_empty():
		return true
	var spec: Dictionary = cond
	if spec.has("all"):
		for item in spec["all"]:
			if not met(item, roster):
				return false
		return true
	if spec.has("any"):
		for item in spec["any"]:
			if met(item, roster):
				return true
		return false
	if spec.has("not"):
		return not met(spec["not"], roster)
	if spec.has("flag") and not GameState.flag(str(spec["flag"])):
		return false
	if spec.has("not_flag") and GameState.flag(str(spec["not_flag"])):
		return false
	if spec.has("any_flag"):
		var hit := false
		for key in spec["any_flag"]:
			if GameState.flag(str(key)):
				hit = true
				break
		if not hit:
			return false
	if spec.has("not_any_flag"):
		for key in spec["not_any_flag"]:
			if GameState.flag(str(key)):
				return false
	if spec.has("bloodline"):
		if not _has_blood(str(spec["bloodline"]), str(spec.get("who", "leader")), roster):
			return false
	if spec.has("companion"):
		if not _has_companion(str(spec["companion"]), roster):
			return false
	return true

static func _roster(roster: Array) -> Array:
	if not roster.is_empty():
		return roster
	if GameState:
		return GameState.roster()
	return []

static var _aliases: Dictionary = {}
static var _aliases_loaded := false

static func _has_companion(token: String, roster: Array) -> bool:
	if token == "":
		return false
	_load_aliases()
	var wanted := {token: true}
	for alt in _aliases.get(token, []):
		wanted[str(alt)] = true
	for c in _roster(roster):
		if c == null:
			continue
		if wanted.has(str(c.cast_key)) or wanted.has(str(c.name)) or wanted.has(str(c.id)):
			return true
	return false

static func _load_aliases() -> void:
	if _aliases_loaded:
		return
	_aliases_loaded = true
	var dir := DirAccess.open("res://data/cast")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast".path_join(name)))
			_walk_cast(data)
		name = dir.get_next()
	dir.list_dir_end()

static func _walk_cast(node) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		var id := str(node.get("id", ""))
		var bits: Array = []
		for key in ["cast_key", "name"]:
			if node.has(key) and str(node[key]) != "":
				bits.append(str(node[key]))
		if id != "" and not bits.is_empty():
			_aliases[id] = bits
		for key in node.keys():
			_walk_cast(node[key])
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			_walk_cast(item)

static func _has_blood(line_id: String, who: String, roster: Array) -> bool:
	if line_id == "":
		return false
	var people: Array = []
	if who == "any":
		people = _roster(roster)
	else:
		var leader = GameState.get_leader() if GameState else null
		if leader != null:
			people = [leader]
	for c in people:
		if c == null:
			continue
		var mix = c.blood_mix
		if typeof(mix) == TYPE_DICTIONARY and float(mix.get(line_id, 0.0)) > 0.0:
			return true
	return false
