extends Node
## CORE-05: month phases stay ordered, and a no-op subscriber does not change the month.

var _dummy_hits := 0

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_registry(fails)
	_dummy(fails)
	if fails.is_empty():
		print("MONTH BUS PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL month bus: ", f)
	get_tree().quit(1)

func _registry(fails: Array) -> void:
	var rows: Array = CKMonthBus.registry()
	var again: Array = CKMonthBus.registry()
	if JSON.stringify(rows) != JSON.stringify(again):
		fails.append("registry moved between reads")
	var phase_at := {}
	for i in CKMonthBus.PHASES.size():
		phase_at[CKMonthBus.PHASES[i]] = i
	var prev_phase := -1
	var prev_order := -1
	var seen := {}
	for row in rows:
		var phase := str(row["phase"])
		var order := int(row["order"])
		var name := str(row["name"])
		print("MONTH BUS phase=%s order=%d name=%s" % [phase, order, name])
		if not phase_at.has(phase):
			fails.append("unknown phase %s" % phase)
			continue
		var at := int(phase_at[phase])
		if at < prev_phase:
			fails.append("phase %s out of order" % phase)
		if at != prev_phase:
			prev_order = -1
		if order < prev_order:
			fails.append("order slipped in %s" % phase)
		prev_phase = at
		prev_order = order
		seen[name] = phase
	for need in ["_tick_life", "_tick_payroll", "_tick_holdings", "_tick_doctrine", "_tick_spring", "_tick_harvest", "_tick_rival_rumor", "_tick_rival_deals", "_tick_court"]:
		if not seen.has(need):
			fails.append("missing %s" % need)

func _dummy(fails: Array) -> void:
	var plain := _one_month(false)
	var with_dummy := _one_month(true)
	if _dummy_hits != 1:
		fails.append("dummy hits %d" % _dummy_hits)
	if plain["silver"] != with_dummy["silver"] or plain["food"] != with_dummy["food"]:
		fails.append("resources %s vs %s" % [str(plain), str(with_dummy)])
	if JSON.stringify(plain["events"]) != JSON.stringify(with_dummy["events"]):
		fails.append("events changed")
	if plain["year"] != with_dummy["year"] or plain["month"] != with_dummy["month"]:
		fails.append("calendar moved")
	CKMonthBus.unregister(Callable(self, "_dummy_tick"))

func _one_month(use_dummy: bool) -> Dictionary:
	_dummy_hits = 0
	if use_dummy:
		Calendar.register("court", Callable(self, "_dummy_tick"), 10)
	GameState.rng.seed = 91
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var events: Array = Calendar.advance(1)
	return {"silver": GameState.silver, "food": GameState.food, "events": events, "year": Calendar.year, "month": Calendar.month}

func _dummy_tick(_ctx: Dictionary) -> void:
	_dummy_hits += 1
