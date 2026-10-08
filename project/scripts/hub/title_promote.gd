extends Control
## Merit ladder 勋士 → 侯. Progress uses CKCourt.requirement_rows; promote() is unchanged.

var _leader: CKCharacter
var _host: Control
var _msg: Label

func _ready() -> void:
	_leader = GameState.get_leader()
	UIKit.void_bg(self)
	UIKit.top_bar(self, "请爵", [["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	UIKit.page_head(self, 42, 72, "TITLE LADDER", "勋士至侯", "MERIT", "功勋、封地、婚约、邦交。升到伯爵时，烬图携因者的河图纹会醒。")
	_paint()
	UIKit.footer_bar(self, [["A", "请爵"], ["ESC", "返回城堡"]], "TITLE LADDER · FROST")
	UIFX.page_enter(self)

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _paint() -> void:
	if _host:
		_host.queue_free()
	_host = Control.new()
	_host.name = "Ladder"
	add_child(_host)
	var c := _leader
	var now := CKCourt.current_title(c)
	var step := HBoxContainer.new()
	step.position = Vector2(42, 168)
	step.add_theme_constant_override("separation", 8)
	_host.add_child(step)
	for id in CKCourt.LADDER:
		var on: bool = str(id) == now
		var done: bool = CKCourt.LADDER.find(str(id)) <= CKCourt.LADDER.find(now)
		var b := Button.new()
		b.text = CKCourt.ladder_zh(str(id))
		b.custom_minimum_size = Vector2(160, 64)
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = true
		var col: Color = UIKit.ACCENT if on else (UIKit.OK if done else UIKit.TEXT_FAINT)
		b.add_theme_stylebox_override("normal", UIKit.flat_box(Color(col, 0.12), col, 10, 2 if on else 1))
		b.add_theme_stylebox_override("disabled", UIKit.flat_box(Color(col, 0.12), col, 10, 2 if on else 1))
		b.add_theme_color_override("font_color", UIKit.TEXT)
		b.add_theme_color_override("font_disabled_color", UIKit.TEXT)
		b.add_theme_font_size_override("font_size", 18)
		step.add_child(b)
	var grid := HBoxContainer.new()
	grid.position = Vector2(42, 260)
	grid.add_theme_constant_override("separation", 12)
	_host.add_child(grid)
	for row in CKCourt.requirement_rows(c, {}):
		grid.add_child(_req_card(row))
	if CKCourt.requirement_rows(c, {}).is_empty():
		grid.add_child(UIKit.body_label("爵位已到侯爵。", UIKit.OK, 16))
	_msg = UIKit.body_label("", UIKit.TEXT_DIM, 14)
	_msg.position = Vector2(42, 470)
	_msg.size = Vector2(800, 48)
	_host.add_child(_msg)
	var block := CKCourt.promotion_block(c, {})
	_msg.text = block if block != "" else "四项都够，可以请下一阶。"
	var go := UIKit.cta_button("请爵", "A", 200, 44)
	go.name = "PromoteTitle"
	go.position = Vector2(42, 540)
	go.disabled = block != ""
	go.pressed.connect(_promote)
	_host.add_child(go)
	UIFX.wire_tree(_host)
	UIFX.stagger_children(step, 0.05, 0.2)

func _req_card(row: Dictionary) -> Control:
	var have := int(row.get("have", 0))
	var need := int(row.get("need", 0))
	var ok := need <= 0 or have >= need
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(280, 120)
	p.add_theme_stylebox_override("panel", UIKit.glass(12, 0.8, ok))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIKit.mono(str(row.get("label", "")), 11, UIKit.TEXT_FAINT, false))
	var num := UIKit.title_label("%d / %d" % [have, need], 28, UIKit.OK if ok else UIKit.TEXT)
	v.add_child(num)
	v.add_child(UIKit.slim_bar(float(have), float(maxi(need, 1)), UIKit.OK if ok else UIKit.ACCENT, 240, 6))
	p.name = "Req" + str(row.get("id", "")).capitalize()
	return p

func _promote() -> void:
	if _leader == null:
		return
	var r := CKCourt.promote(_leader)
	_msg.text = str(r.get("msg", ""))
	if bool(r.get("ok", false)):
		Sfx.confirm()
		Sfx.lineage_chime()
		UIFX.confirm_burst(_msg)
		_paint()
	else:
		Sfx.play("ui_click")
		UIFX.soft_deny(_msg)
