extends Node
## Review 2026-10-17 P1: Android packs only the .medium/.small bank tiers. The preset filter
## must drop every large plate and keep both small tiers, and a bank without large plates must
## still list its stems and serve a "large" request from .medium.

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
	var da := DirAccess.open(BANK)
	if da == null:
		return "bank dir missing"
	var large := 0
	var kept := 0
	for fn in da.get_files():
		var name := str(fn)
		if not name.ends_with(".webp"):
			continue
		var rel := BANK.trim_prefix("res://") + "/" + name
		var is_tier := name.ends_with(".medium.webp") or name.ends_with(".small.webp")
		var out := _excluded(rel, filters)
		if is_tier and out:
			return "tier plate excluded: " + name
		if not is_tier and not out:
			return "large plate still packed: " + name
		if is_tier:
			kept += 1
		else:
			large += 1
	if large == 0 or kept != large * 2:
		return "unexpected tier counts large=%d kept=%d" % [large, kept]
	return _fallback()

## A medium/small-only copy of one plate: stems still list, large asks resolve to medium.
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
	for tier in ["medium", "small"]:
		var n2 := "%s.%s.webp" % [stem, tier]
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
	var got := CKArtPaths.resolve_portrait(tmp.path_join(stem + ".png"), "large")
	if got != want:
		return "large ask resolved to %s, want %s" % [got, want]
	if CKPortraitBank._load_plate(stem, "large") == null:
		return "large ask loaded no texture"
	return ""
