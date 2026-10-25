extends Node
## Under Android pack_excluded + phone-sized ChapterPlayer, a medium speaker plate
## must keep SpeakerPlate.visible (guards is_banner false-hide / w==0).

const PLAYER_SCENE := preload("res://scenes/story/chapter_player.tscn")
const SAMPLE := "res://tests/suites/narrative/fixtures/player_sample.json"
const ROOT := Vector2(1600, 720)

func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	await get_tree().process_frame
	var err := await _run()
	CKArtPaths.pack_excluded = Callable()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		print("FAIL dialogue plate vis android: ", err)
		get_tree().quit(1)
		return
	print("DIALOGUE PLATE VIS ANDROID PASS")
	get_tree().quit(0)

func _run() -> String:
	var droid := _af()
	if droid.is_empty():
		return "Android exclude_filter missing"
	CKArtPaths.pack_excluded = func(p): return _ex(p, droid)
	UnitArt._cache.clear()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var player: ChapterPlayer = PLAYER_SCENE.instantiate()
	player.suppress_scene_change = true
	player.lock_path = true
	if ResourceLoader.exists(SAMPLE):
		player.chapter_path = SAMPLE
	get_tree().root.add_child(player)
	player.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player.position = Vector2.ZERO
	player.size = ROOT
	for _i in 5:
		await get_tree().process_frame
	if player.has_method("apply_mobile_layout"):
		player.apply_mobile_layout()
	var plate := player.find_child("SpeakerPlate", true, false) as Control
	var pr: TextureRect = player.get("_portrait") as TextureRect
	if plate == null or pr == null:
		var msg := "missing plate=%s portrait=%s" % [plate != null, pr != null]
		player.queue_free()
		return msg
	var tex = UnitArt.dialogue_portrait("掌柜", "", null, 420)
	if tex == null:
		player.queue_free()
		return "掌柜 plate null under android pack"
	pr.texture = tex
	pr.set_meta("story_narrator", false)
	pr.set_meta("story_narrator_lead", false)
	var sp: Label = player.get("_speaker") as Label
	if sp != null:
		sp.text = "掌柜"
	# stitch sync runs on 0.1s timer — wait past one tick
	await get_tree().create_timer(0.25).timeout
	for _j in 3:
		await get_tree().process_frame
	var vis := plate.visible
	var w := tex.get_width()
	print("plate_vis android visible=%s w=%d last=%s" % [vis, w, CKArtPaths.last_loaded])
	player.queue_free()
	await get_tree().process_frame
	if not vis:
		return "SpeakerPlate hidden for 掌柜 medium (is_banner?)"
	if w < 200:
		return "thin plate w=%d (banner heuristic risk)" % w
	return ""

func _af() -> PackedStringArray:
	var cf := ConfigFile.new()
	cf.load("res://export_presets.cfg")
	for sec in cf.get_sections():
		if str(cf.get_value(sec, "name", "")) == "Android":
			return str(cf.get_value(sec, "exclude_filter", "")).split(",", false)
	return PackedStringArray()

func _ex(path: String, filters: PackedStringArray) -> bool:
	var rel := path.trim_prefix("res://")
	for f in filters:
		var ff := str(f).strip_edges()
		if ff != "" and (rel.matchn(ff) or ("res://" + rel).matchn("res://" + ff)):
			return true
	return false
