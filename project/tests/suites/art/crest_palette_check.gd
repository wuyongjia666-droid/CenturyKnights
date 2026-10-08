extends Node
## ART-05: gold banners are gone; #c9a227 migrates to frost silver.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL crest: ", err)
		get_tree().quit(1)
	get_tree().quit(0)

func _run() -> String:
	if UnitArt.migrate_crest_hex("#c9a227") != "c9d3de":
		return "migration"
	if UnitArt.migrate_crest_hex("6ed4ff") != "6ed4ff":
		return "passthrough"
	var dir := ProjectSettings.globalize_path("res://assets/art/banners")
	var found := DirAccess.open(dir)
	if found == null:
		return "banner dir"
	found.list_dir_begin()
	var name := found.get_next()
	while name != "":
		if name.find("c9a227") >= 0:
			return "leftover " + name
		name = found.get_next()
	if not FileAccess.file_exists(dir.path_join("banner_c9d3de_w0.png")):
		return "missing frost silver"
	if not FileAccess.file_exists(dir.path_join("banner_6ed4ff_w0.png")):
		return "missing primary"
	var out: Array = []
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/art/recolor_banners_v92.py")
	var code := OS.execute("python3", [script, "--check"], out, true)
	var text := " ".join(out)
	if code != 0 or text.find("CREST CHECK PASS") < 0:
		return "style %d %s" % [code, text.left(180)]
	print("CREST PALETTE PASS migrate=c9a227->c9d3de gold<=0.04")
	return ""
