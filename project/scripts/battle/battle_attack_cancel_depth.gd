class_name BattleAttackCancelDepth
extends RefCounted
## Y1-A T-P28: layered cancel — preview → attack/skill mode → selection.
## Esc / board cancel / (optional) bar walk the same stack; never jumps.

const META := "m_cancel_depth"


static func step(host) -> String:
	if host == null:
		return "noop"
	if str(host.get("turn_team")) != "player" or bool(host.get("battle_over")):
		return "noop"
	# 1) Drop latched move/attack preview, keep mode + selection.
	var has_preview := false
	if host.preview_move_cell.x >= 0:
		has_preview = true
	if int(host.get("preview_attack_ui")) >= 0:
		has_preview = true
	if BattleSkillHealPreview.latched(host):
		has_preview = true
	if BattleSkillBuffPreview.latched(host):
		has_preview = true
	if has_preview:
		# Prefer T-P16 back_out: stop follow tween, keep camera (no yank to unit).
		if not BattleConfirmAffordance.back_out(host):
			BattleTouchConfirm.clear(host, true)
		host.set_meta(META, {"kind": "preview", "msec": Time.get_ticks_msec()})
		return "preview"
	# 2) Leave attack/skill mode, keep the piece selected with move range.
	if bool(host.get("attack_mode")) or bool(host.get("skill_mode")):
		_exit_modes(host)
		host.set_meta(META, {"kind": "mode", "msec": Time.get_ticks_msec()})
		return "mode"
	# 3) Full deselect.
	if int(host.get("selected")) >= 0:
		if host.has_method("_cancel_selection"):
			host._cancel_selection()
		host.set_meta(META, {"kind": "select", "msec": Time.get_ticks_msec()})
		return "select"
	return "noop"


static func _exit_modes(host) -> void:
	host.attack_mode = false
	host.skill_mode = false
	host.active_skill_id = ""
	BattleSkillHealPreview.clear(host)
	BattleSkillBuffPreview.clear(host)
	var ui := int(host.selected)
	if ui >= 0 and ui < host.units.size() and str(host.units[ui].team) == "player" and not bool(host.units[ui].done):
		if host.has_method("_compute_move_cells"):
			host.move_cells = host._compute_move_cells(ui)
		if host.has_method("_refresh_info"):
			host._refresh_info()
		if host.has_method("_update_skill_hint"):
			host._update_skill_hint()
		BattleRangePreview.publish(host)
		# Shared inset keep — do not yank camera off the notch-safe frame.
		if BattleRangePreview.keep_selected(host) == Vector2.ZERO:
			BattlePick.focus_selected(host)
	else:
		host.move_cells.clear()
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)
	if host.overlay:
		host.overlay.queue_redraw()
	if host.get("map_draw") != null:
		host.map_draw.queue_redraw()
