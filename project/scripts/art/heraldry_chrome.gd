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
	return CKHeraldryField.place_board_crest(parent, issuer_id, at, size)

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
	if host.is_inside_tree():
		CKHeraldryField.sync_battle_order_crests.call_deferred(host)
	else:
		CKHeraldryField.sync_battle_order_crests(host)

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

## Field-book / 属事处 header strip: 团徽 + 旗布 (FieldCrestStrip). Distinct from CastleBannerStrip.
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
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
	bn.name = "FieldBanner"
	bn.tooltip_text = Locale.t("lb_field_arms")
	bn.set_meta("arms_kind", "lb_field_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Prepend person FieldRowArms into a field-book HBox row (属事处名单).
static func attach_field_row_arms(row: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if row == null or c == null:
		return
	var old := row.get_node_or_null("FieldRowArms")
	if old:
		old.name = "_FieldRowArmsDying"
		old.queue_free()
	var arms := make_person_arms(c, arms_sz)
	arms.name = "FieldRowArms"
	row.add_child(arms)
	row.move_child(arms, 0)


## Yeartrace panel header: person YeartraceArms (岁课年迹). House mount uses company arms.
## Shrink-only — never expand in the dossier FamilyTree scroll (court_ui overlap guard).
static func attach_yeartrace_arms(panel: Control, c = null, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if panel == null:
		return
	var old := panel.get_node_or_null("YeartraceArmsHead")
	if old:
		old.name = "_YeartraceArmsHeadDying"
		old.queue_free()
	var head := HBoxContainer.new()
	head.name = "YeartraceArmsHead"
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_theme_constant_override("separation", 8)
	var arms: TextureRect
	if c != null:
		arms = make_person_arms(c, arms_sz)
	else:
		arms = make_company_arms(arms_sz)
	arms.name = "YeartraceArms"
	arms.tooltip_text = Locale.t("lb_yeartrace_arms")
	arms.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	arms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Keep person/company arms_kind; suites key off node name.
	head.add_child(arms)
	## Prefer sitting beside the existing mono title if present.
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


## Dossier 私囊 plate: PurseArms (person) + silver readout host. Caller parents into LifePanel.
static func place_purse_plate(parent: Node, c, purse_silver: int = 0, arms_sz: Vector2 = Vector2(28, 34)) -> Control:
	if parent == null or c == null:
		return null
	var old := parent.get_node_or_null("PursePlate")
	if old:
		old.name = "_PursePlateDying"
		old.queue_free()
	var host := HBoxContainer.new()
	host.name = "PursePlate"
	host.add_theme_constant_override("separation", 8)
	var arms := make_person_arms(c, arms_sz)
	arms.name = "PurseArms"
	arms.tooltip_text = Locale.t("lb_purse_arms")
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

## Court gazette strip: 团徽 + nation 朝徽/邦徽 (GazetteCrestStrip). Empty nation → 团徽 only.
static func place_gazette_crest_strip(parent: Node, nation_id: String, at: Vector2, shield: Vector2 = Vector2(36, 44)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("GazetteCrestStrip")
	if old:
		old.name = "_GazetteCrestStripDying"
		old.queue_free()
	var nid := str(nation_id)
	if nid == "":
		nid = World.nation_of(str(World.pos))
	if nid == "":
		nid = "ashbanner"
	var host := Control.new()
	host.name = "GazetteCrestStrip"
	host.position = at
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var w := shield.x
	if nid != "":
		var nat := make_gazette_nation_arms(nid, shield)
		nat.position = Vector2(shield.x + 8.0, 0)
		host.add_child(nat)
		w = shield.x * 2.0 + 8.0
	host.size = Vector2(w, shield.y)
	host.set_meta("nation_id", nid)
	parent.add_child(host)
	return host

## Pin 朝徽 on a court-news row top bar (HBox). Replaces prior GazetteNationArms under host.
static func attach_news_row_arms(host: Control, nation_id: String, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if host == null or str(nation_id) == "":
		return
	var old := host.get_node_or_null("GazetteNationArms")
	if old:
		old.name = "_GazetteNationArmsDying"
		old.queue_free()
	var arms := make_gazette_nation_arms(str(nation_id), arms_sz)
	host.add_child(arms)
	host.move_child(arms, 0)

## Year-card / chronicle person plate: prepend YearArms into a VBox row box via head HBox.
static func attach_yearcard_row_arms(box: Control, c, arms_sz: Vector2 = Vector2(32, 38)) -> void:
	if box == null or c == null:
		return
	var old := box.get_node_or_null("YearArmsHead")
	if old:
		old.name = "_YearArmsHeadDying"
		old.queue_free()
	var head := HBoxContainer.new()
	head.name = "YearArmsHead"
	head.add_theme_constant_override("separation", 10)
	var arms := make_person_arms(c, arms_sz)
	arms.name = "YearArms"
	head.add_child(arms)
	box.add_child(head)
	box.move_child(head, 0)

## Market desk strip: 团徽 + 市集旗布 (MarketCrestStrip). Distinct from CityCrestStrip.
static func place_market_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("MarketCrestStrip")
	if old:
		old.name = "_MarketCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "MarketCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
	bn.name = "MarketBanner"
	bn.tooltip_text = Locale.t("lb_market_arms")
	bn.set_meta("arms_kind", "lb_market_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Skill-tree header: 团徽 + 技徽旗布 (SkillCrestStrip).
static func place_skill_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("SkillCrestStrip")
	if old:
		old.name = "_SkillCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "SkillCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
	bn.name = "SkillBanner"
	bn.tooltip_text = Locale.t("lb_skill_arms")
	bn.set_meta("arms_kind", "lb_skill_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Prepend SkillPersonArms into a detail/head host for the selected roster member.
static func attach_skill_person_arms(host: Control, c, arms_sz: Vector2 = Vector2(28, 34)) -> void:
	if host == null or c == null:
		return
	var old := host.get_node_or_null("SkillPersonArms")
	if old:
		old.name = "_SkillPersonArmsDying"
		old.queue_free()
	var arms := make_person_arms(c, arms_sz)
	arms.name = "SkillPersonArms"
	arms.tooltip_text = Locale.t("lb_skill_arms")
	host.add_child(arms)
	host.move_child(arms, 0)


## Hourglass / 时漏 strip: 团徽 + 时漏旗布 (HourglassCrestStrip).
static func place_hourglass_crest_strip(parent: Node, at: Vector2, shield: Vector2 = Vector2(36, 44), banner: Vector2 = Vector2(24, 34)) -> Control:
	if parent == null:
		return null
	var old := parent.get_node_or_null("HourglassCrestStrip")
	if old:
		old.name = "_HourglassCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "HourglassCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
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
	var old := parent.get_node_or_null("CastleViewCrestStrip")
	if old:
		old.name = "_CastleViewCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "CastleViewCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
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
	var old := parent.get_node_or_null("BloodCrestStrip")
	if old:
		old.name = "_BloodCrestStripDying"
		old.queue_free()
	var host := Control.new()
	host.name = "BloodCrestStrip"
	host.position = at
	host.size = Vector2(shield.x + 8.0 + banner.x, maxf(shield.y, banner.y))
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arms := make_company_arms(shield)
	arms.position = Vector2.ZERO
	host.add_child(arms)
	var bn := make_company_banner(banner)
	bn.name = "BloodBanner"
	bn.tooltip_text = Locale.t("lb_blood_arms")
	bn.set_meta("arms_kind", "lb_blood_arms")
	bn.position = Vector2(shield.x + 8.0, (shield.y - banner.y) * 0.5)
	host.add_child(bn)
	parent.add_child(host)
	return host


## Pin BloodQueueArms on a queue row (person awaiting assay).
static func attach_blood_queue_arms(row: Control, c, arms_sz: Vector2 = Vector2(26, 32)) -> void:
	if row == null or c == null:
		return
	var old := row.get_node_or_null("BloodQueueArms")
	if old:
		old.name = "_BloodQueueArmsDying"
		old.queue_free()
	var arms := make_person_arms(c, arms_sz)
	arms.name = "BloodQueueArms"
	arms.tooltip_text = Locale.t("lb_blood_arms")
	row.add_child(arms)
	row.move_child(arms, 0)

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

