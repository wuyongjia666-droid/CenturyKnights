class_name CKLifeInbox
extends RefCounted
## v9.2 成人重卡收件处：一次只处理一张 life_pending。

static func pending() -> Array:
	var raw = GameState.house_mods.get("life_pending", null)
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


static func next_card() -> Dictionary:
	var rows := pending()
	if rows.is_empty():
		return {}
	var row = rows[0]
	return row if typeof(row) == TYPE_DICTIONARY else {}


static func count() -> int:
	return pending().size()


static func resolve_top(option_id: String) -> Dictionary:
	var card := next_card()
	if card.is_empty():
		return {"ok": false, "msg": Locale.t("life_inbox_empty")}
	var cid := str(card.get("cid", card.get("char_id", "")))
	var eid := str(card.get("event_id", card.get("id", "")))
	if cid == "" or eid == "":
		_force_drop_corrupt()
		return {"ok": false, "msg": Locale.t("life_inbox_bad")}
	## CKLifeEvents.resolve 自己会从 pending 摘掉
	var ok: bool = CKLifeEvents.resolve(cid, eid, option_id)
	return {"ok": ok, "msg": Locale.t("life_inbox_ok") if ok else Locale.t("life_inbox_bad")}


static func _force_drop_corrupt() -> void:
	var rows := pending()
	if rows.is_empty():
		return
	rows.remove_at(0)
	GameState.house_mods["life_pending"] = rows
	GameState.mark_dirty()
