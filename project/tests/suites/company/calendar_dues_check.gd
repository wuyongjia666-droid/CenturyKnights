extends Node
## Review 2026-10-17 P0-2: the era dues and the spring purse run in the real month settlement.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL calendar dues: ", err)
		get_tree().quit(1)
	else:
		print("CALENDAR DUES PASS")
		get_tree().quit(0)

func _has(evs: Array, kind: String) -> bool:
	for e in evs:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == kind:
			return true
	return false

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 200
	var evs: Array = Calendar.advance(1)  # year 1 month 2: the opening errand month stays free
	if _has(evs, "epoch_dues"):
		return "dues fired in month 2 of year 1"
	GameState.silver = 200
	if not _has(Calendar.forecast(1), "epoch_dues"):
		return "X5 forecast does not announce the year-1 muster"
	evs = Calendar.advance(1)  # year 1 month 3: founding muster
	if not _has(evs, "epoch_dues"):
		return "no muster in the month-3 report"
	var mus: Dictionary = GameState.house_mods.get("epoch_dues", {})
	if int(mus.get("year", 0)) != 1 or int(mus.get("silver", 0)) <= 0:
		return "muster not recorded: %s" % str(mus)
	if int(GameState.silver) > 200 - int(mus.get("silver", 0)) + 20:
		return "muster did not leave the treasury tight: %d" % int(GameState.silver)
	var before := int(GameState.silver)
	before = int(GameState.silver)
	evs = Calendar.advance(1)  # month 4: spring purse
	if _has(evs, "epoch_dues") or not _has(evs, "spring_purse"):
		return "April of year 1 must report the spring purse, not era dues"
	if int(GameState.house_mods.get("spring_purse", 0)) != 180:
		return "spring purse not paid in April of year 1"
	# Jump to December of year 1, then cross into January of year 2 with a fat treasury.
	while not (Calendar.year == 1 and Calendar.month == 12):
		Calendar.advance(1)
	GameState.silver = 1000
	if not _has(Calendar.forecast(1), "epoch_dues"):
		return "forecast misses the January dues"
	var quote: Dictionary = CKEconomyState.epoch_pressure_quote(GameState, 2)
	evs = Calendar.advance(1)
	if Calendar.year != 2 or Calendar.month != 1:
		return "calendar not at year 2 month 1"
	if not _has(evs, "epoch_dues"):
		return "no January dues in the month report"
	var rec: Dictionary = GameState.house_mods.get("epoch_dues", {})
	if int(rec.get("year", 0)) != 2 or int(rec.get("silver", 0)) <= 0:
		return "dues not recorded: %s" % str(rec)
	if int(rec.get("silver", 0)) > int(quote.get("silver", 0)):
		return "paid %d above the forecast quote %d" % [int(rec.get("silver", 0)), int(quote.get("silver", 0))]
	return ""
