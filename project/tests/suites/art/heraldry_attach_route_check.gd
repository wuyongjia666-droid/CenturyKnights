extends Node
## Fat Field route coverage — attach_* + place_* child field_route live meta E2E
## for tavern/hire, castle view, board, genealogy wall, marriage/succession,
## deploy muster, atlas travel/camp/encounter/aftermath, city/nation/rite/muster,
## battle HUD, field banner, hourglass/blood/market/skill/roster banners,
## plus court gazette / yearcard / yeartrace / purse / dossier / rival / title.
## Source vows.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("HERALDRY ATTACH ROUTE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry attach route: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("战旗", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")


func _run() -> void:
	_boot()
	var leader = GameState.get_leader()
	_ok(leader != null, "leader for attach E2E")
	await _card_and_forecast(leader)
	await _report_annex_forge(leader)
	await _wall_tree_house_train(leader)
	await _place_major_strips(leader)
	await _atlas_city_battle_strips(leader)
	await _court_chronicle_dossier(leader)
	_source_contracts()


func _card_and_forecast(leader) -> void:
	var card := Control.new()
	card.name = "UnitCardHost"
	card.size = Vector2(200, 120)
	add_child(card)
	CKHeraldryField.attach_card_arms(card, leader, "player", "")
	await _settle()
	var ca := card.get_node_or_null("CardArms")
	_ok(ca != null, "CardArms present")
	_ok(ca != null and str(ca.get_meta("field_route", "")) == "card_arms", "card_arms field_route")
	CKHeraldryField.attach_card_arms(card, leader, "enemy", "ashbanner")
	await _settle()
	ca = card.get_node_or_null("CardArms")
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) != "gen2_36", "enemy card not 团徽")
	_ok(ca != null and str(ca.get_meta("field_route", "")) == "card_arms", "enemy card_arms route")
	card.queue_free()
	await _settle()

	var panel := Control.new()
	panel.name = "ForecastHost"
	panel.size = Vector2(360, 80)
	add_child(panel)
	CKHeraldryField.pin_forecast_arms(panel, leader, "player", "ashbanner")
	await _settle()
	var ours := panel.get_node_or_null("ForecastOursArms")
	var foe := panel.get_node_or_null("ForecastFoeArms")
	_ok(ours != null and str(ours.get_meta("field_route", "")) == "forecast_ours", "forecast_ours route")
	_ok(foe != null and str(foe.get_meta("field_route", "")) == "forecast_foe", "forecast_foe route")
	_ok(bool(panel.get_meta("forecast_has_foe", false)), "forecast_has_foe meta")
	panel.queue_free()
	await _settle()


func _report_annex_forge(leader) -> void:
	var root := Control.new()
	root.name = "ReportHost"
	add_child(root)
	var row := CKHeraldryField.attach_report_row_arms(root, leader, Vector2(4, 4))
	_ok(row != null and str(row.get_meta("field_route", "")) == "report_row", "report_row route")
	var report := CKHeraldryField.place_report_crest_strip(root, Vector2(4, 40), "ashbanner")
	_ok(report != null and str(report.get_meta("field_route", "")) == "report_strip", "report_strip route")
	var rfoe := report.find_child("FoeArms", true, false) if report != null else null
	_ok(rfoe != null and str(rfoe.get_meta("field_route", "")) == "report_foe", "report_foe route")
	var rbn := report.find_child("ReportBanner", true, false) if report != null else null
	_ok(rbn != null and str(rbn.get_meta("field_route", "")) == "report_banner", "report_banner route")
	_ok(rbn != null and str(rbn.get_meta("arms_kind", "")) == "lb_report_arms", "report_banner kind")
	var annex := Control.new()
	annex.name = "AnnexRow"
	root.add_child(annex)
	var aa := CKHeraldryField.attach_annex_row_arms(annex, "person", leader)
	_ok(aa != null and str(aa.get_meta("field_route", "")) == "annex_row", "annex_row route")
	var forge := Control.new()
	forge.name = "ForgeRow"
	forge.size = Vector2(320, 48)
	root.add_child(forge)
	var fa := CKHeraldryField.attach_forge_slot_arms(forge, leader)
	_ok(fa != null and str(fa.get_meta("field_route", "")) == "forge_slot", "forge_slot route")
	var fstrip := CKHeraldryField.place_forge_focus_strip(root, leader, Vector2(4, 100))
	_ok(fstrip != null and str(fstrip.get_meta("field_route", "")) == "forge_focus", "forge_focus route")
	var ff := fstrip.find_child("ForgeFocusArms", true, false) if fstrip != null else null
	_ok(ff != null and str(ff.get_meta("field_route", "")) == "forge_focus_arms", "forge_focus_arms route")
	var fbn := fstrip.find_child("ForgeBanner", true, false) if fstrip != null else null
	_ok(fbn != null and str(fbn.get_meta("field_route", "")) == "forge_banner", "forge_banner route")
	_ok(fbn != null and str(fbn.get_meta("arms_kind", "")) == "lb_forge_arms", "forge_banner kind")
	var fco := fstrip.find_child("CastleArms", true, false) if fstrip != null else null
	_ok(fco != null and str(fco.get_meta("field_route", "")) == "strip_company", "forge strip_company")
	var seal := Control.new()
	seal.name = "SealRow"
	root.add_child(seal)
	var sa := CKHeraldryField.attach_affairs_seal_arms(seal, leader)
	_ok(sa != null and str(sa.get_meta("field_route", "")) == "affairs_seal", "affairs_seal route")
	root.queue_free()
	await _settle()


func _wall_tree_house_train(leader) -> void:
	var wall := Control.new()
	wall.name = "WallTile"
	wall.size = Vector2(120, 160)
	add_child(wall)
	CKHeraldryField.attach_wall_tile_arms(wall, leader, Vector2(120, 160))
	await _settle()
	var cell := wall.get_node_or_null("CellArms")
	_ok(cell != null and str(cell.get_meta("field_route", "")) == "wall_tile", "wall_tile route")
	_ok(wall.get_node_or_null("CellBadge") != null, "wall CellBadge")
	wall.queue_free()
	await _settle()

	var tree := Control.new()
	tree.name = "TreeNode"
	tree.size = Vector2(80, 60)
	add_child(tree)
	CKHeraldryField.attach_tree_node_arms(tree, leader, Vector2(80, 60))
	await _settle()
	var node := tree.get_node_or_null("NodeArms")
	_ok(node != null and str(node.get_meta("field_route", "")) == "tree_node", "tree_node route")
	tree.queue_free()
	await _settle()

	var house := Control.new()
	house.name = "HouseCard"
	house.size = Vector2(200, 160)
	add_child(house)
	var ha := CKHeraldryField.attach_house_card_arms(house, leader, Rect2(10, 10, 180, 140))
	_ok(ha != null and str(ha.get_meta("field_route", "")) == "house_card", "house_card route")
	house.queue_free()
	await _settle()

	var train := HBoxContainer.new()
	train.name = "TrainRow"
	add_child(train)
	var ta := CKHeraldryField.attach_train_row_arms(train, leader)
	_ok(ta != null and str(ta.get_meta("field_route", "")) == "train_row", "train_row route")
	train.queue_free()
	await _settle()


func _place_major_strips(leader) -> void:
	var root := Control.new()
	root.name = "PlaceHost"
	root.size = Vector2(1280, 720)
	add_child(root)

	var tavern := CKHeraldryField.place_tavern_crest_strip(root, leader, Vector2(8, 8))
	_ok(tavern != null and str(tavern.get_meta("field_route", "")) == "tavern_strip", "place tavern_strip")
	var tf := tavern.find_child("HireFocusArms", true, false) if tavern != null else null
	_ok(tf != null and str(tf.get_meta("field_route", "")) == "tavern_focus", "place tavern_focus")
	var tco := tavern.find_child("CastleArms", true, false) if tavern != null else null
	_ok(tco != null and str(tco.get_meta("field_route", "")) == "strip_company", "tavern strip_company")
	var tbn := tavern.find_child("TavernBanner", true, false) if tavern != null else null
	_ok(tbn != null and str(tbn.get_meta("field_route", "")) == "tavern_banner", "place tavern_banner")
	_ok(tbn != null and str(tbn.get_meta("arms_kind", "")) == "lb_tavern_arms", "place tavern_banner kind")

	var hire := Control.new()
	hire.name = "HirePlate"
	hire.size = Vector2(160, 200)
	root.add_child(hire)
	var hp := CKHeraldryField.attach_hire_plate_arms(hire, leader, Rect2(0, 0, 120, 150))
	_ok(hp != null and str(hp.get_meta("field_route", "")) == "hire_plate", "place hire_plate")

	var cv := CKHeraldryField.place_castle_view_crest_strip(root, Vector2(200, 8))
	_ok(cv != null and str(cv.get_meta("field_route", "")) == "castle_view_strip", "place castle_view_strip")
	var bn := cv.find_child("CastleViewBanner", true, false) if cv != null else null
	_ok(bn != null and str(bn.get_meta("field_route", "")) == "castle_view_banner", "place castle_view_banner")
	var hang := CKHeraldryField.place_castle_hang_banner(root, Vector2(280, 8))
	_ok(hang != null and str(hang.get_meta("field_route", "")) == "castle_view_hang", "place castle_view_hang")
	_ok(hang.find_child("HangCloth", true, false) != null and str(hang.find_child("HangCloth", true, false).get_meta("field_route", "")) == "castle_view_hang_cloth", "place castle_view_hang_cloth")

	var pan := CKHeraldryField.place_panorama_lineage_strip(root, [leader], Vector2(320, 8))
	_ok(pan != null and str(pan.get_meta("field_route", "")) == "panorama_lineage", "place panorama_lineage")
	var pp := pan.find_child("PanoramaPerson_%s" % str(leader.id), true, false) if pan != null else null
	_ok(pp != null and str(pp.get_meta("field_route", "")) == "panorama_person", "place panorama_person")

	var home := CKHeraldryField.place_home_lineage_row(root, [leader], Vector2(480, 8))
	_ok(home != null and str(home.get_meta("field_route", "")) == "home_lineage", "place home_lineage")
	var hl := home.find_child("HomeLeaderArms", true, false) if home != null else null
	_ok(hl != null and str(hl.get_meta("field_route", "")) == "home_leader", "place home_leader")

	var hub := CKHeraldryField.place_banner_plate(root, Vector2(640, 8), Vector2(40, 48), Vector2(26, 36))
	_ok(hub != null and str(hub.get_meta("field_route", "")) == "banner_plate", "place banner_plate")
	var hco := hub.find_child("CastleArms", true, false) if hub != null else null
	_ok(hco != null and str(hco.get_meta("field_route", "")) == "strip_company", "hub strip_company")
	var hbn := hub.find_child("CastleBanner", true, false) if hub != null else null
	_ok(hbn != null and str(hbn.get_meta("field_route", "")) == "castle_hub_banner", "place castle_hub_banner")

	var tok := Control.new()
	tok.name = "PartyToken"
	tok.size = Vector2(26, 26)
	root.add_child(tok)
	var ta_arms := CKHeraldryField.attach_party_token_arms(tok)
	_ok(ta_arms != null and str(ta_arms.get_meta("field_route", "")) == "atlas_party", "place atlas_party")
	_ok(str(tok.get_meta("field_route", "")) == "atlas_party_token", "place atlas_party_token")

	var board := Control.new()
	board.name = "BoardRow"
	board.size = Vector2(300, 48)
	root.add_child(board)
	var ba := CKHeraldryField.attach_board_offer_arms(board, "hq")
	_ok(ba != null and str(ba.get_meta("field_route", "")) == "board_offer", "place board_offer")

	var mar := CKHeraldryField.place_marriage_crest_strip(root, leader, leader, Vector2(8, 80))
	_ok(mar != null and str(mar.get_meta("field_route", "")) == "marriage_strip", "place marriage_strip")
	var mco := mar.find_child("CastleArms", true, false) if mar != null else null
	var ml := mar.find_child("LeftArms", true, false) if mar != null else null
	var mr := mar.find_child("RightArms", true, false) if mar != null else null
	var mbn := mar.find_child("MarriageBanner", true, false) if mar != null else null
	_ok(mco != null and str(mco.get_meta("field_route", "")) == "strip_company", "place marriage strip_company")
	_ok(ml != null and str(ml.get_meta("field_route", "")) == "marriage_left", "place marriage_left")
	_ok(mr != null and str(mr.get_meta("field_route", "")) == "marriage_right", "place marriage_right")
	_ok(mbn != null and str(mbn.get_meta("field_route", "")) == "marriage_banner", "place marriage_banner")
	_ok(mbn != null and str(mbn.get_meta("arms_kind", "")) == "lb_marriage_arms", "place marriage_banner kind")

	var succ := CKHeraldryField.place_succession_crest_strip(root, leader, Vector2(280, 80))
	_ok(succ != null and str(succ.get_meta("field_route", "")) == "succession_strip", "place succession_strip")
	var sco := succ.find_child("CastleArms", true, false) if succ != null else null
	var sh := succ.find_child("LeaderArms", true, false) if succ != null else null
	var sbn := succ.find_child("SuccessionBanner", true, false) if succ != null else null
	_ok(sco != null and str(sco.get_meta("field_route", "")) == "strip_company", "place succession strip_company")
	_ok(sh != null and str(sh.get_meta("field_route", "")) == "succession_heir", "place succession_heir")
	_ok(sbn != null and str(sbn.get_meta("field_route", "")) == "succession_banner", "place succession_banner")
	_ok(sbn != null and str(sbn.get_meta("arms_kind", "")) == "lb_succession_arms", "place succession_banner kind")

	var duel := CKHeraldryField.place_duel_crest_strip(root, leader, leader, Vector2(420, 80))
	_ok(duel != null and str(duel.get_meta("field_route", "")) == "duel_strip", "place duel_strip")
	var dco := duel.find_child("CastleArms", true, false) if duel != null else null
	var dl := duel.find_child("LeftArms", true, false) if duel != null else null
	var dr := duel.find_child("RightArms", true, false) if duel != null else null
	var dbn := duel.find_child("DuelBanner", true, false) if duel != null else null
	_ok(dco != null and str(dco.get_meta("field_route", "")) == "strip_company", "place duel strip_company")
	_ok(dl != null and str(dl.get_meta("field_route", "")) == "duel_left", "place duel_left")
	_ok(dr != null and str(dr.get_meta("field_route", "")) == "duel_right", "place duel_right")
	_ok(dbn != null and str(dbn.get_meta("field_route", "")) == "duel_banner", "place duel_banner")
	_ok(dbn != null and str(dbn.get_meta("arms_kind", "")) == "lb_duel_arms", "place duel_banner kind")

	var muster := CKHeraldryField.place_deploy_muster_strip(root, leader, Vector2(8, 160))
	_ok(muster != null and str(muster.get_meta("field_route", "")) == "deploy_muster", "place deploy_muster")
	var mlr := muster.find_child("LeaderArms", true, false) if muster != null else null
	_ok(mlr != null and str(mlr.get_meta("field_route", "")) == "deploy_muster_leader", "place deploy_muster_leader")

	var slot := Control.new()
	slot.name = "DeploySlot"
	slot.size = Vector2(120, 160)
	root.add_child(slot)
	var sa := CKHeraldryField.attach_deploy_slot_arms(slot, leader, Rect2(0, 0, 100, 140))
	_ok(sa != null and str(sa.get_meta("field_route", "")) == "deploy_slot", "place deploy_slot")

	var reserve := CKHeraldryField.place_reserve_crest_strip(root, leader, Vector2(200, 160))
	_ok(reserve != null and str(reserve.get_meta("field_route", "")) == "reserve_strip", "place reserve_strip")
	var rf := reserve.find_child("ReserveArms", true, false) if reserve != null else null
	_ok(rf != null and str(rf.get_meta("field_route", "")) == "reserve_focus", "place reserve_focus")
	var rsvbn := reserve.find_child("ReserveBanner", true, false) if reserve != null else null
	_ok(rsvbn != null and str(rsvbn.get_meta("field_route", "")) == "reserve_banner", "place reserve_banner")
	_ok(rsvbn != null and str(rsvbn.get_meta("arms_kind", "")) == "lb_reserve_arms", "place reserve_banner kind")

	var trainf := CKHeraldryField.place_train_focus_strip(root, leader, Vector2(360, 160))
	_ok(trainf != null and str(trainf.get_meta("field_route", "")) == "train_focus", "place train_focus")
	var tfa := trainf.find_child("TrainFocusArms", true, false) if trainf != null else null
	_ok(tfa != null and str(tfa.get_meta("field_route", "")) == "train_focus_arms", "place train_focus_arms")
	var trbn := trainf.find_child("TrainBanner", true, false) if trainf != null else null
	_ok(trbn != null and str(trbn.get_meta("field_route", "")) == "train_banner", "place train_banner")
	_ok(trbn != null and str(trbn.get_meta("arms_kind", "")) == "lb_train_arms", "place train_banner kind")
	var trco := trainf.find_child("CastleArms", true, false) if trainf != null else null
	_ok(trco != null and str(trco.get_meta("field_route", "")) == "strip_company", "place train strip_company")

	var shrine := CKHeraldryField.place_shrine_heal_strip(root, leader, Vector2(520, 160))
	_ok(shrine != null and str(shrine.get_meta("field_route", "")) == "shrine_heal", "place shrine_heal")
	var hf := shrine.find_child("HealFocusArms", true, false) if shrine != null else null
	_ok(hf != null and str(hf.get_meta("field_route", "")) == "shrine_heal_focus", "place shrine_heal_focus")
	var shbn := shrine.find_child("ShrineBanner", true, false) if shrine != null else null
	_ok(shbn != null and str(shbn.get_meta("field_route", "")) == "shrine_banner", "place shrine_banner")
	_ok(shbn != null and str(shbn.get_meta("arms_kind", "")) == "lb_shrine_arms", "place shrine_banner kind")
	var shco := shrine.find_child("CastleArms", true, false) if shrine != null else null
	_ok(shco != null and str(shco.get_meta("field_route", "")) == "strip_company", "place shrine strip_company")

	root.queue_free()
	await _settle()



func _atlas_city_battle_strips(leader) -> void:
	var root := Control.new()
	root.name = "AtlasBattleHost"
	root.size = Vector2(1280, 720)
	add_child(root)

	var travel := CKHeraldryField.place_travel_crest_strip(root, Vector2(8, 8), "ashbanner")
	_ok(travel != null and str(travel.get_meta("field_route", "")) == "travel_strip", "travel_strip route")
	var tco := travel.find_child("CastleArms", true, false) if travel != null else null
	var tter := travel.find_child("TerritoryArms", true, false) if travel != null else null
	_ok(tco != null and str(tco.get_meta("field_route", "")) == "strip_company", "travel strip_company")
	_ok(tter != null and str(tter.get_meta("field_route", "")) == "travel_territory", "travel_territory")
	var tvbn := travel.find_child("TravelBanner", true, false) if travel != null else null
	_ok(tvbn != null and str(tvbn.get_meta("field_route", "")) == "travel_banner", "travel_banner")
	_ok(tvbn != null and str(tvbn.get_meta("arms_kind", "")) == "lb_travel_arms", "travel_banner kind")

	var camp := CKHeraldryField.place_camp_crest_strip(root, Vector2(200, 8), "ashbanner")
	_ok(camp != null and str(camp.get_meta("field_route", "")) == "camp_strip", "camp_strip route")
	var cter := camp.find_child("TerritoryArms", true, false) if camp != null else null
	_ok(cter != null and str(cter.get_meta("field_route", "")) == "camp_territory", "camp_territory")
	var cabn := camp.find_child("CampBanner", true, false) if camp != null else null
	_ok(cabn != null and str(cabn.get_meta("field_route", "")) == "camp_banner", "camp_banner")
	_ok(cabn != null and str(cabn.get_meta("arms_kind", "")) == "lb_camp_arms", "camp_banner kind")

	var enc := CKHeraldryField.place_encounter_crest_strip(root, Vector2(400, 8), "ashbanner")
	_ok(enc != null and str(enc.get_meta("field_route", "")) == "encounter_strip", "encounter_strip route")
	var efoe := enc.find_child("FoeArms", true, false) if enc != null else null
	_ok(efoe != null and str(efoe.get_meta("field_route", "")) == "encounter_foe", "encounter_foe")
	var encbn := enc.find_child("EncounterBanner", true, false) if enc != null else null
	_ok(encbn != null and str(encbn.get_meta("field_route", "")) == "encounter_banner", "encounter_banner")
	_ok(encbn != null and str(encbn.get_meta("arms_kind", "")) == "lb_encounter_arms", "encounter_banner kind")

	var aft := CKHeraldryField.place_aftermath_crest_strip(root, Vector2(600, 8), "ashbanner")
	_ok(aft != null and str(aft.get_meta("field_route", "")) == "aftermath_strip", "aftermath_strip route")
	var afoe := aft.find_child("FoeArms", true, false) if aft != null else null
	_ok(afoe != null and str(afoe.get_meta("field_route", "")) == "aftermath_foe", "aftermath_foe")
	var aftbn := aft.find_child("AftermathBanner", true, false) if aft != null else null
	_ok(aftbn != null and str(aftbn.get_meta("field_route", "")) == "aftermath_banner", "aftermath_banner")
	_ok(aftbn != null and str(aftbn.get_meta("arms_kind", "")) == "lb_aftermath_arms", "aftermath_banner kind")

	var city := CKHeraldryField.place_city_crest_strip(root, "ash_capital", Vector2(8, 80))
	_ok(city != null and str(city.get_meta("field_route", "")) == "city_strip", "city_strip route")
	var cnat := city.find_child("CityNationArms", true, false) if city != null else null
	_ok(cnat != null and str(cnat.get_meta("field_route", "")) == "city_nation", "city_nation")
	var citybn := city.find_child("CityBanner", true, false) if city != null else null
	_ok(citybn != null and str(citybn.get_meta("field_route", "")) == "city_banner", "city_banner")

	var nat := CKHeraldryField.place_nation_crest_strip(root, "ashbanner", Vector2(200, 80))
	_ok(nat != null and str(nat.get_meta("field_route", "")) == "nation_strip", "nation_strip route")
	var nn := nat.find_child("CityNationArms", true, false) if nat != null else null
	_ok(nn != null and str(nn.get_meta("field_route", "")) == "nation_arms", "nation_arms")
	var natbn := nat.find_child("NationBanner", true, false) if nat != null else null
	_ok(natbn != null and str(natbn.get_meta("field_route", "")) == "nation_banner", "nation_banner")
	_ok(natbn != null and str(natbn.get_meta("arms_kind", "")) == "lb_nation_arms", "nation_banner kind")

	var affairs := CKHeraldryField.place_affairs_crest_strip(root, "ash_capital", Vector2(800, 80))
	_ok(affairs != null and str(affairs.get_meta("field_route", "")) == "affairs_strip", "affairs_strip route")
	var an := affairs.find_child("CityNationArms", true, false) if affairs != null else null
	_ok(an != null and str(an.get_meta("field_route", "")) == "affairs_nation", "affairs_nation")
	var abn := affairs.find_child("AffairsBanner", true, false) if affairs != null else null
	_ok(abn != null and str(abn.get_meta("field_route", "")) == "affairs_banner", "affairs_banner")
	_ok(abn != null and str(abn.get_meta("arms_kind", "")) == "lb_affairs_arms", "affairs_banner kind")
	var aco := affairs.find_child("CastleArms", true, false) if affairs != null else null
	_ok(aco != null and str(aco.get_meta("field_route", "")) == "strip_company", "affairs strip_company")

	var rite := CKHeraldryField.place_rite_crest_strip(root, leader, Vector2(400, 80))
	_ok(rite != null and str(rite.get_meta("field_route", "")) == "rite_strip", "rite_strip route")
	var rl := rite.find_child("LeaderArms", true, false) if rite != null else null
	_ok(rl != null and str(rl.get_meta("field_route", "")) == "rite_leader", "rite_leader")
	var rtbn := rite.find_child("RiteBanner", true, false) if rite != null else null
	_ok(rtbn != null and str(rtbn.get_meta("field_route", "")) == "rite_banner", "rite_banner")
	_ok(rtbn != null and str(rtbn.get_meta("arms_kind", "")) == "lb_rite_arms", "rite_banner kind")
	var rtco := rite.find_child("CastleArms", true, false) if rite != null else null
	_ok(rtco != null and str(rtco.get_meta("field_route", "")) == "strip_company", "rite strip_company")

	var muster := CKHeraldryField.place_muster_crest_strip(root, leader, Vector2(600, 80))
	_ok(muster != null and str(muster.get_meta("field_route", "")) == "muster_strip", "muster_strip route")
	var ml := muster.find_child("LeaderArms", true, false) if muster != null else null
	_ok(ml != null and str(ml.get_meta("field_route", "")) == "muster_leader", "muster_leader")
	var mubn := muster.find_child("MusterBanner", true, false) if muster != null else null
	_ok(mubn != null and str(mubn.get_meta("field_route", "")) == "muster_banner", "muster_banner")
	_ok(mubn != null and str(mubn.get_meta("arms_kind", "")) == "lb_muster_arms", "muster_banner kind")
	var muco := muster.find_child("CastleArms", true, false) if muster != null else null
	_ok(muco != null and str(muco.get_meta("field_route", "")) == "strip_company", "muster strip_company")

	var field := CKHeraldryField.place_field_crest_strip(root, Vector2(8, 160))
	_ok(field != null and str(field.get_meta("field_route", "")) == "field_strip", "field_strip route")
	var fb := field.find_child("FieldBanner", true, false) if field != null else null
	_ok(fb != null and str(fb.get_meta("field_route", "")) == "field_banner", "field_banner")
	_ok(fb != null and str(fb.get_meta("arms_kind", "")) == "lb_field_arms", "field_banner kind")

	var hud := CKHeraldryField.place_battle_hud_crest_strips(root, "ashbanner", Vector2(1280, 720), {}, false, false)
	_ok(hud != null and str(hud.get_meta("field_route", "")) == "battle_hud_strip", "battle_hud_strip route")
	var pa := hud.find_child("PlayerArms", true, false) if hud != null else null
	var ea := hud.find_child("EnemyArms", true, false) if hud != null else null
	_ok(pa != null and str(pa.get_meta("field_route", "")) == "battle_hud_player", "battle_hud_player")
	_ok(ea != null and str(ea.get_meta("field_route", "")) == "battle_hud_enemy", "battle_hud_enemy")

	var hg := CKHeraldryField.place_hourglass_crest_strip(root, Vector2(200, 160))
	var hbn := hg.find_child("HourglassBanner", true, false) if hg != null else null
	_ok(hbn != null and str(hbn.get_meta("field_route", "")) == "hourglass_banner", "hourglass_banner")

	var blood := CKHeraldryField.place_blood_crest_strip(root, Vector2(360, 160))
	var bbn := blood.find_child("BloodBanner", true, false) if blood != null else null
	_ok(bbn != null and str(bbn.get_meta("field_route", "")) == "blood_banner", "blood_banner")

	var market := CKHeraldryField.place_market_crest_strip(root, Vector2(520, 160))
	var mbn := market.find_child("MarketBanner", true, false) if market != null else null
	_ok(mbn != null and str(mbn.get_meta("field_route", "")) == "market_banner", "market_banner")
	_ok(mbn != null and str(mbn.get_meta("arms_kind", "")) == "lb_market_arms", "market_banner kind")

	var skill := CKHeraldryField.place_skill_crest_strip(root, Vector2(680, 160))
	var sbn := skill.find_child("SkillBanner", true, false) if skill != null else null
	_ok(sbn != null and str(sbn.get_meta("field_route", "")) == "skill_banner", "skill_banner")
	_ok(sbn != null and str(sbn.get_meta("arms_kind", "")) == "lb_skill_arms", "skill_banner kind")

	var works := CKHeraldryField.place_works_crest_strip(root, Vector2(8, 320))
	var wbn := works.find_child("WorksBanner", true, false) if works != null else null
	_ok(wbn != null and str(wbn.get_meta("field_route", "")) == "works_banner", "works_banner")
	_ok(wbn != null and str(wbn.get_meta("arms_kind", "")) == "lb_works_arms", "works_banner kind")
	var estates := CKHeraldryField.place_estates_crest_strip(root, Vector2(200, 320))
	var ebn := estates.find_child("EstatesBanner", true, false) if estates != null else null
	_ok(ebn != null and str(ebn.get_meta("field_route", "")) == "estates_banner", "estates_banner")
	_ok(ebn != null and str(ebn.get_meta("arms_kind", "")) == "lb_estates_arms", "estates_banner kind")
	var annex_strip := CKHeraldryField.place_annex_crest_strip(root, Vector2(400, 320))
	var axbn := annex_strip.find_child("AnnexBanner", true, false) if annex_strip != null else null
	_ok(axbn != null and str(axbn.get_meta("field_route", "")) == "annex_banner", "annex_banner")
	_ok(axbn != null and str(axbn.get_meta("arms_kind", "")) == "lb_annex_arms", "annex_banner kind")

	var roster := CKHeraldryField.place_roster_crest_strip(root, Vector2(840, 160))
	var rbn := roster.find_child("RosterBanner", true, false) if roster != null else null
	_ok(rbn != null and str(rbn.get_meta("field_route", "")) == "roster_banner", "roster_banner")
	_ok(rbn != null and str(rbn.get_meta("arms_kind", "")) == "lb_roster_arms", "roster_banner kind")

	var gaz := CKHeraldryField.place_gazette_crest_strip(root, "ashbanner", Vector2(8, 240))
	_ok(gaz != null and str(gaz.get_meta("field_route", "")) == "gazette_strip", "gazette_strip route")
	var gco := gaz.find_child("CastleArms", true, false) if gaz != null else null
	_ok(gco != null and str(gco.get_meta("field_route", "")) == "strip_company", "gazette strip_company")
	var gnat := gaz.find_child("GazetteNationArms", true, false) if gaz != null else null
	_ok(gnat != null and str(gnat.get_meta("field_route", "")) == "gazette_nation", "gazette_nation")
	var gazbn := gaz.find_child("GazetteBanner", true, false) if gaz != null else null
	_ok(gazbn != null and str(gazbn.get_meta("field_route", "")) == "gazette_banner", "gazette_banner")

	# Blood / skill strip hosts already placed above — assert strip field_route + strip_company.
	_ok(blood != null and str(blood.get_meta("field_route", "")) == "blood_strip", "blood_strip route")
	var bco := blood.find_child("CastleArms", true, false) if blood != null else null
	_ok(bco != null and str(bco.get_meta("field_route", "")) == "strip_company", "blood strip_company")
	_ok(skill != null and str(skill.get_meta("field_route", "")) == "skill_strip", "skill_strip route")
	var sco := skill.find_child("CastleArms", true, false) if skill != null else null
	_ok(sco != null and str(sco.get_meta("field_route", "")) == "strip_company", "skill strip_company")
	_ok(roster != null and str(roster.get_meta("field_route", "")) == "roster_strip", "roster_strip route")

	var dialogue := CKHeraldryField.place_dialogue_crest_strip(root, Vector2(200, 240))
	var dbn := dialogue.find_child("DialogueBanner", true, false) if dialogue != null else null
	_ok(dbn != null and str(dbn.get_meta("field_route", "")) == "dialogue_banner", "dialogue_banner")
	_ok(dbn != null and str(dbn.get_meta("arms_kind", "")) == "lb_dialogue_arms", "dialogue_banner kind")

	var shell := CKHeraldryField.place_shell_crest_strip(root, Vector2(400, 240))
	var sbn2 := shell.find_child("ShellBanner", true, false) if shell != null else null
	_ok(sbn2 != null and str(sbn2.get_meta("field_route", "")) == "shell_banner", "shell_banner")
	_ok(sbn2 != null and str(sbn2.get_meta("arms_kind", "")) == "lb_shell_arms", "shell_banner kind")
	_ok(shell != null and shell.get_child_count() == 2, "shell child_count=2")

	root.queue_free()
	await _settle()



func _court_chronicle_dossier(leader) -> void:
	var root := Control.new()
	root.name = "CourtChronicleHost"
	root.size = Vector2(1280, 720)
	add_child(root)

	# News row 朝徽
	var news_host := HBoxContainer.new()
	news_host.name = "NewsRowHost"
	root.add_child(news_host)
	var news := CKHeraldryField.attach_news_row_arms(news_host, "ashbanner")
	_ok(news != null and str(news.get_meta("field_route", "")) == "news_row", "news_row route")

	# Yearcard row + arms
	var yc_box := VBoxContainer.new()
	yc_box.name = "YearCardBox"
	yc_box.position = Vector2(8, 40)
	root.add_child(yc_box)
	var ya := CKHeraldryField.attach_yearcard_row_arms(yc_box, leader)
	_ok(ya != null and str(ya.get_meta("field_route", "")) == "yearcard_arms", "yearcard_arms route")
	var yhead := yc_box.find_child("YearArmsHead", true, false)
	_ok(yhead != null and str(yhead.get_meta("field_route", "")) == "yearcard_row", "yearcard_row route")

	# Yeartrace head + arms
	var yt_panel := VBoxContainer.new()
	yt_panel.name = "YeartracePanel"
	yt_panel.position = Vector2(200, 40)
	root.add_child(yt_panel)
	CKHeraldryField.attach_yeartrace_arms(yt_panel, leader)
	var yt_head := yt_panel.find_child("YeartraceArmsHead", true, false)
	_ok(yt_head != null and str(yt_head.get_meta("field_route", "")) == "yeartrace", "yeartrace head route")
	var yt_arms := yt_panel.find_child("YeartraceArms", true, false)
	_ok(yt_arms != null and str(yt_arms.get_meta("field_route", "")) == "yeartrace_arms", "yeartrace_arms route")

	# Purse plate + arms
	var purse := CKHeraldryField.place_purse_plate(root, leader, 7)
	_ok(purse != null and str(purse.get_meta("field_route", "")) == "purse_plate", "purse_plate route")
	var pa := purse.find_child("PurseArms", true, false) if purse != null else null
	_ok(pa != null and str(pa.get_meta("field_route", "")) == "purse_arms", "purse_arms route")

	# Blood queue + skill person
	var bq := HBoxContainer.new()
	bq.name = "BloodQueueHost"
	bq.position = Vector2(8, 160)
	root.add_child(bq)
	var bqa := CKHeraldryField.attach_blood_queue_arms(bq, leader)
	_ok(bqa != null and str(bqa.get_meta("field_route", "")) == "blood_queue", "blood_queue route")

	var sk_host := HBoxContainer.new()
	sk_host.name = "SkillDetailHost"
	sk_host.position = Vector2(200, 160)
	root.add_child(sk_host)
	var spa := CKHeraldryField.attach_skill_person_arms(sk_host, leader)
	_ok(spa != null and str(spa.get_meta("field_route", "")) == "skill_person", "skill_person route")

	# Dossier chip / badge / crest
	var chip_host := HBoxContainer.new()
	chip_host.name = "ChipHost"
	chip_host.position = Vector2(400, 160)
	root.add_child(chip_host)
	var chip := CKHeraldryField.attach_dossier_chip_arms(chip_host, leader)
	_ok(chip != null and str(chip.get_meta("field_route", "")) == "dossier_chip", "dossier_chip route")
	var badge := CKHeraldryField.attach_dossier_chip_badge(chip_host, "baron")
	_ok(badge != null and str(badge.get_meta("field_route", "")) == "dossier_chip_badge", "dossier_chip_badge route")
	var crest := CKHeraldryField.attach_dossier_crest_banner(root, leader, Vector2(600, 40), Vector2(80, 110))
	_ok(crest != null and str(crest.get_meta("field_route", "")) == "dossier_crest", "dossier_crest route")

	# Rival / vow / title / lineage / codex / site / roster row / infirmary / office / deploy focus
	var rival_host := Control.new()
	rival_host.name = "RivalHost"
	rival_host.position = Vector2(8, 240)
	root.add_child(rival_host)
	var rival_house := {"id": "suite_rival", "nation": "ashbanner", "name": "suite"}
	var ra := CKHeraldryField.attach_rival_arms(rival_host, rival_house)
	_ok(ra != null and str(ra.get_meta("field_route", "")) == "rival_arms", "rival_arms route")

	var vow := CKHeraldryField.attach_vow_company_arms(root, Vector2(120, 240))
	_ok(vow != null and str(vow.get_meta("field_route", "")) == "marriage_vow", "marriage_vow route")

	var de := CKHeraldryField.place_dynasty_end_crest_strip(root, leader, leader, Vector2(8, 320))
	_ok(de != null and str(de.get_meta("field_route", "")) == "dynasty_end_strip", "dynasty_end_strip route")
	_ok(de != null and de.find_child("DynastyEndBanner", true, false) != null, "dynasty_end banner child")
	var ho := CKHeraldryField.place_banner_handoff_crest_strip(root, leader, leader, Vector2(200, 320))
	_ok(ho != null and str(ho.get_meta("field_route", "")) == "banner_handoff_strip", "banner_handoff_strip route")
	_ok(ho != null and ho.find_child("HandoffBanner", true, false) != null, "handoff banner child")
	var vs := CKHeraldryField.place_vow_crest_strip(root, leader, leader, Vector2(400, 320))
	_ok(vs != null and str(vs.get_meta("field_route", "")) == "vow_strip", "vow_strip route")
	var vco = vs.find_child("VowCompanyArms", true, false) if vs != null else null
	_ok(vco != null and str(vco.get_meta("field_route", "")) == "marriage_vow", "vow strip keeps marriage_vow")
	var ans_host := VBoxContainer.new()
	ans_host.name = "AnswerHost"
	ans_host.position = Vector2(600, 320)
	root.add_child(ans_host)
	var ans := CKHeraldryField.attach_succession_answer_arms(ans_host, leader)
	_ok(ans != null and str(ans.get_meta("field_route", "")) == "succession_answer", "succession_answer route")

	var tl := CKHeraldryField.attach_title_leader_arms(root, leader, Vector2(200, 240))
	_ok(tl != null and str(tl.get_meta("field_route", "")) == "title_leader", "title_leader route")
	var lb := CKHeraldryField.attach_ladder_badge(root, "baron")
	_ok(lb != null and str(lb.get_meta("field_route", "")) == "title_ladder_badge", "title_ladder_badge route")

	var li_host := Control.new()
	li_host.name = "LineageInfoHost"
	li_host.position = Vector2(280, 240)
	root.add_child(li_host)
	var lia := CKHeraldryField.attach_lineage_info_arms(li_host, leader)
	_ok(lia != null and str(lia.get_meta("field_route", "")) == "lineage_info", "lineage_info route")
	var lrb := CKHeraldryField.attach_lineage_rank_badge(li_host, "baron")
	_ok(lrb != null and str(lrb.get_meta("field_route", "")) == "lineage_rank_badge", "lineage_rank_badge route")

	var codex := CKHeraldryField.attach_codex_rail_arms(root, "ashbanner", Vector2(400, 240))
	_ok(codex != null and str(codex.get_meta("field_route", "")) == "codex_rail", "codex_rail route")
	var site := CKHeraldryField.attach_site_company_banner(root, Vector2(460, 240))
	_ok(site != null and str(site.get_meta("field_route", "")) == "site_banner", "site_banner route")

	var row := HBoxContainer.new()
	row.name = "RosterRowHost"
	row.position = Vector2(8, 320)
	root.add_child(row)
	var rra := CKHeraldryField.attach_roster_row_arms(row, leader)
	_ok(rra != null and str(rra.get_meta("field_route", "")) == "roster_row", "roster_row route")

	var inf := HBoxContainer.new()
	inf.name = "InfirmaryHost"
	inf.position = Vector2(120, 320)
	root.add_child(inf)
	var iha := CKHeraldryField.attach_infirmary_heal_arms(inf, leader)
	_ok(iha != null and str(iha.get_meta("field_route", "")) == "infirmary_heal", "infirmary_heal route")

	var off := HBoxContainer.new()
	off.name = "OfficeHost"
	off.position = Vector2(240, 320)
	root.add_child(off)
	var ofa := CKHeraldryField.attach_office_field_arms(off, leader)
	_ok(ofa != null and str(ofa.get_meta("field_route", "")) == "office_field", "office_field route")

	var df := CKHeraldryField.attach_deploy_focus_arms(root, leader, Vector2(360, 320))
	_ok(df != null and str(df.get_meta("field_route", "")) == "deploy_focus", "deploy_focus route")

	var hdr := CKHeraldryField.place_company_header(root, Vector2(520, 320))
	_ok(hdr != null and str(hdr.get_meta("field_route", "")) == "company_header", "company_header route")

	root.queue_free()
	await _settle()


func _source_contracts() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	for pair in [
		["card_arms", "CardArms"],
		["forecast_ours", "ForecastOursArms"],
		["forecast_foe", "ForecastFoeArms"],
		["report_row", "ReportRowArms"],
		["report_strip", "ReportCrestStrip"],
		["report_foe", "FoeArms"],
		["report_banner", "ReportBanner"],
		["annex_row", "AnnexRowArms"],
		["forge_slot", "ForgeSlotArms"],
		["forge_focus", "ForgeFocusStrip"],
		["forge_focus_arms", "ForgeFocusArms"],
		["affairs_seal", "AffairSealArms"],
		["wall_tile", "CellArms"],
		["tree_node", "NodeArms"],
		["house_card", "HouseArms"],
		["train_row", "TrainRowArms"],
		["tavern_strip", "TavernCrestStrip"],
		["tavern_focus", "HireFocusArms"],
		["tavern_banner", "TavernBanner"],
		["hire_plate", "HireArms"],
		["castle_hub_banner", "CastleBanner"],
		["banner_plate", "CastleBannerStrip"],
		["atlas_party", "TokenArms"],
		["atlas_party_token", "atlas_party_token"],
		["castle_view_strip", "CastleViewCrestStrip"],
		["castle_view_banner", "CastleViewBanner"],
		["panorama_lineage", "PanoramaLineageStrip"],
		["panorama_person", "panorama_person"],
		["home_lineage", "HomeLineageRow"],
		["home_leader", "home_leader"],
		["board_offer", "board_offer"],
		["marriage_strip", "MarriageCrestStrip"],
		["marriage_left", "marriage_left"],
		["marriage_right", "marriage_right"],
		["marriage_banner", "MarriageBanner"],
		["succession_strip", "SuccessionCrestStrip"],
		["succession_heir", "succession_heir"],
		["succession_banner", "SuccessionBanner"],
		["duel_strip", "DuelCrestStrip"],
		["duel_left", "duel_left"],
		["duel_right", "duel_right"],
		["duel_banner", "DuelBanner"],
		["deploy_muster", "deploy_muster"],
		["deploy_muster_leader", "deploy_muster_leader"],
		["deploy_slot", "deploy_slot"],
		["reserve_strip", "reserve_strip"],
		["reserve_focus", "reserve_focus"],
		["reserve_banner", "ReserveBanner"],
		["train_focus", "train_focus"],
		["train_focus_arms", "train_focus_arms"],
		["shrine_heal", "shrine_heal"],
		["shrine_heal_focus", "shrine_heal_focus"],
		["strip_company", "strip_company"],
		["travel_strip", "travel_strip"],
		["travel_territory", "travel_territory"],
		["travel_banner", "travel_banner"],
		["camp_strip", "camp_strip"],
		["camp_territory", "camp_territory"],
		["camp_banner", "camp_banner"],
		["encounter_strip", "encounter_strip"],
		["encounter_foe", "encounter_foe"],
		["encounter_banner", "encounter_banner"],
		["aftermath_strip", "aftermath_strip"],
		["aftermath_foe", "aftermath_foe"],
		["aftermath_banner", "AftermathBanner"],
		["city_strip", "city_strip"],
		["city_nation", "city_nation"],
		["city_banner", "city_banner"],
		["nation_strip", "nation_strip"],
		["nation_banner", "nation_banner"],
		["nation_arms", "nation_arms"],
		["rite_strip", "rite_strip"],
		["rite_leader", "rite_leader"],
		["muster_strip", "muster_strip"],
		["muster_leader", "muster_leader"],
		["muster_banner", "MusterBanner"],
		["rite_banner", "RiteBanner"],
		["affairs_banner", "AffairsBanner"],
		["affairs_strip", "place_affairs_crest_strip"],
		["affairs_nation", "affairs_nation"],
		["field_strip", "field_strip"],
		["field_banner", "field_banner"],
		["battle_hud_strip", "battle_hud_strip"],
		["battle_hud_player", "battle_hud_player"],
		["battle_hud_enemy", "battle_hud_enemy"],
		["hourglass_banner", "hourglass_banner"],
		["blood_banner", "blood_banner"],
		["market_banner", "market_banner"],
		["skill_banner", "skill_banner"],
		["works_banner", "works_banner"],
		["estates_banner", "estates_banner"],
		["annex_banner", "annex_banner"],
		["works_strip", "WorksCrestStrip"],
		["estates_strip", "EstatesCrestStrip"],
		["annex_strip", "AnnexCrestStrip"],
		["roster_banner", "roster_banner"],
		["gazette_nation", "gazette_nation"],
		["gazette_strip", "GazetteCrestStrip"],
		["gazette_banner", "gazette_banner"],
		["dialogue_banner", "dialogue_banner"],
		["shell_banner", "shell_banner"],
		["news_row", "GazetteNationArms"],
		["yearcard_row", "YearArmsHead"],
		["yearcard_arms", "YearArms"],
		["yeartrace", "YeartraceArmsHead"],
		["yeartrace_arms", "YeartraceArms"],
		["purse_plate", "PursePlate"],
		["purse_arms", "PurseArms"],
		["blood_strip", "BloodCrestStrip"],
		["blood_queue", "BloodQueueArms"],
		["skill_strip", "SkillCrestStrip"],
		["skill_person", "SkillPersonArms"],
		["roster_strip", "RosterCrestStrip"],
		["roster_row", "RosterRowArms"],
		["dossier_chip", "ChipArms"],
		["dossier_chip_badge", "ChipBadge"],
		["dossier_crest", "CrestTexture"],
		["rival_arms", "RivalArms"],
		["marriage_vow", "VowCompanyArms"],
		["dynasty_end_strip", "DynastyEndCrestStrip"],
		["dynasty_end_banner", "DynastyEndBanner"],
		["banner_handoff_strip", "BannerHandoffCrestStrip"],
		["banner_handoff_banner", "HandoffBanner"],
		["vow_strip", "VowCrestStrip"],
		["vow_banner", "VowBanner"],
		["succession_answer", "AnswerHeirArms"],
		["title_leader", "LeaderArms"],
		["title_ladder_badge", "LadderBadge"],
		["lineage_info", "PersonArms"],
		["lineage_rank_badge", "RankBadge"],
		["codex_rail", "CodexRailArms"],
		["site_banner", "SiteBanner"],
		["infirmary_heal", "InnHealArms"],
		["office_field", "FieldRowArms"],
		["deploy_focus", "FocusArms"],
		["company_header", "CastleArms"],
	]:
		var route: String = pair[0]
		var lit := field.find('set_meta("field_route", "%s")' % route) >= 0
		var arg := field.find('"%s"' % route) >= 0
		_ok(lit or arg, "field source route %s" % route)
