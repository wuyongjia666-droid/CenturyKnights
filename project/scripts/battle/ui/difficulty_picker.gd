class_name DifficultyPicker
extends RefCounted
## New-game difficulty. After a mode is stored, only a lower rank can be chosen.

static func attach(parent: Node) -> Panel:
	if parent.get_node_or_null("DifficultyPicker") != null:
		return parent.get_node("DifficultyPicker") as Panel
	var panel := Panel.new()
	panel.name = "DifficultyPicker"
	panel.position = Vector2(24, 24)
	panel.size = Vector2(420, 280)
	panel.clip_contents = true
	var style := UIKit.glass(12, 0.92)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_top = 12
	col.offset_right = -16
	col.offset_bottom = -12
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var eye := UIKit.eyebrow(BattleObjectives.text("diff_pick"), UIKit.ACCENT)
	eye.name = "Eye"
	col.add_child(eye)
	var hint := Label.new()
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	col.add_child(hint)
	for mode in ["casual", "standard", "classic"]:
		var btn := UIKit.make_button(BattleObjectives.text("diff_" + mode), 360)
		btn.name = "Pick_" + mode
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_pick.bind(parent, mode))
		col.add_child(btn)
	parent.add_child(panel)
	refresh(parent)
	return panel


static func _on_pick(parent: Node, mode: String) -> void:
	CKEnemyLoadout.choose(GameState, mode)
	refresh(parent)


static func refresh(parent: Node) -> void:
	var panel := parent.get_node_or_null("DifficultyPicker")
	if panel == null:
		return
	var hint := panel.get_node_or_null("Col/Hint") as Label
	var mode := CKEnemyLoadout.mode_of(GameState)
	var locked := GameState.settings.has("battle_mode")
	if hint:
		var line := BattleObjectives.text("diff_now") % BattleObjectives.text("diff_" + mode)
		if locked:
			line += "\n" + BattleObjectives.text("diff_down_only")
		hint.text = line
	for id in ["casual", "standard", "classic"]:
		var btn := panel.get_node_or_null("Col/Pick_" + id) as Button
		if btn == null:
			continue
		var harder := locked and CKEnemyLoadout.rank_of(id) > CKEnemyLoadout.rank_of(mode)
		btn.disabled = harder
		btn.add_theme_color_override("font_color", UIKit.ACCENT if id == mode else UIKit.TEXT)
