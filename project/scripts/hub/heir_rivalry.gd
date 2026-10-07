extends Control
## 双嗣校场：两名有道路的子嗣对决旁注，可开战或调解

var _body: RichTextLabel
var _actions: VBoxContainer
var _msg: Label
var _a: CKCharacter
var _b: CKCharacter
var _step: int = 0

func _ready() -> void:
	UIKit.make_themed_bg(self, "heir")
	if ResourceLoader.exists("res://assets/art/ui/heir_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/heir_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	if ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	UIFX.page_enter(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	UIFX.wire_tree(self)
	var t = UIKit.make_label("双嗣校场 · 多嗣rivalry", true)
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
	_pick()
	if GameState.flag("ch_heir_clash_done"):
		_msg.text = "校场战已结束。双方子嗣已回堡（血量恢复）。"
		GameState.set_flag("ch_heir_clash_done", false)
	_show()

func _path_cn(c: CKCharacter) -> String:
	if c == null:
		return "—"
	var p = str(GameState.lineage_path.get(c.id, ""))
	return {"martial": "偏武", "scholar": "偏文", "merchant": "偏商"}.get(p, "未择路")

func _pick() -> void:
	var heirs: Array = []
	for ch in GameState.characters.values():
		if not ch.alive:
			continue
		if ch.is_child or GameState.lineage_path.has(ch.id):
			if ch.age >= 8:
				heirs.append(ch)
	heirs.sort_custom(func(x, y): return x.age > y.age)
	_a = heirs[0] if heirs.size() > 0 else null
	_b = heirs[1] if heirs.size() > 1 else null

func _clear() -> void:
	for c in _actions.get_children():
		c.queue_free()

func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 520)
	b.pressed.connect(cb)
	_actions.add_child(b)

func _show() -> void:
	_clear()
	if _a == null:
		_body.text = "族谱中尚无足够年长的子嗣。联姻传代后再来校场。"
		_add("回堡", func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
		return
	if _b == null:
		_body.text = "[b]校场静悄悄[/b]\n\n目前只有 %s（%s，%d岁）。需要至少两名子嗣才会爆发道路争执。\n可为现有子嗣授旗择路，或等待更多诞育。" % [_a.name, _path_cn(_a), _a.age]
		_add("去授旗礼", func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_rite.tscn"))
		_add("回堡", func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
		return
	match _step:
		0:
			_body.text = "[b]双嗣争执[/b]\n\n%s（%s）与 %s（%s）在校场争执『谁更配写进执宴旁注』。\n\n可选：调解、支持其一、或开放校场对决战。" % [
				_a.name, _path_cn(_a), _b.name, _path_cn(_b)
			]
			_add("调解：各退一步（银-15，双方声望旁注）", func(): _mediate())
			_add("支持长嗣 %s" % _a.name, func(): _support(_a, _b))
			_add("支持次嗣 %s" % _b.name, func(): _support(_b, _a))
			_add("校场对决开战", func(): _battle())
		1:
			_add("再议", func(): _step = 0; _show())
			_add("回堡", func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))

func _mediate() -> void:
	if GameState.silver >= 15:
		GameState.silver -= 15
	GameState.add_lineage_event("双嗣调解：%s 与 %s 各退一步" % [_a.name, _b.name])
	GameState.add_rep("ashland", 1)
	_msg.text = "调解成功。校场暂息。"
	Sfx.lineage_chime()
	GameState.save_game()
	_step = 1
	_body.text = "[b]调解落定[/b]\n\n双嗣握手。旁注写『并立待择』。"
	_show()

func _support(win: CKCharacter, lose: CKCharacter) -> void:
	GameState.lineage_path[win.id] = str(GameState.lineage_path.get(win.id, "martial"))
	GameState.add_lineage_event("双嗣拥立：支持 %s，压过 %s" % [win.name, lose.name])
	GameState.add_skill_point(1)
	# grant path skills to winner if path set
	var path = str(GameState.lineage_path.get(win.id, ""))
	if path != "":
		var g = GameState.grant_path_skills(win, path)
		_msg.text = "拥立 %s。战技点+1。道路战技 %d 项。" % [win.name, g.size()]
	else:
		_msg.text = "拥立 %s。战技点+1。" % win.name
	Sfx.fanfare()
	GameState.save_game()
	_step = 1
	_body.text = "[b]拥立落定[/b]\n\n%s 暂写进执宴旁注优先位。%s 退居次席。" % [win.name, lose.name]
	_show()

func _battle() -> void:
	GameState.add_lineage_event("双嗣校场开战：%s vs %s（真人入阵）" % [_a.name, _b.name])
	GameState.set_meta("battle_return", "res://scenes/hub/heir_rivalry.tscn")
	GameState.set_meta("battle_map", "ch_heir_clash")
	GameState.set_meta("heir_clash_a", _a.id)
	GameState.set_meta("heir_clash_b", _b.id)
	# 确保至少临时可出战
	_a.hp = _a.max_hp
	_b.hp = _b.max_hp
	_a.alive = true
	_b.alive = true
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
