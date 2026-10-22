class_name BattleMobileBar
extends RefCounted
## Phone command bar. Matches desktop: Attack / Art / Wait / End-turn.
## Confirm flow swaps the row; end-turn always asks once more.
##
## Y1-A T-P0-3: while confirming, park the bar in the thumb zone (bottom of the
## right rail in landscape; bottom edge in portrait) and make Confirm the large
## accent control.

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
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	host._mobile_bar.add_theme_stylebox_override("panel", st)
	host._mobile_layer.add_child(host._mobile_bar)
	var row: BoxContainer = VBoxContainer.new() if host._mobile_landscape() else HBoxContainer.new()
	row.name = "CmdRow"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	host._mobile_bar.add_child(row)
	rebuild(host)
	place(host)
	if not host.get_viewport().size_changed.is_connected(host._on_viewport_resized):
		host.get_viewport().size_changed.connect(host._on_viewport_resized)


static func _confirming(host) -> bool:
	return host.preview_move_cell.x >= 0 or int(host.preview_attack_ui) >= 0


static func rebuild(host) -> void:
	if host._mobile_bar == null:
		return
	var row := host._mobile_bar.get_node_or_null("CmdRow") as BoxContainer
	if row == null:
		return
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var h := int(maxi(48, int(DeviceProfile.hit_px())))
	if host.preview_move_cell.x >= 0:
		command(row, Locale.t("ux_confirm_move"), h, true, func(): BattleTouchConfirm.confirm_move(host), true)
		command(row, Locale.t("shell_4d0b4688"), h, false, func(): BattleTouchConfirm.clear(host), false)
	elif int(host.preview_attack_ui) >= 0:
		command(row, Locale.t("ux_confirm_attack"), h, true, func(): BattleTouchConfirm.confirm_attack(host), true)
		command(row, Locale.t("shell_4d0b4688"), h, false, func(): BattleTouchConfirm.clear(host), false)
	else:
		# Match desktop order: Attack / Art / Wait / End turn.
		command(row, Locale.t("shell_8669d292"), h, false, host._enter_attack_mode, false)
		command(row, Locale.t("shell_41ec1a25"), h, false, host._cycle_skill, false)
		command(row, Locale.t("shell_1a0db8dc"), h, false, host._wait_selected, false)
		command(row, Locale.t("shell_4faa58f5"), h, true, func(): BattleTouchConfirm.request_end_turn(host), false)
	place(host)


static func command(row: BoxContainer, text: String, h: int, accent: bool, cb: Callable, thumb_primary: bool = false) -> Button:
	var b := UIKit.make_accent_button(text, 120) if accent else UIKit.make_button(text, 96)
	var min_h := maxi(h, 76) if row is VBoxContainer else h
	if thumb_primary:
		min_h = maxi(min_h, 88)
		b.add_theme_font_size_override("font_size", 24 if row is VBoxContainer else 18)
	else:
		b.add_theme_font_size_override("font_size", 22 if row is VBoxContainer else 15)
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if thumb_primary:
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if host._mobile_landscape():
		# Right-edge thumb column: board keeps the full height.
		# Confirm mode: slide the bar down into the lower thumb zone.
		var top := maxf(float(insets.get("top", 0.0)), 8.0)
		var sx: float = host.scale.x if host.scale.x > 0.01 else 1.0
		var w: float = (host.MOBILE_RAIL_W - 4.0) * sx
		var confirming := _confirming(host)
		var y0: float = (top + vp.y * 0.48) if confirming else (top + vp.y * 0.22)
		var bar_h: float = (vp.y - y0 - bottom) if confirming else (vp.y * 0.78 - top - bottom)
		host._mobile_bar.position = Vector2(vp.x - right - w - 4.0, y0)
		host._mobile_bar.size = Vector2(w, maxf(160.0, bar_h))
		return
	# Portrait: confirm uses a taller bottom strip so the accent key is thumb-sized.
	var bar_h2: float = h * 1.35 if _confirming(host) else h
	host._mobile_bar.position = Vector2(left, vp.y - bottom - bar_h2)
	host._mobile_bar.size = Vector2(maxf(240.0, vp.x - left - right), bar_h2)
