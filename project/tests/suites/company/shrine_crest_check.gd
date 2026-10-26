extends Node
## Fat heraldry E2E: shrine company/nation chrome + ShrineHealStrip (团徽 + first hurt 族徽|旗徽).
## Hurt → HealFocusArms. After heal empties roster wounds → strip is 团徽 only. Desktop + mobile.

const SHRINE_SCN := preload("res://scenes/hub/shrine.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		var _src := FileAccess.get_file_as_string("res://scripts/hub/shrine.gd")
		_ok(_src.find("CKHeraldryField.place_nation_crest_strip") >= 0, "source Field call")
		print("SHRINE FIELD CREST PASS")
		print("SHRINE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL shrine crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot(hurt: bool) -> void:
	GameState.new_game("神殿徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var lead: CKCharacter = GameState.get_leader()
	if hurt and lead != null:
		lead.hp = maxi(1, int(lead.max_hp / 2))
		lead.injured = true

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_chrome(page: Node, where: String) -> void:
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms (header/strip)" % where)
	var strip := page.find_child("NationCrestStrip", true, false)
	_ok(strip != null and str(strip.get_meta("field_route", "")) == "nation_strip", "nation_strip field_route")
	_ok(strip != null, "%s NationCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var cn := strip.find_child("CityNationArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
		_ok(cn != null and str(cn.get_meta("arms_kind", "")) == "lb_city_arms", "%s strip 邦徽" % where)
		_ok(cn != null and ca != null and str(cn.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 邦徽!=团徽" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null or page.find_child("CastleBanner", true, false) != null, "%s banner chrome" % where)
	_ok(page.find_child("HealCard", true, false) != null, "%s HealCard still present" % where)

func _assert_heal_filled(page: Node, where: String) -> void:
	var lead: CKCharacter = GameState.get_leader()
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var strips: Array = []
	_collect(page, "ShrineHealStrip", strips)
	_ok(not strips.is_empty(), "%s ShrineHealStrip" % where)
	if strips.is_empty():
		return
	var strip: Node = strips[0]
	var ca := strip.find_child("CastleArms", true, false)
	var fa := strip.find_child("HealFocusArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s heal 团徽" % where)
	_ok(fa != null and str(fa.get_meta("arms_kind", "")) == "gen2_06", "%s HealFocusArms 族徽" % where)
	if ca != null and fa != null:
		_ok(str(ca.get_meta("arms_core", "")) == ban, "%s heal company core" % where)
		_ok(str(fa.get_meta("arms_core", "")) == fam, "%s heal family core" % where)
		_ok(str(fa.get_meta("arms_core", "")) != str(ca.get_meta("arms_core", "")), "%s 族徽!=团徽" % where)
	_ok(strip.get_child_count() == 2, "%s heal strip two shields" % where)
	_ok(bool(strip.get_meta("has_hurt", false)), "%s has_hurt meta" % where)

func _assert_heal_empty(page: Node, where: String) -> void:
	var strips: Array = []
	_collect(page, "ShrineHealStrip", strips)
	_ok(not strips.is_empty(), "%s empty ShrineHealStrip" % where)
	if not strips.is_empty():
		var strip: Node = strips[0]
		_ok(strip.find_child("CastleArms", true, false) != null, "%s empty 团徽" % where)
		_ok(strip.find_child("HealFocusArms", true, false) == null, "%s empty has no HealFocusArms" % where)
		_ok(not bool(strip.get_meta("has_hurt", true)), "%s has_hurt false" % where)

func _open() -> Control:
	var page: Control = SHRINE_SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot(true)
	var page := _open()
	await _settle(12)
	_assert_chrome(page, "desk")
	_assert_heal_filled(page, "desk")
	# Heal clears wounds → strip drops person arms
	if page.has_method("_heal"):
		page._heal()
		await _settle(6)
		_assert_heal_empty(page, "desk-healed")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot(true)
	var page := _open()
	await _settle(8)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(8)
	_assert_chrome(page, "mob")
	_assert_heal_filled(page, "mob")
	var heal := page.find_child("HealCard", true, false)
	_ok(heal != null and heal.find_child("ShrineHealStrip", true, false) != null, "mob strip on HealCard")
	var _hs = heal.find_child("ShrineHealStrip", true, false) if heal else null
	_ok(_hs != null and str(_hs.get_meta("field_route", "")) == "shrine_heal", "shrine_heal route")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
