extends Node
## Shared desk/phone loop: winter seal → detour march → arrive sheet → city market.

const ATLAS := "res://scenes/hub/atlas_view.tscn"
const CITY := "res://scenes/hub/city.tscn"
const ORIGIN := "sy_capital"
const DEST := "sy_ridge"
const SEAL_A := "sy_spire"
const SEAL_B := "sy_ridge"

var fails: Array = []

func run_all() -> void:
	_api_rules()
	_api_detour_march()
	_api_wait_and_force()
	await _ui_loop()

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("封路", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.food = 120
	GameState.silver = 800
	GameState.morale = 80
	Calendar.year = 1
	Calendar.month = 1
	World.day = 1
	World.days_total = 0
	World.pos = ORIGIN
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.road_flags.clear()
	World.last_supply_halt = {}
	World.last_march_muster = {}

func _api_rules() -> void:
	_setup()
	_ok(CKRoadSeal.seal_active(), "winter day 1 seals the passes")
	_ok(CKRoadSeal.is_sealed(SEAL_A, SEAL_B), "sy_spire—sy_ridge is sealed")
	_ok(CKRoadSeal.sealed_count() >= 1, "at least one sealed road")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	_ok(bool(cmp.get("sealed", false)), "direct route to 狼脊村 is sealed")
	_ok(str(cmp.get("direct_text", "")).find("✕") >= 0, "direct text marks the seal")
	var detour: Dictionary = cmp.get("detour", {})
	_ok(bool(detour.get("ok", false)), "a detour exists")
	_ok(int(detour.get("extra_days", 0)) >= 1, "detour costs extra days (%s)" % detour.get("extra_days", 0))
	_ok(int(detour.get("days", 0)) > int(cmp.get("direct_days", 0)), "detour is longer than the direct road")
	var path: Array = detour.get("path", [])
	var stepped := false
	for i in range(maxi(0, path.size() - 1)):
		if CKRoadSeal.is_sealed(str(path[i]), str(path[i + 1])):
			stepped = true
	_ok(not stepped, "detour path avoids sealed edges")
	_ok(CKRoadSeal.days_until_clear() == 8, "wait is 8 days from day 1")
	Calendar.month = 6
	_ok(not CKRoadSeal.seal_active(), "summer does not seal")
	_ok(not CKRoadSeal.is_sealed(SEAL_A, SEAL_B), "summer edge is open")
	_ok(CKRoadSeal.sealed_count() == 0, "summer sealed count is 0")
	Calendar.month = 1
	World.day = 9
	_ok(not CKRoadSeal.seal_active(), "day 9 of winter is open")
	World.day = 1
	var plain: Dictionary = CKRoadSeal.compare("sy_stair")
	_ok(bool(plain.get("ok", false)) and not bool(plain.get("sealed", false)), "open neighbor is not a seal sheet")

func _api_detour_march() -> void:
	_setup()
	var before_food := GameState.food
	var before_day := World.days_total
	var marched: Dictionary = CKRoadSeal.march_detour(DEST)
	_ok(bool(marched.get("ok", false)), "march_detour reached dest: %s" % marched.get("msg", ""))
	_ok(World.pos == DEST, "party stands at sy_ridge")
	_ok(int(marched.get("days", 0)) == int(marched.get("plan_days", -1)), "days match the detour plan")
	_ok(int(marched.get("days", 0)) >= 4, "detour spent at least 4 days")
	_ok(World.days_total - before_day == int(marched.get("days", -1)), "days_total moved with the march")
	_ok(GameState.food < before_food, "rations fell on the detour")
	_ok(GameState.food == int(marched.get("food_after", -1)), "reported food matches the purse")
	_ok(not World.is_traveling(), "detour march is finished")

func _api_wait_and_force() -> void:
	_setup()
	var morale0 := GameState.morale
	var forced: Dictionary = CKRoadSeal.commit_force(DEST)
	_ok(bool(forced.get("ok", false)), "force opens the seal")
	_ok(not CKRoadSeal.is_sealed(SEAL_A, SEAL_B), "forced edge is open")
	_ok(GameState.morale == morale0 - CKRoadSeal.FORCE_MORALE, "force costs morale")
	_ok(World.days_total == 1, "force spends one day")
	_ok(GameState.food < 120, "force spends a day's food")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(World.to_save()))
	World.road_flags.clear()
	_ok(CKRoadSeal.is_sealed(SEAL_A, SEAL_B), "clearing flags reseals")
	World.from_save(saved)
	World.day = 2
	Calendar.month = 1
	Calendar.year = 1
	_ok(not CKRoadSeal.is_sealed(SEAL_A, SEAL_B), "open flag survives from_save")
	_setup()
	var waited: Dictionary = CKRoadSeal.commit_wait()
	_ok(bool(waited.get("ok", false)) and int(waited.get("days", 0)) == 8, "wait spends 8 days")
	_ok(World.day == 9, "wait lands on day 9")
	_ok(not CKRoadSeal.seal_active(), "seal lifts after the wait")
	_ok(GameState.food < int(waited.get("food_before", 0)), "waiting eats rations")
	var gone: Dictionary = CKRoadSeal.compare(DEST)
	_ok(not bool(gone.get("sealed", false)), "direct road is open after the thaw")

func _ui_loop() -> void:
	_setup()
	var mobile := DeviceProfile.is_mobile()
	var page := load(ATLAS).instantiate() as Control
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 720) if mobile else Vector2(1280, 720)
	get_tree().root.add_child(page)
	for _i in 8:
		await get_tree().process_frame
	if mobile and page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
	if not page.has_method("_select_node"):
		_ok(false, "atlas script did not load")
		page.queue_free()
		return
	page.call("_show_view", "shuoying")
	page.call("_select_node", DEST)
	for _j in 6:
		await get_tree().process_frame
	if mobile:
		_ok(page.get("_mob") == true, "atlas took the phone layout")
	var legend := page.find_child("SealLegend", true, false) as Label
	_ok(legend != null and legend.visible and legend.text.find("冬封") >= 0, "seal legend on the shuoying plate")
	var marks := page.find_child("SealMarks", true, false)
	_ok(marks != null, "seal marks draw on the plate")
	var sheet := page.find_child("BlockedRoadSheet", true, false)
	_ok(sheet != null, "BlockedRoadSheet is up")
	var direct := page.find_child("SealDirect", true, false) as Label
	_ok(direct != null and direct.text.find("✕") >= 0, "sheet shows the sealed leg")
	var detour_path := page.find_child("SealDetourPath", true, false) as Label
	_ok(detour_path != null and detour_path.text.find("✕") < 0 and detour_path.text.find("绕") >= 0, "sheet shows a clear detour")
	var food := page.find_child("SealFood", true, false) as Label
	_ok(food != null and food.text.find("120") >= 0, "sheet shows rations on hand")
	var go_name := "GoButton" if mobile else "HudGo"
	var go := page.find_child(go_name, true, false) as Button
	_ok(go != null and go.disabled, "%s disabled while the road is sealed" % go_name)
	var detour_btn := page.find_child("SealDetour", true, false) as Button
	_ok(detour_btn != null and not detour_btn.disabled, "SealDetour can be pressed")
	var day0 := World.days_total
	var food0 := GameState.food
	if detour_btn != null:
		detour_btn.pressed.emit()
	var err := await _pump(page)
	_ok(err == "", "march pump: %s" % err)
	_ok(World.pos == DEST, "UI march arrived at sy_ridge (at %s)" % World.pos)
	_ok(World.days_total - day0 >= 4, "UI march spent %d days" % (World.days_total - day0))
	_ok(GameState.food < food0, "UI march consumed food")
	var arrive := page.find_child("ArriveSheet", true, false)
	_ok(arrive != null, "ArriveSheet after the march")
	var days_lbl := page.find_child("ArriveDays", true, false) as Label
	_ok(days_lbl != null and days_lbl.text.find(str(World.days_total - day0)) >= 0, "arrival names the days spent")
	var title := page.find_child("ArriveTitle", true, false) as Label
	_ok(title != null and title.text.find(str(World.node(DEST).get("name", ""))) >= 0, "arrival names 狼脊村")
	_ok(page.find_child("ArriveEnter", true, false) != null, "ArriveEnter")
	_ok(page.find_child("ArriveMarket", true, false) != null, "ArriveMarket")
	_ok(page.find_child("ArriveSmith", true, false) != null, "ArriveSmith")
	_ok(page.find_child("ArriveTavern", true, false) != null, "ArriveTavern")
	_ok(page.find_child("ArriveBoard", true, false) != null, "ArriveBoard")
	var market := page.find_child("ArriveMarket", true, false) as Button
	CKNav._busy = true
	if market != null:
		market.pressed.emit()
	for _k in 4:
		await get_tree().process_frame
	_ok(str(GameState.get_meta("city_tab", "")) == "market", "ArriveMarket arms the market tab")
	_ok(str(GameState.get_meta("city_id", "")) == DEST, "enter targets the arrived city")
	CKNav._busy = false
	var city := load(CITY).instantiate() as Control
	city.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city.position = Vector2.ZERO
	city.size = page.size
	get_tree().root.add_child(city)
	for _n in 8:
		await get_tree().process_frame
	_ok(str(city.get("tab")) == "market", "city opened on the market panel")
	_ok(_find_named(city, "Mkt_") != null, "market rows are on the panel")
	city.queue_free()
	if is_instance_valid(page):
		page.queue_free()
	await get_tree().process_frame

func _pump(page: Control) -> String:
	var started := Time.get_ticks_msec()
	var saw_strip := false
	while Time.get_ticks_msec() - started < 30000:
		if page.find_child("ArriveSheet", true, false) != null and World.pos == DEST and not World.is_traveling():
			return "" if saw_strip else "march strip never showed"
		var strip := page.find_child("MarchPathStrip", true, false) as Label
		if strip != null and strip.visible and strip.text != "":
			saw_strip = true
		var opt := page.find_child("EventOpt0", true, false) as Button
		if opt != null and not opt.has_meta("ck_seal_clicked"):
			opt.set_meta("ck_seal_clicked", true)
			opt.pressed.emit()
		var cont := page.find_child("AftermathContinue", true, false) as Button
		if cont != null and not cont.has_meta("ck_seal_clicked"):
			cont.set_meta("ck_seal_clicked", true)
			cont.pressed.emit()
		await get_tree().process_frame
	return "timed out at %s traveling=%s" % [World.pos, World.is_traveling()]

func _find_named(node: Node, prefix: String) -> Node:
	if str(node.name).begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_named(child, prefix)
		if found != null:
			return found
	return null
