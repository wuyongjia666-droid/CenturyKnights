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
	var p: Control = host.call("_show_lock_tip_panel", str(steps[i].t), str(steps[i].b), i, 0.0)
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
