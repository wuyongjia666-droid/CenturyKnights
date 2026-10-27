extends Node
## Fat heraldry E2E: open real hub UIs and assert Field place_*/attach_* crest
## nodes exist with field_route ownership across tavern/hire, castle view +
## panorama lineage, board offers, genealogy wall, marriage + succession strips,
## and deploy muster. Desk + mobile. No EmptyHost theater; no baseline raises.

const TAVERN := "res://scenes/hub/tavern.tscn"
const CASTLE_VIEW := "res://scenes/hub/castle_view.tscn"
const QUESTS := "res://scenes/hub/quests.tscn"
const LINEAGE := "res://scenes/hub/lineage_view.tscn"
const MARRIAGE := "res://scenes/hub/marriage.tscn"
const INHERIT := "res://scenes/hub/inheritance.tscn"
const DEPLOY := "res://scenes/hub/deploy.tscn"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_source_contracts()
	if _fails.is_empty():
		print("HERALDRY PLACE SCENE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry place scene: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("场徽深刀", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 9000
	GameState.food = 40
	GameState.iron = 40
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
		lead.gender = "m"
		if not (lead.id in GameState.deploy_ids):
			GameState.deploy_ids = [lead.id]
	# Tavern hire pool: family + familyless.
	var kin := CKCharacter.new()
	kin.id = "place_kin"
	kin.name = "族聘"
	kin.age = 24
	kin.alive = true
	kin.in_roster = false
	kin.family_id = str(lead.family_id) if lead != null else ""
	kin.job_id = "light_inf"
	kin.rank = "knight"
	var loner := CKCharacter.new()
	loner.id = "place_loner"
	loner.name = "客刃"
	loner.age = 22
	loner.alive = true
	loner.in_roster = false
	loner.family_id = ""
	loner.job_id = "hunter"
	loner.rank = "knight"
	GameState.tavern_candidates = [kin, loner]
	# Deploy loner so muster/slot Field plates show 旗徽 too.
	var dep := CKCharacter.new()
	dep.id = "place_dep"
	dep.name = "散卒"
	dep.age = 23
	dep.alive = true
	dep.in_roster = true
	dep.is_leader = false
	dep.family_id = ""
	dep.job_id = "light_inf"
	dep.rank = "knight"
	dep.gender = "m"
	GameState.characters[dep.id] = dep
	# Succession heir.
	var kid := CKCharacter.new()
	kid.id = "place_heir"
	kid.name = "嗣位子"
	kid.age = 14
	kid.gender = "m"
	kid.family_id = str(lead.family_id) if lead != null else ""
	kid.is_child = true
	kid.alive = true
	kid.in_roster = false
	kid.rank = "knight"
	kid.is_leader = false
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "martial"
	# Marriage pool.
	GameState.reputation["ashland"] = 90
	GameState.refresh_marriage_candidates("", lead)


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	return page


func _route(n: Node, want: String) -> bool:
	return n != null and str(n.get_meta("field_route", "")) == want


func _assert_tavern(page: Node, where: String) -> void:
	var strip := page.find_child("TavernCrestStrip", true, false)
	_ok(_route(strip, "tavern_strip"), "%s tavern_strip" % where)
	if strip != null:
		var co := strip.find_child("CastleArms", true, false)
		_ok(_route(co, "strip_company"), "%s tavern strip_company" % where)
		var focus := strip.find_child("HireFocusArms", true, false)
		_ok(_route(focus, "tavern_focus"), "%s tavern_focus" % where)
		var bn := strip.find_child("TavernBanner", true, false)
		_ok(_route(bn, "tavern_banner"), "%s tavern_banner" % where)
	var hires: Array = []
	_collect(page, "HireArms", hires)
	_ok(hires.size() >= 1, "%s HireArms present" % where)
	for a in hires:
		_ok(_route(a, "hire_plate"), "%s hire_plate" % where)


func _assert_castle_view(page: Node, where: String) -> void:
	var strip := page.find_child("CastleViewCrestStrip", true, false)
	_ok(_route(strip, "castle_view_strip"), "%s castle_view_strip" % where)
	if strip != null:
		var co := strip.find_child("CastleArms", true, false)
		_ok(_route(co, "strip_company"), "%s castle strip_company" % where)
		var bn := strip.find_child("CastleViewBanner", true, false)
		_ok(_route(bn, "castle_view_banner"), "%s castle_view_banner" % where)
	var pan := page.find_child("PanoramaLineageStrip", true, false)
	_ok(_route(pan, "panorama_lineage"), "%s panorama_lineage" % where)
	if pan != null:
		_ok(pan.find_child("CastleArms", true, false) != null, "%s panorama CastleArms" % where)


func _assert_board(page: Node, where: String) -> void:
	var arms: Array = []
	_collect(page, "BoardCrest", arms)
	_ok(arms.size() >= 1, "%s BoardCrest count=%d" % [where, arms.size()])
	var saw := false
	for a in arms:
		if str(a.get_meta("field_route", "")) == "board_offer":
			saw = true
			break
	_ok(saw, "%s board_offer route" % where)
	_ok(page.find_child("CastleArms", true, false) != null, "%s quests company header" % where)


func _assert_genealogy(page: Node, where: String) -> void:
	var lead: CKCharacter = GameState.get_leader()
	_ok(page.find_child("CastleArms", true, false) != null, "%s genealogy CastleArms" % where)
	if lead == null:
		return
	var cell := page.find_child("Avatar_%s" % lead.id, true, false) as Control
	_ok(cell != null, "%s leader wall tile" % where)
	if cell != null:
		var arms := cell.find_child("CellArms", true, false)
		_ok(_route(arms, "wall_tile"), "%s wall_tile" % where)
		_ok(cell.find_child("CellBadge", true, false) != null, "%s CellBadge" % where)


func _assert_marriage(page: Node, where: String) -> void:
	var strip := page.find_child("MarriageCrestStrip", true, false)
	_ok(_route(strip, "marriage_strip"), "%s marriage_strip" % where)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s marriage strip_company" % where)
		var la := strip.find_child("LeftArms", true, false)
		var ra := strip.find_child("RightArms", true, false)
		_ok(_route(la, "marriage_left"), "%s marriage_left" % where)
		_ok(_route(ra, "marriage_right"), "%s marriage_right" % where)
		_ok(_route(strip.find_child("MarriageBanner", true, false), "marriage_banner"), "%s marriage_banner" % where)
	var houses: Array = []
	_collect(page, "HouseArms", houses)
	_ok(houses.size() >= 1, "%s HouseArms" % where)
	for a in houses:
		_ok(_route(a, "house_card"), "%s house_card" % where)


func _assert_succession(page: Node, where: String) -> void:
	var strip := page.find_child("SuccessionCrestStrip", true, false)
	_ok(_route(strip, "succession_strip"), "%s succession_strip" % where)
	if strip != null:
		_ok(_route(strip.find_child("CastleArms", true, false), "strip_company"), "%s succession strip_company" % where)
		var la := strip.find_child("LeaderArms", true, false)
		_ok(_route(la, "succession_heir"), "%s succession_heir" % where)
		_ok(_route(strip.find_child("SuccessionBanner", true, false), "succession_banner"), "%s succession_banner" % where)


func _assert_deploy(page: Node, where: String) -> void:
	var strip := page.find_child("MusterCrestStrip", true, false)
	_ok(_route(strip, "deploy_muster"), "%s deploy_muster" % where)
	if strip != null:
		_ok(strip.find_child("CastleArms", true, false) != null, "%s muster CastleArms" % where)
		var la := strip.find_child("LeaderArms", true, false)
		_ok(_route(la, "deploy_muster_leader"), "%s deploy_muster_leader" % where)
	var slots: Array = []
	_collect(page, "DeployArms", slots)
	_ok(slots.size() >= 1, "%s DeployArms" % where)
	for a in slots:
		_ok(_route(a, "deploy_slot"), "%s deploy_slot" % where)


func _collect(n: Node, node_name: String, out: Array) -> void:
	if str(n.name) == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)


func _run_pass(tag: String) -> void:
	_boot()
	var tavern := _open(TAVERN)
	await _settle(12)
	_assert_tavern(tavern, tag + "/tavern")
	tavern.queue_free()
	await _settle(2)

	_boot()
	var cv := _open(CASTLE_VIEW)
	await _settle(12)
	if cv.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		cv.call("apply_mobile_layout")
		await _settle(6)
	_assert_castle_view(cv, tag + "/castle")
	cv.queue_free()
	await _settle(2)

	_boot()
	var quests := _open(QUESTS)
	await _settle(12)
	_assert_board(quests, tag + "/board")
	quests.queue_free()
	await _settle(2)

	_boot()
	var lin := _open(LINEAGE)
	await _settle(12)
	_assert_genealogy(lin, tag + "/wall")
	lin.queue_free()
	await _settle(2)

	_boot()
	var mar := _open(MARRIAGE)
	await _settle(12)
	_assert_marriage(mar, tag + "/marriage")
	mar.queue_free()
	await _settle(2)

	_boot()
	var inh := _open(INHERIT)
	await _settle(12)
	_assert_succession(inh, tag + "/succession")
	inh.queue_free()
	await _settle(2)

	_boot()
	var dep := _open(DEPLOY)
	await _settle(12)
	if dep.has_method("apply_mobile_layout") and tag.begins_with("mob"):
		dep.call("apply_mobile_layout")
		await _settle(6)
	_assert_deploy(dep, tag + "/deploy")
	dep.queue_free()
	await _settle(2)


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
	for pair in [
		["tavern_strip", "place_tavern_crest_strip"],
		["tavern_focus", "HireFocusArms"],
		["tavern_banner", "TavernBanner"],
		["strip_company", "strip_company"],
		["castle_view_strip", "place_castle_view_crest_strip"],
		["castle_view_banner", "CastleViewBanner"],
		["panorama_lineage", "place_panorama_lineage_strip"],
		["board_offer", "attach_board_offer_arms"],
		["wall_tile", "attach_wall_tile_arms"],
		["marriage_strip", "place_marriage_crest_strip"],
		["marriage_left", "LeftArms"],
		["marriage_right", "RightArms"],
		["marriage_banner", "MarriageBanner"],
		["succession_strip", "place_succession_crest_strip"],
		["succession_heir", "succession_heir"],
		["succession_banner", "SuccessionBanner"],
		["deploy_muster", "place_deploy_muster_strip"],
		["deploy_muster_leader", "deploy_muster_leader"],
		["hire_plate", "attach_hire_plate_arms"],
		["house_card", "attach_house_card_arms"],
	]:
		var route: String = pair[0]
		_ok(field.find('set_meta("field_route", "%s")' % route) >= 0 or field.find('"%s"' % route) >= 0, "field source route %s" % route)
	var hubs := {
		"tavern": "res://scripts/hub/tavern.gd",
		"castle_view": "res://scripts/hub/castle_view.gd",
		"quests": "res://scripts/hub/quests.gd",
		"lineage_view": "res://scripts/hub/lineage_view.gd",
		"marriage": "res://scripts/hub/marriage.gd",
		"inheritance": "res://scripts/hub/inheritance.gd",
		"deploy": "res://scripts/hub/deploy.gd",
	}
	for hub in hubs.keys():
		var src := FileAccess.get_file_as_string(hubs[hub])
		_ok(src.find("CKHeraldryField.") >= 0, "%s wires Field" % hub)
