extends Control
var _line_idx: int = 0
var _beat: Dictionary = {}
var _speaker: Label
var _body: RichTextLabel
var _actions: VBoxContainer
var _title: Label
var _portrait: TextureRect
var _banner: TextureRect
func _ready() -> void:
	_build(); UIFX.fade_in(self, 0.4); Music.play_hub()
	_load_beat(GameState.chapter54_beat if GameState.chapter54_beat != "" else "54.0")
func _build() -> void:
	UIKit.make_screen_bg(self)
	_banner = UIKit.make_banner_rect(70, 100); _banner.position = Vector2(48, 24); add_child(_banner)
	_title = UIKit.make_label("", true); _title.position = Vector2(140, 28); add_child(_title)
	var panel = UIKit.make_panel(); panel.position = Vector2(48, 110); panel.custom_minimum_size = Vector2(980, 300); add_child(panel)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 16); panel.add_child(hb)
	_portrait = TextureRect.new(); _portrait.custom_minimum_size = Vector2(120, 120)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; hb.add_child(_portrait)
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(vb)
	_speaker = UIKit.make_label(""); _speaker.add_theme_color_override("font_color", UIKit.ACCENT); vb.add_child(_speaker)
	_body = RichTextLabel.new(); _body.bbcode_enabled = true; _body.fit_content = true
	_body.custom_minimum_size = Vector2(780, 200); _body.add_theme_color_override("default_color", UIKit.TEXT); vb.add_child(_body)
	_actions = VBoxContainer.new(); _actions.position = Vector2(48, 440); _actions.add_theme_constant_override("separation", 10); add_child(_actions)
	var hub = UIKit.make_button("返回灰旗堡", 140); hub.position = Vector2(1000, 36)
	hub.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(hub)
func _load_beat(beat_id: String) -> void:
	_beat = {}
	for b in GameState.data_chapter54.get("beats", []):
		if b.get("id") == beat_id: _beat = b; break
	if _beat.is_empty(): return
	GameState.chapter54_beat = beat_id; GameState.mark_dirty(); _line_idx = 0
	_title.text = "%s · %s" % [GameState.data_chapter54.get("title", ""), _beat.get("title", "")]
	_banner.texture = UnitArt.banner(70, 100, true); _show_line(); _refresh_actions()
func _show_line() -> void:
	var lines: Array = _beat.get("lines", [])
	if _line_idx >= lines.size():
		_speaker.text = ""; _body.text = "（本节对白结束）"; return
	var line = lines[_line_idx]
	_speaker.text = str(line.get("speaker", "")); _body.text = str(line.get("text", ""))
	var leader = GameState.get_leader()
	if leader: _portrait.texture = UnitArt.portrait(leader, 120)
func _refresh_actions() -> void:
	for c in _actions.get_children(): c.queue_free()
	var lines: Array = _beat.get("lines", [])
	if _line_idx < lines.size() - 1:
		var nxt = UIKit.make_accent_button("继续 ▶", 220)
		nxt.pressed.connect(func(): _line_idx += 1; _show_line(); _refresh_actions()); _actions.add_child(nxt); return
	match str(_beat.get("id", "")):
		"54.0":
			_add("前往八卷钤印", func(): _goto_next())
		"54.1":
			if GameState.flag("ch54_seal_done"): _add("听八卷中段", func(): _goto_next())
			else: _add("出战：八卷钤印", func(): _battle("ch54_seal"))
		"54.2":
			_add("完成第五十四章并回堡", func():
				GameState.set_flag("chapter54_done"); GameState.set_flag("volume8_mid_done")
				GameState.silver += 360; GameState.add_skill_point(3); GameState.save_game()
				get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
			_add("踏上第五十五章·朔风", func():
				GameState.set_flag("chapter54_done"); GameState.set_flag("volume8_mid_done"); GameState.add_skill_point(2)
				GameState.chapter55_beat = "55.0"; get_tree().change_scene_to_file("res://scenes/story/chapter55.tscn"))
		_:
			_add("继续", func(): _goto_next())
func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 460); b.pressed.connect(cb); _actions.add_child(b)
func _goto_next() -> void:
	var n = _beat.get("next")
	if n == null: get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"); return
	_load_beat(str(n))
func _battle(map_id: String) -> void:
	GameState.set_meta("battle_return", "res://scenes/story/chapter54.tscn")
	GameState.set_meta("battle_map", map_id)
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
