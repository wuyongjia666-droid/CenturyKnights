extends Control
signal skill_pressed(sid: String)
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
var _chips: Container
var _mob := false
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
	_stats.add_theme_font_size_override("font_size", UIKit.desk_sz(11))
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
		if portrait != null and portrait.get_parent() is Control:
			CKPortraitStatus.attach(portrait.get_parent(), null, portrait.size)
		CKHeraldryField.attach_card_arms(self, null, team, "")
		return
	var tex = UnitArt.unit_portrait(c)
	if tex != null:
		portrait.texture = tex
	if portrait != null and portrait.get_parent() is Control:
		CKPortraitStatus.attach(portrait.get_parent(), c, portrait.size)
	var enemy := team != "player"
	var tc: Color = UIKit.DANGER if enemy else UIKit.OK
	var name_fallback := str(c.id) if "id" in c else "Knight"
	_name.text = Locale.latin(str(c.name), name_fallback)
	var role := str(BattleRules.role_label(BattleRules.job_role(c.job_id)))
	role = Locale.latin(role, str(BattleRules.job_role(c.job_id)))
	_sub.text = "%s · %s · LV %d" % [Locale.t("shell_f4069c8b") if enemy else Locale.t("shell_c832b9ce"), role, int(c.level)]
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
	_stats.text = Locale.t("shell_f59809be") % [c.derived_atk(), c.derived_def(), c.derived_hit(), c.derived_avo(), c.derived_move()]
	for ch in _chips.get_children():
		ch.queue_free()
	var n := 0
	for sid in c.skills:
		if n >= 6:
			break
		_chips.add_child(_make_chip(c, str(sid), enemy))
		n += 1
	var foe := str(get_meta("foe_nation", ""))
	if foe == "" and str(team) != "player":
		foe = CKHeraldryChrome.battle_foe_nation_for(null)
	CKHeraldryField.attach_card_arms(self, c, team, foe)
	if _mob:
		_fit_mobile()
		landscape_readable()

func _make_chip(c, sid: String, enemy: bool) -> Control:
	var sk: Dictionary = GameState.get_skill(sid)
	var nm := str(sk.get("name", sid))
	var desc := str(sk.get("desc", "")).strip_edges()
	if desc.find("。") >= 0:
		desc = desc.split("。")[0]
	elif desc.find(".") >= 0:
		desc = desc.split(".")[0]
	if desc.length() > 18:
		desc = desc.substr(0, 18) + "…"
	var left := int(c.skill_uses.get(sid, 0)) if "skill_uses" in c else 1
	var cd := int(c.skill_cd.get(sid, 0)) if "skill_cd" in c else 0
	var ready := left > 0 and cd <= 0
	var chip := nm
	if Locale.is_en() and Locale.has_cjk(nm):
		chip = sid
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var col: Color = (UIKit.DANGER if enemy else UIKit.ACCENT)
	if _mob:
		# Full name + short desc so phones match the desktop Art label / hint.
		b.text = "%s\n%s" % [chip, desc] if desc != "" else chip
		b.custom_minimum_size = Vector2(maxf(148.0, (_w - 16.0) * 0.48), 76.0)
		b.add_theme_font_size_override("font_size", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		b.text = chip.substr(0, 1)
		b.custom_minimum_size = Vector2(22.0, 22.0)
		b.add_theme_font_size_override("font_size", 12)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(col, 0.10) if ready else Color(1, 1, 1, 0.03)
	n.border_color = Color(col, 0.55) if ready else Color(1, 1, 1, 0.08)
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	n.anti_aliasing = true
	n.content_margin_left = 8 if _mob else 2
	n.content_margin_right = 8 if _mob else 2
	n.content_margin_top = 6 if _mob else 0
	n.content_margin_bottom = 6 if _mob else 0
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
	b.tooltip_text = Locale.t("shell_77586a60") % [Locale.latin(nm, sid), left, (Locale.t("shell_4140eed2") % cd) if cd > 0 else ""]
	b.disabled = enemy or not ready
	var sz: Vector2 = b.custom_minimum_size
	b.pivot_offset = sz * 0.5
	b.mouse_entered.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	if not enemy:
		var skill_id := str(sid)
		b.pressed.connect(func(): skill_pressed.emit(skill_id))
	return b


## Phone landscape: bigger type, chips wrap below the portrait at full touch size.
func mobile_layout(width: float) -> void:
	_mob = true
	_w = width
	set_meta("m_custom", true)
	var x0 := PW + 14.0
	_sub.position = Vector2(x0, 0)
	_sub.add_theme_font_size_override("font_size", 22)
	_name.position = Vector2(x0, 30)
	_name.add_theme_font_size_override("font_size", 26)
	_hp.position = Vector2(x0, 70)
	_hp.custom_minimum_size = Vector2(_w - x0, 8)
	_hp.size = _hp.custom_minimum_size
	_hp_txt.position = Vector2(x0, 78)
	_hp_txt.size = Vector2(_w - x0, 28)
	_hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hp_txt.add_theme_font_size_override("font_size", 22)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.position = Vector2(0, PH + 10.0)
	flow.size = Vector2(_w, 76)
	flow.custom_minimum_size = Vector2(_w, 0)
	flow.mouse_filter = Control.MOUSE_FILTER_PASS
	for ch in _chips.get_children():
		ch.reparent(flow, false)
	_chips.replace_by(flow)
	_chips.queue_free()
	_chips = flow
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit_mobile()


func _fit_mobile() -> void:
	var n := 0
	for ch in _chips.get_children():
		if not ch.is_queued_for_deletion():
			n += 1
	var chip_w := maxf(148.0, (_w - 16.0) * 0.48)
	var per := maxi(1, int((_w + 8.0) / (chip_w + 8.0)))
	var rows := 0 if n == 0 else int(ceil(float(n) / float(per)))
	_chips.size = Vector2(_w, maxf(0.0, rows * 84.0 - 8.0))
	var sy := PH + 10.0 + (rows * 84.0 if rows > 0 else 0.0)
	_stats.position = Vector2(0, sy)
	_stats.size = Vector2(_w, 56)
	custom_minimum_size = Vector2(_w, sy + 60.0)
	size = custom_minimum_size


## Phone landscape: wrap the name and stats, and let empty card chrome pass taps.
## Skill buttons stay STOP. Idempotent — positions are absolute, not cumulative.
func landscape_readable() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if not _mob:
		return
	var x0 := _name.position.x
	var text_w := maxf(48.0, _w - x0)
	_sub.clip_text = false
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.position = Vector2(x0, 0)
	_sub.size = Vector2(text_w, 28)
	_sub.custom_minimum_size = _sub.size
	_name.clip_text = false
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.position = Vector2(x0, 30)
	_name.size = Vector2(text_w, 52)
	_name.custom_minimum_size = _name.size
	_hp.position = Vector2(x0, 88)
	_hp_txt.clip_text = false
	_hp_txt.position = Vector2(x0, 100)
	_hp_txt.size = Vector2(text_w, 28)
	if _chips != null:
		_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chips.position = Vector2(0, PH + 28.0)
	_stats.clip_text = false
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chip_h := 0.0 if _chips == null else _chips.size.y
	var stat_y := PH + 28.0 + chip_h + 8.0
	_stats.position = Vector2(0, stat_y)
	_stats.size = Vector2(_w, 72)
	_stats.custom_minimum_size = Vector2(_w, 72)
	custom_minimum_size = Vector2(_w, stat_y + 80.0)
	size = custom_minimum_size
