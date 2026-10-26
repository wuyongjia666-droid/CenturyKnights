class_name ForecastPanel
extends RefCounted
## Two columns, attacker and counter. Every number is BattleRules.preview.
## Y1-A T-P2-1: on phone, floor type and grow the box so floored labels are not
## clipped/squashed inside the old fixed 340×132 desktop chrome.

const DESK_SIZE := Vector2(340, 132)
const MOBILE_COL_MIN_W := 168.0
const MOBILE_PANEL_MIN := Vector2(400, 196)
const MOBILE_PAD := Vector2(28, 24)  ## stylebox margins + breathing room

static func sides(
	attacker: CKCharacter,
	defender: CKCharacter,
	terrain_id: String,
	extras: Dictionary,
	atk_pos: Vector2i,
	def_pos: Vector2i,
	counter_terrain: String = "",
) -> Dictionary:
	var ours: Dictionary = BattleRules.preview(attacker, defender, terrain_id, extras)
	var counter := BattleRules.can_counter(attacker, defender, atk_pos, def_pos)
	var back_tid: String = counter_terrain if counter_terrain != "" else terrain_id
	var theirs := {}
	if counter and defender.hp > 0:
		var back_ex := {
			"counter": true,
			"night": bool(extras.get("night", false)),
			"opening": bool(extras.get("foe_opening", false)),
		}
		theirs = BattleRules.preview(defender, attacker, back_tid, back_ex)
	return {
		"hit": int(ours.hit),
		"dmg_lo": int(ours.dmg.x),
		"dmg_hi": int(ours.dmg.y),
		"crit": int(ours.crit),
		"follow": bool(ours.follow_up),
		"counter": counter,
		"counter_hit": int(theirs.hit) if counter else 0,
		"counter_lo": int(theirs.dmg.x) if counter else 0,
		"counter_hi": int(theirs.dmg.y) if counter else 0,
		"counter_crit": int(theirs.crit) if counter else 0,
		"tags": ours.tags,
		"link_names": extras.get("link_names", []),
	}


static func attach(host: Node) -> void:
	if host.get_node_or_null("ForecastPanel") != null:
		return
	var panel := Panel.new()
	panel.name = "ForecastPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	var style := UIKit.glass(12, 0.9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "Cols"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	row.add_child(_column("Ours"))
	row.add_child(_column("Theirs"))
	host.add_child(panel)
	if DeviceProfile.is_mobile():
		_style_mobile(panel)


static func _column(name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = name
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(150, 0)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_override("font", UIKit.font("bold"))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UIKit.TEXT)
	box.add_child(title)
	var body := Label.new()
	body.name = "Body"
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	box.add_child(body)
	return box


static func refresh(host) -> void:
	var panel := host.get_node_or_null("ForecastPanel") as Control
	if panel == null:
		return
	var show := false
	var atk_i := int(host.selected)
	var def_i := -1
	if int(host.get("preview_attack_ui")) >= 0:
		def_i = int(host.preview_attack_ui)
		if atk_i >= 0 and def_i < host.units.size() and str(host.units[def_i].team) == "enemy":
			show = true
	elif host.attack_mode and atk_i >= 0 and atk_i < host.units.size():
		def_i = host._unit_at(host._hover_cell)
		if def_i >= 0 and str(host.units[def_i].team) == "enemy" and host.units[def_i].char.hp > 0:
			show = true
	panel.visible = show
	if not show:
		CKHeraldryField.pin_forecast_arms(panel, null, "player", "")
		return
	# T-P13: frame the pair before placing, unless a unit drag owns the camera.
	if host.has_meta("ck_unit_drag"):
		if host.has_meta("m_combat_frame"):
			host.remove_meta("m_combat_frame")
	else:
		BattleCombatFrame.follow_attack(host)
	_place(host, panel)
	var atk = host.units[atk_i]
	var def = host.units[def_i]
	var tid := str(host.terrain[def.pos.y][def.pos.x])
	var atk_tid := str(host.terrain[atk.pos.y][atk.pos.x])
	var info := sides(atk.char, def.char, tid, host._combat_extras(atk_i, def_i), atk.pos, def.pos, atk_tid)
	_fill(panel.get_node("Cols/Ours"), BattleObjectives.text("forecast_ours"), info, false)
	_fill(panel.get_node("Cols/Theirs"), BattleObjectives.text("forecast_theirs"), info, true)
	# Refit after text lands so floored fonts are not clipped.
	if DeviceProfile.is_mobile():
		_place(host, panel)
	CKHeraldryField.pin_forecast_arms(panel, atk.char, str(atk.get("team", "player")), CKHeraldryChrome.battle_foe_nation_for(host))


static func _fill(box: Node, title: String, info: Dictionary, counter_side: bool) -> void:
	var title_l := box.get_node("Title") as Label
	var body := box.get_node("Body") as Label
	title_l.text = title
	title_l.add_theme_color_override("font_color", UIKit.faction_color("enemy" if counter_side else "player"))
	if counter_side and not bool(info.counter):
		body.text = BattleObjectives.text("forecast_no_counter")
		return
	var hit := int(info.counter_hit) if counter_side else int(info.hit)
	var lo := int(info.counter_lo) if counter_side else int(info.dmg_lo)
	var hi := int(info.counter_hi) if counter_side else int(info.dmg_hi)
	var crit := int(info.counter_crit) if counter_side else int(info.crit)
	var follow := BattleObjectives.text("forecast_yes") if (not counter_side and bool(info.follow)) else BattleObjectives.text("forecast_no")
	var back := BattleObjectives.text("forecast_yes") if bool(info.counter) else BattleObjectives.text("forecast_no")
	body.text = "%s %d%%\n%s %d–%d\n%s %d%%\n%s %s\n%s %s" % [
		BattleObjectives.text("forecast_hit"), hit,
		BattleObjectives.text("forecast_dmg"), lo, hi,
		BattleObjectives.text("forecast_crit"), crit,
		BattleObjectives.text("forecast_follow"), follow,
		BattleObjectives.text("forecast_counter"), back,
	]
	var links: Array = info.get("link_names", [])
	if not counter_side and not links.is_empty():
		body.text += "\n" + (BattleObjectives.text("link_with") % str(links[0]))


static func _style_mobile(panel: Control) -> void:
	## Match MobileLayout.FONT_FLOOR / MobileSide.FONT; keep key lines unclipped.
	panel.clip_contents = false
	var floor_px: int = MobileLayout.FONT_FLOOR
	var style: StyleBox = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var s := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", s)
	var cols := panel.get_node_or_null("Cols") as HBoxContainer
	if cols:
		cols.add_theme_constant_override("separation", 20)
	for nm in ["Ours", "Theirs"]:
		var box := panel.get_node_or_null("Cols/%s" % nm) as VBoxContainer
		if box == null:
			continue
		box.custom_minimum_size = Vector2(MOBILE_COL_MIN_W, 0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := box.get_node_or_null("Title") as Label
		var body := box.get_node_or_null("Body") as Label
		if title:
			title.add_theme_font_size_override("font_size", floor_px)
			title.clip_text = false
			title.autowrap_mode = TextServer.AUTOWRAP_OFF
			title.custom_minimum_size = Vector2(MOBILE_COL_MIN_W, float(floor_px) + 6.0)
		if body:
			body.add_theme_font_size_override("font_size", floor_px)
			body.clip_text = false
			body.autowrap_mode = TextServer.AUTOWRAP_OFF
			# 5 forecast lines (+ optional link); keep a floor so VBox cannot squash glyphs.
			body.custom_minimum_size = Vector2(MOBILE_COL_MIN_W, float(floor_px) * 5.5 + 8.0)


static func _mobile_panel_size(panel: Control) -> Vector2:
	var cols := panel.get_node_or_null("Cols") as Control
	var want := MOBILE_PANEL_MIN
	if cols != null:
		var combined: Vector2 = cols.get_combined_minimum_size()
		want = Vector2(
			maxf(MOBILE_PANEL_MIN.x, combined.x + MOBILE_PAD.x),
			maxf(MOBILE_PANEL_MIN.y, combined.y + MOBILE_PAD.y),
		)
	return want


static func _stage_of(host) -> Rect2:
	if host.has_meta("m_board_area"):
		return host.get_meta("m_board_area")
	var stage = host.get("BOARD_AREA")
	if stage is Rect2:
		return stage
	return Rect2()


static func _place(host, panel: Control) -> void:
	var stage := _stage_of(host)
	var pair := BattleCombatFrame.pair_mid_shown(host)
	if DeviceProfile.is_mobile():
		_style_mobile(panel)
		var sz := _mobile_panel_size(panel)
		panel.custom_minimum_size = sz
		panel.size = sz
		if stage.size.x < 32.0:
			panel.position = Vector2(12, 56)
			return
		# Opposite the pair so the forecast band does not cover the fight.
		panel.position = BattleCombatFrame.forecast_slot(stage, sz, pair)
		return
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = DESK_SIZE
	if stage.size.x < 32.0:
		panel.position = Vector2(24, 560)
		return
	panel.position = BattleCombatFrame.forecast_slot(stage, DESK_SIZE, pair)
