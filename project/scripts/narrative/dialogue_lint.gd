class_name DialogueLint
extends RefCounted
## NAR-08：对白守则。不挂 autoload。套件测试调用 scan_dir / scan_file。

var rules: Dictionary = {}
var _allowed: Dictionary = {}
var _patterns: Array = []

func load_rules(path: String = "res://data/story/lint_rules.json") -> String:
	if not FileAccess.file_exists(path):
		return "missing rules"
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "rules json"
	rules = data
	_allowed.clear()
	for speaker in rules.get("allowed_speakers", []):
		_allowed[str(speaker)] = true
	_load_cast(str(rules.get("cast_dir", "res://data/cast")))
	_patterns.clear()
	for spec in rules.get("patterns", []):
		if typeof(spec) != TYPE_DICTIONARY:
			return "pattern spec"
		var re := RegEx.new()
		if re.compile(str(spec.get("pattern", ""))) != OK:
			return "bad pattern " + str(spec.get("id", ""))
		_patterns.append({"id": str(spec.get("id", "")), "re": re})
	return ""

func scan_dir(root: String) -> Dictionary:
	var files: Array = []
	_json_files(root, files)
	return _scan_files(files)

func scan_file(path: String) -> Dictionary:
	return _scan_files([path])

func _scan_files(files: Array) -> Dictionary:
	var violations: Array = []
	var lines := 0
	var seen := 0
	for path in files:
		if not FileAccess.file_exists(str(path)):
			violations.append(_hit("missing_file", str(path), "", "absent"))
			continue
		seen += 1
		var data = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
		if data == null:
			violations.append(_hit("json", str(path), "", "parse"))
			continue
		var found: Array = []
		_collect(data, found)
		for line in found:
			lines += 1
			_check_line(line, str(path), violations)
	return {"files": seen, "lines": lines, "violations": violations}

func _check_line(line: Dictionary, path: String, violations: Array) -> void:
	var speaker := str(line.get("speaker", ""))
	var text := str(line.get("text", ""))
	var forbidden: Array = rules.get("forbidden_speakers", [])
	if forbidden.has(speaker):
		violations.append(_hit("system_speaker", path, speaker, speaker))
	if not _allowed.has(speaker):
		violations.append(_hit("unregistered_speaker", path, speaker, speaker))
	for spec in _patterns:
		var re: RegEx = spec["re"]
		if re.search(text) != null:
			violations.append(_hit(str(spec["id"]), path, speaker, text))
	var hanzi := _hanzi_count(text)
	var limit := int(rules.get("max_hanzi", 60))
	if hanzi > limit:
		violations.append(_hit("line_too_long", path, speaker, "%d>%d" % [hanzi, limit]))
	for term in rules.get("anti_trope", []):
		if _term_hit(text, str(term)):
			violations.append(_hit("anti_trope", path, speaker, str(term)))

func _term_hit(text: String, term: String) -> bool:
	if term == "":
		return false
	var ascii := true
	for i in term.length():
		if term.unicode_at(i) > 127:
			ascii = false
			break
	if ascii:
		var re := RegEx.new()
		re.compile("(?i)\\b" + term + "\\b")
		return re.search(text) != null
	return text.contains(term)

func _hanzi_count(text: String) -> int:
	var n := 0
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			n += 1
	return n

func _collect(node, found: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("speaker") and node.has("text"):
			found.append(node)
		for key in node.keys():
			_collect(node[key], found)
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			_collect(item, found)

func _load_cast(root: String) -> void:
	var files: Array = []
	_json_files(root, files)
	for path in files:
		var data = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
		_register_cast(data)

func _register_cast(node) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for key in ["name", "id", "cast_key"]:
			if node.has(key) and typeof(node[key]) == TYPE_STRING and str(node[key]) != "":
				_allowed[str(node[key])] = true
		for key in node.keys():
			_register_cast(node[key])
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			_register_cast(item)

func _json_files(root: String, acc: Array) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var path := root.path_join(name)
			if dir.current_is_dir():
				_json_files(path, acc)
			elif name.ends_with(".json"):
				acc.append(path)
		name = dir.get_next()
	dir.list_dir_end()

func _hit(rule: String, path: String, speaker: String, detail: String) -> Dictionary:
	return {"rule": rule, "file": path, "speaker": speaker, "detail": detail}
