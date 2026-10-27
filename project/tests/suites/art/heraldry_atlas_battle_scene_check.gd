extends Node
## Fat heraldry wave-2 E2E: remaining crest surfaces across atlas travel/camp/
## encounter/aftermath, city, market, lineage_rite, title_promote (muster),
## estates field book, and battle HUD — assert Field child field_route ownership.
## Desk + mobile. No EmptyHost theater; no baseline raises.

const ATLAS := "res://scenes/hub/atlas_view.tscn"
const CITY := "res://scenes/hub/city.tscn"
const MARKET := "res://scenes/hub/market.tscn"
const RITE := "res://scenes/hub/lineage_rite.tscn"
const TITLE := "res://scenes/hub/title_promote.tscn"
const ESTATES := "res://scenes/hub/estates.tscn"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY ATLAS BATTLE SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry atlas battle scene: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame


func _route(n: Node, want: String) -> bool:
	return n != null and str(n.get_meta("field_route", "")) == want


func _boot() -> void:
	GameState.new_game("图战徽深刀", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 9000
	GameState.food = 40
	GameState.iron = 40
	GameState.morale = 80
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	GameState.set_meta("city_id", "ash_capital")
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
		lead.gender = "m"
		if not (lead.id in GameState.deploy_ids):
			GameState.deploy_ids = [lead.id]
	# Rite heir.
	var kid := CKCharacter.new()
	kid.id = "atlas_rite_heir"
	kid.name = "图嗣"
	kid.age = 16
	kid.gender = "m"
	kid.family_id = str(lead.family_id) if lead != null else ""
	kid.is_child = true
	kid.alive = true
	kid.in_roster = false
	kid.rank = "knight"
	kid.is_leader = false
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "martial"


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	return page


func _assert_atlas(tag: String) -> void:
	var nid := World.nation_of("ash_capital")
	if nid == "":
		nid = "ashbanner"
	_boot()
	var page := _open(ATLAS)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)

	# Travel HUD strip on atlas shell.
	var travel := page.find_child("TravelCrestStrip", true, false)
	_ok(_route(travel, "travel_strip"), "%s/atlas travel_strip" % tag)
	if travel != null:
		_ok(_route(travel.find_child("CastleArms", true, false), "strip_company"), "%s/atlas travel strip_company" % tag)
		var terr := travel.find_child("TerritoryArms", true, false)
		if nid != "":
			_ok(_route(terr, "travel_territory"), "%s/atlas travel_territory" % tag)

	# Halt modal travel strip.
	page.call("_show_travel_halt_modal")
	await _settle(8)
	var halt := page.find_child("TravelHaltModal", true, false)
	_ok(halt != null, "%s/atlas TravelHaltModal" % tag)
	var halt_strip := (halt if halt else page).find_child("TravelCrestStrip", true, false)
	_ok(_route(halt_strip, "travel_strip"), "%s/atlas halt travel_strip" % tag)
	if halt_strip != null:
		_ok(_route(halt_strip.find_child("CastleArms", true, false), "strip_company"), "%s/atlas halt strip_company" % tag)
		var ht := halt_strip.find_child("TerritoryArms", true, false)
		if nid != "":
			_ok(_route(ht, "travel_territory"), "%s/atlas halt travel_territory" % tag)
	page.call("_clear_modal")
	await _settle(2)

	# Camp night event.
	World.pending_event = {}
	World.cancel_travel()
	World.pending_event = {}
	World.travel = {}
	World.encounter = {}
	page.call("_show_event_modal", {
		"id": "camp_night",
		"kind": "camp",
		"title": "夜营",
		"text": "队伍扎营歇脚。",
		"b": "ash_capital",
		"options": [{"label": "休息", "fx": {}}],
	})
	await _settle(8)
	var camp_modal := page.find_child("EventModal", true, false)
	_ok(camp_modal != null, "%s/atlas EventModal camp" % tag)
	var camp := page.find_child("CampCrestStrip", true, false)
	_ok(_route(camp, "camp_strip"), "%s/atlas camp_strip" % tag)
	if camp != null:
		_ok(_route(camp.find_child("CastleArms", true, false), "strip_company"), "%s/atlas camp strip_company" % tag)
		var ct := camp.find_child("TerritoryArms", true, false)
		if nid != "":
			_ok(_route(ct, "camp_territory"), "%s/atlas camp_territory" % tag)
	page.call("_clear_modal")
	await _settle(2)

	# Encounter modal.
	World.encounter = {}
	page.call("_show_encounter_modal", {
		"nation": nid,
		"label": "遭遇",
		"node": "ash_capital",
		"danger": 2,
		"map": {"enemy_templates": ["bandit"]},
	})
	await _settle(8)
	var enc_modal := page.find_child("EncounterModal", true, false)
	_ok(enc_modal != null, "%s/atlas EncounterModal" % tag)
	var enc := page.find_child("EncounterCrestStrip", true, false)
	_ok(_route(enc, "encounter_strip"), "%s/atlas encounter_strip" % tag)
	if enc != null:
		_ok(_route(enc.find_child("CastleArms", true, false), "strip_company"), "%s/atlas encounter strip_company" % tag)
		_ok(_route(enc.find_child("FoeArms", true, false), "encounter_foe"), "%s/atlas encounter_foe" % tag)
	page.call("_clear_modal")
	await _settle(2)

	# Battle aftermath (async — press continue after asserts).
	page.call("_show_battle_aftermath_modal", {
		"win": true,
		"nation": nid,
		"title": "捷报",
		"lines": ["旗开得胜"],
		"silver_now": GameState.silver,
		"silver_delta": 10,
	})
	await _settle(10)
	var aft := page.find_child("AftermathCrestStrip", true, false)
	_ok(_route(aft, "aftermath_strip"), "%s/atlas aftermath_strip" % tag)
	if aft != null:
		_ok(_route(aft.find_child("CastleArms", true, false), "strip_company"), "%s/atlas aftermath strip_company" % tag)
		_ok(_route(aft.find_child("FoeArms", true, false), "aftermath_foe"), "%s/atlas aftermath_foe" % tag)
	var cont := page.find_child("BattleAftermathContinue", true, false) as Button
	if cont:
		cont.emit_signal("pressed")
		await _settle(4)

	page.queue_free()
	await _settle(2)


func _assert_city(tag: String) -> void:
	_boot()
	var page := _open(CITY)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("CityCrestStrip", true, false)
	_ok(_route(strip, "city_strip"), "%s/city city_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/city strip_company" % tag)
		var nat := strip.find_child("CityNationArms", true, false)
		_ok(_route(nat, "city_nation"), "%s/city city_nation" % tag)
	page.queue_free()
	await _settle(2)


func _assert_market(tag: String) -> void:
	_boot()
	var page := _open(MARKET)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var city := page.find_child("CityCrestStrip", true, false)
	_ok(_route(city, "city_strip"), "%s/market city_strip" % tag)
	if city != null:
		_ok(_route(city.find_child("CityNationArms", true, false), "city_nation"), "%s/market city_nation" % tag)
	var mkt := page.find_child("MarketCrestStrip", true, false)
	_ok(_route(mkt, "market_strip"), "%s/market market_strip" % tag)
	if mkt != null:
		_ok(_route(mkt.find_child("CastleArms", true, false), "strip_company"), "%s/market strip_company" % tag)
		_ok(_route(mkt.find_child("MarketBanner", true, false), "market_banner"), "%s/market market_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_rite(tag: String) -> void:
	_boot()
	var kid: CKCharacter = GameState.characters.get("atlas_rite_heir")
	var page := _open(RITE)
	await _settle(12)
	if kid != null and page.has_method("_select"):
		page.call("_select", kid)
		await _settle(8)
	var strip := page.find_child("RiteCrestStrip", true, false)
	_ok(_route(strip, "rite_strip"), "%s/rite rite_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/rite strip_company" % tag)
		_ok(_route(strip.find_child("LeaderArms", true, false), "rite_leader"), "%s/rite rite_leader" % tag)
	page.queue_free()
	await _settle(2)


func _assert_title(tag: String) -> void:
	_boot()
	var page := _open(TITLE)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	var strip := page.find_child("MusterCrestStrip", true, false)
	_ok(_route(strip, "muster_strip"), "%s/title muster_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/title strip_company" % tag)
		_ok(_route(strip.find_child("LeaderArms", true, false), "muster_leader"), "%s/title muster_leader" % tag)
	page.queue_free()
	await _settle(2)


func _assert_estates_field(tag: String) -> void:
	_boot()
	var page := _open(ESTATES)
	await _settle(12)
	if page.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		page.call("apply_mobile_layout")
		await _settle(6)
	if page.has_method("open_field_book"):
		page.call("open_field_book")
		await _settle(8)
	var strip := page.find_child("FieldCrestStrip", true, false)
	_ok(_route(strip, "field_strip"), "%s/estates field_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s/estates strip_company" % tag)
		_ok(_route(strip.find_child("FieldBanner", true, false), "field_banner"), "%s/estates field_banner" % tag)
	page.queue_free()
	await _settle(2)


func _assert_battle_hud(tag: String) -> void:
	_boot()
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var root := Control.new()
	root.name = "BattleHudHost"
	root.size = Vector2(1280, 720)
	get_tree().root.add_child(root)
	await _settle(2)
	var mobile := tag.begins_with("mob")
	var strip: Control = CKHeraldryField.place_battle_hud_crest_strips(
		root, "ashbanner", Vector2(1280, 720), {"top": 24.0} if mobile else {}, mobile, false)
	_ok(_route(strip, "battle_hud_strip"), "%s/hud battle_hud_strip" % tag)
	if strip != null:
		_ok(_route(strip.find_child("PlayerArms", true, false), "battle_hud_player"), "%s/hud battle_hud_player" % tag)
		_ok(_route(strip.find_child("EnemyArms", true, false), "battle_hud_enemy"), "%s/hud battle_hud_enemy" % tag)
	# sync path (Field owns lifecycle)
	CKHeraldryField.sync_battle_hud_crests(root)
	await _settle(4)
	var synced := root.find_child("BattleHudCrestStrip", true, false)
	_ok(_route(synced, "battle_hud_strip"), "%s/hud sync battle_hud_strip" % tag)
	if synced != null:
		_ok(_route(synced.find_child("PlayerArms", true, false), "battle_hud_player"), "%s/hud sync player" % tag)
		_ok(_route(synced.find_child("EnemyArms", true, false), "battle_hud_enemy"), "%s/hud sync enemy" % tag)
	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")
	root.queue_free()
	await _settle(2)


func _run_pass(tag: String) -> void:
	await _assert_atlas(tag)
	await _assert_city(tag)
	await _assert_market(tag)
	await _assert_rite(tag)
	await _assert_title(tag)
	await _assert_estates_field(tag)
	await _assert_battle_hud(tag)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	await _run_pass("desk")


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	await _run_pass("mob")
	OS.set_environment("CK_FORCE_MOBILE", "")


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	for route in [
		"travel_territory", "camp_territory", "encounter_foe", "aftermath_foe",
		"city_nation", "nation_arms", "rite_leader", "muster_leader",
		"field_banner", "battle_hud_player", "battle_hud_enemy",
		"market_banner", "hourglass_banner", "blood_banner", "skill_banner",
		"roster_banner", "gazette_nation", "strip_company",
	]:
		# Cloth-migrated routes stamp via _cloth_beside arg; others still set_meta.
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
	var hubs := {
		"atlas_view": "res://scripts/hub/atlas_view.gd",
		"city": "res://scripts/hub/city.gd",
		"market": "res://scripts/hub/market.gd",
		"lineage_rite": "res://scripts/hub/lineage_rite.gd",
		"title_promote": "res://scripts/hub/title_promote.gd",
		"estates": "res://scripts/hub/estates.gd",
		"battle_controller": "res://scripts/battle/battle_controller.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
