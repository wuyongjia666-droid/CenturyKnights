class_name ChapterPlayer
extends Control
## NAR-02：一个场景播放 data/story/chapters/*.json。第零章场景把 lock_path 打开。

const DEFAULT_PATH := "res://data/story/chapters/ch0.json"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

@export var chapter_path: String = DEFAULT_PATH
@export var lock_path: bool = false
@export var suppress_scene_change: bool = false

var _chapter: Dictionary = {}
var _beat: Dictionary = {}
var _line_idx: int = 0
var _speaker: Label
var _body: RichTextLabel
var _actions: VBoxContainer
var _title: Label
var _hint: Label
var _portrait: TextureRect
var _banner: TextureRect
var _beat_meta: Label
var test_capture: Dictionary = {}

func _ready() -> void:
	_build()
	UIKit.stitch_dialogue(self)
	_open(_resolve_path())

func _resolve_path() -> String:
	if not lock_path:
		var requested := str(GameState.get_meta("story_chapter_id", ""))
		if requested != "":
			var pointed := "res://data/story/chapters/%s.json" % requested
			if FileAccess.file_exists(pointed):
				GameState.set_meta("story_chapter_id", "")
				return pointed
	if chapter_path != "":
		return chapter_path
	return DEFAULT_PATH

func _open(path: String) -> void:
	_chapter = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			_chapter = parsed
	var beat_id := _stored_beat()
	if not _has_beat(beat_id):
		var beats: Array = _chapter.get("beats", [])
		beat_id = str(beats[0].get("id", "")) if not beats.is_empty() else ""
	_load_beat(beat_id)

func _has_beat(beat_id: String) -> bool:
	if beat_id == "":
		return false
	for b in _chapter.get("beats", []):
		if str(b.get("id", "")) == beat_id:
			return true
	return false

func _stored_beat() -> String:
	var idx := int(_chapter.get("legacy_index", 0))
	if idx == 0 and str(_chapter.get("id", "")) == "ch0":
		return str(GameState.chapter0_beat)
	return str(GameState.story.beat(idx))

func _remember_beat(beat_id: String) -> void:
	var idx := int(_chapter.get("legacy_index", 0))
	if idx == 0 and str(_chapter.get("id", "")) == "ch0":
		GameState.set_beat(beat_id)
	else:
		GameState.story.set_beat(idx, beat_id)
		GameState.mark_dirty()

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

func _load_beat(beat_id: String) -> void:
	_beat = {}
	for b in _chapter.get("beats", []):
		if str(b.get("id", "")) == beat_id:
			_beat = b
			break
	if _beat.is_empty():
		_hint.text = "章节结束"
		_speaker.text = ""
		_body.text = ""
		return
	_remember_beat(beat_id)
	_line_idx = 0
	_title.text = "%s · %s" % [str(_chapter.get("title", "")), str(_beat.get("title", ""))]
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
	var sp := str(line.get("speaker", ""))
	_speaker.text = sp
	_body.text = str(line.get("text", ""))
	_speaker_portrait(sp, str(line.get("expression", line.get("emotion", ""))))

func _character_named(speaker: String) -> CKCharacter:
	for c in GameState.characters.values():
		if c.name == speaker or str(c.cast_key) == speaker:
			return c
	return null

func _speaker_portrait(speaker: String, emotion: String = "") -> void:
	var who := _character_named(speaker)
	if who == null and UnitArt.companion_slot(speaker) != "":
		who = GameState.get_leader()
	var plate := UnitArt.dialogue_portrait(speaker, emotion, who, 120)
	if plate != null:
		_portrait.texture = plate
		return
	var leader = GameState.get_leader()
	match speaker:
		"旁白", "掌柜", "管事", "稳婆", "春令使者", "老旗手", "斥候", "盟友亲属":
			if leader and speaker in ["老旗手", "斥候"]:
				_portrait.texture = UnitArt.portrait(leader, 120)
			else:
				_portrait.texture = UnitArt.banner(120, 120, false)
		_:
			if leader:
				_portrait.texture = UnitArt.portrait(leader, 120)
			else:
				_portrait.texture = UnitArt.banner(120, 120, false)

func _refresh_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var lines: Array = _beat.get("lines", [])
	if _line_idx >= lines.size() - 1:
		for step in _beat.get("prepare", []):
			_run_op(step)
	if _line_idx < lines.size() - 1:
		_add_action("继续 ▶", func():
			_line_idx += 1
			_show_line()
			_refresh_actions()
		)
		return
	var shown := 0
	for action in _beat.get("actions", []):
		if typeof(action) != TYPE_DICTIONARY:
			continue
		if not StoryConditions.met(action.get("when", {})):
			continue
		shown += 1
		var row: Dictionary = action
		var steps: Array = (row.get("do", []) as Array).duplicate(true)
		var disabled := bool(row.get("disabled", false))
		_add_action(str(row.get("label", "")), _on_action.bind(steps), disabled)
	if shown == 0 and _beat.get("next") != null and str(_beat.get("next", "")) != "":
		_add_action("继续", func(): _goto_next())

func _add_action(text: String, cb: Callable, disabled: bool = false) -> void:
	var b = UIKit.make_button(text, 460) if disabled else UIKit.make_accent_button(text, 460)
	b.disabled = disabled
	if not disabled:
		b.pressed.connect(cb)
	_actions.add_child(b)

func _on_action(steps: Array) -> void:
	_run_steps(steps)

func _run_steps(steps: Array) -> void:
	for step in steps:
		if _run_op(step) == "stop":
			return

func _run_op(step) -> String:
	if typeof(step) != TYPE_DICTIONARY:
		return ""
	var row: Dictionary = step
	if row.has("when") and not StoryConditions.met(row["when"]):
		return ""
	match str(row.get("op", "")):
		"goto":
			var target := str(row.get("beat", "next"))
			if target == "next":
				_goto_next()
			else:
				_load_beat(target)
			return "stop"
		"set_flag":
			GameState.set_flag(str(row.get("flag", "")), bool(row.get("value", true)))
		"set_beat":
			GameState.story.set_beat(int(row.get("chapter", 0)), str(row.get("beat", "")))
			GameState.mark_dirty()
		"battle":
			var ret := str(row.get("return", _chapter.get("return_scene", "res://scenes/story/chapter0.tscn")))
			GameState.set_meta("battle_return", ret)
			GameState.set_meta("battle_map", str(row.get("map", "")))
			GameState.set_meta("battle_objective", str(row.get("objective", "")))
			test_capture["battle_map"] = str(row.get("map", ""))
			test_capture["battle_objective"] = str(row.get("objective", ""))
			_go_scene(BATTLE_SCENE)
			return "stop"
		"scene":
			_go_scene(str(row.get("path", "")))
			return "stop"
		"advance":
			var evs = Calendar.advance(int(row.get("months", 1)))
			_hint.text = "事件：" + _summarize(evs)
			_refresh_actions()
			return "stop"
		"fast_harvest":
			_fast_to_harvest()
			return "stop"
		"journal":
			_body.text = GameState.build_dynasty_journal()
			_speaker.text = Locale.t("dynasty_journal")
			GameState.set_flag("chapter0_done")
			GameState.save_game()
		"ensure_reputation":
			_ensure_reputation(row)
		"archive_notice":
			var msg := Locale.t("story_archive_sealed")
			if msg == "story_archive_sealed":
				msg = "旧卷已封存。这些模板章不再作为主线，也不再重玩。"
			_body.text = msg
			_speaker.text = "老旗手"
			_hint.text = msg
	return ""

func _ensure_reputation(row: Dictionary) -> void:
	var realm := str(row.get("realm", ""))
	var below := int(row.get("below", 30))
	var tier := str(row.get("also_if_tier", ""))
	var current := int(GameState.reputation.get(realm, 0))
	if (tier != "" and GameState.get_rep_tier(realm) == tier) or current < below:
		GameState.reputation[realm] = int(row.get("set", below))
		var note := str(row.get("log", ""))
		if note != "":
			GameState.log_event(note)

func _goto_next() -> void:
	var n = _beat.get("next")
	if n == null or str(n) == "":
		_go_scene("res://scenes/hub/castle_hub.tscn")
		return
	_load_beat(str(n))

func _go_scene(path: String) -> void:
	test_capture["scene"] = path
	if suppress_scene_change or path == "":
		return
	get_tree().change_scene_to_file(path)

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

func current_beat_id() -> String:
	return str(_beat.get("id", _stored_beat()))

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
