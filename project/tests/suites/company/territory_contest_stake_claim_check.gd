extends Node
## Territory fat: contest_preview → contest_stake (加码) → tick resolve → capture(how contest)
## → month_echo.contest + ContestTug ContestStake/EchoLine_contest + TerritoryMonth ContestLine E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY CONTEST STAKE CLAIM PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory contest stake claim: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_stake_then_claim()
	if err != "":
		return err
	err = _api_rival_resolve_echo()
	if err != "":
		return err
	err = await _ui_stake_echo()
	if err != "":
		return err
	err = await _ui_month_contest_line()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("拉锯加码落幕", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	World.rivals = [
		{"id": "rv_a", "name": "灰烬狼团", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
		{"id": "rv_b", "name": "盐湾镖旗", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
	]
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 40
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_neutral_contest = {}
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")


func _reset(id: String = SITE) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.cache_food = 0
	CKTerritory._put(id, st)
	World.last_neutral_contest = {}


func _force_factions() -> Array:
	return [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	]


func _api_rejects() -> String:
	_setup()
	_reset()
	var prev: Dictionary = CKTerritory.contest_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should fail without contest"
	var r: Dictionary = CKTerritory.contest_stake(SITE)
	if bool(r.get("ok", false)):
		return "stake should reject without contest"
	if str(CKEconomyState.month_echo_snapshot().get("contest", "")) != "":
		return "echo leaked on reject"
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	GameState.silver = 0
	prev = CKTerritory.contest_preview(SITE)
	if not bool(prev.get("ok", false)):
		return "preview want ok with contest: %s" % str(prev)
	if bool(prev.get("can_stake", true)):
		return "can_stake should be false with 0 silver"
	r = CKTerritory.contest_stake(SITE)
	if bool(r.get("ok", false)):
		return "stake should reject 0 silver"
	print("api contest stake rejects ok")
	return ""


func _api_stake_then_claim() -> String:
	_setup()
	_reset()
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	var prev: Dictionary = CKTerritory.contest_preview(SITE)
	var err := ""
	if not bool(prev.get("ok", false)):
		err = "preview fail: %s" % str(prev)
	var cost := int(prev.get("stake_cost", 0))
	if err == "" and cost <= 0:
		err = "stake_cost should be > 0"
	var silver_before := GameState.silver
	var r: Dictionary = {}
	if err == "":
		r = CKTerritory.contest_stake(SITE)
		if not bool(r.get("ok", false)):
			err = "stake fail: %s" % str(r)
	if err == "" and GameState.silver != silver_before - cost:
		err = "silver not deducted want %d got %d" % [silver_before - cost, GameState.silver]
	if err == "" and int(r.get("pressure", 0)) <= 3:
		err = "company pressure should beat top rival (3)"
	var echo := str(CKEconomyState.month_echo_snapshot().get("contest", ""))
	if err == "" and echo == "":
		err = "month_echo.contest missing after stake"
	if err == "" and "拉锯" not in echo and "加码" not in echo:
		err = "month_echo.contest unexpected: %s" % echo
	if err == "":
		var r2: Dictionary = CKTerritory.contest_stake(SITE)
		if bool(r2.get("ok", false)):
			err = "double stake should fail"
	var resolved: Array = []
	if err == "":
		World.last_neutral_contest = {}
		resolved = CKTerritory.tick_neutral_contests(true)
		if resolved.is_empty():
			err = "tick resolve empty"
	if err == "" and str(resolved[0].get("winner", "")) != "company":
		err = "winner want company got %s" % str(resolved[0].get("winner", ""))
	if err == "" and not CKTerritory.owned(SITE):
		err = "site not owned after company win"
	if err == "" and int(CKTerritory.state(SITE).garrison) < 1:
		err = "contest claim should leave garrison >= 1"
	var echo2 := str(CKEconomyState.month_echo_snapshot().get("contest", ""))
	if err == "" and echo2 == "":
		err = "month_echo.contest missing after claim"
	if err == "":
		var found := false
		for line in CKEconomyState.month_echo_lines():
			if str(line.get("kind", "")) == "contest":
				found = true
				break
		if not found:
			err = "month_echo_lines missing contest"
	if err == "":
		CKTerritory.apply_month(0.99)
		if not CKTerritory.owned(SITE):
			err = "lost ownership unexpectedly"
	if err != "":
		return err
	print("api stake→claim ok echo=%s" % echo2)
	return ""


func _api_rival_resolve_echo() -> String:
	_setup()
	_reset()
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	var resolved: Array = CKTerritory.tick_neutral_contests(true)
	if resolved.is_empty():
		return "rival resolve empty"
	if str(resolved[0].get("winner", "")) != "rival:rv_a":
		return "want rival:rv_a got %s" % str(resolved[0].get("winner", ""))
	if not str(CKTerritory.owner(SITE)).begins_with("rival:"):
		return "rival should own site"
	var echo := str(CKEconomyState.month_echo_snapshot().get("contest", ""))
	if echo == "":
		return "rival resolve should write month_echo.contest"
	print("api rival resolve echo ok text=%s" % echo)
	return ""


func _ui_stake_echo() -> String:
	_setup()
	_reset()
	World.pos = "ash_capital"
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 10:
		await get_tree().process_frame
	if atlas.find_child("ContestTugModal", true, false) == null and atlas.has_method("_check_neutral_contest"):
		atlas.call("_check_neutral_contest")
		for _j in 8:
			await get_tree().process_frame
	var panel := atlas.find_child("ContestTugModal", true, false) as Control
	var err := ""
	if panel == null:
		err = "ContestTugModal missing"
	var btn: Button = null
	if err == "":
		btn = panel.find_child("ContestStake", true, false) as Button
		if btn == null:
			err = "ContestStake missing"
		elif btn.disabled:
			err = "ContestStake disabled unexpectedly"
	if err == "":
		btn.pressed.emit()
		for _k in 10:
			await get_tree().process_frame
		if str(CKEconomyState.month_echo_snapshot().get("contest", "")) == "":
			err = "UI missing month_echo.contest after stake"
	if err == "":
		panel = atlas.find_child("ContestTugModal", true, false) as Control
		if panel == null:
			err = "ContestTugModal gone after stake (should stay open)"
	var el: Label = null
	if err == "":
		el = panel.find_child("EchoLine_contest", true, false) as Label
		if el == null:
			err = "EchoLine_contest missing"
		elif el.text == "":
			err = "EchoLine_contest empty"
	if err != "":
		atlas.queue_free()
		await get_tree().process_frame
		return err
	print("ui stake echo ok text=%s" % el.text)
	atlas.queue_free()
	await get_tree().process_frame
	return ""


func _ui_month_contest_line() -> String:
	_setup()
	_reset()
	var sister := "t_ash_millrun"
	_reset(sister)
	var anch := str(CKTerritory.site(sister).get("anchor", ""))
	World.pos = anch
	World.arrive(anch)
	CKTerritory.capture(sister, "chain")
	var st := CKTerritory.state(sister)
	st.garrison = 1
	CKTerritory._put(sister, st)
	CKTerritory.start_neutral_contest(SITE, _force_factions())
	CKTerritory.contest_stake(SITE)
	World.last_territory_month = {}
	CKTerritory.apply_month(0.99)
	CKTerritory.apply_month(0.99)
	var err := ""
	if not CKTerritory.owned(SITE):
		err = "SITE not claimed after two months"
	if err == "":
		World.last_territory_month = CKTerritory.last_month_report.duplicate(true)
		if World.last_territory_month.is_empty():
			err = "last_month_report empty"
	if err != "":
		return err
	var contests: Array = World.last_territory_month.get("contests", [])
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 10:
		await get_tree().process_frame
	if atlas.find_child("TerritoryMonthModal", true, false) == null and atlas.has_method("_check_territory_month"):
		atlas.call("_check_territory_month")
		for _j in 8:
			await get_tree().process_frame
	var panel := atlas.find_child("TerritoryMonthModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		await get_tree().process_frame
		return "TerritoryMonthModal missing"
	var cl := panel.find_child("ContestLine", true, false) as Label
	var el := panel.find_child("EchoLine_contest", true, false) as Label
	if cl == null and el == null:
		var body := panel.find_child("TerritoryMonthBody", true, false) as Label
		if body == null or ("拉锯" not in body.text and "Contest" not in body.text and "contest" not in body.text.to_lower()):
			atlas.queue_free()
			await get_tree().process_frame
			return "month modal missing contest surface (ContestLine/EchoLine/body)"
	print("ui month contest ok contests=%s echo=%s" % [str(contests.size()), str(el.text if el else "")])
	atlas.queue_free()
	await get_tree().process_frame
	return ""
