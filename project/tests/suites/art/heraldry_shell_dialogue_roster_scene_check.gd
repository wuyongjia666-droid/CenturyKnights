extends Node
## Fat heraldry wave-15 E2E: ShellCrestStrip / DialogueCrestStrip / RosterCrestStrip
## — _cloth_beside Field cloth + arms_kind ownership — desk + mobile.
## Real main_menu / chapter_player / roster; no EmptyHost.

const MENU := "res://scenes/ui/main_menu.tscn"
const DIALOGUE := "res://scenes/story/chapter_player.tscn"
const SAMPLE := "res://tests/suites/narrative/fixtures/player_sample.json"
const ROSTER := "res://scenes/hub/roster.tscn"

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_helpers()
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY SHELL DIALOGUE ROSTER CLOTH SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry shell dialogue roster cloth scene: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame


func _route(n: Node, want: String) -> bool:
	return n != null and str(n.get_meta("field_route", "")) == want


func _boot() -> void:
	GameState.new_game("壳对话名册旗学徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 40
	GameState.silver = 8000
	GameState.morale = 80
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _run_helpers() -> void:
	_boot()
	var host := Control.new()
	add_child(host)
	var shell := CKHeraldryField.place_shell_crest_strip(host, Vector2(8, 8))
	_ok(shell != null and shell.name == "ShellCrestStrip", "helper ShellCrestStrip")
	_ok(shell != null and shell.get_child_count() == 2, "helper shell child_count=2")
	var sbn := shell.find_child("ShellBanner", true, false) if shell else null
	_ok(_route(sbn, "shell_banner"), "helper shell_banner")
	_ok(sbn != null and str(sbn.get_meta("arms_kind", "")) == "lb_shell_arms", "helper shell kind")
	var dlg := CKHeraldryField.place_dialogue_crest_strip(host, Vector2(200, 8))
	_ok(dlg != null and dlg.name == "DialogueCrestStrip", "helper DialogueCrestStrip")
	_ok(dlg != null and dlg.get_child_count() == 2, "helper dialogue child_count=2")
	_ok(_route(dlg.find_child("DialogueBanner", true, false) if dlg else null, "dialogue_banner"), "helper dialogue_banner")
	var ros := CKHeraldryField.place_roster_crest_strip(host, Vector2(400, 8))
	_ok(ros != null and ros.name == "RosterCrestStrip", "helper RosterCrestStrip")
	_ok(ros != null and ros.get_child_count() == 2, "helper roster child_count=2")
	_ok(_route(ros.find_child("RosterBanner", true, false) if ros else null, "roster_banner"), "helper roster_banner")
	host.queue_free()
	await _settle(2)


func _assert_shell(tag: String) -> void:
	_boot()
	var page := _open(MENU)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("ShellCrestStrip", true, false)
	_ok(_route(strip, "shell_strip"), "%s/shell shell_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/shell strip_company" % tag)
		var bn := strip.find_child("ShellBanner", true, false)
		_ok(_route(bn, "shell_banner"), "%s/shell shell_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_shell_arms", "%s/shell ShellBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/shell child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _assert_dialogue(tag: String) -> void:
	_boot()
	var page: Control = (load(DIALOGUE) as PackedScene).instantiate()
	page.set("chapter_path", SAMPLE)
	page.set("lock_path", true)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	await _settle(14)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("DialogueCrestStrip", true, false)
	_ok(_route(strip, "dialogue_strip"), "%s/dialogue dialogue_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/dialogue strip_company" % tag)
		var bn := strip.find_child("DialogueBanner", true, false)
		_ok(_route(bn, "dialogue_banner"), "%s/dialogue dialogue_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_dialogue_arms", "%s/dialogue DialogueBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/dialogue child_count=2" % tag)
	var speaker := page.find_child("DialogueSpeakerArms", true, false)
	_ok(speaker != null and str(speaker.get_meta("field_route", "")) == "dialogue_speaker", "%s/dialogue speaker" % tag)
	page.queue_free()
	await _settle(2)


func _assert_roster(tag: String) -> void:
	_boot()
	var page := _open(ROSTER)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(8)
	var strip := page.find_child("RosterCrestStrip", true, false)
	_ok(_route(strip, "roster_strip"), "%s/roster roster_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/roster strip_company" % tag)
		var bn := strip.find_child("RosterBanner", true, false)
		_ok(_route(bn, "roster_banner"), "%s/roster roster_banner" % tag)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_roster_arms", "%s/roster RosterBanner kind" % tag)
		_ok(strip.get_child_count() == 2, "%s/roster child_count=2" % tag)
	page.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_shell(tag)
	await _assert_dialogue(tag)
	await _assert_roster(tag)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	await _run_pass("desk")


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	await _run_pass("mob")
	OS.set_environment("CK_FORCE_MOBILE", "")


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	for route in [
		"shell_strip", "shell_banner",
		"dialogue_strip", "dialogue_banner", "dialogue_speaker",
		"roster_strip", "roster_banner", "roster_row",
		"strip_company",
	]:
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	_ok(field.find('_cloth_beside(host, shield, "ShellBanner"') >= 0, "field shell via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "DialogueBanner"') >= 0, "field dialogue via _cloth_beside")
	_ok(field.find('_cloth_beside(host, shield, "RosterBanner"') >= 0, "field roster via _cloth_beside")
	_ok(field.find('"lb_shell_arms"') >= 0, "field lb_shell_arms")
	_ok(field.find('"lb_dialogue_arms"') >= 0, "field lb_dialogue_arms")
	_ok(field.find('"lb_roster_arms"') >= 0, "field lb_roster_arms")
	# Manual banner blocks must be gone for these three strips.
	_ok(field.find('bn.name = "ShellBanner"') < 0, "shell banner not manual")
	_ok(field.find('bn.name = "DialogueBanner"') < 0, "dialogue banner not manual")
	_ok(field.find('bn.name = "RosterBanner"') < 0, "roster banner not manual")
	var menu := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_ok(menu.find("CKHeraldryField.place_shell_crest_strip") >= 0
			or menu.find("CKHeraldryChrome.place_shell_crest_strip") >= 0, "main_menu wires shell Field")
	var ch := FileAccess.get_file_as_string("res://scripts/story/chapter_player.gd")
	_ok(ch.find("CKHeraldryField.place_dialogue_crest_strip") >= 0
			or ch.find("CKHeraldryChrome.place_dialogue_crest_strip") >= 0, "chapter_player wires dialogue Field")
	var ros := FileAccess.get_file_as_string("res://scripts/hub/roster.gd")
	_ok(ros.find("CKHeraldryField.place_roster_crest_strip") >= 0
			or ros.find("CKHeraldryChrome.place_roster_crest_strip") >= 0, "roster wires Field")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(loc.find("lb_shell_arms,") >= 0, "locale lb_shell_arms")
	_ok(loc.find("lb_dialogue_arms,") >= 0, "locale lb_dialogue_arms")
	_ok(loc.find("lb_roster_arms,") >= 0, "locale lb_roster_arms")
