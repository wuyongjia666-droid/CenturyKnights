extends Node
## Fat heraldry E2E: genealogy avatar wall goes through CKHeraldryField.
## House kin show 族徽, a second family keeps its own core, a familyless
## roster tile on the banner band shows the castle banner. Rank badges follow
## rank_changed. Desktop + mobile. Real lineage_view, not an empty host.

const OVERVIEW := "res://scenes/hub/lineage_view.tscn"
const VIEW_SRC := "res://scripts/hub/lineage_view.gd"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("GENEALOGY WALL FIELD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL genealogy wall field: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame

func _person(id: String, nm: String, age: int, gender: String = "m") -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = nm
	c.age = age
	c.gender = gender
	c.in_roster = true
	c.alive = true
	GameState.characters[id] = c
	return c

func _house() -> Dictionary:
	GameState.new_game("墙徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	World.events_enabled = false
	World.rivals_enabled = false
	var leader: CKCharacter = GameState.get_leader()
	leader.age = 34
	leader.rank = "count"
	for id in GameState.characters.keys():
		if GameState.characters[id] != leader:
			GameState.characters.erase(id)
	var fid := str(leader.family_id)
	var sp := _person("t_spouse", "林素", 30, "f")
	sp.family_id = fid
	sp.rank = "baron"
	leader.spouse_id = sp.id
	sp.spouse_id = leader.id
	var branch := _person("t_branch", "客支", 27, "m")
	branch.rank = "knight"
	GameState.found_family("客支", "shuoying", [branch.id])
	var loner := _person("t_loner", "散丁", 28, "m")
	loner.family_id = ""
	loner.rank = "baron"
	return {"leader": leader, "spouse": sp, "branch": branch, "loner": loner}

func _await_scene(path: String) -> Node:
	for _i in 40:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc != null and sc.scene_file_path == path:
			await _settle(3)
			return sc
	return null

func _kind(node: Node) -> String:
	return "" if node == null else str(node.get_meta("arms_kind", ""))

func _core(node: Node) -> String:
	return "" if node == null else str(node.get_meta("arms_core", ""))

func _arms_named(host: Node, node_name: String) -> Array:
	var out: Array = []
	if host == null:
		return out
	_collect(host, node_name, out)
	return out

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_wall(where: String) -> void:
	var src := FileAccess.get_file_as_string(VIEW_SRC)
	_ok(src.find("CKHeraldryField.attach_wall_tile_arms") >= 0, "%s wall calls CKHeraldryField" % where)
	var fam := _house()
	var leader: CKCharacter = fam.leader
	var branch: CKCharacter = fam.branch
	var loner: CKCharacter = fam.loner
	var fam_core := CKHeraldry.core_key(GameState.arms_for_character(leader))
	var branch_core := CKHeraldry.core_key(GameState.arms_for_character(branch))
	var ban_core := CKHeraldry.core_key(GameState.banner_spec)
	_ok(fam_core != "" and fam_core != ban_core, "%s leader core != company" % where)
	_ok(branch_core != "" and branch_core != fam_core and branch_core != ban_core, "%s second family core unique" % where)
	CKNav.home()
	await _settle()
	_ok(CKNav.go(OVERVIEW), "%s go overview refused" % where)
	var wall := await _await_scene(OVERVIEW)
	_ok(wall != null, "%s overview loaded" % where)
	if wall == null:
		return
	if wall.has_method("apply_mobile_layout") and DeviceProfile.is_mobile():
		wall.apply_mobile_layout()
		await _settle(4)
	var banner := wall.find_child("GenBand_banner", true, false)
	_ok(banner != null, "%s banner band" % where)
	var leader_cell := wall.find_child("Avatar_%s" % leader.id, true, false) as Control
	var branch_cell := wall.find_child("Avatar_%s" % branch.id, true, false) as Control
	var loner_cell := wall.find_child("Avatar_%s" % loner.id, true, false) as Control
	_ok(leader_cell != null and branch_cell != null and loner_cell != null, "%s three tiles" % where)
	if banner != null:
		_ok(banner.find_child("Avatar_%s" % branch.id, true, false) != null, "%s branch stays on banner band" % where)
		_ok(banner.find_child("Avatar_%s" % loner.id, true, false) != null, "%s loner stays on banner band" % where)
		_ok(banner.find_child("Avatar_%s" % leader.id, true, false) == null, "%s leader not filed as banner" % where)
	var leader_arms := leader_cell.find_child("CellArms", true, false) if leader_cell != null else null
	var branch_arms := branch_cell.find_child("CellArms", true, false) if branch_cell != null else null
	var loner_arms := loner_cell.find_child("CellArms", true, false) if loner_cell != null else null
	_ok(_kind(leader_arms) == "gen2_06" and _core(leader_arms) == fam_core, "%s leader tile 族徽" % where)
	_ok(_kind(branch_arms) == "gen2_06" and _core(branch_arms) == branch_core, "%s branch tile keeps own 族徽" % where)
	_ok(_kind(loner_arms) == "gen2_35" and _core(loner_arms) == ban_core, "%s loner tile 旗徽" % where)
	for cell in [leader_cell, branch_cell, loner_cell]:
		if cell == null:
			continue
		_ok(_arms_named(cell, "CellArms").size() == 1, "%s one shield, no marshalling" % where)
		_ok(cell.find_child("CellBadge", true, false) != null, "%s rank badge" % where)
	var badge := leader_cell.find_child("CellBadge", true, false) as TextureRect if leader_cell != null else null
	_ok(badge != null and str(badge.get_meta("rank_id", "")) == "count", "%s badge starts at count" % where)
	var before: Texture2D = badge.texture if badge != null else null
	leader.rank = "duke"
	await _settle(3)
	badge = leader_cell.find_child("CellBadge", true, false) as TextureRect if leader_cell != null else null
	_ok(badge != null and str(badge.get_meta("rank_id", "")) == "duke", "%s badge follows rank_changed" % where)
	_ok(badge != null and badge.texture != null and badge.texture != before, "%s badge texture changed" % where)
	var seen := {}
	for arms in [leader_arms, branch_arms]:
		var key := _core(arms)
		_ok(key != "" and not seen.has(key), "%s family cores globally unique on the wall" % where)
		seen[key] = true

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	await _assert_wall("desk")

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(2400, 1080)
	await _settle(2)
	await _assert_wall("mob")
	var wall := get_tree().current_scene
	if wall != null and wall.scene_file_path == OVERVIEW:
		var cell := wall.find_child("Avatar_%s" % GameState.get_leader().id, true, false) as Control
		_ok(cell != null and cell.custom_minimum_size.y >= 220.0, "mob cell keeps landscape size")
		_ok(wall.find_child("StitchFooter", true, false) == null, "mob hides key hints")
	OS.set_environment("CK_FORCE_MOBILE", "0")
