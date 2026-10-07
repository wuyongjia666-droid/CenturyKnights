extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _expect: RichTextLabel
var _selected: CKCharacter
var _msg: Label

func _ready() -> void:
	if int(GameState.reputation.get("ashland", 0)) < 30:
		GameState.reputation["ashland"] = maxi(int(GameState.reputation.get("ashland", 0)), 35)
	if GameState.marriage_candidates.is_empty():
		GameState.refresh_marriage_candidates()
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t = UIKit.make_label("联姻廷 · 春令试婚", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var rep = UIKit.make_label("灰烬邦声望：%s　河卫邦：%s" % [GameState.get_rep_name("ashland"), GameState.get_rep_name("riverland")])
	rep.position = Vector2(40, 56)
	add_child(rep)
	_list = VBoxContainer.new()
	_list.position = Vector2(40, 90)
	add_child(_list)
	_detail = RichTextLabel.new()
	_detail.position = Vector2(420, 90)
	_detail.custom_minimum_size = Vector2(400, 280)
	_detail.bbcode_enabled = true
	add_child(_detail)
	var el = UIKit.make_label(Locale.t("heir_expect"))
	el.position = Vector2(840, 90)
	el.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(el)
	_expect = RichTextLabel.new()
	_expect.position = Vector2(840, 120)
	_expect.custom_minimum_size = Vector2(400, 400)
	_expect.bbcode_enabled = true
	add_child(_expect)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 520)
	_msg.custom_minimum_size = Vector2(800, 40)
	add_child(_msg)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 580)
	add_child(row)
	var marry = UIKit.make_button("定聘礼并成婚（40银）", 220)
	marry.pressed.connect(_do_marry)
	row.add_child(marry)
	var refresh = UIKit.make_button("刷新候选", 120)
	refresh.pressed.connect(func():
		GameState.refresh_marriage_candidates()
		_refresh()
	)
	row.add_child(refresh)
	var back = UIKit.make_button(Locale.t("btn_back"), 100)
	back.pressed.connect(_back)
	row.add_child(back)

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for cand in GameState.marriage_candidates:
		var check = Lineage.can_propose(GameState.get_leader(), cand)
		var tag = "可表白" if check.get("ok") else "声望不足"
		var b = UIKit.make_button("%s　%s　%s" % [cand.name, cand.rank_name(), tag], 340)
		var captured = cand
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
	if GameState.marriage_candidates.size() > 0:
		_select(GameState.marriage_candidates[0])

func _select(c: CKCharacter) -> void:
	_selected = c
	var check = Lineage.can_propose(GameState.get_leader(), c)
	_detail.text = UIKit.char_card_text(c) + "\n\n门槛：%s\n%s" % [check.get("need", ""), check.get("msg", "")]
	# X1 子嗣期望
	var leader = GameState.get_leader()
	var exp = Lineage.heir_expectation(leader, c)
	var lines: Array = ["[b]子嗣期望（订婚前）[/b]"]
	lines.append("血胤混合预览：")
	for k in exp.blood_mix.keys():
		var bl = GameState.get_bloodline(k)
		lines.append("  %s %d%%" % [bl.get("name", k), int(round(float(exp.blood_mix[k]) * 100))])
	lines.append("六维资质区间：")
	for sk in CKCharacter.STAT_KEYS:
		lines.append("  %s %d–%d" % [Locale.t("stat_" + sk), exp.apt_min[sk], exp.apt_max[sk]])
	lines.append("禀性概率（前几）：")
	for tp in exp.trait_probs.slice(0, mini(5, exp.trait_probs.size())):
		lines.append("  %s %.0f%%" % [tp.name, tp.prob * 100])
	lines.append("容貌·发色：")
	for ap in exp.appearance_probs.get("hair", []).slice(0, 3):
		lines.append("  %s %.0f%%" % [ap.name, ap.prob * 100])
	lines.append("预估子代勋位：%s" % CKCharacter.RANK_NAMES.get(exp.rank_hint, exp.rank_hint))
	_expect.text = "\n".join(lines)

func _do_marry() -> void:
	if _selected == null:
		return
	var r = Lineage.marry(GameState.get_leader(), _selected, 40)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		GameState.save_game()
		_msg.text += "　妊娠将在岁月推进后分娩。"

func _back() -> void:
	if str(GameState.chapter0_beat) in ["0.4", "0.5"] and not GameState.flag("chapter0_done"):
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
