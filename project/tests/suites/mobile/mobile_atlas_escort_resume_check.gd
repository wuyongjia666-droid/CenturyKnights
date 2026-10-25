extends Node
## Mobile E2E: escort accept→ambush→AftermathModal resume→arrive→TurnInNow + rival AftermathModal.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas escort/resume: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS ESCORT RESUME PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机护送续行", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 50
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
	var a := await _check_escort_ambush_resume_turnin()
	if a != "":
		return "escort: %s" % a
	var b := await _check_rival_aftermath()
	if b != "":
		return "rival: %s" % b
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

func _check_escort_ambush_resume_turnin() -> String:
	var err := ""
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.encounter = {}
	World.last_battle_aftermath.clear()
	var q: Dictionary = World.seed_escort_offer("ash_capital", "fog_vale")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q.id))
	if not bool(acc.get("ok", false)):
		err = "accept fail: %s" % acc.get("msg", "")
	var st: Dictionary = {} if err != "" else World.begin_travel("fog_vale")
	if err == "" and not bool(st.get("ok", false)):
		err = "begin_travel fail: %s" % st.get("msg", "")
	var enc: Dictionary = {} if err != "" else World.trigger_escort_ambush(str(q.id))
	if err == "" and enc.is_empty():
		err = "ambush empty"
	var r: Dictionary = {} if err != "" else World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", {}) if err == "" else {}
	if err == "" and af.is_empty():
		err = "no aftermath"
	if err == "" and not bool(af.get("resume_travel", false)):
		err = "resume_travel false"
	if err == "" and str(World.quest_by_id(str(q.id)).get("state", "")) != "active":
		err = "escort wrongly readied mid-march"
	var page: Control = null
	if err == "":
		page = await _mount_atlas()
		if not bool(page.get("_mob")):
			err = "_mob false"
	if err == "" and page != null:
		page.call("_show_battle_aftermath_modal", af)
		for _n in 10:
			await get_tree().process_frame
			if page.find_child("BattleAftermathModal", true, false) != null:
				break
		if page.find_child("BattleAftermathModal", true, false) == null:
			err = "BattleAftermathModal missing"
		var cont := page.find_child("BattleAftermathContinue", true, false) as Button
		if err == "" and cont == null:
			err = "Continue missing"
		if err == "" and cont != null:
			cont.emit_signal("pressed")
			for _m in 8:
				await get_tree().process_frame
		page.queue_free()
		await get_tree().process_frame
		page = null
	if err == "":
		World.cancel_travel()
		World.travel = {}
		World.pos = "fog_vale"
		World.arrive("fog_vale")
		if str(World.quest_by_id(str(q.id)).get("state", "")) != "ready":
			err = "escort not ready at target"
	if err == "":
		page = await _mount_atlas()
		page.call("_show_turnin_modal", World.ready_turn_ins_here().size())
		for _n in 6:
			await get_tree().process_frame
		if page.find_child("TurnInNow", true, false) == null:
			err = "TurnInNow missing"
		var silver0 := GameState.silver
		var now := page.find_child("TurnInNow", true, false) as Button
		if err == "" and now != null:
			now.emit_signal("pressed")
			for _k in 12:
				await get_tree().process_frame
			if not World.quest_by_id(str(q.id)).is_empty():
				err = "quest still after TurnInNow"
			elif GameState.silver <= silver0:
				err = "silver not paid"
		if page != null:
			page.queue_free()
			await get_tree().process_frame
	if err == "":
		print("mobile escort ambush→resume→TurnInNow ok")
	elif page != null and is_instance_valid(page):
		page.queue_free()
	return err

func _check_rival_aftermath() -> String:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.encounter = {}
	World.last_battle_aftermath.clear()
	World.place_rival_here("ash_capital")
	var enc: Dictionary = World.rival_clash()
	if enc.is_empty():
		return "rival_clash empty"
	var r: Dictionary = World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", {})
	if str(af.get("kind", "")) != "rival":
		return "aftermath kind %s" % af.get("kind", "")
	var page := await _mount_atlas()
	page.call("_show_battle_aftermath_modal", af)
	for _n in 10:
		await get_tree().process_frame
		if page.find_child("BattleAftermathModal", true, false) != null:
			break
	var err := ""
	if page.find_child("BattleAftermathModal", true, false) == null:
		err = "rival BattleAftermathModal missing"
	else:
		var cont := page.find_child("BattleAftermathContinue", true, false) as Button
		if cont != null:
			cont.emit_signal("pressed")
			for _m in 6:
				await get_tree().process_frame
		print("mobile rival aftermath ok")
	page.queue_free()
	await get_tree().process_frame
	return err
