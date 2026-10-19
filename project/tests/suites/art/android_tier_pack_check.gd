extends Node
## Android packs only the .medium bank tier (large + small excluded). The preset
## filter must drop every large and small plate and keep medium, and a bank with
## only medium plates must still list its stems and serve a "large"/"small"
## request from .medium.

const BANK := "res://assets/art/portraits/genome/bank"

func _ready() -> void:
	var err := _run()
	CKPortraitBank.dir_override = ""
	CKPortraitBank.clear_cache()
	if err != "":
		print("FAIL android tier pack: ", err)
		get_tree().quit(1)
	else:
		print("ANDROID TIER PACK PASS")
		get_tree().quit(0)


func _android_filters() -> PackedStringArray:
	var cf := ConfigFile.new()
	if cf.load("res://export_presets.cfg") != OK:
		return PackedStringArray()
	for sec in cf.get_sections():
		if str(cf.get_value(sec, "platform", "")) == "Android":
			return str(cf.get_value(sec, "exclude_filter", "")).split(",", false)
	return PackedStringArray()


## Same rule as Godot's EditorExportPlatform::_match_filter (with and without res://).
static func _excluded(rel: String, filters: PackedStringArray) -> bool:
	for f in filters:
		var ff := str(f).strip_edges()
		if ff != "" and (rel.matchn(ff) or ("res://" + rel).matchn("res://" + ff)):
			return true
	return false


func _run() -> String:
	var filters := _android_filters()
	if filters.is_empty():
		return "no Android preset exclude_filter"
	var joined := ",".join(filters)
	if not joined.contains("genome/bank/*.small.webp") and not joined.contains("bank/*.small.webp"):
		return "Android filter missing bank *.small.webp exclude"
	var da := DirAccess.open(BANK)
	if da == null:
		return "bank dir missing"
	var large := 0
	var medium := 0
	var small := 0
	for fn in da.get_files():
		var name := str(fn)
		if not name.ends_with(".webp"):
			continue
		var rel := BANK.trim_prefix("res://") + "/" + name
		var out := _excluded(rel, filters)
		if name.ends_with(".medium.webp"):
			medium += 1
			if out:
				return "medium plate excluded: " + name
		elif name.ends_with(".small.webp"):
			small += 1
			if not out:
				return "small plate still packed: " + name
		else:
			large += 1
			if not out:
				return "large plate still packed: " + name
	if large == 0 or medium == 0 or small == 0:
		return "unexpected tier counts large=%d medium=%d small=%d" % [large, medium, small]
	if medium != large or small != large:
		return "tier count mismatch large=%d medium=%d small=%d" % [large, medium, small]
	return _fallback()


## A medium-only copy of one plate: stems still list; large/small asks resolve to medium.
func _fallback() -> String:
	var tmp := OS.get_user_data_dir().path_join("android_tier_pack")
	DirAccess.make_dir_recursive_absolute(tmp)
	var dt := DirAccess.open(tmp)
	for old in dt.get_files():
		dt.remove(str(old))
	var src_dir := ProjectSettings.globalize_path(BANK)
	var picked := ""
	for fn in DirAccess.open(BANK).get_files():
		var n := str(fn)
		if n.ends_with(".medium.webp"):
			picked = n.trim_suffix(".medium.webp")
			break
	if picked == "":
		return "no medium plate to copy"
	var stem := picked
	var n2 := "%s.medium.webp" % stem
	if DirAccess.copy_absolute(src_dir.path_join(n2), tmp.path_join(n2)) != OK:
		return "copy " + n2
	CKPortraitBank.dir_override = tmp
	CKPortraitBank.clear_cache()
	if not CKPortraitBank.has_plates():
		return "medium-only bank reports no plates"
	CKPortraitBank._ensure_disk_index()
	var listed := false
	for st in CKPortraitBank._disk_by_stage.keys():
		if (CKPortraitBank._disk_by_stage[st] as Array).has(stem):
			listed = true
	if not listed:
		return "stem %s not listed without its large plate: %s" % [stem, str(CKPortraitBank._disk_by_stage)]
	var want := tmp.path_join(stem + ".medium.webp")
	for ask in ["large", "small", "medium"]:
		var got := CKArtPaths.resolve_portrait(tmp.path_join(stem + ".png"), ask)
		if got != want:
			return "%s ask resolved to %s, want %s" % [ask, got, want]
	if CKPortraitBank._load_plate(stem, "large") == null:
		return "large ask loaded no texture"
	if CKPortraitBank._load_plate(stem, "small") == null:
		return "small ask loaded no texture"
	return ""
