class_name BattleLockTutorial
extends RefCounted
## Opening review E-02: lock teaching cards wait for battle-story, then advance on tap.
## Players can dismiss with ×; remembered for the rest of this battle.


static func _dismissed(host: Node) -> bool:
	return host != null and host.has_meta("lock_tut_dismissed")


static func dismiss(host: Node, panel: Control = null) -> void:
	if host != null:
		host.set_meta("lock_tut_dismissed", true)
	var target: Control = panel
	if target == null and host != null:
		target = host.get_node_or_null("LockTipPanel") as Control
	if target != null and is_instance_valid(target):
		target.name = "LockTipPanelDying"
		target.queue_free()


static func attach_dismiss(host: Node, panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if panel.find_child("LockTipDismiss", true, false) != null:
		return
	var close := UIKit.make_button("×", 36)
	close.name = "LockTipDismiss"
	close.custom_minimum_size = Vector2(36, 32)
	close.tooltip_text = Locale.t("shell_lock_dismiss")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): dismiss(host, panel))
	# Prefer the pip row (first child of content VBox); else top of panel tree.
	var hrow: Node = panel.get_child(0) if panel.get_child_count() > 0 else null
	var vb: Node = hrow.get_child(1) if hrow != null and hrow.get_child_count() > 1 else null
	var pips: Node = vb.get_child(0) if vb != null and vb.get_child_count() > 0 else null
	if pips is HBoxContainer:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.add_child(spacer)
		pips.add_child(close)
	else:
		panel.add_child(close)


static func queue_after_story(host: Node) -> void:
	if _dismissed(host):
		return
	if BattleStory.is_showing(host):
		host.get_tree().create_timer(0.2).timeout.connect(func(): queue_after_story(host))
		return
	run_sequence(host)


static func run_sequence(host: Node) -> void:
	if _dismissed(host):
		return
	var steps: Array = [
		{"t": Locale.t("shell_lock_1t"), "b": Locale.t("shell_lock_1b")},
		{"t": Locale.t("shell_lock_2t"), "b": Locale.t("shell_lock_2b") % [BattleRules.LEAVE_COST_LOCK, BattleRules.LEAVE_COST_ENGAGED]},
		{"t": Locale.t("shell_lock_3t"), "b": Locale.t("shell_lock_3b")},
	]
	host.set_meta("lock_tut_steps", steps)
	host.set_meta("lock_tut_i", 0)
	show_step(host)


static func show_step(host: Node) -> void:
	if _dismissed(host):
		var leftover = host.get_node_or_null("LockTipPanel")
		if leftover:
			leftover.name = "LockTipPanelDying"
			leftover.queue_free()
		return
	var old = host.get_node_or_null("LockTipPanel")
	if old:
		old.name = "LockTipPanelDying"
		old.queue_free()
	var steps: Array = host.get_meta("lock_tut_steps", [])
	var i := int(host.get_meta("lock_tut_i", 0))
	if i < 0 or i >= steps.size():
		return
	var last := i >= steps.size() - 1
	var p: Control = show_tip_panel(host, str(steps[i].t), str(steps[i].b), i, 0.0)
	attach_dismiss(host, p)
	var row := HBoxContainer.new()
	row.name = "LockTipActions"
	row.add_theme_constant_override("separation", 8)
	var box: Node = p.get_child(0).get_child(1) if p.get_child_count() > 0 and p.get_child(0).get_child_count() > 1 else p
	box.add_child(row)
	var label := Locale.t("shell_lock_start") if last else Locale.t("shell_lock_next")
	var btn = UIKit.make_accent_button(label, 140)
	btn.name = "LockTipNext"
	btn.pressed.connect(func():
		if last:
			dismiss(host, p)
			return
		host.set_meta("lock_tut_i", i + 1)
		# Defer rebuild so we do not free the pressed button mid-signal.
		show_step.call_deferred(host)
	)
	row.add_child(btn)


const RAIL_X := 904.0
const RAIL_W := 352.0


static func is_tutorial_map(host) -> bool:
	if host == null:
		return false
	var mid := str(host.get("map_id"))
	var md = BattleMaps.get_map(mid)
	if bool(md.get("tutorial_militia", false)) or bool(md.get("tutorial", false)) or mid.begins_with("ch0"):
		return true
	return bool(md.get("lock_drill", false))


static func practice_pending(host) -> bool:
	return is_tutorial_map(host) and host != null and not host.has_meta("lock_beat_fired")


static func _host_tex(host, path: String) -> Texture2D:
	if host != null and host.has_method("_tex"):
		return host.call("_tex", path)
	return load(path) if ResourceLoader.exists(path) else null


static func show_tip_once(host) -> void:
	if host == null or host.has_meta("lock_tip_shown"):
		return
	host.set_meta("lock_tip_shown", true)
	# E-02: tutorial maps wait for first_lock (and story bar) before teaching cards.
	if is_tutorial_map(host):
		return
	attach_dismiss(host, show_tip_panel(
		host,
		"交战锁定",
		"跟人缠上以后，想走要多花 %d 步；被缠住的人反击更准。想脱身，用战技『抽身一步』。" % BattleRules.LEAVE_COST_LOCK,
		0,
		8.0
	))


static func show_tip_panel(host, title: String, body: String, step: int, auto_sec: float) -> Control:
	var panel = UIKit.make_panel()
	panel.position = Vector2(RAIL_X, 462)  # v8.6: rail slot over the log — never on the board
	panel.custom_minimum_size = Vector2(RAIL_W, 96)
	panel.add_theme_stylebox_override("panel", UIKit.glass(12, 0.94, true))
	panel.z_index = 20
	panel.name = "LockTipPanel"
	host.add_child(panel)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	panel.add_child(hrow)
	var glyph := TextureRect.new()
	glyph.texture = _host_tex(host, "res://assets/art/fx/lock_dense_3.png")
	glyph.custom_minimum_size = Vector2(44, 44)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(glyph)
	UIFX.breathe(glyph, 0.04, 1.6)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	hrow.add_child(vb)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	for pi in range(3):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22 if pi == step else 10, 4)
		pip.color = UIKit.DANGER if pi == step else Color(UIKit.TEXT_DIM, 0.5)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	vb.add_child(pips)
	var t = UIKit.make_label(title, true)
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", UIKit.DANGER)
	vb.add_child(t)
	var d = UIKit.make_dim_label(body)
	d.add_theme_font_size_override("font_size", 12)
	d.custom_minimum_size = Vector2(RAIL_W - 110, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	if auto_sec > 0.0:
		host.get_tree().create_timer(auto_sec).timeout.connect(func():
			if is_instance_valid(panel):
				panel.queue_free()
		)
	return panel


static func show_practice_banner(host) -> void:
	if host == null or host.has_meta("lock_practice_banner"):
		return
	host.set_meta("lock_practice_banner", true)
	## v8.6: slim coral pill in the turn bar — the board stays clear
	var panel = UIKit.make_glass(18, 0.82)
	var pst: StyleBoxFlat = UIKit.glass(18, 0.82)
	pst.border_color = Color(UIKit.DANGER, 0.55)
	pst.content_margin_top = 4
	pst.content_margin_bottom = 4
	pst.content_margin_left = 14
	pst.content_margin_right = 14
	pst.shadow_size = 0
	panel.add_theme_stylebox_override("panel", pst)
	panel.position = Vector2(RAIL_X, 48 if DeviceProfile.is_mobile() else 2)
	panel.custom_minimum_size = Vector2(RAIL_W, 0)
	panel.z_index = 18
	var ct: Node = host.find_child("ControlsTip", true, false)
	if ct:
		ct.visible = false
	panel.name = "LockPracticeBanner"
	host.add_child(panel)
	var oh := host.get_node_or_null("ObjectiveHud") as CanvasItem
	if oh and not DeviceProfile.is_mobile():
		oh.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)
	var mid := str(host.get("map_id"))
	var title = Locale.t("shell_lock_drill")
	var tip = Locale.t("shell_lock_drill_tip")
	if bool(BattleMaps.get_map(mid).get("lock_drill", false)) and not mid.begins_with("ch0"):
		if mid.begins_with("ch6"):
			title = Locale.t("shell_lock_final")
			tip = Locale.t("shell_lock_final_tip")
		elif mid.begins_with("ch5") or mid.begins_with("ch4"):
			title = Locale.t("shell_lock_late")
			tip = Locale.t("shell_lock_late_tip")
		else:
			title = Locale.t("shell_lock_mid")
			tip = Locale.t("shell_lock_mid_tip")
	var t = UIKit.make_label(title)
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", UIKit.DANGER)
	vb.add_child(t)
	var tl = UIKit.make_dim_label(tip)
	tl.add_theme_font_size_override("font_size", UIKit.desk_sz(10))
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(RAIL_W - 28, 0)
	vb.add_child(tl)
	panel.tooltip_text = tip


static func clear_practice_banner(host) -> void:
	if host == null:
		return
	var p = host.get_node_or_null("LockPracticeBanner")
	if p:
		p.queue_free()
	var oh := host.get_node_or_null("ObjectiveHud") as CanvasItem
	if oh and not DeviceProfile.is_mobile():
		oh.visible = true
	var ct: Node = host.find_child("ControlsTip", true, false)
	if ct:
		ct.visible = true
