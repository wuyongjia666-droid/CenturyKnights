extends Node
## Fat heraldry E2E: market via CKHeraldryField (MarketCrestStrip + field_route).

const SCN := preload("res://scenes/hub/market.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("MARKET FIELD CREST PASS")
		print("MARKET CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL market crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("市技血", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.food = 40
	GameState.iron = 40

func _assert_page(page: Node, where: String) -> void:
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null, "%s CastleBannerStrip" % where)
	var mkt = page.find_child("MarketCrestStrip", true, false)
	_ok(mkt != null, "%s MarketCrestStrip" % where)
	if mkt != null:
		_ok(str(mkt.get_meta("field_route", "")) == "market_strip", "%s field_route" % where)
		var bn = mkt.find_child("MarketBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_market_arms", "%s MarketBanner" % where)
	var src := FileAccess.get_file_as_string("res://scripts/hub/market.gd")
	_ok(src.find("CKHeraldryField.place_market_crest_strip") >= 0, "%s hub calls Field" % where)


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
		await _settle(6)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
