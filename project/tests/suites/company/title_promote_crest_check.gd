extends Node
## Fat heraldry E2E: title_promote MusterCrestStrip + LeaderArms + LadderBadge via Field.
## Desk + mobile.

const SCN := preload("res://scenes/hub/title_promote.tscn")
var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_run_sources()
	if _fails.is_empty():
		print("TITLE PROMOTE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL title promote crest: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("职印徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000


func _assert_page(page: Node, where: String) -> void:
	var strip := page.find_child("MusterCrestStrip", true, false)
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "muster_strip", "%s muster field_route" % where)
	_ok(strip != null, "%s MusterCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var la := strip.find_child("LeaderArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
		_ok(la != null and str(la.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s strip LeaderArms" % where)
	var lead := page.find_child("LeaderArms", true, false)
	# Prefer the paint-row LeaderArms (field_route title_leader) over strip child.
	for n in page.find_children("LeaderArms", "", true, false):
		if str(n.get_meta("field_route", "")) == "title_leader":
			lead = n
			break
	_ok(lead != null and str(lead.get_meta("field_route", "")) == "title_leader", "%s LeaderArms field_route" % where)
	_ok(lead != null and str(lead.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s LeaderArms kind" % where)
	var badges: Array = []
	for n in page.find_children("LadderBadge", "", true, false):
		if str(n.get_meta("field_route", "")) == "title_ladder_badge":
			badges.append(n)
	_ok(badges.size() >= 3, "%s LadderBadge count>=3 got %d" % [where, badges.size()])
	for b in badges:
		_ok(str(b.get_meta("rank_id", "")) != "", "%s LadderBadge rank_id" % where)
		_ok(b.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s LadderBadge mouse" % where)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(8)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")


func _run_sources() -> void:
	var hub := FileAccess.get_file_as_string("res://scripts/hub/title_promote.gd")
	_ok(hub.find("CKHeraldryField.attach_title_leader_arms") >= 0, "hub LeaderArms → Field")
	_ok(hub.find("CKHeraldryField.attach_ladder_badge") >= 0, "hub LadderBadge → Field")
	_ok(hub.find("CKHeraldryChrome.make_person_arms") < 0, "hub no Chrome person arms")
	_ok(hub.find("CKHeraldryChrome.make_rank_badge") < 0, "hub no Chrome rank badge")
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("static func attach_title_leader_arms") >= 0, "field owns title leader")
	_ok(field.find("static func attach_ladder_badge") >= 0, "field owns ladder badge")
	var host := Control.new()
	get_tree().root.add_child(host)
	var lead: CKCharacter = GameState.get_leader()
	var arms := CKHeraldryField.attach_title_leader_arms(host, lead, Vector2(4, 4), Vector2(36, 44))
	_ok(arms != null and arms.name == "LeaderArms", "api LeaderArms name")
	_ok(arms != null and str(arms.get_meta("field_route", "")) == "title_leader", "api LeaderArms route")
	var again := CKHeraldryField.attach_title_leader_arms(host, lead, Vector2(8, 8), Vector2(36, 44))
	_ok(again != null and again != arms, "api LeaderArms retires previous")
	var badge := CKHeraldryField.attach_ladder_badge(host, "knight", 24)
	_ok(badge != null and str(badge.get_meta("field_route", "")) == "title_ladder_badge", "api LadderBadge route")
	_ok(badge != null and str(badge.get_meta("rank_id", "")) == "knight", "api LadderBadge rank")
	host.queue_free()
