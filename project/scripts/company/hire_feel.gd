class_name CKHireFeel
extends RefCounted
## Fat knife #8: 酒馆编制上阵情感闭环 —
## hire success stamps last_hire; tavern shows face/name + ToRoster/ToDeploy;
## roster/deploy read it back. Cleared on dismiss or when the hire fights.
## Mercenaries stay marriage-suitor via in_roster (no regress).

const KEY := "last_hire"


static func stamp(c: CKCharacter) -> void:
	if c == null:
		return
	GameState.house_mods[KEY] = {
		"id": str(c.id),
		"name": str(c.name),
		"at": Calendar.label(),
	}
	GameState.mark_dirty()


static func clear() -> void:
	if GameState.house_mods.has(KEY):
		GameState.house_mods.erase(KEY)
		GameState.mark_dirty()


static func pending() -> bool:
	var raw: Variant = GameState.house_mods.get(KEY, {})
	return typeof(raw) == TYPE_DICTIONARY and not (raw as Dictionary).is_empty()


static func snapshot() -> Dictionary:
	var raw: Variant = GameState.house_mods.get(KEY, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


static func character() -> CKCharacter:
	if not pending():
		return null
	var cid := str(snapshot().get("id", ""))
	if cid == "":
		return null
	var c = GameState.characters.get(cid)
	if c == null or not bool(c.in_roster) or not bool(c.alive):
		return null
	return c


static func is_new(cid: String) -> bool:
	if not pending():
		return false
	return str(snapshot().get("id", "")) == str(cid)


## Tavern post-hire payoff: portrait + name + roster/deploy CTAs (not empty-host how).
static func attach_panel(parent: Node, width: float = 400.0) -> Control:
	if parent == null:
		return null
	var old := parent.find_child("HireFeelPanel", true, false)
	if old != null:
		old.queue_free()
	var c := character()
	if c == null:
		return null
	var panel := PanelContainer.new()
	panel.name = "HireFeelPanel"
	panel.custom_minimum_size = Vector2(width, 0)
	var sb := UIKit.flat_box(Color(0.06, 0.08, 0.12, 0.96), Color(UIKit.ACCENT, 0.75), 10, 2)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 12)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.name = "HireFeelBody"
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	body.add_child(UIKit.mono(Locale.t("lb_hire_feel_head"), 11, UIKit.ACCENT, false))
	var row := HBoxContainer.new()
	row.name = "HireFeelFaceRow"
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var plate := Control.new()
	plate.name = "HireFeelPortrait"
	plate.custom_minimum_size = Vector2(96, 120)
	row.add_child(plate)
	UIKit.portrait_plate(plate, Rect2(0, 0, 96, 120), c, "")
	CKHeraldryField.attach_hire_plate_arms(plate, c, Rect2(0, 0, 96, 120), Vector2(28, 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var nm := UIKit.title_label(c.name, 20)
	nm.name = "HireFeelName"
	nm.add_theme_color_override("font_color", UIKit.OK)
	col.add_child(nm)
	col.add_child(CKPageKit.text(Locale.t("lb_hire_feel_name", [c.name]), UIKit.TEXT, 13, maxf(160.0, width - 140.0)))
	var job: Dictionary = GameState.get_job(c.job_id)
	col.add_child(UIKit.mono(str(job.get("name", "")), 11, UIKit.TEXT_DIM, false))
	var acts := HBoxContainer.new()
	acts.name = "HireFeelActions"
	acts.add_theme_constant_override("separation", 10)
	body.add_child(acts)
	var bw := mini(180.0, maxf(120.0, (width - 36.0) / 3.0))
	var to_r := CKPageKit.button(Locale.t("lb_hire_feel_to_roster"), true, bw)
	to_r.name = "ToRoster"
	to_r.pressed.connect(func(): CKNav.go("res://scenes/hub/roster.tscn"))
	acts.add_child(to_r)
	UIFX.wire_button(to_r)
	var to_d := CKPageKit.button(Locale.t("lb_hire_feel_to_deploy"), false, bw)
	to_d.name = "ToDeploy"
	to_d.pressed.connect(func(): CKNav.go("res://scenes/hub/deploy.tscn"))
	acts.add_child(to_d)
	UIFX.wire_button(to_d)
	var dismiss := CKPageKit.button(Locale.t("lb_hire_feel_dismiss"), false, bw)
	dismiss.name = "DismissHireFeel"
	dismiss.pressed.connect(func():
		clear()
		if is_instance_valid(panel):
			panel.queue_free()
	)
	acts.add_child(dismiss)
	UIFX.wire_button(dismiss)
	return panel


static func new_chip() -> Control:
	var chip := UIKit.tag_chip(Locale.t("lb_hire_new_chip"), UIKit.OK)
	chip.name = "NewHireChip"
	return chip
