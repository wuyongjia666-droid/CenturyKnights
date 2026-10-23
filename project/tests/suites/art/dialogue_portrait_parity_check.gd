extends Node
## Y1-A weeks 7–10: desktop ↔ Android dialogue portrait parity, simulated headless.
## Every speaker line in data/story/chapters/*.json is resolved the way chapter_player
## does (_character_named / recruit / leader / narrator → UnitArt.dialogue_portrait) twice:
## once with the Windows preset file set, once with the Android preset file set
## (export_presets.cfg exclude_filter, applied through CKArtPaths.pack_excluded).
## Fails when Android shows a silhouette where desktop shows a plate, or a different face
## (different plate stem). Same stem at a different tier is fine (dialogue asks medium).
## Speakers with no art on either platform must be listed in NO_ART (data gap, not drift).

const CHAPTER_DIR := "res://data/story/chapters"
const REPORT := "user://dialogue_portrait_parity.json"
## Antagonists / supporting rows with no plate anywhere (audit §2.3 机制 D + v92 villains).
## Desktop shows the same silhouette; adding art here is a farm job, not an export fix.
const NO_ART := ["藤桥·新雨", "渡口·阿禾", "镜湖·护帖", "冷窑·收火",
	"观象·孤衡", "碧潭·澜芷", "白垣·计勋", "南灯·欠盏", "冷湾·折弦"]
const RECRUIT_SPEAKERS := ["新来的人"]

var _rows: Array = []

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	CKArtPaths.pack_excluded = Callable()
	if err != "":
		print("FAIL dialogue portrait parity: ", err)
		get_tree().quit(1)
		return
	print("DIALOGUE PORTRAIT PARITY PASS lines=%d" % _rows.size())
	get_tree().quit(0)

func _run() -> String:
	var refs := _speaker_refs()
	if refs.size() < 20:
		return "too few speaker refs (%d) — chapter scan broken?" % refs.size()
	var win := _filters("Windows Desktop")
	var droid := _filters("Android")
	if droid.size() <= win.size():
		return "Android preset should exclude more than Windows (%d vs %d)" % [droid.size(), win.size()]
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	var desk := _resolve_all(refs, win)
	var andr := _resolve_all(refs, droid)
	var bad: Array = []
	var gaps: Array = []
	for key in refs.keys():
		var d: String = desk[key]
		var a: String = andr[key]
		var sp: String = str(refs[key]["speaker"])
		var status := "ok"
		if d == "silhouette" and a == "silhouette":
			status = "no_art"
			if not (sp in NO_ART):
				bad.append("%s: no art on either platform and not in NO_ART" % key)
			gaps.append(sp)
		elif a == "silhouette":
			status = "android_silhouette"
			bad.append("%s: desktop=%s android=silhouette" % [key, d])
		elif _stem(a) != _stem(d):
			status = "different_face"
			bad.append("%s: desktop=%s android=%s" % [key, d, a])
		elif sp in NO_ART:
			bad.append("%s: has art now (%s) — drop it from NO_ART" % [key, a])
		var row := {"key": key, "speaker": sp, "emotion": refs[key]["emotion"], "lines": refs[key]["lines"],
			"chapters": refs[key]["chapters"], "desktop": d, "android": a, "status": status}
		_rows.append(row)
		print("PARITY %-14s %-8s lines=%-4d %-18s desktop=%s android=%s" % [sp, row.emotion, row.lines, status, d, a])
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_rows, " "))
	print("PARITY report ", ProjectSettings.globalize_path(REPORT), " no_art=", gaps)
	if not bad.is_empty():
		return "; ".join(bad)
	return ""

## (speaker|emotion) → {speaker, emotion, lines, chapters}
func _speaker_refs() -> Dictionary:
	var out: Dictionary = {}
	var da := DirAccess.open(CHAPTER_DIR)
	if da == null:
		return out
	for fn in da.get_files():
		if not str(fn).ends_with(".json") or str(fn) == "lint_clean.json":
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CHAPTER_DIR + "/" + fn))
		_walk(parsed, str(fn).get_basename(), out)
	return out

func _walk(node, chapter: String, out: Dictionary) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		var d: Dictionary = node
		if d.has("speaker") and d.has("text"):
			var sp := str(d["speaker"])
			var emo := str(d.get("expression", d.get("emotion", "")))
			var key := "%s|%s" % [sp, emo]
			if not out.has(key):
				out[key] = {"speaker": sp, "emotion": emo, "lines": 0, "chapters": []}
			out[key]["lines"] = int(out[key]["lines"]) + 1
			if not (chapter in out[key]["chapters"]):
				(out[key]["chapters"] as Array).append(chapter)
		for v in d.values():
			_walk(v, chapter, out)
	elif typeof(node) == TYPE_ARRAY:
		for v in node:
			_walk(v, chapter, out)

func _filters(preset: String) -> PackedStringArray:
	var cf := ConfigFile.new()
	if cf.load("res://export_presets.cfg") != OK:
		return PackedStringArray()
	for sec in cf.get_sections():
		if str(cf.get_value(sec, "name", "")) == preset:
			return str(cf.get_value(sec, "exclude_filter", "")).split(",", false)
	return PackedStringArray()

## Same rule as android_tier_pack_check / EditorExportPlatform::_match_filter.
static func _excluded(path: String, filters: PackedStringArray) -> bool:
	var rel := path.trim_prefix("res://")
	for f in filters:
		var ff := str(f).strip_edges()
		if ff != "" and (rel.matchn(ff) or ("res://" + rel).matchn("res://" + ff)):
			return true
	return false

func _resolve_all(refs: Dictionary, filters: PackedStringArray) -> Dictionary:
	CKArtPaths.pack_excluded = func(p: String) -> bool: return _excluded(p, filters)
	var out: Dictionary = {}
	for key in refs.keys():
		out[key] = _resolve(str(refs[key]["speaker"]), str(refs[key]["emotion"]))
	CKArtPaths.pack_excluded = Callable()
	return out

## Mirrors chapter_player._speaker_portrait (who lookup, recruit, leader, narrator).
func _resolve(speaker: String, emotion: String) -> String:
	UnitArt._cache.clear()
	CKGenomePortrait.clear_mem()
	CKArtPaths.last_loaded = ""
	var who: CKCharacter = null
	for c in GameState.characters.values():
		if c.name == speaker or str(c.cast_key) == speaker:
			who = c
			break
	if speaker in RECRUIT_SPEAKERS:
		who = null
	if speaker == "leader":
		who = GameState.get_leader()
	var tex: Texture2D = null
	if speaker == "" or speaker == "旁白":
		tex = UnitArt.dialogue_portrait("leader", "", GameState.get_leader(), 300)
	else:
		tex = UnitArt.dialogue_portrait(speaker, emotion, who, 300)
	if tex == null:
		return "silhouette"
	return CKArtPaths.last_loaded if CKArtPaths.last_loaded != "" else "texture(no path)"

static func _stem(p: String) -> String:
	return CKArtPaths._portrait_stem(p)
