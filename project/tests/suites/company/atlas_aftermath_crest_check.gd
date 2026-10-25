extends Node
## Fat heraldry E2E: battle/danger aftermath + travel-halt crest strips (团徽 + 敌徽).

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	await _ui_battle_crests()
	await _ui_danger_aftermath_crests()
	await _ui_halt_company_crest()
	if _fails.is_empty():
		print("ATLAS AFTERMATH CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas aftermath crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("战徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 8000
	GameState.morale = 80
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _ui_battle_crests() -> void:
	World.cancel_travel()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.begin_travel("fog_vale")
	var enc: Dictionary = World.start_encounter("road", {"node": "hq", "from": "ash_capital", "danger": 2})
	var r: Dictionary = World.on_battle_end(true)
	var af: Dictionary = r.get("aftermath", {})
	_ok(str(af.get("nation", "")) != "", "battle af.nation set")
	_ok(str(af.get("nation", "")) == str(enc.get("nation", "")), "battle af.nation == enc")
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle()
	page.call("_show_battle_aftermath_modal", af)
	await _settle(8)
	var modal := page.find_child("BattleAftermathModal", true, false)
	_ok(modal != null, "BattleAftermathModal")
	var strip := page.find_child("AftermathCrestStrip", true, false)
	_ok(strip != null, "battle AftermathCrestStrip")
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var foe := strip.find_child("FoeArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "battle 团徽")
		_ok(foe != null and str(foe.get_meta("arms_kind", "")) == "lb_rv_arms", "battle 敌徽")
		_ok(foe != null and str(foe.get_meta("nation_id", "")) == str(af.get("nation", "")), "battle foe nation_id")
		_ok(foe != null and str(foe.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "foe != company core")
	var cont := page.find_child("BattleAftermathContinue", true, false) as Button
	if cont:
		cont.emit_signal("pressed")
		await _settle(4)
	page.queue_free()
	await _settle(2)
	World.cancel_travel()

func _ui_danger_aftermath_crests() -> void:
	## Synthetic danger road aftermath — mirrors World.last_aftermath shape.
	var nid := World.nation_of("ash_capital")
	if nid == "":
		nid = "ashbanner"
	var af := {
		"title": "伏兵",
		"choice": "迎战",
		"lines": ["商队引来了伏兵！"],
		"food_delta": -1,
		"silver_delta": 0,
		"days_delta": 1,
		"food_now": GameState.food,
		"silver_now": GameState.silver,
		"route_note": "",
		"danger": true,
		"id": "ambush",
		"kind": "road",
		"nation": nid,
		"node": "ash_capital",
	}
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle()
	page.call("_show_aftermath_modal", af)
	await _settle(8)
	var modal := page.find_child("AftermathModal", true, false)
	_ok(modal != null, "AftermathModal danger")
	var strip := page.find_child("AftermathCrestStrip", true, false)
	_ok(strip != null, "danger AftermathCrestStrip")
	if strip != null:
		_ok(strip.find_child("CastleArms", true, false) != null, "danger 团徽")
		var foe := strip.find_child("FoeArms", true, false)
		_ok(foe != null and str(foe.get_meta("arms_kind", "")) == "lb_rv_arms", "danger 敌徽")
		_ok(foe != null and str(foe.get_meta("nation_id", "")) == nid, "danger foe nation")
	## Calm road: company only
	var calm := af.duplicate()
	calm["danger"] = false
	calm["title"] = "商队"
	page.call("_show_aftermath_modal", calm)
	await _settle(8)
	var strip2 := page.find_child("AftermathCrestStrip", true, false)
	_ok(strip2 != null and strip2.find_child("CastleArms", true, false) != null, "calm 团徽")
	_ok(strip2 != null and strip2.find_child("FoeArms", true, false) == null, "calm no 敌徽")
	var cont := page.find_child("AftermathContinue", true, false) as Button
	if cont:
		cont.emit_signal("pressed")
		await _settle(4)
	page.queue_free()
	await _settle(2)

func _ui_halt_company_crest() -> void:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle()
	page.call("_show_travel_halt_modal")
	await _settle(8)
	var modal := page.find_child("TravelHaltModal", true, false)
	_ok(modal != null, "TravelHaltModal")
	var strip := page.find_child("AftermathCrestStrip", true, false)
	_ok(strip != null, "halt AftermathCrestStrip")
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "halt 团徽")
		_ok(strip.find_child("FoeArms", true, false) == null, "halt no 敌徽")
	page.queue_free()
	await _settle(2)
