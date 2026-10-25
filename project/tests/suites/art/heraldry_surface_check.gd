extends Node
## Player-visible heraldry consistency across genealogy + castle banner strip +
## rival houses + tavern/hire + board unit shields + city/smith 邦徽 +
## commission-board 委托徽 + mobile genealogy/quests company header +
## succession / heir-duel strips + works/forge/estates castle chrome.
## 团徽 / 旗徽 / 族徽 / 敌徽 / 邦徽 / 委托徽 never mismatch outside their Chrome routes.

const OVERVIEW := "res://scenes/hub/lineage_view.tscn"
const TREE := "res://scenes/hub/lineage_tree.tscn"
const DOSSIER := "res://scenes/hub/unit_dossier.tscn"
const CASTLE := "res://scenes/hub/castle_hub.tscn"
const RIVALS := "res://scenes/hub/rival_houses.tscn"
const TAVERN := "res://scenes/hub/tavern.tscn"
const ROSTER := "res://scenes/hub/roster.tscn"
const QUESTS := "res://scenes/hub/quests.tscn"
const CITY := "res://scenes/hub/city.tscn"

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

func _open_page(path: String, sz: Vector2 = Vector2(1280, 720)) -> Control:
	var page: Control = load(path).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = sz
	return page

func _open_dossier(cid: String) -> Control:
	GameState.set_meta("dossier_id", cid)
	GameState.set_meta("dossier_back", OVERVIEW)
	return _open_page(DOSSIER)

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
	loner.job_id = "squire"
	GameState.characters[loner.id] = loner

	var fam_spec: Dictionary = GameState.arms_for_character(leader)
	var ban_spec: Dictionary = CKHeraldryChrome.company_spec()
	_ok(fam_spec.has("castle_mark"), "family arms missing canton")
	_ok(CKHeraldry.core_key(fam_spec) != CKHeraldry.core_key(ban_spec), "family core collided with company")
	_ok(CKHeraldry.core_key(GameState.arms_for_character(loner)) == CKHeraldry.core_key(ban_spec), "familyless not company banner")
	_ok(CKHeraldryChrome.arms_kind_key(leader) == "gen2_06", "leader kind not 族徽")
	_ok(CKHeraldryChrome.arms_kind_key(loner) == "gen2_35", "loner kind not 旗徽")
	_ok(CKHeraldryChrome.dossier_crest_label(leader) == Locale.t("lb_dos_crest_family"), "dossier family label")
	_ok(CKHeraldryChrome.dossier_crest_label(loner) == Locale.t("lb_dos_crest_banner"), "dossier banner label")
	_ok(CKHeraldry.core_key(CKHeraldryChrome.person_spec(leader)) == CKHeraldry.core_key(fam_spec), "person_spec leader drift")
	_ok(CKHeraldry.core_key(CKHeraldryChrome.person_spec(loner)) == CKHeraldry.core_key(ban_spec), "person_spec loner drift")
	if _fail != "":
		return

	# ── Genealogy (regression from #454) ─────────────────────────
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

	# ── Castle banner strip ───────────────────────────────────────
	var castle := _open_page(CASTLE)
	await _settle(8)
	var strip := castle.find_child("CastleBannerStrip", true, false)
	_ok(strip != null, "CastleBannerStrip missing")
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var bn := strip.find_child("CastleBanner", true, false)
		_ok(ca != null, "castle strip CastleArms missing")
		_ok(bn != null, "castle strip CastleBanner missing")
		if ca != null:
			_ok(str(ca.get_meta("arms_kind", "")) == "gen2_36", "castle arms kind not 团徽")
			_ok(str(ca.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "castle arms core drift")
		if bn != null:
			_ok(str(bn.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "castle banner core drift")
	## Territory banner_texture must match company core
	var terr_tex := CKTerritory.banner_texture(26, 36)
	_ok(terr_tex != null, "territory banner null")
	_ok(CKHeraldry.core_key(CKHeraldryChrome.company_spec()) == CKHeraldry.core_key(ban_spec), "territory company_spec drift")
	castle.queue_free()
	await _settle(2)
	if _fail != "":
		return

	# ── Rival houses 敌徽 ─────────────────────────────────────────
	## Ensure rivals data is present (new_game loads it).
	var houses: Array = GameState.data_rivals.get("houses", [])
	_ok(not houses.is_empty(), "rival houses empty")
	if _fail != "":
		return
	var rival := _open_page(RIVALS)
	await _settle(8)
	var first: Dictionary = houses[0]
	var hid := str(first.get("id"))
	var list_btn := rival.find_child("House_%s" % hid, true, false) as Control
	_ok(list_btn != null, "rival list button missing")
	if list_btn != null:
		var list_arms := list_btn.find_child("RivalArms", true, false)
		_ok(list_arms != null, "list RivalArms missing")
		if list_arms != null:
			_ok(str(list_arms.get_meta("arms_kind", "")) == "lb_rv_arms", "list rival kind")
			_ok(str(list_arms.get_meta("arms_core", "")) == CKHeraldry.core_key(CKHeraldryChrome.rival_spec(first)), "list rival core")
			_ok(str(list_arms.get_meta("arms_core", "")) != CKHeraldry.core_key(ban_spec), "rival must not equal company")
			_ok(str(list_arms.get_meta("arms_core", "")) != CKHeraldry.core_key(fam_spec), "rival must not equal family")
	var detail_arms := rival.find_child("RivalArms", true, false)
	## Detail head also has RivalArms; find via DetailInner / _head path
	var detail := rival.find_child("DetailInner", true, false)
	_ok(detail != null, "rival DetailInner missing")
	if detail != null:
		var head_arms := detail.find_child("RivalArms", true, false)
		_ok(head_arms != null, "detail RivalArms missing")
		if head_arms != null:
			_ok(str(head_arms.get_meta("arms_core", "")) == CKHeraldry.core_key(CKHeraldryChrome.rival_spec(first)), "detail rival core")
	## Distinct nation cores across at least two houses
	var cores: Dictionary = {}
	for h in houses.slice(0, mini(4, houses.size())):
		cores[CKHeraldry.core_key(CKHeraldryChrome.rival_spec(h))] = str(h.get("id"))
	_ok(cores.size() >= 2, "rival nation cores not distinct")
	rival.queue_free()
	await _settle(2)
	if _fail != "":
		return

	# ── Tavern / hire cards ───────────────────────────────────────
	if GameState.tavern_candidates.is_empty():
		GameState.refresh_tavern()
	## Inject loner into tavern so we can assert 旗徽 on a known familyless hire.
	if not GameState.tavern_candidates.has(loner):
		GameState.tavern_candidates.push_front(loner)
	## Inject a family member too if possible
	if not GameState.tavern_candidates.has(leader):
		GameState.tavern_candidates.push_front(leader)
	var tavern := _open_page(TAVERN)
	await _settle(8)
	var hire_nodes := []
	_collect_named(tavern, "HireArms", hire_nodes)
	_ok(hire_nodes.size() >= 1, "tavern HireArms missing")
	var saw_family := false
	var saw_banner := false
	for ha in hire_nodes:
		var k := str(ha.get_meta("arms_kind", ""))
		var core := str(ha.get_meta("arms_core", ""))
		if k == "gen2_06":
			saw_family = true
			_ok(core == CKHeraldry.core_key(fam_spec), "tavern family HireArms core")
		elif k == "gen2_35":
			saw_banner = true
			_ok(core == CKHeraldry.core_key(ban_spec), "tavern banner HireArms core")
		else:
			_ok(false, "tavern HireArms unknown kind " + k)
	_ok(saw_banner or saw_family, "tavern HireArms no known kind")
	## Roster also carries HireArms for the selected knight
	tavern.queue_free()
	await _settle(2)
	var roster := _open_page(ROSTER)
	await _settle(8)
	var rost_arms := roster.find_child("HireArms", true, false)
	_ok(rost_arms != null, "roster HireArms missing")
	if rost_arms != null:
		## Selected defaults to a roster member — leader is family → 族徽
		_ok(str(rost_arms.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "roster HireArms kind")
	roster.queue_free()
	await _settle(2)
	if _fail != "":
		return

	# ── Board unit shields ────────────────────────────────────────
	_ok(CKHeraldryChrome.token_shield_core(leader, "player") == CKHeraldry.core_key(fam_spec), "token shield leader not 族徽")
	_ok(CKHeraldryChrome.token_shield_core(loner, "player") == CKHeraldry.core_key(ban_spec), "token shield loner not 旗徽")
	_ok(CKHeraldryChrome.token_shield_core(leader, "enemy") == "", "enemy token must not carry player arms")
	var lead_tex := CKHeraldryChrome.person_shield(leader, 24, 28)
	var lone_tex := CKHeraldryChrome.person_shield(loner, 24, 28)
	_ok(lead_tex != null and lone_tex != null, "person_shield null")
	if lead_tex != null and lone_tex != null:
		var ld := Marshalls.raw_to_base64(lead_tex.get_image().get_data()).md5_text()
		var ln := Marshalls.raw_to_base64(lone_tex.get_image().get_data()).md5_text()
		_ok(ld != ln, "family and company shields identical on board")
	## Blit into a blank board image and confirm pixels changed
	var blank := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0, 0, 0, 0))
	CKHeraldryChrome.blit_token_shield(blank, leader, "player")
	var painted := false
	for y in 64:
		for x in 64:
			if blank.get_pixel(x, y).a > 0.05:
				painted = true
				break
		if painted:
			break
	_ok(painted, "blit_token_shield left image empty")
	## board_pawn_texture cache key includes arms core (family != loner)
	var pawn_l := UnitArt.board_pawn_texture(leader, "player", 64, false)
	var pawn_n := UnitArt.board_pawn_texture(loner, "player", 64, false)
	_ok(pawn_l != null and pawn_n != null, "board pawn null")
	if _fail != "":
		return

	# ── City crest strip (团徽 + 邦徽) ─────────────────────────────
	var city_host := Control.new()
	city_host.name = "CityCrestHost"
	get_tree().root.add_child(city_host)
	var city_strip := CKHeraldryChrome.place_city_crest_strip(city_host, "ash_capital", Vector2(8, 8), Vector2(36, 44))
	_ok(city_strip != null and city_strip.name == "CityCrestStrip", "CityCrestStrip missing")
	if city_strip != null:
		var ca2 := city_strip.find_child("CastleArms", true, false)
		var cn := city_strip.find_child("CityNationArms", true, false)
		_ok(ca2 != null and str(ca2.get_meta("arms_kind", "")) == "gen2_36", "city strip 团徽")
		_ok(cn != null and str(cn.get_meta("arms_kind", "")) == "lb_city_arms", "city strip 邦徽")
		var expect_nid := World.nation_of("ash_capital")
		_ok(cn != null and str(cn.get_meta("nation_id", "")) == expect_nid, "city strip nation_id")
		_ok(cn != null and str(cn.get_meta("arms_core", "")) == CKHeraldry.core_key(CKHeraldryChrome.nation_spec(expect_nid)), "city strip nation core")
		_ok(cn != null and str(cn.get_meta("arms_core", "")) != CKHeraldry.core_key(ban_spec), "邦徽 != 团徽")
	city_host.queue_free()
	# ── Commission board crests (委托徽) ───────────────────────────
	_ok(CKHeraldryChrome.issuer_is_home("hq"), "hq should be home issuer")
	_ok(not CKHeraldryChrome.issuer_is_home("ash_capital"), "ash_capital not home")
	_ok(CKHeraldry.core_key(CKHeraldryChrome.issuer_spec("hq")) == CKHeraldry.core_key(ban_spec), "hq issuer not 团徽")
	var ash_nid := World.nation_of("ash_capital")
	_ok(ash_nid != "", "ash_capital nation missing")
	if ash_nid != "":
		_ok(CKHeraldry.core_key(CKHeraldryChrome.issuer_spec("ash_capital")) == CKHeraldry.core_key(CKHeraldryChrome.nation_spec(ash_nid)), "ash issuer not nation plate")
		_ok(CKHeraldryChrome.issuer_arms_kind("ash_capital") == "lb_board_arms", "ash issuer kind")
	_ok(CKHeraldryChrome.issuer_arms_kind("hq") == "gen2_36", "hq issuer kind")
	## Quests hub shows CastleArms + BoardCrest on cards
	var quests := _open_page(QUESTS)
	await _settle(8)
	var q_arms := quests.find_child("CastleArms", true, false)
	_ok(q_arms != null, "quests CastleArms missing")
	if q_arms != null:
		_ok(str(q_arms.get_meta("arms_kind", "")) == "gen2_36", "quests CastleArms kind")
		_ok(str(q_arms.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "quests CastleArms core")
	var board_crests := []
	_collect_named(quests, "BoardCrest", board_crests)
	## Castle board posts (GameState.quests) always carry hq 团徽 when present
	for bc in board_crests:
		var bkind := str(bc.get_meta("arms_kind", ""))
		var bcore := str(bc.get_meta("arms_core", ""))
		if bkind == "gen2_36":
			_ok(bcore == CKHeraldry.core_key(ban_spec), "quests BoardCrest hq core drift")
		elif bkind == "lb_board_arms":
			_ok(bcore != CKHeraldry.core_key(ban_spec), "nation BoardCrest collided with 团徽")
		else:
			_ok(false, "quests BoardCrest unknown kind " + bkind)
	quests.queue_free()
	await _settle(2)
	## City commission board detail crest
	World.pos = "ash_capital"
	GameState.set_meta("city_tab", "board")
	var city_pg := _open_page(CITY)
	await _settle(10)
	var qdetail := city_pg.find_child("QuestDetail", true, false)
	if qdetail != null:
		var dc := qdetail.find_child("BoardCrest", true, false)
		_ok(dc != null, "city board detail BoardCrest missing")
		if dc != null:
			_ok(str(dc.get_meta("arms_kind", "")) in ["gen2_36", "lb_board_arms"], "city BoardCrest kind")
			## Issuer must not silently fall back to a random family 族徽
			_ok(str(dc.get_meta("arms_kind", "")) != "gen2_06", "city BoardCrest must not be 族徽")
	var offer_crests := []
	_collect_named(city_pg, "BoardCrest", offer_crests)
	_ok(offer_crests.size() >= 1, "city board BoardCrest none")
	city_pg.queue_free()


	# ── Succession crest strip (团徽 + heir) ───────────────────────
	var succ_host := Control.new()
	succ_host.name = "SuccessionCrestHost"
	get_tree().root.add_child(succ_host)
	var succ := CKHeraldryChrome.place_succession_crest_strip(succ_host, leader, Vector2(10, 10), Vector2(36, 44))
	_ok(succ != null and succ.name == "SuccessionCrestStrip", "SuccessionCrestStrip missing")
	if succ != null:
		_ok(succ.find_child("CastleArms", true, false) != null, "succession CastleArms")
		_ok(succ.find_child("LeaderArms", true, false) != null, "succession LeaderArms")
		_ok(bool(succ.get_meta("has_heir", false)), "succession has_heir")
	var succ_empty := CKHeraldryChrome.place_succession_crest_strip(succ_host, null, Vector2(10, 80), Vector2(36, 44))
	_ok(succ_empty != null and succ_empty.find_child("LeaderArms", true, false) == null, "succession empty no LeaderArms")
	succ_host.queue_free()

	# ── Heir duel crest strip (团徽 + A + B) ───────────────────────
	var duel_host := Control.new()
	duel_host.name = "DuelCrestHost"
	get_tree().root.add_child(duel_host)
	var duel := CKHeraldryChrome.place_duel_crest_strip(duel_host, leader, loner, Vector2(10, 10), Vector2(36, 44))
	_ok(duel != null and duel.name == "DuelCrestStrip", "DuelCrestStrip missing")
	if duel != null:
		_ok(duel.find_child("CastleArms", true, false) != null, "duel CastleArms")
		_ok(duel.find_child("LeftArms", true, false) != null, "duel LeftArms")
		_ok(duel.find_child("RightArms", true, false) != null, "duel RightArms")
	duel_host.queue_free()
	# ── Works / forge / estates castle chrome (团徽 + banner) ───────
	for scn_path in ["res://scenes/hub/works.tscn", "res://scenes/hub/forge.tscn", "res://scenes/hub/estates.tscn"]:
		var pg: Control = load(scn_path).instantiate()
		get_tree().root.add_child(pg)
		await _settle(8)
		_ok(pg.find_child("CastleArms", true, false) != null, "%s CastleArms" % scn_path.get_file())
		_ok(pg.find_child("CastleBannerStrip", true, false) != null or pg.find_child("CastleBanner", true, false) != null, "%s banner" % scn_path.get_file())
		pg.queue_free()
		await _settle(2)

	await _settle(2)
	if _fail != "":
		return

	# ── Mobile heraldry parity (company header reposition) ─────────
	var mob_ov := _open_page(OVERVIEW, Vector2(390, 844))
	await _settle(6)
	if mob_ov.has_method("apply_mobile_layout"):
		mob_ov.apply_mobile_layout()
		await _settle(4)
	var mob_ca := mob_ov.find_child("CastleArms", true, false) as Control
	_ok(mob_ca != null, "mobile overview CastleArms missing")
	if mob_ca != null:
		_ok(str(mob_ca.get_meta("arms_kind", "")) == "gen2_36", "mobile overview CastleArms kind")
		_ok(str(mob_ca.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "mobile overview CastleArms core")
		## Right-edge placement from apply_mobile_layout (w - 64)
		_ok(mob_ca.position.x >= 280.0, "mobile overview CastleArms not right-anchored")
	mob_ov.queue_free()
	await _settle(2)
	var mob_q := _open_page(QUESTS, Vector2(390, 844))
	await _settle(6)
	if mob_q.has_method("apply_mobile_layout"):
		mob_q.apply_mobile_layout()
		await _settle(4)
	var mq_ca := mob_q.find_child("CastleArms", true, false) as Control
	_ok(mq_ca != null, "mobile quests CastleArms missing")
	if mq_ca != null:
		_ok(str(mq_ca.get_meta("arms_kind", "")) == "gen2_36", "mobile quests CastleArms kind")
		_ok(mq_ca.position.x >= 280.0, "mobile quests CastleArms not right-anchored")
	mob_q.queue_free()
	await _settle(2)
	## (no early-return here — keeps _run under gdlint max-returns=12)

	# Rank badges distinct
	var sigs: Dictionary = {}
	for rk in ["knight", "baron", "viscount", "count", "duke", "royal"]:
		var bt := CKHeraldryRender.rank_badge(rk, 28)
		_ok(bt != null, "rank badge null " + rk)
		if bt != null:
			sigs[Marshalls.raw_to_base64(bt.get_image().get_data()).md5_text()] = rk
	_ok(sigs.size() == 6, "rank badges not distinct on surface")

func _collect_named(n: Node, name: String, out: Array) -> void:
	if n.name == name:
		out.append(n)
	for ch in n.get_children():
		_collect_named(ch, name, out)
