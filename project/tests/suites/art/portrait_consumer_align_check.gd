extends Node
## Desktop/mobile portrait path alignment for non-dialogue consumers.
## Surfaces call UnitArt.unit_portrait, which canonicalizes to the unit tier.
## Widget size must not pick a sibling the other platform does not ship.
## Atlas world plates go through CKArtPaths.

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
		if src.find("UnitArt.unit_portrait(") < 0:
			return "%s does not call UnitArt.unit_portrait" % path.get_file()
		if src.find("tier_for_display") >= 0:
			return "%s still maps portrait tier from widget size" % path.get_file()
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
	if dossier.find("TIER_LARGE") >= 0:
		return "dossier still requests TIER_LARGE"
	if dossier.find("portrait_plate(") < 0:
		return "dossier missing portrait_plate"
	var kit := FileAccess.get_file_as_string("res://scripts/ui/ui_kit.gd")
	if kit.find("UnitArt.unit_portrait(") < 0:
		return "ui_kit portrait rect left the shared resolver"
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
	var desk_tex: Texture2D = UnitArt.unit_portrait(leader)
	var desk_path := CKArtPaths.last_loaded
	if desk_tex == null:
		return "desktop MEDIUM portrait null for leader"
	CKArtPaths.pack_excluded = func(p: String) -> bool: return _excluded(p, droid)
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	CKArtPaths.last_loaded = ""
	var mob_tex: Texture2D = UnitArt.unit_portrait(leader)
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
