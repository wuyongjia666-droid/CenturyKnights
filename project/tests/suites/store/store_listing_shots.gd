extends Node
## Store listing evidence: five real landscape ≥1080p frames matching docs/store/screenshots-checklist.md.
## Drive under xvfb + opengl3 (scripts/capture_store_shots.sh). Headless prints STORE SHOTS SKIP and exits 0.
## Not marketing mockups — instantiates real hub/battle/story scenes after new_game.

const RATIO := Vector2i(1920, 1080)
const WAIT_HUB := 0.7
const WAIT_STORY := 3.2
const WAIT_BATTLE := 1.0

## id, scene path, settle seconds, optional setup callable name
const SHOTS := [
	["01_castle_hub", "res://scenes/hub/castle_hub.tscn", WAIT_HUB, ""],
	["02_battle", "res://scenes/battle/battle.tscn", WAIT_BATTLE, ""],
	["03_genealogy", "res://scenes/hub/lineage_view.tscn", WAIT_HUB, ""],
	["04_cs_dialogue", "res://scenes/story/chapter_player.tscn", WAIT_STORY, "_prep_cs01"],
	["05_month_echo", "res://scenes/hub/estates.tscn", WAIT_HUB, "_prep_echo"],
]

var _out := "/tmp/ck-store-shots"
var _manifest: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if DisplayServer.get_name() == "headless":
		print("STORE SHOTS SKIP headless-no-display")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.new_game("Li", "Banner", "#%02x%02x%02x" % [110, 212, 255])
	## Stabilize smith overlay so estates/city chrome stays clean for listing frames.
	if World.has_method("list_signature_ids") and World.has_method("mark_smith_revealed"):
		for sid in World.list_signature_ids():
			World.mark_smith_revealed(sid)
	get_window().size = RATIO
	get_tree().root.size = RATIO
	await get_tree().process_frame
	await get_tree().process_frame
	for row in SHOTS:
		var setup_name := str(row[3])
		if setup_name != "" and has_method(setup_name):
			call(setup_name)
		await _shoot(str(row[1]), str(row[0]), float(row[2]))
	_write_manifest()
	print("STORE SHOTS CAPTURE PASS count=%d out=%s" % [_manifest.size(), _out])
	get_tree().quit(0)

func _prep_cs01() -> void:
	## Open season_01 playable chapter (cs01_01) so the frame is real content-season dialogue.
	GameState.set_meta("story_chapter_id", "cs01_01")

func _prep_echo() -> void:
	## Seed month_echo lines so estates / 产业 surface shows经营节奏, not an empty panel.
	CKEconomyState.month_echo_note("harvest", "属地收成入账（商店截图样帧）")
	CKEconomyState.month_echo_note("holdings", "产业月结对照（商店截图样帧）")
	CKEconomyState.month_echo_note("commission", "委托交付回响（商店截图样帧）")

func _shoot(path: String, shot_id: String, settle: float) -> void:
	var packed = load(path)
	if packed == null:
		push_error("store_listing_shots missing " + path)
		print("STORE SHOTS FAIL missing " + path)
		get_tree().quit(1)
		return
	var node = packed.instantiate()
	## Prefer chapter_path on ChapterPlayer when meta is cleared by another path.
	if shot_id == "04_cs_dialogue" and "chapter_path" in node:
		node.chapter_path = "res://data/story/chapters/cs01_01.json"
		node.lock_path = true
	add_child(node)
	if node is Control:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.size = Vector2(RATIO)
	await get_tree().create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var fname := "%s_%dx%d.png" % [shot_id, RATIO.x, RATIO.y]
	var fpath := "%s/%s" % [_out, fname]
	image.save_png(fpath)
	_manifest.append({
		"id": shot_id,
		"file": fname,
		"width": image.get_width(),
		"height": image.get_height(),
		"scene": path,
	})
	print("STORE SHOT %s %dx%d -> %s" % [shot_id, image.get_width(), image.get_height(), fpath])
	node.queue_free()
	await get_tree().process_frame

func _write_manifest() -> void:
	var path := "%s/manifest.json" % _out
	var payload := {
		"version": 1,
		"ratio": [RATIO.x, RATIO.y],
		"min_short_side": 1080,
		"landscape": true,
		"shots": _manifest,
		"listing_bullets": [
			{"id": "01_castle_hub", "bullet": "castle_hub", "selling_point_zh": "百年王朝"},
			{"id": "02_battle", "bullet": "mid_battle", "selling_point_zh": "战棋"},
			{"id": "03_genealogy", "bullet": "genealogy_atlas", "selling_point_zh": "血脉"},
			{"id": "04_cs_dialogue", "bullet": "content_season_dialogue", "selling_point_zh": "内容季"},
			{"id": "05_month_echo", "bullet": "month_echo_estates", "selling_point_zh": "月回响"},
		],
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
		print("STORE SHOTS MANIFEST ", path)
