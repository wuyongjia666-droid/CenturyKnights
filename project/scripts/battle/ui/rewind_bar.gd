class_name RewindBar
extends RefCounted
## 回灯：灯芯用尽前，可以把已确认的行动拨回上一拍。
## 撤回只退回还没确认的那一步移动，不消耗灯芯。

static func attach(host: Node) -> void:
	if host.get_node_or_null("RewindBar") != null:
		refresh(host)
		return
	var panel := Panel.new()
	panel.name = "RewindBar"
	panel.position = Vector2(904, 432)
	panel.size = Vector2(352, 40)
	panel.custom_minimum_size = panel.size
	var style := UIKit.glass(10, 0.9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var eye := UIKit.eyebrow(BattleObjectives.text("rewind_lamp"), UIKit.ACCENT)
	eye.name = "Eye"
	row.add_child(eye)
	var undo := UIKit.make_button(BattleObjectives.text("rewind_undo"), 96)
	undo.name = "UndoMove"
	undo.add_theme_font_size_override("font_size", 13)
	undo.pressed.connect(func(): host._undo_move())
	row.add_child(undo)
	var lamp := UIKit.make_button("", 168)
	lamp.name = "Lamp"
	lamp.add_theme_font_size_override("font_size", 13)
	lamp.add_theme_color_override("font_color", UIKit.ACCENT)
	lamp.pressed.connect(func(): host._rewind_lamp())
	row.add_child(lamp)
	host.add_child(panel)
	refresh(host)


static func refresh(host) -> void:
	var panel: Node = host.get_node_or_null("RewindBar")
	if panel == null:
		return
	var undo := panel.get_node_or_null("Row/UndoMove") as Button
	var lamp := panel.get_node_or_null("Row/Lamp") as Button
	if undo == null or lamp == null:
		return
	undo.disabled = host._move_undo.is_empty() or bool(host.battle_over)
	var charges := int(host._lamp_charges)
	lamp.text = BattleObjectives.text("rewind_wicks") % charges
	lamp.disabled = charges <= 0 or bool(host.battle_over) or str(host.turn_team) != "player"
