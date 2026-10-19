extends Node
## Android packs bank medium only (large + small excluded), drops expression/
## speaker large masters, excludes dead hireface/hire_*_plate (never shown),
## and drops legacy music_*.wav duplicates. hireuniq stays (bank miss must not
## fall to cartoon bust). Medium-only bank still lists stems / serves asks.

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
	var expr_err := _assert_dir_large_excluded("res://assets/art/portraits/expressions", true)
	if expr_err != "":
		return expr_err
	var spk_err := _assert_dir_large_excluded("res://assets/art/portraits/speakers", false)
	if spk_err != "":
		return spk_err
	var hu_err := _assert_dead_portrait_plates()
	if hu_err != "":
		return hu_err
	var au_err := _assert_legacy_music_wav_excluded()
	if au_err != "":
		return au_err
	return _fallback()



## Expressions use emotion-suffix globs; speakers list each large stem. keep_small
## true also requires small plates stay packed (expressions keep small; speakers too).
func _assert_dir_large_excluded(dir_res: String, _keep_small: bool) -> String:
	var filters := _android_filters()
	var da := DirAccess.open(dir_res)
	if da == null:
		return dir_res + " missing"
	var large := 0
	var medium := 0
	var small := 0
	for fn in da.get_files():
		var name := str(fn)
		if not name.ends_with(".webp"):
			continue
		var rel := dir_res.trim_prefix("res://") + "/" + name
		var out := _excluded(rel, filters)
		if name.ends_with(".medium.webp"):
			medium += 1
			if out:
				return "medium excluded in %s: %s" % [dir_res, name]
		elif name.ends_with(".small.webp"):
			small += 1
			if out:
				return "small excluded in %s: %s" % [dir_res, name]
		else:
			large += 1
			if not out:
				return "large still packed in %s: %s" % [dir_res, name]
	if large == 0 or medium == 0:
		return "%s unexpected tiers large=%d medium=%d small=%d" % [dir_res, large, medium, small]
	# large ask with only medium on disk must resolve to medium
	var stem := ""
	for fn2 in da.get_files():
		var n2 := str(fn2)
		if n2.ends_with(".medium.webp"):
			stem = n2.trim_suffix(".medium.webp")
			break
	var abs_med := ProjectSettings.globalize_path(dir_res).path_join(stem + ".medium.webp")
	var got := CKArtPaths.resolve_portrait(ProjectSettings.globalize_path(dir_res).path_join(stem + ".png"), "large")
	# resolve_portrait probes siblings next to the path; with large present on disk it
	# would pick large. Exclude check already proved large is filtered; probe a temp
	# medium-only copy so fallback is exercised the same way as the bank test.
	var tmp := OS.get_user_data_dir().path_join("android_tier_pack_expr")
	DirAccess.make_dir_recursive_absolute(tmp)
	var dt := DirAccess.open(tmp)
	for old in dt.get_files():
		dt.remove(str(old))
	if DirAccess.copy_absolute(abs_med, tmp.path_join(stem + ".medium.webp")) != OK:
		return "copy medium for fallback " + stem
	var want := tmp.path_join(stem + ".medium.webp")
	got = CKArtPaths.resolve_portrait(tmp.path_join(stem + ".png"), "large")
	if got != want:
		return "%s large fallback got %s want %s" % [dir_res, got, want]
	return ""


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


## Dead cartoon plates only (hireface / hire_*_plate). hireuniq stays packed.
## Band child plates must remain (quality-neutral relocate from hireuniq_150/170).
func _assert_dead_portrait_plates() -> String:
	var filters := _android_filters()
	var joined := ",".join(filters)
	for need in ["hireface_*.webp", "hire_*_plate.webp"]:
		if not joined.contains(need):
			return "Android filter missing " + need
	if joined.contains("hireuniq_*.webp"):
		return "hireuniq must stay packed (bank miss must not fall to bust)"
	var por := "res://assets/art/portraits"
	var da := DirAccess.open(por)
	if da == null:
		return "portraits dir missing"
	var seen_dead := 0
	var seen_hu := 0
	for fn in da.get_files():
		var name := str(fn)
		if not name.ends_with(".webp"):
			continue
		var rel: String = "assets/art/portraits/" + name
		if name.begins_with("hireface_") or (name.begins_with("hire_") and name.ends_with("_plate.webp")):
			seen_dead += 1
			if not _excluded(rel, filters):
				return "dead plate still packed on Android: " + name
		elif name.begins_with("hireuniq_"):
			seen_hu += 1
			if _excluded(rel, filters):
				return "hireuniq excluded (quality risk): " + name
	if seen_dead < 10:
		return "expected hireface/hire_plate samples, got %d" % seen_dead
	if seen_hu < 10:
		return "expected hireuniq kept on disk, got %d" % seen_hu
	for band_name in ["child_f.webp", "child_m.webp"]:
		var brel: String = "assets/art/portraits/band/" + str(band_name)
		if _excluded(brel, filters):
			return "band child plate excluded: " + band_name
		if not FileAccess.file_exists("res://assets/art/portraits/band/" + band_name):
			return "band child plate missing: " + band_name
	return ""


func _assert_legacy_music_wav_excluded() -> String:
	var filters := _android_filters()
	var joined := ",".join(filters)
	for need in ["music_hub.wav", "music_castle.wav", "music_battle.wav"]:
		if not joined.contains(need):
			return "Android filter missing " + need
		var rel: String = "assets/sfx/" + str(need)
		if not _excluded(rel, filters):
			return "legacy music wav still packed: " + need
	return ""
