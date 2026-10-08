class_name ForecastPanel
extends RefCounted
## Two columns, attacker and counter. Every number is BattleRules.preview.

static func sides(attacker: CKCharacter, defender: CKCharacter, terrain_id: String, extras: Dictionary, atk_pos: Vector2i, def_pos: Vector2i, counter_terrain: String = "") -> Dictionary:
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
	if host.attack_mode and atk_i >= 0 and atk_i < host.units.size():
		def_i = host._unit_at(host._hover_cell)
		if def_i >= 0 and str(host.units[def_i].team) == "enemy" and host.units[def_i].char.hp > 0:
			show = true
	panel.visible = show
	if not show:
		return
	_place(host, panel)
	var atk = host.units[atk_i]
	var def = host.units[def_i]
	var tid := str(host.terrain[def.pos.y][def.pos.x])
	var atk_tid := str(host.terrain[atk.pos.y][atk.pos.x])
	var info := sides(atk.char, def.char, tid, host._combat_extras(atk_i, def_i), atk.pos, def.pos, atk_tid)
	_fill(panel.get_node("Cols/Ours"), BattleObjectives.text("forecast_ours"), info, false)
	_fill(panel.get_node("Cols/Theirs"), BattleObjectives.text("forecast_theirs"), info, true)


static func _fill(box: Node, title: String, info: Dictionary, counter_side: bool) -> void:
	var title_l := box.get_node("Title") as Label
	var body := box.get_node("Body") as Label
	title_l.text = title
	title_l.add_theme_color_override("font_color", UIKit.DANGER if counter_side else UIKit.OK)
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


static func _place(host, panel: Control) -> void:
	panel.size = Vector2(340, 132)
	panel.position = Vector2(24, 560)
	if DeviceProfile.is_mobile():
		var top := 8.0
		if host.has_meta("mobile_insets"):
			top = float(host.get_meta("mobile_insets").get("top", 0.0)) + 8.0
		if host.position.y + 0.5 < top:
			panel.position = Vector2(16, top + 48)
		else:
			panel.position = Vector2(24, 96)
