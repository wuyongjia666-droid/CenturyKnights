extends Node
## Player-visible heraldry consistency across genealogy + castle banner strip +
## rival houses + tavern/hire + board unit shields + city/smith 邦徽 +
## codex/shrine/rite crests + battle/danger aftermath + commission-board 委托徽 +
## mobile genealogy/quests company header + succession / heir-duel strips +
## court gazette / year-card chronicle + title/settings/save/pause shell crests +
## works/forge/estates castle chrome.
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


	# ── Nation crest strip (团徽 + 邦徽) ───────────────────────────
	var nat_host := Control.new()
	nat_host.name = "NationCrestHost"
	get_tree().root.add_child(nat_host)
	var nat_ids: Array = CKBloodline.nation_ids()
	var sample_nid := str(nat_ids[0]) if not nat_ids.is_empty() else "ashbanner"
	var nat_strip := CKHeraldryChrome.place_nation_crest_strip(nat_host, sample_nid, Vector2(10, 10), Vector2(36, 44))
	_ok(nat_strip != null and nat_strip.name == "NationCrestStrip", "NationCrestStrip missing")
	if nat_strip != null:
		var nca := nat_strip.find_child("CastleArms", true, false)
		var ncn := nat_strip.find_child("CityNationArms", true, false)
		_ok(nca != null and str(nca.get_meta("arms_kind", "")) == "gen2_36", "nation strip 团徽")
		_ok(ncn != null and str(ncn.get_meta("arms_kind", "")) == "lb_city_arms", "nation strip 邦徽")
		_ok(ncn != null and str(ncn.get_meta("nation_id", "")) == sample_nid, "nation strip nation_id")
		_ok(ncn != null and str(ncn.get_meta("arms_core", "")) != CKHeraldry.core_key(ban_spec), "邦徽 != 团徽 on nation strip")
	nat_host.queue_free()

	# ── Banner-rite crest strip (团徽 + heir) ──────────────────────
	var rite_host := Control.new()
	rite_host.name = "RiteCrestHost"
	get_tree().root.add_child(rite_host)
	var rite_strip := CKHeraldryChrome.place_rite_crest_strip(rite_host, leader, Vector2(10, 10), Vector2(36, 44))
	_ok(rite_strip != null and rite_strip.name == "RiteCrestStrip", "RiteCrestStrip missing")
	if rite_strip != null:
		_ok(rite_strip.find_child("CastleArms", true, false) != null, "rite CastleArms")
		var rla := rite_strip.find_child("LeaderArms", true, false)
		_ok(rla != null, "rite LeaderArms")
		_ok(bool(rite_strip.get_meta("has_heir", false)), "rite has_heir meta")
	var rite_empty := CKHeraldryChrome.place_rite_crest_strip(rite_host, null, Vector2(10, 80), Vector2(36, 44))
	_ok(rite_empty != null and rite_empty.find_child("LeaderArms", true, false) == null, "rite empty no LeaderArms")
	rite_host.queue_free()

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


	# ── Aftermath crest strip (团徽 + 敌徽) ────────────────────────
	var host := Control.new()
	host.name = "AftermathHost"
	get_tree().root.add_child(host)
	var af_strip := CKHeraldryChrome.place_aftermath_crest_strip(host, Vector2(10, 10), "ashbanner", Vector2(36, 44))
	_ok(af_strip != null and af_strip.name == "AftermathCrestStrip", "AftermathCrestStrip missing")
	if af_strip != null:
		var ca := af_strip.find_child("CastleArms", true, false)
		var foe := af_strip.find_child("FoeArms", true, false)
		_ok(ca != null, "aftermath CastleArms missing")
		_ok(foe != null, "aftermath FoeArms missing")
		if ca != null:
			_ok(str(ca.get_meta("arms_kind", "")) == "gen2_36", "aftermath company not 团徽")
			_ok(str(ca.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "aftermath company core drift")
		if foe != null:
			_ok(str(foe.get_meta("arms_kind", "")) == "lb_rv_arms", "aftermath foe not 敌徽")
			_ok(str(foe.get_meta("nation_id", "")) == "ashbanner", "aftermath foe nation_id")
			_ok(str(foe.get_meta("arms_core", "")) == CKHeraldry.core_key(CKHeraldryChrome.nation_spec("ashbanner")), "aftermath foe core")
			_ok(str(foe.get_meta("arms_core", "")) != CKHeraldry.core_key(ban_spec), "foe must not equal company")
	## Company-only strip (halt / calm road) has no FoeArms
	var af_halt := CKHeraldryChrome.place_aftermath_crest_strip(host, Vector2(10, 80), "", Vector2(36, 44))
	_ok(af_halt != null, "company-only strip missing")
	if af_halt != null:
		_ok(af_halt.find_child("CastleArms", true, false) != null, "halt CastleArms missing")
		_ok(af_halt.find_child("FoeArms", true, false) == null, "halt must not show FoeArms")
	host.queue_free()

	# ── Atlas travel / camp / encounter crest strips ────────────────
	var atlas_host := Control.new()
	atlas_host.name = "AtlasTravelCrestHost"
	get_tree().root.add_child(atlas_host)
	var travel_strip := CKHeraldryChrome.place_travel_crest_strip(atlas_host, Vector2(10, 10), "ashbanner", Vector2(36, 44))
	_ok(travel_strip != null and travel_strip.name == "TravelCrestStrip", "TravelCrestStrip missing")
	if travel_strip != null:
		var tca := travel_strip.find_child("CastleArms", true, false)
		var tterr := travel_strip.find_child("TerritoryArms", true, false)
		_ok(tca != null and str(tca.get_meta("arms_kind", "")) == "gen2_36", "travel 团徽")
		_ok(tterr != null and str(tterr.get_meta("arms_kind", "")) == "lb_territory_arms", "travel 领地徽")
		_ok(tterr != null and str(tterr.get_meta("nation_id", "")) == "ashbanner", "travel territory nation")
		_ok(str(travel_strip.get_meta("nation_id", "")) == "ashbanner", "travel strip meta")
	var travel_solo := CKHeraldryChrome.place_travel_crest_strip(atlas_host, Vector2(10, 80), "", Vector2(36, 44))
	_ok(travel_solo != null and travel_solo.find_child("TerritoryArms", true, false) == null, "travel solo no TerritoryArms")
	var camp_strip := CKHeraldryChrome.place_camp_crest_strip(atlas_host, Vector2(10, 150), "ashbanner", Vector2(36, 44))
	_ok(camp_strip != null and camp_strip.name == "CampCrestStrip", "CampCrestStrip missing")
	if camp_strip != null:
		_ok(camp_strip.find_child("CastleArms", true, false) != null, "camp CastleArms")
		var cterr := camp_strip.find_child("TerritoryArms", true, false)
		_ok(cterr != null and str(cterr.get_meta("arms_kind", "")) == "lb_territory_arms", "camp 领地徽")
	var enc_strip := CKHeraldryChrome.place_encounter_crest_strip(atlas_host, Vector2(10, 220), "ashbanner", Vector2(36, 44))
	_ok(enc_strip != null and enc_strip.name == "EncounterCrestStrip", "EncounterCrestStrip missing")
	if enc_strip != null:
		var eca := enc_strip.find_child("CastleArms", true, false)
		var efoe := enc_strip.find_child("FoeArms", true, false)
		_ok(eca != null and str(eca.get_meta("arms_kind", "")) == "gen2_36", "encounter 团徽")
		_ok(efoe != null and str(efoe.get_meta("arms_kind", "")) == "lb_rv_arms", "encounter 敌徽")
		_ok(efoe != null and str(efoe.get_meta("nation_id", "")) == "ashbanner", "encounter foe nation")
	atlas_host.queue_free()

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

	# ── Shell crest strip (title / settings / save / pause) ─────────
	var shell_host := Control.new()
	shell_host.name = "ShellCrestHost"
	get_tree().root.add_child(shell_host)
	var shell_strip := CKHeraldryChrome.place_shell_crest_strip(shell_host, Vector2(10, 10), Vector2(44, 52), Vector2(28, 38))
	_ok(shell_strip != null and shell_strip.name == "ShellCrestStrip", "ShellCrestStrip missing")
	if shell_strip != null:
		var sca := shell_strip.find_child("CastleArms", true, false)
		var scb := shell_strip.find_child("CastleBanner", true, false)
		_ok(sca != null and str(sca.get_meta("arms_kind", "")) == "gen2_36", "shell strip 团徽")
		_ok(scb != null and str(scb.get_meta("arms_kind", "")) == "gen2_36", "shell strip 旗徽")
		_ok(sca != null and str(sca.get_meta("arms_core", "")) == CKHeraldry.core_key(ban_spec), "shell arms_core")
	var shell_row := HBoxContainer.new()
	shell_host.add_child(shell_row)
	var slot_arms := CKHeraldryChrome.attach_save_row_arms(shell_row, Vector2(36, 44))
	_ok(slot_arms != null and slot_arms.name == "SlotArms", "SlotArms attach")
	_ok(shell_row.get_child_count() > 0 and shell_row.get_child(0).name == "SlotArms", "SlotArms prepended")
	shell_host.queue_free()

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


	# ── Court gazette crest strip (团徽 + 朝徽) ────────────────────
	var gaz_host := Control.new()
	gaz_host.name = "GazetteCrestHost"
	get_tree().root.add_child(gaz_host)
	var nid := World.nation_of(str(World.pos))
	if nid == "":
		nid = "ashbanner"
	var gaz := CKHeraldryChrome.place_gazette_crest_strip(gaz_host, nid, Vector2(10, 10), Vector2(36, 44))
	_ok(gaz != null and gaz.name == "GazetteCrestStrip", "GazetteCrestStrip missing")
	if gaz != null:
		_ok(gaz.find_child("CastleArms", true, false) != null, "gazette CastleArms")
		var gna := gaz.find_child("GazetteNationArms", true, false)
		_ok(gna != null, "gazette GazetteNationArms")
		if gna != null:
			_ok(str(gna.get_meta("arms_kind", "")) == "lb_gazette_arms", "gazette arms_kind")
			_ok(str(gna.get_meta("nation_id", "")) == nid, "gazette nation_id")
	gaz_host.queue_free()

	# ── Year-card person arms helper ───────────────────────────────
	var yc_host := VBoxContainer.new()
	yc_host.name = "YearArmsHost"
	get_tree().root.add_child(yc_host)
	CKHeraldryChrome.attach_yearcard_row_arms(yc_host, leader, Vector2(32, 38))
	_ok(yc_host.find_child("YearArms", true, false) != null, "YearArms missing")
	yc_host.queue_free()

	# ── Live court_news page chrome ────────────────────────────────
	## Seed one gazette event so row arms mount.
	if typeof(World.get("royal_courts")) != TYPE_DICTIONARY:
		World.royal_courts = {"nations": {}}
	var nations: Dictionary = World.royal_courts.get("nations", {})
	if typeof(nations) != TYPE_DICTIONARY:
		nations = {}
	var house: Dictionary = nations.get(nid, {})
	if typeof(house) != TYPE_DICTIONARY:
		house = {}
	var log: Array = house.get("log", [])
	if typeof(log) != TYPE_ARRAY:
		log = []
	log.append({"year": int(Calendar.year), "kind": "birth", "text": "surface gazette seed"})
	house["log"] = log
	nations[nid] = house
	World.royal_courts["nations"] = nations
	var news_pg := _open_page("res://scenes/hub/court_news.tscn")
	await _settle(10)
	_ok(news_pg.find_child("GazetteCrestStrip", true, false) != null, "court_news GazetteCrestStrip")
	_ok(news_pg.find_child("CastleBannerStrip", true, false) != null, "court_news CastleBannerStrip")
	_ok(news_pg.find_child("GazetteNationArms", true, false) != null, "court_news GazetteNationArms")
	news_pg.queue_free()
	await _settle(2)

	# ── Field / yeartrace / purse chrome ───────────────────────
	var field_host := Control.new()
	field_host.name = "FieldCrestHost"
	get_tree().root.add_child(field_host)
	var field_strip := CKHeraldryChrome.place_field_crest_strip(field_host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(field_strip != null and field_strip.name == "FieldCrestStrip", "FieldCrestStrip missing")
	if field_strip != null:
		_ok(field_strip.find_child("CastleArms", true, false) != null, "field CastleArms")
		var fbn := field_strip.find_child("FieldBanner", true, false)
		_ok(fbn != null and str(fbn.get_meta("arms_kind", "")) == "lb_field_arms", "field FieldBanner kind")
	var frow := HBoxContainer.new()
	frow.name = "FieldRowProbe"
	field_host.add_child(frow)
	CKHeraldryChrome.attach_field_row_arms(frow, leader, Vector2(28, 34))
	_ok(frow.find_child("FieldRowArms", true, false) != null, "FieldRowArms attached")
	field_host.queue_free()

	var yt_panel := VBoxContainer.new()
	yt_panel.name = "YeartraceProbe"
	get_tree().root.add_child(yt_panel)
	CKHeraldryChrome.attach_yeartrace_arms(yt_panel, leader, Vector2(28, 34))
	_ok(yt_panel.find_child("YeartraceArms", true, false) != null, "YeartraceArms person")
	CKHeraldryChrome.attach_yeartrace_arms(yt_panel, null, Vector2(28, 34))
	var yta := yt_panel.find_child("YeartraceArms", true, false)
	_ok(yta != null and yta.name == "YeartraceArms", "YeartraceArms house/company")
	yt_panel.queue_free()

	var purse_host := VBoxContainer.new()
	purse_host.name = "PurseProbe"
	get_tree().root.add_child(purse_host)
	var plate := CKHeraldryChrome.place_purse_plate(purse_host, leader, 7, Vector2(28, 34))
	_ok(plate != null and plate.name == "PursePlate", "PursePlate missing")
	if plate != null:
		_ok(plate.find_child("PurseArms", true, false) != null, "PurseArms")
		_ok(int(plate.get_meta("purse_silver", -1)) == 7, "PursePlate silver meta")
	purse_host.queue_free()


	# ── Market / skill / hourglass / castle-view / blood chrome ─
	var mkt_host := Control.new()
	mkt_host.name = "MarketCrestHost"
	get_tree().root.add_child(mkt_host)
	var mkt := CKHeraldryChrome.place_market_crest_strip(mkt_host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(mkt != null and mkt.name == "MarketCrestStrip", "MarketCrestStrip missing")
	if mkt != null:
		_ok(mkt.find_child("CastleArms", true, false) != null, "market CastleArms")
		var mbn := mkt.find_child("MarketBanner", true, false)
		_ok(mbn != null and str(mbn.get_meta("arms_kind", "")) == "lb_market_arms", "market MarketBanner kind")
	mkt_host.queue_free()

	var sk_host := Control.new()
	sk_host.name = "SkillCrestHost"
	get_tree().root.add_child(sk_host)
	var sk := CKHeraldryChrome.place_skill_crest_strip(sk_host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(sk != null and sk.name == "SkillCrestStrip", "SkillCrestStrip missing")
	if sk != null:
		var sbn := sk.find_child("SkillBanner", true, false)
		_ok(sbn != null and str(sbn.get_meta("arms_kind", "")) == "lb_skill_arms", "skill SkillBanner kind")
	var sk_row := HBoxContainer.new()
	sk_host.add_child(sk_row)
	CKHeraldryChrome.attach_skill_person_arms(sk_row, leader, Vector2(28, 34))
	_ok(sk_row.find_child("SkillPersonArms", true, false) != null, "SkillPersonArms attached")
	sk_host.queue_free()

	var hg_host := Control.new()
	hg_host.name = "HourglassCrestHost"
	get_tree().root.add_child(hg_host)
	var hg := CKHeraldryChrome.place_hourglass_crest_strip(hg_host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(hg != null and hg.name == "HourglassCrestStrip", "HourglassCrestStrip missing")
	if hg != null:
		var hbn := hg.find_child("HourglassBanner", true, false)
		_ok(hbn != null and str(hbn.get_meta("arms_kind", "")) == "lb_hourglass_arms", "hourglass banner kind")
	hg_host.queue_free()

	var cv_host := Control.new()
	cv_host.name = "CastleViewCrestHost"
	get_tree().root.add_child(cv_host)
	var cv := CKHeraldryChrome.place_castle_view_crest_strip(cv_host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(cv != null and cv.name == "CastleViewCrestStrip", "CastleViewCrestStrip missing")
	if cv != null:
		var cbn := cv.find_child("CastleViewBanner", true, false)
		_ok(cbn != null and str(cbn.get_meta("arms_kind", "")) == "lb_castle_view_arms", "castle_view banner kind")
	cv_host.queue_free()

	var bd_host := Control.new()
	bd_host.name = "BloodCrestHost"
	get_tree().root.add_child(bd_host)
	var bd := CKHeraldryChrome.place_blood_crest_strip(bd_host, Vector2(10, 10), Vector2(36, 44), Vector2(24, 34))
	_ok(bd != null and bd.name == "BloodCrestStrip", "BloodCrestStrip missing")
	if bd != null:
		var bbn := bd.find_child("BloodBanner", true, false)
		_ok(bbn != null and str(bbn.get_meta("arms_kind", "")) == "lb_blood_arms", "blood banner kind")
	var bd_row := HBoxContainer.new()
	bd_host.add_child(bd_row)
	CKHeraldryChrome.attach_blood_queue_arms(bd_row, leader, Vector2(26, 32))
	_ok(bd_row.find_child("BloodQueueArms", true, false) != null, "BloodQueueArms attached")
	bd_host.queue_free()

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
