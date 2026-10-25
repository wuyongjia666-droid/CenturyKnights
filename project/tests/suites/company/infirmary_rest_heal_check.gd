extends Node
## Infirmary paid rest/heal silver sink: gates, light clear, grave shorten, lasting refuse,
## recovery_months on wound, HP restore, save/load, named InnKnight_/InnRest UI.

const ANNEX_SCN := preload("res://scenes/hub/annex.tscn")

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_gates()
	_api_light_clear()
	_api_grave_shorten()
	_api_lasting_refuse()
	_api_recovery_months_on_wound()
	_api_save_load()
	await _ui_rest()
	if _fails.is_empty():
		print("INFIRMARY REST HEAL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL infirmary rest heal: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("医所休养", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.buildings["infirmary"] = 1
	for c in GameState.roster():
		c.injured = false
		c.hp = c.max_hp
		if typeof(c.blood_meta) == TYPE_DICTIONARY:
			c.blood_meta.erase("injury")


func _ally() -> CKCharacter:
	for c in GameState.roster():
		if not c.is_leader:
			return c
	return GameState.roster()[0] as CKCharacter


func _stamp_light(c: CKCharacter, months: int = 2) -> void:
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	c.blood_meta["injury"] = {
		"tier": "light", "months_left": months, "skl_applied": 0, "move": 0,
		"id": "bruise", "name": Locale.t("轻伤"),
	}
	c.injured = true
	c.hp = maxi(1, int(c.max_hp / 3))


func _stamp_grave(c: CKCharacter, months: int = 5) -> void:
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	c.blood_meta["injury"] = {
		"tier": "grave", "months_left": months, "skl_applied": 0, "move": 0,
		"id": "fracture", "name": Locale.t("重伤"),
	}
	c.injured = true
	c.hp = maxi(1, int(c.max_hp / 4))


func _api_gates() -> void:
	var c := _ally()
	GameState.buildings.erase("infirmary")
	_stamp_light(c)
	_ok(not bool(CKCastleServices.rest_heal(GameState, c.id).get("ok", false)), "refuse when unbuilt")
	GameState.buildings["infirmary"] = 1
	var cost := CKCastleServices.rest_cost(GameState)
	_ok(cost == 22, "lv1 rest cost %d want 22" % cost)
	GameState.buildings["infirmary"] = 3
	_ok(CKCastleServices.rest_cost(GameState) == 10, "lv3 cheaper")
	GameState.buildings["infirmary"] = 1
	GameState.silver = 0
	_ok(not bool(CKCastleServices.rest_heal(GameState, c.id).get("ok", false)), "refuse when broke")
	GameState.silver = 80000
	# healthy refuse
	if typeof(c.blood_meta) == TYPE_DICTIONARY:
		c.blood_meta.erase("injury")
	c.injured = false
	c.hp = c.max_hp
	_ok(not bool(CKCastleServices.rest_heal(GameState, c.id).get("ok", false)), "refuse healthy")


func _api_light_clear() -> void:
	var c := _ally()
	_stamp_light(c)
	var sil0 := GameState.silver
	var cost := CKCastleServices.rest_cost(GameState)
	var r: Dictionary = CKCastleServices.rest_heal(GameState, c.id)
	_ok(bool(r.get("ok", false)), "light rest ok: %s" % r.get("msg", ""))
	_ok(CKInjury.record(c).is_empty() and not c.injured, "light cleared")
	_ok(c.hp == c.max_hp, "HP restored")
	_ok(GameState.silver == sil0 - cost, "silver sunk %d" % cost)


func _api_grave_shorten() -> void:
	var c := _ally()
	GameState.buildings["infirmary"] = 2
	_stamp_grave(c, 5)
	var left0 := int(CKInjury.record(c).get("months_left", 0))
	var r: Dictionary = CKCastleServices.rest_heal(GameState, c.id)
	_ok(bool(r.get("ok", false)), "grave rest ok")
	var left1 := int(CKInjury.record(c).get("months_left", 0))
	# lv2 cuts 2 → 5-2=3 still injured
	_ok(left1 == left0 - 2, "grave shortened %d→%d" % [left0, left1])
	_ok(c.injured and c.hp == c.max_hp, "grave still injured, HP full")
	# rest again until clear
	r = CKCastleServices.rest_heal(GameState, c.id)
	_ok(bool(r.get("ok", false)), "grave rest 2")
	r = CKCastleServices.rest_heal(GameState, c.id)
	_ok(bool(r.get("ok", false)), "grave rest 3 clears")
	_ok(CKInjury.record(c).is_empty() and not c.injured, "grave cleared")
	GameState.buildings["infirmary"] = 1


func _api_lasting_refuse() -> void:
	var c := _ally()
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	c.blood_meta["injury"] = {
		"tier": "lasting", "months_left": 0, "skl_applied": 0, "move": -1,
		"id": "limp", "name": Locale.t("跛足"),
	}
	c.injured = true
	c.hp = c.max_hp
	var r: Dictionary = CKCastleServices.rest_heal(GameState, c.id)
	_ok(not bool(r.get("ok", false)), "lasting refused")
	_ok(not CKInjury.record(c).is_empty(), "lasting still present")
	if typeof(c.blood_meta) == TYPE_DICTIONARY:
		c.blood_meta.erase("injury")
	c.injured = false


func _api_recovery_months_on_wound() -> void:
	GameState.buildings.erase("infirmary")
	_ok(CKCastleServices.recovery_months(GameState, 4) == 4, "unbuilt recovery flat")
	GameState.buildings["infirmary"] = 2
	_ok(CKCastleServices.recovery_months(GameState, 4) == 2, "lv2 recovery −2")
	# apply wound with infirmary: months shortened
	CKInjury.set_mode("casual")
	var c := _ally()
	if typeof(c.blood_meta) == TYPE_DICTIONARY:
		c.blood_meta.erase("injury")
	c.injured = false
	var got: Dictionary = {}
	for seed_i in range(1, 120):
		GameState.new_game("医所休养", "灰旗", GameState.crest_color)
		GameState.buildings["infirmary"] = 2
		CKInjury.set_mode("casual")
		c = _ally()
		got = CKInjury.resolve(c, 4, 0, seed_i)
		if str(got.get("outcome", "")) == "grave":
			break
	_ok(str(got.get("outcome", "")) == "grave", "found grave wound for recovery check")
	var months := int(CKInjury.record(c).get("months_left", 0))
	# base grave 3–6, recovery −2 → 1–4 (floored at 1)
	_ok(months >= 1 and months <= 4, "grave months with lv2 infirmary %d" % months)
	GameState.silver = 80000
	GameState.buildings["infirmary"] = 1


func _api_save_load() -> void:
	var c := _ally()
	_stamp_light(c)
	_ok(bool(CKCastleServices.rest_heal(GameState, c.id).get("ok", false)), "rest before save")
	_ok(GameState.save_game(), "save")
	_stamp_light(c)  # dirty
	_ok(GameState.load_game(), "load")
	c = GameState.characters.get(c.id)
	_ok(c != null and CKInjury.record(c).is_empty() and c.hp == c.max_hp, "healed state restored")


func _ui_rest() -> void:
	GameState.buildings["infirmary"] = 1
	GameState.silver = 80000
	var c := _ally()
	_stamp_light(c)
	var page = ANNEX_SCN.instantiate()
	page.set_meta("annex", "infirmary")
	add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	_ok(page.id == "infirmary", "page id infirmary")
	var slot := page.find_child("InnKnight_" + c.id, true, false) as Button
	_ok(slot != null, "UI InnKnight_%s" % c.id)
	var rest := page.find_child("InnRest", true, false) as Button
	_ok(rest != null and not rest.disabled, "UI InnRest enabled")
	var up := page.find_child("Upgrade", true, false) as Button
	_ok(up != null, "UI Upgrade present")
	var link := page.find_child("Link", true, false) as Button
	_ok(link != null and not link.disabled, "UI Link to shrine enabled")
	var sil0 := GameState.silver
	if rest:
		rest.emit_signal("pressed")
		for _k in 8:
			await get_tree().process_frame
	_ok(CKInjury.record(c).is_empty() and not c.injured, "UI cleared light")
	_ok(c.hp == c.max_hp, "UI HP full")
	_ok(GameState.silver < sil0, "UI sank silver")
	# empty state after heal
	rest = page.find_child("InnRest", true, false) as Button
	_ok(rest != null and rest.disabled, "UI InnRest disabled when none need rest")
	_ok(page.find_child("Empty", true, false) != null, "UI Empty after heal")
	page.queue_free()
	await get_tree().process_frame
