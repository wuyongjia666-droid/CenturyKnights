extends Node
## Fat heraldry E2E: castle home roster plate shows company + person arms.
## Familyless knights use the castle banner; a founded branch keeps its own 族徽.
## Desktop RosterPlate and the mobile roster column both carry HomeLineageRow.

const SCN := preload("res://scenes/hub/castle_hub.tscn")
const SRC := "res://scripts/hub/castle_hub.gd"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("CASTLE HOME LINEAGE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL castle home lineage: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame

func _boot() -> Dictionary:
	GameState.new_game("家徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	GameState.set_flag("hub_open", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	var leader: CKCharacter = GameState.get_leader()
	var rest: Array = []
	for c in GameState.roster():
		if c != leader:
			rest.append(c)
	rest.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var branch: CKCharacter = rest[0] if not rest.is_empty() else null
	var loner: CKCharacter = rest[1] if rest.size() > 1 else null
	if branch != null:
		branch.family_id = ""
		GameState.found_family("客支", "shuoying", [branch.id])
	if loner != null:
		loner.family_id = ""
	return {"leader": leader, "branch": branch, "loner": loner}

func _open() -> Control:
	var page: Control = SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _assert_page(page: Node, where: String, fam: Dictionary) -> void:
	var src := FileAccess.get_file_as_string(SRC)
	_ok(src.find("CKHeraldryField.place_home_lineage_row") >= 0, "%s home calls CKHeraldryField" % where)
	var row := page.find_child("HomeLineageRow", true, false) as Control
	_ok(row != null, "%s HomeLineageRow" % where)
	if row == null:
		return
	_ok(row.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s row ignores mouse" % where)
	var company := row.get_node_or_null("CastleArms")
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	_ok(company != null and str(company.get_meta("arms_kind", "")) == "gen2_36", "%s row 团徽" % where)
	if company != null:
		_ok(str(company.get_meta("arms_core", "")) == ban, "%s row company core" % where)
	var leader: CKCharacter = fam.leader
	var lead := row.get_node_or_null("HomeLeaderArms")
	var fam_core := CKHeraldry.core_key(GameState.arms_for_character(leader))
	_ok(lead != null and str(lead.get_meta("arms_kind", "")) == "gen2_06", "%s leader 族徽" % where)
	_ok(lead != null and str(lead.get_meta("arms_core", "")) == fam_core, "%s leader core" % where)
	_ok(lead != null and lead.get_child_count() == 0, "%s leader not marshalled" % where)
	var branch: CKCharacter = fam.branch
	if branch != null:
		var br := row.get_node_or_null("HomeKin_%s" % branch.id)
		var br_core := CKHeraldry.core_key(GameState.arms_for_character(branch))
		_ok(br != null and str(br.get_meta("arms_kind", "")) == "gen2_06", "%s branch 族徽" % where)
		_ok(br != null and str(br.get_meta("arms_core", "")) == br_core and br_core != fam_core and br_core != ban, "%s branch core unique" % where)
	var loner: CKCharacter = fam.loner
	if loner != null:
		var lo := row.get_node_or_null("HomeKin_%s" % loner.id)
		_ok(lo != null and str(lo.get_meta("arms_kind", "")) == "gen2_35", "%s loner 旗徽" % where)
		_ok(lo != null and str(lo.get_meta("arms_core", "")) == ban, "%s loner matches castle banner" % where)
	var people := int(row.get_meta("person_count", 0))
	_ok(people >= 2 and row.get_child_count() == people + 1, "%s company plus people" % where)
	_ok(page.find_child("PromoteOpen", true, false) != null, "%s promote control stays" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null, "%s castle banner strip stays" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var fam := _boot()
	var page := _open()
	await _settle(12)
	_assert_page(page, "desk", fam)
	var plate := page.find_child("RosterPlate", true, false)
	var row := page.find_child("HomeLineageRow", true, false)
	_ok(plate != null and row != null and row.get_parent() == plate, "desk row sits on RosterPlate")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1600, 720)
	await _settle(2)
	var fam := _boot()
	var page := _open()
	await _settle(10)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(6)
	_assert_page(page, "mob", fam)
	var row := page.find_child("HomeLineageRow", true, false)
	var plate := page.find_child("RosterPlate", true, false)
	_ok(row != null and plate != null and _is_under(row, plate), "mob row stays inside RosterPlate")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "0")

func _is_under(node: Node, parent: Node) -> bool:
	var cur := node
	while cur != null:
		if cur == parent:
			return true
		cur = cur.get_parent()
	return false
