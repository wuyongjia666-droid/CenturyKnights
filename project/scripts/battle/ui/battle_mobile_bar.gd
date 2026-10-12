class_name BattleMobileBar
extends RefCounted
## Phone command bar. ≤4 primary keys ≥48dp; confirm flow swaps the row.

static func build(host) -> void:
	if not DeviceProfile.is_mobile():
		return
	host._mobile_layer = CanvasLayer.new()
	host._mobile_layer.name = "MobileCommandBar"
	host._mobile_layer.layer = 30
	host.add_child(host._mobile_layer)
	host._mobile_bar = PanelContainer.new()
	var st := UIKit.flat_box(Color(UIKit.PANEL, 0.94), Color(UIKit.ACCENT, 0.55), 0, 1)
	st.border_width_left = 0
	st.border_width_right = 0
	st.border_width_bottom = 0
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	host._mobile_bar.add_theme_stylebox_override("panel", st)
	host._mobile_layer.add_child(host._mobile_bar)
	var row := HBoxContainer.new()
	row.name = "CmdRow"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	host._mobile_bar.add_child(row)
	rebuild(host)
	place(host)
	if not host.get_viewport().size_changed.is_connected(host._on_viewport_resized):
		host.get_viewport().size_changed.connect(host._on_viewport_resized)

static func rebuild(host) -> void:
	if host._mobile_bar == null:
		return
	var row := host._mobile_bar.get_node_or_null("CmdRow") as HBoxContainer
	if row == null:
		return
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var h := int(maxi(48, int(DeviceProfile.hit_px())))
	if host.preview_move_cell.x >= 0:
		command(row, Locale.t("ux_confirm_move"), h, true, host._confirm_preview_move)
		command(row, Locale.t("shell_4d0b4688"), h, false, host._clear_touch_preview)
	elif int(host.preview_attack_ui) >= 0:
		command(row, Locale.t("ux_confirm_attack"), h, true, host._confirm_preview_attack)
		command(row, Locale.t("shell_4d0b4688"), h, false, host._clear_touch_preview)
	else:
		command(row, Locale.t("shell_8669d292"), h, false, host._enter_attack_mode)
		command(row, Locale.t("shell_1a0db8dc"), h, false, host._wait_selected)
		command(row, Locale.t("shell_4d0b4688"), h, false, host._cancel_selection)
		command(row, Locale.t("ux_more_cmds"), h, true, host._mobile_overflow_menu)
	place(host)

static func command(row: HBoxContainer, text: String, h: int, accent: bool, cb: Callable) -> Button:
	var b := UIKit.make_accent_button(text, 120) if accent else UIKit.make_button(text, 96)
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	row.add_child(b)
	return b

static func place(host) -> void:
	if host._mobile_bar == null:
		return
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var insets := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if host.has_meta("mobile_insets"):
		insets = host.get_meta("mobile_insets")
	var h: float = float(host._command_bar_px())
	var left := float(insets.get("left", 0.0))
	var right := float(insets.get("right", 0.0))
	var bottom := maxf(float(insets.get("bottom", 0.0)), 8.0)
	# Dead zone: keep bar a few dp above the board so pans don't mis-tap.
	host._mobile_bar.position = Vector2(left, vp.y - bottom - h)
	host._mobile_bar.size = Vector2(maxf(240.0, vp.x - left - right), h)
