extends Control
## v8.5 battle unit card — composes the v840 unit_card_frame / hp_bar_kit / skill_chip plates
## (prepped by tools/farm_queue/prep_v850_chrome.py) around a live portrait.
## Plate space is 320x128; everything is laid out in plate coords * _s.

const SHELL := "res://assets/art/ui/v85/unit_card_shell.png"
const HP_FRAME := "res://assets/art/ui/v85/hp_bar_frame.png"
const HP_UNDER := "res://assets/art/ui/v85/hp_bar_under.png"
const HP_ALLY := "res://assets/art/ui/v85/hp_fill_ally.png"
const HP_ENEMY := "res://assets/art/ui/v85/hp_fill_enemy.png"
const CHIP := "res://assets/art/ui/v85/skill_chip_frame.png"

var portrait: TextureRect
var _s: float = 1.0
var _name: Label
var _sub: Label
var _hp: TextureProgressBar
var _hp_txt: Label
var _stats: Label
var _chips: HBoxContainer
var _last_uid: String = ""

func _init(width: float = 360.0) -> void:
	_s = width / 320.0
	custom_minimum_size = Vector2(320, 128) * _s
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()

func _r(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _s

func _tex(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

func _build() -> void:
	# portrait window (12,10)-(92,116): clip so a square bust crops top-biased
	var clip := Control.new()
	clip.position = _r(12, 10)
	clip.size = _r(80, 106)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = clip.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(bg)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size = clip.size
	portrait.pivot_offset = clip.size * 0.5
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(portrait)

	var shell := TextureRect.new()
	shell.texture = _tex(SHELL)
	shell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shell.stretch_mode = TextureRect.STRETCH_SCALE
	shell.size = _r(320, 128)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shell)

	_name = Label.new()
	_name.position = _r(102, 9)
	_name.add_theme_font_size_override("font_size", int(15 * _s))
	_name.add_theme_color_override("font_color", UIKit.TEXT)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_name.add_theme_constant_override("outline_size", 3)
	add_child(_name)
	_sub = Label.new()
	_sub.position = _r(102, 27)
	_sub.add_theme_font_size_override("font_size", int(10 * _s))
	_sub.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	add_child(_sub)

	# HP: frame 300x40 placed at k scale; window (57,14)-(252,26) in frame space
	var k := 0.58
	var fpos := Vector2(98, 40)
	_hp = TextureProgressBar.new()
	_hp.texture_under = _tex(HP_UNDER)
	_hp.texture_progress = _tex(HP_ALLY)
	_hp.nine_patch_stretch = true
	_hp.position = _r(fpos.x + 57 * k, fpos.y + 15 * k)
	_hp.size = _r(195 * k, 10 * k)
	_hp.min_value = 0
	_hp.max_value = 100
	_hp.value = 100
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp)
	var hf := TextureRect.new()
	hf.texture = _tex(HP_FRAME)
	hf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hf.stretch_mode = TextureRect.STRETCH_SCALE
	hf.position = _r(fpos.x, fpos.y)
	hf.size = _r(300 * k, 40 * k)
	hf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hf)
	_hp_txt = Label.new()
	_hp_txt.position = _r(fpos.x + 300 * k + 2, fpos.y + 6)
	_hp_txt.add_theme_font_size_override("font_size", int(11 * _s))
	_hp_txt.add_theme_color_override("font_color", UIKit.TEXT)
	add_child(_hp_txt)

	_chips = HBoxContainer.new()
	_chips.position = _r(102, 70)
	_chips.add_theme_constant_override("separation", int(4 * _s))
	_chips.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_chips)

	_stats = Label.new()
	_stats.position = _r(100, 101)
	_stats.add_theme_font_size_override("font_size", int(10 * _s))
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
	_name.text = str(c.name)
	_name.add_theme_color_override("font_color", UIKit.DANGER.lightened(0.25) if enemy else UIKit.TEXT)
	var role := BattleRules.role_label(BattleRules.job_role(c.job_id))
	_sub.text = "%s · %s · Lv%d" % ["敌军" if enemy else "我军", role, int(c.level)]
	_hp.texture_progress = _tex(HP_ENEMY if enemy else HP_ALLY)
	_hp.max_value = maxi(1, int(c.max_hp))
	var target := float(clampi(int(c.hp), 0, int(c.max_hp)))
	var uid := str(c.id) if "id" in c else str(c.name)
	if uid == _last_uid and is_inside_tree():
		create_tween().tween_property(_hp, "value", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_hp.value = target
	_last_uid = uid
	_hp_txt.text = "%d/%d" % [int(c.hp), int(c.max_hp)]
	_stats.text = "攻 %d　防 %d　命 %d　避 %d　移 %d" % [c.derived_atk(), c.derived_def(), c.derived_hit(), c.derived_avo(), c.derived_move()]
	for ch in _chips.get_children():
		ch.queue_free()
	var n := 0
	for sid in c.skills:
		if n >= 6:
			break
		_chips.add_child(_make_chip(c, str(sid)))
		n += 1

func _make_chip(c, sid: String) -> Control:
	var sz := 26.0 * _s
	var root := Control.new()
	root.custom_minimum_size = Vector2(sz, sz)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var fr := TextureRect.new()
	fr.texture = _tex(CHIP)
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	fr.size = Vector2(sz, sz)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fr)
	var sk: Dictionary = GameState.get_skill(sid)
	var nm := str(sk.get("name", sid))
	var lab := Label.new()
	lab.text = nm.substr(0, 1)
	lab.size = Vector2(sz, sz)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", int(12 * _s))
	lab.add_theme_color_override("font_color", UIKit.ACCENT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lab)
	var left := int(c.skill_uses.get(sid, 0)) if "skill_uses" in c else 1
	var cd := int(c.skill_cd.get(sid, 0)) if "skill_cd" in c else 0
	var ready := left > 0 and cd <= 0
	root.modulate = Color(1, 1, 1, 1) if ready else Color(0.55, 0.58, 0.65, 0.75)
	root.tooltip_text = "%s　余%d%s" % [nm, left, ("　冷却%d" % cd) if cd > 0 else ""]
	root.mouse_entered.connect(func(): root.create_tween().tween_property(root, "scale", Vector2(1.12, 1.12), 0.08))
	root.mouse_exited.connect(func(): root.create_tween().tween_property(root, "scale", Vector2.ONE, 0.1))
	root.pivot_offset = Vector2(sz, sz) * 0.5
	return root
