extends Node
## ART-05: retired crest keys migrate using the palette table.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL crest: ", err)
		get_tree().quit(1)
	get_tree().quit(0)

func _table() -> Dictionary:
	var f := FileAccess.open("res://assets/art/crest_palette_v92.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _run() -> String:
	var table := _table()
	var migration: Dictionary = table.get("migration", {})
	if migration.is_empty():
		return "empty table"
	var fallback := UIKit.ACCENT.to_html(false).trim_prefix("#").to_lower()
	if UnitArt.crest_fallback() != fallback:
		return "fallback token"
	if UnitArt.migrate_crest_hex(fallback) != fallback:
		return "passthrough"
	for key in migration.keys():
		var raw := "#" + str(key)
		if UnitArt.migrate_crest_hex(raw) != str(migration[key]):
			return "migration"
		if UnitArt.migrate_crest_hex(str(key)) != str(migration[key]):
			return "bare key"
	var dir := "res://assets/art/banners"
	var found := DirAccess.open(dir)
	if found == null:
		return "banner dir"
	for name in found.get_files():
		var leaf := str(name)
		for key in migration.keys():
			if leaf.find(str(key)) >= 0:
				return "leftover " + leaf
	for key in migration.keys():
		var mapped := "banner_%s_w0.png" % str(migration[key])
		if not FileAccess.file_exists(dir.path_join(mapped)):
			return "missing mapped"
	var primary := "banner_%s_w0.png" % fallback
	if not FileAccess.file_exists(dir.path_join(primary)):
		return "missing primary"
	var out: Array = []
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/art/recolor_banners_v92.py")
	var code := OS.execute("python3", [script, "--check"], out, true)
	var text := " ".join(out)
	if code != 0 or text.find("CREST CHECK PASS") < 0:
		return "style %d %s" % [code, text.left(180)]
	print("CREST PALETTE PASS")
	return ""
