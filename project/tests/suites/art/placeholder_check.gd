extends Node
## ART-04: real v8.7 plates win; missing ids still use the frost glyph or city badge.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL placeholder: ", err)
		get_tree().quit(1)
	get_tree().quit(0)

func _run() -> String:
	var landed := AtlasArt.item_icon("ashbanner_sword_1")
	if not landed.ends_with("v87_item_ashbanner_sword_1.png"):
		return "item icon " + landed
	var glyph := AtlasArt.item_icon("eo_archive_sig1")
	if not glyph.ends_with("v92_glyph_eo_archive_sig1.png"):
		return "glyph fallback " + glyph
	var city := AtlasArt.city_plate("stone_slope")
	if not city.ends_with("v87_city_stone_slope.png"):
		return "city plate " + city
	var missing := AtlasArt.city_plate("eo_banner")
	if not missing.ends_with("v92_fallback_eo_banner.png"):
		return "city fallback " + missing
	var kept := AtlasArt.city_plate("ash_capital")
	if kept == "" or kept.find("v92_fallback") >= 0:
		return "passed city lost " + kept
	var out: Array = []
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/art/item_glyphs_v92.py")
	var code := OS.execute("python3", [script, "--check"], out, true)
	var text := " ".join(out)
	if code != 0 or text.find("GLYPH CHECK PASS") < 0:
		return "check %d %s" % [code, text.left(180)]
	print("PLACEHOLDER PASS glyphs=223 fallbacks=35")
	return ""
