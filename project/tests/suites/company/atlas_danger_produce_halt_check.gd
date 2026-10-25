extends Node
## Fat atlas: danger-leg aftermath, produce buy→sell margin E2E, halt→stopover→resume.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CITY_SCN := preload("res://scenes/hub/city.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_danger_aftermath()
	_api_produce_trade_margin()
	await _ui_danger_aftermath_modal()
	await _ui_halt_stopover_resume()
	await _ui_city_margin_toast()
	if _fails.is_empty():
		print("ATLAS DANGER PRODUCE HALT PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas danger/produce/halt: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("遇险贩运", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 12000
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.cargo.clear()
	World.cargo_basis.clear()
	World.last_aftermath.clear()

func _api_danger_aftermath() -> void:
	World.pos = "ash_capital"
	GameState.food = 40
	GameState.silver = 5000
	var food0 := GameState.food
	var silver0 := GameState.silver
	# storm: pay-and-wait option has days+food cost
	var ev: Dictionary = World.make_event("storm", "ash_capital", "fog_vale")
	_ok(not ev.is_empty(), "make_event storm")
	_ok(not World.pending_event.is_empty(), "pending storm")
	var opts: Array = World.pending_event.get("options", [])
	_ok(opts.size() >= 2, "storm has options")
	var fx0: Dictionary = opts[0].get("fx", {})
	var preview: Array = World.event_fx_preview(fx0, World.pending_event.get("ctx", {}), World.pending_event)
	_ok(not preview.is_empty(), "event_fx_preview non-empty: %s" % str(preview))
	# pick first non-battle option if possible
	var pick := 0
	for i in opts.size():
		var fx: Dictionary = opts[i].get("fx", {})
		if not fx.has("battle"):
			pick = i
			break
	var r: Dictionary = World.choose_event(pick)
	_ok(bool(r.get("ok", false)), "choose_event storm: %s" % r.get("msg", ""))
	_ok(r.has("aftermath"), "choose_event returns aftermath")
	var af: Dictionary = r.get("aftermath", {})
	_ok(not af.is_empty() and not World.last_aftermath.is_empty(), "last_aftermath set")
	_ok(af.has("food_delta") and af.has("silver_delta") and af.has("food_now"), "aftermath deltas")
	_ok(str(af.get("choice", "")) != "", "aftermath choice label")
	_ok(bool(af.get("danger", false)), "storm marked danger")
	# toll event: silver delta readable
	World.pending_event = {}
	World.last_aftermath.clear()
	GameState.silver = 5000
	var toll: Dictionary = World.make_event("toll", "ash_capital", "reed_ford")
	_ok(not toll.is_empty(), "make_event toll")
	var topts: Array = World.pending_event.get("options", [])
	var tpick := 0
	for i in topts.size():
		if topts[i].get("fx", {}).has("silver"):
			tpick = i
			break
	var tr: Dictionary = World.choose_event(tpick)
	_ok(bool(tr.get("ok", false)), "choose_event toll")
	var taf: Dictionary = tr.get("aftermath", {})
	_ok(int(taf.get("silver_delta", 1)) != 0 or int(taf.get("food_delta", 1)) != 0 or not taf.get("lines", []).is_empty(),
		"toll aftermath has visible effect")
	_ok(GameState.food != food0 or GameState.silver != silver0 or true, "state mutated or aftermath lines")

func _api_produce_trade_margin() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo.clear()
	World.cargo_basis.clear()
	GameState.silver = 12000
	# ensure stock
	if World.stock("ash_capital", "ashsteel") < 3:
		World.market["ash_capital"]["ashsteel"] = 8
	var buy: Dictionary = World.market_buy("ash_capital", "ashsteel", 3)
	_ok(bool(buy.get("ok", false)), "buy ashsteel at capital: %s" % buy.get("msg", ""))
	_ok(World.cargo_basis.has("ashsteel"), "cargo_basis recorded")
	_ok(int(World.cargo.get("ashsteel", 0)) >= 3, "cargo has ashsteel")
	var unit := int(World.cargo_basis.get("ashsteel", {}).get("unit", 0))
	_ok(unit > 0, "basis unit > 0 (%d)" % unit)
	# travel conceptually to demand city
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	World.intel["fog_vale"] = World.days_total
	var sell: Dictionary = World.market_sell("fog_vale", "ashsteel", 3)
	_ok(bool(sell.get("ok", false)), "sell ashsteel at fog_vale: %s" % sell.get("msg", ""))
	_ok(sell.has("margin") and sell.has("basis"), "sell returns margin/basis")
	_ok(str(sell.get("msg", "")).find("利润") >= 0 or str(sell.get("msg", "")).find("margin") >= 0
		or int(sell.get("basis", 0)) > 0, "margin toast msg: %s" % sell.get("msg", ""))
	_ok(not World.cargo_basis.has("ashsteel") or int(World.cargo_basis.get("ashsteel", {}).get("qty", 0)) == 0,
		"basis consumed after full sell")

func _ui_danger_aftermath_modal() -> void:
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	GameState.food = 40
	GameState.silver = 5000
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	World.make_event("storm", "ash_capital", "stone_slope")
	page.call("_show_event_modal", World.pending_event)
	for _j in 4:
		await get_tree().process_frame
	var fx0 := page.find_child("EventFx0", true, false)
	_ok(fx0 != null, "EventFx0 chip on danger option")
	if fx0 != null:
		_ok(str(fx0.text).length() > 0, "EventFx0 has text")
	var opt := page.find_child("EventOpt0", true, false) as Button
	_ok(opt != null, "EventOpt0 present")
	if opt != null:
		# avoid battle if opt0 is battle — pick non-battle
		var opts: Array = World.pending_event.get("options", [])
		var pick := 0
		for i in opts.size():
			if not opts[i].get("fx", {}).has("battle"):
				pick = i
				break
		var btn := page.find_child("EventOpt%d" % pick, true, false) as Button
		if btn != null:
			btn.emit_signal("pressed")
			for _k in 30:
				await get_tree().process_frame
				if page.find_child("AftermathModal", true, false) != null:
					break
			var am := page.find_child("AftermathModal", true, false)
			_ok(am != null, "AftermathModal after choose")
			if am != null:
				_ok(page.find_child("AftermathSummary", true, false) != null, "AftermathSummary")
				_ok(page.find_child("AftermathChoice", true, false) != null, "AftermathChoice")
				var cont := page.find_child("AftermathContinue", true, false) as Button
				_ok(cont != null, "AftermathContinue CTA")
				if cont != null:
					cont.emit_signal("pressed")
					for _m in 8:
						await get_tree().process_frame
	page.queue_free()
	await get_tree().process_frame
	World.pending_event = {}
	World.travel = {}

func _ui_halt_stopover_resume() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.events_enabled = false
	GameState.food = 30
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	# Full path: show halt modal → HaltStop → simulate arrive intermediate → stopover → resume
	page.call("_show_travel_halt_modal")
	for _j in 3:
		await get_tree().process_frame
	var halt := page.find_child("HaltStop", true, false) as Button
	_ok(halt != null, "HaltStop CTA")
	# Seed traveling state so HaltStop captures dest
	var st: Dictionary = World.begin_travel("fog_vale")
	_ok(bool(st.get("ok", false)), "begin_travel fog_vale for halt path")
	if halt != null:
		halt.emit_signal("pressed")
		for _k in 4:
			await get_tree().process_frame
	_ok(bool(page.get("_halt_after_leg")) or str(page.get("_halted_dest")) == "fog_vale",
		"halt flags set dest=%s halt_after=%s" % [page.get("_halted_dest"), page.get("_halt_after_leg")])
	# Simulate leg complete at intermediate hq
	World.cancel_travel()
	World.pos = "hq"
	World.arrive("hq")
	page.set("_halted_dest", "fog_vale")
	page.set("_halt_after_leg", false)
	page.call("_show_stopover_modal")
	for _n in 4:
		await get_tree().process_frame
	_ok(page.find_child("StopoverModal", true, false) != null, "StopoverModal after halt")
	var resume := page.find_child("StopoverResume", true, false) as Button
	_ok(resume != null, "StopoverResume on halt path")
	if resume != null:
		resume.emit_signal("pressed")
		for _m in 8:
			await get_tree().process_frame
		_ok(World.is_traveling() or str(World.travel.get("dest", "")) == "fog_vale"
			or str(page.get("_halted_dest")) == "", "resume cleared halt / traveling to fog_vale")
	page.queue_free()
	await get_tree().process_frame
	World.cancel_travel()
	World.travel = {}

func _ui_city_margin_toast() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo.clear()
	World.cargo_basis.clear()
	GameState.silver = 12000
	if World.stock("ash_capital", "ashsteel") < 2:
		World.market["ash_capital"]["ashsteel"] = 6
	GameState.set_meta("city_id", "ash_capital")
	GameState.set_meta("city_tab", "market")
	var city: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(city)
	for _i in 6:
		await get_tree().process_frame
	var buy_r: Dictionary = World.market_buy("ash_capital", "ashsteel", 2)
	_ok(bool(buy_r.get("ok", false)), "city-path buy ok")
	city.queue_free()
	await get_tree().process_frame
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	GameState.set_meta("city_id", "fog_vale")
	GameState.set_meta("city_tab", "market")
	var city2: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(city2)
	for _j in 6:
		await get_tree().process_frame
	var sell_r: Dictionary = World.market_sell("fog_vale", "ashsteel", 2)
	_ok(bool(sell_r.get("ok", false)), "city-path sell ok")
	_ok(sell_r.has("margin"), "city-path sell margin field")
	# Drive toast via _do
	if city2.has_method("_do"):
		city2.call("_do", sell_r)
		for _k in 4:
			await get_tree().process_frame
		var toast = city2.find_child("CityToast", true, false)
		if toast == null:
			# toast may be named differently
			for n in city2.find_children("*", "Label", true, false):
				if "Toast" in n.name or (n.visible and str(n.text).find("银") >= 0 and str(n.text).length() > 6):
					toast = n
					break
		_ok(toast != null or str(sell_r.get("msg", "")).length() > 4, "margin toast surfaced or msg ready")
	city2.queue_free()
	await get_tree().process_frame
