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
	_build(); UIKit.stitch_dialogue(self); UIFX.fade_in(self, 0.4); Music.play_hub()
	_load_beat(GameState.chapter103_beat if GameState.chapter103_beat != "" else "103.0")
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
	for b in GameState.data_chapter103.get("beats", []):
		if b.get("id") == beat_id: _beat = b; break
	if _beat.is_empty(): return
	GameState.chapter103_beat = beat_id; GameState.mark_dirty(); _line_idx = 0
	_title.text = "%s · %s" % [GameState.data_chapter103.get("title", ""), _beat.get("title", "")]
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
		"103.0":
			_add("前往马市", func(): _goto_next())
		"103.1":
			if GameState.flag("ch103_market_done"): _add("听缰绳", func(): _goto_next())
			else: _add("出战：马市", func(): _battle("ch103_market"))
		"103.2":
			if GameState.flag("ch103_rein_done"): _add("听可开市", func(): _goto_next())
			else: _add("出战：缰绳", func(): _battle("ch103_rein"))
		"103.3":
			_add("完成第一百零三章并回堡", func():
				GameState.set_flag("chapter103_done")
				GameState.silver += 440; GameState.add_skill_point(2)
				GameState.add_rep("ashland", 18); GameState.save_game()
				get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
			_add("踏上第一百零四章·鞍房", func():
				GameState.set_flag("chapter103_done"); GameState.add_skill_point(2)
				GameState.chapter104_beat = "104.0"; get_tree().change_scene_to_file("res://scenes/story/chapter104.tscn"))
		_:
			_add("继续", func(): _goto_next())

func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 460); b.pressed.connect(cb); _actions.add_child(b)
func _goto_next() -> void:
	var nn = _beat.get("next")
	if nn == null: get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"); return
	_load_beat(str(nn))
func _battle(map_id: String) -> void:
	GameState.set_meta("battle_return", "res://scenes/story/chapter103.tscn")
	GameState.set_meta("battle_map", map_id)
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
