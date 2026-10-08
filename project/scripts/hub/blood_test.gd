extends Control
## Shrine blood test: queue, staggered reveal, impostor exposure. The verify call is unchanged.

var _stage: Control
var _status: Label
var _pending: Array = []
var _lines: Array = []
var _reveal_i := 0
var _busy := false

func _ready() -> void:
	_pending = _queue()
	UIKit.void_bg(self)
	var cost := CKBloodline.verify_cost(GameState.building_level("shrine"))
	UIKit.top_bar(self, "祠堂验血", [["银币", str(GameState.silver), UIKit.ACCENT], ["每人", "%d 银" % cost, UIKit.TEXT_DIM]], "返回祠堂", _back)
	UIKit.page_head(self, 42, 72, "SANCTUARY // BLOOD ASSAY", "验血", "REVEAL", "一次验明尚未入册的族人。潜征展开，伪胤在灯下现形。", "", 18)
	var left := UIKit.panel_at(self, Rect2(42, 200, 420, 476), 12)
	left.name = "AssayQueue"
	var cap := UIKit.mono("QUEUE · %d" % _pending.size(), 9, UIKit.TEXT_FAINT)
	cap.position = Vector2(16, 14)
	left.add_child(cap)
	var queue_scroll := ScrollContainer.new()
	queue_scroll.position = Vector2(16, 40)
	queue_scroll.size = Vector2(388, 360)
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(queue_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(360, 0)
	list.add_theme_constant_override("separation", 8)
	queue_scroll.add_child(list)
	if _pending.is_empty():
		list.add_child(UIKit.empty_state("族中人人都已验过血。"))
	for c in _pending:
		var row := UIKit.body_label("%s · %s · %d岁" % [c.name, c.rank_name(), c.age], UIKit.TEXT, 14)
		row.custom_minimum_size = Vector2(360, 28)
		list.add_child(row)
	var begin := UIKit.cta_button("开始验血", "A", 220, 44)
	begin.name = "BeginReveal"
	begin.position = Vector2(16, 416)
	var affordable := not _pending.is_empty() and GameState.silver >= cost
	begin.disabled = not affordable
	begin.tooltip_text = "银币不足" if not _pending.is_empty() and not affordable else ""
	begin.pressed.connect(_begin)
	left.add_child(begin)
	var right := UIKit.panel_at(self, Rect2(478, 200, 760, 476), 12, true)
	right.name = "RevealStage"
	var rh := UIKit.mono("REVEAL", 9, UIKit.ACCENT)
	rh.position = Vector2(18, 14)
	right.add_child(rh)
	_status = UIKit.body_label("灯还没点。按下开始之后，结果会一张一张掀开。", UIKit.TEXT_DIM, 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.position = Vector2(18, 40)
	_status.size = Vector2(720, 40)
	right.add_child(_status)
	_stage = VBoxContainer.new()
	_stage.name = "RevealCards"
	_stage.position = Vector2(18, 88)
	_stage.size = Vector2(724, 400)
	_stage.add_theme_constant_override("separation", 8)
	right.add_child(_stage)
	UIKit.footer_bar(self, [["A", "开始验血"], ["ESC", "返回祠堂"]], "SANCTUARY ASSAY · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/shrine.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _queue() -> Array:
	var out: Array = []
	for c in GameState.characters.values():
		if c.alive and (c.in_roster or c.is_leader or c.spouse_id != "" or c.is_child) and not bool(c.blood_meta.get("verified", false)):
			out.append(c)
	return out

func _begin() -> void:
	if _busy:
		return
	var r: Dictionary = GameState.verify_bloodlines_at_shrine()
	_status.text = str(r.get("msg", ""))
	if not bool(r.get("ok", false)):
		Sfx.play("ui_click")
		UIFX.soft_deny(_status)
		return
	_busy = true
	_lines = r.get("lines", [])
	_reveal_i = 0
	Sfx.play("incense_hiss")
	_next_card()

func _next_card() -> void:
	if _reveal_i >= _lines.size():
		_status.text = "验血结束。伪胤已改回真实血脉，详档可以打开携因。"
		Sfx.confirm()
		_busy = false
		return
	var text := str(_lines[_reveal_i])
	_reveal_i += 1
	var impostor := text.find("伪") >= 0
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 56)
	card.modulate.a = 0.0
	if impostor:
		card.name = "ImpostorReveal"
	card.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.DANGER, 0.16) if impostor else Color(UIKit.OK, 0.08), UIKit.DANGER if impostor else Color(UIKit.OK, 0.45), 10, 2 if impostor else 1))
	var lab := UIKit.body_label(("伪胤揭穿 · " if impostor else "验明 · ") + text, UIKit.DANGER if impostor else UIKit.TEXT, 14)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(lab)
	_stage.add_child(card)
	UIFX.fade_in(card, 0.22)
	if impostor:
		UIFX.shake_control(card, 8.0, 0.28)
		Sfx.play("paper_tear")
	else:
		Sfx.lineage_chime()
	var tw := create_tween()
	tw.tween_interval(0.45 if not UIFX.reduced() else 0.05)
	tw.tween_callback(_next_card)
