extends Node
## Arrive city -> resolve 本城之事 -> pack regional specialty -> atlas march ->
## deliver at the demanding city. Flag, cargo, silver, and reputation all move.
## Desktop, or phone when CK_FORCE_MOBILE=1 (mobile_* scene).

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOME := "ash_capital"

var _fails: Array = []
var _mobile := false
var _dest := ""
var _good := ""
var _good_name := ""
var _dest_name := ""
var _reward := ""


func _ready() -> void:
	await get_tree().process_frame
	_mobile = DeviceProfile.is_mobile()
	if _mobile:
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.size = Vector2i(2400, 1080)
		await get_tree().process_frame
		await get_tree().process_frame
	_setup()
	_api()
	_setup()
	await _ui()
	if _fails.is_empty():
		print("ATLAS CITY AFFAIRS SPECIALTY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas city affairs specialty: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("本城特产", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	World.events_enabled = false
	World.rivals_enabled = false
	World.active.clear()
	World.cargo.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.city_visit = {}
	World.last_city_sortie.clear()
	World.pos = HOME
	World.visited[HOME] = true
	World.rep_city[HOME] = 12
	GameState.silver = 100
	GameState.iron = 5
	GameState.food = 80
	GameState.morale = 80
	_dest = CKCitySpecialty.dest_for(HOME)
	_good = CKCitySpecialty.good_id(HOME)
	_good_name = World.good_name(_good)
	_dest_name = str(World.node(_dest).get("name", _dest))
	_reward = "silk"


func _api() -> void:
	_ok(_good == "ashsteel", "specialty good %s" % _good)
	_ok(_dest == "reed_ford", "demand city %s" % _dest)
	_ok(int(World.route(HOME, _dest).get("days", 0)) >= 1, "route has days")
	var blocked: Dictionary = CKCitySpecialty.act(HOME)
	_ok(not bool(blocked.get("ok", false)) and str(blocked.get("msg", "")).find("本城之事") >= 0, "take blocked until affair: %s" % blocked.get("msg", ""))
	var cost: Dictionary = CKCityAffairs.template_for(HOME).get("cost", {})
	_ok(int(cost.get("silver", 0)) == 20, "ash capital affair is the 20-silver honor gift, cost %s" % cost)
	GameState.silver = 0
	var broke: Dictionary = CKCityAffairs.do_affair(HOME)
	_ok(not bool(broke.get("ok", false)) and str(broke.get("msg", "")).find("银") >= 0, "affair refuses when silver is short: %s" % broke.get("msg", ""))
	GameState.silver = 100
	var rep0 := World.rep_of(HOME)
	var did: Dictionary = CKCityAffairs.do_affair(HOME)
	_ok(bool(did.get("ok", false)), "affair ok %s" % did.get("msg", ""))
	_ok(GameState.flag(CKCityAffairs.flag_key(HOME)), "affair flag")
	_ok(int(GameState.silver) == 80, "affair spent 20 silver, left %d" % int(GameState.silver))
	_ok(World.rep_of(HOME) == rep0 + 2, "affair rep +2")
	_ok(not bool(CKCityAffairs.do_affair(HOME).get("ok", false)), "affair does not repeat")
	GameState.silver = 3
	var poor: Dictionary = CKCitySpecialty.act(HOME)
	_ok(not bool(poor.get("ok", false)) and str(poor.get("msg", "")).find("银") >= 0, "crate needs silver: %s" % poor.get("msg", ""))
	GameState.silver = 100
	World.cargo["silk"] = World.cargo_cap()
	var full: Dictionary = CKCitySpecialty.act(HOME)
	_ok(not bool(full.get("ok", false)) and str(full.get("msg", "")).find("货舱") >= 0, "crate needs hold space: %s" % full.get("msg", ""))
	World.cargo.clear()
	var took: Dictionary = CKCitySpecialty.act(HOME)
	_ok(bool(took.get("ok", false)), "take ok %s" % took.get("msg", ""))
	_ok(int(GameState.silver) == 92, "take spent 8 silver, left %d" % int(GameState.silver))
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 1, "parcel in cargo")
	_ok(str(CKCitySpecialty.run().get("to", "")) == _dest, "run dest")
	_ok(CKCitySpecialty.hud_text().find(_dest_name) >= 0 and CKCitySpecialty.hud_text().find(_good_name) >= 0, "hud %s" % CKCitySpecialty.hud_text())
	_ok(not bool(CKCitySpecialty.act(HOME).get("ok", false)), "second crate blocked")
	World.pos = "tide_bridge"
	var wrong: Dictionary = CKCitySpecialty.act("tide_bridge")
	_ok(not bool(wrong.get("ok", false)), "wrong city refuses deliver: %s" % wrong.get("msg", ""))
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 1, "parcel kept")
	_roundtrip()
	_ok(str(CKCitySpecialty.run().get("to", "")) == _dest, "run survived save")
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 1, "parcel survived save")
	World.pos = _dest
	var dest_rep := World.rep_of(_dest)
	var home_rep := World.rep_of(HOME)
	var silk0 := World.have_good(_reward)
	var pay: Dictionary = CKCitySpecialty.act(_dest)
	_ok(bool(pay.get("ok", false)), "deliver ok %s" % pay.get("msg", ""))
	_ok(str(pay.get("msg", "")).find("声望") >= 0 and str(pay.get("msg", "")).find(_good_name) >= 0, "deliver text %s" % pay.get("msg", ""))
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 0, "parcel consumed")
	_ok(World.have_good(_reward) == silk0 + 1, "reward silk in cargo")
	_ok(int(GameState.silver) == 116, "deliver silver %d" % int(GameState.silver))
	_ok(World.rep_of(_dest) == dest_rep + 4, "dest rep +4")
	_ok(World.rep_of(HOME) == home_rep + 2, "origin rep +2")
	_ok(GameState.flag(CKCitySpecialty.flag_key(HOME)), "spec flag")
	_ok(CKCitySpecialty.hud_text() == "", "hud cleared")
	_ok(str(CKCitySpecialty.card(HOME).get("phase", "")) == "done", "origin card done")
	_ok(not bool(CKCitySpecialty.act(_dest).get("ok", false)), "deliver does not repeat")


func _roundtrip() -> void:
	var raw := JSON.stringify({
		"chapter0_flags": GameState.story.flags.duplicate(true),
		"cargo": World.cargo.duplicate(),
	})
	var parsed = JSON.parse_string(raw)
	_ok(typeof(parsed) == TYPE_DICTIONARY, "save json")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	GameState.story.flags.clear()
	World.cargo.clear()
	var flags: Dictionary = parsed.get("chapter0_flags", {})
	for k in flags.keys():
		GameState.story.flags[str(k)] = flags[k]
	var cargo: Dictionary = parsed.get("cargo", {})
	for k2 in cargo.keys():
		World.cargo[str(k2)] = int(cargo[k2])


func _ui() -> void:
	GameState.set_meta("city_id", HOME)
	var city: Control = CITY_SCN.instantiate()
	city.position = Vector2.ZERO
	city.size = Vector2(1280, 720)
	get_tree().root.add_child(city)
	for _i in 6:
		await get_tree().process_frame
	var entry: Button = city.find_child("AffairBtn", true, false) as Button
	_ok(entry != null, "AffairBtn entry")
	if entry:
		entry.pressed.emit()
	for _j in 4:
		await get_tree().process_frame
	var overlay := city.find_child("AffairOverlay", true, false)
	_ok(overlay != null, "AffairOverlay")
	if overlay == null:
		city.queue_free()
		return
	_ok(_text(city, "AffairLabel") == CKCityAffairs.label(HOME), "affair cost readable %s" % _text(city, "AffairLabel"))
	_ok(_text(city, "SpecialtyWhy").find("本城之事") >= 0, "specialty waits on affair %s" % _text(city, "SpecialtyWhy"))
	_ok(_text(city, "SpecialtyBody").find(_dest_name) >= 0 and _text(city, "SpecialtyBody").find(_good_name) >= 0, "offer names good and city %s" % _text(city, "SpecialtyBody"))
	var locked: Button = city.find_child("SpecialtyDo", true, false) as Button
	_ok(locked != null and locked.disabled, "SpecialtyDo locked before affair")
	var affair: Button = city.find_child("AffairDo", true, false) as Button
	_ok(affair != null and not affair.disabled, "AffairDo enabled")
	if not _mobile:
		var ov0 := city.find_child("AffairOverlay", true, false)
		_ok(ov0 != null, "overlay alive for hit sizes")
		if ov0 != null:
			for b in ov0.find_children("*", "Button", true, false):
				var btn := b as Button
				if btn.get_combined_minimum_size().y < 48:
					_fails.append("small button %s" % btn.text)
					print("ROW FAIL small button %s" % btn.text)
	if affair and not affair.disabled:
		affair.pressed.emit()
	for _k in 4:
		await get_tree().process_frame
	_ok(_text(city, "AffairMsg").find("声望") >= 0, "affair feedback %s" % _text(city, "AffairMsg"))
	_ok(GameState.flag(CKCityAffairs.flag_key(HOME)), "ui affair flag")
	_ok(_text(city, "SpecialtyCost").find("8") >= 0, "crate cost %s" % _text(city, "SpecialtyCost"))
	_ok(_text(city, "SpecialtyPay").find("24") >= 0 and _text(city, "SpecialtyPay").find(_dest_name) >= 0, "payoff preview %s" % _text(city, "SpecialtyPay"))
	var pack: Button = city.find_child("SpecialtyDo", true, false) as Button
	_ok(pack != null and not pack.disabled, "SpecialtyDo packs")
	if _mobile:
		_ok(_font(city.find_child("SpecialtyBody", true, false)) >= 22, "mobile body font")
		_ok(_font(city.find_child("SpecialtyCost", true, false)) >= 22, "mobile cost font")
		_ok(pack != null and pack.custom_minimum_size.y + 0.5 >= MobilePage.HIT * 0.9, "mobile SpecialtyDo hit")
		_ok(pack != null and _font(pack) >= 22, "mobile SpecialtyDo font")
	if pack and not pack.disabled:
		pack.pressed.emit()
	for _n in 4:
		await get_tree().process_frame
	_ok(_text(city, "AffairMsg").find(_dest_name) >= 0, "packed feedback %s" % _text(city, "AffairMsg"))
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 1, "ui parcel")
	_ok(_text(city, "SpecialtyHold").find(_good_name) >= 0, "hold line %s" % _text(city, "SpecialtyHold"))
	city.queue_free()
	await get_tree().process_frame
	var page: Control = ATLAS_SCN.instantiate()
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 720) if _mobile else Vector2(1280, 720)
	get_tree().root.add_child(page)
	for _p in 8:
		await get_tree().process_frame
	var hud := _text(page, "SpecialtyRunLine")
	_ok(hud.find(_dest_name) >= 0 and hud.find(_good_name) >= 0, "atlas line %s" % hud)
	if _mobile:
		_ok(_font(page.find_child("SpecialtyRunLine", true, false)) >= 22, "mobile atlas line font")
	if World.nation_of(_dest) != World.nation_of(World.pos) and page.has_method("_show_view"):
		page.call("_show_view", World.nation_of(_dest))
		for _q in 4:
			await get_tree().process_frame
	var node_b: Button = page.find_child("Node_" + _dest, true, false) as Button
	_ok(node_b != null, "atlas node Node_%s" % _dest)
	if node_b:
		node_b.pressed.emit()
	for _r in 4:
		await get_tree().process_frame
	var go: Button = page.find_child("GoButton", true, false) as Button
	_ok(go != null and not go.disabled, "GoButton")
	# pressed.emit rebuilds the profile and frees GoButton mid-signal. Same handler, next frame.
	if go and not go.disabled and page.has_method("_start_travel"):
		page.call_deferred("_start_travel")
	var event: Node = await _wait_named(page, "EventModal", 8000)
	_ok(event != null, "camp on the specialty road")
	if event != null:
		var opt: Button = page.find_child("EventOpt0", true, false) as Button
		_ok(opt != null, "EventOpt0")
		if opt:
			opt.pressed.emit()
		var cont: Button = await _wait_button(page, "AftermathContinue", 4000)
		_ok(cont != null, "AftermathContinue")
		if cont:
			cont.pressed.emit()
	var arrived := await _wait_pos(page, _dest, 12000)
	_ok(arrived, "atlas arrived at %s pos=%s" % [_dest_name, World.pos])
	_ok(_text(page, "SpecialtyRunLine").find(_dest_name) >= 0, "line still up at destination")
	var idle_until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < idle_until and bool(page._busy):
		await get_tree().process_frame
	for _idle in 8:
		await get_tree().process_frame
	var dest_rep := World.rep_of(_dest)
	var home_rep := World.rep_of(HOME)
	var silver0 := int(GameState.silver)
	# Leave the atlas mounted. Freeing it while the march coroutine is unwinding crashes headless Godot.
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.set_meta("city_id", _dest)
	var drop: Control = CITY_SCN.instantiate()
	drop.position = Vector2.ZERO
	drop.size = Vector2(1280, 720)
	get_tree().root.add_child(drop)
	for _s in 6:
		await get_tree().process_frame
	var again: Button = drop.find_child("AffairBtn", true, false) as Button
	_ok(again != null, "dest AffairBtn")
	if again:
		again.pressed.emit()
	for _t in 4:
		await get_tree().process_frame
	_ok(_text(drop, "SpecialtyBody").find(_good_name) >= 0, "deliver body %s" % _text(drop, "SpecialtyBody"))
	var give: Button = drop.find_child("SpecialtyDo", true, false) as Button
	_ok(give != null and not give.disabled, "deliver button")
	if _mobile and give:
		_ok(give.custom_minimum_size.y + 0.5 >= MobilePage.HIT * 0.9, "mobile deliver hit")
		_ok(_font(give) >= 22, "mobile deliver font")
	if give and not give.disabled:
		give.pressed.emit()
	for _u in 4:
		await get_tree().process_frame
	var msg := _text(drop, "AffairMsg")
	_ok(msg.find("声望") >= 0 and msg.find(_good_name) >= 0, "deliver feedback %s" % msg)
	_ok(GameState.flag(CKCitySpecialty.flag_key(HOME)), "ui spec flag")
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 0, "ui parcel consumed")
	_ok(World.have_good(_reward) >= 1, "ui reward cargo")
	_ok(int(GameState.silver) == silver0 + 24, "ui silver +24 (%d -> %d)" % [silver0, int(GameState.silver)])
	_ok(World.rep_of(_dest) == dest_rep + 4, "ui dest rep")
	_ok(World.rep_of(HOME) == home_rep + 2, "ui origin rep")
	drop.queue_free()
	await get_tree().process_frame
	World.pos = HOME
	GameState.set_meta("city_id", HOME)
	var back: Control = CITY_SCN.instantiate()
	back.position = Vector2.ZERO
	back.size = Vector2(1280, 720)
	get_tree().root.add_child(back)
	for _v in 4:
		await get_tree().process_frame
	var home_btn: Button = back.find_child("AffairBtn", true, false) as Button
	if home_btn:
		home_btn.pressed.emit()
	for _w in 3:
		await get_tree().process_frame
	_ok(_text(back, "SpecialtyBody").find("已经送过") >= 0, "done line %s" % _text(back, "SpecialtyBody"))
	var done_b: Button = back.find_child("SpecialtyDo", true, false) as Button
	_ok(done_b != null and done_b.disabled, "done button locked")
	back.queue_free()


func _text(root: Node, node_name: String) -> String:
	var n := root.find_child(node_name, true, false)
	if n is Label:
		return str((n as Label).text)
	return ""


func _font(n: Node) -> int:
	if n is Control:
		return (n as Control).get_theme_font_size("font_size")
	return 0


func _wait_named(page: Node, node_name: String, ms: int) -> Node:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		var n := page.find_child(node_name, true, false)
		if n != null:
			return n
		await get_tree().process_frame
	return null


func _wait_button(page: Node, node_name: String, ms: int) -> Button:
	var n := await _wait_named(page, node_name, ms)
	return n as Button


func _wait_pos(page: Node, id: String, ms: int) -> bool:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		if World.pos == id and not World.is_traveling() and page.find_child("EventModal", true, false) == null and page.find_child("AftermathModal", true, false) == null:
			return true
		await get_tree().process_frame
	return World.pos == id and not World.is_traveling()
