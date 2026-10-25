extends Node
## Genealogy v2 (docs/design/genealogy-v2.md): avatar overview + per-person tree.
## 0 / 1 / 30+ members, selection, details focus + re-focus, pan/zoom, back through CKNav.

const OVERVIEW := "res://scenes/hub/lineage_view.tscn"
const TREE := "res://scenes/hub/lineage_tree.tscn"

var _fail := ""
var _shots := OS.get_environment("CK_GENEALOGY_SHOTS")

func _ready() -> void:
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await _run()
	if _fail != "":
		print("FAIL genealogy v2: ", _fail)
		get_tree().quit(1)
		return
	print("GENEALOGY V2 PASS")
	get_tree().quit(0)

func _ok(cond: bool, msg: String) -> void:
	if not cond and _fail == "":
		_fail = msg

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _scene() -> Node:
	return get_tree().current_scene

func _person(id: String, nm: String, age: int, gender: String = "m") -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = nm
	c.age = age
	c.gender = gender
	GameState.characters[id] = c
	return c

func _family(kids: int) -> Dictionary:
	GameState.new_game("谱测", "灰旗", GameState.crest_color)
	var leader := GameState.get_leader()
	for id in GameState.characters.keys():
		if GameState.characters[id] != leader:
			GameState.characters.erase(id)
	if kids < 0:
		return {"leader": leader}
	var fid := str(leader.family_id)
	var sp := _person("t_spouse", "林素", 30, "f")
	sp.family_id = fid  # married into the house; shows 族徽
	leader.spouse_id = sp.id
	sp.spouse_id = leader.id
	var dad := _person("t_father", "老家主", 60)
	dad.alive = false
	dad.family_id = fid
	leader.parent_ids = [dad.id, ""]
	dad.children_ids = [leader.id]
	var out := {"leader": leader, "spouse": sp, "father": dad, "kids": []}
	for i in kids:
		var k := _person("t_kid_%02d" % i, "嗣%02d" % i, i % 17, "m" if i % 2 == 0 else "f")
		k.is_child = true
		k.family_id = fid  # birth inherits paternal family → 族徽
		k.parent_ids = [leader.id, sp.id]
		leader.children_ids.append(k.id)
		sp.children_ids.append(k.id)
		if i == 3:
			k.alive = false
		out.kids.append(k)
	return out

func _open_overview() -> Node:
	CKNav.home()
	await _settle()
	_ok(CKNav.go(OVERVIEW), "go overview refused")
	await _settle()
	_ok(_scene() != null and _scene().scene_file_path == OVERVIEW, "overview did not load")
	return _scene()

func _shot(tag: String) -> void:
	if _shots == "":
		return
	await get_tree().create_timer(CKTransition.total_seconds() + 0.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots)
	img.save_png(_shots.path_join("genealogy_%s.png" % tag))

func _run() -> void:
	# ── 0 members: empty state, no details ──
	_family(-1)
	GameState.characters.clear()
	var v := await _open_overview()
	_ok(v.members().is_empty(), "empty: members not empty")
	_ok(v.find_child("LineageEmpty", true, false) != null, "empty: no empty-state label")
	_ok(v.find_child("InfoEmpty", true, false) != null, "empty: info panel placeholder missing")
	_ok(v.find_child("InfoAction", true, false) == null, "empty: details button shown")
	_ok(not v.open_details(), "empty: details opened without a person")
	await _shot("empty")
	# ── 1 member ──
	_family(-1)
	v = await _open_overview()
	_ok(v.members().size() == 1, "one: expected 1 member, got %d" % v.members().size())
	_ok(v.selected() == GameState.get_leader(), "one: leader not preselected")
	_ok(v.find_child("LineageEmpty", true, false) == null, "one: empty label shown")
	# ── 30+ members ──
	var fam := _family(32)
	v = await _open_overview()
	_ok(v.members().size() == 35, "many: expected 35 members, got %d" % v.members().size())
	_ok(v.members()[0] == fam.leader, "many: leader not first")
	var scroll := v.find_child("LineageGridScroll", true, false) as ScrollContainer
	await _settle(2)
	_ok(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.size.y + 1.0, "many: grid does not scroll")
	var hit := DeviceProfile.hit_px()
	for b in v.find_child("LineageGrid", true, false).get_children():
		_ok((b as Control).custom_minimum_size.x >= hit and (b as Control).custom_minimum_size.y >= hit, "avatar under 48dp")
		_ok((b as Control).mouse_filter == Control.MOUSE_FILTER_PASS, "avatar blocks drag-scroll")
	var dk: CKCharacter = fam.kids[3]
	var cell := v.find_child("Avatar_%s" % dk.id, true, false) as Button
	_ok(cell != null, "many: deceased avatar missing")
	await _shot("overview_many")
	# ── selection ──
	cell.pressed.emit()
	await _settle(2)
	_ok(v.selected() == dk, "select: avatar tap did not select")
	var nm := v.find_child("InfoName", true, false) as Label
	var ag := v.find_child("InfoAge", true, false) as Label
	_ok(nm != null and nm.text == dk.name, "select: info name not updated")
	_ok(ag != null and ag.text.begins_with("已故"), "select: deceased not marked")
	for need in ["PersonArms", "RankBadge", "ArmsKind", "InfoJob", "InfoRank", "InfoAction"]:
		_ok(v.find_child(need, true, false) != null, "info panel missing %s" % need)
	_ok(v.find_child("CastleArms", true, false) != null, "overview missing company CastleArms")
	var leader_cell := v.find_child("Avatar_%s" % fam.leader.id, true, false) as Control
	_ok(leader_cell != null and leader_cell.find_child("CellArms", true, false) != null, "avatar wall missing CellArms")
	_ok(leader_cell != null and leader_cell.find_child("CellBadge", true, false) != null, "avatar wall missing CellBadge")
	# Leader is family → 族徽; add a familyless recruit and confirm info shows 旗徽.
	var loner := CKCharacter.new()
	loner.id = "t_loner"
	loner.name = "散丁"
	loner.age = 28
	loner.gender = "m"
	loner.family_id = ""
	loner.rank = "knight"
	GameState.characters[loner.id] = loner
	# Arms kind on selected deceased kid (same family as leader) must be 族徽.
	var kind_lbl := v.find_child("ArmsKind", true, false) as Label
	_ok(kind_lbl != null and kind_lbl.text == Locale.t("gen2_06"), "family member ArmsKind not 族徽")
	var fam_core := CKHeraldry.core_key(GameState.arms_for_character(fam.leader))
	var ban_core := CKHeraldry.core_key(GameState.banner_spec)
	_ok(fam_core != ban_core, "family arms core should differ from company banner")
	_ok(CKHeraldry.core_key(GameState.arms_for_character(loner)) == ban_core, "familyless should resolve to company banner")
	if DeviceProfile.is_mobile():
		_ok(v.find_child("StitchFooter", true, false) == null, "key hints on touch")
		var ca := v.find_child("CastleArms", true, false) as Control
		_ok(ca != null and ca.visible, "mobile must keep company CastleArms visible")
	# ── details focus ──
	(v.find_child("Avatar_%s" % fam.leader.id, true, false) as Button).pressed.emit()
	await _settle(2)
	(v.find_child("InfoAction", true, false) as Button).pressed.emit()
	await _settle()
	var t := _scene()
	_ok(t.scene_file_path == TREE, "details did not open the tree")
	_ok(t.focus_id == str(fam.leader.id), "details focus is not the selected person")
	var cv: Control = t.canvas()
	_ok(cv.find_child("Node_%s" % fam.spouse.id, false, false) != null, "tree: spouse missing")
	_ok(cv.find_child("Node_%s" % fam.father.id, false, false) != null, "tree: parent missing")
	_ok(t.find_child("CastleArms", true, false) != null, "tree missing company CastleArms")
	var focus_node := cv.find_child("Node_%s" % fam.leader.id, false, false) as Control
	_ok(focus_node != null and focus_node.find_child("NodeArms", true, false) != null, "tree node missing NodeArms")
	_ok(focus_node != null and focus_node.find_child("NodeBadge", true, false) != null, "tree node missing NodeBadge")
	for need in ["PersonArms", "RankBadge", "ArmsKind"]:
		_ok(t.find_child(need, true, false) != null, "tree info missing %s" % need)
	for k in fam.kids:
		_ok(cv.find_child("Node_%s" % k.id, false, false) != null, "tree: child %s missing" % k.id)
	_ok(t.find_child("InfoAction", true, false) == null, "tree: re-focus offered on the focus itself")
	await _shot("tree_leader")
	# tap a child -> panel updates, re-focus
	var kid: CKCharacter = fam.kids[5]
	(cv.find_child("Node_%s" % kid.id, false, false) as Button).pressed.emit()
	await _settle(2)
	_ok(t.selected() == kid, "tree: node tap did not select")
	_ok((t.find_child("InfoName", true, false) as Label).text == kid.name, "tree: info not updated")
	var refocus := t.find_child("InfoAction", true, false) as Button
	_ok(refocus != null, "tree: no re-focus button")
	refocus.pressed.emit()
	await _settle(2)
	cv = t.canvas()
	_ok(t.focus_id == str(kid.id), "tree: re-focus failed")
	_ok(cv.find_child("Node_%s" % fam.leader.id, false, false) != null and cv.find_child("Node_%s" % fam.spouse.id, false, false) != null, "tree: re-focused parents missing")
	# pan / zoom stay bounded
	t.refocus(str(fam.leader.id))
	await _settle(2)
	cv = t.canvas()
	var p0: Vector2 = cv.position
	t.pan(Vector2(-300, 0))
	_ok(cv.position.x < p0.x, "tree: pan did nothing")
	t.pan(Vector2(-100000, -100000))
	_ok(cv.position.x >= 120.0 - cv.size.x * cv.scale.x - 0.5, "tree: pan escaped bounds")
	t.zoom_by(10.0)
	_ok(is_equal_approx(cv.scale.x, 2.0), "tree: zoom max")
	t.zoom_by(0.01)
	_ok(is_equal_approx(cv.scale.x, 0.5), "tree: zoom min")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(40, 0)
	var px: float = cv.position.x
	t._on_view_input(drag)
	_ok(not is_equal_approx(cv.position.x, px) or cv.position.x >= t.VIEW.size.x - 120.5, "tree: drag did not pan")
	# ── back: details -> overview -> hub ──
	_ok(CKNav.back() == "page", "tree back not routed through the page")
	await _settle()
	_ok(_scene().scene_file_path == OVERVIEW, "tree back did not return to overview (%s)" % _scene().scene_file_path)
	_ok(CKNav.back() == "page", "overview back not routed")
	await _settle()
	_ok(_scene().scene_file_path == CKNav.HOME, "overview back did not return to hub")
