class_name CKHeraldryChrome
extends RefCounted
## Shared player-facing heraldry chrome: 团徽 / 旗徽 / 族徽 + 爵位徽记 + 敌徽 + 邦徽.
## One design system everywhere (castle header/banner strip, genealogy, dossier,
## board unit shields, rival houses, tavern/hire cards, city/smith/market chrome,
## marriage house cards + crest strip, bloodline codex / shrine / banner rite,
## succession / heir-duel / annex, battle/danger aftermath, title/settings/save/pause shell).
## No marriage marshalling / per-person cadency — only company vs family vs nation arms + rank badge.

static func is_family_member(c) -> bool:
	if c == null:
		return false
	var fid := str(c.family_id)
	return fid != "" and GameState.families.has(fid)

static func arms_kind_key(c) -> String:
	## Locale key for the arms the player sees on this person.
	return "gen2_06" if is_family_member(c) else "gen2_35"

static func arms_kind_label(c) -> String:
	return Locale.t(arms_kind_key(c))

static func company_label() -> String:
	return Locale.t("gen2_36")

static func rival_label() -> String:
	return Locale.t("lb_rv_arms")

static func dossier_crest_label(c) -> String:
	return Locale.t("lb_dos_crest_family") if is_family_member(c) else Locale.t("lb_dos_crest_banner")

static func person_spec(c) -> Dictionary:
	## Family member → 族徽 (with canton); familyless → 旗徽/团徽.
	if c == null:
		return company_spec()
	var raw = GameState.arms_for_character(c)
	return raw if typeof(raw) == TYPE_DICTIONARY else company_spec()

static func company_spec() -> Dictionary:
	var raw = GameState.get("banner_spec")
	if typeof(raw) == TYPE_DICTIONARY and not (raw as Dictionary).is_empty():
		return raw
	return CKHeraldry.from_crest(str(GameState.crest_color))

static func nation_spec(nid: String, rank: String = "knight") -> Dictionary:
	return CKHeraldry.from_nation(str(nid), rank)

static func rival_spec(house) -> Dictionary:
	## Rival house dict or id → nation arms (敌徽). Never company/family.
	var nid := ""
	if typeof(house) == TYPE_DICTIONARY:
		nid = str(house.get("nation", house.get("id", "")))
	else:
		nid = str(house)
		for h in GameState.data_rivals.get("houses", []):
			if str(h.get("id", "")) == nid:
				nid = str(h.get("nation", nid))
				break
	if nid == "":
		nid = "ashbanner"
	return nation_spec(nid)

static func person_shield(c, w: int = 40, h: int = 48) -> Texture2D:
	return UnitArt.shield_arms(person_spec(c), w, h)

static func company_shield(w: int = 44, h: int = 52) -> Texture2D:
	return UnitArt.shield_arms(company_spec(), w, h)

static func company_banner(w: int = 28, h: int = 38) -> Texture2D:
	## Castle / atlas banner strip — always 团徽 cloth.
	return CKHeraldryRender.compose_texture(company_spec(), w, h, 0.0, "banner")

static func rival_shield(house, w: int = 40, h: int = 48) -> Texture2D:
	return UnitArt.shield_arms(rival_spec(house), w, h)

static func person_banner(c, w: int = 320, h: int = 440) -> Texture2D:
	## Full-size crest overlay (dossier). Family arms use shield mode so canton reads.
	var spec := person_spec(c)
	if is_family_member(c):
		return UnitArt.achievement_arms(spec, w, h)
	return CKHeraldryRender.compose_texture(spec, w, h, 0.0, "banner")

static func make_company_arms(size: Vector2 = Vector2(44, 52)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "CastleArms"
	tr.texture = company_shield(int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = company_label()
	tr.set_meta("arms_kind", "gen2_36")
	tr.set_meta("arms_core", CKHeraldry.core_key(company_spec()))
	return tr

static func make_company_banner(size: Vector2 = Vector2(28, 38)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "CastleBanner"
	tr.texture = company_banner(int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = company_label()
	tr.set_meta("arms_kind", "gen2_36")
	tr.set_meta("arms_core", CKHeraldry.core_key(company_spec()))
	return tr

static func make_person_arms(c, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "PersonArms"
	tr.texture = person_shield(c, int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = arms_kind_label(c)
	tr.set_meta("arms_kind", arms_kind_key(c))
	tr.set_meta("arms_core", CKHeraldry.core_key(person_spec(c)))
	return tr

static func make_rival_arms(house, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "RivalArms"
	tr.texture = rival_shield(house, int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = rival_label()
	tr.set_meta("arms_kind", "lb_rv_arms")
	tr.set_meta("arms_core", CKHeraldry.core_key(rival_spec(house)))
	var nid := ""
	if typeof(house) == TYPE_DICTIONARY:
		nid = str(house.get("nation", house.get("id", "")))
	else:
		nid = str(house)
	tr.set_meta("nation_id", nid)
	return tr

static func make_rank_badge(rank: String, size: int = 28) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "RankBadge"
	tr.texture = CKHeraldryRender.rank_badge(str(rank), size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Corner chrome on genealogy avatar-wall / tree nodes: mini 族徽|旗徽 + 爵位徽记.
static func attach_cell_chrome(host: Control, c, cell: Vector2, portrait_top: float = 6.0) -> void:
	if c == null or host == null:
		return
	var arms_sz := Vector2(28, 34)
	var badge_sz := 22
	if cell.x >= 150.0:
		arms_sz = Vector2(36, 44)
		badge_sz = 28
	## Arms sit on the portrait's lower-left; rank badge on the upper-right (clears 家主 chip).
	var arms := make_person_arms(c, arms_sz)
	arms.name = "CellArms"
	var por_h := 88.0 if cell.x < 150.0 else 132.0
	arms.position = Vector2(6.0, portrait_top + por_h - arms_sz.y - 2.0)
	host.add_child(arms)
	var badge := make_rank_badge(str(c.rank), badge_sz)
	badge.name = "CellBadge"
	badge.position = Vector2(cell.x - float(badge_sz) - 4.0, portrait_top + 2.0)
	host.add_child(badge)

static func attach_node_chrome(host: Control, c, node: Vector2) -> void:
	if c == null or host == null:
		return
	var arms := make_person_arms(c, Vector2(30, 36))
	arms.name = "NodeArms"
	arms.position = Vector2(4, 4)
	host.add_child(arms)
	var badge := make_rank_badge(str(c.rank), 22)
	badge.name = "NodeBadge"
	badge.position = Vector2(node.x - 26.0, 4)
	host.add_child(badge)

## Hire / tavern / roster portrait plate: 旗徽|族徽 on lower-left of the plate rect.
static func attach_hire_chrome(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(36, 44)) -> void:
	if parent == null or c == null:
		return
	var old := parent.get_node_or_null("HireArms")
	if old:
		old.queue_free()
	var arms := make_person_arms(c, arms_sz)
	arms.name = "HireArms"
	arms.position = Vector2(plate.position.x + 4.0, plate.position.y + plate.size.y - arms_sz.y - 4.0)
	parent.add_child(arms)

static func place_company_header(parent: Node, at: Vector2, size: Vector2 = Vector2(44, 52)) -> TextureRect:
	var old := parent.get_node_or_null("CastleArms")
	if old:
		old.name = "_CastleArmsDying"
		old.queue_free()
	var tr := make_company_arms(size)
	tr.position = at
	parent.add_child(tr)
	return tr

## Title / settings / save / pause shell crest strip: 团徽 + 旗徽 cloth.
## Host name ShellCrestStrip — distinct from CastleBannerStrip so shell suites do not collide with hub asserts.
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
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host

## Save-slot / load-card row arms: prepend 团徽 so every slot row carries company chrome.
## Empty slots still get the plate (disabled load button already signals emptiness).
static func attach_save_row_arms(row: Control, size: Vector2 = Vector2(36, 44)) -> TextureRect:
	if row == null:
		return null
	var old := row.get_node_or_null("SlotArms")
	if old:
		old.name = "_SlotArmsDying"
		old.queue_free()
	var tr := make_company_arms(size)
	tr.name = "SlotArms"
	# Prefer HBox prepend when the row lays out horizontally.
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

## Castle hub banner strip: 团徽 shield + cloth banner side by side under the top bar.
static func place_castle_banner_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(44, 52), banner: Vector2 = Vector2(28, 38)) -> Control:
	var old := parent.get_node_or_null("CastleBannerStrip")
	if old:
		old.queue_free()
	var host := Control.new()
	host.name = "CastleBannerStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host

## Board / battle token: person (or company) shield core key — suite asserts never mismatch.
static func token_shield_core(c, team: String = "player") -> String:
	if str(team) != "player":
		return ""
	return CKHeraldry.core_key(person_spec(c))

## Blit mini 旗徽|族徽 onto a board token image (lower-left). Player team only.
static func blit_token_shield(img: Image, c, team: String = "player") -> void:
	if img == null or c == null or str(team) != "player":
		return
	var S := mini(img.get_width(), img.get_height())
	var sw := maxi(10, int(S * 0.34))
	var sh := maxi(12, int(sw * 1.18))
	var tex := person_shield(c, sw, sh)
	if tex == null:
		return
	var simg: Image = tex.get_image()
	if simg == null or simg.is_empty():
		return
	if simg.is_compressed():
		simg.decompress()
	simg.convert(Image.FORMAT_RGBA8)
	var ox := 2
	var oy := img.get_height() - sh - 2
	img.blit_rect(simg, Rect2i(0, 0, sw, sh), Vector2i(ox, oy))

## Nation / foe shield (敌徽). Shared plate; city chrome uses make_city_nation_arms for 邦徽.
static func nation_shield(nid: String, w: int = 40, h: int = 48) -> Texture2D:
	return UnitArt.shield_arms(nation_spec(nid), w, h)

static func make_nation_arms(nid: String, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "FoeArms"
	tr.texture = nation_shield(str(nid), int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = rival_label()
	tr.set_meta("arms_kind", "lb_rv_arms")
	tr.set_meta("arms_core", CKHeraldry.core_key(nation_spec(str(nid))))
	tr.set_meta("nation_id", str(nid))
	return tr

static func make_city_nation_arms(nid: String, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "CityNationArms"
	tr.texture = nation_shield(str(nid), int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = Locale.t("lb_city_arms")
	tr.set_meta("arms_kind", "lb_city_arms")
	tr.set_meta("arms_core", CKHeraldry.core_key(nation_spec(str(nid))))
	tr.set_meta("nation_id", str(nid))
	return tr

## City hub crest strip: 团徽 + host-nation 邦徽 (side card / smith / market).
static func place_city_crest_strip(parent: Node, city_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("CityCrestStrip")
	if old:
		old.queue_free()
	var nid := World.nation_of(str(city_id))
	if nid == "":
		nid = str(World.node(str(city_id)).get("nation", ""))
	var host := Control.new()
	host.name = "CityCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	if nid != "":
		var nat := make_city_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	host.set_meta("city_id", str(city_id))
	parent.add_child(host)
	return host

## Battle / danger aftermath crest strip: 团徽 + optional foe 敌徽 (nation of the fight).
## Host name AftermathCrestStrip so suites can assert both arms without walking siblings.
static func place_aftermath_crest_strip(parent: Node, at: Vector2, foe_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("AftermathCrestStrip")
	if old:
		old.queue_free()
	var host := Control.new()
	host.name = "AftermathCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(foe_nation)
	if nid != "":
		var foe := make_nation_arms(nid, shield)
		foe.position = Vector2(shield.x + 8.0, 0)
		host.add_child(foe)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	parent.add_child(host)
	return host

## Bloodline-codex / shrine nation crest strip: 团徽 + 邦徽 for the focused nation.
## Host name NationCrestStrip. Distinct from CityCrestStrip (city_id meta) — this one keys on nation_id only.
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
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(nation_id)
	if nid != "":
		var nat := make_city_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host

## Banner-rite crest strip: 团徽 + selected heir 族徽|旗徽 (LeaderArms). Empty selection → 团徽 only.
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
	var co := make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	var gap := 8.0
	if heir != null:
		var la := make_person_arms(heir, shield)
		la.name = "LeaderArms"
		la.position = Vector2(shield.x + gap, 0)
		host.add_child(la)
		host.size = Vector2(shield.x * 2.0 + gap, shield.y)
	else:
		host.size = Vector2(shield.x, shield.y)
	host.set_meta("has_heir", heir != null)
	parent.add_child(host)
	return host

## Succession clash strip: 团徽 + named heir 族徽|旗徽 (SuccessionCrestStrip).
static func place_succession_crest_strip(parent: Node, heir, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("SuccessionCrestStrip")
	if old:
		old.name = "_SuccessionCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "SuccessionCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var co := make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	var gap := 8.0
	if heir != null:
		var la := make_person_arms(heir, shield)
		la.name = "LeaderArms"
		la.position = Vector2(shield.x + gap, 0)
		host.add_child(la)
		host.size = Vector2(shield.x * 2.0 + gap, shield.y)
	else:
		host.size = Vector2(shield.x, shield.y)
	host.set_meta("has_heir", heir != null)
	parent.add_child(host)
	return host

## Heir-trial duel strip: 团徽 + heir A + heir B 族徽|旗徽 (DuelCrestStrip). Missing side omitted.
static func place_duel_crest_strip(parent: Node, left_c, right_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("DuelCrestStrip")
	if old:
		old.name = "_DuelCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "DuelCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := 8.0
	var x := 0.0
	var co := make_company_arms(shield)
	co.position = Vector2(x, 0)
	host.add_child(co)
	x += shield.x + gap
	if left_c != null:
		var la := make_person_arms(left_c, shield)
		la.name = "LeftArms"
		la.position = Vector2(x, 0)
		host.add_child(la)
		x += shield.x + gap
	if right_c != null:
		var ra := make_person_arms(right_c, shield)
		ra.name = "RightArms"
		ra.position = Vector2(x, 0)
		host.add_child(ra)
		x += shield.x
	else:
		x -= gap
	host.size = Vector2(maxf(shield.x, x), shield.y)
	host.set_meta("has_left", left_c != null)
	host.set_meta("has_right", right_c != null)
	parent.add_child(host)
	return host

## Marriage house-card plate: 族徽|旗徽 as HouseArms (lower-left of portrait plate).
static func attach_house_card_chrome(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(32, 38)) -> void:
	if parent == null or c == null:
		return
	var old := parent.get_node_or_null("HouseArms")
	if old:
		old.queue_free()
	var arms := make_person_arms(c, arms_sz)
	arms.name = "HouseArms"
	arms.position = Vector2(plate.position.x + 4.0, plate.position.y + plate.size.y - arms_sz.y - 4.0)
	parent.add_child(arms)

## Marriage protocol strip: 团徽 + left (suitor) + right (candidate/spouse) 族徽|旗徽.
## Never marshalls/impales — three separate shields. Re-place renames dying node.
static func place_marriage_crest_strip(parent: Node, left_c, right_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("MarriageCrestStrip")
	if old:
		old.name = "_MarriageCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "MarriageCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := 8.0
	var x := 0.0
	var co := make_company_arms(shield)
	co.position = Vector2(x, 0)
	host.add_child(co)
	x += shield.x + gap
	if left_c != null:
		var la := make_person_arms(left_c, shield)
		la.name = "LeftArms"
		la.position = Vector2(x, 0)
		host.add_child(la)
		x += shield.x + gap
	if right_c != null:
		var ra := make_person_arms(right_c, shield)
		ra.name = "RightArms"
		ra.position = Vector2(x, 0)
		host.add_child(ra)
		x += shield.x
	else:
		x -= gap
	host.size = Vector2(maxf(shield.x, x), shield.y)
	host.set_meta("has_left", left_c != null)
	host.set_meta("has_right", right_c != null)
	parent.add_child(host)
	return host
## Commission-board issuer crest: 团徽 when the post is from home (hq), else nation 敌徽-style arms.
static func issuer_is_home(issuer_id: String) -> bool:
	## Company seat posts use 团徽; every other city uses its nation plate.
	var id := str(issuer_id)
	return id == "" or id == "hq"

## Deploy / muster card plate: 族徽|旗徽 as DeployArms (lower-left of portrait plate).
static func attach_deploy_chrome(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(36, 44)) -> void:
	if parent == null or c == null:
		return
	var old := parent.get_node_or_null("DeployArms")
	if old:
		old.queue_free()
	var arms := make_person_arms(c, arms_sz)
	arms.name = "DeployArms"
	arms.position = Vector2(plate.position.x + 4.0, plate.position.y + plate.size.y - arms_sz.y - 4.0)
	parent.add_child(arms)

## Train / pick-row inline arms (HBox-friendly). Caller parents the returned TextureRect.
static func make_row_arms(c, size: Vector2 = Vector2(28, 34)) -> TextureRect:
	var arms := make_person_arms(c, size)
	arms.name = "RowArms"
	return arms

## Muster strip: 团徽 + focused leader 族徽|旗徽 — deploy / title ladder header.
static func place_muster_crest_strip(parent: Node, leader, at: Vector2, shield: Vector2 = Vector2(40, 48)) -> Control:
	var old := parent.get_node_or_null("MusterCrestStrip")
	if old:
		old.name = "_MusterCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "MusterCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var co := make_company_arms(shield)
	co.position = Vector2.ZERO
	host.add_child(co)
	var gap := 8.0
	if leader != null:
		var la := make_person_arms(leader, shield)
		la.name = "LeaderArms"
		la.position = Vector2(shield.x + gap, 0)
		host.add_child(la)
		host.size = Vector2(shield.x * 2.0 + gap, shield.y)
	else:
		host.size = Vector2(shield.x, shield.y)
	parent.add_child(host)
	return host
static func issuer_spec(issuer_id: String) -> Dictionary:
	if issuer_is_home(issuer_id):
		return company_spec()
	var nid := World.nation_of(str(issuer_id))
	if nid == "":
		return company_spec()
	return nation_spec(nid)

static func issuer_arms_kind(issuer_id: String) -> String:
	return "gen2_36" if issuer_is_home(issuer_id) else "lb_board_arms"

static func issuer_arms_label(issuer_id: String) -> String:
	return company_label() if issuer_is_home(issuer_id) else Locale.t("lb_board_arms")

static func make_issuer_arms(issuer_id: String, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "BoardCrest"
	tr.texture = UnitArt.shield_arms(issuer_spec(issuer_id), int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = issuer_arms_label(issuer_id)
	tr.set_meta("arms_kind", issuer_arms_kind(issuer_id))
	tr.set_meta("arms_core", CKHeraldry.core_key(issuer_spec(issuer_id)))
	tr.set_meta("issuer_id", str(issuer_id))
	return tr

## Pin issuer crest on a commission-board detail / offer host (replaces prior BoardCrest).
static func place_board_crest(parent: Node, issuer_id: String, at: Vector2, size: Vector2 = Vector2(44, 52)) -> TextureRect:
	if parent == null:
		return null
	var old := parent.get_node_or_null("BoardCrest")
	if old:
		old.queue_free()
	var tr := make_issuer_arms(issuer_id, size)
	tr.position = at
	parent.add_child(tr)
	return tr

## Resolve foe nation for an in-battle HUD: meta → World.encounter → map.nation/foe_nation.
static func battle_foe_nation_for(host) -> String:
	var n := str(GameState.get_meta("battle_foe_nation", ""))
	if n != "":
		return n
	if typeof(World.encounter) == TYPE_DICTIONARY:
		n = str(World.encounter.get("nation", ""))
		if n != "":
			return n
	if host == null:
		return ""
	var mid := str(host.get("map_id") if host.get("map_id") != null else "")
	if mid == "":
		return ""
	var m: Dictionary = BattleMaps.get_map(mid)
	n = str(m.get("nation", m.get("foe_nation", "")))
	return n


## Pure layout for 双方纹章条 — player left, enemy right; inset-aware.
## Returns {player_at, enemy_at, shield, gap}.
static func battle_hud_crest_layout(
	vp: Vector2,
	insets: Dictionary = {},
	mobile: bool = false,
	landscape: bool = false,
	shield: Vector2 = Vector2.ZERO,
) -> Dictionary:
	var sh: Vector2 = shield
	if sh == Vector2.ZERO:
		if mobile and landscape:
			sh = Vector2(40, 48)
		elif mobile:
			sh = Vector2(36, 44)
		else:
			sh = Vector2(36, 44)
	var top := float(insets.get("top", 0.0))
	var left := float(insets.get("left", 0.0))
	var right := float(insets.get("right", 0.0))
	var y := top + (10.0 if mobile else 8.0)
	var pad := 12.0 if mobile else 16.0
	var p_at := Vector2(left + pad, y)
	var e_at := Vector2(maxf(p_at.x + sh.x + 24.0, vp.x - right - pad - sh.x), y)
	return {"player_at": p_at, "enemy_at": e_at, "shield": sh, "gap": 8.0}


## In-battle HUD 双方纹章条: PlayerArms (团徽) left + EnemyArms (敌徽) right.
## Host name BattleHudCrestStrip. MOUSE_FILTER_IGNORE — never steals InputRouter taps.
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
	var lay: Dictionary = battle_hud_crest_layout(size_vp, insets, mobile, landscape, shield)
	var sh: Vector2 = lay["shield"]
	var host := Control.new()
	host.name = "BattleHudCrestStrip"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var player := make_company_arms(sh)
	player.name = "PlayerArms"
	player.position = lay["player_at"]
	host.add_child(player)
	var nid := str(foe_nation)
	if nid != "":
		var foe := make_nation_arms(nid, sh)
		foe.name = "EnemyArms"
		foe.position = lay["enemy_at"]
		host.add_child(foe)
	host.set_meta("foe_nation", nid)
	host.set_meta("has_enemy", nid != "")
	parent.add_child(host)
	return host


## Battle host sync: resolve foe + device/insets and (re)place the strip.
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
		host, battle_foe_nation_for(host), vp, insets, mobile, land
	)

## Territory / domain shield (领地徽). Same plate as city nation arms; distinct node name for atlas travel/camp.
static func make_territory_arms(nid: String, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "TerritoryArms"
	tr.texture = nation_shield(str(nid), int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = Locale.t("lb_territory_arms")
	tr.set_meta("arms_kind", "lb_territory_arms")
	tr.set_meta("arms_core", CKHeraldry.core_key(nation_spec(str(nid))))
	tr.set_meta("nation_id", str(nid))
	return tr

## Atlas travel HUD / halt / stopover: 团徽 + 领地徽 (nation underfoot or along the route).
## Host name TravelCrestStrip.
static func place_travel_crest_strip(parent: Node, at: Vector2, territory_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("TravelCrestStrip")
	if old:
		old.name = "_TravelCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "TravelCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(territory_nation)
	if nid != "":
		var terr := make_territory_arms(nid, shield)
		terr.position = Vector2(shield.x + 8.0, 0)
		host.add_child(terr)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host

## Night-camp / road-event crest strip: 团徽 + 营地所在邦的领地徽.
## Host name CampCrestStrip.
static func place_camp_crest_strip(parent: Node, at: Vector2, territory_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("CampCrestStrip")
	if old:
		old.name = "_CampCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "CampCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(territory_nation)
	if nid != "":
		var terr := make_territory_arms(nid, shield)
		terr.position = Vector2(shield.x + 8.0, 0)
		host.add_child(terr)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host

## Road encounter crest strip: 团徽 + 敌徽 (foe nation of the clash). Distinct from AftermathCrestStrip.
## Host name EncounterCrestStrip.
static func place_encounter_crest_strip(parent: Node, at: Vector2, foe_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("EncounterCrestStrip")
	if old:
		old.name = "_EncounterCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "EncounterCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	var nid := str(foe_nation)
	if nid != "":
		var foe := make_nation_arms(nid, shield)
		foe.position = Vector2(shield.x + 8.0, 0)
		host.add_child(foe)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host
