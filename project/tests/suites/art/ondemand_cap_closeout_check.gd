extends Node
const OnDemandArt = preload("res://scripts/art/ondemand_art.gd")
## On-demand + CAP closeout E2E: manifest contract, Android exclude alignment,
## large→medium fallback under pack_excluded, critical paths stay packed.
## Complements tools/ci/store_ondemand_check.py (Python gate).

func _ready() -> void:
	var err := _run()
	CKArtPaths.pack_excluded = Callable()
	if err != "":
		print("FAIL ondemand_cap_closeout: ", err)
		get_tree().quit(1)
		return
	print("ONDEMAND CAP CLOSEOUT PASS")
	get_tree().quit(0)


func _android_filters() -> PackedStringArray:
	var cf := ConfigFile.new()
	if cf.load("res://export_presets.cfg") != OK:
		return PackedStringArray()
	for sec in cf.get_sections():
		if str(cf.get_value(sec, "platform", "")) == "Android":
			return str(cf.get_value(sec, "exclude_filter", "")).split(",", false)
	return PackedStringArray()


static func _excluded(rel: String, filters: PackedStringArray) -> bool:
	for f in filters:
		var ff := str(f).strip_edges()
		if ff != "" and (rel.matchn(ff) or ("res://" + rel).matchn("res://" + ff)):
			return true
	return false


func _run() -> String:
	var err := _assert_helper_source()
	if err != "":
		return err
	err = _assert_manifest()
	if err != "":
		return err
	err = _assert_deferred_bank_excludes()
	if err != "":
		return err
	err = _assert_large_falls_to_medium()
	if err != "":
		return err
	err = _assert_critical_packed()
	if err != "":
		return err
	err = _assert_pack_safe_api()
	if err != "":
		return err
	return ""


func _assert_helper_source() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/art/ondemand_art.gd")
	if src.find("class_name CKOnDemandArt") < 0:
		return "CKOnDemandArt missing class_name"
	if src.find("resolve_pack_safe") < 0 or src.find("load_pack_safe") < 0:
		return "CKOnDemandArt missing pack_safe APIs"
	if src.find("ondemand-assets.json") < 0:
		return "CKOnDemandArt missing manifest reference"
	if src.find("FALLBACK_TIER") < 0:
		return "CKOnDemandArt missing FALLBACK_TIER"
	var paths := FileAccess.get_file_as_string("res://scripts/art/art_paths.gd")
	if paths.find("_tier_candidates") < 0 or paths.find("UNIT_TIER") < 0:
		return "CKArtPaths missing tier fallthrough seams"
	return ""


func _assert_manifest() -> String:
	if not OnDemandArt.manifest_exists():
		return "ondemand-assets.json missing at " + OnDemandArt.manifest_path()
	var data: Dictionary = OnDemandArt.load_manifest()
	if data.is_empty():
		return "ondemand-assets.json failed to parse"
	if str(data.get("version", "")).find("ondemand-") < 0:
		return "bad manifest version"
	var cap: Dictionary = data.get("cap", {})
	if str(cap.get("source_status", "")) != "UNDER":
		return "manifest cap.source_status must be UNDER"
	if cap.get("h_i_user_only", false) != true:
		return "manifest must lock h_i_user_only"
	var deferred: Array = data.get("deferred_classes", [])
	if deferred.size() < 5:
		return "manifest deferred_classes too thin"
	var critical: Array = data.get("always_packed_critical", [])
	if critical.size() < 4:
		return "manifest always_packed_critical too thin"
	return ""


func _assert_deferred_bank_excludes() -> String:
	var filters := _android_filters()
	if filters.is_empty():
		return "no Android exclude_filter"
	var joined := ",".join(filters)
	var bank_err: String = OnDemandArt.asserts_android_deferred_bank_in(joined)
	if bank_err != "":
		return bank_err
	return ""


func _assert_large_falls_to_medium() -> String:
	var filters := _android_filters()
	var probe := "res://assets/art/portraits/speakers/barkeep.png"
	var large := "res://assets/art/portraits/speakers/barkeep.webp"
	var medium := "res://assets/art/portraits/speakers/barkeep.medium.webp"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(medium)):
		return "fixture medium missing: " + medium
	CKArtPaths.pack_excluded = func(path: String) -> bool:
		return _excluded(path.trim_prefix("res://"), filters)
	if not _excluded(large.trim_prefix("res://"), filters):
		CKArtPaths.pack_excluded = Callable()
		return "Android filter does not defer speaker large"
	var got: String = OnDemandArt.resolve_pack_safe(probe, CKArtPaths.TIER_LARGE)
	var got_unit: String = OnDemandArt.unit_plate(probe)
	CKArtPaths.pack_excluded = Callable()
	if got != medium:
		return "resolve_pack_safe(large ask) got %s want %s" % [got, medium]
	if got_unit != medium:
		return "unit_plate under Android exclude got %s want %s" % [got_unit, medium]
	return ""


func _assert_critical_packed() -> String:
	var filters := _android_filters()
	var keep := [
		"assets/art/portraits/speakers/barkeep.medium.webp",
		"assets/art/estates/fog_vale.png",
		"assets/art/estates/stone_slope.png",
	]
	for rel in keep:
		if _excluded(rel, filters):
			return "critical path excluded: " + rel
		if not FileAccess.file_exists("res://" + rel) and not FileAccess.file_exists(
			ProjectSettings.globalize_path("res://" + rel)
		):
			return "critical path missing: " + rel
	# At least one live v8 scene must stay packable.
	var scene_dir := DirAccess.open("res://assets/art/scenes")
	if scene_dir == null:
		return "scenes dir missing"
	var v8 := 0
	for fn in scene_dir.get_files():
		var name := str(fn)
		if name.begins_with("v8_scene_") and name.ends_with(".webp"):
			v8 += 1
			if _excluded("assets/art/scenes/" + name, filters):
				return "live v8 scene excluded: " + name
	if v8 < 3:
		return "expected live v8_scene plates, got %d" % v8
	return ""


func _assert_pack_safe_api() -> String:
	# Without pack_excluded, large ask may resolve to large on disk (Windows-like).
	# API must still return a non-empty existing sibling and not crash.
	var probe := "res://assets/art/portraits/speakers/barkeep.png"
	var got: String = OnDemandArt.resolve_pack_safe(probe, CKArtPaths.TIER_MEDIUM)
	if got.find("barkeep") < 0:
		return "pack_safe medium ask drifted: " + got
	if not got.ends_with(".medium.webp") and not got.ends_with(".webp"):
		return "pack_safe unexpected suffix: " + got
	var tex: Texture2D = OnDemandArt.load_pack_safe(probe, CKArtPaths.TIER_MEDIUM)
	if tex == null:
		return "load_pack_safe returned null for barkeep medium"
	return ""
