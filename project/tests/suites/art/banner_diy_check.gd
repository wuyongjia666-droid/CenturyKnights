extends Node
## P0-BNR-01: layered banner DIY + crest migration + no warm gold in naming defaults.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL banner diy: ", err)
		get_tree().quit(1)
	print("BANNER DIY PASS")
	get_tree().quit(0)

func _run() -> String:
	if BannerSpec.palette().size() < 24:
		return "palette size"
	for c in BannerSpec.palette():
		if str(c).to_lower().find("c9a227") >= 0:
			return "warm gold in palette"
	if BannerSpec.CHARGES.size() < 6 or BannerSpec.BORDERS.size() < 4 or BannerSpec.EMBLEMS.size() < 12:
		return "layer counts"
	var spec := BannerSpec.default_spec("#" + UIKit.ACCENT.to_html(false))
	var img := BannerSpec.compose(spec, 80, 110, 0.2)
	if img.get_width() != 80 or img.get_height() != 110:
		return "compose size"
	var opaque := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.1:
				opaque += 1
	if opaque < 200:
		return "compose empty"
	GameState.new_game("烬行", "霜旗", "#" + UIKit.ACCENT.to_html(false))
	GameState.banner_spec = BannerSpec.normalize({
		"field": "per_pale", "field_a": "#" + UIKit.OK.to_html(false), "field_b": "#" + UIKit.ACCENT_DIM.to_html(false),
		"charge": "chevron", "border": "dentil", "emblem": "spark",
	})
	UnitArt.clear_cache()
	var tex := UnitArt.banner(120, 170, true)
	if tex == null:
		return "unitart banner"
	var data := GameState.build_save_data()
	if not data.has("banner_spec"):
		return "save missing banner_spec"
	# Old save: crest only
	var old := data.duplicate(true)
	old.erase("banner_spec")
	old["crest_color"] = "#" + "c9a227"
	if not GameState.apply_save_data(old):
		return "load old"
	if str(GameState.banner_spec.get("field_a", "")).to_lower().find("c9a227") >= 0:
		return "old crest not migrated in spec"
	# Naming defaults must not offer warm gold
	var src := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	if src.find("#" + "c9a227") >= 0 or src.find("灰烬金") >= 0:
		return "naming still offers warm gold"
	if FileAccess.get_file_as_string("res://icon.svg").find("#" + "c9a227") >= 0:
		return "icon still warm gold"
	var migrated := BannerSpec.normalize({"field": "solid", "field_a": "#" + UIKit.ACCENT.to_html(false), "emblem": "ring"})
	if int(migrated.get("schema", 0)) != 2:
		return "banner schema not v2"
	return ""
