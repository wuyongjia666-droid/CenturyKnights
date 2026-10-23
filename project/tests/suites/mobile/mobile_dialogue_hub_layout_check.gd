extends Node
## Y1-A 机制 C：宽屏手机下 SpeakerPlate 名签不被压成 ~1px；CastleHub 家族「同袍」瓷砖不被 NavRail 半裁。
## 命名 mobile_* → ci_godot_run.sh 设 CK_FORCE_MOBILE=1。

const CAP_MIN_W := 80.0
const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)  # MobileLayout.fit logical size for 2400×1080 landscape
const PLAYER_SCENE := preload("res://scenes/story/chapter_player.tscn")
const HUB_SCENE := preload("res://scenes/hub/castle_hub.tscn")
const SAMPLE := "res://tests/suites/narrative/fixtures/player_sample.json"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mech-c layout: ", err)
		get_tree().quit(1)
	else:
		print("MECH-C LAYOUT PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	var err := await _dialogue_caption()
	if err != "":
		return "dialogue: " + err
	err = await _dialogue_desktop_baseline()
	if err != "":
		return "desktop: " + err
	err = await _hub_bonds_tile()
	if err != "":
		return "hub: " + err
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _dialogue_caption() -> String:
	await _set_phone_window()
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
	player.apply_mobile_layout()
	MobileLayout.ensure_min_fonts(player)
	UIKit.layout_speaker_caption(player)
	for _j in 3:
		await get_tree().process_frame
	var plate := player.find_child("SpeakerPlate", true, false) as Control
	if plate == null:
		player.queue_free()
		return "SpeakerPlate missing"
	var cap := plate.get_node_or_null("SpeakerCaption") as Label
	if cap == null:
		player.queue_free()
		return "SpeakerCaption missing"
	cap.text = "SPEAKER // 掌柜"
	UIKit.layout_speaker_caption(player)
	await get_tree().process_frame
	var cw := cap.size.x
	var cap_rect := Rect2(cap.position, cap.size)
	var plate_local := Rect2(Vector2.ZERO, plate.size)
	var local_ok := plate_local.grow(1.0).encloses(cap_rect)
	var report := "caption size=(%.1f,%.1f) pos=(%.1f,%.1f) plate=(%.1f,%.1f)" % [
		cap.size.x, cap.size.y, cap.position.x, cap.position.y, plate.size.x, plate.size.y]
	print("mech-c dialogue ", report)
	player.queue_free()
	await get_tree().process_frame
	if cw < CAP_MIN_W:
		return "SpeakerCaption width %.1f < %d (%s)" % [cw, int(CAP_MIN_W), report]
	if not local_ok:
		return "SpeakerCaption outside plate (%s)" % report
	return ""

func _dialogue_desktop_baseline() -> String:
	## 1280×720 must keep a sized caption (no mobile widen path).
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var player: ChapterPlayer = PLAYER_SCENE.instantiate()
	player.suppress_scene_change = true
	player.lock_path = true
	if ResourceLoader.exists(SAMPLE):
		player.chapter_path = SAMPLE
	get_tree().root.add_child(player)
	player.position = Vector2.ZERO
	player.size = Vector2(1280, 720)
	for _i in 5:
		await get_tree().process_frame
	var plate := player.find_child("SpeakerPlate", true, false) as Control
	var cap := plate.get_node_or_null("SpeakerCaption") as Label if plate else null
	var msg := ""
	if plate == null or cap == null:
		msg = "SpeakerPlate/Caption missing on desktop"
	elif cap.size.x < CAP_MIN_W:
		msg = "desktop caption width %.1f < %d" % [cap.size.x, int(CAP_MIN_W)]
	else:
		print("mech-c desktop caption w=%.1f" % cap.size.x)
	player.queue_free()
	await get_tree().process_frame
	OS.set_environment("CK_FORCE_MOBILE", "1")
	return msg

func _hub_bonds_tile() -> String:
	await _set_phone_window()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var hub: Control = HUB_SCENE.instantiate()
	hub.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hub.position = Vector2.ZERO
	hub.size = ROOT
	get_tree().root.add_child(hub)
	for _i in 6:
		await get_tree().process_frame
	# Re-fit at ROOT in case _ready deferred layout saw a smaller default size.
	if hub.has_meta("m_relayout"):
		hub.remove_meta("m_relayout")
	hub.size = ROOT
	hub.apply_mobile_layout()
	for _j in 3:
		await get_tree().process_frame
	hub.call("_m_select", "family")
	for _k in 2:
		await get_tree().process_frame
	var bonds: Control = hub.find_child("Locked_bonds", true, false) as Control
	if bonds == null:
		for n in hub.find_children("*", "BaseButton", true, false):
			if str(n.get_meta("hub_entry", "")) == "bonds":
				bonds = n as Control
				break
	if bonds == null:
		hub.queue_free()
		return "bonds entry missing"
	var scroll := hub.find_child("NavRail", true, false) as ScrollContainer
	if scroll == null:
		hub.queue_free()
		return "NavRail missing"
	var br := bonds.get_global_rect()
	var sr := scroll.get_global_rect()
	var tile_w := bonds.size.x
	var enclosed := sr.grow(1.0).encloses(br)
	print("mech-c hub bonds rect=", br, " scroll=", sr, " enclosed=", enclosed, " tile_w=", tile_w)
	hub.queue_free()
	await get_tree().process_frame
	if not enclosed:
		return "Locked_bonds clipped by NavRail (bonds=%s scroll=%s)" % [str(br), str(sr)]
	if tile_w < 80.0:
		return "bonds tile width %.1f too narrow" % tile_w
	return ""
