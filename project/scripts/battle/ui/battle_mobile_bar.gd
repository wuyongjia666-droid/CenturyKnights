class_name BattleMobileBar
extends RefCounted
## Phone command bar. Matches desktop: Attack / Art / Wait / End-turn.
## Confirm flow swaps the row; end-turn always asks once more.
##
## Y1-A T-P0-3: while confirming, park the bar in the thumb zone (bottom of the
## right rail in landscape; bottom edge in portrait) and make Confirm the large
## accent control.
## Y1-A T-P2/T-P3: landscape confirm sinks to lower thumb (0.58) with taller primary.
## Y1-A T-P3: landscape Confirm sinks to the bottom thumb (Cancel above + dest
## hint); primary hit ≥108px; clearer move/attack confirm flow beyond rail width.

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


## T-P3 pure policy: landscape confirm stacks Cancel → hint → Confirm (thumb bottom).
static func landscape_confirm_stack() -> PackedStringArray:
	return PackedStringArray(["cancel", "hint", "confirm"])


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
	var land: bool = bool(host._mobile_landscape()) and (row is VBoxContainer)
	if host.preview_move_cell.x >= 0:
		_rebuild_confirm(host, row, h, land, true)
	elif int(host.preview_attack_ui) >= 0:
		_rebuild_confirm(host, row, h, land, false)
	else:
		# Match desktop order + Y1-A T-P12 Next: Next / Attack / Art / Wait / End turn.
		command(row, Locale.t("formation_next"), h, false, func(): BattleFormationCycle.apply_next(host), false)
		command(row, Locale.t("shell_8669d292"), h, false, host._enter_attack_mode, false)
		command(row, Locale.t("shell_41ec1a25"), h, false, host._cycle_skill, false)
		command(row, Locale.t("shell_1a0db8dc"), h, false, host._wait_selected, false)
		command(row, Locale.t("shell_4faa58f5"), h, true, func(): BattleTouchConfirm.request_end_turn(host), false)
	place(host)


static func _rebuild_confirm(host, row: BoxContainer, h: int, land: bool, is_move: bool) -> void:
	var confirm_cb: Callable
	if is_move:
		confirm_cb = func(): BattleTouchConfirm.confirm_move(host)
	else:
		confirm_cb = func(): BattleTouchConfirm.confirm_attack(host)
	var cancel_cb := func(): BattleAttackCancelDepth.step(host)
	var confirm_txt := Locale.t("ux_confirm_move") if is_move else Locale.t("ux_confirm_attack")
	var hint := _dest_hint(host, is_move)
	if land:
		# Thumb bottom: Cancel (top) → dest hint → Confirm (bottom, large).
		var cancel_btn := command(row, Locale.t("shell_4d0b4688"), h, false, cancel_cb, false)
		cancel_btn.name = "ConfirmCancel"
		cancel_btn.custom_minimum_size = Vector2(0, maxi(h, 56))
		_add_dest_hint(row, hint)
		var conf := command(row, confirm_txt, h, true, confirm_cb, true)
		conf.name = "ConfirmPrimary"
		conf.custom_minimum_size = Vector2(0, maxi(108, int(conf.custom_minimum_size.y)))
	else:
		# Portrait: Confirm primary left, Cancel right (existing flow).
		var conf2 := command(row, confirm_txt, h, true, confirm_cb, true)
		conf2.name = "ConfirmPrimary"
		_add_dest_hint(row, hint)
		var cancel2 := command(row, Locale.t("shell_4d0b4688"), h, false, cancel_cb, false)
		cancel2.name = "ConfirmCancel"


static func _dest_hint(host, is_move: bool) -> String:
	if is_move:
		var c: Vector2i = host.preview_move_cell
		return Locale.t("ux_confirm_dest_move") % [c.x, c.y]
	var ui: int = int(host.preview_attack_ui)
	var name := "?"
	if ui >= 0 and ui < host.units.size():
		name = str(host.units[ui].char.name)
	return Locale.t("ux_confirm_dest_attack") % name


static func _add_dest_hint(row: BoxContainer, text: String) -> void:
	var tip := Label.new()
	tip.name = "ConfirmHint"
	tip.text = text
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 16 if row is VBoxContainer else 14)
	tip.add_theme_color_override("font_color", Color(UIKit.TEXT, 0.92))
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tip)


static func command(row: BoxContainer, text: String, h: int, accent: bool, cb: Callable, thumb_primary: bool = false) -> Button:
	var b := UIKit.make_accent_button(text, 120) if accent else UIKit.make_button(text, 96)
	var min_h := maxi(h, 76) if row is VBoxContainer else h
	if thumb_primary:
		min_h = maxi(min_h, 96)
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
		# T-P3 confirm: sink deeper into the lower thumb zone (0.58).
		var top := maxf(float(insets.get("top", 0.0)), 8.0)
		var sx: float = host.scale.x if host.scale.x > 0.01 else 1.0
		var w: float = (host.MOBILE_RAIL_W - 4.0) * sx
		var confirming := _confirming(host)
		var y0: float = (top + vp.y * 0.58) if confirming else (top + vp.y * 0.22)
		var bar_h: float = (vp.y - y0 - bottom) if confirming else (vp.y * 0.78 - top - bottom)
		host._mobile_bar.position = Vector2(vp.x - right - w - 4.0, y0)
		host._mobile_bar.size = Vector2(w, maxf(180.0, bar_h))
		BattleConfirmAffordance.grow_bar_hits(host)
		return
	# Portrait: confirm uses a taller bottom strip so the accent key is thumb-sized.
	var bar_h2: float = h * 1.45 if _confirming(host) else h
	host._mobile_bar.position = Vector2(left, vp.y - bottom - bar_h2)
	host._mobile_bar.size = Vector2(maxf(240.0, vp.x - left - right), bar_h2)
	BattleConfirmAffordance.grow_bar_hits(host)
