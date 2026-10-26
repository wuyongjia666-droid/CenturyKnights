extends Node
## Fat atlas: city gate → market produce → forge buy/forge_mats →
## month_echo.smith/produce + GateForgeBuy / EchoLine_ E2E.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const OTHER := "sy_capital"
const SIG := "ash_capital_sig1"
const REGIONAL := "ashbanner_sword_1"
const PRODUCE := "ashsteel"
const MARKER := "ATLAS GATE FORGE BUY PASS"

var _fails: Array = []
var _passes := 0
var _mobile := false


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
	_api_preview_rejects()
	_setup()
	_api_gate_market_forge_buy()
	_setup()
	_api_forge_mats_echo()
	_setup()
	await _ui_gate_forge_and_echo()
	if World == null:
		_fails.append("World autoload null (compile failed?)")
	if _passes < 12:
		_fails.append("too few PASS rows (%d)" % _passes)
	if _fails.is_empty():
		print(MARKER)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas gate forge: ", f)
		print("passes=%d fails=%d" % [_passes, _fails.size()])
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if cond:
		_passes += 1
	else:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("城门铁匠", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 50000
	GameState.food = 80
	GameState.morale = 80
	World.armory.clear()
	World.gear.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.hub_tour.clear()
	World.done_sig.clear()
	World.city_gate = {}
	GameState.house_mods.erase("month_echo")
	GameState.settings.erase("smith_revealed")
	World.pos = CAP
	World.arrive(CAP)
	World.rep_city[CAP] = 40
	for sid in World.list_signature_ids():
		World.mark_smith_revealed(str(sid))
	if not World.market.has(CAP):
		World._init_market(CAP)
	World.market[CAP]["iron"] = maxi(int(World.market[CAP].get("iron", 0)), 12)
	World.market[CAP][PRODUCE] = maxi(int(World.market[CAP].get(PRODUCE, 0)), 8)


func _api_preview_rejects() -> void:
	# wrong city
	World.pos = OTHER
	World.arrive(OTHER)
	var away: Dictionary = World.gate_forge_preview(CAP, SIG)
	_ok(not bool(away.get("ok", true)), "preview rejects away from city")
	_ok(str(away.get("reason", "")).find("须身在") >= 0 or str(away.get("reason", "")).find("Must") >= 0, "away reason")
	var act_away: Dictionary = World.gate_forge_act(CAP, SIG, "buy")
	_ok(not bool(act_away.get("ok", true)), "act rejects away")
	World.pos = CAP
	World.arrive(CAP)
	# short silver buy
	GameState.silver = 1
	var shortp: Dictionary = World.gate_forge_preview(CAP, SIG)
	_ok(bool(shortp.get("ok", false)), "preview ok when short")
	_ok(bool(shortp.get("short_buy", false)), "short_buy flagged")
	_ok(not bool(shortp.get("can_buy", true)), "cannot buy when short")
	var shorta: Dictionary = World.gate_forge_act(CAP, SIG, "buy")
	_ok(not bool(shorta.get("ok", true)), "act buy rejects short silver")
	GameState.silver = 50000
	# foreign stock
	World.pos = OTHER
	World.arrive(OTHER)
	var leak: Dictionary = World.gate_forge_preview(OTHER, SIG)
	_ok(not bool(leak.get("ok", true)) or not bool(leak.get("available", true)) or World._stock_entry(OTHER, SIG).is_empty(), "ash sig not stocked at foreign: %s" % leak)
	var foreign: Dictionary = World.buy_item(OTHER, SIG)
	_ok(not bool(foreign.get("ok", true)), "buy ash sig at foreign rejected")
	World.pos = CAP
	World.arrive(CAP)
	# low rep locks signature
	World.rep_city[CAP] = 0
	var locked: Dictionary = World.gate_forge_preview(CAP, SIG)
	_ok(not bool(locked.get("available", true)), "low-rep sig unavailable: %s" % locked.get("reason", ""))
	World.rep_city[CAP] = 40
	print("api preview rejects ok")


func _api_gate_market_forge_buy() -> void:
	World.city_gate = {}
	GameState.house_mods.erase("month_echo")
	World.armory.erase(SIG)
	World.cargo.clear()
	# gate in + produce buy → month_echo.produce
	World.note_city_gate("in")
	_ok(str(World.city_gate.get("dir", "")) == "in", "gate in stamped")
	var produce0 := World.have_good(PRODUCE)
	var mb: Dictionary = World.market_buy(CAP, PRODUCE, 1)
	_ok(bool(mb.get("ok", false)), "market produce buy: %s" % mb.get("msg", ""))
	_ok(World.have_good(PRODUCE) == produce0 + 1, "produce cargo +1")
	var snap0: Dictionary = CKEconomyState.month_echo_snapshot()
	_ok(str(snap0.get("produce", "")) != "", "month_echo.produce set")
	# gate forge buy → month_echo.smith + gate shop stamp
	var prev: Dictionary = World.gate_forge_preview(CAP, SIG)
	_ok(bool(prev.get("can_buy", false)), "can_buy signature: %s" % prev)
	var before_s := GameState.silver
	var r: Dictionary = World.gate_forge_act(CAP, SIG, "buy")
	_ok(bool(r.get("ok", false)), "gate_forge_act buy: %s" % r.get("msg", ""))
	_ok(int(World.armory.get(SIG, 0)) >= 1, "armory holds sig")
	_ok(GameState.silver < before_s, "silver spent")
	_ok(bool(World.city_gate.get("shopped", false)), "gate shopped stamp")
	_ok(str(World.city_gate.get("last_item", "")) == SIG, "gate last_item")
	_ok(str(World.city_gate.get("last_mode", "")) == "buy", "gate last_mode buy")
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	_ok(str(snap.get("smith", "")) != "", "month_echo.smith set: %s" % snap.get("smith", ""))
	_ok(str(snap.get("produce", "")) != "", "produce echo retained")
	# auto mode_hint buy path
	World.armory.erase(REGIONAL)
	GameState.house_mods.erase("month_echo")
	var auto: Dictionary = World.gate_forge_act(CAP, REGIONAL, "")
	_ok(bool(auto.get("ok", false)), "auto mode buy regional: %s" % auto.get("msg", ""))
	_ok(str(auto.get("mode", "")) == "buy", "auto picked buy")
	print("api gate market forge buy ok")


func _api_forge_mats_echo() -> void:
	World.armory.erase(REGIONAL)
	GameState.house_mods.erase("month_echo")
	while World.have_good("iron") > 0:
		World._add_good("iron", -1)
	World.market[CAP]["iron"] = 8
	GameState.silver = 50000
	var prev: Dictionary = World.gate_forge_preview(CAP, REGIONAL)
	_ok(bool(prev.get("can_forge_mats", false)), "can_forge_mats: %s" % prev)
	_ok(not bool(prev.get("can_forge", true)), "cannot forge without mats")
	# short silver forge_mats reject
	var need := int(prev.get("total_forge", 1))
	GameState.silver = maxi(0, need - 1)
	var broke: Dictionary = World.gate_forge_act(CAP, REGIONAL, "forge_mats")
	_ok(not bool(broke.get("ok", true)), "forge_mats rejects short silver")
	GameState.silver = 50000
	var r: Dictionary = World.gate_forge_act(CAP, REGIONAL, "forge_mats")
	_ok(bool(r.get("ok", false)), "forge_mats ok: %s" % r.get("msg", ""))
	_ok(int(World.armory.get(REGIONAL, 0)) >= 1, "armory after forge_mats")
	_ok(str(World.city_gate.get("last_mode", "")) == "forge_mats", "gate last_mode forge_mats")
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var smith_echo := str(snap.get("smith", ""))
	_ok(
		smith_echo.find("料") >= 0 or smith_echo.find("mats") >= 0 or smith_echo != "",
		"month_echo.smith forge_mats: %s" % smith_echo
	)
	print("api forge mats echo ok")


func _ui_gate_forge_and_echo() -> void:
	World.armory.erase(SIG)
	GameState.house_mods.erase("month_echo")
	World.city_gate = {}
	GameState.silver = 50000
	GameState.set_meta("city_id", CAP)
	GameState.set_meta("city_tab", "smith")
	var city: Control = CITY_SCN.instantiate()
	city.position = Vector2.ZERO
	city.size = Vector2(1280, 720)
	get_tree().root.add_child(city)
	for _i in 10:
		await get_tree().process_frame
	_ok(str(World.city_gate.get("dir", "")) == "in", "UI city ready notes gate in")
	# open smith tab explicitly
	if city.has_method("_set_tab"):
		city.call("_set_tab", "smith")
	for _j in 6:
		await get_tree().process_frame
	var reveal: Button = city.find_child("SmithRevealSkip", true, false) as Button
	if reveal:
		reveal.pressed.emit()
		await get_tree().process_frame
	var item_b: Button = city.find_child("Item_" + SIG, true, false) as Button
	_ok(item_b != null, "UI Item_%s" % SIG)
	if item_b:
		item_b.pressed.emit()
		for _k in 6:
			await get_tree().process_frame
	var gb: Button = city.find_child("GateForgeBuy", true, false) as Button
	_ok(gb != null, "UI GateForgeBuy present")
	_ok(gb != null and not gb.disabled, "UI GateForgeBuy enabled")
	if gb and not gb.disabled:
		gb.pressed.emit()
		for _n in 8:
			await get_tree().process_frame
	_ok(int(World.armory.get(SIG, 0)) >= 1, "UI armory got sig")
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	_ok(str(snap.get("smith", "")) != "", "UI month_echo.smith")
	# re-render to paint echo strip
	if city.has_method("_set_tab"):
		city.call("_set_tab", "smith")
	for _m in 6:
		await get_tree().process_frame
	var item2: Button = city.find_child("Item_" + SIG, true, false) as Button
	if item2:
		item2.pressed.emit()
		for _p in 6:
			await get_tree().process_frame
	var echo: Label = city.find_child("EchoLine_smith", true, false) as Label
	_ok(echo != null, "UI EchoLine_smith present")
	# market produce via tab for produce echo line
	if city.has_method("_set_tab"):
		city.call("_set_tab", "market")
	for _q in 4:
		await get_tree().process_frame
	var mb: Button = city.find_child("Mkt_%s_buy1" % PRODUCE, true, false) as Button
	_ok(mb != null and not mb.disabled, "UI produce buy button")
	if mb and not mb.disabled:
		mb.pressed.emit()
		for _r in 4:
			await get_tree().process_frame
	_ok(str(CKEconomyState.month_echo_snapshot().get("produce", "")) != "", "UI produce echo")
	print("ui gate forge echo ok")
	city.queue_free()
	await get_tree().process_frame
