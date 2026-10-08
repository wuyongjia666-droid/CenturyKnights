class_name ChapterSchema
extends RefCounted
## NAR-02：章节 JSON 形状。叙事套件执行；tools/ci/json_lint.py 归基础设施，接入时移植本规则。

const OPS := [
	"goto", "set_flag", "set_beat", "battle", "scene",
	"advance", "fast_harvest", "journal", "ensure_reputation", "archive_notice",
]

static func validate(data) -> Array:
	var errors: Array = []
	if typeof(data) != TYPE_DICTIONARY:
		return ["root must be an object"]
	var doc: Dictionary = data
	_str(doc, "id", errors)
	_str(doc, "title", errors)
	if not doc.has("beats") or typeof(doc["beats"]) != TYPE_ARRAY or (doc["beats"] as Array).is_empty():
		errors.append("beats must be a non-empty array")
		return errors
	var beat_ids := {}
	var line_ids := {}
	for beat in doc["beats"]:
		if typeof(beat) != TYPE_DICTIONARY:
			errors.append("beat must be an object")
			continue
		var b: Dictionary = beat
		_str(b, "id", errors)
		_str(b, "title", errors)
		var bid := str(b.get("id", ""))
		if bid != "" and beat_ids.has(bid):
			errors.append("duplicate beat " + bid)
		beat_ids[bid] = true
		if not b.has("lines") or typeof(b["lines"]) != TYPE_ARRAY:
			errors.append(bid + " lines must be an array")
		else:
			for line in b["lines"]:
				if typeof(line) != TYPE_DICTIONARY:
					errors.append(bid + " line must be an object")
					continue
				var row: Dictionary = line
				for key in ["id", "speaker", "text"]:
					if not row.has(key) or typeof(row[key]) != TYPE_STRING or str(row[key]) == "":
						errors.append(bid + " line missing " + key)
				var lid := str(row.get("id", ""))
				if lid != "" and line_ids.has(lid):
					errors.append("duplicate line " + lid)
				line_ids[lid] = true
		if b.has("actions"):
			if typeof(b["actions"]) != TYPE_ARRAY:
				errors.append(bid + " actions must be an array")
			else:
				var action_ids := {}
				for action in b["actions"]:
					_action(bid, action, action_ids, errors)
		if b.has("prepare"):
			if typeof(b["prepare"]) != TYPE_ARRAY:
				errors.append(bid + " prepare must be an array")
			else:
				for step in b["prepare"]:
					_op(bid, step, errors)
	return errors

static func validate_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return ["missing " + path]
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var errors := validate(data)
	var prefixed: Array = []
	for err in errors:
		prefixed.append(path + ": " + str(err))
	return prefixed

static func _action(bid: String, action, seen: Dictionary, errors: Array) -> void:
	if typeof(action) != TYPE_DICTIONARY:
		errors.append(bid + " action must be an object")
		return
	var row: Dictionary = action
	for key in ["id", "label"]:
		if not row.has(key) or typeof(row[key]) != TYPE_STRING or str(row[key]) == "":
			errors.append(bid + " action missing " + key)
	var aid := str(row.get("id", ""))
	if aid != "" and seen.has(aid):
		errors.append(bid + " duplicate action " + aid)
	seen[aid] = true
	if not row.has("do") or typeof(row["do"]) != TYPE_ARRAY:
		errors.append(bid + " action do must be an array")
	else:
		for step in row["do"]:
			_op(bid, step, errors)
	if row.has("when") and typeof(row["when"]) != TYPE_DICTIONARY:
		errors.append(bid + " action when must be an object")

static func _op(bid: String, step, errors: Array) -> void:
	if typeof(step) != TYPE_DICTIONARY:
		errors.append(bid + " op must be an object")
		return
	var row: Dictionary = step
	var op := str(row.get("op", ""))
	if not OPS.has(op):
		errors.append(bid + " unknown op " + op)
		return
	if op == "battle" and str(row.get("map", "")) == "":
		errors.append(bid + " battle missing map")
	if op == "scene" and str(row.get("path", "")) == "":
		errors.append(bid + " scene missing path")
	if op == "set_flag" and str(row.get("flag", "")) == "":
		errors.append(bid + " set_flag missing flag")
	if op == "goto" and str(row.get("beat", "")) == "":
		errors.append(bid + " goto missing beat")

static func _str(row: Dictionary, key: String, errors: Array) -> void:
	if not row.has(key) or typeof(row[key]) != TYPE_STRING or str(row[key]) == "":
		errors.append("missing " + key)
