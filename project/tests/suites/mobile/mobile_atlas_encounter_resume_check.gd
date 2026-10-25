extends Node
## Mobile E2E: encounter resolve → BattleAftermathModal → resume + deliver TurnInNow.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas encounter/resume: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS ENCOUNTER RESUME PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机遭遇续行", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 10000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.last_battle_aftermath.clear()
	var a := await _check_win_aftermath_resume()
	if a != "":
		return "win: %s" % a
	var b := await _check_retreat_aftermath()
	if b != "":
		return "retreat: %s" % b
	var c := await _check_deliver_turnin_now()
	if c != "":
		return "deliver: %s" % c
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

func _check_win_aftermath_resume() -> String:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.encounter = {}
	World.last_battle_aftermath.clear()
	var st: Dictionary = World.begin_travel("fog_vale")
	if not bool(st.get("ok", false)):
		return "begin_travel fail: %s" % st.get("msg", "")
	World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 1})
	var r: Dictionary = World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", {})
	if af.is_empty():
		return "no aftermath"
	if not bool(af.get("resume_travel", false)):
		return "resume_travel false on win"
	var page := await _mount_atlas()
	if not bool(page.get("_mob")):
		page.queue_free()
		return "_mob false"
	page.call("_show_battle_aftermath_modal", af)
	for _n in 10:
		await get_tree().process_frame
		if page.find_child("BattleAftermathModal", true, false) != null:
			break
	if page.find_child("BattleAftermathModal", true, false) == null:
		page.queue_free()
		return "BattleAftermathModal missing"
	var strip := page.find_child("AftermathCrestStrip", true, false)
	if strip == null or strip.find_child("CastleArms", true, false) == null:
		page.queue_free()
		return "AftermathCrestStrip/团徽 missing on win"
	if strip.find_child("FoeArms", true, false) == null:
		page.queue_free()
		return "FoeArms/敌徽 missing on win"
	if page.find_child("BattleAftermathSummary", true, false) == null:
		page.queue_free()
		return "BattleAftermathSummary missing"
	var cont := page.find_child("BattleAftermathContinue", true, false) as Button
	if cont == null:
		page.queue_free()
		return "BattleAftermathContinue missing"
	cont.emit_signal("pressed")
	for _m in 8:
		await get_tree().process_frame
	print("mobile win aftermath ok resume=%s" % af.get("resume_travel"))
	page.queue_free()
	await get_tree().process_frame
	World.cancel_travel()
	World.travel = {}
	return ""

func _check_retreat_aftermath() -> String:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo["ashsteel"] = 2
	World.last_battle_aftermath.clear()
	World.begin_travel("fog_vale")
	World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 1})
	var page := await _mount_atlas()
	page.call("_show_encounter_modal", World.encounter)
	for _n in 5:
		await get_tree().process_frame
	var retreat := page.find_child("EncounterRetreat", true, false) as Button
	if retreat == null:
		page.queue_free()
		return "EncounterRetreat missing"
	retreat.emit_signal("pressed")
	for _k in 50:
		await get_tree().process_frame
		if page.find_child("BattleAftermathModal", true, false) != null:
			break
	if page.find_child("BattleAftermathModal", true, false) == null:
		page.queue_free()
		return "BattleAftermathModal after retreat missing"
	if page.find_child("AftermathCrestStrip", true, false) == null:
		page.queue_free()
		return "AftermathCrestStrip missing on retreat"
	var cont := page.find_child("BattleAftermathContinue", true, false) as Button
	if cont == null:
		page.queue_free()
		return "Continue missing on lose"
	cont.emit_signal("pressed")
	for _m in 6:
		await get_tree().process_frame
	print("mobile retreat aftermath ok")
	page.queue_free()
	await get_tree().process_frame
	World.encounter = {}
	World.travel = {}
	return ""

func _check_deliver_turnin_now() -> String:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.cargo.clear()
	var q: Dictionary = World.seed_deliver_offer("ash_capital", "fog_vale")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q.id))
	if not bool(acc.get("ok", false)):
		return "accept fail: %s" % acc.get("msg", "")
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	if World.ready_turn_ins_here().is_empty():
		return "no ready turn-ins"
	var page := await _mount_atlas()
	page.call("_show_turnin_modal", World.ready_turn_ins_here().size())
	for _n in 6:
		await get_tree().process_frame
	if page.find_child("TurnInReadyModal", true, false) == null:
		page.queue_free()
		return "TurnInReadyModal missing"
	if page.find_child("TurnInNow", true, false) == null:
		page.queue_free()
		return "TurnInNow missing"
	var silver0 := GameState.silver
	var now := page.find_child("TurnInNow", true, false) as Button
	now.emit_signal("pressed")
	for _k in 12:
		await get_tree().process_frame
	if not World.quest_by_id(str(q.id)).is_empty():
		page.queue_free()
		return "quest still active after TurnInNow"
	if GameState.silver <= silver0:
		page.queue_free()
		return "silver not paid"
	print("mobile deliver TurnInNow ok")
	page.queue_free()
	await get_tree().process_frame
	return ""
