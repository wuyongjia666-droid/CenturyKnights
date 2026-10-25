extends Node
## Y1-A residual: Android APK packs .ctex+.import, not raw .webp. After Mech A medium
## fallback, every desktop↔Android parity plate must still be ResourceLoader-visible
## (the decode path the device actually uses). FileAccess-only success is not enough.

const CHAPTER_DIR := "res://data/story/chapters"

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	CKArtPaths.pack_excluded = Callable()
	if err != "":
		print("FAIL dialogue portrait resloader: ", err)
		get_tree().quit(1)
		return
	print("DIALOGUE PORTRAIT RESLOADER PASS")
	get_tree().quit(0)

func _run() -> String:
	var droid := _filters("Android")
	if droid.is_empty():
		return "Android exclude_filter missing"
	GameState.new_game("烬行", "灰旗", "#6ED4FF")
	var refs := _speaker_refs()
	if refs.size() < 20:
		return "too few refs (%d)" % refs.size()
	var bad: PackedStringArray = []
	var checked := 0
	for key in refs.keys():
		var sp: String = str(refs[key]["speaker"])
		var emo: String = str(refs[key]["emotion"])
		CKArtPaths.pack_excluded = func(p): return _excluded(p, droid)
		UnitArt._cache.clear()
		CKArtPaths.last_loaded = ""
		var who = _who(sp)
		var tex = UnitArt.dialogue_portrait(sp, emo, who, 420)
		CKArtPaths.pack_excluded = Callable()
		if tex == null:
			bad.append("%s: android resolve null" % key)
			continue
		var loaded := CKArtPaths.last_loaded
		if loaded == "":
			# silhouette / procedural — no disk path; OK
			continue
		checked += 1
		if not ResourceLoader.exists(loaded):
			bad.append("%s: ResourceLoader miss for %s" % [key, loaded])
			continue
		var rl = load(loaded)
		if not (rl is Texture2D):
			bad.append("%s: load(%s) not Texture2D" % [key, loaded])
	print("RESLOADER checked=%d refs=%d" % [checked, refs.size()])
	if not bad.is_empty():
		return "; ".join(bad)
	return ""

func _who(sp: String):
	if sp == "leader" or sp == "旁白":
		return GameState.get_leader()
	for c in GameState.characters.values():
		if str(c.name) == sp or str(c.cast_key) == sp:
			return c
	return null

func _speaker_refs() -> Dictionary:
	var out: Dictionary = {}
	var da := DirAccess.open(CHAPTER_DIR)
	if da == null:
		return out
	for fn in da.get_files():
		if not str(fn).ends_with(".json") or str(fn) == "lint_clean.json":
			continue
		_walk(JSON.parse_string(FileAccess.get_file_as_string(CHAPTER_DIR + "/" + fn)), out)
	return out

func _walk(node, out: Dictionary) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		var d: Dictionary = node
		if d.has("speaker") and d.has("text"):
			var sp := str(d["speaker"])
			var emo := str(d.get("expression", d.get("emotion", "")))
			var key := "%s|%s" % [sp, emo]
			if not out.has(key):
				out[key] = {"speaker": sp, "emotion": emo}
		for v in d.values():
			_walk(v, out)
	elif typeof(node) == TYPE_ARRAY:
		for v in node:
			_walk(v, out)

func _filters(preset: String) -> PackedStringArray:
	var cf := ConfigFile.new()
	if cf.load("res://export_presets.cfg") != OK:
		return PackedStringArray()
	for sec in cf.get_sections():
		if str(cf.get_value(sec, "name", "")) == preset:
			return str(cf.get_value(sec, "exclude_filter", "")).split(",", false)
	return PackedStringArray()

static func _excluded(path: String, filters: PackedStringArray) -> bool:
	var rel := path.trim_prefix("res://")
	for f in filters:
		var ff := str(f).strip_edges()
		if ff != "" and (rel.matchn(ff) or ("res://" + rel).matchn("res://" + ff)):
			return true
	return false
