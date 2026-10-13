extends Control
## Shrine blood test (line B, audit #31). Left: who is waiting, the price and how many the
## purse covers, and the start button right under that. Right: results card by card.
## Done / nobody left / short of silver each say so. The verify call is unchanged.

var _stage: VBoxContainer
var _status: Label
var _begin_btn: Button
var _pending: Array = []
var _lines: Array = []
var _reveal_i := 0
var _busy := false

func _ready() -> void:
	_pending = _queue()
	var cost := CKBloodline.verify_cost(GameState.building_level("shrine"))
	CKPageKit.shell(self, Locale.t("lb_bt_ctx"), "BLOOD ASSAY", Locale.t("lb_bt_title"), Locale.t("lb_bt_desc"))
	var left := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 420, 512), "AssayQueue")
	CKPageKit.card_head(left, Locale.t("lb_bt_queue", [_pending.size()]), "QUEUE")
	var can := mini(_pending.size(), GameState.silver / maxi(1, cost))
	CKPageKit.stat(left, Vector2(18, 64), Locale.t("lb_bt_price"), Locale.t("lb_shrine_per_head", [cost]), UIKit.ACCENT)
	CKPageKit.stat(left, Vector2(210, 64), Locale.t("lb_bt_covers"), Locale.t("lb_people", [can]), UIKit.OK if can >= _pending.size() else UIKit.DANGER)
	_begin_btn = CKPageKit.button(Locale.t("lb_bt_go"), true, 384)
	_begin_btn.name = "BeginReveal"
	_begin_btn.position = Vector2(18, 118)
	var why := ""
	if _pending.is_empty():
		why = Locale.t("lb_bt_all_done")
	elif can <= 0:
		why = Locale.t("lb_short_silver", [cost - GameState.silver])
	CKPageKit.lock(_begin_btn, why)
	_begin_btn.pressed.connect(_begin)
	left.add_child(_begin_btn)
	var list := CKPageKit.list(left, Rect2(14, 178, 392, 320), "QueueList")
	if _pending.is_empty():
		list.add_child(CKPageKit.empty(Locale.t("lb_bt_all_done"), Locale.t("lb_bt_all_done_why"), "", 360))
	for i in _pending.size():
		var c: CKCharacter = _pending[i]
		var r := CKPageKit.row(UIKit.OK if i < can else UIKit.TEXT_FAINT, 52)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		(r[1] as VBoxContainer).add_child(h)
		var pr := UIKit.make_portrait_rect(c, 36)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pr)
		var said := Locale.t("lb_bt_row", [c.name, c.rank_name(), c.age]) + ("" if i < can else Locale.t("lb_bt_wait_money"))
		h.add_child(CKPageKit.text(said, UIKit.TEXT if i < can else UIKit.TEXT_DIM, 14, 300))
		list.add_child(r[0])
	CKPageKit.drag_through(list)
	var right := CKPageKit.card(self, Rect2(478, CKPageKit.TOP + 8, 760, 512), "RevealStage", true)
	CKPageKit.card_head(right, Locale.t("lb_bt_result"), "REVEAL")
	_status = CKPageKit.text(Locale.t("lb_bt_idle") if not _pending.is_empty() else Locale.t("lb_bt_idle_done"), UIKit.TEXT_DIM, 14, 720)
	_status.name = "RevealStatus"
	_status.position = Vector2(18, 58)
	_status.size = Vector2(720, 40)
	right.add_child(_status)
	_stage = CKPageKit.list(right, Rect2(14, 104, 732, 394), "RevealCards")
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "SANCTUARY ASSAY · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

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
		_status.add_theme_color_override("font_color", UIKit.DANGER)
		UIFX.soft_deny(_status)
		UIFX.haptic(8)
		return
	_busy = true
	CKPageKit.clear(_stage)
	CKPageKit.lock(_begin_btn, Locale.t("lb_bt_running"))
	_lines = r.get("lines", [])
	_reveal_i = 0
	Sfx.play("incense_hiss")
	UIFX.confirm(_begin_btn)
	_next_card()

func _next_card() -> void:
	if _reveal_i >= _lines.size():
		_status.text = Locale.t("lb_bt_done")
		_status.add_theme_color_override("font_color", UIKit.OK)
		Sfx.confirm()
		_busy = false
		var left := _queue().size()
		CKPageKit.lock(_begin_btn, "" if left > 0 else Locale.t("lb_bt_all_done"))
		return
	var text := str(_lines[_reveal_i])
	_reveal_i += 1
	var impostor := text.find(Locale.t("lb_bt_fake_mark")) >= 0
	var r := CKPageKit.row(UIKit.DANGER if impostor else UIKit.OK, 56)
	var card: PanelContainer = r[0]
	card.modulate.a = 0.0
	if impostor:
		card.name = "ImpostorReveal"
	var head := Locale.t("lb_bt_fake") if impostor else Locale.t("lb_bt_ok")
	(r[1] as VBoxContainer).add_child(CKPageKit.text(head + text, UIKit.DANGER if impostor else UIKit.TEXT, 14, 690))
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
