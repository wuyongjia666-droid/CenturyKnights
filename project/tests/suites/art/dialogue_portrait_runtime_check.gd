extends Node
## Y1-A runtime: ch0 speakers (掌柜/稳婆) load real medium plates via dialogue_portrait.
## Complements android_tier_pack_check (source contracts) by actually decoding textures.
## Also asserts resolve_portrait(TIER_MEDIUM) picks *.medium.webp for speaker stems.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var err := _check()
	if err == "":
		print("DIALOGUE PORTRAIT RUNTIME PASS")
		get_tree().quit(0)
	else:
		print("FAIL ", err)
		get_tree().quit(1)


func _check() -> String:
	for key in ["掌柜", "稳婆", "barkeep", "midwife", "voice_barkeep", "voice_midwife"]:
		var path := UnitArt.speaker_plate_path(key)
		if path == "":
			return "speaker_plate_path empty for %s" % key
		var resolved := CKArtPaths.resolve_portrait(path, CKArtPaths.TIER_MEDIUM)
		if not str(resolved).ends_with(".medium.webp"):
			return "resolve_portrait medium missed for %s got=%s" % [key, resolved]
		print("plate %s -> %s => %s" % [key, path, resolved])
	for cn in ["掌柜", "稳婆"]:
		var tex: Texture2D = UnitArt.dialogue_portrait(cn, "", null, 120)
		if tex == null:
			return "dialogue_portrait(%s) null (silhouette risk)" % cn
		var w := tex.get_width()
		var h := tex.get_height()
		print("dialogue_portrait(%s) -> %dx%d" % [cn, w, h])
		if w < 32 or h < 32:
			return "dialogue_portrait(%s) too small %dx%d" % [cn, w, h]
	for stem in ["barkeep", "midwife"]:
		var med := "res://assets/art/portraits/speakers/%s.medium.webp" % stem
		var t: Texture2D = CKArtPaths.load_texture(med)
		if t == null:
			return "cannot load medium plate %s" % med
		var png := "res://assets/art/portraits/speakers/%s.png" % stem
		var got := CKArtPaths.resolve_portrait(png, CKArtPaths.TIER_MEDIUM)
		if not str(got).ends_with(".medium.webp"):
			return "png stem resolve_portrait medium failed for %s got=%s" % [stem, got]
	return ""
