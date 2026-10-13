extends Control
## Read-only 岁课 inbox: title / body / which side happened / effect hint.
## No left/right buttons — birthday already auto-resolved from temperament.

var _list: VBoxContainer
var _msg: Label


func _ready() -> void:
	CKPageKit.shell(self, Locale.t("sui_year_ctx"), "YEAR CARD", Locale.t("sui_year_title"), Locale.t("sui_year_desc"))
	var panel := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 1196, 512), "SuiInbox")
	_list = CKPageKit.list(panel, Rect2(16, 16, 1164, 480), "SuiRows")
	_msg = CKPageKit.feedback(self)
	_fill()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "YEAR CARD · SUI")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)


func _fill() -> void:
	CKPageKit.clear(_list)
	var rows: Array = CKSuiKe.inbox()
	if rows.is_empty():
		_list.add_child(CKPageKit.empty(Locale.t("sui_year_empty"), Locale.t("sui_year_empty_why"), "", 1100))
		return
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_row(item)


func _row(item: Dictionary) -> void:
	var cid := str(item.get("cid", ""))
	var c: CKCharacter = GameState.characters.get(cid)
	var who := cid
	var age := 0
	if c != null:
		who = str(c.name)
		age = int(c.age)
	var r := CKPageKit.row(UIKit.ACCENT, 0)
	var box: VBoxContainer = r[1]
	box.add_child(UIKit.tag_chip(str(item.get("band", "sui")), UIKit.ACCENT))
	box.add_child(UIKit.title_label(str(item.get("title", "")), 18))
	box.add_child(CKPageKit.text(Locale.t("sui_year_who", [who, age]), UIKit.TEXT_DIM, 13, 1000))
	var body := str(item.get("body", ""))
	if body != "":
		box.add_child(CKPageKit.text(body, UIKit.TEXT, 15, 1000))
	var side := str(item.get("side", ""))
	var side_zh := Locale.t("sui_year_side_left") if side == "left" else (
		Locale.t("sui_year_side_right") if side == "right" else side
	)
	var outcome := str(item.get("outcome", ""))
	box.add_child(CKPageKit.text("%s · %s" % [side_zh, Locale.t("sui_year_outcome", [outcome])], UIKit.OK, 14, 1000))
	var eid := str(item.get("id", ""))
	var btn := CKPageKit.button(Locale.t("sui_year_ack"), true, 160)
	btn.pressed.connect(func(): _ack(cid, eid))
	box.add_child(btn)
	_list.add_child(r[0])


func _ack(cid: String, eid: String) -> void:
	Sfx.click()
	CKSuiKe.ack(cid, eid)
	CKPageKit.say(_msg, Locale.t("sui_year_ack"), true)
	_fill()


func nav_back() -> void:
	CKNav.up()
