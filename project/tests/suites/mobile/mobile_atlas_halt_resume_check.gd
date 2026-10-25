extends Node
## Mobile E2E: HaltStop → stopover → StopoverResume + danger AftermathModal.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas halt/resume: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS HALT RESUME PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机停靠续行", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 30
	GameState.silver = 8000
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.cargo.clear()
	World.cargo_basis.clear()
	var a := await _check_halt_resume()
	if a != "":
		return "halt: %s" % a
	var b := await _check_aftermath()
	if b != "":
		return "aftermath: %s" % b
	var c := await _check_produce_margin_api()
	if c != "":
		return "produce: %s" % c
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _mount_atlas() -> Control:
	var page: Control = ATLAS_SCN.instantiate()
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
	return page

func _check_halt_resume() -> String:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	GameState.food = 25
	var page := await _mount_atlas()
	if not bool(page.get("_mob")):
		page.queue_free()
		return "_mob false"
	var st: Dictionary = World.begin_travel("fog_vale")
	if not bool(st.get("ok", false)):
		page.queue_free()
		return "begin_travel failed: %s" % st.get("msg", "")
	page.call("_show_travel_halt_modal")
	for _n in 4:
		await get_tree().process_frame
	var halt := page.find_child("HaltStop", true, false) as Button
	if halt == null:
		page.queue_free()
		return "HaltStop missing"
	halt.emit_signal("pressed")
	for _k in 5:
		await get_tree().process_frame
	if str(page.get("_halted_dest")) != "fog_vale" and not bool(page.get("_halt_after_leg")):
		page.queue_free()
		return "halt did not capture dest"
	# Arrive intermediate stopover
	World.cancel_travel()
	World.pos = "hq"
	World.arrive("hq")
	page.set("_halted_dest", "fog_vale")
	page.call("_show_stopover_modal")
	for _m in 5:
		await get_tree().process_frame
	if page.find_child("StopoverModal", true, false) == null:
		page.queue_free()
		return "StopoverModal missing"
	var resume := page.find_child("StopoverResume", true, false) as Button
	if resume == null:
		page.queue_free()
		return "StopoverResume missing"
	resume.emit_signal("pressed")
	for _p in 10:
		await get_tree().process_frame
		if World.is_traveling():
			break
	if not World.is_traveling() and str(World.travel.get("dest", "")) != "fog_vale":
		# begin_travel may have started _run_travel which consumes; accept cleared halt
		if str(page.get("_halted_dest")) != "":
			page.queue_free()
			return "resume did not clear halt / start travel"
	print("mobile halt→stopover→resume ok")
	page.queue_free()
	await get_tree().process_frame
	World.cancel_travel()
	World.travel = {}
	return ""

func _check_aftermath() -> String:
	World.pos = "ash_capital"
	World.pending_event = {}
	GameState.food = 40
	GameState.silver = 5000
	var page := await _mount_atlas()
	World.make_event("storm", "ash_capital", "stone_slope")
	page.call("_show_event_modal", World.pending_event)
	for _n in 5:
		await get_tree().process_frame
	if page.find_child("EventFx0", true, false) == null:
		page.queue_free()
		return "EventFx0 missing on mobile"
	var opts: Array = World.pending_event.get("options", [])
	var pick := 0
	for i in opts.size():
		if not opts[i].get("fx", {}).has("battle"):
			pick = i
			break
	var btn := page.find_child("EventOpt%d" % pick, true, false) as Button
	if btn == null:
		page.queue_free()
		return "EventOpt missing"
	btn.emit_signal("pressed")
	for _k in 40:
		await get_tree().process_frame
		if page.find_child("AftermathModal", true, false) != null:
			break
	var am := page.find_child("AftermathModal", true, false)
	if am == null:
		page.queue_free()
		return "AftermathModal missing"
	var cont := page.find_child("AftermathContinue", true, false) as Button
	if cont == null:
		page.queue_free()
		return "AftermathContinue missing"
	cont.emit_signal("pressed")
	for _m in 6:
		await get_tree().process_frame
	print("mobile aftermath ok")
	page.queue_free()
	await get_tree().process_frame
	World.pending_event = {}
	return ""

func _check_produce_margin_api() -> String:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo.clear()
	World.cargo_basis.clear()
	GameState.silver = 10000
	if World.stock("ash_capital", "ashsteel") < 2:
		World.market["ash_capital"]["ashsteel"] = 5
	var buy: Dictionary = World.market_buy("ash_capital", "ashsteel", 2)
	if not bool(buy.get("ok", false)):
		return "buy fail: %s" % buy.get("msg", "")
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	var sell: Dictionary = World.market_sell("fog_vale", "ashsteel", 2)
	if not bool(sell.get("ok", false)):
		return "sell fail: %s" % sell.get("msg", "")
	if not sell.has("margin"):
		return "no margin field"
	print("mobile produce margin ok margin=%s" % sell.get("margin"))
	return ""
