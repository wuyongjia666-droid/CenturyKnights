extends Node
## Fat heraldry E2E: bloodline codex NationCrestStrip (团徽+邦徽) + rail CityNationArms, desktop + mobile.

const CODEX_SCN := preload("res://scenes/hub/bloodline_codex.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_helpers()
	if _fails.is_empty():
		print("CODEX CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL codex crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("图鉴徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false

func _assert_page(page: Node, where: String, nid: String) -> void:
	var strip := page.find_child("NationCrestStrip", true, false)
	_ok(strip != null, "%s NationCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var cn := strip.find_child("CityNationArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
		_ok(cn != null and str(cn.get_meta("arms_kind", "")) == "lb_city_arms", "%s 邦徽" % where)
		_ok(cn != null and str(cn.get_meta("nation_id", "")) == nid, "%s nation_id" % where)
		_ok(cn != null and ca != null and str(cn.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 邦徽!=团徽" % where)
	var btn := page.find_child("Nation_%s" % nid, true, false)
	_ok(btn != null, "%s Nation_%s button" % [where, nid])
	if btn != null:
		var rail_arms := btn.find_child("CityNationArms", true, false)
		_ok(rail_arms != null, "%s rail CityNationArms" % where)
		if rail_arms != null:
			_ok(str(rail_arms.get_meta("nation_id", "")) == nid, "%s rail nation_id" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var ids: Array = CKBloodline.nation_ids()
	_ok(not ids.is_empty(), "nation_ids nonempty")
	var nid := str(ids[0])
	var page: Control = CODEX_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "desk", nid)
	if ids.size() >= 2:
		var nid2 := str(ids[1])
		page.call("_show", nid2)
		await _settle(8)
		_assert_page(page, "desk-switch", nid2)
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var ids: Array = CKBloodline.nation_ids()
	var nid := str(ids[0]) if not ids.is_empty() else ""
	var page: Control = CODEX_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_page(page, "mob", nid)
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")

func _run_helpers() -> void:
	GameState.new_game("图鉴助", "灰旗", GameState.crest_color)
	var host := Control.new()
	add_child(host)
	var ids: Array = CKBloodline.nation_ids()
	var nid := str(ids[0]) if not ids.is_empty() else "ashbanner"
	var strip := CKHeraldryField.place_nation_crest_strip(host, nid, Vector2(10, 10), Vector2(36, 44))
	_ok(strip != null and strip.name == "NationCrestStrip", "helper NationCrestStrip")
	_ok(strip.find_child("CastleArms", true, false) != null, "helper CastleArms")
	_ok(strip.find_child("CityNationArms", true, false) != null, "helper CityNationArms")
	host.queue_free()
