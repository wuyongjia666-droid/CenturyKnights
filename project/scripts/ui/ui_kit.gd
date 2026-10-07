class_name UIKit
extends RefCounted

const BG := Color(0.12, 0.14, 0.18)
const PANEL := Color(0.18, 0.21, 0.28)
const ACCENT := Color(0.79, 0.64, 0.15)
const TEXT := Color(0.92, 0.90, 0.85)
const DANGER := Color(0.75, 0.28, 0.28)
const OK := Color(0.35, 0.65, 0.45)

static func make_button(text: String, min_w: int = 160) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 40)
	return b

static func make_label(text: String, large: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", TEXT)
	if large:
		l.add_theme_font_size_override("font_size", 28)
	return l

static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p

static func resource_bar() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	return h

static func update_resources(bar: HBoxContainer) -> void:
	for c in bar.get_children():
		c.queue_free()
	var items = [
		["银币", GameState.silver],
		["粮", GameState.food],
		["铁", GameState.iron],
		["药", GameState.herb],
		["士气", GameState.morale],
		[Calendar.label(), ""],
	]
	for it in items:
		var l := Label.new()
		if str(it[1]) == "":
			l.text = str(it[0])
		else:
			l.text = "%s %s" % [it[0], str(it[1])]
		l.add_theme_color_override("font_color", ACCENT if it[0] == "银币" else TEXT)
		bar.add_child(l)

static func char_card_text(c: CKCharacter) -> String:
	var job = GameState.get_job(c.job_id)
	var lines = [
		"%s　%s　%d岁　%s" % [c.name, job.get("name", ""), c.age, c.rank_name()],
		"六维 力%d 体%d 技%d 敏%d 感%d 意%d" % [c.stats["str"], c.stats["vit"], c.stats["skl"], c.stats["agi"], c.stats["per"], c.stats["wil"]],
		"血胤 %s" % c.bloodline_display(),
	]
	var tnames: Array = []
	for tid in c.traits:
		tnames.append(GameState.get_trait(tid).get("name", tid))
	lines.append("禀性 " + ("、".join(tnames) if tnames.size() else "无"))
	if c.injured:
		lines.append("【临时伤】")
	return "\n".join(lines)
