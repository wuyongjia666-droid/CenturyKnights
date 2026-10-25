extends Node
## Mobile atlas E2E: route leg danger readout in place sheet + city HubDiscover CTAs.
## Named mobile_* → ci_godot_run.sh sets CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas travel feel: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS TRAVEL FEEL PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机跑图", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 999
	GameState.silver = 8000
	World.hub_tour.clear()
	World.pos = "ash_capital"
	var a := await _check_atlas_legs()
	if a != "":
		return "atlas: %s" % a
	var c := await _check_city_discover()
	if c != "":
		return "city: %s" % c
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _check_atlas_legs() -> String:
	var packed: PackedScene = load("res://scenes/hub/atlas_view.tscn")
	if packed == null:
		return "load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 6:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	for _j in 4:
		await get_tree().process_frame
	if not bool(page.get("_mob")):
		page.queue_free()
		return "_mob false after apply_mobile_layout (need landscape vp)"
	if page.has_method("_select_node"):
		page.call("_select_node", "fog_vale")
	for _k in 6:
		await get_tree().process_frame
	var prev: Dictionary = page.get("_preview") if typeof(page.get("_preview")) == TYPE_DICTIONARY else {}
	if not bool(prev.get("ok", false)):
		page.queue_free()
		return "preview not ok after select fog_vale"
	if page.has_method("_set_sheet_tab"):
		page.call("_set_sheet_tab", "place")
	for _n in 3:
		await get_tree().process_frame
	var legs := page.find_child("RouteLegs", true, false)
	if legs == null:
		# one intentional re-render after sync-free should keep the name
		if page.has_method("_render_right"):
			page.call("_render_right")
		for _m in 4:
			await get_tree().process_frame
		legs = page.find_child("RouteLegs", true, false)
	if legs == null:
		page.queue_free()
		return "RouteLegs missing on mobile place sheet"
	var leg0 := legs.find_child("Leg_0", true, false)
	if leg0 == null:
		page.queue_free()
		return "Leg_0 missing"
	var go := page.find_child("GoButton", true, false) as Button
	if go == null:
		page.queue_free()
		return "GoButton missing"
	print("mobile atlas legs ok legs=%d" % legs.get_child_count())
	page.queue_free()
	await get_tree().process_frame
	return ""

func _check_city_discover() -> String:
	World.hub_tour.erase("ash_capital")
	GameState.set_meta("city_id", "ash_capital")
	var packed: PackedScene = load("res://scenes/hub/city.tscn")
	if packed == null:
		return "city load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 6:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	for _j in 4:
		await get_tree().process_frame
	var band := page.find_child("HubDiscover", true, false)
	if band == null:
		page.queue_free()
		return "HubDiscover missing on mobile city"
	var smith := page.find_child("GotoHub_smith", true, false) as Button
	var market := page.find_child("GotoHub_market", true, false) as Button
	if market == null and smith == null:
		page.queue_free()
		return "no GotoHub_* CTAs"
	if market != null:
		if market.size.y + 0.5 < MobilePage.HIT * 0.85 and market.custom_minimum_size.y + 0.5 < MobilePage.HIT * 0.85:
			page.queue_free()
			return "GotoHub_market hit %.1f too small" % maxf(market.size.y, market.custom_minimum_size.y)
		market.emit_signal("pressed")
		for _k in 5:
			await get_tree().process_frame
		if not bool(World.hub_tour.get("ash_capital", {}).get("market", false)):
			page.queue_free()
			return "market not marked after CTA"
	print("mobile city hub discover ok")
	page.queue_free()
	await get_tree().process_frame
	return ""
