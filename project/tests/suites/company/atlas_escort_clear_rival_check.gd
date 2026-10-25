extends Node
## Fat atlas: escort ambush→resume→arrive→TurnInNow; clear edge fight→ready→TurnInNow; rival clash AftermathModal.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_escort_ambush_resume_turnin()
	_api_clear_fight_ready_turnin()
	_api_rival_clash_aftermath()
	await _ui_escort_aftermath_resume()
	await _ui_clear_engage_turnin()
	await _ui_rival_clash_modal()
	if _fails.is_empty():
		print("ATLAS ESCORT CLEAR RIVAL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas escort/clear/rival: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("护送清剿", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 50
	GameState.silver = 12000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()

func _api_escort_ambush_resume_turnin() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.encounter = {}
	World.last_battle_aftermath.clear()
	var q: Dictionary = World.seed_escort_offer("ash_capital", "fog_vale")
	_ok(str(q.get("kind", "")) == "escort", "seed escort kind")
	_ok(str(q.get("target", "")) == "fog_vale", "seed escort target")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q.id))
	_ok(bool(acc.get("ok", false)), "accept escort: %s" % acc.get("msg", ""))
	var st: Dictionary = World.begin_travel("fog_vale")
	_ok(bool(st.get("ok", false)), "begin escort march: %s" % st.get("msg", ""))
	_ok(World.is_traveling(), "traveling with escort")
	var enc: Dictionary = World.trigger_escort_ambush(str(q.id))
	_ok(not enc.is_empty() and not World.encounter.is_empty(), "escort ambush encounter")
	_ok(str(enc.get("quest", "")) == str(q.id), "ambush linked to escort quest")
	var r: Dictionary = World.on_battle_end(true)
	_ok(bool(r.get("ok", false)), "escort ambush win ok")
	var af: Dictionary = r.get("aftermath", {})
	_ok(not af.is_empty(), "escort aftermath set")
	_ok(bool(af.get("resume_travel", false)), "escort win resume_travel")
	var aq: Dictionary = World.quest_by_id(str(q.id))
	_ok(str(aq.get("state", "")) == "active", "escort stays active after mid-march win")
	_ok(bool(aq.get("battle_won", false)), "escort battle_won stamped")
	_ok(str(af.get("quest_kind", "")) == "escort", "aftermath quest_kind escort")
	# Finish march → ready at target
	World.cancel_travel()
	World.travel = {}
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	aq = World.quest_by_id(str(q.id))
	_ok(str(aq.get("state", "")) == "ready", "escort ready at target")
	var silver0 := GameState.silver
	var tr: Dictionary = World.turn_in(str(q.id))
	_ok(bool(tr.get("ok", false)), "escort turn_in: %s" % tr.get("msg", ""))
	_ok(GameState.silver > silver0, "escort turn_in silver")
	_ok(World.quest_by_id(str(q.id)).is_empty(), "escort removed after turn_in")

func _api_clear_fight_ready_turnin() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.encounter = {}
	World.last_battle_aftermath.clear()
	var q: Dictionary = World.seed_clear_offer("ash_capital", "ash_capital", "hq")
	_ok(str(q.get("kind", "")) == "clear", "seed clear kind")
	_ok(q.has("edge"), "seed clear has edge")
	var edge: Array = q.get("edge", [])
	_ok(edge.size() == 2 and "ash_capital" in edge and "hq" in edge, "clear edge ash↔hq")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q.id))
	_ok(bool(acc.get("ok", false)), "accept clear: %s" % acc.get("msg", ""))
	# Fight at issuer end without marching
	var enc: Dictionary = World.trigger_clear_fight(str(q.id))
	_ok(not enc.is_empty(), "clear fight encounter")
	_ok(str(enc.get("quest", "")) == str(q.id), "clear linked quest")
	var r: Dictionary = World.on_battle_end(true)
	_ok(bool(r.get("ok", false)), "clear win ok")
	var aq: Dictionary = World.quest_by_id(str(q.id))
	_ok(str(aq.get("state", "")) == "ready", "clear ready after objective win")
	var af: Dictionary = r.get("aftermath", {})
	_ok(str(af.get("quest_kind", "")) == "clear", "aftermath quest_kind clear")
	# Turn in at issuer
	_ok(World.ready_turn_ins_here().size() >= 1, "clear ready_turn_ins_here")
	var silver0 := GameState.silver
	var tr: Dictionary = World.turn_in(str(q.id))
	_ok(bool(tr.get("ok", false)), "clear turn_in: %s" % tr.get("msg", ""))
	_ok(GameState.silver > silver0, "clear turn_in silver")

func _api_rival_clash_aftermath() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.encounter = {}
	World.last_battle_aftermath.clear()
	World.rivals_enabled = true
	var rv: Dictionary = World.place_rival_here("ash_capital")
	_ok(not rv.is_empty(), "place_rival_here")
	_ok(not World.rival_here().is_empty(), "rival_here after place")
	var enc: Dictionary = World.rival_clash()
	_ok(not enc.is_empty(), "rival_clash encounter")
	_ok(str(enc.get("event", "")).begins_with("rival_"), "rival event id")
	var r: Dictionary = World.on_battle_end(true)
	_ok(bool(r.get("ok", false)), "rival win ok")
	var af: Dictionary = r.get("aftermath", {})
	_ok(str(af.get("kind", "")) == "rival", "aftermath kind rival")
	_ok(not af.get("lines", []).is_empty(), "rival aftermath lines")

func _ui_escort_aftermath_resume() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.encounter = {}
	World.last_battle_aftermath.clear()
	var q: Dictionary = World.seed_escort_offer("ash_capital", "fog_vale")
	World.accept_quest("ash_capital", str(q.id))
	World.begin_travel("fog_vale")
	World.trigger_escort_ambush(str(q.id))
	var r: Dictionary = World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", World.last_battle_aftermath)
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	page.call("_show_battle_aftermath_modal", af)
	for _j in 8:
		await get_tree().process_frame
		if page.find_child("BattleAftermathModal", true, false) != null:
			break
	_ok(page.find_child("BattleAftermathModal", true, false) != null, "escort BattleAftermathModal")
	var cont := page.find_child("BattleAftermathContinue", true, false) as Button
	_ok(cont != null, "escort aftermath Continue")
	if cont != null:
		_ok(str(cont.text).find("行军") >= 0 or str(cont.text).find("继续") >= 0,
			"escort CTA resume got=%s" % cont.text)
		cont.emit_signal("pressed")
		for _k in 8:
			await get_tree().process_frame
	_ok(str(World.quest_by_id(str(q.id)).get("state", "")) == "active", "escort still active after UI resume")
	page.queue_free()
	await get_tree().process_frame
	World.cancel_travel()
	World.travel = {}

func _ui_clear_engage_turnin() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.encounter = {}
	var q: Dictionary = World.seed_clear_offer("ash_capital", "ash_capital", "hq")
	World.accept_quest("ash_capital", str(q.id))
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 6:
		await get_tree().process_frame
	page.set("_sel", "ash_capital")
	page.call("_render_right")
	for _j in 4:
		await get_tree().process_frame
	var eng := page.find_child("EngageButton", true, false) as Button
	_ok(eng != null, "EngageButton present")
	_ok(eng != null and not eng.disabled, "EngageButton enabled for clear")
	if eng != null and not eng.disabled:
		eng.emit_signal("pressed")
		for _k in 10:
			await get_tree().process_frame
			if page.find_child("EncounterFight", true, false) != null or page.find_child("EncounterModal", true, false) != null:
				break
		_ok(not World.encounter.is_empty(), "clear engage opened encounter")
		# Resolve win via retreat path alternative: call on_battle_end directly after closing modal
		page.call("_clear_modal")
		for _m in 4:
			await get_tree().process_frame
		var r: Dictionary = World.on_battle_end(true)
		_ok(bool(r.get("ok", false)), "clear UI fight win")
		_ok(str(World.quest_by_id(str(q.id)).get("state", "")) == "ready", "clear ready after UI engage")
		page.call("_show_turnin_modal", World.ready_turn_ins_here().size())
		for _n in 6:
			await get_tree().process_frame
		_ok(page.find_child("TurnInReadyModal", true, false) != null, "clear TurnInReadyModal")
		var now := page.find_child("TurnInNow", true, false) as Button
		_ok(now != null, "clear TurnInNow")
		if now != null:
			now.emit_signal("pressed")
			for _p in 10:
				await get_tree().process_frame
		_ok(World.quest_by_id(str(q.id)).is_empty(), "clear TurnInNow cleared quest")
	page.queue_free()
	await get_tree().process_frame

func _ui_rival_clash_modal() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.encounter = {}
	World.last_battle_aftermath.clear()
	World.place_rival_here("ash_capital")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 6:
		await get_tree().process_frame
	page.set("_sel", "ash_capital")
	page.call("_render_right")
	for _j in 4:
		await get_tree().process_frame
	var btn := page.find_child("RivalClash", true, false) as Button
	_ok(btn != null, "RivalClash CTA present")
	_ok(btn != null and not btn.disabled, "RivalClash enabled")
	if btn != null and not btn.disabled:
		btn.emit_signal("pressed")
		for _k in 10:
			await get_tree().process_frame
		_ok(not World.encounter.is_empty(), "rival clash encounter opened")
		page.call("_clear_modal")
		for _m in 3:
			await get_tree().process_frame
		var r: Dictionary = World.on_battle_end(true)
		var af: Dictionary = r.get("aftermath", {})
		_ok(str(af.get("kind", "")) == "rival", "UI rival aftermath kind")
		page.call("_show_battle_aftermath_modal", af)
		for _n in 8:
			await get_tree().process_frame
			if page.find_child("BattleAftermathModal", true, false) != null:
				break
		_ok(page.find_child("BattleAftermathModal", true, false) != null, "rival BattleAftermathModal")
		var cont := page.find_child("BattleAftermathContinue", true, false) as Button
		if cont != null:
			cont.emit_signal("pressed")
			for _p in 6:
				await get_tree().process_frame
	page.queue_free()
	await get_tree().process_frame
