extends Node
## Fat heraldry E2E: shrine company header + castle banner strip + NationCrestStrip, desktop + mobile.

const SHRINE_SCN := preload("res://scenes/hub/shrine.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("SHRINE CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL shrine crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("神殿徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")

func _assert_page(page: Node, where: String) -> void:
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms (header/strip)" % where)
	var strip := page.find_child("NationCrestStrip", true, false)
	_ok(strip != null, "%s NationCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var cn := strip.find_child("CityNationArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
		_ok(cn != null and str(cn.get_meta("arms_kind", "")) == "lb_city_arms", "%s strip 邦徽" % where)
		_ok(cn != null and ca != null and str(cn.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 邦徽!=团徽" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null or page.find_child("CastleBanner", true, false) != null, "%s banner chrome" % where)
	_ok(page.find_child("HealCard", true, false) != null, "%s HealCard still present" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SHRINE_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SHRINE_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
