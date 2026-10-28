extends Node
## Audit P1-1: a fresh game has nothing due; hp below max is not a wound; locked entries never count.

const Todo = preload("res://scripts/ui/widgets/todo_center.gd")

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL todo due: ", err)
		get_tree().quit(1)
	else:
		print("TODO DUE PASS")
		get_tree().quit(0)

func _run() -> String:
	Todo.reset_for_tests()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	for item in Todo.snapshot():
		if int(item.get("count", 0)) > 0 and str(item.get("category", "")) != "festival":
			return "fresh game shows %s %d" % [str(item.get("label", "")), int(item.get("count", 0))]
	GameState.get_leader().hp = 1
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "injured" and int(item.get("count", 0)) > 0:
			return "hp below max counted as wounded"
	GameState.set_meta("active_quest_id", "q_bandit")
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "quests" and not Todo.is_unlocked("quests"):
			return "locked quests still counted"
	GameState.get_leader().injured = true
	var hurt := 0
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "injured":
			hurt = int(item.get("count", 0))
	if hurt != 1:
		return "real wound not counted (%d)" % hurt
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "injured" and Todo.link_for(item) != "res://scenes/hub/roster.tscn":
			return "injured chip has no roster link"
		if str(item.get("category", "")) == "festival" and Todo.link_for(item) != "":
			return "festival chip links somewhere"
	if Todo.link_for({"link": "res://scenes/hub/nope.tscn"}) != "":
		return "missing scene accepted as link"
	Todo.register("x", "home", "x", 1, "res://scenes/hub/roster.tscn")
	var found := false
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "x" and Todo.link_for(item) != "":
			found = true
	Todo.reset_for_tests()
	if not found:
		return "registered link dropped"
	GameState.remove_meta("active_quest_id")
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.active = [{"id": "wq_probe", "title": "probe", "state": "active", "kind": "deliver", "target": "ash_capital", "issuer": "ash_capital"}]
	if Todo.is_unlocked("quests"):
		var wq := 0
		for item in Todo.snapshot():
			if str(item.get("category", "")) == "quests":
				wq = int(item.get("count", 0))
		if wq < 1:
			return "world active not counted (%d)" % wq
	World.active.clear()
	var terr_err := _check_territory_todos()
	if terr_err != "":
		return terr_err
	print("OK todo due")
	return ""


## J14 threat + §20 stockade credit + §21 reclaim + §22 unrest + §23 chain + §24 contest + §25 drain HubTodo chips.
func _check_territory_todos() -> String:
	var err := _check_threat()
	if err != "":
		return err
	err = _check_stockade_credit()
	if err != "":
		return err
	err = _check_reclaim()
	if err != "":
		return err
	err = _check_unrest()
	if err != "":
		return err
	err = _check_chain()
	if err != "":
		return err
	err = _check_contest()
	if err != "":
		return err
	return _check_drain()


func _check_threat() -> String:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat" and int(item.get("count", 0)) > 0:
			return "fresh/no-threat still shows territory_threat"
	var site := "t_ash_cinderpit"
	var st: Dictionary = CKTerritory.state(site)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.threat = {}
	CKTerritory._put(site, st)
	var anchor := str(CKTerritory.site(site).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(site, "chain")
	st = CKTerritory.state(site)
	st.garrison = 2
	st.threat = {}
	CKTerritory._put(site, st)
	World.last_siege_alert = {}
	CKTerritory.start_threat(site)
	World.take_siege_alert()  # dismiss — chip must still count from live threat
	var threat_row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat":
			threat_row = item
	if int(threat_row.get("count", 0)) != 1:
		return "threatened site not counted (%s)" % str(threat_row)
	if Todo.link_for(threat_row) != "res://scenes/hub/atlas_view.tscn":
		return "territory_threat chip has no atlas link"
	Todo.prepare_nav(threat_row)
	if World.last_siege_alert.is_empty() or str(World.last_siege_alert.get("id", "")) != site:
		return "prepare_nav did not requeue siege alert"
	st = CKTerritory.state(site)
	st.threat = {}
	CKTerritory._put(site, st)
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat" and int(item.get("count", 0)) > 0:
			return "cleared threat still shows territory_threat"
	return ""


func _check_stockade_credit() -> String:
	CKTerritory._st().stockade_credit = 0
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "stockade_credit" and int(item.get("count", 0)) > 0:
			return "no-credit still shows stockade_credit"
	CKTerritory.grant_stockade_credit("chain_ash")
	var credit_row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "stockade_credit":
			credit_row = item
	if int(credit_row.get("count", 0)) != 1:
		return "stockade_credit chip missing after grant (%s)" % str(credit_row)
	if Todo.link_for(credit_row) != "res://scenes/hub/territory_ledger.tscn":
		return "stockade_credit chip has no ledger link"
	CKTerritory._st().stockade_credit = 0
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "stockade_credit" and int(item.get("count", 0)) > 0:
			return "cleared credit still shows stockade_credit"
	return ""


## §21 reclaim: lose → chip+atlas focus; finish → chip gone.
func _check_reclaim() -> String:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_reclaim" and int(item.get("count", 0)) > 0:
			return "fresh/no-reclaim still shows territory_reclaim"
	World.active.clear()
	var reclaim_site := "t_ash_cinderpit"
	var rst: Dictionary = CKTerritory.state(reclaim_site)
	rst.owner = CKTerritory.NEUTRAL
	rst.garrison = 0
	rst.threat = {}
	CKTerritory._put(reclaim_site, rst)
	var ranchor := str(CKTerritory.site(reclaim_site).get("anchor", ""))
	World.pos = ranchor
	World.arrive(ranchor)
	CKTerritory.capture(reclaim_site, "chain")
	rst = CKTerritory.state(reclaim_site)
	rst.garrison = 1
	CKTerritory._put(reclaim_site, rst)
	CKTerritory.lose(reclaim_site, "rival:salt_crow")
	var reclaim_row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_reclaim":
			reclaim_row = item
	if int(reclaim_row.get("count", 0)) < 1:
		return "reclaim chip missing after lose (%s)" % str(reclaim_row)
	if Todo.link_for(reclaim_row) != "res://scenes/hub/atlas_view.tscn":
		return "territory_reclaim chip has no atlas link"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	if GameState.has_meta("atlas_select"):
		GameState.remove_meta("atlas_select")
	Todo.prepare_nav(reclaim_row)
	if not GameState.has_meta("atlas_territory_site") or str(GameState.get_meta("atlas_territory_site")) != reclaim_site:
		return "prepare_nav did not focus reclaim site"
	CKTerritory._finish_reclaim(reclaim_site)
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_reclaim" and int(item.get("count", 0)) > 0:
			return "cleared reclaim still shows territory_reclaim"
	return ""

## §22 unrest: assault capture → chip+ledger link; appease → chip gone.
func _check_unrest() -> String:
	# Prior §21 reclaim finish leaves unrest=1 on the site — clear owned unrest first.
	for oid in CKTerritory.owned_ids():
		var ost: Dictionary = CKTerritory.state(str(oid))
		ost.unrest = 0
		CKTerritory._put(str(oid), ost)
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_unrest" and int(item.get("count", 0)) > 0:
			return "fresh/no-unrest still shows territory_unrest"
	var site := "t_ash_cinderpit"
	var st: Dictionary = CKTerritory.state(site)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(site, st)
	var anchor := str(CKTerritory.site(site).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(site, "assault")
	if int(CKTerritory.state(site).unrest) <= 0:
		return "assault capture did not set unrest"
	var unrest_row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_unrest":
			unrest_row = item
	if int(unrest_row.get("count", 0)) < 1:
		return "unrest chip missing after assault (%s)" % str(unrest_row)
	if Todo.link_for(unrest_row) != "res://scenes/hub/territory_ledger.tscn":
		return "territory_unrest chip has no ledger link"
	GameState.silver = maxi(GameState.silver, CKTerritory.appease_cost(site) + 10)
	var r: Dictionary = CKTerritory.appease(site)
	if not bool(r.get("ok", false)):
		return "appease failed: %s" % r.get("msg", "")
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_unrest" and int(item.get("count", 0)) > 0:
			return "cleared unrest still shows territory_unrest"
	return ""

## §23 chain pledge: post_chain → chip+atlas focus; capture → chip gone.
func _check_chain() -> String:
	# Prior captures may leave owned sites — reset target to neutral first.
	World.active.clear()
	var site := "t_ash_cinderpit"
	var st: Dictionary = CKTerritory.state(site)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(site, st)
	# Drop any leftover chain/reclaim offers on this anchor.
	CKTerritory._clear_chain(site)
	CKTerritory._clear_reclaim(site)
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_chain" and int(item.get("count", 0)) > 0:
			return "fresh/no-chain still shows territory_chain"
	var anchor := str(CKTerritory.site(site).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	var pr: Dictionary = CKTerritory.post_chain(site)
	if not bool(pr.get("ok", false)):
		return "post_chain failed: %s" % pr.get("msg", "")
	var chain_row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_chain":
			chain_row = item
	if int(chain_row.get("count", 0)) < 1:
		return "chain chip missing after post_chain (%s)" % str(chain_row)
	if Todo.link_for(chain_row) != "res://scenes/hub/atlas_view.tscn":
		return "territory_chain chip has no atlas link"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	if GameState.has_meta("atlas_select"):
		GameState.remove_meta("atlas_select")
	Todo.prepare_nav(chain_row)
	if not GameState.has_meta("atlas_territory_site") or str(GameState.get_meta("atlas_territory_site")) != site:
		return "prepare_nav did not focus chain site"
	CKTerritory.capture(site, "chain")
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_chain" and int(item.get("count", 0)) > 0:
			return "cleared chain still shows territory_chain"
	return ""


## §24 contest: start_neutral_contest → chip+atlas focus; capture → chip gone.
func _check_contest() -> String:
	var site := "t_ash_cinderpit"
	var st: Dictionary = CKTerritory.state(site)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(site, st)
	World.last_neutral_contest = {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_contest" and int(item.get("count", 0)) > 0:
			return "fresh/no-contest still shows territory_contest"
	CKTerritory.start_neutral_contest(site, [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	])
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_contest":
			row = item
	if int(row.get("count", 0)) < 1:
		return "contest chip missing after start (%s)" % str(row)
	if Todo.link_for(row) != "res://scenes/hub/atlas_view.tscn":
		return "territory_contest chip has no atlas link"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	Todo.prepare_nav(row)
	if not GameState.has_meta("atlas_territory_site") or str(GameState.get_meta("atlas_territory_site")) != site:
		return "prepare_nav did not focus contest site"
	var anchor := str(CKTerritory.site(site).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(site, "contest")
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_contest" and int(item.get("count", 0)) > 0:
			return "cleared contest still shows territory_contest"
	return ""


## §25 drain: seed drains → chip+ledger; reinforce → chip gone.
func _check_drain() -> String:
	var site := "t_ash_cinderpit"
	var st: Dictionary = CKTerritory.state(site)
	st.owner = CKTerritory.OWN
	st.garrison = 1
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(site, st)
	CKTerritory.last_month_report = {
		"silver": 0, "food": 0, "owned": 1, "owned_before": 1,
		"drains": [], "lost": [], "held": [], "threats": [], "line": "ok",
		"reclaims": [], "contests": [], "contest_open": [],
	}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_drain" and int(item.get("count", 0)) > 0:
			return "fresh/no-drain still shows territory_drain"
	CKTerritory.last_month_report["drains"] = [{"id": site, "name": str(CKTerritory.site(site).name), "garrison": 1, "text": "drain"}]
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_drain":
			row = item
	if int(row.get("count", 0)) < 1:
		return "drain chip missing after seed (%s)" % str(row)
	if Todo.link_for(row) != "res://scenes/hub/territory_ledger.tscn":
		return "territory_drain chip has no ledger link"
	GameState.silver = maxi(GameState.silver, 500)
	var r: Dictionary = CKTerritory.reinforce(site)
	if not bool(r.get("ok", false)):
		return "reinforce fail: %s" % r.get("msg", "")
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_drain" and int(item.get("count", 0)) > 0:
			return "cleared drain still shows territory_drain"
	return ""
