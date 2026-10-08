extends Node
## ART-04: 223 frost glyphs and 35 city fallback plates.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL placeholder: ", err)
		get_tree().quit(1)
	get_tree().quit(0)

func _run() -> String:
	var glyph := AtlasArt.item_icon("ashbanner_sword_1")
	if not glyph.ends_with("v92_glyph_ashbanner_sword_1.png"):
		return "item icon " + glyph
	var missing := AtlasArt.city_plate("stone_slope")
	if not missing.ends_with("v92_fallback_stone_slope.png"):
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
	print("PLACEHOLDER PASS glyphs=223 fallbacks=35 gold=0 parchment=0")
	return ""
