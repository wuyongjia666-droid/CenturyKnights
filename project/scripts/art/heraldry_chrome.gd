class_name CKHeraldryChrome
extends RefCounted
## Shared player-facing heraldry chrome: 团徽 / 旗徽 / 族徽 + 爵位徽记.
## One design system everywhere (castle header, genealogy wall/tree, dossier crest).
## No marriage marshalling / per-person cadency — only company vs family arms + rank badge.

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

static func person_shield(c, w: int = 40, h: int = 48) -> Texture2D:
	return UnitArt.shield_arms(person_spec(c), w, h)

static func company_shield(w: int = 44, h: int = 52) -> Texture2D:
	return UnitArt.shield_arms(company_spec(), w, h)

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

static func place_company_header(parent: Node, at: Vector2, size: Vector2 = Vector2(44, 52)) -> TextureRect:
	var old := parent.get_node_or_null("CastleArms")
	if old:
		old.queue_free()
	var tr := make_company_arms(size)
	tr.position = at
	parent.add_child(tr)
	return tr
