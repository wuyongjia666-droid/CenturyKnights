class_name BattleMobileBar
extends RefCounted
## Phone command bar. Extracted from the battle controller in BTL-01.

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
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	host._mobile_bar.add_child(row)
	var h := int(DeviceProfile.hit_px())
	command(row, "攻击", h, false, host._enter_attack_mode)
	command(row, "战技", h, false, host._cycle_skill)
	command(row, "待命", h, false, host._wait_selected)
	command(row, "取消", h, false, host._cancel_selection)
	command(row, "结束回合", h, true, host._end_player_turn)
	place(host)
	if not host.get_viewport().size_changed.is_connected(host._on_viewport_resized):
		host.get_viewport().size_changed.connect(host._on_viewport_resized)
static func command(row: HBoxContainer, text: String, h: int, accent: bool, cb: Callable) -> Button:
	var b := UIKit.make_accent_button(text, 120) if accent else UIKit.make_button(text, 96)
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
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
	var bottom := float(insets.get("bottom", 0.0))
	host._mobile_bar.position = Vector2(left, vp.y - bottom - h)
	host._mobile_bar.size = Vector2(maxf(240.0, vp.x - left - right), h)
