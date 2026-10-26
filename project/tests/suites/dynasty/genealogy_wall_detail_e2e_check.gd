extends Node
## Avatar wall + detail navigation + crest/arms_kind.
## Desktop run and mobile_genealogy_wall_detail_check (CK_FORCE_MOBILE=1) share this script.
## House members show 族徽; a familyless roster tile shows the castle banner.
## 详情 opens the lineage tree; 血脉详档 opens unit_dossier; back restores the same person and arms.

const OVERVIEW := "res://scenes/hub/lineage_view.tscn"
const TREE := "res://scenes/hub/lineage_tree.tscn"
const DOSSIER := "res://scenes/hub/unit_dossier.tscn"

var _fail := ""

func _ready() -> void:
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await _run()
	if _fail != "":
		print("FAIL genealogy wall detail: ", _fail)
		get_tree().quit(1)
		return
	print("GENEALOGY WALL DETAIL PASS")
	get_tree().quit(0)

func _ok(cond: bool, msg: String) -> void:
	if not cond and _fail == "":
		_fail = msg

func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame

func _scene() -> Node:
	return get_tree().current_scene

func _person(id: String, nm: String, age: int, gender: String = "m") -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = nm
	c.age = age
	c.gender = gender
	c.in_roster = true
	GameState.characters[id] = c
	return c

func _house() -> Dictionary:
	GameState.new_game("谱测", "灰旗", GameState.crest_color)
	var leader := GameState.get_leader()
	leader.age = 34
	leader.rank = "count"
	for id in GameState.characters.keys():
		if GameState.characters[id] != leader:
			GameState.characters.erase(id)
	var fid := str(leader.family_id)
	var sp := _person("t_spouse", "林素", 30, "f")
	sp.family_id = fid
	leader.spouse_id = sp.id
	sp.spouse_id = leader.id
	var dad := _person("t_father", "老家主", 62)
	dad.alive = false
	dad.family_id = fid
	dad.rank = "baron"
	leader.parent_ids = [dad.id]
	dad.children_ids = [leader.id]
	var kid := _person("t_kid", "嗣成", 20, "m")
	kid.family_id = fid
	kid.rank = "knight"
	kid.parent_ids = [leader.id, sp.id]
	leader.children_ids = [kid.id]
	sp.children_ids = [kid.id]
	var dead := _person("t_dead", "嗣殇", 8, "f")
	dead.alive = false
	dead.is_child = true
	dead.family_id = fid
	dead.parent_ids = [leader.id, sp.id]
	leader.children_ids.append(dead.id)
	sp.children_ids.append(dead.id)
	var loner := _person("t_loner", "散丁", 28, "m")
	loner.family_id = ""
	loner.rank = "baron"
	return {"leader": leader, "spouse": sp, "father": dad, "kid": kid, "dead": dead, "loner": loner}

func _await_scene(path: String) -> Node:
	for _i in 40:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc != null and sc.scene_file_path == path:
			await _settle(3)
			return sc
	return get_tree().current_scene

func _open(path: String) -> Node:
	var page := await _await_scene(path)
	if page != null and DeviceProfile.is_mobile() and page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(4)
	return page

func _press(node: Node) -> void:
	_ok(node != null and node is BaseButton, "missing button %s" % (node.name if node != null else "?"))
	if node is BaseButton:
		(node as BaseButton).pressed.emit()

func _kind(node: Node) -> String:
	if node == null:
		return ""
	return str(node.get_meta("arms_kind", ""))

func _core(node: Node) -> String:
	if node == null:
		return ""
	return str(node.get_meta("arms_core", ""))

func _run() -> void:
	var mobile := DeviceProfile.is_mobile()
	if mobile:
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.size = Vector2i(2400, 1080)
		await _settle(3)
	var fam := _house()
	var leader: CKCharacter = fam.leader
	var loner: CKCharacter = fam.loner
	var fam_core := CKHeraldry.core_key(GameState.arms_for_character(leader))
	var ban_core := CKHeraldry.core_key(GameState.banner_spec)
	_ok(fam_core != "" and fam_core != ban_core, "family core should differ from the castle banner")
	CKNav.home()
	await _settle()
	_ok(CKNav.go(OVERVIEW), "go overview refused")
	var wall := await _open(OVERVIEW)
	_ok(wall != null and wall.scene_file_path == OVERVIEW, "overview did not load")
	if _fail != "":
		return
	await _assert_wall(wall, fam, fam_core, ban_core, mobile)
	if _fail != "":
		return
	await _assert_loner_roundtrip(wall, loner, ban_core)
	if _fail != "":
		return
	wall = _scene()
	await _assert_leader_roundtrip(wall, fam, fam_core)

func _assert_wall(wall: Node, fam: Dictionary, fam_core: String, ban_core: String, mobile: bool) -> void:
	var leader: CKCharacter = fam.leader
	var spouse: CKCharacter = fam.spouse
	var father: CKCharacter = fam.father
	var kid: CKCharacter = fam.kid
	var dead: CKCharacter = fam.dead
	var loner: CKCharacter = fam.loner
	_ok(wall.members().size() == 5, "family members %d" % wall.members().size())
	_ok(wall.find_child("GenBand_peers", true, false) != null, "peers band missing")
	_ok(wall.find_child("GenBand_parents", true, false) != null, "parents band missing")
	_ok(wall.find_child("GenBand_children", true, false) != null, "children band missing")
	_ok(wall.find_child("GenBand_banner", true, false) != null, "banner band missing")
	var peers := wall.find_child("GenBand_peers", true, false)
	var parents := wall.find_child("GenBand_parents", true, false)
	var children := wall.find_child("GenBand_children", true, false)
	var banner := wall.find_child("GenBand_banner", true, false)
	_ok(peers.find_child("Avatar_%s" % leader.id, true, false) != null, "leader not in peers")
	_ok(peers.find_child("Avatar_%s" % spouse.id, true, false) != null, "spouse not in peers")
	_ok(parents.find_child("Avatar_%s" % father.id, true, false) != null, "father not in parents")
	_ok(children.find_child("Avatar_%s" % kid.id, true, false) != null, "child not in children")
	_ok(children.find_child("Avatar_%s" % dead.id, true, false) != null, "deceased child missing")
	_ok(banner.find_child("Avatar_%s" % loner.id, true, false) != null, "familyless not on the banner band")
	_ok(peers.find_child("Avatar_%s" % loner.id, true, false) == null, "familyless filed as kin")
	_ok(_rel(wall, leader) == Locale.t("gen2_33"), "leader relation")
	_ok(_rel(wall, spouse) == Locale.t("gen2_rel_spouse"), "spouse relation")
	_ok(_rel(wall, father) == Locale.t("gen2_rel_parent"), "parent relation")
	_ok(_rel(wall, kid) == Locale.t("gen2_rel_child"), "child relation")
	_ok(_rel(wall, loner) == Locale.t("gen2_rel_banner"), "banner relation")
	var leader_cell := wall.find_child("Avatar_%s" % leader.id, true, false) as Control
	var loner_cell := wall.find_child("Avatar_%s" % loner.id, true, false) as Control
	var dead_cell := wall.find_child("Avatar_%s" % dead.id, true, false) as Control
	var leader_arms := leader_cell.find_child("CellArms", true, false)
	var loner_arms := loner_cell.find_child("CellArms", true, false)
	_ok(_kind(leader_arms) == "gen2_06" and _core(leader_arms) == fam_core, "leader wall arms")
	_ok(_kind(loner_arms) == "gen2_35" and _core(loner_arms) == ban_core, "loner wall arms")
	_ok(leader_cell.find_child("CellBadge", true, false) != null, "leader badge missing")
	var leader_badge := leader_cell.find_child("CellBadge", true, false) as TextureRect
	var loner_badge := loner_cell.find_child("CellBadge", true, false) as TextureRect
	_ok(str(leader_badge.get_meta("rank_id", "")) == "count", "leader badge rank")
	_ok(str(loner_badge.get_meta("rank_id", "")) == "baron", "loner badge rank")
	_ok(leader_badge.texture != null and loner_badge.texture != null, "rank badge texture missing")
	_ok(leader_badge.texture != loner_badge.texture, "count and baron share a badge")
	var leader_rank := leader_cell.find_child("CellRank", true, false) as Label
	var dead_rank := dead_cell.find_child("CellRank", true, false) as Label
	var expect_leader := "%s · %s" % [Locale.t("gen2_21") % leader.age, leader.rank_name()]
	var expect_dead := "%s · %s" % [Locale.t("gen2_22"), Locale.t("lin_minor")]
	_ok(leader_rank != null and leader_rank.text == expect_leader, "leader rank line '%s'" % (leader_rank.text if leader_rank != null else ""))
	_ok(dead_rank != null and dead_rank.text == expect_dead, "deceased minor line")
	var por := dead_cell.find_child("Portrait", true, false) as CanvasItem
	_ok(por != null and por.modulate.r < 0.8, "deceased portrait not greyed")
	var castle := wall.find_child("CastleArms", true, false)
	_ok(_kind(castle) == "gen2_36", "overview company arms")
	if mobile:
		_ok(wall.find_child("StitchFooter", true, false) == null, "key hints on touch")
		_ok(leader_cell.custom_minimum_size.y >= 220.0, "mobile cell not landscape size")
		var title := wall.find_child("GenBandTitle", true, false) as Label
		_ok(title != null and title.get_theme_font_size("font_size") >= 22, "band title under phone floor")
	else:
		_ok(leader_cell.custom_minimum_size.y >= 160.0 and leader_cell.custom_minimum_size.y < 200.0, "desktop cell size")
	var action := wall.find_child("InfoAction", true, false) as Control
	var dossier := wall.find_child("InfoDossier", true, false) as Control
	_ok(action != null and action.custom_minimum_size.y >= 48.0, "detail control short")
	_ok(dossier != null and dossier.custom_minimum_size.y >= 48.0, "dossier control short")

func _rel(wall: Node, c: CKCharacter) -> String:
	var cell := wall.find_child("Avatar_%s" % c.id, true, false)
	if cell == null:
		return ""
	var lab := cell.find_child("CellRelation", true, false) as Label
	return lab.text if lab != null else ""

func _assert_loner_roundtrip(wall: Node, loner: CKCharacter, ban_core: String) -> void:
	_press(wall.find_child("Avatar_%s" % loner.id, true, false))
	await _settle(2)
	_ok(wall.selected() == loner, "loner tap did not select")
	var kind := wall.find_child("ArmsKind", true, false) as Label
	var arms := wall.find_child("PersonArms", true, false)
	_ok(kind != null and kind.text == Locale.t("gen2_35"), "info kind not banner")
	_ok(_kind(arms) == "gen2_35" and _core(arms) == ban_core, "info person arms not banner")
	_press(wall.find_child("InfoAction", true, false))
	var tree := await _open(TREE)
	_ok(tree != null and tree.scene_file_path == TREE, "detail did not open the tree")
	if _fail != "":
		return
	_ok(str(tree.focus_id) == str(loner.id), "tree focus is not the loner")
	var node: Node = tree.canvas().find_child("Node_%s" % loner.id, true, false)
	var node_arms: Node = node.find_child("NodeArms", true, false) if node != null else null
	_ok(_kind(node_arms) == "gen2_35" and _core(node_arms) == ban_core, "tree node lost banner arms")
	_ok(tree.find_child("NodeBadge", true, false) != null, "tree rank badge missing")
	_press(tree.find_child("InfoDossier", true, false))
	var page := await _open(DOSSIER)
	_ok(page != null and page.scene_file_path == DOSSIER, "dossier did not open from the tree")
	if _fail != "":
		return
	var crest := page.find_child("CrestPreview", true, false)
	_ok(_kind(crest) == "gen2_35" and _core(crest) == ban_core, "dossier crest lost banner arms")
	var chip := page.find_child("KinChip_%s" % loner.id, true, false)
	var chip_arms := chip.find_child("ChipArms", true, false) if chip != null else null
	_ok(_kind(chip) == "gen2_35" and _kind(chip_arms) == "gen2_35" and _core(chip_arms) == ban_core, "dossier chip lost banner arms")
	_ok(CKNav.back() == "page", "dossier back not routed")
	tree = await _open(TREE)
	_ok(tree != null and tree.scene_file_path == TREE and str(tree.focus_id) == str(loner.id), "back from dossier lost the tree focus")
	if _fail != "":
		return
	node = tree.canvas().find_child("Node_%s" % loner.id, true, false)
	node_arms = node.find_child("NodeArms", true, false) if node != null else null
	_ok(_kind(node_arms) == "gen2_35" and _core(node_arms) == ban_core, "tree arms changed after dossier")
	_ok(CKNav.back() == "page", "tree back not routed")
	wall = await _open(OVERVIEW)
	_ok(wall != null and wall.scene_file_path == OVERVIEW, "tree back did not return to the wall")
	if _fail != "":
		return
	_ok(wall.selected() == loner, "wall did not restore the loner")
	var back_arms := wall.find_child("Avatar_%s" % loner.id, true, false).find_child("CellArms", true, false)
	_ok(_kind(back_arms) == "gen2_35" and _core(back_arms) == ban_core, "wall banner arms changed after the round trip")

func _assert_leader_roundtrip(wall: Node, fam: Dictionary, fam_core: String) -> void:
	var leader: CKCharacter = fam.leader
	var spouse: CKCharacter = fam.spouse
	var kid: CKCharacter = fam.kid
	_press(wall.find_child("Avatar_%s" % leader.id, true, false))
	await _settle(2)
	_press(wall.find_child("InfoDossier", true, false))
	var page := await _open(DOSSIER)
	_ok(page != null and page.scene_file_path == DOSSIER, "wall dossier did not open")
	if _fail != "":
		return
	var crest := page.find_child("CrestPreview", true, false)
	_ok(_kind(crest) == "gen2_06" and _core(crest) == fam_core, "leader dossier crest is not family arms")
	for person in [leader, spouse, kid]:
		var chip: Node = page.find_child("KinChip_%s" % person.id, true, false)
		var chip_arms: Node = chip.find_child("ChipArms", true, false) if chip != null else null
		_ok(chip != null and _kind(chip_arms) == "gen2_06" and _core(chip_arms) == fam_core, "kin chip arms %s" % person.id)
		_ok(chip != null and chip.find_child("ChipBadge", true, false) != null, "kin chip badge %s" % person.id)
	_press(page.find_child("OpenLineageDetail", true, false))
	var tree := await _open(TREE)
	_ok(tree != null and tree.scene_file_path == TREE and str(tree.focus_id) == str(leader.id), "lineage detail did not focus the leader")
	if _fail != "":
		return
	var node: Node = tree.canvas().find_child("Node_%s" % leader.id, true, false)
	var node_arms: Node = node.find_child("NodeArms", true, false) if node != null else null
	_ok(_kind(node_arms) == "gen2_06" and _core(node_arms) == fam_core, "leader tree node lost family arms")
	_ok(tree.canvas().find_child("Node_%s" % spouse.id, true, false) != null, "spouse missing on the leader tree")
	_ok(tree.canvas().find_child("Node_%s" % kid.id, true, false) != null, "child missing on the leader tree")
	_ok(CKNav.back() == "page", "detail back not routed")
	page = await _open(DOSSIER)
	_ok(page != null and page.scene_file_path == DOSSIER, "detail back did not return to the dossier")
	if _fail != "":
		return
	crest = page.find_child("CrestPreview", true, false)
	_ok(_kind(crest) == "gen2_06" and _core(crest) == fam_core, "dossier arms changed after lineage detail")
	_ok(CKNav.back() == "page", "dossier back not routed")
	wall = await _open(OVERVIEW)
	_ok(wall != null and wall.scene_file_path == OVERVIEW and wall.selected() == leader, "wall did not restore the leader")
	if _fail != "":
		return
	var cell_arms := wall.find_child("Avatar_%s" % leader.id, true, false).find_child("CellArms", true, false)
	_ok(_kind(cell_arms) == "gen2_06" and _core(cell_arms) == fam_core, "leader wall arms changed after dossier")
