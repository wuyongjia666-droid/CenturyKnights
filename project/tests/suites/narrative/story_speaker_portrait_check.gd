extends Node
## Every voice in the prologue (ch0) and chapter 1 (era1_01) has a face route: leader,
## companion expression slot, or a supporting_v92 portrait path. Narrator/system excepted.
func _ready() -> void:
	var errors: PackedStringArray = []
	var seen := {}
	for ch in ["ch0", "era1_01"]:
		var doc = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters/%s.json" % ch))
		_walk(doc, seen)
	for sp in seen.keys():
		if sp in ["旁白", "系统", "leader", ""]:
			continue
		if UnitArt.companion_slot(sp) == "" and UnitArt.speaker_plate_path(sp) == "":
			errors.append("no portrait route for %s" % sp)
	if errors.is_empty():
		print("STORY SPEAKER PORTRAIT PASS speakers=%d" % seen.size())
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(0 if errors.is_empty() else 1)

func _walk(x, seen: Dictionary) -> void:
	if x is Dictionary:
		if x.has("speaker"):
			seen[str(x.speaker)] = true
		for v in x.values():
			_walk(v, seen)
	elif x is Array:
		for v in x:
			_walk(v, seen)
