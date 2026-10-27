extends Node
## Fat heraldry E2E: city 本城之事 AffairOverlay — AffairCrestStrip (团徽+邦徽)
## + AffairSealArms on stamp rows (族徽|旗徽). Desktop + mobile. No marshalling.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CITY := "lt_capital"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("CITY AFFAIRS CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL city affairs crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("本城徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	# city rep rides nation (rep_of → rep_nation)
	GameState.silver = 8000
	GameState.food = 40
	World.pos = CITY
	World.arrive(CITY)
	GameState.set_meta("city_id", CITY)
	# Seed priest (seal from) + loner so 族徽 and 旗徽 both appear on stamp rows.
	var lead: CKCharacter = GameState.get_leader()
	lead.job_id = "priest"
	var loner := CKCharacter.new()
	loner.id = "affairs_loner"
	loner.name = "客司"
	loner.age = 28
	loner.alive = true
	loner.in_roster = true
	loner.family_id = ""
	loner.job_id = "priest"
	loner.rank = "knight"
	loner.hp = loner.max_hp
	GameState.characters[loner.id] = loner

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_overlay(page: Node, where: String) -> void:
	var ov := page.find_child("AffairOverlay", true, false)
	_ok(ov != null, "%s AffairOverlay" % where)
	if ov == null:
		return
	var strips: Array = []
	_collect(ov, "AffairCrestStrip", strips)
	_ok(not strips.is_empty(), "%s AffairCrestStrip" % where)
	if not strips.is_empty():
		var strip: Node = strips[0]
		var ca := strip.find_child("CastleArms", true, false)
		var cn := strip.find_child("CityNationArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
		_ok(cn != null and str(cn.get_meta("arms_kind", "")) == "lb_city_arms", "%s strip 邦徽" % where)
		if ca != null and cn != null:
			_ok(str(cn.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 邦徽!=团徽" % where)
		_ok(str(strip.get_meta("field_route", "")) == "affairs_strip", "%s affairs_strip route" % where)
		_ok(str(ca.get_meta("field_route", "")) == "strip_company" if ca != null else false, "%s strip_company" % where)
		_ok(str(cn.get_meta("field_route", "")) == "affairs_nation" if cn != null else false, "%s affairs_nation" % where)
		var bn := strip.find_child("AffairsBanner", true, false)
		_ok(bn != null and str(bn.get_meta("field_route", "")) == "affairs_banner", "%s affairs_banner" % where)
		# Two shields + cloth plate (banner is not a third marshalling shield).
		_ok(strip.get_child_count() == 3, "%s strip two shields + cloth" % where)
		_ok(str(strip.get_meta("city_id", "")) == CITY, "%s city_id meta" % where)
		_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s strip ignores mouse" % where)
	var seals: Array = []
	_collect(ov, "AffairSealArms", seals)
	_ok(seals.size() >= 2, "%s AffairSealArms (>=2)" % where)
	var saw_fam := false
	var saw_flag := false
	for a in seals:
		var k := str(a.get_meta("arms_kind", ""))
		if k == "gen2_06":
			saw_fam = true
		elif k == "gen2_35":
			saw_flag = true
	_ok(saw_fam, "%s seal 族徽" % where)
	_ok(saw_flag, "%s seal 旗徽" % where)

func _open() -> Control:
	var page: Control = CITY_SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	page.set_meta("city_id", CITY)
	get_tree().root.add_child(page)
	return page

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _open()
	await _settle(12)
	if page.has_method("open_affairs"):
		page.open_affairs()
		await _settle(10)
	_assert_overlay(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page := _open()
	await _settle(8)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(6)
	if page.has_method("open_affairs"):
		page.open_affairs()
		await _settle(10)
	_assert_overlay(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
