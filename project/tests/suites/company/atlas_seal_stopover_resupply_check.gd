extends Node
## Fat deepen: winter detour mid-halt -> city stopover grain buy covers bypass remain -> resume stays off sealed shortpath.

const ORIGIN := "fog_vale"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_seal_aware_days()
	_api_stopover_buy_covers_bypass()
	_api_resume_after_city_resupply()
	await _ui_stopover_seal_cover()
	if fails.is_empty():
		print("SEAL STOPOVER RESUPPLY PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL seal stopover resupply: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _setup() -> void:
	GameState.new_game("封路停靠补给", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.food = 40
	GameState.silver = 20000
	GameState.morale = 80
	Calendar.year = 1
	Calendar.month = 1
	World.day = 1
	World.days_total = 0
	World.pos = ORIGIN
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.road_flags.clear()
	World.march_hold = {}
	World.seal_detour = {}
	World.last_supply_halt = {}
	World.visited[ORIGIN] = true
	World.visited[DEST] = true

func _path_hits_seal(path: Array) -> bool:
	for i in range(maxi(0, path.size() - 1)):
		if CKRoadSeal.is_sealed(str(path[i]), str(path[i + 1])):
			return true
	return false

func _seed_mid_detour() -> Dictionary:
	_ok(CKRoadSeal.seal_active(), "winter seals")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	_ok(bool(cmp.get("sealed", false)), "direct road sealed fog_vale->sy_ridge")
	var detour: Dictionary = cmp.get("detour", {})
	var path: Array = detour.get("path", [])
	_ok(bool(detour.get("ok", false)) and path.size() >= 4, "detour >=4 hops (%s)" % path.size())
	if path.size() < 4:
		return {}
	World.note_seal_detour(DEST, path)
	# Walk two hops so remain still >> floor 7.
	for i in range(1, mini(3, path.size() - 1)):
		World.travel_to(str(path[i]))
	_ok(World.pos != ORIGIN and World.pos != DEST, "stood mid-detour at %s" % World.pos)
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "seal_detour survives hops")
	World.hold_march(DEST)
	return {"path": path, "rem": World.seal_detour_remaining(), "days": int(detour.get("days", 0))}

func _api_seal_aware_days() -> void:
	_setup()
	var seed: Dictionary = _seed_mid_detour()
	if seed.is_empty():
		return
	var rem: Array = seed.get("rem", [])
	_ok(rem.size() >= 2, "remaining path >=2")
	var aware := World.seal_aware_remain_days(DEST)
	_ok(aware > 7, "seal-aware remain >7 (got %d)" % aware)
	var naive: Dictionary = World.route(World.pos, DEST)
	var naive_days := int(naive.get("days", 0))
	_ok(aware >= naive_days, "seal-aware (%d) >= naive shortpath (%d)" % [aware, naive_days])
	_ok(_path_hits_seal(naive.get("path", [])), "naive shortpath still hits seal")
	var buy_days := World.stopover_resupply_days(DEST, 7)
	_ok(buy_days == maxi(7, aware), "stopover days=%d == max(7,%d)" % [buy_days, aware])

func _api_stopover_buy_covers_bypass() -> void:
	_setup()
	var seed: Dictionary = _seed_mid_detour()
	if seed.is_empty():
		return
	var here := World.pos
	var aware := World.seal_aware_remain_days(DEST)
	var days := World.stopover_resupply_days(DEST, 7)
	GameState.food = 2
	var before := GameState.food
	var q: Dictionary = World.resupply_quote(here, days)
	_ok(bool(q.get("ok", false)), "resupply_quote ok: %s" % q.get("msg", ""))
	_ok(int(q.get("days", 0)) >= aware or int(q.get("qty", 0)) >= World.food_per_day() * aware,
		"quote covers seal-aware remain (days=%s qty=%s aware=%d)" % [q.get("days"), q.get("qty"), aware])
	var r: Dictionary = World.resupply_food(here, days)
	_ok(bool(r.get("ok", false)), "resupply_food ok: %s" % r.get("msg", ""))
	_ok(GameState.food > before, "food raised %d -> %d" % [before, GameState.food])
	var need_food := World.food_per_day() * aware
	_ok(GameState.food >= need_food, "food %d covers bypass need %d" % [GameState.food, need_food])
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "seal_detour survives city resupply")

func _api_resume_after_city_resupply() -> void:
	_setup()
	var seed: Dictionary = _seed_mid_detour()
	if seed.is_empty():
		return
	var days := World.stopover_resupply_days(DEST, 7)
	GameState.food = 2
	World.resupply_food(World.pos, days)
	# City market visit must not clear seal_detour.
	World.visited[World.pos] = true
	_ok(str(World.seal_detour.get("dest", "")) == DEST, "seal_detour after city mark")
	var go: Dictionary = World.begin_travel(DEST)
	_ok(bool(go.get("ok", false)), "begin_travel after resupply: %s" % go.get("msg", ""))
	var route: Array = World.travel.get("route", [])
	_ok(not _path_hits_seal(route), "resume route avoids sealed edges (%s)" % str(route))
	var rem: Array = World.seal_detour_remaining()
	_ok(route.size() >= 2 and rem.size() >= 2 and str(route[0]) == str(rem[0]), "resume starts on remaining bypass")

func _ui_stopover_seal_cover() -> void:
	_setup()
	var seed: Dictionary = _seed_mid_detour()
	if seed.is_empty():
		return
	GameState.food = 3
	var atlas = load("res://scenes/hub/atlas_view.tscn").instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	# Drive stopover via atlas internal state if present.
	if atlas.has_method("_show_stopover_modal"):
		if "_halted_dest" in atlas:
			atlas._halted_dest = DEST
		elif atlas.get("_halted_dest") != null:
			atlas.set("_halted_dest", DEST)
		# Property access
		atlas.set("_halted_dest", DEST)
		atlas.call("_show_stopover_modal")
		await get_tree().process_frame
		await get_tree().process_frame
		var modal = atlas.find_child("StopoverModal", true, false)
		_ok(modal != null, "StopoverModal shown")
		if modal != null:
			var cover = modal.find_child("StopoverSealCover", true, false)
			_ok(cover != null, "StopoverSealCover tip present")
			var buy = modal.find_child("StopoverBuy", true, false)
			_ok(buy != null, "StopoverBuy present")
			if buy != null:
				var aware := World.seal_aware_remain_days(DEST)
				var label := str(buy.text) if "text" in buy else str(buy.get_text() if buy.has_method("get_text") else "")
				# Button caption includes day count as first %d of atlas_stopover_buy.
				_ok(str(aware) in label or str(maxi(7, aware)) in label,
					"buy caption includes seal days (aware=%d label=%s)" % [aware, label])
	else:
		_ok(false, "atlas missing _show_stopover_modal")
	atlas.queue_free()
	await get_tree().process_frame
