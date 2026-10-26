extends Node
## Fat heraldry E2E: Field marriage protocol strip (团徽 + suitor + spouse) + HouseArms, desktop + mobile.

const MARRIAGE_SCN := preload("res://scenes/hub/marriage.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_helpers()
	if _fails.is_empty():
		print("MARRIAGE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL marriage crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("联姻徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.reputation["ashland"] = 90
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = "m"
	GameState.refresh_marriage_candidates("", lead)
	_ok(not GameState.marriage_candidates.is_empty(), "seed marriage_candidates")

func _assert_strip(page: Node, where: String) -> void:
	var strip := page.find_child("MarriageCrestStrip", true, false)
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "marriage_strip", "marriage_strip")
	_ok(strip != null, "%s MarriageCrestStrip" % where)
	if strip == null:
		return
	var ca := strip.find_child("CastleArms", true, false)
	var la := strip.find_child("LeftArms", true, false)
	var ra := strip.find_child("RightArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
	_ok(la != null and str(la.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s LeftArms (suitor)" % where)
	_ok(ra != null and str(ra.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s RightArms (candidate)" % where)
	if la != null and ca != null:
		_ok(str(la.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s suitor!=团徽" % where)
	if ra != null and la != null:
		_ok(str(ra.get_meta("arms_core", "")) != "" and str(la.get_meta("arms_core", "")) != "", "%s person cores set" % where)
	_ok(bool(strip.get_meta("has_left", false)) and bool(strip.get_meta("has_right", false)), "%s strip metas" % where)

func _assert_house_arms(page: Node, where: String, expect: int) -> void:
	var arms: Array = []
	_collect_named(page, "HouseArms", arms)
	_ok(arms.size() >= expect, "%s HouseArms count>=%d got %d" % [where, expect, arms.size()])
	for a in arms:
		_ok(str(a.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s HouseArms kind" % where)
		_ok(str(a.get_meta("arms_core", "")) != "", "%s HouseArms core" % where)
		_ok(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s HouseArms mouse" % where)

func _collect_named(n: Node, nm: String, out: Array) -> void:
	if str(n.name) == nm:
		out.append(n)
	for c in n.get_children():
		_collect_named(c, nm, out)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = MARRIAGE_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_strip(page, "desk")
	_assert_house_arms(page, "desk", 2)
	var vow := page.find_child("VowCompanyArms", true, false)
	_ok(vow != null and str(vow.get_meta("arms_kind", "")) == "gen2_36", "desk VowCompanyArms")
	# Re-place after selecting another candidate keeps strip alive.
	if GameState.marriage_candidates.size() >= 2:
		page.call("_select", GameState.marriage_candidates[1])
		await _settle(8)
		_assert_strip(page, "desk-reselect")
		_assert_house_arms(page, "desk-reselect", 2)
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = MARRIAGE_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_ok(bool(page.get("_mob")), "marriage._mob after force mobile")
	_assert_strip(page, "mob")
	_assert_house_arms(page, "mob", 2)
	var strip := page.find_child("MarriageCrestStrip", true, false) as Control
	if strip != null:
		var vp := page.get_viewport_rect().size
		_ok(strip.position.x >= vp.x * 0.4 or strip.position.y <= 24.0, "mob strip right/top anchored")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")

func _run_helpers() -> void:
	GameState.new_game("徽助手", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	GameState.refresh_marriage_candidates("", lead)
	var cand = GameState.marriage_candidates[0] if not GameState.marriage_candidates.is_empty() else null
	var host := Control.new()
	add_child(host)
	var strip := CKHeraldryField.place_marriage_crest_strip(host, lead, cand, Vector2(10, 10), Vector2(36, 44))
	_ok(strip != null and strip.name == "MarriageCrestStrip", "helper place strip")
	_ok(strip.find_child("CastleArms", true, false) != null, "helper CastleArms")
	_ok(strip.find_child("LeftArms", true, false) != null, "helper LeftArms")
	if cand != null:
		_ok(strip.find_child("RightArms", true, false) != null, "helper RightArms")
	CKHeraldryField.attach_house_card_arms(host, lead, Rect2(0, 0, 120, 128), Vector2(32, 38))
	_ok(host.get_node_or_null("HouseArms") != null, "helper HouseArms")
	# Re-place renames dying strip (no name clash).
	var strip2 := CKHeraldryField.place_marriage_crest_strip(host, lead, cand, Vector2(20, 20), Vector2(28, 34))
	_ok(strip2 != null and host.get_node_or_null("MarriageCrestStrip") == strip2, "helper re-place")
	host.queue_free()
