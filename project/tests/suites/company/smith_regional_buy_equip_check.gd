extends Node
## AC-4 smith loop: regional stock isolation, buy/forge, signature gates,
## equip→atk+skill, unequip strips gear skill, save/load, UI Buy/Forge/Equip.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const REGIONAL := "ashbanner_sword_1"
const SIG1 := "ash_capital_sig1"
const SIG2 := "ash_capital_sig2"
const OTHER_CITY := "sy_capital"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_regional_stock()
	_api_buy_and_stats()
	_api_forge_cheaper()
	_api_signature_gates()
	_api_equip_skill_sync()
	_api_save_load()
	await _ui_buy_forge_equip()
	if _fails.is_empty():
		print("SMITH REGIONAL BUY EQUIP PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL smith regional: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("铁匠环", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 50000
	GameState.iron = 40  # store good for forge mats
	World.armory.clear()
	World.gear.clear()
	World.pos = CAP
	World.arrive(CAP)
	World.rep_city[CAP] = 0
	World.done_sig.clear()
	GameState.settings.erase("smith_revealed")

func _api_regional_stock() -> void:
	var st: Array = World.smith_stock(CAP)
	_ok(not st.is_empty(), "ash_capital smith stock non-empty")
	var ids: Array = []
	var foreign := 0
	for e in st:
		var it: Dictionary = e.item
		ids.append(str(it.id))
		if str(it.nation) != "ashbanner":
			foreign += 1
	_ok(foreign == 0, "regional stock is ashbanner-only (foreign=%d)" % foreign)
	_ok(ids.has(REGIONAL), "regional sword in stock")
	_ok(ids.has(SIG1) and ids.has(SIG2), "city signatures listed")
	# other-nation capital must not sell ashbanner line
	World.pos = OTHER_CITY
	World.arrive(OTHER_CITY)
	var other: Array = World.smith_stock(OTHER_CITY)
	var leak := 0
	for e2 in other:
		if str(e2.item.get("nation", "")) == "ashbanner":
			leak += 1
	_ok(leak == 0, "shuoying capital has no ashbanner stock (leak=%d)" % leak)
	var reject: Dictionary = World.buy_item(OTHER_CITY, REGIONAL)
	_ok(not bool(reject.get("ok", false)), "buy ash sword at foreign smith rejected")
	World.pos = CAP
	World.arrive(CAP)

func _api_buy_and_stats() -> void:
	World.armory.clear()
	var leader: CKCharacter = GameState.get_leader()
	var atk0 := leader.derived_atk()
	var cost := World.smith_price(CAP, REGIONAL)
	var silver0 := GameState.silver
	var r: Dictionary = World.buy_item(CAP, REGIONAL)
	_ok(bool(r.get("ok", false)), "buy regional: %s" % r.get("msg", ""))
	_ok(int(World.armory.get(REGIONAL, 0)) == 1, "armory +1 after buy")
	_ok(GameState.silver == silver0 - cost, "silver spent %d" % cost)
	var eq: Dictionary = World.equip(leader.id, REGIONAL)
	_ok(bool(eq.get("ok", false)), "equip regional: %s" % eq.get("msg", ""))
	_ok(World.equipped(leader, "weapon") == REGIONAL, "weapon slot set")
	_ok(leader.derived_atk() > atk0, "atk rose %d -> %d" % [atk0, leader.derived_atk()])
	World.unequip(leader.id, "weapon")
	_ok(int(World.armory.get(REGIONAL, 0)) == 1, "unequip returns to armory")

func _api_forge_cheaper() -> void:
	World.armory.erase(REGIONAL)
	var buy_cost := World.smith_price(CAP, REGIONAL)
	var forge_cost := int(World.item(REGIONAL).get("forge_silver", 0))
	_ok(forge_cost < buy_cost, "forge %d cheaper than buy %d" % [forge_cost, buy_cost])
	# ensure mats
	GameState.iron = maxi(GameState.iron, 10)
	var iron0 := GameState.iron
	# have_good("iron") uses hub store / goods — seed via World
	if World.have_good("iron") < 2:
		World._add_good("iron", 2 - World.have_good("iron"))
	var have0 := World.have_good("iron")
	var silver0 := GameState.silver
	var r: Dictionary = World.forge_item(CAP, REGIONAL)
	_ok(bool(r.get("ok", false)), "forge regional: %s" % r.get("msg", ""))
	_ok(int(World.armory.get(REGIONAL, 0)) >= 1, "forge fills armory")
	_ok(GameState.silver == silver0 - forge_cost, "forge spent labor only")
	_ok(World.have_good("iron") == have0 - 2, "forge consumed iron mats")
	# broke forge
	var save_s := GameState.silver
	GameState.silver = 0
	if World.have_good("iron") < 2:
		World._add_good("iron", 2)
	var broke: Dictionary = World.forge_item(CAP, REGIONAL)
	_ok(not bool(broke.get("ok", false)), "forge rejected when broke")
	GameState.silver = save_s

func _api_signature_gates() -> void:
	World.rep_city[CAP] = 0
	World.done_sig.clear()
	var locked: Dictionary = {}
	for e in World.smith_stock(CAP):
		if str(e.item.id) == SIG1:
			locked = e
			break
	_ok(not locked.is_empty() and not bool(locked.get("available", true)), "sig1 locked at rep 0")
	World.rep_city[CAP] = 12
	var open1: Dictionary = {}
	for e2 in World.smith_stock(CAP):
		if str(e2.item.id) == SIG1:
			open1 = e2
			break
	_ok(bool(open1.get("available", false)), "sig1 buyable at rep 12 (AC-4)")
	var leg: Dictionary = {}
	for e3 in World.smith_stock(CAP):
		if str(e3.item.id) == SIG2:
			leg = e3
			break
	_ok(not bool(leg.get("available", true)), "legendary locked without honor quest")
	var sq := str(World.node(CAP).get("sig_quest", {}).get("id", ""))
	if sq != "":
		World.done_sig[sq] = true
	World.rep_city[CAP] = 55
	var leg2: Dictionary = {}
	for e4 in World.smith_stock(CAP):
		if str(e4.item.id) == SIG2:
			leg2 = e4
			break
	_ok(bool(leg2.get("available", false)), "legendary open after honor + trust")

func _api_equip_skill_sync() -> void:
	var leader: CKCharacter = GameState.get_leader()
	# force sig1 into armory
	World.armory[SIG1] = int(World.armory.get(SIG1, 0)) + 1
	World.rep_city[CAP] = 20
	var sk := str(World.item(SIG1).get("skill", ""))
	_ok(sk != "", "sig1 has battle skill %s" % sk)
	# strip any prior
	var stripped: Array = []
	for s in leader.skills:
		if str(s) != sk:
			stripped.append(s)
	leader.skills = stripped
	var r: Dictionary = World.equip(leader.id, SIG1)
	_ok(bool(r.get("ok", false)), "equip sig1")
	_ok(sk in leader.skills, "equip grants gear skill")
	World.unequip(leader.id, "weapon")
	_ok(sk not in leader.skills, "unequip strips gear skill (no leak)")

func _api_save_load() -> void:
	var leader: CKCharacter = GameState.get_leader()
	World.armory.clear()
	World.armory[REGIONAL] = 1
	World.equip(leader.id, REGIONAL)
	var atk := leader.derived_atk()
	_ok(GameState.save_game(), "save_game")
	World.armory.clear()
	leader.weapon_id = ""
	World.gear.clear()
	_ok(GameState.load_game(), "load_game")
	leader = GameState.get_leader()
	_ok(World.equipped(leader, "weapon") == REGIONAL, "weapon round-trip")
	_ok(leader.derived_atk() == atk, "atk round-trip %d" % atk)

func _ui_buy_forge_equip() -> void:
	_setup()
	World.rep_city[CAP] = 20
	GameState.silver = 50000
	if World.have_good("iron") < 4:
		World._add_good("iron", 4 - World.have_good("iron"))
	# mark reveals so overlay does not block
	for e in World.smith_stock(CAP):
		if int(e.get("signature", 0)) >= 1:
			World.mark_smith_revealed(str(e.item.id))
	var city: Control = CITY_SCN.instantiate()
	add_child(city)
	for _i in 6:
		await get_tree().process_frame
	if not city.has_method("_set_tab"):
		_ok(false, "city.gd failed to load (no _set_tab)")
		city.queue_free()
		return
	city.call("_set_tab", "smith")
	for _j in 4:
		await get_tree().process_frame
	var skip := city.find_child("SmithRevealSkip", true, false) as Button
	if skip:
		skip.pressed.emit()
		await get_tree().process_frame
	# select regional row
	var row := city.find_child("Item_" + REGIONAL, true, false) as Button
	_ok(row != null, "UI Item_%s row" % REGIONAL)
	if row:
		row.pressed.emit()
		await get_tree().process_frame
	var arm0 := int(World.armory.get(REGIONAL, 0))
	var buy := city.find_child("BuyItem", true, false) as Button
	_ok(buy != null and not buy.disabled, "UI BuyItem ready")
	if buy and not buy.disabled:
		buy.pressed.emit()
		await get_tree().process_frame
	_ok(int(World.armory.get(REGIONAL, 0)) == arm0 + 1, "UI buy mutates armory")
	# forge another
	var forge := city.find_child("ForgeItem", true, false) as Button
	_ok(forge != null, "UI ForgeItem present")
	if forge and not forge.disabled:
		var a1 := int(World.armory.get(REGIONAL, 0))
		forge.pressed.emit()
		await get_tree().process_frame
		_ok(int(World.armory.get(REGIONAL, 0)) == a1 + 1, "UI forge mutates armory")
	else:
		_ok(false, "UI ForgeItem disabled unexpectedly")
	# armory equip
	city.call("_set_tab", "armory")
	await get_tree().process_frame
	var leader: CKCharacter = GameState.get_leader()
	city.set("_sel_char", leader.id)
	city.call("_render_tab")
	await get_tree().process_frame
	var atk0 := leader.derived_atk()
	var eqb := city.find_child("Equip_" + REGIONAL, true, false) as Button
	_ok(eqb != null and not eqb.disabled, "UI Equip_%s" % REGIONAL)
	if eqb and not eqb.disabled:
		eqb.pressed.emit()
		await get_tree().process_frame
	_ok(World.equipped(leader, "weapon") == REGIONAL, "UI equip applied")
	_ok(leader.derived_atk() >= atk0, "UI equip atk held/raised")
	var ub := city.find_child("Unequip_weapon", true, false) as Button
	_ok(ub != null and not ub.disabled, "UI Unequip_weapon")
	if ub and not ub.disabled:
		ub.pressed.emit()
		await get_tree().process_frame
	_ok(World.equipped(leader, "weapon") != REGIONAL, "UI unequip cleared weapon")
	city.queue_free()
	await get_tree().process_frame
