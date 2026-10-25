extends Node
## Fat atlas: fight resolve → battle aftermath → resume march + deliver accept→arrive→TurnInNow.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_battle_aftermath_win_lose()
	_api_deliver_seed_accept()
	await _ui_battle_aftermath_modal_win_resume()
	await _ui_battle_aftermath_modal_lose()
	await _ui_deliver_turnin_now()
	if _fails.is_empty():
		print("ATLAS ENCOUNTER DELIVER RESUME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas encounter/deliver/resume: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("遭遇送达", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
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

func _api_battle_aftermath_win_lose() -> void:
	# Win while mid-travel → structured aftermath + resume_travel
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.encounter = {}
	World.last_battle_aftermath.clear()
	GameState.silver = 5000
	GameState.morale = 80
	var st: Dictionary = World.begin_travel("fog_vale")
	_ok(bool(st.get("ok", false)), "begin_travel fog_vale for win: %s" % st.get("msg", ""))
	_ok(World.is_traveling(), "traveling before encounter")
	var enc: Dictionary = World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 1})
	_ok(not enc.is_empty() and not World.encounter.is_empty(), "road encounter seeded")
	var silver0 := GameState.silver
	var r: Dictionary = World.on_battle_end(true)
	_ok(bool(r.get("ok", false)), "on_battle_end win ok")
	_ok(bool(r.get("win", false)), "win flag")
	_ok(r.has("aftermath"), "win returns aftermath")
	var af: Dictionary = r.get("aftermath", {})
	_ok(not af.is_empty() and not World.last_battle_aftermath.is_empty(), "last_battle_aftermath set")
	_ok(af.has("lines") and not af.get("lines", []).is_empty(), "win lines non-empty")
	_ok(af.has("silver_delta") and int(af.get("silver_delta", 0)) > 0, "loot silver_delta > 0")
	_ok(GameState.silver > silver0, "silver increased on win")
	_ok(bool(af.get("resume_travel", false)) or bool(r.get("resume_travel", false)), "resume_travel on win mid-march")
	_ok(str(af.get("nation", "")) != "", "win aftermath nation for 敌徽")
	_ok(str(af.get("nation", "")) == str(enc.get("nation", "")), "win aftermath nation matches enc")
	_ok(World.is_traveling() and World.encounter.is_empty(), "still traveling, encounter cleared")
	# Lose → retreat + cargo/morale + no resume
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo["ashsteel"] = 4
	World.cargo_basis["ashsteel"] = {"unit": 100, "qty": 4}
	World.last_battle_aftermath.clear()
	var st2: Dictionary = World.begin_travel("fog_vale")
	_ok(bool(st2.get("ok", false)), "begin_travel for lose")
	World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 1})
	var morale0 := GameState.morale
	var cargo0 := int(World.cargo.get("ashsteel", 0))
	var lose: Dictionary = World.on_battle_end(false)
	_ok(bool(lose.get("ok", false)), "on_battle_end lose ok")
	_ok(not bool(lose.get("win", true)), "lose flag")
	var laf: Dictionary = lose.get("aftermath", {})
	_ok(not laf.is_empty(), "lose aftermath set")
	_ok(not bool(laf.get("resume_travel", true)), "no resume_travel on lose")
	_ok(not World.is_traveling(), "travel cleared on lose")
	_ok(GameState.morale < morale0, "morale dropped on lose")
	_ok(int(World.cargo.get("ashsteel", 0)) < cargo0, "cargo damaged on lose")
	_ok(laf.has("lines") and not laf.get("lines", []).is_empty(), "lose lines")

func _api_deliver_seed_accept() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.cargo.clear()
	World.encounter = {}
	var q: Dictionary = World.seed_deliver_offer("ash_capital", "fog_vale")
	_ok(str(q.get("kind", "")) == "deliver", "seed deliver kind")
	_ok(str(q.get("target", "")) == "fog_vale", "seed target fog_vale")
	_ok(int(q.get("req_rep", -1)) == 0, "seed req_rep 0")
	var offers: Array = World.board("ash_capital")
	_ok(not offers.is_empty() and str(offers[0].get("id", "")) == str(q.get("id", "")), "seed on board")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q.id))
	_ok(bool(acc.get("ok", false)), "accept deliver: %s" % acc.get("msg", ""))
	_ok(World.active.size() >= 1, "active has deliver")
	var aq: Dictionary = World.quest_by_id(str(q.id))
	_ok(str(aq.get("state", "")) == "active", "deliver active")
	# Arrive target → ready
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	aq = World.quest_by_id(str(q.id))
	_ok(str(aq.get("state", "")) == "ready", "deliver ready at fog_vale")
	var ready: Array = World.ready_turn_ins_here()
	_ok(ready.size() >= 1, "ready_turn_ins_here has deliver")
	var silver0 := GameState.silver
	var tr: Dictionary = World.turn_in(str(q.id))
	_ok(bool(tr.get("ok", false)), "turn_in deliver: %s" % tr.get("msg", ""))
	_ok(GameState.silver > silver0, "silver from turn_in")
	_ok(World.quest_by_id(str(q.id)).is_empty(), "quest removed after turn_in")

func _ui_battle_aftermath_modal_win_resume() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.encounter = {}
	World.last_battle_aftermath.clear()
	GameState.silver = 5000
	var st: Dictionary = World.begin_travel("fog_vale")
	_ok(bool(st.get("ok", false)), "ui win begin_travel")
	World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 1})
	var r: Dictionary = World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", World.last_battle_aftermath)
	_ok(not af.is_empty(), "ui win aftermath payload")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	page.call("_show_battle_aftermath_modal", af)
	for _j in 8:
		await get_tree().process_frame
		if page.find_child("BattleAftermathModal", true, false) != null:
			break
	var modal := page.find_child("BattleAftermathModal", true, false)
	_ok(modal != null, "BattleAftermathModal win shown")
	_ok(page.find_child("BattleAftermathLines", true, false) != null, "BattleAftermathLines")
	_ok(page.find_child("BattleAftermathSummary", true, false) != null, "BattleAftermathSummary")
	var strip := page.find_child("AftermathCrestStrip", true, false)
	_ok(strip != null, "win AftermathCrestStrip")
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var foe := strip.find_child("FoeArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "win 团徽")
		_ok(foe != null and str(foe.get_meta("arms_kind", "")) == "lb_rv_arms", "win 敌徽")
		_ok(str(af.get("nation", "")) != "", "aftermath carries nation")
		if foe != null and str(af.get("nation", "")) != "":
			_ok(str(foe.get_meta("nation_id", "")) == str(af.get("nation", "")), "win foe nation match")
	var cont := page.find_child("BattleAftermathContinue", true, false) as Button
	_ok(cont != null, "BattleAftermathContinue CTA")
	if cont != null:
		var label := str(cont.text)
		_ok(label.find("行军") >= 0 or label.to_lower().find("resume") >= 0 or label.find("继续") >= 0,
			"CTA resume label got=%s" % label)
		cont.emit_signal("pressed")
		for _k in 10:
			await get_tree().process_frame
	page.queue_free()
	await get_tree().process_frame
	World.cancel_travel()
	World.travel = {}

func _ui_battle_aftermath_modal_lose() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo["ashsteel"] = 2
	World.last_battle_aftermath.clear()
	World.begin_travel("fog_vale")
	World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 1})
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	page.call("_show_encounter_modal", World.encounter)
	for _j in 4:
		await get_tree().process_frame
	var enc_strip := page.find_child("AftermathCrestStrip", true, false)
	_ok(enc_strip != null and enc_strip.find_child("FoeArms", true, false) != null, "EncounterModal crest strip")
	var retreat := page.find_child("EncounterRetreat", true, false) as Button
	_ok(retreat != null, "EncounterRetreat present")
	if retreat != null:
		retreat.emit_signal("pressed")
		for _k in 40:
			await get_tree().process_frame
			if page.find_child("BattleAftermathModal", true, false) != null:
				break
		var am := page.find_child("BattleAftermathModal", true, false)
		_ok(am != null, "BattleAftermathModal after retreat")
		var rstrip := page.find_child("AftermathCrestStrip", true, false)
		_ok(rstrip != null and rstrip.find_child("CastleArms", true, false) != null, "retreat AftermathCrestStrip")
		_ok(rstrip != null and rstrip.find_child("FoeArms", true, false) != null, "retreat FoeArms")
		var cont := page.find_child("BattleAftermathContinue", true, false) as Button
		_ok(cont != null, "BattleAftermathContinue on lose")
		if cont != null:
			cont.emit_signal("pressed")
			for _m in 8:
				await get_tree().process_frame
	page.queue_free()
	await get_tree().process_frame
	World.encounter = {}
	World.travel = {}

func _ui_deliver_turnin_now() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.active.clear()
	World.cargo.clear()
	World.encounter = {}
	var q: Dictionary = World.seed_deliver_offer("ash_capital", "fog_vale")
	var acc: Dictionary = World.accept_quest("ash_capital", str(q.id))
	_ok(bool(acc.get("ok", false)), "ui accept deliver")
	# Simulate march arrival at target
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	var ready: Array = World.ready_turn_ins_here()
	_ok(ready.size() >= 1, "ui ready turn-ins")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	page.call("_show_turnin_modal", ready.size())
	for _j in 5:
		await get_tree().process_frame
	var modal := page.find_child("TurnInReadyModal", true, false)
	_ok(modal != null, "TurnInReadyModal shown")
	_ok(page.find_child("TurnInList", true, false) != null, "TurnInList")
	_ok(page.find_child("TurnInNow", true, false) != null, "TurnInNow CTA")
	_ok(page.find_child("TurnInEnter", true, false) != null, "TurnInEnter still present")
	var silver0 := GameState.silver
	var now := page.find_child("TurnInNow", true, false) as Button
	if now != null:
		now.emit_signal("pressed")
		for _k in 12:
			await get_tree().process_frame
	_ok(World.quest_by_id(str(q.id)).is_empty(), "TurnInNow cleared quest")
	_ok(GameState.silver > silver0, "TurnInNow paid silver")
	page.queue_free()
	await get_tree().process_frame
