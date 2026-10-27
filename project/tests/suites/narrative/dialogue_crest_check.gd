extends Node
## Fat heraldry E2E: chapter_player DialogueCrestStrip + DialogueSpeakerArms beside portrait.

const SCN := "res://scenes/story/chapter_player.tscn"
const SAMPLE := "res://tests/suites/narrative/fixtures/player_sample.json"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_api_probe()
	if _fails.is_empty():
		print("DIALOGUE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL dialogue crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("对话徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false

func _assert_page(page: Node, where: String) -> void:
	var strip = page.find_child("DialogueCrestStrip", true, false)
	_ok(strip != null, "%s DialogueCrestStrip" % where)
	if strip != null:
		_ok(str(strip.get_meta("field_route", "")) == "dialogue_strip", "%s strip field_route" % where)
		_ok(strip.find_child("CastleArms", true, false) != null, "%s strip CastleArms" % where)
		var bn = strip.find_child("DialogueBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_dialogue_arms", "%s DialogueBanner" % where)
		_ok(bn != null and str(bn.get_meta("field_route", "")) == "dialogue_banner", "%s dialogue_banner route" % where)
		_ok(strip.get_child_count() == 2, "%s dialogue child_count=2" % where)
	## Speaker arms appear once a character (or narrator-leader) plate mounts.
	var speaker = page.find_child("DialogueSpeakerArms", true, false)
	_ok(speaker != null, "%s DialogueSpeakerArms" % where)
	if speaker != null:
		_ok(str(speaker.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s speaker kind" % where)
		_ok(str(speaker.get_meta("field_route", "")) == "dialogue_speaker", "%s speaker field_route" % where)

func _mount() -> Control:
	var page: Control = (load(SCN) as PackedScene).instantiate()
	page.set("chapter_path", SAMPLE)
	page.set("lock_path", true)
	page.set("suppress_scene_change", true)
	get_tree().root.add_child(page)
	return page

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _mount()
	await _settle(16)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page := _mount()
	await _settle(16)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")

func _run_api_probe() -> void:
	var host := Control.new()
	host.name = "DialogueCrestHost"
	get_tree().root.add_child(host)
	var src := FileAccess.get_file_as_string("res://scripts/story/chapter_player.gd")
	_ok(src.find("CKHeraldryField.place_dialogue_crest_strip") >= 0, "chapter_player strip calls Field")
	_ok(src.find("CKHeraldryField.attach_dialogue_speaker_arms") >= 0, "chapter_player speaker calls Field")
	_ok(src.find("CKHeraldryChrome.attach_dialogue_speaker_arms") < 0, "chapter_player speaker left Chrome")
	var strip := CKHeraldryField.place_dialogue_crest_strip(host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(strip != null and strip.name == "DialogueCrestStrip", "api DialogueCrestStrip")
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "dialogue_strip", "api strip field_route")
	var por := TextureRect.new()
	por.name = "ProbePortrait"
	por.custom_minimum_size = Vector2(120, 120)
	host.add_child(por)
	var lead = GameState.get_leader()
	var arms := CKHeraldryField.attach_dialogue_speaker_arms(por, lead, Vector2(28, 34))
	_ok(arms != null, "api DialogueSpeakerArms")
	if arms != null and lead != null:
		_ok(str(arms.get_meta("field_route", "")) == "dialogue_speaker", "api speaker field_route")
		_ok(str(arms.get_meta("arms_core", "")) == CKHeraldry.core_key(GameState.arms_for_character(lead)), "api speaker core")
	CKHeraldryField.attach_dialogue_speaker_arms(por, null)
	_ok(por.find_child("DialogueSpeakerArms", true, false) == null, "api clear speaker arms")
	host.queue_free()
