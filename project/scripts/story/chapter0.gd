extends Control

var _line_idx: int = 0
var _beat: Dictionary = {}
var _speaker: Label
var _body: RichTextLabel
var _actions: VBoxContainer
var _title: Label
var _hint: Label
var _portrait: TextureRect
var _banner: TextureRect
var _beat_meta: Label

func _ready() -> void:
	_build()
	_load_beat(GameState.chapter0_beat)

func _build() -> void:
	UIKit.make_screen_bg(self)

	_banner = UIKit.make_banner_rect(70, 100)
	_banner.position = Vector2(48, 24)
	add_child(_banner)

	_title = UIKit.make_label("", true)
	_title.position = Vector2(140, 28)
	add_child(_title)

	_beat_meta = UIKit.make_dim_label("")
	_beat_meta.position = Vector2(140, 68)
	add_child(_beat_meta)

	var panel = UIKit.make_panel()
	panel.position = Vector2(48, 110)
	panel.custom_minimum_size = Vector2(980, 300)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(120, 120)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_portrait)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_speaker = UIKit.make_label("")
	_speaker.add_theme_color_override("font_color", UIKit.ACCENT)
	_speaker.add_theme_font_size_override("font_size", 18)
	vb.add_child(_speaker)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(780, 200)
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	_body.add_theme_font_size_override("normal_font_size", 16)
	vb.add_child(_body)

	_actions = VBoxContainer.new()
	_actions.position = Vector2(48, 440)
	_actions.add_theme_constant_override("separation", 10)
	add_child(_actions)

	_hint = UIKit.make_dim_label("")
	_hint.position = Vector2(48, 660)
	_hint.custom_minimum_size = Vector2(900, 40)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

	var top := HBoxContainer.new()
	top.position = Vector2(900, 36)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var save_btn = UIKit.make_button("存档", 100)
	save_btn.pressed.connect(func():
		GameState.save_game()
		_hint.text = Locale.t("save_ok")
	)
	top.add_child(save_btn)

func _speaker_portrait(speaker: String) -> void:
	var leader = GameState.get_leader()
	var ally: CKCharacter = null
	for c in GameState.characters.values():
		if c.name.find("灯影") >= 0:
			ally = c
			break
	match speaker:
		"苇原·灯影":
			if ally:
				_portrait.texture = UnitArt.portrait(ally, 120)
			elif leader:
				_portrait.texture = UnitArt.portrait(leader, 120)
		"旁白", "系统", "掌柜", "管事", "稳婆", "春令使者", "老旗手", "斥候", "盟友亲属":
			# 叙事角色：用团长或战旗感立绘框
			if leader and speaker in ["老旗手", "斥候"]:
				_portrait.texture = UnitArt.portrait(leader, 120)
			else:
				_portrait.texture = UnitArt.banner(120, 120, false)
		_:
			if leader:
				_portrait.texture = UnitArt.portrait(leader, 120)
			else:
				_portrait.texture = UnitArt.banner(120, 120, false)

func _load_beat(beat_id: String) -> void:
	_beat = {}
	for b in GameState.data_chapter0.get("beats", []):
		if b.get("id") == beat_id:
			_beat = b
			break
	if _beat.is_empty():
		_hint.text = "章节结束"
		return
	GameState.set_beat(beat_id)
	_line_idx = 0
	_title.text = "%s · %s" % [GameState.data_chapter0.get("title", ""), _beat.get("title", "")]
	_beat_meta.text = "节拍 %s　灰烬旗 · %s" % [beat_id, GameState.surname]
	_banner.texture = UnitArt.banner(70, 100, true)
	_show_line()
	_refresh_actions()

func _show_line() -> void:
	var lines: Array = _beat.get("lines", [])
	if _line_idx >= lines.size():
		_speaker.text = ""
		_body.text = "（本节对白结束——请选择下方行动）"
		return
	var line = lines[_line_idx]
	var sp = str(line.get("speaker", ""))
	_speaker.text = sp
	_body.text = str(line.get("text", ""))
	_speaker_portrait(sp)

func _refresh_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var lines: Array = _beat.get("lines", [])
	if _line_idx < lines.size() - 1:
		var nxt = UIKit.make_accent_button("继续 ▶", 220)
		nxt.pressed.connect(func():
			_line_idx += 1
			_show_line()
			_refresh_actions()
		)
		_actions.add_child(nxt)
		return
	# 对白读完：根据节拍显示系统行动
	var bid = str(_beat.get("id", ""))
	match bid:
		"0.0":
			_add_action("踏入旗面初成", func(): _goto_next())
		"0.05":
			_add_action("前往隘口之夜", func(): _goto_next())
		"0.1":
			if GameState.flag("battle_done"):
				_add_action("听烟散之后", func(): _goto_next())
			else:
				_add_action("开始战斗教学", func(): _start_battle("ch0_pass"))
				_add_action("（战败可重试，不毁进度）", func(): pass, true)
		"0.15":
			_add_action("前往烽火酒馆", func(): _goto_next())
		"0.2":
			if GameState.flag("recruited"):
				_add_action("新刃入鞘", func(): _goto_next())
			else:
				_add_action("打开烽火酒馆（须招募 1 人）", func():
					get_tree().change_scene_to_file("res://scenes/hub/tavern.tscn")
				)
		"0.25":
			_add_action("入驻灰旗堡", func():
				GameState.set_flag("hub_open")
				_goto_next()
			)
		"0.3":
			_add_action("进入灰旗堡枢纽", func():
				GameState.set_flag("hub_open")
				GameState.set_beat("0.35")
				get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
			)
			_add_action("先听陆桥耳语", func():
				GameState.set_flag("hub_open")
				_goto_next()
			)
		"0.35":
			_add_action("进入春令试婚", func(): _goto_next())
			_add_action("先回灰旗堡准备", func():
				get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
			)
		"0.4":
			if GameState.flag("married"):
				_add_action("赴双姓共席", func(): _goto_next())
			else:
				if GameState.get_rep_tier("ashland") == "none" or int(GameState.reputation.get("ashland", 0)) < 30:
					GameState.reputation["ashland"] = 35
					GameState.log_event("春令使者代请：灰烬邦声望升至友善")
				_add_action("前往联姻廷", func():
					get_tree().change_scene_to_file("res://scenes/hub/marriage.tscn")
				)
		"0.45":
			_add_action("等待初啼", func(): _goto_next())
		"0.5":
			if GameState.flag("child_born"):
				_add_action("翻开族谱新页", func(): _goto_next())
			else:
				_add_action("推进一月迎来初啼", func():
					var evs = Calendar.advance(1)
					_hint.text = "事件：" + _summarize(evs)
					_refresh_actions()
				)
				_add_action("打开族谱/遗传面板", func():
					get_tree().change_scene_to_file("res://scenes/hub/lineage_view.tscn")
				)
		"0.55":
			_add_action("进入秋收簿", func(): _goto_next())
			_add_action("再看一眼族谱", func():
				get_tree().change_scene_to_file("res://scenes/hub/lineage_view.tscn")
			)
		"0.6":
			if GameState.flag("harvest_done") or GameState.flag("chapter0_done"):
				_add_action("生成王朝手记", func():
					var j = GameState.build_dynasty_journal()
					_body.text = j
					_speaker.text = Locale.t("dynasty_journal")
					GameState.set_flag("chapter0_done")
					GameState.save_game()
				)
				_add_action("返回灰旗堡（自由游玩）", func():
					GameState.set_flag("chapter0_done")
					get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
				)
			else:
				_add_action("岁月沙漏：跳至丰收月并结算", func():
					_fast_to_harvest()
				)
				_add_action("打开岁月沙漏", func():
					get_tree().change_scene_to_file("res://scenes/hub/hourglass.tscn")
				)
		_:
			_add_action("继续", func(): _goto_next())

func _add_action(text: String, cb: Callable, disabled: bool = false) -> void:
	var b = UIKit.make_button(text, 460) if disabled else UIKit.make_accent_button(text, 460)
	b.disabled = disabled
	if not disabled:
		b.pressed.connect(cb)
	_actions.add_child(b)

func _goto_next() -> void:
	var n = _beat.get("next")
	if n == null:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
		return
	_load_beat(str(n))

func _start_battle(map_id: String) -> void:
	GameState.set_meta("battle_return", "res://scenes/story/chapter0.tscn")
	GameState.set_meta("battle_map", map_id)
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")

func _fast_to_harvest() -> void:
	while not (Calendar.month == Calendar.HARVEST_MONTH and GameState.flag("harvest_done")):
		Calendar.advance(1)
		if Calendar.year > 3:
			break
	_hint.text = "已至 %s，丰收已结算。年龄可见变化。" % Calendar.label()
	_refresh_actions()

func _summarize(evs: Array) -> String:
	var parts: Array = []
	for e in evs:
		parts.append(str(e.get("text", "")))
	return "；".join(parts)

## --- Headless e2e helpers ---

func current_beat_id() -> String:
	return str(_beat.get("id", GameState.chapter0_beat))

func action_labels() -> Array:
	var out: Array = []
	for c in _actions.get_children():
		if c is BaseButton and is_instance_valid(c) and not c.is_queued_for_deletion():
			out.append(str(c.text))
	return out

func simulate_finish_dialogue() -> void:
	for c in _actions.get_children():
		c.free()
	var lines: Array = _beat.get("lines", [])
	_line_idx = maxi(0, lines.size() - 1)
	_show_line()
	_refresh_actions()

func simulate_press_action_containing(substr: String) -> bool:
	for c in _actions.get_children():
		if c is BaseButton and is_instance_valid(c) and not c.is_queued_for_deletion() and not c.disabled and str(c.text).find(substr) >= 0:
			c.pressed.emit()
			return true
	return false

func simulate_goto_beat(beat_id: String) -> void:
	_load_beat(beat_id)
