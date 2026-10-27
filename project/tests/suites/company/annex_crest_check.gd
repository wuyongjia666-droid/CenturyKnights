extends Node
## Fat heraldry E2E: castle annex company header + CastleBannerStrip, desktop + mobile.

const SCN := preload("res://scenes/hub/annex.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("ANNEX CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL annex crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("兼并徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.iron = 40
	GameState.food = 40

func _assert_page(page: Node, where: String) -> void:
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null or page.find_child("CastleBanner", true, false) != null, "%s banner chrome" % where)
	var strip := page.find_child("AnnexCrestStrip", true, false)
	_ok(strip != null, "%s AnnexCrestStrip" % where)
	if strip != null:
		_ok(str(strip.get_meta("field_route", "")) == "annex_strip", "%s annex_strip" % where)
		var bn := strip.find_child("AnnexBanner", true, false)
		_ok(bn != null and str(bn.get_meta("field_route", "")) == "annex_banner", "%s annex_banner" % where)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_annex_arms", "%s lb_annex_arms" % where)
		_ok(strip.get_child_count() == 2, "%s annex child_count=2" % where)
	_ok(page.find_child("Upgrade", true, false) != null or page.find_child("Art", true, false) != null, "%s annex body" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	page.set_meta("annex", "infirmary")
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
	page.set_meta("annex", "academy")
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
