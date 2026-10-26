extends Node
## Fat heraldry E2E: castle annex serve-list leftovers.
## Infirmary heal rows wear InnHealArms. Academy rows wear AnnexRowArms 族徽.
## Embassy rows wear 敌徽. Treasury wears 团徽.
## Desktop + mobile. Fails when the row shield is missing. Page header chrome stays.

const SCN := preload("res://scenes/hub/annex.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("ANNEX SERVE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL annex serve crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("附楼徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	lead.hp = maxi(1, lead.max_hp - 3)
	var kid := CKCharacter.new()
	kid.id = "annex_kid"
	kid.name = "学童"
	kid.age = 8
	kid.alive = true
	kid.in_roster = false
	kid.is_child = true
	kid.is_leader = false
	kid.family_id = str(lead.family_id)
	kid.job_id = "light_inf"
	kid.rank = "knight"
	GameState.characters[kid.id] = kid

func _open(annex_id: String) -> Control:
	var page: Control = SCN.instantiate()
	page.set_meta("annex", annex_id)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _arms(page: Node) -> Array:
	var out: Array = []
	_collect(page, "AnnexRowArms", out)
	return out

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_person(page: Node, where: String, node_name: String = "AnnexRowArms") -> void:
	var lead: CKCharacter = GameState.get_leader()
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var arms: Array = []
	_collect(page, node_name, arms)
	_ok(not arms.is_empty(), "%s %s" % [where, node_name])
	var hit := false
	for a in arms:
		_ok(str(a.get_meta("arms_kind", "")) == "gen2_06", "%s person 族徽" % where)
		if str(a.get_meta("arms_core", "")) == fam:
			hit = true
		_ok(str(a.get_meta("arms_core", "")) != ban, "%s person != 团徽" % where)
		_ok(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s person ignores mouse" % where)
	_ok(hit, "%s family core on a serve row" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null, "%s header banner remains" % where)

func _assert_rival(page: Node, where: String) -> void:
	var houses: Array = GameState.data_rivals.get("houses", [])
	_ok(not houses.is_empty(), "%s rival houses exist" % where)
	var arms := _arms(page)
	_ok(arms.size() >= houses.size() and houses.size() > 0, "%s one AnnexRowArms per house" % where)
	if houses.is_empty() or arms.is_empty():
		return
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var want := CKHeraldry.core_key(CKHeraldryChrome.rival_spec(houses[0]))
	var a: Node = arms[0]
	_ok(str(a.get_meta("arms_kind", "")) == "lb_rv_arms", "%s embassy 敌徽" % where)
	_ok(str(a.get_meta("arms_core", "")) == want, "%s embassy rival core" % where)
	_ok(str(a.get_meta("arms_core", "")) != ban, "%s embassy != 团徽" % where)

func _assert_company(page: Node, where: String) -> void:
	var arms := _arms(page)
	_ok(arms.size() == 1, "%s treasury one plate" % where)
	if arms.is_empty():
		return
	var a: Node = arms[0]
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	_ok(str(a.get_meta("arms_kind", "")) == "gen2_36", "%s treasury 团徽" % where)
	_ok(str(a.get_meta("arms_core", "")) == ban, "%s treasury company core" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var inf := _open("infirmary")
	await _settle(10)
	_assert_person(inf, "desk-infirmary", "InnHealArms")
	inf.queue_free()
	await _settle(2)
	var emb := _open("embassy")
	await _settle(10)
	_assert_rival(emb, "desk-embassy")
	emb.queue_free()
	await _settle(2)
	var tre := _open("treasury")
	await _settle(10)
	_assert_company(tre, "desk-treasury")
	tre.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var aca := _open("academy")
	await _settle(8)
	if aca.has_method("apply_mobile_layout"):
		aca.apply_mobile_layout()
		await _settle(6)
	_assert_person(aca, "mob-academy")
	aca.queue_free()
	await _settle(2)
	var emb := _open("embassy")
	await _settle(6)
	if emb.has_method("apply_mobile_layout"):
		emb.apply_mobile_layout()
		await _settle(4)
	_assert_rival(emb, "mob-embassy")
	emb.queue_free()
	await _settle(2)
	var tre := _open("treasury")
	await _settle(6)
	if tre.has_method("apply_mobile_layout"):
		tre.apply_mobile_layout()
		await _settle(4)
	_assert_company(tre, "mob-treasury")
	tre.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
