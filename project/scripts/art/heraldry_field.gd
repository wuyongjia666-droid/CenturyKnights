class_name CKHeraldryField
extends RefCounted
## Field chrome for surfaces #511 does not own: tavern hire strip, deploy reserve,
## battle card / forecast / report, annex serve rows, forge smith slots, shrine heal,
## city 本城之事 affairs overlay (团徽 + 本城邦徽), genealogy avatar-wall tiles,
## castle panorama lineage, castle-home roster row, marriage protocol / succession /
## heir-trial duel strips, house-card person arms, banner-school train
## (pupil focus strip + row person arms), roster crest/row/hire plate,
## dialogue / save / battle-order / board / tavern-annex Field plates,
## infirmary / deploy / office Field arms,
## hourglass / castle-view / blood / market Field strips,
## gazette / yeartrace / purse / yearcard Field plates,
## atlas travel / camp / encounter Field strips,
## city / aftermath / nation / rite / muster / battle-hud / field-row Field plates,
## and company-header CastleArms Field placement.
## and skill-tree / lineage-info Field arms.
## 团徽 stays the company banner. A family id shows 族徽; no family id shows 旗徽.
## Enemy plates are 敌徽. No impale, quarter, or marriage marshalling.


static func _retire(parent: Node, node_name: String) -> void:
	if parent == null:
		return
	var old := parent.get_node_or_null(node_name)
	if old:
		old.name = "_Dying_%s" % node_name
		old.queue_free()


static func _host(parent: Node, node_name: String, at: Vector2, size: Vector2, field_route: String = "") -> Control:
	_retire(parent, node_name)
	var host := Control.new()
	host.name = node_name
	host.position = at
	host.size = size
	host.custom_minimum_size = size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if field_route != "":
		host.set_meta("field_route", field_route)
	parent.add_child(host)
	if parent is Container:
		parent.move_child(host, 0)
	return host


static func _pair(host: Control, shield: Vector2, second: TextureRect) -> void:
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	if second != null:
		second.position = Vector2(shield.x + 8.0, 0)
		host.add_child(second)


## Tavern hire header: 团徽 + focused candidate 族徽|旗徽. No candidate → 团徽 only.
static func place_tavern_crest_strip(parent: Node, candidate, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if candidate != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "TavernCrestStrip", at, Vector2(w, shield.y), "tavern_strip")
	var focus: TextureRect = null
	if candidate != null:
		focus = CKHeraldryChrome.make_person_arms(candidate, shield)
		focus.name = "HireFocusArms"
	_pair(host, shield, focus)
	host.set_meta("has_candidate", candidate != null)
	return host


## Deploy reserve chip: 团徽 + appointed reserve 族徽|旗徽. Unset → 团徽 only.
static func place_reserve_crest_strip(parent: Node, reserve_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if reserve_c != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "ReserveCrestStrip", at, Vector2(w, shield.y), "reserve_strip")
	var extra: TextureRect = null
	if reserve_c != null:
		extra = CKHeraldryChrome.make_person_arms(reserve_c, shield)
		extra.name = "ReserveArms"
	_pair(host, shield, extra)
	host.set_meta("has_reserve", reserve_c != null)
	return host


## Selected-unit card. Player → 族徽|旗徽. Enemy → 敌徽, never company or family arms.
static func attach_card_arms(card: Control, c, team: String, foe_nation: String, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if card == null:
		return
	_retire(card, "CardArms")
	if c == null:
		return
	var arms: TextureRect = null
	if str(team) != "player":
		if str(foe_nation) == "":
			return
		arms = CKHeraldryChrome.make_nation_arms(str(foe_nation), arms_sz)
	else:
		arms = CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "CardArms"
	arms.position = Vector2(4.0, 108.0 - arms_sz.y - 4.0)
	card.add_child(arms)


## Forecast overlay. Ours follows the attacker team. Theirs is always 敌徽 when a nation is known.
static func pin_forecast_arms(panel: Control, atk_char, atk_team: String, foe_nation: String) -> void:
	if panel == null:
		return
	_retire(panel, "ForecastOursArms")
	_retire(panel, "ForecastFoeArms")
	if atk_char == null:
		return
	var shield := Vector2(22, 26)
	var ours: TextureRect
	if str(atk_team) != "player":
		if str(foe_nation) == "":
			return
		ours = CKHeraldryChrome.make_nation_arms(str(foe_nation), shield)
	else:
		ours = CKHeraldryChrome.make_person_arms(atk_char, shield)
	ours.name = "ForecastOursArms"
	ours.position = Vector2(6, 4)
	panel.add_child(ours)
	if str(foe_nation) != "" and str(atk_team) == "player":
		var foe := CKHeraldryChrome.make_nation_arms(str(foe_nation), shield)
		foe.name = "ForecastFoeArms"
		var x := maxf(160.0, panel.size.x * 0.5 + 6.0)
		foe.position = Vector2(x, 4)
		panel.add_child(foe)
	panel.set_meta("forecast_has_foe", str(foe_nation) != "" and str(atk_team) == "player")


## Post-action report header: 团徽 + optional 敌徽.
static func place_report_crest_strip(parent: Node, at: Vector2, foe_nation: String, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var nid := str(foe_nation)
	var w := shield.x if nid == "" else shield.x * 2.0 + 8.0
	var host := _host(parent, "ReportCrestStrip", at, Vector2(w, shield.y), "report_strip")
	var extra: TextureRect = null
	if nid != "":
		extra = CKHeraldryChrome.make_nation_arms(nid, shield)
	_pair(host, shield, extra)
	host.set_meta("has_foe", nid != "")
	return host


static func attach_report_row_arms(parent: Node, c, at: Vector2, arms_sz: Vector2 = Vector2(22, 26)) -> TextureRect:
	if parent == null or c == null:
		return null
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "ReportRowArms"
	arms.position = at
	parent.add_child(arms)
	return arms


## Annex serve row. kind: person | rival | company.
static func attach_annex_row_arms(row: Control, kind: String, who, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if row == null:
		return null
	_retire(row, "AnnexRowArms")
	var arms: TextureRect = null
	match kind:
		"person":
			if who == null:
				return null
			arms = CKHeraldryChrome.make_person_arms(who, arms_sz)
		"rival":
			arms = CKHeraldryChrome.make_rival_arms(who, arms_sz)
		"company":
			arms = CKHeraldryChrome.make_company_arms(arms_sz)
		_:
			return null
	arms.name = "AnnexRowArms"
	row.add_child(arms)
	if row is Container:
		row.move_child(arms, 0)
	return arms


## Forge focus strip: 团徽 + selected smith 族徽|旗徽. No selection → 团徽 only.
static func place_forge_focus_strip(parent: Node, smith, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if smith != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "ForgeFocusStrip", at, Vector2(w, shield.y), "forge_focus")
	var focus: TextureRect = null
	if smith != null:
		focus = CKHeraldryChrome.make_person_arms(smith, shield)
		focus.name = "ForgeFocusArms"
	_pair(host, shield, focus)
	host.set_meta("has_smith", smith != null)
	return host


## Smith list row: person 族徽|旗徽. No marshalling with company arms.
static func attach_forge_slot_arms(row: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if row == null or c == null:
		return null
	_retire(row, "ForgeSlotArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "ForgeSlotArms"
	arms.position = Vector2(maxf(4.0, row.size.x - arms_sz.x - 8.0) if row.size.x > 80.0 else 292.0, 12.0)
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arms)
	return arms


## Shrine HealCard strip: 团徽 + first hurt knight 族徽|旗徽. Empty hurt → 团徽 only.
static func place_shrine_heal_strip(parent: Node, focus_hurt, at: Vector2, shield: Vector2 = Vector2(32, 40)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if focus_hurt != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "ShrineHealStrip", at, Vector2(w, shield.y), "shrine_heal")
	var focus: TextureRect = null
	if focus_hurt != null:
		focus = CKHeraldryChrome.make_person_arms(focus_hurt, shield)
		focus.name = "HealFocusArms"
	_pair(host, shield, focus)
	host.set_meta("has_hurt", focus_hurt != null)
	return host

## City 本城之事 overlay: 团徽 + 本城邦徽. Host AffairCrestStrip (not CityCrestStrip).
static func place_affairs_crest_strip(parent: Node, city_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "AffairCrestStrip")
	var nid := World.nation_of(str(city_id))
	if nid == "":
		nid = str(World.node(str(city_id)).get("nation", ""))
	var w := shield.x
	if nid != "":
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "AffairCrestStrip", at, Vector2(w, shield.y), "affairs_strip")
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	if nid != "":
		var nat := CKHeraldryChrome.make_city_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
	host.set_meta("nation_id", nid)
	host.set_meta("city_id", str(city_id))
	return host


## Seal-stamp candidate row: person 族徽|旗徽. No marshalling with company arms.
static func attach_affairs_seal_arms(row: Control, c, arms_sz: Vector2 = Vector2(26, 32)) -> TextureRect:
	if row == null or c == null:
		return null
	_retire(row, "AffairSealArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "AffairSealArms"
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arms)
	if row is Container:
		row.move_child(arms, 0)
	else:
		arms.position = Vector2(4, 8)
	return arms


## Living roster for castle overview: leader, then other family members, then 旗徽 knights.
static func household_for_overview(limit: int = 8) -> Array:
	var out: Array = []
	var leader = GameState.get_leader()
	if leader != null and leader.alive and leader.in_roster and not leader.retired:
		out.append(leader)
	var rest: Array = []
	for c in GameState.roster():
		if leader != null and c == leader:
			continue
		rest.append(c)
	rest.sort_custom(func(a, b):
		var fa := 1 if CKHeraldryChrome.is_family_member(a) else 0
		var fb := 1 if CKHeraldryChrome.is_family_member(b) else 0
		if fa != fb:
			return fa > fb
		return str(a.id) < str(b.id))
	var cap := maxi(1, limit)
	for c in rest:
		if out.size() >= cap:
			break
		out.append(c)
	return out


static func _lineage_host(parent: Node, node_name: String, people: Array, at: Vector2, shield: Vector2, gap: float) -> Control:
	var n := people.size()
	var w := shield.x + float(n) * (shield.x + gap)
	var host := _host(parent, node_name, at, Vector2(w, shield.y))
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	var i := 0
	for c in people:
		if c == null:
			continue
		var arms := CKHeraldryChrome.make_person_arms(c, shield)
		arms.position = Vector2(shield.x + gap + float(i) * (shield.x + gap), 0)
		host.add_child(arms)
		host.set_meta("slot_%d" % i, arms)
		i += 1
	host.set_meta("person_count", i)
	return host


## Castle panorama: one 团徽, then each living knight's own shield. No marshalling.
static func place_panorama_lineage_strip(parent: Node, people: Array, at: Vector2, shield: Vector2 = Vector2(26, 32)) -> Control:
	if parent == null:
		return null
	var host := _lineage_host(parent, "PanoramaLineageStrip", people, at, shield, 6.0)
	host.set_meta("field_route", "panorama_lineage")
	var i := 0
	for c in people:
		if c == null:
			continue
		var arms: TextureRect = host.get_meta("slot_%d" % i)
		arms.name = "PanoramaPerson_%s" % str(c.id)
		i += 1
	return host


## Castle home roster: 团徽 reference plus leader 族徽|旗徽 and the rest of the household.
static func place_home_lineage_row(parent: Node, people: Array, at: Vector2, shield: Vector2 = Vector2(22, 28)) -> Control:
	if parent == null:
		return null
	var host := _lineage_host(parent, "HomeLineageRow", people, at, shield, 4.0)
	host.set_meta("field_route", "home_lineage")
	var i := 0
	for c in people:
		if c == null:
			continue
		var arms: TextureRect = host.get_meta("slot_%d" % i)
		arms.name = "HomeLeaderArms" if c.is_leader else "HomeKin_%s" % str(c.id)
		i += 1
	return host


## Avatar-wall tile: one 族徽|旗徽 plus a rank badge that follows rank_changed.
static func attach_wall_tile_arms(host: Control, c, cell: Vector2, portrait_top: float = 6.0) -> void:
	if c == null or host == null:
		return
	_retire(host, "CellArms")
	_retire(host, "CellBadge")
	var arms_sz := Vector2(28, 34)
	var badge_sz := 22
	if cell.x >= 150.0:
		arms_sz = Vector2(36, 44)
		badge_sz = 28
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "CellArms"
	var por_h := 88.0 if cell.x < 150.0 else 132.0
	arms.position = Vector2(6.0, portrait_top + por_h - arms_sz.y - 2.0)
	host.add_child(arms)
	var badge := CKHeraldryChrome.make_rank_badge(str(c.rank), badge_sz)
	badge.name = "CellBadge"
	badge.position = Vector2(cell.x - float(badge_sz) - 4.0, portrait_top + 2.0)
	badge.set_meta("rank_id", str(c.rank))
	host.add_child(badge)
	_bind_rank_badge(c, badge, badge_sz)


## Lineage-tree node: same arms rule as the wall, smaller shield.
static func attach_tree_node_arms(host: Control, c, node: Vector2) -> void:
	if c == null or host == null:
		return
	_retire(host, "NodeArms")
	_retire(host, "NodeBadge")
	var arms := CKHeraldryChrome.make_person_arms(c, Vector2(30, 36))
	arms.name = "NodeArms"
	arms.position = Vector2(4, 4)
	host.add_child(arms)
	var badge := CKHeraldryChrome.make_rank_badge(str(c.rank), 22)
	badge.name = "NodeBadge"
	badge.position = Vector2(node.x - 26.0, 4)
	badge.set_meta("rank_id", str(c.rank))
	host.add_child(badge)
	_bind_rank_badge(c, badge, 22)


static func _bind_rank_badge(c, badge: TextureRect, badge_sz: int) -> void:
	if c == null or badge == null or not c.has_signal("rank_changed"):
		return
	var cb := func(new_rank: String) -> void:
		if not is_instance_valid(badge):
			return
		badge.texture = CKHeraldryRender.rank_badge(str(new_rank), badge_sz)
		badge.set_meta("rank_id", str(new_rank))
	c.rank_changed.connect(cb)
	badge.tree_exiting.connect(func() -> void:
		if is_instance_valid(c) and c.rank_changed.is_connected(cb):
			c.rank_changed.disconnect(cb)
	)


## Marriage protocol strip: 团徽 + left (suitor) + right (candidate/spouse) 族徽|旗徽.
## Never marshalls/impales — three separate shields.
static func place_marriage_crest_strip(parent: Node, left_c, right_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var gap := 8.0
	var x := 0.0
	var w := shield.x
	if left_c != null:
		w += gap + shield.x
	if right_c != null:
		w += gap + shield.x
	var host := _host(parent, "MarriageCrestStrip", at, Vector2(w, shield.y), "marriage_strip")
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2(x, 0)
	host.add_child(co)
	x += shield.x + gap
	if left_c != null:
		var la := CKHeraldryChrome.make_person_arms(left_c, shield)
		la.name = "LeftArms"
		la.position = Vector2(x, 0)
		host.add_child(la)
		x += shield.x + gap
	if right_c != null:
		var ra := CKHeraldryChrome.make_person_arms(right_c, shield)
		ra.name = "RightArms"
		ra.position = Vector2(x, 0)
		host.add_child(ra)
	host.set_meta("has_left", left_c != null)
	host.set_meta("has_right", right_c != null)
	return host


## Marriage house-card plate: person 族徽|旗徽 as HouseArms (lower-left of portrait plate).
static func attach_house_card_arms(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(32, 38)) -> TextureRect:
	if parent == null or c == null:
		return null
	_retire(parent, "HouseArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "HouseArms"
	arms.position = Vector2(plate.position.x + 4.0, plate.position.y + plate.size.y - arms_sz.y - 4.0)
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arms)
	return arms


## Succession clash strip: 团徽 + named heir 族徽|旗徽 (SuccessionCrestStrip).
static func place_succession_crest_strip(parent: Node, heir, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if heir != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "SuccessionCrestStrip", at, Vector2(w, shield.y), "succession_strip")
	var focus: TextureRect = null
	if heir != null:
		focus = CKHeraldryChrome.make_person_arms(heir, shield)
		focus.name = "LeaderArms"
	_pair(host, shield, focus)
	host.set_meta("has_heir", heir != null)
	return host


## Heir-trial duel strip: 团徽 + heir A + heir B 族徽|旗徽 (DuelCrestStrip). Missing side omitted.
static func place_duel_crest_strip(parent: Node, left_c, right_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var gap := 8.0
	var x := 0.0
	var w := shield.x
	if left_c != null:
		w += gap + shield.x
	if right_c != null:
		w += gap + shield.x
	var host := _host(parent, "DuelCrestStrip", at, Vector2(w, shield.y), "duel_strip")
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2(x, 0)
	host.add_child(co)
	x += shield.x + gap
	if left_c != null:
		var la := CKHeraldryChrome.make_person_arms(left_c, shield)
		la.name = "LeftArms"
		la.position = Vector2(x, 0)
		host.add_child(la)
		x += shield.x + gap
	if right_c != null:
		var ra := CKHeraldryChrome.make_person_arms(right_c, shield)
		ra.name = "RightArms"
		ra.position = Vector2(x, 0)
		host.add_child(ra)
	host.set_meta("has_left", left_c != null)
	host.set_meta("has_right", right_c != null)
	return host


## Banner school focus strip: 团徽 + selected pupil 族徽|旗徽. No pupil → 团徽 only.
static func place_train_focus_strip(parent: Node, pupil, at: Vector2, shield: Vector2 = Vector2(40, 48)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if pupil != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "TrainFocusStrip", at, Vector2(w, shield.y), "train_focus")
	var focus: TextureRect = null
	if pupil != null:
		focus = CKHeraldryChrome.make_person_arms(pupil, shield)
		focus.name = "TrainFocusArms"
	_pair(host, shield, focus)
	host.set_meta("has_pupil", pupil != null)
	return host


## Pupil / tutor / promo pick row: person 族徽|旗徽. No marshalling with company arms.
static func attach_train_row_arms(host: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if host == null or c == null:
		return null
	_retire(host, "TrainRowArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "TrainRowArms"
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.add_child(arms)
	return arms

## Roster header strip: 团徽 + company banner cloth (RosterCrestStrip / RosterBanner).
static func place_roster_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	_retire(parent, "RosterCrestStrip")
	var host := Control.new()
	host.name = "RosterCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "roster_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "RosterBanner"
	bn.tooltip_text = Locale.t("lb_roster_arms")
	bn.set_meta("arms_kind", "lb_roster_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Roster list-row person arms (RosterRowArms). No marshalling with company arms.
static func attach_roster_row_arms(row: Control, c, arms_sz: Vector2 = Vector2(26, 32)) -> TextureRect:
	if row == null or c == null:
		return null
	_retire(row, "RosterRowArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "RosterRowArms"
	arms.tooltip_text = Locale.t("lb_roster_arms")
	arms.set_meta("field_route", "roster_row")
	## Keep person arms_kind; pin left of CLASS column (row ~364 wide).
	arms.position = Vector2(286.0, 16.0)
	row.add_child(arms)
	return arms


## Hire / roster dossier portrait plate: 族徽|旗徽 on lower-left of the plate rect.
static func attach_hire_plate_arms(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(36, 44)) -> TextureRect:
	if parent == null or c == null:
		return null
	_retire(parent, "HireArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "HireArms"
	arms.position = Vector2(plate.position.x + 4.0, plate.position.y + plate.size.y - arms_sz.y - 4.0)
	arms.set_meta("field_route", "hire_plate")
	parent.add_child(arms)
	return arms


## Dialogue stage strip: 团徽 + 对话旗布 (DialogueCrestStrip).
static func place_dialogue_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("DialogueCrestStrip")
	if old:
		old.name = "_DialogueCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "DialogueCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "dialogue_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "DialogueBanner"
	bn.tooltip_text = Locale.t("lb_dialogue_arms")
	bn.set_meta("arms_kind", "lb_dialogue_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Speaker 族徽|旗徽 under the dialogue portrait (DialogueSpeakerArms). Null clears it.
static func attach_dialogue_speaker_arms(portrait_host: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if portrait_host == null:
		return null
	var old := portrait_host.get_node_or_null("DialogueSpeakerArms")
	if old:
		old.name = "_DialogueSpeakerArmsDying"
		old.queue_free()
	if c == null:
		return null
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "DialogueSpeakerArms"
	arms.tooltip_text = Locale.t("lb_dialogue_arms")
	arms.set_meta("field_route", "dialogue_speaker")
	var pw := portrait_host.custom_minimum_size.x
	var ph := portrait_host.custom_minimum_size.y
	if pw < 8.0:
		pw = portrait_host.size.x
	if ph < 8.0:
		ph = portrait_host.size.y
	arms.position = Vector2(maxf(0.0, pw - arms_sz.x - 2.0), maxf(0.0, ph - arms_sz.y - 2.0))
	portrait_host.add_child(arms)
	return arms


## Title / settings / save / pause shell strip: 团徽 + 旗布 (ShellCrestStrip).
static func place_shell_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(44, 52), banner: Vector2 = Vector2(28, 38)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("ShellCrestStrip")
	if old:
		old.name = "_ShellCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "ShellCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "shell_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Save-slot / load-card row. crest_hex paints that slot, not the live company.
static func attach_save_row_arms(row: Control, size: Vector2 = Vector2(36, 44), crest_hex: String = "") -> TextureRect:
	if row == null:
		return null
	var old := row.get_node_or_null("SlotArms")
	if old:
		old.name = "_SlotArmsDying"
		old.queue_free()
	var tr: TextureRect
	var hx := crest_hex.strip_edges()
	if hx != "":
		tr = TextureRect.new()
		tr.texture = UnitArt.shield_arms(CKHeraldry.from_crest(hx), int(size.x), int(size.y))
		tr.custom_minimum_size = size
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_meta("arms_kind", "lb_slot_arms")
		tr.set_meta("arms_core", CKHeraldry.core_key(CKHeraldry.from_crest(hx)))
		tr.tooltip_text = Locale.t("lb_slot_arms")
	else:
		tr = CKHeraldryChrome.make_company_arms(size)
		tr.set_meta("arms_kind", "lb_slot_arms")
		tr.tooltip_text = Locale.t("lb_slot_arms")
	tr.name = "SlotArms"
	tr.set_meta("field_route", "save_row")
	if row is HBoxContainer:
		row.add_child(tr)
		row.move_child(tr, 0)
	elif row is PanelContainer:
		var inner = row.get_child(0) if row.get_child_count() > 0 else null
		if inner is HBoxContainer:
			inner.add_child(tr)
			inner.move_child(tr, 0)
		else:
			row.add_child(tr)
	else:
		row.add_child(tr)
	return tr


## Castle / annex cloth plate beside the header shield (CastleBannerStrip).
static func place_banner_plate(parent: Node, at: Vector2, shield: Vector2 = Vector2(44, 52), banner: Vector2 = Vector2(28, 38)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("CastleBannerStrip")
	if old:
		old.name = "_CastleBannerStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "CastleBannerStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "banner_plate")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Commission detail plate (BoardCrest). Home issuer is 团徽; other cities are 邦徽.
static func place_board_crest(parent: Node, issuer_id: String, at: Vector2, size: Vector2 = Vector2(44, 52)) -> TextureRect:
	if parent == null:
		return null
	var old := parent.get_node_or_null("BoardCrest")
	if old:
		old.name = "_BoardCrestDying"
		old.queue_free()
	var tr := CKHeraldryChrome.make_issuer_arms(issuer_id, size)
	tr.position = at
	tr.set_meta("field_route", "board_plate")
	parent.add_child(tr)
	return tr


## Quest-card offer plate prepended in an HBox (BoardCrest, field_route board_offer).
static func attach_board_offer_arms(row: Control, issuer_id: String, arms_sz: Vector2 = Vector2(36, 44)) -> TextureRect:
	if row == null or str(issuer_id) == "":
		return null
	_retire(row, "BoardCrest")
	var tr := CKHeraldryChrome.make_issuer_arms(issuer_id, arms_sz)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.set_meta("field_route", "board_offer")
	row.add_child(tr)
	return tr


## City commission row plate, pinned at `at` (BoardCrest, field_route board_row).
static func pin_board_row_arms(row: Control, issuer_id: String, at: Vector2, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if row == null:
		return null
	_retire(row, "BoardCrest")
	var tr := CKHeraldryChrome.make_issuer_arms(issuer_id, arms_sz)
	tr.position = at
	tr.set_meta("field_route", "board_row")
	row.add_child(tr)
	return tr


## Mount the live initiative strip. Chips repaint when turn, hp, or done changes.
static func sync_battle_order_crests(battle) -> void:
	if battle == null:
		return
	var strip := battle.get_node_or_null("BattleOrderCrest") as Control
	if strip == null:
		strip = Control.new()
		strip.name = "BattleOrderCrest"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.z_index = 3
		var scr := load("res://scripts/battle/ui/battle_order_crest.gd")
		strip.set_script(scr)
		battle.add_child(strip)
	var vp := Vector2(1280, 720)
	if battle is Control and (battle as Control).is_inside_tree():
		vp = (battle as Control).get_viewport().get_visible_rect().size
	var mobile := DeviceProfile.is_mobile()
	var x := 700.0
	if mobile:
		x = clampf(vp.x * 0.46, 220.0, maxf(220.0, vp.x - 240.0))
	strip.position = Vector2(x, 8.0 if not mobile else 6.0)
	strip.set_meta("field_route", "battle_order")
	fill_battle_order(strip, battle)


## Rebuild BattleOrderCrest chips. Player/ally: 族徽|旗徽. Enemy: 敌徽. No labels.
static func fill_battle_order(strip: Control, battle) -> void:
	if strip == null or battle == null:
		return
	var sig := _battle_order_sig(battle)
	if str(strip.get_meta("order_sig", "")) == sig and strip.get_child_count() > 0:
		return
	for c in strip.get_children():
		strip.remove_child(c)
		c.queue_free()
	var shield := Vector2(28, 34)
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2.ZERO
	strip.add_child(co)
	var x := shield.x + 6.0
	var added := 0
	for e in _battle_order_entries(battle):
		if added >= 6:
			break
		var team := str(e["team"])
		var arms: TextureRect = null
		if team == "player" or team == "ally":
			arms = CKHeraldryChrome.make_person_arms(e["char"], shield)
		else:
			var nid := str(e["foe"])
			if nid == "":
				continue
			arms = CKHeraldryChrome.make_nation_arms(nid, shield)
		arms.name = "OrderChip%d" % added
		arms.position = Vector2(x, 0)
		arms.set_meta("field_route", "battle_order_chip")
		arms.set_meta("order_team", team)
		arms.set_meta("order_done", bool(e["done"]))
		arms.set_meta("order_idx", int(e["idx"]))
		strip.add_child(arms)
		x += shield.x + 4.0
		added += 1
	strip.size = Vector2(maxf(shield.x, x), shield.y)
	strip.custom_minimum_size = strip.size
	strip.set_meta("order_sig", sig)
	strip.set_meta("chip_count", added)
	strip.set_meta("field_route", "battle_order")


static func _battle_order_sig(battle) -> String:
	var parts := PackedStringArray()
	parts.append(str(battle.get("turn_team")))
	parts.append(CKHeraldryChrome.battle_foe_nation_for(battle))
	var units = battle.get("units")
	if typeof(units) != TYPE_ARRAY:
		return "|".join(parts)
	var i := 0
	for u in units:
		if typeof(u) != TYPE_DICTIONARY:
			parts.append("%d:bad" % i)
		else:
			var ch = u.get("char")
			var hp := -1
			var agi := 0
			if ch != null and "hp" in ch:
				hp = int(ch.hp)
			if ch != null and "stats" in ch and typeof(ch.stats) == TYPE_DICTIONARY:
				agi = int(ch.stats.get("agi", 0))
			parts.append("%d:%s:%s:%d:%d" % [i, str(u.get("team", "")), str(bool(u.get("done", false))), hp, agi])
		i += 1
	return "|".join(parts)


static func _battle_order_entries(battle) -> Array:
	var units = battle.get("units")
	if typeof(units) != TYPE_ARRAY:
		return []
	var turn := str(battle.get("turn_team"))
	var foe := CKHeraldryChrome.battle_foe_nation_for(battle)
	var rows: Array = []
	var idx := 0
	for u in units:
		if typeof(u) != TYPE_DICTIONARY:
			idx += 1
			continue
		var ch = u.get("char")
		if ch == null or not ("hp" in ch) or int(ch.hp) <= 0:
			idx += 1
			continue
		var team := str(u.get("team", ""))
		var done := bool(u.get("done", false))
		var agi := 0
		if "stats" in ch and typeof(ch.stats) == TYPE_DICTIONARY:
			agi = int(ch.stats.get("agi", 0))
		var same := team == turn or (turn == "player" and team == "ally") or (turn == "ally" and team == "player")
		var rank := 2
		if not done and same:
			rank = 0
		elif not done:
			rank = 1
		rows.append({"char": ch, "team": team, "done": done, "foe": foe, "agi": agi, "idx": idx, "rank": rank})
		idx += 1
	rows.sort_custom(_order_before)
	return rows


static func _order_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["rank"]) != int(b["rank"]):
		return int(a["rank"]) < int(b["rank"])
	if int(a["agi"]) != int(b["agi"]):
		return int(a["agi"]) > int(b["agi"])
	return int(a["idx"]) < int(b["idx"])

## Infirmary heal roster row: one person shield (族徽|旗徽). No company pair, no cadency.
static func attach_infirmary_heal_arms(row: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if row == null or c == null:
		return null
	_retire(row, "InnHealArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "InnHealArms"
	arms.set_meta("field_route", "infirmary_heal")
	row.add_child(arms)
	if row is Container:
		row.move_child(arms, 0)
	return arms


## Deploy muster strip: 团徽 + one leader shield. No leader → 团徽 only.
static func place_deploy_muster_strip(parent: Node, leader, at: Vector2, shield: Vector2 = Vector2(40, 48)) -> Control:
	if parent == null:
		return null
	var w := shield.x
	if leader != null:
		w = shield.x * 2.0 + 8.0
	var host := _host(parent, "MusterCrestStrip", at, Vector2(w, shield.y), "deploy_muster")
	var extra: TextureRect = null
	if leader != null:
		extra = CKHeraldryChrome.make_person_arms(leader, shield)
		extra.name = "LeaderArms"
	_pair(host, shield, extra)
	host.set_meta("field_route", "deploy_muster")
	host.set_meta("has_leader", leader != null)
	return host


## Deploy slot card: one person shield. Position matches the legacy plate inset.
static func attach_deploy_slot_arms(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(36, 44)) -> TextureRect:
	if parent == null or c == null:
		return null
	var at := Vector2(plate.position.x + 4.0, plate.position.y + plate.size.y - arms_sz.y - 4.0)
	return place_deploy_slot_arms(parent, c, at, arms_sz)


static func place_deploy_slot_arms(parent: Control, c, at: Vector2, arms_sz: Vector2 = Vector2(36, 44)) -> TextureRect:
	if parent == null or c == null:
		return null
	_retire(parent, "DeployArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "DeployArms"
	arms.position = at
	arms.set_meta("field_route", "deploy_slot")
	parent.add_child(arms)
	return arms


## Focused deploy metrics: one person shield for the selected knight.
static func attach_deploy_focus_arms(parent: Control, c, at: Vector2, arms_sz: Vector2 = Vector2(40, 48)) -> TextureRect:
	if parent == null or c == null:
		return null
	_retire(parent, "FocusArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "FocusArms"
	arms.position = at
	arms.set_meta("field_route", "deploy_focus")
	parent.add_child(arms)
	if parent is Container:
		parent.move_child(arms, 0)
	return arms


## Estates field-book / 属事处 row: one person shield. No marshalling with the office strip.
static func attach_office_field_arms(row: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if row == null or c == null:
		return null
	_retire(row, "FieldRowArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "FieldRowArms"
	arms.set_meta("field_route", "office_field")
	row.add_child(arms)
	if row is Container:
		row.move_child(arms, 0)
	return arms

## Hourglass / 时漏 strip: 团徽 + 时漏旗布 (HourglassCrestStrip).
static func place_hourglass_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	_retire(parent, "HourglassCrestStrip")
	var host := Control.new()
	host.name = "HourglassCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "hourglass_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "HourglassBanner"
	bn.tooltip_text = Locale.t("lb_hourglass_arms")
	bn.set_meta("arms_kind", "lb_hourglass_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Castle overview strip: 团徽 + 城堡旗布 (CastleViewCrestStrip). Distinct from CastleBannerStrip.
static func place_castle_view_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	_retire(parent, "CastleViewCrestStrip")
	var host := Control.new()
	host.name = "CastleViewCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "castle_view_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "CastleViewBanner"
	bn.tooltip_text = Locale.t("lb_castle_view_arms")
	bn.set_meta("arms_kind", "lb_castle_view_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Blood-assay strip: 团徽 + 血验旗布 (BloodCrestStrip).
static func place_blood_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	_retire(parent, "BloodCrestStrip")
	var host := Control.new()
	host.name = "BloodCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "blood_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "BloodBanner"
	bn.tooltip_text = Locale.t("lb_blood_arms")
	bn.set_meta("arms_kind", "lb_blood_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Pin BloodQueueArms on a queue row (person awaiting assay).
static func attach_blood_queue_arms(row: Control, c, arms_sz: Vector2 = Vector2(26, 32)) -> TextureRect:
	if row == null or c == null:
		return null
	_retire(row, "BloodQueueArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "BloodQueueArms"
	arms.tooltip_text = Locale.t("lb_blood_arms")
	arms.set_meta("field_route", "blood_queue")
	row.add_child(arms)
	if row is Container:
		row.move_child(arms, 0)
	return arms


## Market desk strip: 团徽 + 市集旗布 (MarketCrestStrip). Distinct from CityCrestStrip.
static func place_market_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	_retire(parent, "MarketCrestStrip")
	var host := Control.new()
	host.name = "MarketCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "market_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "MarketBanner"
	bn.tooltip_text = Locale.t("lb_market_arms")
	bn.set_meta("arms_kind", "lb_market_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Yeartrace panel header: person YeartraceArms (岁课年迹). House mount uses company arms.
## Shrink-only — never expand in the dossier FamilyTree scroll (court_ui overlap guard).
static func attach_yeartrace_arms(panel: Control, c = null, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if panel == null:
		return
	_retire(panel, "YeartraceArmsHead")
	var head := HBoxContainer.new()
	head.name = "YeartraceArmsHead"
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_theme_constant_override("separation", 8)
	head.set_meta("field_route", "yeartrace")
	var arms: TextureRect
	if c != null:
		arms = CKHeraldryChrome.make_person_arms(c, arms_sz)
	else:
		arms = CKHeraldryChrome.make_company_arms(arms_sz)
	arms.name = "YeartraceArms"
	arms.tooltip_text = Locale.t("lb_yeartrace_arms")
	arms.set_meta("field_route", "yeartrace")
	arms.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	arms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(arms)
	var mono_i := -1
	for i in panel.get_child_count():
		var ch: Node = panel.get_child(i)
		if ch is Label and str(ch.text).find("YEARTRACE") >= 0:
			mono_i = i
			break
	if mono_i >= 0:
		var mono: Node = panel.get_child(mono_i)
		panel.remove_child(mono)
		head.add_child(mono)
		panel.add_child(head)
		panel.move_child(head, mono_i)
	else:
		panel.add_child(head)
		panel.move_child(head, 0)


## Dossier 私囊 plate: PurseArms (person) + silver readout host.
static func place_purse_plate(parent: Node, c, purse_silver: int = 0, arms_sz: Vector2 = Vector2(28, 34)) -> Control:
	if parent == null or c == null:
		return null
	_retire(parent, "PursePlate")
	var host := HBoxContainer.new()
	host.name = "PursePlate"
	host.add_theme_constant_override("separation", 8)
	host.set_meta("field_route", "purse")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "PurseArms"
	arms.tooltip_text = Locale.t("lb_purse_arms")
	arms.set_meta("field_route", "purse")
	host.add_child(arms)
	var lab := UIKit.body_label(Locale.t("lb_dos_purse", [int(purse_silver)]), UIKit.TEXT, 13)
	lab.name = "PurseSilver"
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.add_child(lab)
	host.set_meta("purse_silver", int(purse_silver))
	host.set_meta("arms_kind", str(arms.get_meta("arms_kind", "")))
	host.set_meta("arms_core", str(arms.get_meta("arms_core", "")))
	parent.add_child(host)
	return host


## Court gazette strip: 团徽 + nation 朝徽/邦徽 (GazetteCrestStrip). Empty nation → 团徽 only.
static func place_gazette_crest_strip(parent: Node, nation_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "GazetteCrestStrip")
	var nid := str(nation_id)
	if nid == "":
		nid = World.nation_of(str(World.pos))
	if nid == "":
		nid = "ashbanner"
	var host := Control.new()
	host.name = "GazetteCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "gazette_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	if nid != "":
		var nat := CKHeraldryChrome.make_gazette_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host


## Pin 朝徽 on a court-news row top bar (HBox).
static func attach_news_row_arms(host: Control, nation_id: String, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if host == null or str(nation_id) == "":
		return null
	_retire(host, "GazetteNationArms")
	var arms := CKHeraldryChrome.make_gazette_nation_arms(str(nation_id), arms_sz)
	arms.set_meta("field_route", "news_row")
	host.add_child(arms)
	if host is Container:
		host.move_child(arms, 0)
	return arms


## Year-card / chronicle person plate: prepend YearArms into a VBox row box via head HBox.
static func attach_yearcard_row_arms(box: Control, c, arms_sz: Vector2 = Vector2(32, 38)) -> TextureRect:
	if box == null or c == null:
		return null
	_retire(box, "YearArmsHead")
	var head := HBoxContainer.new()
	head.name = "YearArmsHead"
	head.add_theme_constant_override("separation", 10)
	head.set_meta("field_route", "yearcard")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "YearArms"
	arms.set_meta("field_route", "yearcard")
	head.add_child(arms)
	box.add_child(head)
	if box is Container:
		box.move_child(head, 0)
	return arms


## Atlas travel strip: 团徽 + territory 领地徽 (TravelCrestStrip). Empty nation → 团徽 only.
static func place_travel_crest_strip(parent: Node, at: Vector2, territory_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "TravelCrestStrip")
	var host := Control.new()
	host.name = "TravelCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "travel_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(territory_nation)
	if nid != "":
		var terr := CKHeraldryChrome.make_territory_arms(nid, shield)
		terr.position = Vector2(shield.x + 8.0, 0)
		host.add_child(terr)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host


## Night-camp / road-event crest strip: 团徽 + 营地所在邦的领地徽 (CampCrestStrip).
static func place_camp_crest_strip(parent: Node, at: Vector2, territory_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "CampCrestStrip")
	var host := Control.new()
	host.name = "CampCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "camp_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(territory_nation)
	if nid != "":
		var terr := CKHeraldryChrome.make_territory_arms(nid, shield)
		terr.position = Vector2(shield.x + 8.0, 0)
		host.add_child(terr)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host


## Road encounter crest strip: 团徽 + 敌徽 (EncounterCrestStrip).
static func place_encounter_crest_strip(parent: Node, at: Vector2, foe_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "EncounterCrestStrip")
	var host := Control.new()
	host.name = "EncounterCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "encounter_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(foe_nation)
	if nid != "":
		var foe := CKHeraldryChrome.make_nation_arms(nid, shield)
		foe.position = Vector2(shield.x + 8.0, 0)
		host.add_child(foe)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host


## City / 城关 strip: 团徽 + territory (CityCrestStrip).
static func place_city_crest_strip(parent: Node, city_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "CityCrestStrip")
	var nid := World.nation_of(str(city_id))
	if nid == "":
		nid = str(World.node(str(city_id)).get("nation", ""))
	var host := Control.new()
	host.name = "CityCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "city_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	if nid != "":
		var nat := CKHeraldryChrome.make_city_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	host.set_meta("city_id", str(city_id))
	parent.add_child(host)
	return host


## Aftermath strip: 团徽 + optional foe (AftermathCrestStrip).
static func place_aftermath_crest_strip(parent: Node, at: Vector2, foe_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	_retire(parent, "AftermathCrestStrip")
	var host := Control.new()
	host.name = "AftermathCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "aftermath_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(foe_nation)
	if nid != "":
		var foe := CKHeraldryChrome.make_nation_arms(nid, shield)
		foe.position = Vector2(shield.x + 8.0, 0)
		host.add_child(foe)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	parent.add_child(host)
	return host


## Nation overview strip: 团徽 + nation arms (NationCrestStrip).
static func place_nation_crest_strip(parent: Node, nation_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("NationCrestStrip")
	if old:
		old.name = "_NationCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "NationCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "nation_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(nation_id)
	if nid != "":
		var nat := CKHeraldryChrome.make_city_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host


## Rite / 仪礼 strip: 团徽 + rite nation (RiteCrestStrip).
static func place_rite_crest_strip(parent: Node, heir, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("RiteCrestStrip")
	if old:
		old.name = "_RiteCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "RiteCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "rite_strip")
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	var gap := 8.0
	if heir != null:
		var la := CKHeraldryChrome.make_person_arms(heir, shield)
		la.name = "LeaderArms"
		la.position = Vector2(shield.x + gap, 0)
		host.add_child(la)
		host.size = Vector2(shield.x * 2.0 + gap, shield.y)
	else:
		host.size = Vector2(shield.x, shield.y)
	host.set_meta("has_heir", heir != null)
	parent.add_child(host)
	return host


## Muster / 点兵 strip: 团徽 + muster nation (MusterCrestStrip).
static func place_muster_crest_strip(parent: Node, leader, at: Vector2, shield: Vector2 = Vector2(40, 48)) -> Control:
	var old := parent.get_node_or_null("MusterCrestStrip")
	if old:
		old.name = "_MusterCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "MusterCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "muster_strip")
	var co := CKHeraldryChrome.make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	var gap := 8.0
	if leader != null:
		var la := CKHeraldryChrome.make_person_arms(leader, shield)
		la.name = "LeaderArms"
		la.position = Vector2(shield.x + gap, 0)
		host.add_child(la)
		host.size = Vector2(shield.x * 2.0 + gap, shield.y)
	else:
		host.size = Vector2(shield.x, shield.y)
	parent.add_child(host)
	return host


## Field / 战场 strip: 团徽 + field nation (FieldCrestStrip).
static func place_field_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("FieldCrestStrip")
	if old:
		old.name = "_FieldCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "FieldCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "field_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "FieldBanner"
	bn.tooltip_text = Locale.t("lb_field_arms")
	bn.set_meta("arms_kind", "lb_field_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Battle HUD crest strips (left/right). Field owns BattleHud strips.
static func place_battle_hud_crest_strips(
	parent: Node,
	foe_nation: String = "",
	vp: Vector2 = Vector2.ZERO,
	insets: Dictionary = {},
	mobile: bool = false,
	landscape: bool = false,
	shield: Vector2 = Vector2.ZERO,
) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("BattleHudCrestStrip")
	if old:
		old.name = "_BattleHudCrestStripDying"
		old.queue_free()
	var size_vp := vp
	if size_vp == Vector2.ZERO and parent is Control and (parent as Control).is_inside_tree():
		size_vp = (parent as Control).get_viewport().get_visible_rect().size
	if size_vp == Vector2.ZERO:
		size_vp = Vector2(1280, 720)
	var lay: Dictionary = CKHeraldryChrome.battle_hud_crest_layout(size_vp, insets, mobile, landscape, shield)
	var sh: Vector2 = lay["shield"]
	var host := Control.new()
	host.name = "BattleHudCrestStrip"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "battle_hud_strip")
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var player := CKHeraldryChrome.make_company_arms(sh)
	player.name = "PlayerArms"
	player.position = lay["player_at"]
	host.add_child(player)
	var nid := str(foe_nation)
	if nid != "":
		var foe := CKHeraldryChrome.make_nation_arms(nid, sh)
		foe.name = "EnemyArms"
		foe.position = lay["enemy_at"]
		host.add_child(foe)
	host.set_meta("foe_nation", nid)
	host.set_meta("has_enemy", nid != "")
	parent.add_child(host)
	return host


## Field roster row person arms. Field owns FieldRowArms.
static func attach_field_row_arms(row: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if row == null or c == null:
		return
	var old := row.get_node_or_null("FieldRowArms")
	if old:
		old.name = "_FieldRowArmsDying"
		old.queue_free()
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "FieldRowArms"
	arms.set_meta("field_route", "field_row")
	row.add_child(arms)
	row.move_child(arms, 0)


## Lone company CastleArms header (no banner cloth). Field owns CastleArms placement.
static func place_company_header(parent: Node, at: Vector2, size: Vector2 = Vector2(44, 52)) -> TextureRect:
	if parent == null:
		return null
	_retire(parent, "CastleArms")
	var tr := CKHeraldryChrome.make_company_arms(size)
	tr.position = at
	tr.set_meta("field_route", "company_header")
	parent.add_child(tr)
	return tr

## Battle host sync: resolve foe + device/insets and (re)place the HUD strip + order crests.
## Field owns BattleHudCrestStrip lifecycle; Chrome keeps battle_foe_nation_for / layout helpers.
static func sync_battle_hud_crests(host) -> void:
	if host == null:
		return
	var mobile := DeviceProfile.is_mobile()
	var land := false
	var insets: Dictionary = {}
	var vp := Vector2(1280, 720)
	if host is Control and (host as Control).is_inside_tree():
		vp = (host as Control).get_viewport().get_visible_rect().size
		land = mobile and vp.x > vp.y * 1.2
		if host.has_method("_safe_insets"):
			insets = host._safe_insets()
		elif host.has_meta("m_safe_insets"):
			insets = host.get_meta("m_safe_insets")
	place_battle_hud_crest_strips(
		host, CKHeraldryChrome.battle_foe_nation_for(host), vp, insets, mobile, land
	)
	if host.is_inside_tree():
		sync_battle_order_crests.call_deferred(host)
	else:
		sync_battle_order_crests(host)

## Skill tree header: 团徽 + skill banner cloth (SkillCrestStrip / SkillBanner).
static func place_skill_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	_retire(parent, "SkillCrestStrip")
	var host := Control.new()
	host.name = "SkillCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("field_route", "skill_strip")
	var arms := CKHeraldryChrome.make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := CKHeraldryChrome.make_company_banner(banner)
	bn.name = "SkillBanner"
	bn.tooltip_text = Locale.t("lb_skill_arms")
	bn.set_meta("arms_kind", "lb_skill_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Skill detail/head host: selected roster member person arms (SkillPersonArms), prepended.
static func attach_skill_person_arms(host: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if host == null or c == null:
		return null
	_retire(host, "SkillPersonArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "SkillPersonArms"
	arms.tooltip_text = Locale.t("lb_skill_arms")
	arms.set_meta("field_route", "skill_person")
	host.add_child(arms)
	host.move_child(arms, 0)
	return arms


## Lineage-info dossier plate: person arms (PersonArms). field_route marks Field ownership.
static func attach_lineage_info_arms(parent: Control, c, arms_sz: Vector2 = Vector2(48, 58)) -> TextureRect:
	if parent == null or c == null:
		return null
	_retire(parent, "PersonArms")
	_retire(parent, "LineageInfoArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "PersonArms"
	arms.set_meta("field_route", "lineage_info")
	parent.add_child(arms)
	return arms


## Title-promote request row: leader person arms (LeaderArms).
static func attach_title_leader_arms(parent: Node, leader, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(44, 52)) -> TextureRect:
	if parent == null or leader == null:
		return null
	_retire(parent, "LeaderArms")
	var arms := CKHeraldryChrome.make_person_arms(leader, arms_sz)
	arms.name = "LeaderArms"
	arms.position = at
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arms.set_meta("field_route", "title_leader")
	parent.add_child(arms)
	return arms


## Title ladder chip: rank badge (LadderBadge).
static func attach_ladder_badge(parent: Node, rank: String, badge_size: int = 26) -> TextureRect:
	if parent == null:
		return null
	_retire(parent, "LadderBadge")
	var badge := CKHeraldryChrome.make_rank_badge(str(rank), badge_size)
	badge.name = "LadderBadge"
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("field_route", "title_ladder_badge")
	badge.set_meta("rank_id", str(rank))
	parent.add_child(badge)
	return badge


## Marriage vow ritual plate: company arms (VowCompanyArms).
static func attach_vow_company_arms(parent: Node, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(40, 48)) -> TextureRect:
	if parent == null:
		return null
	_retire(parent, "VowCompanyArms")
	var arms := CKHeraldryChrome.make_company_arms(arms_sz)
	arms.name = "VowCompanyArms"
	arms.position = at
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arms.set_meta("field_route", "marriage_vow")
	parent.add_child(arms)
	return arms


## Rival-houses list/head: enemy nation arms (RivalArms).
static func attach_rival_arms(parent: Node, house, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(40, 48)) -> TextureRect:
	if parent == null or house == null:
		return null
	_retire(parent, "RivalArms")
	var arms := CKHeraldryChrome.make_rival_arms(house, arms_sz)
	arms.name = "RivalArms"
	arms.position = at
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arms.set_meta("field_route", "rival_arms")
	parent.add_child(arms)
	return arms


## Unit-dossier relation chip: person arms (ChipArms).
static func attach_dossier_chip_arms(parent: Node, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	if parent == null or c == null:
		return null
	_retire(parent, "ChipArms")
	var arms := CKHeraldryChrome.make_person_arms(c, arms_sz)
	arms.name = "ChipArms"
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arms.set_meta("field_route", "dossier_chip")
	parent.add_child(arms)
	return arms


## Unit-dossier relation chip: rank badge (ChipBadge).
static func attach_dossier_chip_badge(parent: Node, rank: String, badge_size: int = 22) -> TextureRect:
	if parent == null:
		return null
	_retire(parent, "ChipBadge")
	var badge := CKHeraldryChrome.make_rank_badge(str(rank), badge_size)
	badge.name = "ChipBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("field_route", "dossier_chip_badge")
	badge.set_meta("rank_id", str(rank))
	parent.add_child(badge)
	return badge


## Lineage-info dossier: rank badge beside PersonArms.
static func attach_lineage_rank_badge(parent: Node, rank: String, at: Vector2 = Vector2.ZERO, badge_size: int = 32) -> TextureRect:
	if parent == null:
		return null
	_retire(parent, "RankBadge")
	_retire(parent, "LineageRankBadge")
	var badge := CKHeraldryChrome.make_rank_badge(str(rank), badge_size)
	badge.name = "RankBadge"
	badge.position = at
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("field_route", "lineage_rank_badge")
	badge.set_meta("rank_id", str(rank))
	parent.add_child(badge)
	return badge


## Bloodline-codex nation rail: compact 邦徽 (CodexRailArms).
static func attach_codex_rail_arms(parent: Node, nation_id: String, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(22, 26)) -> TextureRect:
	if parent == null or str(nation_id) == "":
		return null
	_retire(parent, "CodexRailArms")
	var arms := CKHeraldryChrome.make_city_nation_arms(str(nation_id), arms_sz)
	arms.name = "CodexRailArms"
	arms.position = at
	arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arms.set_meta("field_route", "codex_rail")
	arms.set_meta("nation_id", str(nation_id))
	parent.add_child(arms)
	return arms

