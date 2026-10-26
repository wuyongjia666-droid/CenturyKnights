extends Node
## Real scene-change loop: city gate out → march → ration warning → halt →
## re-enter → leave → resume readout → arrive → enter the destination.

const ATLAS := "res://scenes/hub/atlas_view.tscn"
const CITY := "res://scenes/hub/city.tscn"
const HOME := "ash_capital"
const HALT_AT := "tide_bridge"
const DEST := "lb_west"

var _phone := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_phone = bool(get_meta("phone", false))
	call_deferred("_run")


func _run() -> void:
	var err := await _loop()
	if err != "":
		print("FAIL gate march ration: ", err)
		get_tree().quit(1)
		return
	if _phone:
		print("MOBILE GATE MARCH RATION LOOP PASS")
	else:
		print("GATE MARCH RATION LOOP PASS")
	get_tree().quit(0)


func _loop() -> String:
	var err := await _boot()
	if err == "":
		err = await _phase_leave_home()
	if err == "":
		err = await _phase_march_halt()
	if err == "":
		err = await _phase_resume_arrive()
	return err


func _phase_leave_home() -> String:
	if not CKNav.replace(ATLAS):
		return "CKNav.replace atlas failed"
	var atlas := await _wait_scene(ATLAS, 8000)
	if atlas == null:
		return "atlas scene missing"
	var entered := await _through_gate(atlas, HOME)
	if entered != "":
		return entered
	var back := await _leave_gate()
	if back != "":
		return back
	atlas = await _wait_scene(ATLAS, 8000)
	if atlas == null:
		return "atlas did not return after leaving the gate"
	var strip := await _wait_node(atlas, "CityGateStrip", 5000)
	if strip == null:
		return "CityGateStrip missing after leaving %s" % HOME
	if str(World.city_gate.get("dir", "")) != "out":
		return "city_gate dir=%s" % str(World.city_gate.get("dir", ""))
	if str(strip.text).find(str(World.node(HOME).get("name", ""))) < 0:
		return "gate strip text=%s" % str(strip.text)
	if str(strip.text).find(Locale.t("atlas_gate_warn")) < 0:
		return "gate strip has no ration warning: %s" % str(strip.text)
	return ""


func _phase_march_halt() -> String:
	var atlas := get_tree().current_scene
	if atlas == null:
		return "atlas gone before march"
	if not await _press(atlas, "Gate_%s_%s" % [HALT_AT, DEST], 4000):
		return "border gate Gate_%s_%s missing" % [HALT_AT, DEST]
	for _i in 8:
		await get_tree().process_frame
	var warn := await _wait_node(atlas, "RouteWarn", 4000)
	if warn == null:
		return "RouteWarn missing food=%d preview=%s" % [GameState.food, str(World.travel_preview(DEST))]
	if not await _press_go(atlas):
		return "march button disabled"
	var halt := await _wait_button(atlas, "CampHalt", 20000)
	if halt == null:
		if atlas.find_child("SupplyHaltModal", true, false) != null:
			return "supply halt opened before the ration warning food=%d" % GameState.food
		return "CampHalt missing pos=%s travel=%s" % [World.pos, str(World.travel)]
	halt.emit_signal("pressed")
	for _j in 12:
		await get_tree().process_frame
	if World.pos != HALT_AT or World.is_traveling():
		return "halt pos=%s traveling=%s" % [World.pos, World.is_traveling()]
	if str(World.march_hold.get("dest", "")) != DEST:
		return "march_hold dest=%s" % str(World.march_hold.get("dest", ""))
	var readout := await _wait_node(atlas, "ResumeMarchReadout", 4000)
	if readout == null or str(readout.text).find(str(World.node(DEST).get("name", ""))) < 0:
		return "ResumeMarchReadout %s" % ("" if readout == null else str(readout.text))
	if atlas.find_child("StopoverModal", true, false) == null:
		return "StopoverModal missing after halt"
	return await _buy_and_reenter(atlas)


func _buy_and_reenter(atlas: Node) -> String:
	var buy := atlas.find_child("StopoverBuy", true, false) as Button
	if buy == null or buy.disabled:
		return "StopoverBuy unavailable"
	var food0 := GameState.food
	buy.emit_signal("pressed")
	for _k in 8:
		await get_tree().process_frame
	if GameState.food <= food0:
		return "resupply did not raise food %d" % GameState.food
	if not await _press(atlas, "StopoverDismiss", 3000):
		return "StopoverDismiss missing"
	for _d in 4:
		await get_tree().process_frame
	if str(World.march_hold.get("dest", "")) != DEST:
		return "hold cleared by stopover dismiss"
	var reenter := await _through_gate(atlas, HALT_AT)
	if reenter != "":
		return "re-enter: %s" % reenter
	if str(World.march_hold.get("dest", "")) != DEST:
		return "hold dropped inside the city"
	return ""


func _phase_resume_arrive() -> String:
	var left := await _leave_gate()
	if left != "":
		return left
	var atlas := await _wait_scene(ATLAS, 8000)
	if atlas == null:
		return "atlas missing after second exit"
	if str(World.march_hold.get("dest", "")) != DEST:
		return "hold dropped across the gate handoff"
	var resume_line := await _wait_node(atlas, "ResumeMarchReadout", 5000)
	if resume_line == null:
		return "resume readout missing after leaving the halt city"
	if not await _press(atlas, "ResumeMarch", 4000):
		return "ResumeMarch button missing"
	var chip := await _wait_node(atlas, "ResumeMarchChip", 5000)
	if chip == null or str(chip.text).find(str(World.node(DEST).get("name", ""))) < 0:
		return "ResumeMarchChip %s" % ("" if chip == null else str(chip.text))
	var arrive := await _finish_march(atlas, 60000)
	if arrive != "":
		return arrive
	if World.pos != DEST or World.is_traveling():
		return "did not arrive dest pos=%s traveling=%s" % [World.pos, World.is_traveling()]
	var final_enter := await _through_gate(atlas, DEST)
	if final_enter != "":
		return "arrive enter: %s" % final_enter
	return ""


func _boot() -> String:
	if _phone:
		if not DeviceProfile.is_mobile():
			return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
		DisplayServer.window_set_size(Vector2i(2400, 1080))
		for _i in 4:
			await get_tree().process_frame
	GameState.new_game("城门行军", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 8000
	GameState.morale = 80
	World.pos = HOME
	World.arrive(HOME)
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.march_hold = {}
	World.march_resume = {}
	World.city_gate = {}
	var held := World.hold_march(DEST)
	if str(held.get("dest", "")) != DEST:
		return "hold_march failed %s" % str(held)
	var snap := World.to_save()
	World.march_hold = {}
	World.from_save(snap)
	if str(World.march_hold.get("dest", "")) != DEST:
		return "march_hold dropped on save roundtrip"
	World.march_hold = {}
	World.march_resume = {}
	World.city_gate = {}
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = HOME
	var pv: Dictionary = World.travel_preview(DEST)
	if not bool(pv.get("ok", false)) or int(pv.get("days", 0)) < 2:
		return "route preview %s" % str(pv)
	var per := World.food_per_day()
	var need := int(pv.get("food", 0))
	GameState.food = maxi(per + 1, need - per)
	if GameState.food >= need or GameState.food <= per:
		return "ration setup per=%d need=%d food=%d" % [per, need, GameState.food]
	return ""


func _through_gate(atlas: Node, city_id: String) -> String:
	if World.pos != city_id:
		return "expected to stand at %s but pos=%s" % [city_id, World.pos]
	if not await _press(atlas, "EnterButton", 6000):
		return "EnterButton missing at %s" % city_id
	var city := await _wait_scene(CITY, 8000)
	if city == null:
		return "city scene did not open from %s" % city_id
	var banner := await _wait_node(city, "CityGateBanner", 4000)
	if banner == null:
		return "CityGateBanner missing"
	if str(World.city_gate.get("dir", "")) != "in" or str(World.city_gate.get("city", "")) != city_id:
		return "gate handoff %s" % str(World.city_gate)
	var cname := str(World.node(city_id).get("name", ""))
	if str(banner.text).find(cname) < 0:
		return "banner %s lacks %s" % [str(banner.text), cname]
	return ""


func _leave_gate() -> String:
	var city := get_tree().current_scene
	if city == null or city.scene_file_path != CITY:
		return "not on the city scene"
	if not await _press(city, "BackToAtlas", 4000):
		return "BackToAtlas missing"
	return ""


func _finish_march(atlas: Node, budget_ms: int) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < budget_ms:
		var page := get_tree().current_scene
		if page == null or page.scene_file_path != ATLAS:
			await get_tree().process_frame
			continue
		if World.pos == DEST and not World.is_traveling() and page.find_child("EventModal", true, false) == null and page.find_child("AftermathModal", true, false) == null:
			return ""
		if page.find_child("CampHalt", true, false) != null:
			return "second camp still short food=%d" % GameState.food
		if page.find_child("SupplyHaltModal", true, false) != null:
			return "supply halt during resume food=%d" % GameState.food
		if not await _press(page, "AftermathContinue", 1) and not await _press(page, "BattleAftermathContinue", 1):
			await _press(page, "EventOpt0", 1)
		await get_tree().process_frame
	return "march timeout pos=%s traveling=%s food=%d" % [World.pos, World.is_traveling(), GameState.food]


func _press_go(page: Node) -> bool:
	for node_name in ["GoButton", "HudGo"]:
		if await _press(page, node_name, 1500):
			return true
	return false


func _press(page: Node, node_name: String, budget_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < budget_ms:
		if not is_instance_valid(page):
			return false
		var btn := _enabled_button(page, node_name)
		if btn != null:
			btn.emit_signal("pressed")
			return true
		await get_tree().process_frame
	return false


func _enabled_button(page: Node, node_name: String) -> Button:
	var found: Array[Button] = []
	_collect_buttons(page, node_name, found)
	for btn in found:
		if not btn.disabled:
			return btn
	return null


func _collect_buttons(n: Node, node_name: String, out: Array[Button]) -> void:
	if n.name == node_name and n is Button:
		out.append(n as Button)
	for c in n.get_children():
		_collect_buttons(c, node_name, out)


func _wait_scene(path: String, budget_ms: int) -> Node:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < budget_ms:
		var sc := get_tree().current_scene
		if sc != null and sc.scene_file_path == path:
			for _i in 6:
				await get_tree().process_frame
			return sc
		await get_tree().process_frame
	return null


func _wait_node(page: Node, node_name: String, budget_ms: int) -> Node:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < budget_ms:
		if not is_instance_valid(page):
			return null
		var n := page.find_child(node_name, true, false)
		if n != null:
			return n
		await get_tree().process_frame
	return null


func _wait_button(page: Node, node_name: String, budget_ms: int) -> Button:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < budget_ms:
		if not is_instance_valid(page):
			return null
		var btn := _enabled_button(page, node_name)
		if btn != null:
			return btn
		await get_tree().process_frame
	return null
