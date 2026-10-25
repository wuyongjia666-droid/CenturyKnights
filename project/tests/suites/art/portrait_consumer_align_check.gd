extends Node
## Desktop/mobile portrait path alignment for non-dialogue consumers.
## Dialogue already forces TIER_MEDIUM. Combat HUD / genealogy / unit cards used
## size→small, so Android (small excluded) fell to medium while desktop decoded
## small — same stem, different plate. Force MEDIUM so both layouts resolve the
## same tier for the same unit. Atlas world plates go through CKArtPaths.

const DETAIL_SOURCES := [
	"res://scripts/battle/ui/battle_info_panel.gd",
	"res://scripts/hub/lineage_info.gd",
	"res://scripts/ui/unit_card.gd",
]


func _ready() -> void:
	var err := _run()
	CKArtPaths.pack_excluded = Callable()
	if err != "":
		print("FAIL portrait_consumer_align: ", err)
		get_tree().quit(1)
		return
	print("PORTRAIT CONSUMER ALIGN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _source_gate()
	if err != "":
		return err
	err = _atlas_uses_art_paths()
	if err != "":
		return err
	err = _tier_parity_sample()
	if err != "":
		return err
	return ""


func _source_gate() -> String:
	for path in DETAIL_SOURCES:
		var src := FileAccess.get_file_as_string(path)
		if src == "":
			return "missing " + path
		var i := 0
		var hits := 0
		while true:
			var at := src.find("UnitArt.portrait(", i)
			if at < 0:
				break
			hits += 1
			var frag := src.substr(at, 140)
			if frag.find("TIER_MEDIUM") < 0:
				return "%s portrait call missing TIER_MEDIUM near: %s" % [
					path.get_file(), frag.replace("\n", " ")]
			i = at + 16
		if hits < 1:
			return "%s has no UnitArt.portrait calls" % path.get_file()
	var ua := FileAccess.get_file_as_string("res://scripts/art/unit_art.gd")
	var block_at := ua.find("static func dialogue_portrait")
	if block_at < 0:
		return "dialogue_portrait missing"
	if ua.substr(block_at, 700).find("TIER_MEDIUM") < 0:
		return "dialogue_portrait lost TIER_MEDIUM"
	var cp := FileAccess.get_file_as_string("res://scripts/story/chapter_player.gd")
	if cp.find("UnitArt.dialogue_portrait") < 0:
		return "chapter_player not on dialogue_portrait"
	if cp.find("_portrait.texture = load(") >= 0:
		return "chapter_player raw-loads portrait texture"
	var dossier := FileAccess.get_file_as_string("res://scripts/hub/unit_dossier.gd")
	if dossier.find("CKArtPaths.TIER_LARGE") < 0 and dossier.find("TIER_LARGE") < 0:
		return "dossier portrait_plate missing TIER_LARGE"
	return ""


func _atlas_uses_art_paths() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/hub/atlas_view.gd")
	if src.find("_plate.texture = load(") >= 0:
		return "atlas_view still raw-loads world plate"
	if src.find("CKArtPaths.load_texture(path)") < 0:
		return "atlas_view not on CKArtPaths.load_texture"
	return ""


func _tier_parity_sample() -> String:
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader after new_game"
	var win := _filters("Windows Desktop")
	var droid := _filters("Android")
	if droid.is_empty():
		return "Android exclude_filter empty — export_presets.cfg changed?"
	CKArtPaths.pack_excluded = func(p: String) -> bool: return _excluded(p, win)
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	CKArtPaths.last_loaded = ""
	var desk_tex: Texture2D = UnitArt.portrait(leader, 96, CKArtPaths.TIER_MEDIUM)
	var desk_path := CKArtPaths.last_loaded
	if desk_tex == null:
		return "desktop MEDIUM portrait null for leader"
	CKArtPaths.pack_excluded = func(p: String) -> bool: return _excluded(p, droid)
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	CKArtPaths.last_loaded = ""
	var mob_tex: Texture2D = UnitArt.portrait(leader, 96, CKArtPaths.TIER_MEDIUM)
	var mob_path := CKArtPaths.last_loaded
	if mob_tex == null:
		return "android MEDIUM portrait null for leader (path=%s)" % mob_path
	var desk_stem := CKArtPaths._portrait_stem(desk_path)
	var mob_stem := CKArtPaths._portrait_stem(mob_path)
	if desk_stem == "" or mob_stem == "":
		return "empty stem desk=%s mob=%s" % [desk_path, mob_path]
	if desk_stem != mob_stem:
		return "leader stem drift desk=%s mob=%s" % [desk_stem, mob_stem]
	print("OK leader MEDIUM desk=%s mob=%s" % [desk_path.get_file(), mob_path.get_file()])
	return ""


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
