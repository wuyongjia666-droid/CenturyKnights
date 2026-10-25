extends Node
## Fat heraldry E2E: city side card + smith + market crest strips (团徽 + 邦徽), desktop + mobile.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("CITY CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL city crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot(cid: String) -> void:
	GameState.new_game("城徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 8000
	GameState.food = 40
	World.pos = cid
	World.arrive(cid)
	GameState.set_meta("city_id", cid)

func _assert_strip(page: Node, where: String, cid: String) -> void:
	var strip := page.find_child("CityCrestStrip", true, false)
	_ok(strip != null, "%s CityCrestStrip" % where)
	if strip == null:
		return
	var ca := strip.find_child("CastleArms", true, false)
	var cn := strip.find_child("CityNationArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
	_ok(cn != null and str(cn.get_meta("arms_kind", "")) == "lb_city_arms", "%s 邦徽" % where)
	var nid := World.nation_of(cid)
	_ok(cn != null and str(cn.get_meta("nation_id", "")) == nid, "%s nation_id" % where)
	_ok(cn != null and str(cn.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 邦徽≠团徽" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot("ash_capital")
	var page: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	_assert_strip(page, "desk-side", "ash_capital")
	page.call("_set_tab", "smith")
	await _settle(8)
	_assert_strip(page, "desk-smith", "ash_capital")
	page.call("_set_tab", "market")
	await _settle(8)
	_assert_strip(page, "desk-market", "ash_capital")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot("ash_capital")
	var page: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	_ok(bool(page.get("_mob")), "city._mob after force mobile")
	_assert_strip(page, "mob-side", "ash_capital")
	if World.smith_tier("ash_capital") > 0:
		page.call("_set_tab", "smith")
		await _settle(8)
		_assert_strip(page, "mob-smith", "ash_capital")
	page.call("_set_tab", "market")
	await _settle(8)
	_assert_strip(page, "mob-market", "ash_capital")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
