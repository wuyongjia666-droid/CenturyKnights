extends RefCounted
## Shared read-only 岁课年迹 panel for dossier / lineage / bloodline codex.
## Lines are ghost buttons: press opens unit dossier focused on that cid.

const CAP_PERSON := 6
const CAP_HOUSE := 8


static func mount_for(parent: Node, focus: CKCharacter, width: float = 360.0, cap: int = CAP_PERSON) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "YeartracePanel"
	panel.add_theme_constant_override("separation", 4)
	parent.add_child(panel)
	panel.add_child(UIKit.mono("SUI · YEARTRACE", 9, UIKit.ACCENT, false))
	if focus == null:
		panel.add_child(UIKit.body_label("—", UIKit.TEXT_FAINT, 12))
		return panel
	var rows: Array = CKSuiKe.yeartrace_for(focus.id)
	_fill_rows(panel, rows, width, maxi(1, cap), false)
	return panel


static func mount_house(parent: Node, width: float = 400.0, cap: int = CAP_HOUSE) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "YeartracePanel"
	panel.add_theme_constant_override("separation", 4)
	parent.add_child(panel)
	panel.add_child(UIKit.mono("SUI · YEARTRACE", 9, UIKit.ACCENT, false))
	var head := UIKit.body_label(Locale.t("sui_yeartrace_house"), UIKit.TEXT_DIM, 12)
	head.name = "YeartraceHouseHead"
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.clip_text = true
	panel.add_child(head)
	var rows: Array = CKSuiKe.yeartrace()
	_fill_rows(panel, rows, width, maxi(1, cap), true)
	return panel


static func _fill_rows(panel: Control, rows: Array, width: float, cap: int, with_who: bool) -> void:
	if rows.is_empty():
		var empty := UIKit.body_label(Locale.t("sui_yeartrace_empty"), UIKit.TEXT_FAINT, 12)
		empty.name = "YeartraceEmpty"
		panel.add_child(empty)
		return
	var shown := 0
	for i in range(rows.size() - 1, -1, -1):
		if shown >= cap:
			break
		var item: Dictionary = rows[i]
		var text := ""
		if with_who:
			text = Locale.t("sui_yeartrace_who_line", [
				str(item.get("who", item.get("cid", ""))),
				int(item.get("year", 0)),
				int(item.get("month", 0)),
				str(item.get("title", "")),
				str(item.get("outcome", "")),
			])
		else:
			text = Locale.t("sui_yeartrace_line", [
				int(item.get("year", 0)),
				int(item.get("month", 0)),
				str(item.get("title", "")),
				str(item.get("outcome", "")),
			])
		var cid := str(item.get("cid", ""))
		var btn := UIKit.ghost_button(text, int(width), maxi(28, MobileLayout.FONT_FLOOR + 6))
		btn.name = "Yeartrace_%d" % shown
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.tooltip_text = text
		btn.set_meta("yeartrace_cid", cid)
		var captured := cid
		btn.pressed.connect(func():
			_open_dossier(captured))
		panel.add_child(btn)
		shown += 1


static func _open_dossier(cid: String) -> void:
	if cid == "":
		return
	GameState.set_meta("dossier_id", cid)
	var back := "res://scenes/hub/lineage_view.tscn"
	if GameState.has_meta("yeartrace_back"):
		back = str(GameState.get_meta("yeartrace_back"))
	GameState.set_meta("dossier_back", back)
	CKNav.go("res://scenes/hub/unit_dossier.tscn")
