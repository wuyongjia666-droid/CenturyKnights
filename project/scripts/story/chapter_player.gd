class_name ChapterPlayer
extends Control
## NAR-02：一个场景播放 data/story/chapters/*.json。第零章场景把 lock_path 打开。

const DEFAULT_PATH := "res://data/story/chapters/ch0.json"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const HUB_SCENE := "res://scenes/hub/castle_hub.tscn"

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
var _stage_tween: Tween

func _ready() -> void:
	# Story lines are authored text. RichTextLabel.set_text runs them through
	# TranslationServer, and an exported OptimizedTranslation can hash-collide
	# a line into empty text (a black transcript page).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_build()
	UIKit.stitch_dialogue(self)
	# Back from a side screen the story opened with "visit": the trip is over.
	if GameState.has_meta("story_return"):
		GameState.set_meta("story_return", "")
	_open(_resolve_path())

func _resolve_path() -> String:
	if not lock_path:
		var requested := str(GameState.get_meta("story_chapter_id", ""))
		if requested != "":
			GameState.set_meta("story_chapter_id", "")
			var pointed := StoryCatalog.path_for(requested)
			if pointed == "":
				# Never fall back to ch0: that replays the prologue's last beat forever.
				push_error("chapter_player: unknown chapter id %s" % requested)
				test_capture["missing_chapter"] = requested
				return ""
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
	_body.bbcode_enabled = false
	_body.fit_content = false
	_body.scroll_active = true
	_body.scroll_following = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(640, 96)
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	_body.add_theme_font_override("normal_font", UIKit.font("regular"))
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
		_set_body("")
		for c in _actions.get_children():
			c.queue_free()
		_add_action(Locale.t("story_back_to_hub"), func(): _go_scene(HUB_SCENE))
		return
	if not StoryConditions.met(_beat.get("when", {})):
		var skipped = _beat.get("next")
		if skipped != null and str(skipped) != "" and str(skipped) != beat_id:
			_load_beat(str(skipped))
		return
	_remember_beat(beat_id)
	_line_idx = 0
	_title.text = "%s · %s" % [str(_chapter.get("title", "")), str(_beat.get("title", ""))]
	_beat_meta.text = "节拍 %s　灰烬旗 · %s" % [beat_id, GameState.surname]
	_banner.texture = UnitArt.banner(70, 100, true)
	_show_line()
	_refresh_actions()

func _visible_lines() -> Array:
	var out: Array = []
	for line in _beat.get("lines", []):
		if typeof(line) != TYPE_DICTIONARY:
			continue
		if StoryConditions.met(line.get("when", {})):
			out.append(line)
	return out

func _show_line() -> void:
	var lines: Array = _visible_lines()
	if _line_idx >= lines.size():
		_speaker.text = ""
		_set_body("（本节对白结束——请选择下方行动）")
		return
	var line = lines[_line_idx]
	var sp := str(line.get("speaker", ""))
	_speaker.text = sp
	_body.visible_ratio = 1.0
	_body.modulate.a = 1.0
	_set_body(_line_text(line))
	_speaker_portrait(sp, str(line.get("expression", line.get("emotion", ""))))
	_apply_stage(line.get("stage", {}))

func _set_body(text: String) -> void:
	_body.text = text
	# A previous long line leaves the scrollbar past the new text, so the
	# page draws as an empty dark box until the player scrolls back up.
	_body.scroll_to_line(0)

func _line_text(line) -> String:
	var body := str(line.get("text", ""))
	if body.find("{surname}") >= 0:
		var sn := str(GameState.surname).strip_edges()
		body = body.replace("{surname}", sn if sn != "" else Locale.t("pro_surname_fallback"))
	if body.find("{heir}") < 0:
		return body
	return body.replace("{heir}", _living_heir_name())

## Staging hooks authored on a line: {"music", "tension", "camera", "pace"}.
## Every cue is optional and harmless when the asset or autoload is missing.
func _apply_stage(stage) -> void:
	if typeof(stage) != TYPE_DICTIONARY or (stage as Dictionary).is_empty():
		return
	var s: Dictionary = stage
	test_capture["stage"] = s.duplicate(true)
	var trail: Array = test_capture.get("stage_log", [])
	trail.append(s.duplicate(true))
	test_capture["stage_log"] = trail
	var music := str(s.get("music", ""))
	if music != "" and Music != null:
		if music.begins_with("dynasty:"):
			Music.play_dynasty(music.trim_prefix("dynasty:"))
		else:
			Music.play_state(music)
	if s.has("tension") and Music != null:
		Music.set_tension(float(s.get("tension", 0.0)))
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()
	_stage_tween = null
	match str(s.get("camera", "")):
		"close":
			_portrait.pivot_offset = _portrait.custom_minimum_size * 0.5
			_tw().tween_property(_portrait, "scale", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
		"wide":
			_tw().tween_property(_portrait, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
			_tw().tween_property(_banner, "scale", Vector2.ONE, 0.45)
		"banner":
			_banner.pivot_offset = Vector2.ZERO
			_tw().tween_property(_banner, "scale", Vector2(1.6, 1.6), 0.6).set_trans(Tween.TRANS_SINE)
		"shake":
			var base := _portrait.position
			var seq := create_tween()
			for dx in [6.0, -5.0, 3.0, 0.0]:
				seq.tween_property(_portrait, "position", base + Vector2(dx, 0), 0.05)
	match str(s.get("pace", "")):
		"slow":
			_body.visible_ratio = 0.0
			_tw().tween_property(_body, "visible_ratio", 1.0, 1.4)
		"beat":
			_body.modulate.a = 0.0
			_tw().tween_property(_body, "modulate:a", 1.0, 0.5)

func _tw() -> Tween:
	if _stage_tween == null or not _stage_tween.is_valid():
		_stage_tween = create_tween().set_parallel(true)
	return _stage_tween

## Living child whose parent_ids include the leader. Locale key holds the unnamed fallback.
func _living_heir_name() -> String:
	var leader = GameState.get_leader()
	if leader == null:
		return Locale.t("nar06_no_heir")
	for c in GameState.characters.values():
		if c == null or not c.alive:
			continue
		var parents = c.parent_ids
		if typeof(parents) != TYPE_ARRAY:
			continue
		if leader.id in parents and str(c.name) != "":
			return str(c.name)
	return Locale.t("nar06_no_heir")

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
				_portrait.texture = UnitArt.portrait(leader, 120, CKArtPaths.TIER_MEDIUM)
			else:
				_portrait.texture = UnitArt.banner(120, 120, false)
		_:
			# A named voice without a roster body (patron, rival, family) must not borrow the leader's face.
			_portrait.texture = UnitArt.banner(120, 120, false)

func _refresh_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var lines: Array = _visible_lines()
	if _line_idx >= lines.size() - 1:
		for step in _beat.get("prepare", []):
			_run_op(step)
	if _line_idx < lines.size() - 1:
		_add_action("继续 ▶", func():
			_line_idx += 1
			_show_line()
			_refresh_actions()
		, false, true)
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
		_add_action("继续", func(): _goto_next(), false, true)
	elif shown == 0:
		# Chapter end protocol: a last beat with no actions still has a way out.
		# The beat is already remembered, so the mainline cursor moves on.
		_add_action(Locale.t("story_back_to_hub"), func(): _go_scene(HUB_SCENE))

func _add_action(text: String, cb: Callable, disabled: bool = false, compact: bool = false) -> void:
	var w := 148 if compact else 320
	var b = UIKit.make_button(text, w) if disabled else UIKit.make_accent_button(text, w)
	b.disabled = disabled
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	if compact:
		b.name = "AdvanceLine"
		b.custom_minimum_size = Vector2(148, 36)
		UIKit.compact(b, 36)
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
		"open_chapter":
			# Leave this chapter for another one by id (ch0 -> e1_01). Audit P1-5.
			var target_id := str(row.get("id", ""))
			test_capture["open_chapter"] = target_id
			_go_scene(StoryCatalog.request_chapter(target_id))
			return "stop"
		"advance":
			var until := str(row.get("until_flag", ""))
			var evs: Array = []
			if until != "":
				var guard := int(row.get("max", 14))
				while not GameState.flag(until) and guard > 0:
					evs.append_array(Calendar.advance(1))
					guard -= 1
			else:
				evs = Calendar.advance(int(row.get("months", 1)))
			_hint.text = "事件：" + _summarize(evs)
			_refresh_actions()
			return "stop"
		"visit":
			GameState.set_meta("story_return", str(_chapter.get("return_scene", StoryCatalog.chapter0_scene())))
			_go_scene(str(row.get("path", "")))
			return "stop"
		"adjust":
			_adjust(row)
		"skip_battle":
			GameState.set_flag("battle_done")
			GameState.log_event(str(row.get("log", Locale.t("pro_skip_battle_log"))))
			test_capture["skipped_battle"] = true
		"auto_recruit":
			_auto_recruit()
		"auto_marry":
			_auto_marry()
		"fast_harvest":
			_fast_to_harvest()
			return "stop"
		"journal":
			_set_body(GameState.build_dynasty_journal())
			_speaker.text = Locale.t("dynasty_journal")
			GameState.set_flag("chapter0_done")
			GameState.save_game()
		"ensure_reputation":
			_ensure_reputation(row)
		"archive_notice":
			var msg := Locale.t("story_archive_sealed")
			if msg == "story_archive_sealed":
				msg = "旧卷已封存。这些模板章不再作为主线，也不再重玩。"
			_set_body(msg)
			_speaker.text = "老旗手"
			_hint.text = msg
	return ""

func _adjust(row: Dictionary) -> void:
	GameState.silver = maxi(0, GameState.silver + int(row.get("silver", 0)))
	GameState.food = maxi(0, GameState.food + int(row.get("food", 0)))
	GameState.morale = clampi(GameState.morale + int(row.get("morale", 0)), 0, 100)
	var rep = row.get("reputation", {})
	if typeof(rep) == TYPE_DICTIONARY:
		for realm in rep.keys():
			GameState.reputation[str(realm)] = int(GameState.reputation.get(str(realm), 0)) + int(rep[realm])
	var note := str(row.get("log", ""))
	if note != "":
		GameState.log_event(note)
	GameState.mark_dirty()

## Brief-guide path: hire the cheapest stranger the purse covers, without the tavern screen.
func _auto_recruit() -> void:
	if GameState.flag("recruited"):
		return
	if GameState.tavern_candidates.is_empty():
		GameState.refresh_tavern()
	var best: CKCharacter = null
	var best_cost := 1 << 30
	for c in GameState.tavern_candidates:
		var cost := CKEconomyState.recruit_price(GameState, c)
		if cost < best_cost:
			best = c
			best_cost = cost
	if best == null:
		_hint.text = Locale.t("pro_auto_recruit_none")
		return
	if GameState.silver < best_cost:
		GameState.silver = best_cost
	var r: Dictionary = GameState.recruit(best, best_cost)
	_hint.text = str(r.get("msg", ""))
	test_capture["auto_recruit"] = bool(r.get("ok", false))

## Brief-guide path: the first candidate who can accept a trial seat.
func _auto_marry() -> void:
	if GameState.flag("married"):
		return
	var leader = GameState.get_leader()
	if leader == null:
		return
	GameState.refresh_marriage_candidates()
	for c in GameState.marriage_candidates:
		if Lineage.can_propose(leader, c).get("ok", false):
			GameState.silver = maxi(GameState.silver, 40)
			var r: Dictionary = Lineage.marry(leader, c, 40)
			_hint.text = str(r.get("msg", ""))
			test_capture["auto_marry"] = bool(r.get("ok", false))
			return
	_hint.text = Locale.t("pro_auto_marry_none")

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
	var lines: Array = _visible_lines()
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
