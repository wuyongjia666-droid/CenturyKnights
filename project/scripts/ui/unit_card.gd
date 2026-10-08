extends Control
## v8.6 battle unit card — Frost design system (Stitch "06 战棋战斗 HUD" selected-unit card):
## rounded portrait w/ 1px stroke · team eyebrow · headline name · slim token HP bar (mint ally /
## coral enemy, mono numerals, tween) · rounded skill chips (hover/press/disabled/tooltip) · mono stats.
## v8.5 ice-crystal shell / hp kit plates retired from chrome.

var portrait: TextureRect
var _w: float = 312.0
var _name: Label
var _sub: Label
var _hp: ProgressBar
var _hp_fill: StyleBoxFlat
var _hp_txt: Label
var _stats: Label
var _chips: HBoxContainer
var _last_uid: String = ""
const PW := 84.0
const PH := 108.0

func _init(width: float = 312.0) -> void:
	_w = width
	custom_minimum_size = Vector2(_w, PH)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()

func _build() -> void:
	var mask := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = UIKit.BG_GLOW
	ms.set_corner_radius_all(10)
	mask.add_theme_stylebox_override("panel", ms)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.size = Vector2(PW, PH)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size = Vector2(PW, PH)
	portrait.pivot_offset = Vector2(PW, PH) * 0.5
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(portrait)
	var ring := Panel.new()
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = UIKit.STROKE_HI
	rs.set_border_width_all(1)
	rs.set_corner_radius_all(10)
	rs.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", rs)
	ring.size = Vector2(PW, PH)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)

	var x0 := PW + 16.0
	var cw := _w - x0
	_sub = Label.new()
	_sub.position = Vector2(x0, 0)
	_sub.add_theme_font_size_override("font_size", UIKit.SZ_LABEL)
	_sub.add_theme_font_override("font", UIKit.font("bold"))
	add_child(_sub)
	_name = Label.new()
	_name.position = Vector2(x0, 15)
	_name.add_theme_font_size_override("font_size", 21)
	_name.add_theme_color_override("font_color", UIKit.TEXT)
	add_child(_name)

	_hp = ProgressBar.new()
	_hp.show_percentage = false
	_hp.position = Vector2(x0, 52)
	_hp.size = Vector2(cw - 74, 6)
	_hp.custom_minimum_size = Vector2(cw - 74, 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = UIKit.OK
	_hp_fill.set_corner_radius_all(3)
	_hp.add_theme_stylebox_override("background", bg)
	_hp.add_theme_stylebox_override("fill", _hp_fill)
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp)
	_hp_txt = Label.new()
	_hp_txt.position = Vector2(_w - 70, 43)
	_hp_txt.size = Vector2(70, 20)
	_hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_txt.add_theme_font_override("font", UIKit.font("mono"))
	_hp_txt.add_theme_font_size_override("font_size", 13)
	_hp_txt.add_theme_color_override("font_color", UIKit.TEXT)
	add_child(_hp_txt)

	_chips = HBoxContainer.new()
	_chips.position = Vector2(x0, 66)
	_chips.add_theme_constant_override("separation", 6)
	_chips.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_chips)

	_stats = Label.new()
	_stats.position = Vector2(x0, 92)
	_stats.add_theme_font_override("font", UIKit.font("mono"))
	_stats.add_theme_font_size_override("font_size", 11)
	_stats.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	add_child(_stats)

func set_unit(c, team: String = "player") -> void:
	if c == null:
		_name.text = ""
		_sub.text = ""
		_stats.text = ""
		_hp_txt.text = ""
		_hp.value = 0
		for ch in _chips.get_children():
			ch.queue_free()
		return
	var tex = UnitArt.portrait(c, 128)
	if tex != null:
		portrait.texture = tex
	var enemy := team != "player"
	var tc: Color = UIKit.DANGER if enemy else UIKit.OK
	_name.text = str(c.name)
	var role := BattleRules.role_label(BattleRules.job_role(c.job_id))
	_sub.text = "%s · %s · LV %d" % ["敌军" if enemy else "我军", role, int(c.level)]
	_sub.add_theme_color_override("font_color", tc)
	_hp_fill.bg_color = tc
	_hp.max_value = maxi(1, int(c.max_hp))
	var target := float(clampi(int(c.hp), 0, int(c.max_hp)))
	var uid := str(c.id) if "id" in c else str(c.name)
	if uid == _last_uid and is_inside_tree():
		create_tween().tween_property(_hp, "value", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_hp.value = target
	_last_uid = uid
	_hp_txt.text = "%d / %d" % [int(c.hp), int(c.max_hp)]
	_stats.text = "攻%d  防%d  命%d  避%d  移%d" % [c.derived_atk(), c.derived_def(), c.derived_hit(), c.derived_avo(), c.derived_move()]
	for ch in _chips.get_children():
		ch.queue_free()
	var n := 0
	for sid in c.skills:
		if n >= 6:
			break
		_chips.add_child(_make_chip(c, str(sid), enemy))
		n += 1

func _make_chip(c, sid: String, enemy: bool) -> Control:
	var sz := 22.0
	var sk: Dictionary = GameState.get_skill(sid)
	var nm := str(sk.get("name", sid))
	var left := int(c.skill_uses.get(sid, 0)) if "skill_uses" in c else 1
	var cd := int(c.skill_cd.get(sid, 0)) if "skill_cd" in c else 0
	var ready := left > 0 and cd <= 0
	var b := Button.new()
	b.text = nm.substr(0, 1)
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	var col: Color = (UIKit.DANGER if enemy else UIKit.ACCENT)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(col, 0.10) if ready else Color(1, 1, 1, 0.03)
	n.border_color = Color(col, 0.55) if ready else Color(1, 1, 1, 0.08)
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	n.anti_aliasing = true
	n.content_margin_left = 2
	n.content_margin_right = 2
	n.content_margin_top = 0
	n.content_margin_bottom = 0
	var h: StyleBoxFlat = n.duplicate()
	h.bg_color = Color(col, 0.22)
	h.border_color = col
	var p: StyleBoxFlat = n.duplicate()
	p.bg_color = Color(0, 0, 0, 0.3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", col if ready else UIKit.TEXT_FAINT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", UIKit.TEXT_FAINT)
	b.tooltip_text = "%s　余%d%s" % [nm, left, ("　冷却%d" % cd) if cd > 0 else ""]
	b.pivot_offset = Vector2(sz, sz) * 0.5
	b.mouse_entered.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(1.1, 1.1), 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b
