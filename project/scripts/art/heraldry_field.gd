class_name CKHeraldryField
extends RefCounted
## Field chrome for surfaces #511 does not own: tavern hire strip, deploy reserve,
## battle card / forecast / report, annex serve rows, forge smith slots, shrine heal,
## and city 本城之事 affairs overlay (团徽 + 本城邦徽).
## 团徽 stays the company banner. A family id shows 族徽; no family id shows 旗徽.
## Enemy plates are 敌徽. No impale, quarter, or marriage marshalling.


static func _retire(parent: Node, node_name: String) -> void:
	if parent == null:
		return
	var old := parent.get_node_or_null(node_name)
	if old:
		old.name = "_Dying_%s" % node_name
		old.queue_free()


static func _host(parent: Node, node_name: String, at: Vector2, size: Vector2) -> Control:
	_retire(parent, node_name)
	var host := Control.new()
	host.name = node_name
	host.position = at
	host.size = size
	host.custom_minimum_size = size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var host := _host(parent, "TavernCrestStrip", at, Vector2(w, shield.y))
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
	var host := _host(parent, "ReserveCrestStrip", at, Vector2(w, shield.y))
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
	var host := _host(parent, "ReportCrestStrip", at, Vector2(w, shield.y))
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
	var host := _host(parent, "ForgeFocusStrip", at, Vector2(w, shield.y))
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
	var host := _host(parent, "ShrineHealStrip", at, Vector2(w, shield.y))
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
	var host := _host(parent, "AffairCrestStrip", at, Vector2(w, shield.y))
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

