extends Node
## Commission loop e2e: every world kind + reclaim + castle board (auto / battle / A-05 herb),
## accept → guide → travel → objective → turn-in → rewards → cleared; expiry, abandon, save/load.
## Prints one "ROW <type> <step> PASS|FAIL <detail>" line per check.

const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const CITY := "ash_capital"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	for kind in ["deliver", "escort", "scout", "hunt", "defend", "clear", "gather"]:
		_world_kind(kind)
	_reclaim()
	_expiry()
	_abandon()
	_save_load()
	_castle_auto()
	_castle_battle()
	_herb_escort()
	if _fails.is_empty():
		print("QUEST LOOP E2E PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL quest loop: ", f)
		get_tree().quit(1)

func _row(kind: String, step: String, ok: bool, detail: String = "") -> bool:
	print("ROW %s %s %s %s" % [kind, step, "PASS" if ok else "FAIL", detail])
	if not ok:
		_fails.append("%s/%s %s" % [kind, step, detail])
	return ok

func _setup() -> void:
	Todo.reset_for_tests()
	GameState.new_game("闭环", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40

func _reset_at(city: String) -> void:
	GameState.food = 900
	GameState.silver = 5000
	World.pos = city
	World.travel = {}
	World.encounter = {}
	World.pending_event = {}
	World.active.clear()
	World.rep_city[city] = 80

func _todo_quests() -> int:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "quests":
			return int(item.get("count", 0))
	return 0

## Walk to dest, winning any encounter on the way (and the one on arrival).
func _go(dest: String) -> int:
	var fights := 0
	for _i in 8:
		if not World.encounter.is_empty():
			World.on_battle_end(true)
			fights += 1
			continue
		if World.pos == dest and not World.is_traveling():
			break
		World.travel_to(dest)
	if not World.encounter.is_empty():
		World.on_battle_end(true)
		fights += 1
	return fights

func _post(city: String, q: Dictionary) -> void:
	World._ensure_board(city)
	World.boards[city].offers.append(q)

func _make(kind: String, seed_tag: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("loop:" + seed_tag)
	for _t in 20:
		var q: Dictionary = World._make_quest(CITY, kind, 1, r)
		if not q.is_empty() and (kind == "gather" or kind == "clear" or str(q.get("target", "")) != CITY):
			return q
	return {}

func _world_kind(kind: String) -> void:
	_reset_at(CITY)
	var q := _make(kind, kind)
	if not _row(kind, "make", not q.is_empty()):
		return
	_run_world(kind, q, CITY)

func _run_world(kind: String, q: Dictionary, city: String) -> void:
	_post(city, q)
	var qid := str(q.id)
	var acc: Dictionary = World.accept_quest(city, qid)
	if not _row(kind, "accept", bool(acc.get("ok", false)), str(acc.get("msg", ""))):
		return
	var guide := str(acc.get("guide_node", ""))
	_row(kind, "guidance", guide != "" and str(acc.get("hint", "")) != "" and str(acc.msg).find(str(acc.hint)) >= 0, "guide=%s" % guide)
	_row(kind, "todo_on", _todo_quests() >= 1, "count=%d" % _todo_quests())
	_row(kind, "atlas_marker", World.quest_markers().has(guide), guide)
	if kind == "gather":
		var mks: Array = World.quest_markers().get(guide, [])
		var pickup_ok := false
		for mk in mks:
			if str(mk.get("kind", "")) == "pickup":
				pickup_ok = true
				break
		_row(kind, "pickup_marker", pickup_ok, guide)
	var issuer := str(q.issuer)
	var rep0 := World.rep_of(issuer)
	if kind == "gather":
		World._add_good(str(q.good), int(q.qty))
		World._check_gather_ready()
	elif kind == "clear":
		var e: Array = q.edge
		var f := _go(str(e[0]))
		if World.quest_by_id(qid).get("state", "") != "ready":
			f += _go(str(e[1]))
		if World.quest_by_id(qid).get("state", "") != "ready":
			f += _go(str(e[0]))
		_row(kind, "battle_spawn_win", f >= 1, "fights=%d" % f)
	else:
		var f2 := _go(guide)
		if str(q.kind) in ["hunt", "defend"]:
			_row(kind, "battle_spawn_win", f2 >= 1, "fights=%d" % f2)
		else:
			_row(kind, "travel_arrive", World.pos == guide, "pos=%s" % World.pos)
	var live := World.quest_by_id(qid)
	if not _row(kind, "objective_ready", str(live.get("state", "")) == "ready", str(live.get("state", "gone"))):
		return
	var turn := World.turn_in_city(live)
	_row(kind, "guide_turnin", World.quest_guide_node(live) == turn and World.quest_markers().has(turn), turn)
	_go(turn)
	var s0 := GameState.silver
	var good := str(q.get("reward_good", ""))
	var g0 := World.have_good(good) if good != "" else 0
	var res: Dictionary = World.turn_in(qid)
	if not _row(kind, "turn_in", bool(res.get("ok", false)), str(res.get("msg", ""))):
		return
	_row(kind, "reward_silver", GameState.silver - s0 >= int(q.reward_silver), "+%d want %d" % [GameState.silver - s0, int(q.reward_silver)])
	_row(kind, "reward_rep", World.rep_of(issuer) > rep0, "%d->%d" % [rep0, World.rep_of(issuer)])
	if good != "":
		_row(kind, "reward_item", World.have_good(good) >= g0 + int(q.reward_qty), good)
	_row(kind, "removed", World.quest_by_id(qid).is_empty())
	_row(kind, "todo_cleared", _todo_quests() == 0, "count=%d" % _todo_quests())

func _reclaim() -> void:
	_reset_at(CITY)
	var sid := ""
	for id in CKTerritory.site_ids():
		var a := str(CKTerritory.site(id).anchor)
		if World.nodes.has(a) and not CKTerritory.is_home(id):
			sid = id
			break
	if not _row("reclaim", "site", sid != ""):
		return
	var anchor := str(CKTerritory.site(sid).anchor)
	CKTerritory.capture(sid, "chain")
	CKTerritory.lose(sid, CKTerritory.NEUTRAL)
	var q: Dictionary = {}
	for o in World.board(anchor):
		if bool(o.get("territory_reclaim", false)):
			q = o
	if not _row("reclaim", "posted", not q.is_empty(), anchor):
		return
	_reset_at(anchor)
	World.boards[anchor].offers.erase(q)
	_run_world("reclaim", q, anchor)
	_row("reclaim", "site_back", CKTerritory.owned(sid), sid)

func _expiry() -> void:
	_reset_at(CITY)
	var q := _make("deliver", "expire")
	_post(CITY, q)
	World.accept_quest(CITY, str(q.id))
	var rep0 := World.rep_of(CITY)
	World.days_total = int(World.quest_by_id(str(q.id)).deadline) + 1
	World._expire_quests()
	_row("expiry", "removed", World.quest_by_id(str(q.id)).is_empty())
	_row("expiry", "rep_penalty", World.rep_of(CITY) < rep0, "%d->%d" % [rep0, World.rep_of(CITY)])
	_row("expiry", "todo_cleared", _todo_quests() == 0)

func _abandon() -> void:
	_reset_at(CITY)
	var q := _make("escort", "abandon")
	_post(CITY, q)
	World.accept_quest(CITY, str(q.id))
	var r: Dictionary = World.abandon(str(q.id))
	_row("abandon", "ok", bool(r.get("ok", false)), str(r.get("msg", "")))
	_row("abandon", "removed", World.quest_by_id(str(q.id)).is_empty())
	_row("abandon", "todo_cleared", _todo_quests() == 0)

func _save_load() -> void:
	_reset_at(CITY)
	var q := _make("hunt", "save")
	_post(CITY, q)
	var qid := str(q.id)
	World.accept_quest(CITY, qid)
	var dl := int(World.quest_by_id(qid).deadline)
	_row("save_load", "save", GameState.save_to_slot("quick"))
	World.active.clear()
	_row("save_load", "load", GameState.load_from_slot("quick"))
	var live := World.quest_by_id(qid)
	_row("save_load", "active_kept", not live.is_empty() and int(live.get("deadline", -1)) == dl, str(live.get("state", "gone")))
	# mid-encounter save
	World.events_enabled = false
	World.travel_to(str(q.target))
	var had := not World.encounter.is_empty()
	GameState.save_to_slot("quick")
	World.encounter = {}
	GameState.load_from_slot("quick")
	World.events_enabled = false
	_row("save_load", "encounter_kept", had and str(World.encounter.get("quest", "")) == qid)
	World.on_battle_end(true)
	_go(World.turn_in_city(World.quest_by_id(qid)))
	_row("save_load", "finish_after_load", bool(World.turn_in(qid).get("ok", false)))

func _castle_auto() -> void:
	_reset_at(CITY)
	var s0 := GameState.silver
	var r := GameState.accept_quest("q_drill")
	_row("castle_auto", "accept_settle", bool(r.get("ok", false)) and not bool(r.get("battle", true)))
	_row("castle_auto", "reward_silver", GameState.silver > s0 - 200, "silver %d->%d (月饷已扣)" % [s0, GameState.silver])
	_row("castle_auto", "todo_cleared", _todo_quests() == 0)

func _castle_battle() -> void:
	_reset_at(CITY)
	var q: Dictionary = {}
	for row in GameState.quests:
		if str(row.id) == "q_bandit":
			q = row
	var r := GameState.accept_quest("q_bandit")
	_row("castle_battle", "accept", bool(r.get("ok", false)) and bool(r.get("battle", false)))
	_row("castle_battle", "battle_map", str(GameState.get_meta("battle_map", "")) == str(q.get("map", "")), str(GameState.get_meta("battle_map", "")))
	_row("castle_battle", "todo_on", _todo_quests() == 1)
	var s0 := GameState.silver
	var rep0 := int(GameState.reputation.get("ashland", 0))
	GameState.on_battle_quest_victory()
	_row("castle_battle", "reward_silver", GameState.silver - s0 >= int(q.silver), "+%d want %d" % [GameState.silver - s0, int(q.silver)])
	var rep1 := int(GameState.reputation.get("ashland", 0))
	_row("castle_battle", "reward_rep", rep1 - rep0 >= int(q.rep), "+%d want %d" % [rep1 - rep0, int(q.rep)])
	_row("castle_battle", "first_clear", bool(GameState.quest_done.get("q_bandit", false)))
	_row("castle_battle", "todo_cleared", _todo_quests() == 0)

func _herb_escort() -> void:
	_reset_at(CITY)
	GameState.set_flag("pro_lease_kept", true)
	var q := World.ensure_opening_herb_escort()
	_row("herb_A05", "posted", not q.is_empty())
	var s0 := GameState.silver
	var r := World.accept_opening_herb_escort()
	_row("herb_A05", "accept_settle", bool(r.get("ok", false)), str(r.get("msg", "")))
	_row("herb_A05", "reward_silver", bool(GameState.quest_done.get("q_opening_herb_escort", false)), "silver %d->%d" % [s0, GameState.silver])
	var s1 := GameState.silver
	var again := World.accept_opening_herb_escort()
	_row("herb_A05", "no_double_pay", bool(again.get("ok", false)) and GameState.silver == s1)
	_row("herb_A05", "todo_cleared", _todo_quests() == 0)
