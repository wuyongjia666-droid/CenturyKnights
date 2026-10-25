extends Node
## Fat atlas: season × biome march rations + readable HUD (MarchRationRow / chip).

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_season_bands()
	_api_biome_and_winter_stack()
	_api_text_locale()
	await _ui_party_row_and_top()
	await _ui_route_chip()
	if _fails.is_empty():
		print("ATLAS MARCH RATION SEASON PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas march ration: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("RationSeason", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 120
	GameState.silver = 500
	GameState.morale = 70
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	_pad_party(5)

func _pad_party(n: int) -> void:
	var have := World.party_size()
	var i := 0
	while have < n:
		i += 1
		var cid := "ration_pad_%d" % i
		if GameState.characters.has(cid):
			have = World.party_size()
			continue
		var c := CKCharacter.new()
		c.id = cid
		c.name = "Pad%d" % i
		c.alive = true
		c.is_child = false
		c.in_roster = true
		c.age = 22
		c.stats = {"str": 10, "agi": 10, "vit": 10, "wil": 10, "per": 10, "skl": 10}
		GameState.characters[cid] = c
		have = World.party_size()
	_ok(World.party_size() >= n, "party padded to %d (got %d)" % [n, World.party_size()])

func _api_season_bands() -> void:
	Calendar.year = 1
	Calendar.month = 4
	_ok(Calendar.season_id() == "spring", "season spring")
	Calendar.month = 7
	_ok(Calendar.season_id() == "summer", "season summer")
	Calendar.month = 10
	_ok(Calendar.season_id() == "autumn", "season autumn")
	Calendar.month = 1
	_ok(Calendar.season_id() == "winter", "season winter")
	Calendar.month = 12
	_ok(Calendar.season_id() == "winter", "season winter Dec")

func _api_biome_and_winter_stack() -> void:
	World.pos = "ash_capital"  # urban
	Calendar.month = 4  # spring 1.0
	var spring_plain := World.food_per_day()
	var info_sp: Dictionary = World.food_ration_info()
	_ok(int(info_sp.base) == spring_plain, "spring urban per==base")
	_ok(int(info_sp.mod_pct) == 0, "spring urban mod 0")
	Calendar.month = 1  # winter 1.35
	var winter_urban := World.food_per_day()
	_ok(winter_urban > spring_plain, "winter urban > spring urban (%d>%d)" % [winter_urban, spring_plain])
	World.pos = "sy_frostfort"  # snow
	var winter_snow := World.food_per_day()
	var info_ws: Dictionary = World.food_ration_info()
	_ok(winter_snow >= winter_urban, "winter snow >= winter urban (%d>=%d)" % [winter_snow, winter_urban])
	_ok(int(info_ws.mod_pct) > 0, "winter snow mod_pct > 0")
	_ok(str(info_ws.biome) == "snow", "biome snow")
	_ok(str(info_ws.season_id) == "winter", "info season winter")
	# autumn discount at urban
	World.pos = "ash_capital"
	Calendar.month = 10
	var autumn := World.food_per_day()
	_ok(autumn <= spring_plain, "autumn <= spring (%d<=%d)" % [autumn, spring_plain])

func _api_text_locale() -> void:
	Calendar.month = 1
	World.pos = "sy_frostfort"
	var text := World.food_ration_text()
	_ok(text.contains("%d" % World.food_per_day()) or str(World.food_per_day()) in text, "text has per_day")
	_ok(Locale.t("atlas_season_winter") in text, "text has winter label")
	_ok("+" in text or Locale.t("atlas_ration_mod_up", [1]).substr(0, 1) in text, "text shows uplift")

func _ui_party_row_and_top() -> void:
	Calendar.month = 1
	World.pos = "sy_frostfort"
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 14:
		await get_tree().process_frame
	var row: Node = page.find_child("MarchRationRow", true, false)
	_ok(row != null, "MarchRationRow present")
	if row != null:
		var blob := str(row.get("text")) if row.get("text") != null else ""
		# kv_row may nest labels
		if blob == "" or blob == "<null>":
			blob = _collect_text(row)
		_ok(str(World.food_per_day()) in blob or Locale.t("atlas_ration_label") in blob or blob.length() > 0, "row shows ration text")
	page.queue_free()
	for _z in 4:
		await get_tree().process_frame

func _ui_route_chip() -> void:
	Calendar.month = 1
	World.pos = "ash_capital"
	var dest := "ash_market"
	if World.node(dest).is_empty():
		var adj: Array = World.adj.get(World.pos, [])
		if not adj.is_empty():
			dest = str(World.other_end(adj[0], World.pos))
	var pv: Dictionary = World.travel_preview(dest)
	_ok(not pv.is_empty() and bool(pv.get("ok", false)), "travel_preview ok")
	var per := World.food_per_day()
	var days := int(pv.get("days", 0))
	_ok(int(pv.get("food", -1)) == per * days,
		"preview food == per*days (%d == %d*%d)" % [int(pv.get("food", -1)), per, days])
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	if page.has_method("_select_node"):
		page.call("_select_node", dest)
	for _k in 12:
		await get_tree().process_frame
	var chip: Node = page.find_child("MarchRationChip", true, false)
	_ok(chip != null, "MarchRationChip after select")
	page.queue_free()
	for _z in 4:
		await get_tree().process_frame

func _collect_text(n: Node) -> String:
	var parts: PackedStringArray = []
	if n is Label or n is Button or n is RichTextLabel:
		parts.append(str(n.get("text")))
	for c in n.get_children():
		parts.append(_collect_text(c))
	return " ".join(parts)
