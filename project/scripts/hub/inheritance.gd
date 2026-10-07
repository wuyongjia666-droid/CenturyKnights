extends Control
## 嗣位冲突：互动抉择场景（偏武/偏文/偏商继承人旁注 vs 朔影家）

var _body: RichTextLabel
var _actions: VBoxContainer
var _msg: Label
var _step: int = 0
var _heir: CKCharacter
var _choice: String = ""

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	var t = UIKit.make_label("嗣位冲突 · 继承权旁注", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var panel = UIKit.make_panel()
	panel.position = Vector2(80, 90)
	panel.custom_minimum_size = Vector2(1120, 480)
	add_child(panel)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.custom_minimum_size = Vector2(1080, 300)
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	panel.add_child(_body)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(20, 320)
	_actions.add_theme_constant_override("separation", 10)
	panel.add_child(_actions)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 590)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	var rivals = UIKit.make_button("回敌宅", 120)
	rivals.position = Vector2(180, 640)
	rivals.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/rival_houses.tscn"))
	add_child(rivals)
	_pick_heir()
	_show()

func _pick_heir() -> void:
	_heir = null
	for ch in GameState.characters.values():
		if ch.alive and (ch.is_child or GameState.lineage_path.has(ch.id)):
			if ch.age >= 10:
				_heir = ch
				break
	if _heir == null:
		_heir = GameState.get_leader()

func _clear_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()

func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 520)
	b.pressed.connect(cb)
	_actions.add_child(b)

func _show() -> void:
	_clear_actions()
	var hname = _heir.name if _heir else "（无嗣）"
	var path = str(GameState.lineage_path.get(_heir.id, "")) if _heir else ""
	var pn = {"martial": "偏武", "scholar": "偏文", "merchant": "偏商"}.get(path, "未择路")
	match _step:
		0:
			_body.text = "[b]朔影家来使[/b]\n\n「灰旗既可执宴，就该公开嗣位旁注。」\n当前焦点人物：%s（道路：%s）\n\n他们要你们在三种回应里选一条——都会写入族谱纪事。" % [hname, pn]
			_add("强硬：以战技与旗印压场", func(): _choice = "steel"; _step = 1; _show())
			_add("怀柔：承认并席、交换旁注", func(): _choice = "soft"; _step = 1; _show())
			_add("回避：推迟到第十三章对决", func(): _choice = "delay"; _step = 1; _show())
		1:
			match _choice:
				"steel":
					_body.text = "[b]强硬回应[/b]\n\n厅上旗印砸案。朔影家退半步，却记下仇恨。\n效果：灰烬声望+3；朔影立场若非并席则趋向对峙；开战准备度上升。"
					_add("落定强硬旁注", func(): _resolve())
				"soft":
					_body.text = "[b]怀柔回应[/b]\n\n双姓共席文书草签。偏商子嗣更易被灯市会接受。\n效果：银-20；朔影→对峙/中立；清河好感。"
					_add("落定怀柔旁注", func(): _resolve())
				"delay":
					_body.text = "[b]回避回应[/b]\n\n「对决书上见。」余波推到旷野。\n效果：战技点+1；建议尽快打第十三章嗣位对决。"
					_add("落定回避旁注", func(): _resolve())
			_add("返回重选", func(): _step = 0; _show())

func _resolve() -> void:
	match _choice:
		"steel":
			GameState.add_rep("ashland", 3)
			if GameState.get_rival_stance("shuoying") == "hostile":
				GameState.set_rival_stance("shuoying", "wary")
			GameState.add_lineage_event("嗣位冲突：强硬压场（%s）" % (_heir.name if _heir else "?"))
			_msg.text = "强硬旁注已写。可回主线推进战役。"
		"soft":
			if GameState.silver >= 20:
				GameState.silver -= 20
			GameState.set_rival_stance("shuoying", "neutral" if GameState.get_rival_stance("shuoying") != "hostile" else "wary")
			GameState.set_rival_stance("qinghe", "cordial")
			GameState.add_lineage_event("嗣位冲突：怀柔并席草签")
			_msg.text = "怀柔旁注已写。清河宅改为并席。"
		"delay":
			GameState.add_skill_point(1)
			GameState.add_lineage_event("嗣位冲突：推迟至对决")
			_msg.text = "回避旁注已写。战技点+1。请打第十三章。"
	Sfx.lineage_chime()
	GameState.save_game()
	_step = 0
	_clear_actions()
	_add("再议一轮", func(): _show())
	_add("回堡", func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
