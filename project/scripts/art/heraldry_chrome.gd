class_name CKHeraldryChrome
extends RefCounted
## Shared player-facing heraldry chrome: 团徽 / 旗徽 / 族徽 + 爵位徽记 + 敌徽 + 邦徽.
## One design system everywhere (castle header/banner strip, genealogy, dossier,
## board unit shields, rival houses, tavern/hire cards, city/smith/market chrome,
## marriage house cards + crest strip, bloodline codex / shrine / banner rite,
## succession / heir-duel / annex, battle HUD / aftermath, court gazette / year-card chronicle,
## title/settings/save/pause shell).
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

static func company_banner_texture(w: int = 28, h: int = 38) -> Texture2D:
	return CKHeraldryField.company_banner_texture(w, h)

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

## Corner chrome on genealogy avatar-wall / tree nodes. Field owns the shield and the live rank badge.
static func attach_cell_chrome(host: Control, c, cell: Vector2, portrait_top: float = 6.0) -> void:
	CKHeraldryField.attach_wall_tile_arms(host, c, cell, portrait_top)

static func attach_node_chrome(host: Control, c, node: Vector2) -> void:
	CKHeraldryField.attach_tree_node_arms(host, c, node)

## Hire / tavern / roster portrait plate: 旗徽|族徽 on lower-left of the plate rect.
static func attach_hire_chrome(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(36, 44)) -> void:
	CKHeraldryField.attach_hire_plate_arms(parent, c, plate, arms_sz)

## Lone company CastleArms header. Field owns CastleArms placement.
static func place_company_header(parent: Node, at: Vector2, size: Vector2 = Vector2(44, 52)) -> TextureRect:
	return CKHeraldryField.place_company_header(parent, at, size)

## Title / settings / save / pause shell crest strip: 团徽 + 旗徽 cloth.
## Host name ShellCrestStrip — distinct from CastleBannerStrip so shell suites do not collide with hub asserts.
static func place_shell_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(44, 52), banner: Vector2 = Vector2(28, 38)) -> Control:
	return CKHeraldryField.place_shell_crest_strip(parent, at, shield, banner)


## Save-slot / load-card row arms. Field owns the plate; crest_hex stays the slot crest.
static func attach_save_row_arms(row: Control, size: Vector2 = Vector2(36, 44), crest_hex: String = "") -> TextureRect:
	return CKHeraldryField.attach_save_row_arms(row, size, crest_hex)

## Castle hub banner strip: 团徽 shield + cloth banner side by side under the top bar.
static func place_castle_banner_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(44, 52), banner: Vector2 = Vector2(28, 38)) -> Control:
	return CKHeraldryField.place_banner_plate(parent, at, shield, banner)

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

## City crest strip. Field owns CityCrestStrip.
static func place_city_crest_strip(parent: Node, city_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_city_crest_strip(parent, city_id, at, shield)

## Aftermath crest strip. Field owns AftermathCrestStrip.
static func place_aftermath_crest_strip(parent: Node, at: Vector2, foe_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_aftermath_crest_strip(parent, at, foe_nation, shield)

## Nation crest strip. Field owns NationCrestStrip.
static func place_nation_crest_strip(parent: Node, nation_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_nation_crest_strip(parent, nation_id, at, shield)

## Rite crest strip. Field owns RiteCrestStrip.
static func place_rite_crest_strip(parent: Node, heir, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_rite_crest_strip(parent, heir, at, shield)

## Succession clash strip: 团徽 + named heir 族徽|旗徽 (SuccessionCrestStrip). Field-owned.
static func place_succession_crest_strip(parent: Node, heir, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_succession_crest_strip(parent, heir, at, shield)


## Heir-trial duel strip: 团徽 + A + B. Field-owned.
static func place_duel_crest_strip(parent: Node, left_c, right_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_duel_crest_strip(parent, left_c, right_c, at, shield)


## Marriage house-card plate HouseArms. Field-owned.
static func attach_house_card_chrome(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(32, 38)) -> void:
	CKHeraldryField.attach_house_card_arms(parent, c, plate, arms_sz)


## Marriage protocol strip: 团徽 + suitor + candidate. Field-owned.
static func place_marriage_crest_strip(parent: Node, left_c, right_c, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_marriage_crest_strip(parent, left_c, right_c, at, shield)

static func issuer_is_home(issuer_id: String) -> bool:
	## Company seat posts use 团徽; every other city uses its nation plate.
	var id := str(issuer_id)
	return id == "" or id == "hq"

## Deploy / muster card plate. Field owns DeployArms via attach_deploy_slot_arms.
static func attach_deploy_chrome(parent: Control, c, plate: Rect2, arms_sz: Vector2 = Vector2(36, 44)) -> void:
	CKHeraldryField.attach_deploy_slot_arms(parent, c, plate, arms_sz)

## Train / pick-row inline arms (HBox-friendly). Caller parents the returned TextureRect.
static func make_row_arms(c, size: Vector2 = Vector2(28, 34)) -> TextureRect:
	var arms := make_person_arms(c, size)
	arms.name = "RowArms"
	return arms

## Muster crest strip. Field owns MusterCrestStrip.
static func place_muster_crest_strip(parent: Node, leader, at: Vector2, shield: Vector2 = Vector2(40, 48)) -> Control:
	return CKHeraldryField.place_muster_crest_strip(parent, leader, at, shield)


static func attach_title_leader_arms(parent: Node, leader, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(44, 52)) -> TextureRect:
	return CKHeraldryField.attach_title_leader_arms(parent, leader, at, arms_sz)


static func attach_ladder_badge(parent: Node, rank: String, badge_size: int = 26) -> TextureRect:
	return CKHeraldryField.attach_ladder_badge(parent, rank, badge_size)


static func attach_vow_company_arms(parent: Node, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(40, 48)) -> TextureRect:
	return CKHeraldryField.attach_vow_company_arms(parent, at, arms_sz)

static func attach_rival_arms(parent: Node, house, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(40, 48)) -> TextureRect:
	return CKHeraldryField.attach_rival_arms(parent, house, at, arms_sz)


static func attach_dossier_chip_arms(parent: Node, c, arms_sz: Vector2 = Vector2(28, 34)) -> TextureRect:
	return CKHeraldryField.attach_dossier_chip_arms(parent, c, arms_sz)


static func attach_dossier_chip_badge(parent: Node, rank: String, badge_size: int = 22) -> TextureRect:
	return CKHeraldryField.attach_dossier_chip_badge(parent, rank, badge_size)


static func attach_lineage_rank_badge(parent: Node, rank: String, at: Vector2 = Vector2.ZERO, badge_size: int = 32) -> TextureRect:
	return CKHeraldryField.attach_lineage_rank_badge(parent, rank, at, badge_size)


static func attach_codex_rail_arms(parent: Node, nation_id: String, at: Vector2 = Vector2.ZERO, arms_sz: Vector2 = Vector2(22, 26)) -> TextureRect:
	return CKHeraldryField.attach_codex_rail_arms(parent, nation_id, at, arms_sz)

static func attach_site_company_banner(parent: Node, at: Vector2 = Vector2.ZERO, banner_sz: Vector2 = Vector2(26, 36)) -> TextureRect:
	return CKHeraldryField.attach_site_company_banner(parent, at, banner_sz)


static func attach_dossier_crest_banner(parent: Node, c, at: Vector2 = Vector2.ZERO, banner_sz: Vector2 = Vector2(320, 440)) -> TextureRect:
	return CKHeraldryField.attach_dossier_crest_banner(parent, c, at, banner_sz)



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
	return CKHeraldryField.place_board_crest(parent, issuer_id, at, size)

## Resolve foe nation — Field owns; Chrome thin shim.
static func battle_foe_nation_for(host) -> String:
	return CKHeraldryField.battle_foe_nation_for(host)


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


## Battle HUD crest strips. Field owns BattleHud strips.
static func place_battle_hud_crest_strips(
	parent: Node,
	foe_nation: String = "",
	vp: Vector2 = Vector2.ZERO,
	insets: Dictionary = {},
	mobile: bool = false,
	landscape: bool = false,
	shield: Vector2 = Vector2.ZERO,
) -> Control:
	return CKHeraldryField.place_battle_hud_crest_strips(parent, foe_nation, vp, insets, mobile, landscape, shield)

## Battle host sync. Field owns BattleHudCrestStrip sync.
static func sync_battle_hud_crests(host) -> void:
	CKHeraldryField.sync_battle_hud_crests(host)

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

## Atlas travel strip. Field owns TravelCrestStrip.
static func place_travel_crest_strip(parent: Node, at: Vector2, territory_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_travel_crest_strip(parent, at, territory_nation, shield)

## Night-camp crest strip. Field owns CampCrestStrip.
static func place_camp_crest_strip(parent: Node, at: Vector2, territory_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_camp_crest_strip(parent, at, territory_nation, shield)

## Road encounter crest strip. Field owns EncounterCrestStrip.
static func place_encounter_crest_strip(parent: Node, at: Vector2, foe_nation: String = "", shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_encounter_crest_strip(parent, at, foe_nation, shield)

## Field crest strip. Field owns FieldCrestStrip.
static func place_field_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_field_crest_strip(parent, at, shield, banner)

## Field roster row arms. Field owns FieldRowArms.
static func attach_field_row_arms(row: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	CKHeraldryField.attach_field_row_arms(row, c, arms_sz)

## Yeartrace panel header. Field owns YeartraceArmsHead.
static func attach_yeartrace_arms(panel: Control, c = null, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	CKHeraldryField.attach_yeartrace_arms(panel, c, arms_sz)


## Dossier 私囊 plate. Field owns PursePlate.
static func place_purse_plate(parent: Node, c, purse_silver: int = 0, arms_sz: Vector2 = Vector2(28, 34)) -> Control:
	return CKHeraldryField.place_purse_plate(parent, c, purse_silver, arms_sz)

## Gazette / court-news nation plate (朝徽). Same art as 邦徽; distinct node name for suites.
static func make_gazette_nation_arms(nid: String, size: Vector2 = Vector2(40, 48)) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "GazetteNationArms"
	tr.texture = nation_shield(str(nid), int(size.x), int(size.y))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = Locale.t("lb_gazette_arms")
	tr.set_meta("arms_kind", "lb_gazette_arms")
	tr.set_meta("arms_core", CKHeraldry.core_key(nation_spec(str(nid))))
	tr.set_meta("nation_id", str(nid))
	return tr

## Court gazette strip. Field owns GazetteCrestStrip.
static func place_gazette_crest_strip(parent: Node, nation_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	return CKHeraldryField.place_gazette_crest_strip(parent, nation_id, at, shield)

## Pin 朝徽 on a court-news row. Field owns GazetteNationArms.
static func attach_news_row_arms(host: Control, nation_id: String, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	CKHeraldryField.attach_news_row_arms(host, nation_id, arms_sz)

## Year-card person plate. Field owns YearArmsHead.
static func attach_yearcard_row_arms(box: Control, c, arms_sz: Vector2 = Vector2(32, 38)) -> void:
	CKHeraldryField.attach_yearcard_row_arms(box, c, arms_sz)

## Market desk strip. Field owns MarketCrestStrip.
static func place_market_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_market_crest_strip(parent, at, shield, banner)


## Skill-tree header: 团徽 + 技徽旗布 (SkillCrestStrip).
static func place_skill_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_skill_crest_strip(parent, at, shield, banner)


## Prepend SkillPersonArms into a detail/head host for the selected roster member.
static func attach_skill_person_arms(host: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	CKHeraldryField.attach_skill_person_arms(host, c, arms_sz)

## Lineage-info dossier plate person arms (LineageInfoArms).
static func attach_lineage_info_arms(parent: Control, c, arms_sz: Vector2 = Vector2(48, 58)) -> TextureRect:
	return CKHeraldryField.attach_lineage_info_arms(parent, c, arms_sz)




## Hourglass / 时漏 strip. Field owns HourglassCrestStrip.
static func place_hourglass_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_hourglass_crest_strip(parent, at, shield, banner)


## Castle overview strip. Field owns CastleViewCrestStrip.
static func place_castle_view_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_castle_view_crest_strip(parent, at, shield, banner)


## Blood-assay strip. Field owns BloodCrestStrip.
static func place_blood_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_blood_crest_strip(parent, at, shield, banner)


## Pin BloodQueueArms. Field owns the person arms.
static func attach_blood_queue_arms(row: Control, c, arms_sz: Vector2 = Vector2(26, 32)) -> void:
	CKHeraldryField.attach_blood_queue_arms(row, c, arms_sz)

## Dialogue / chapter plate. Field owns DialogueCrestStrip.
static func place_dialogue_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_dialogue_crest_strip(parent, at, shield, banner)


## Speaker plate under the portrait. Field owns DialogueSpeakerArms.
static func attach_dialogue_speaker_arms(portrait_host: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	CKHeraldryField.attach_dialogue_speaker_arms(portrait_host, c, arms_sz)


## Mercenary roster page strip: 团徽 + 名册旗布 (RosterCrestStrip).
static func place_roster_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	return CKHeraldryField.place_roster_crest_strip(parent, at, shield, banner)


## Roster list-row person arms (RosterRowArms) pinned on the numbered row button.
static func attach_roster_row_arms(row: Control, c, arms_sz: Vector2 = Vector2(26, 32)) -> void:
	CKHeraldryField.attach_roster_row_arms(row, c, arms_sz)

