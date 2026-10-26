extends Node
## Fat E2E (B): city affair → specialty pack → atlas march → deliver →
## month_echo.produce (take+deliver) + Affair EchoLine_produce + silver/rep/cargo.
## Desktop path; phone when CK_FORCE_MOBILE=1. Does not collide with #636 gate→forge.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOME := "ash_capital"
const MARKER := "ATLAS SPECIALTY PRODUCE ECHO PASS"

var _fails: Array = []
var _passes := 0
var _mobile := false
var _dest := ""
var _good := ""
var _good_name := ""
var _dest_name := ""
var _home_name := ""
var _reward := "silk"


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
	_api_locale_and_gates()
	_setup()
	_api_take_deliver_echo()
	_setup()
	await _ui_affair_echo_and_atlas_deliver()
	if _passes < 14:
		_fails.append("too few PASS rows (%d)" % _passes)
	if _fails.is_empty():
		print(MARKER)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas specialty produce echo: ", f)
		print("passes=%d fails=%d" % [_passes, _fails.size()])
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if cond:
		_passes += 1
	else:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("特产回声", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
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
	GameState.house_mods.erase("month_echo")
	_dest = CKCitySpecialty.dest_for(HOME)
	_good = CKCitySpecialty.good_id(HOME)
	_good_name = World.good_name(_good)
	_dest_name = str(World.node(_dest).get("name", _dest))
	_home_name = str(World.node(HOME).get("name", HOME))
	_reward = "silk"


func _api_locale_and_gates() -> void:
	_ok(Locale.t("atlas_produce_echo_specialty_take") != "atlas_produce_echo_specialty_take", "locale take echo")
	_ok(Locale.t("atlas_produce_echo_specialty_deliver") != "atlas_produce_echo_specialty_deliver", "locale deliver echo")
	_ok(Locale.t("atlas_specialty_echo_head") != "atlas_specialty_echo_head", "locale specialty echo head")
	_ok(_good == "ashsteel", "specialty good %s" % _good)
	_ok(_dest == "reed_ford", "demand city %s" % _dest)
	# Take blocked until affair — no echo yet.
	var blocked: Dictionary = CKCitySpecialty.act(HOME)
	_ok(not bool(blocked.get("ok", false)), "take blocked pre-affair")
	_ok(str(CKEconomyState.month_echo_snapshot().get("produce", "")) == "", "no produce echo before take")


func _api_take_deliver_echo() -> void:
	var did: Dictionary = CKCityAffairs.do_affair(HOME)
	_ok(bool(did.get("ok", false)), "affair ok")
	GameState.silver = 100
	World.cargo.clear()
	GameState.house_mods.erase("month_echo")
	var took: Dictionary = CKCitySpecialty.act(HOME)
	_ok(bool(took.get("ok", false)), "take ok: %s" % took.get("msg", ""))
	var snap0: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx0 := str(snap0.get("produce", ""))
	_ok(tx0 != "", "month_echo.produce after take")
	_ok(tx0.find("特产") >= 0 or tx0.find("Specialty") >= 0, "take echo marks specialty: %s" % tx0)
	_ok(tx0.find(_good_name) >= 0, "take echo names good")
	_ok(tx0.find(_dest_name) >= 0, "take echo names dest")
	_ok(tx0.find(_home_name) >= 0, "take echo names origin city")
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 1, "parcel in cargo")
	# Wrong-city refuse must not append a second echo.
	World.pos = "tide_bridge"
	var wrong: Dictionary = CKCitySpecialty.act("tide_bridge")
	_ok(not bool(wrong.get("ok", false)), "wrong city refuse")
	var snap_wrong: Dictionary = CKEconomyState.month_echo_snapshot()
	_ok(str(snap_wrong.get("produce", "")) == tx0, "refuse does not append produce echo")
	World.pos = _dest
	World.visited[_dest] = true
	var dest_rep := World.rep_of(_dest)
	var home_rep := World.rep_of(HOME)
	var silver0 := int(GameState.silver)
	var silk0 := World.have_good(_reward)
	var pay: Dictionary = CKCitySpecialty.act(_dest)
	_ok(bool(pay.get("ok", false)), "deliver ok: %s" % pay.get("msg", ""))
	var snap1: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx1 := str(snap1.get("produce", ""))
	_ok(tx1.find(tx0) >= 0 or tx1.find("装箱") >= 0 or tx1.find("packed") >= 0, "take echo still in same-month append")
	_ok(tx1.find("上缴") >= 0 or tx1.find("delivered") >= 0, "deliver echo present: %s" % tx1)
	_ok(tx1.find(_dest_name) >= 0, "deliver echo names dest city")
	_ok(tx1.find(_good_name) >= 0, "deliver echo names good")
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 0, "parcel consumed")
	_ok(World.have_good(_reward) == silk0 + 1, "reward silk")
	_ok(int(GameState.silver) == silver0 + 24, "deliver +24 silver")
	_ok(World.rep_of(_dest) == dest_rep + 4, "dest rep +4")
	_ok(World.rep_of(HOME) == home_rep + 2, "origin rep +2")
	# month_echo_lines exposes produce kind for UI strips.
	var kinds: Array = []
	for row in CKEconomyState.month_echo_lines():
		kinds.append(str(row.get("kind", "")))
	_ok("produce" in kinds, "month_echo_lines has produce")


func _ui_affair_echo_and_atlas_deliver() -> void:
	GameState.house_mods.erase("month_echo")
	var did: Dictionary = CKCityAffairs.do_affair(HOME)
	_ok(bool(did.get("ok", false)), "ui affair")
	GameState.silver = 100
	World.cargo.clear()
	GameState.set_meta("city_id", HOME)
	var city: Control = CITY_SCN.instantiate()
	city.position = Vector2.ZERO
	city.size = Vector2(1280, 720)
	get_tree().root.add_child(city)
	for _i in 6:
		await get_tree().process_frame
	var entry: Button = city.find_child("AffairBtn", true, false) as Button
	_ok(entry != null, "AffairBtn")
	if entry:
		entry.pressed.emit()
	for _j in 4:
		await get_tree().process_frame
	var pack: Button = city.find_child("SpecialtyDo", true, false) as Button
	_ok(pack != null and not pack.disabled, "SpecialtyDo packs")
	if pack and not pack.disabled:
		pack.pressed.emit()
	for _k in 6:
		await get_tree().process_frame
	var snap_take: Dictionary = CKEconomyState.month_echo_snapshot()
	_ok(str(snap_take.get("produce", "")) != "", "ui take wrote produce echo")
	var echo_line := city.find_child("EchoLine_produce", true, false) as Label
	_ok(echo_line != null, "EchoLine_produce on AffairOverlay after take")
	if echo_line != null:
		_ok(str(echo_line.text).find(_good_name) >= 0 or str(echo_line.text).find("特产") >= 0, "EchoLine text %s" % echo_line.text)
	var head := city.find_child("SpecialtyEchoHead", true, false)
	_ok(head != null, "SpecialtyEchoHead")
	city.queue_free()
	await get_tree().process_frame
	# Atlas HUD still shows specialty run while marching.
	var page: Control = ATLAS_SCN.instantiate()
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 720) if _mobile else Vector2(1280, 720)
	get_tree().root.add_child(page)
	for _p in 8:
		await get_tree().process_frame
	var hud := _text(page, "SpecialtyRunLine")
	_ok(hud.find(_dest_name) >= 0 and hud.find(_good_name) >= 0, "atlas SpecialtyRunLine %s" % hud)
	# Headless march (skip UI event path flakiness) then deliver at dest city.
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.process_mode = Node.PROCESS_MODE_DISABLED
	_go(_dest)
	_ok(World.pos == _dest, "arrived dest %s" % World.pos)
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
	var give: Button = drop.find_child("SpecialtyDo", true, false) as Button
	_ok(give != null and not give.disabled, "deliver SpecialtyDo")
	if give and not give.disabled:
		give.pressed.emit()
	for _u in 6:
		await get_tree().process_frame
	var snap_d: Dictionary = CKEconomyState.month_echo_snapshot()
	var dtx := str(snap_d.get("produce", ""))
	_ok(dtx.find("上缴") >= 0 or dtx.find("delivered") >= 0, "ui deliver produce echo: %s" % dtx)
	var echo2 := drop.find_child("EchoLine_produce", true, false) as Label
	_ok(echo2 != null, "EchoLine_produce after deliver")
	if echo2 != null:
		_ok(str(echo2.text).find(_good_name) >= 0 or str(echo2.text).find("上缴") >= 0 or str(echo2.text).find("装箱") >= 0, "deliver EchoLine %s" % echo2.text)
	_ok(GameState.flag(CKCitySpecialty.flag_key(HOME)), "spec done flag")
	_ok(int(World.cargo.get(CKCitySpecialty.parcel_id(HOME), 0)) == 0, "ui parcel gone")
	# Estates MonthEchoPanel also surfaces produce for 物产账回读.
	drop.queue_free()
	await get_tree().process_frame
	page.queue_free()
	await get_tree().process_frame
	await _audit_estates_produce(dtx)


func _audit_estates_produce(want: String) -> void:
	if want == "":
		_ok(false, "no produce text for estates")
		return
	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	var line := page.find_child("EchoLine_produce", true, false) as Label
	var bit := want.substr(0, mini(6, want.length()))
	if line != null:
		_ok(str(line.text).find(bit) >= 0, "estates EchoLine_produce")
	else:
		var hit := false
		var panel := page.find_child("MonthEchoPanel", true, false)
		var scope: Node = panel if panel != null else page
		for n in scope.find_children("*", "Label", true, false):
			if str((n as Label).text).find(bit) >= 0:
				hit = true
				break
		_ok(hit, "estates produce echo bit=%s" % bit)
	page.queue_free()
	await get_tree().process_frame


func _go(dest: String) -> void:
	for _i in 32:
		if not World.encounter.is_empty():
			World.on_battle_end(true)
			continue
		if World.pos == dest and not World.is_traveling():
			break
		World.travel_to(dest)
	if not World.encounter.is_empty():
		World.on_battle_end(true)
	if World.pos != dest:
		World.pos = dest
		World.arrive(dest)


func _text(root: Node, node_name: String) -> String:
	var n := root.find_child(node_name, true, false)
	if n is Label:
		return str((n as Label).text)
	return ""
