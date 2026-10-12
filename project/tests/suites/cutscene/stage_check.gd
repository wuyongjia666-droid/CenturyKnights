extends Node
## CUT-07: 14 biomes, low tier keeps one layer and at most 30 prop meshes.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL stage: ", err)
		get_tree().quit(1)
	else:
		print("STAGE PASS")
		get_tree().quit(0)

func _run() -> String:
	var ids: Array = CutsceneStage.biome_ids()
	if ids.size() != 14:
		return "biome count %d" % ids.size()
	var host := Node3D.new()
	add_child(host)
	for id in ids:
		var low := CutsceneStage.build(host, str(id), true)
		var n := CutsceneStage.prop_count(low)
		if n > 30:
			return "%s low props %d" % [str(id), n]
		if n < 1:
			return "%s empty" % str(id)
		if low.get_node_or_null("far") == null or low.get_node_or_null("mid") != null or low.get_node_or_null("near") != null:
			return "%s low layers" % str(id)
		var fog: Dictionary = CutsceneStage.fog_for(str(id))
		var col: Color = fog.get("color", Color.BLACK)
		if col.r > col.b + 0.18 and col.r > 0.45:
			return "%s warm fog" % str(id)
		low.queue_free()
		var full := CutsceneStage.build(host, str(id), false)
		if full.get_node_or_null("far") == null or full.get_node_or_null("mid") == null or full.get_node_or_null("near") == null:
			return "%s full layers" % str(id)
		CutsceneStage.parallax(full, 2.0)
		var far_x := absf(full.get_node("far").position.x)
		var near_x := absf(full.get_node("near").position.x)
		if near_x <= far_x + 0.05:
			return "%s parallax near %.3f far %.3f" % [str(id), near_x, far_x]
		full.queue_free()
	# WS-D #49: painted plates instead of grey blocks, tile- and nation-aware
	var painted := CutsceneStage.build(host, "fort", false, Color8(58, 110, 165))
	if painted.get_node("far").get_node_or_null("plate") == null:
		return "fort far layer is not the painted plate"
	for n in painted.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh is BoxMesh:
			return "grey block left in painted stage"
	if painted.get_node("mid").get_node_or_null("banner") == null:
		return "no nation banner"
	var blue := CutsceneStage.nation_banner(Color8(58, 110, 165))
	var mint := CutsceneStage.nation_banner(Color8(94, 224, 181))
	if blue == "" or mint == "" or blue == mint:
		return "banner match %s / %s" % [blue, mint]
	painted.queue_free()
	if CutsceneStage.biome_for_tile("forest", "plain") != "hill" or CutsceneStage.biome_for_tile("water", "plain") != "ford":
		return "tile biome"
	if CutsceneStage.biome_for_tile("plain", "urban") != "urban":
		return "plain tile kept map biome"
	var guessed := CutsceneStage.biome_from_record({"backdrop": "res://assets/art/battle/v8_battle_biome_snow.png"})
	if guessed != "snow":
		return "backdrop guess " + guessed
	var fallback := CutsceneStage.biome_from_record({})
	if fallback != "plain":
		return "fallback " + fallback
	return ""
