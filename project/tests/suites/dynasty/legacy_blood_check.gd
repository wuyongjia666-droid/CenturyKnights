extends Node
## DYN-08: v8.7 blood ids migrate onto v8.9 lines, and the live genome table
## goes through CKBloodline. CKGenome.BLOOD stays an offline fallback.

const FIXTURE := "res://tests/fixtures/save_v87_blood.json"
const LEGACY_IDS := ["common_ash", "river_ward", "ember_noble", "frost_crown"]

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_check_migration(fails)
	_check_fallback(fails)
	_check_references(fails)
	if fails.is_empty():
		print("LEGACY BLOOD PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL legacy blood: ", f)
		get_tree().quit(1)

func _check_migration(fails: Array) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if typeof(parsed) != TYPE_DICTIONARY:
		fails.append("v8.7 fixture did not parse")
		return
	var migrated: Dictionary = CKBloodline.migrate_save(parsed)
	var chars: Dictionary = migrated.get("characters", {})
	var knight: Dictionary = chars.get("old_knight", {})
	var mix: Dictionary = knight.get("blood_mix", {})
	if not is_equal_approx(float(mix.get("frost_crown", 0.0)), 0.25):
		fails.append("frost_royal did not map to frost_crown 0.25")
	if not is_equal_approx(float(mix.get("common_ash", 0.0)), 0.75):
		fails.append("ash_folk did not map to common_ash 0.75")
	if mix.has("frost_royal") or mix.has("ash_folk"):
		fails.append("retired v8.7 ids still present on old_knight")
	var meta: Dictionary = knight.get("blood_meta", {})
	var legacy: Dictionary = meta.get("legacy_blood", {})
	if not legacy.has("frost_royal") or not legacy.has("ash_folk"):
		fails.append("migration did not keep the pre-map blood_mix")
	var kept: Dictionary = chars.get("kept_line", {})
	var kept_mix: Dictionary = kept.get("blood_mix", {})
	if not is_equal_approx(float(kept_mix.get("river_ward", 0.0)), 0.6):
		fails.append("river_ward weight drifted")
	if not is_equal_approx(float(kept_mix.get("ember_noble", 0.0)), 0.4):
		fails.append("ember_noble weight drifted")
	if kept.get("blood_meta", {}).has("legacy_blood"):
		fails.append("identity v8.9 ids should not be stamped as rewritten")
	var loaded := CKCharacter.from_dict(parsed["characters"]["old_knight"])
	if loaded.primary_bloodline() != "common_ash":
		fails.append("from_dict primary bloodline %s" % loaded.primary_bloodline())
	if not is_equal_approx(float(loaded.blood_mix.get("frost_crown", 0.0)), 0.25):
		fails.append("from_dict missed frost_crown")
	for id in LEGACY_IDS:
		if not CKBloodline.has_line(id):
			fails.append("v8.9 catalog missing legacy id %s" % id)
		var row: Dictionary = CKBloodline.line(id)
		var legacy_row: Dictionary = CKBloodline.legacy_row(id)
		if str(row.get("name", "")) == "" or str(row.get("name", "")) != str(legacy_row.get("name", "")):
			fails.append("legacy name mismatch for %s" % id)

func _check_fallback(fails: Array) -> void:
	for id in LEGACY_IDS:
		var live: Dictionary = CKBloodline.genome_or_fallback(id)
		var table: Dictionary = CKBloodline.genome_table(id)
		var blood: Dictionary = CKGenome.BLOOD[id]
		if str(live.get("skin", "")) != str(table.get("skin", "")) or str(live.get("skin", "")) == "":
			fails.append("live genome for %s did not come from the v8.9 table" % id)
		if JSON.stringify(table.get("face", {})) != JSON.stringify(blood.get("face", {})):
			fails.append("fallback face drifted for %s" % id)
		if JSON.stringify(table.get("body", {})) != JSON.stringify(blood.get("body", {})):
			fails.append("fallback body drifted for %s" % id)
		if str(table.get("skin", "")) != str(blood.get("skin", "")):
			fails.append("fallback skin drifted for %s" % id)
	var missing: Dictionary = CKBloodline.genome_or_fallback("___no_such_line___")
	if str(missing.get("skin", "")) != str(CKGenome.BLOOD["common_ash"].get("skin", "")):
		fails.append("unknown line did not fall back to CKGenome.BLOOD common_ash")

func _check_references(fails: Array) -> void:
	var hits: Array = []
	_scan_dir("res://scripts", hits)
	_scan_dir("res://autoload", hits)
	_scan_dir("res://tests", hits)
	var allowed := {
		"res://scripts/characters/bloodline_v89.gd": true,
		"res://autoload/game_state.gd": true,
		"res://tests/suites/dynasty/legacy_blood_check.gd": true,
	}
	for path in hits:
		if allowed.has(path):
			continue
		fails.append("bloodlines.json referenced outside migration: %s" % path)
	if not hits.has("res://autoload/game_state.gd"):
		fails.append("expected the known game_state handoff reference")
	else:
		print("HANDOFF game_state.gd still loads bloodlines.json; S02-core owns that file")

func _scan_dir(root: String, hits: Array) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := root + "/" + name
		if dir.current_is_dir():
			_scan_dir(path, hits)
		elif name.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(path)
			if text.find("bloodlines.json") >= 0:
				hits.append(path)
		name = dir.get_next()
	dir.list_dir_end()
