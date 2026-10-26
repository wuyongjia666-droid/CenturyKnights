extends Node
## Fat heraldry E2E: castle panorama (castle_view) lineage strip.
## 团徽 once, then each living roster shield: family 族徽 or familyless 旗徽.
## Cores stay unique. No marriage marshalling. Desktop + mobile. Real scene.

const SCN := preload("res://scenes/hub/castle_view.tscn")
const SRC := "res://scripts/hub/castle_view.gd"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("CASTLE PANORAMA LINEAGE CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL castle panorama lineage: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame

func _boot() -> Dictionary:
	GameState.new_game("城览徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	GameState.food = 40
	GameState.iron = 40
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
		branch.rank = "baron"
	if loner != null:
		loner.family_id = ""
		loner.rank = "knight"
	return {"leader": leader, "branch": branch, "loner": loner}

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _open() -> Control:
	var page: Control = SCN.instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page

func _assert_page(page: Node, where: String, fam: Dictionary) -> void:
	var src := FileAccess.get_file_as_string(SRC)
	_ok(src.find("CKHeraldryField.place_panorama_lineage_strip") >= 0, "%s panorama calls CKHeraldryField" % where)
	var crest := page.find_child("CastleViewCrestStrip", true, false) as Control
	_ok(crest != null, "%s keeps CastleViewCrestStrip" % where)
	var strips: Array = []
	_collect(page, "PanoramaLineageStrip", strips)
	_ok(strips.size() == 1, "%s one PanoramaLineageStrip" % where)
	if strips.is_empty():
		return
	var strip: Control = strips[0]
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s strip ignores mouse" % where)
	var company := strip.get_node_or_null("CastleArms")
	_ok(company != null and str(company.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	if company != null:
		_ok(str(company.get_meta("arms_core", "")) == ban, "%s strip company core" % where)
	var leader: CKCharacter = fam.leader
	var branch: CKCharacter = fam.branch
	var loner: CKCharacter = fam.loner
	var lead_arms := strip.get_node_or_null("PanoramaPerson_%s" % leader.id)
	_ok(lead_arms != null and str(lead_arms.get_meta("arms_kind", "")) == "gen2_06", "%s leader 族徽" % where)
	var fam_core := CKHeraldry.core_key(GameState.arms_for_character(leader))
	if lead_arms != null:
		_ok(str(lead_arms.get_meta("arms_core", "")) == fam_core, "%s leader core" % where)
		_ok(lead_arms.get_child_count() == 0, "%s leader shield is not marshalled" % where)
	if branch != null:
		var br := strip.get_node_or_null("PanoramaPerson_%s" % branch.id)
		var br_core := CKHeraldry.core_key(GameState.arms_for_character(branch))
		_ok(br != null and str(br.get_meta("arms_kind", "")) == "gen2_06", "%s branch 族徽" % where)
		_ok(br != null and str(br.get_meta("arms_core", "")) == br_core and br_core != fam_core, "%s branch core unique" % where)
	if loner != null:
		var lo := strip.get_node_or_null("PanoramaPerson_%s" % loner.id)
		_ok(lo != null and str(lo.get_meta("arms_kind", "")) == "gen2_35", "%s loner 旗徽" % where)
		_ok(lo != null and str(lo.get_meta("arms_core", "")) == ban, "%s loner matches castle banner" % where)
	var people := int(strip.get_meta("person_count", 0))
	_ok(people >= 2 and strip.get_child_count() == people + 1, "%s company plus people, no extra shield" % where)
	if crest != null:
		_ok(not strip.get_global_rect().intersects(crest.get_global_rect()), "%s strip clears the crest" % where)
	for id in _slot_ids(page):
		_ok(page.find_child("card_%s" % id, true, false) != null, "%s card %s stays" % [where, id])

func _slot_ids(page: Node) -> Array:
	return ["hall", "barracks", "market"] if page != null else []

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var fam := _boot()
	var page := _open()
	await _settle(12)
	_assert_page(page, "desk", fam)
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var fam := _boot()
	var page := _open()
	await _settle(8)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(6)
	_assert_page(page, "mob", fam)
	_ok(page.find_child("MobileGrid", true, false) != null, "mob building grid")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "0")
