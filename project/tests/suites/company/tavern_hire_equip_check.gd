extends Node
## Store/economy: tavern Hire0 → roster → armory Equip_ on hire,
## cargo_cap grows with party, broke-hire gate, save/load.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const WEAPON := "ashbanner_sword_1"
const CARGO_G := "ashsteel"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_hire_and_cargo()
	_api_equip_hire()
	_api_save_load()
	await _ui_hire_equip()
	if _fails.is_empty():
		print("TAVERN HIRE EQUIP PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL tavern hire equip: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("酒馆环", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	World.pos = CAP
	World.arrive(CAP)
	World.armory.clear()
	World.gear.clear()
	World.cargo.clear()

func _api_hire_and_cargo() -> void:
	var lst: Array = World.city_recruits(CAP)
	_ok(lst.size() >= 1, "tavern faces >=1 (got %d)" % lst.size())
	if lst.is_empty():
		return
	var cap0 := World.cargo_cap()
	var party0 := World.party_size()
	var face: CKCharacter = lst[0]
	var cost := World.hire_cost(face)
	# broke gate
	var save_s := GameState.silver
	GameState.silver = maxi(0, cost - 1)
	var broke: Dictionary = World.hire(CAP, 0)
	_ok(not bool(broke.get("ok", false)), "hire rejected when silver short")
	GameState.silver = save_s
	# fill cargo to the rim so one more ashsteel would fail
	var room := World.cargo_cap() - World.cargo_used()
	if room > 0:
		World._add_good(CARGO_G, room)
	_ok(World.cargo_used() == World.cargo_cap(), "cargo packed to cap %d" % World.cargo_cap())
	if World.stock(CAP, CARGO_G) < 2:
		World.market[CAP][CARGO_G] = 8
	var blocked: Dictionary = World.market_buy(CAP, CARGO_G, 1)
	_ok(not bool(blocked.get("ok", false)), "market buy blocked at full cargo")
	# hire → party + cargo_cap bump
	lst = World.city_recruits(CAP)
	face = lst[0]
	cost = World.hire_cost(face)
	var silver0 := GameState.silver
	var n0 := lst.size()
	var r: Dictionary = World.hire(CAP, 0)
	_ok(bool(r.get("ok", false)), "hire ok: %s" % r.get("msg", ""))
	var hid := str(r.get("id", ""))
	_ok(hid != "" and GameState.characters.has(hid), "hire returns roster id")
	_ok(GameState.silver == silver0 - cost, "hire spent %d silver" % cost)
	_ok(World.city_recruits(CAP).size() == n0 - 1, "face removed from tavern")
	_ok(World.party_size() == party0 + 1, "party_size +1")
	_ok(World.cargo_cap() > cap0, "cargo_cap grew %d -> %d" % [cap0, World.cargo_cap()])
	# now one more unit of cargo fits
	var opened: Dictionary = World.market_buy(CAP, CARGO_G, 1)
	_ok(bool(opened.get("ok", false)), "buy after hire uses new cargo room: %s" % opened.get("msg", ""))

func _api_equip_hire() -> void:
	# pick a non-leader roster member
	var leader: CKCharacter = GameState.get_leader()
	var hired: CKCharacter = null
	for c in GameState.roster():
		if c.id != leader.id:
			hired = c
			break
	_ok(hired != null, "have hired roster member")
	if hired == null:
		return
	hired.job_id = "squire"
	World.armory[WEAPON] = int(World.armory.get(WEAPON, 0)) + 1
	var atk0 := hired.derived_atk()
	var eq: Dictionary = World.equip(hired.id, WEAPON)
	_ok(bool(eq.get("ok", false)), "equip hire: %s" % eq.get("msg", ""))
	_ok(World.equipped(hired, "weapon") == WEAPON, "hire weapon slot")
	_ok(hired.derived_atk() > atk0, "hire atk rose %d -> %d" % [atk0, hired.derived_atk()])
	World.unequip(hired.id, "weapon")
	_ok(World.equipped(hired, "weapon") != WEAPON, "unequip hire")

func _api_save_load() -> void:
	var leader: CKCharacter = GameState.get_leader()
	var hired: CKCharacter = null
	for c in GameState.roster():
		if c.id != leader.id:
			hired = c
			break
	if hired == null:
		_ok(false, "save/load needs hire")
		return
	hired.job_id = "squire"
	World.armory[WEAPON] = maxi(1, int(World.armory.get(WEAPON, 0)))
	World.equip(hired.id, WEAPON)
	var hid := hired.id
	_ok(GameState.save_game(), "save_game")
	World.armory.clear()
	hired.weapon_id = ""
	_ok(GameState.load_game(), "load_game")
	hired = GameState.characters.get(hid)
	_ok(hired != null and hired.in_roster, "hire survived save")
	_ok(World.equipped(hired, "weapon") == WEAPON, "hire weapon round-trip")

func _ui_hire_equip() -> void:
	_setup()
	GameState.silver = 80000
	World.armory[WEAPON] = 1
	var city: Control = CITY_SCN.instantiate()
	add_child(city)
	for _i in 8:
		await get_tree().process_frame
	if not city.has_method("_set_tab"):
		_ok(false, "city.gd failed to load")
		city.queue_free()
		return
	city.call("_set_tab", "tavern")
	for _j in 5:
		await get_tree().process_frame
	var roster0 := GameState.roster().size()
	var hire0 := city.find_child("Hire0", true, false) as Button
	_ok(hire0 != null and not hire0.disabled, "UI Hire0 ready")
	if hire0 and not hire0.disabled:
		hire0.pressed.emit()
		for _k in 5:
			await get_tree().process_frame
	_ok(GameState.roster().size() == roster0 + 1, "UI hire grew roster")
	var hired_id := str(city.get("_sel_char"))
	_ok(hired_id != "" and hired_id != GameState.get_leader().id, "UI selected hired char")
	var hired: CKCharacter = GameState.characters.get(hired_id)
	if hired:
		hired.job_id = "squire"
	city.call("_set_tab", "armory")
	for _n in 4:
		await get_tree().process_frame
	city.set("_sel_char", hired_id)
	city.call("_render_tab")
	for _p in 4:
		await get_tree().process_frame
	var crow := city.find_child("Char_" + hired_id, true, false) as Button
	_ok(crow != null, "UI Char_%s row" % hired_id)
	if crow:
		crow.pressed.emit()
		await get_tree().process_frame
	var atk0 := 0
	if hired:
		atk0 = hired.derived_atk()
	var eqb := city.find_child("Equip_" + WEAPON, true, false) as Button
	_ok(eqb != null and not eqb.disabled, "UI Equip_%s on hire" % WEAPON)
	if eqb and not eqb.disabled:
		eqb.pressed.emit()
		for _q in 4:
			await get_tree().process_frame
	if hired:
		hired = GameState.characters.get(hired_id)
		_ok(World.equipped(hired, "weapon") == WEAPON, "UI equip on hire applied")
		_ok(hired.derived_atk() >= atk0, "UI hire atk held/raised")
	city.queue_free()
	await get_tree().process_frame
