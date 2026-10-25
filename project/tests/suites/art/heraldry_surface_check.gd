extends Node
## Player-visible heraldry consistency across genealogy wall/tree + dossier crest.
## 团徽 header once; familyless → 旗徽; family → 族徽 + canton; 爵位徽记 on wall/tree/info.

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
		print("FAIL heraldry surface: ", _fail)
		get_tree().quit(1)
		return
	print("HERALDRY SURFACE PASS")
	get_tree().quit(0)

func _ok(cond: bool, msg: String) -> void:
	if not cond and _fail == "":
		_fail = msg

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _open_dossier(cid: String) -> Control:
	GameState.set_meta("dossier_id", cid)
	GameState.set_meta("dossier_back", OVERVIEW)
	var page: Control = load(DOSSIER).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	return page

func _run() -> void:
	GameState.new_game("烬行", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	var leader = GameState.get_leader()
	_ok(leader != null and str(leader.family_id) != "", "leader family missing")
	if _fail != "":
		return
	leader.rank = "baron"
	var loner := CKCharacter.new()
	loner.id = "hs_loner"
	loner.name = "散丁"
	loner.age = 26
	loner.gender = "m"
	loner.family_id = ""
	loner.rank = "knight"
	loner.is_leader = false
	GameState.characters[loner.id] = loner

	var fam_spec: Dictionary = GameState.arms_for_character(leader)
	var ban_spec: Dictionary = GameState.banner_spec
	_ok(fam_spec.has("castle_mark"), "family arms missing canton")
	_ok(CKHeraldry.core_key(fam_spec) != CKHeraldry.core_key(ban_spec), "family core collided with company")
	_ok(CKHeraldry.core_key(GameState.arms_for_character(loner)) == CKHeraldry.core_key(ban_spec), "familyless not company banner")
	_ok(CKHeraldryChrome.arms_kind_key(leader) == "gen2_06", "leader kind not 族徽")
	_ok(CKHeraldryChrome.arms_kind_key(loner) == "gen2_35", "loner kind not 旗徽")
	_ok(CKHeraldryChrome.dossier_crest_label(leader) == Locale.t("lb_dos_crest_family"), "dossier family label")
	_ok(CKHeraldryChrome.dossier_crest_label(loner) == Locale.t("lb_dos_crest_banner"), "dossier banner label")
	if _fail != "":
		return

	# Overview wall + company header (CKNav path, same as genealogy suite)
	CKNav.home()
	await _settle()
	_ok(CKNav.go(OVERVIEW), "go overview refused")
	await _settle()
	var v := get_tree().current_scene
	_ok(v != null and v.scene_file_path == OVERVIEW, "overview not loaded")
	_ok(v.find_child("CastleArms", true, false) != null, "CastleArms missing on overview")
	var cell := v.find_child("Avatar_%s" % leader.id, true, false) as Control
	_ok(cell != null, "leader avatar missing")
	if cell != null:
		_ok(cell.find_child("CellArms", true, false) != null, "wall CellArms missing")
		_ok(cell.find_child("CellBadge", true, false) != null, "wall CellBadge missing")
	v.select(leader)
	await _settle(2)
	var kind := v.find_child("ArmsKind", true, false) as Label
	_ok(kind != null and kind.text == Locale.t("gen2_06"), "overview ArmsKind wrong")
	_ok(v.find_child("PersonArms", true, false) != null, "overview PersonArms missing")
	_ok(v.find_child("RankBadge", true, false) != null, "overview RankBadge missing")
	if _fail != "":
		return

	# Details tree
	_ok(v.open_details(), "open details failed")
	await _settle()
	var t := get_tree().current_scene
	_ok(t != null and t.scene_file_path == TREE, "tree not loaded")
	_ok(t.find_child("CastleArms", true, false) != null, "CastleArms missing on tree")
	var node := t.canvas().find_child("Node_%s" % leader.id, false, false) as Control
	_ok(node != null, "tree node missing")
	if node != null:
		_ok(node.find_child("NodeArms", true, false) != null, "tree NodeArms missing")
		_ok(node.find_child("NodeBadge", true, false) != null, "tree NodeBadge missing")
	if _fail != "":
		return

	# Dossier crest: family → 族徽 (instantiate; no change_scene)
	var d := _open_dossier(leader.id)
	await _settle(8)
	var crest_btn := d.find_child("CrestPreview", true, false) as Button
	_ok(crest_btn != null, "CrestPreview missing")
	if crest_btn != null:
		_ok(str(crest_btn.get_meta("arms_kind", "")) == "gen2_06", "dossier crest kind not family")
		_ok(crest_btn.text == Locale.t("lb_dos_crest_family"), "dossier crest label not 族徽")
		crest_btn.pressed.emit()
		await _settle(4)
		var overlay := d.find_child("CrestOverlay", true, false)
		_ok(overlay != null, "CrestOverlay missing")
		var tex := overlay.find_child("CrestTexture", true, false) if overlay else null
		_ok(tex != null, "CrestTexture missing")
		if tex != null:
			_ok(str(tex.get_meta("arms_kind", "")) == "gen2_06", "overlay kind not family")
			_ok(str(tex.get_meta("arms_core", "")) == CKHeraldry.core_key(fam_spec), "overlay core mismatch family")
	d.queue_free()
	await _settle(2)
	if _fail != "":
		return

	# Dossier crest: familyless → 旗徽
	d = _open_dossier(loner.id)
	await _settle(8)
	crest_btn = d.find_child("CrestPreview", true, false) as Button
	_ok(crest_btn != null and str(crest_btn.get_meta("arms_kind", "")) == "gen2_35", "loner dossier crest kind")
	_ok(crest_btn != null and crest_btn.text == Locale.t("lb_dos_crest_banner"), "loner crest label")
	if crest_btn != null:
		crest_btn.pressed.emit()
		await _settle(4)
		var overlay2 := d.find_child("CrestOverlay", true, false)
		var tex2 = overlay2.find_child("CrestTexture", true, false) if overlay2 else null
		_ok(tex2 != null and str(tex2.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "loner overlay core not company")
	d.queue_free()
	await _settle(2)
	if _fail != "":
		return

	# Rank badges distinct (wall/tree use same renderer)
	var sigs: Dictionary = {}
	for rk in ["knight", "baron", "viscount", "count", "duke", "royal"]:
		var bt := CKHeraldryRender.rank_badge(rk, 28)
		_ok(bt != null, "rank badge null " + rk)
		if bt != null:
			sigs[Marshalls.raw_to_base64(bt.get_image().get_data()).md5_text()] = rk
	_ok(sigs.size() == 6, "rank badges not distinct on surface")


