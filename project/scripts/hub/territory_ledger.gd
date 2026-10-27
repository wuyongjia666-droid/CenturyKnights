extends Control
## Territory Ledger (P1-UX-04 / design §19–§21) — owned sites whole-chain:
## list · yield/garrison/threat · remote reinforce · siege alert · atlas · free stockade · reclaim.

const _MAX_LIST := 48

var _list: ItemList
var _detail: RichTextLabel
var _btn_reinforce: Button
var _btn_alert: Button
var _btn_atlas: Button
var _btn_stockade: Button
var _msg: Label
var _empty: Label
var _credit: Label
var _reclaim: Label
var _btn_reclaim: Button
var _ids: Array = []
var _pick := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.void_bg(self)
	Music.play_castle()
	UIKit.top_bar(self, Locale.t("ux_territory_title"), UIKit.std_resource_chips(), Locale.t("ux_territory_back"), func(): CKNav.up())
	UIKit.page_head(self, 42, 70, "TERRITORY LEDGER // HOLDINGS", Locale.t("ux_territory_title"), "OWNED SITES · THREAT · GARRISON")
	_build()
	_refresh()
	UIKit.footer_bar(self, [
		["A", Locale.t("ux_territory_reinforce")],
		["X", Locale.t("ux_territory_alert")],
		["Y", Locale.t("ux_territory_goto_atlas")],
		["ESC", Locale.t("ux_territory_back")],
	], "TERRITORY PROTOCOL · FROST_TACTICAL")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	call_deferred("_focus_first")


func _build() -> void:
	var hint := UIKit.body_label(Locale.t("ux_territory_hint"), UIKit.TEXT_DIM, 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(42, 118)
	hint.size = Vector2(1196, 28)
	add_child(hint)

	_credit = UIKit.body_label("", UIKit.OK, 13)
	_credit.name = "TerritoryCreditBanner"
	_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credit.position = Vector2(42, 148)
	_credit.size = Vector2(980, 24)
	_credit.visible = false
	add_child(_credit)

	_reclaim = UIKit.body_label("", UIKit.EMBER, 13)
	_reclaim.name = "TerritoryReclaimBanner"
	_reclaim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reclaim.position = Vector2(42, 172)
	_reclaim.size = Vector2(980, 24)
	_reclaim.visible = false
	add_child(_reclaim)

	_btn_reclaim = UIKit.cta_button(Locale.t("ux_territory_reclaim_goto"), "R", 160, 28)
	_btn_reclaim.name = "TerritoryReclaimGoto"
	_btn_reclaim.position = Vector2(1040, 168)
	_btn_reclaim.size = Vector2(160, 28)
	_btn_reclaim.visible = false
	_btn_reclaim.pressed.connect(_on_reclaim_goto)
	add_child(_btn_reclaim)

	_empty = UIKit.body_label(Locale.t("ux_territory_empty"), UIKit.EMBER, 13)
	_empty.name = "TerritoryEmpty"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.position = Vector2(42, 200)
	_empty.size = Vector2(1196, 28)
	_empty.visible = false
	add_child(_empty)

	_list = ItemList.new()
	_list.name = "TerritoryList"
	_list.position = Vector2(42, 214)
	_list.size = Vector2(420, 396)
	_list.item_selected.connect(_on_pick)
	add_child(_list)

	_detail = RichTextLabel.new()
	_detail.name = "TerritoryDetail"
	_detail.bbcode_enabled = true
	_detail.fit_content = false
	_detail.scroll_active = true
	_detail.position = Vector2(480, 214)
	_detail.size = Vector2(760, 276)
	add_child(_detail)

	var acts := HBoxContainer.new()
	acts.name = "TerritoryActions"
	acts.position = Vector2(480, 500)
	acts.size = Vector2(760, 48)
	acts.add_theme_constant_override("separation", 10)
	add_child(acts)

	_btn_reinforce = UIKit.cta_button(Locale.t("ux_territory_reinforce"), "A", 160, 40)
	_btn_reinforce.name = "TerritoryReinforce"
	_btn_reinforce.pressed.connect(_on_reinforce)
	acts.add_child(_btn_reinforce)

	_btn_stockade = UIKit.ghost_button(Locale.t("ux_territory_stockade"), 140, 40)
	_btn_stockade.name = "TerritoryStockade"
	_btn_stockade.pressed.connect(_on_stockade)
	acts.add_child(_btn_stockade)

	_btn_alert = UIKit.cta_button(Locale.t("ux_territory_alert"), "X", 140, 40)
	_btn_alert.name = "TerritoryAlert"
	_btn_alert.pressed.connect(_on_alert)
	acts.add_child(_btn_alert)

	_btn_atlas = UIKit.ghost_button(Locale.t("ux_territory_goto_atlas"), 160, 40)
	_btn_atlas.name = "TerritoryGotoAtlas"
	_btn_atlas.pressed.connect(_on_atlas)
	acts.add_child(_btn_atlas)

	_msg = UIKit.body_label("", UIKit.OK, 12)
	_msg.name = "TerritoryMsg"
	_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	_msg.position = Vector2(42, 640)
	_msg.size = Vector2(1196, 20)
	add_child(_msg)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		CKNav.up()
		get_viewport().set_input_as_handled()


func _focus_first() -> void:
	if _list.item_count > 0:
		_list.select(0)
		_on_pick(0)
		_list.grab_focus()
	elif _btn_atlas:
		_btn_atlas.grab_focus()


func _refresh() -> void:
	_ids.clear()
	_list.clear()
	var credit_n := CKTerritory.stockade_credit_count()
	if credit_n > 0:
		_credit.text = Locale.t("ux_territory_credit_banner") % credit_n
		_credit.visible = true
	else:
		_credit.text = ""
		_credit.visible = false
	var reclaim_n := CKTerritory.pending_reclaim_ids().size()
	if reclaim_n > 0:
		_reclaim.text = Locale.t("ux_territory_reclaim_banner") % reclaim_n
		_reclaim.visible = true
		_btn_reclaim.visible = true
		_btn_reclaim.disabled = false
	else:
		_reclaim.text = ""
		_reclaim.visible = false
		_btn_reclaim.visible = false
	var owned: Array = CKTerritory.owned_ids()
	owned.sort()
	for id in owned:
		if _ids.size() >= _MAX_LIST:
			break
		_ids.append(str(id))
		_list.add_item(_row_label(str(id)))
	_empty.visible = _ids.is_empty()
	if _ids.is_empty():
		_pick = ""
		_detail.text = Locale.t("ux_territory_empty_detail")
		_btn_reinforce.disabled = true
		_btn_stockade.disabled = true
		_btn_alert.disabled = true
		_btn_atlas.disabled = true
		return
	var idx := 0
	if _pick != "":
		var found := _ids.find(_pick)
		if found >= 0:
			idx = found
	_list.select(idx)
	_on_pick(idx)


func _row_label(id: String) -> String:
	var s: Dictionary = CKTerritory.site(id)
	var nm := str(s.get("name", id))
	var th: Dictionary = CKTerritory.state(id).threat if typeof(CKTerritory.state(id).threat) == TYPE_DICTIONARY else {}
	var tag := ""
	if not th.is_empty():
		tag = " · " + Locale.t("ux_territory_tag_threat")
	elif int(CKTerritory.state(id).unrest) > 0:
		tag = " · " + Locale.t("ux_territory_tag_unrest")
	elif bool(CKTerritory.state(id).stockade):
		tag = " · " + Locale.t("ux_territory_tag_stockade")
	return "%s%s" % [nm, tag]


func _on_pick(idx: int) -> void:
	if idx < 0 or idx >= _ids.size():
		return
	_pick = str(_ids[idx])
	var s: Dictionary = CKTerritory.site(_pick)
	var st: Dictionary = CKTerritory.state(_pick)
	var th: Dictionary = st.threat if typeof(st.threat) == TYPE_DICTIONARY else {}
	var ys := int(s.get("yield_silver", s.get("yield", 0)))
	var gar := int(st.garrison)
	var unrest := int(st.unrest)
	var nation := str(s.get("nation", ""))
	var stockade := bool(st.stockade)
	var prev: Dictionary = CKTerritory.reinforce_preview(_pick)
	var cost := int(prev.get("cost", 0))
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % str(s.get("name", _pick)))
	lines.append(Locale.t("ux_territory_detail_meta") % [nation, ys, gar, unrest])
	if stockade:
		lines.append(Locale.t("ux_territory_detail_stockade"))
	else:
		lines.append(Locale.t("ux_territory_detail_no_stockade"))
	lines.append(Locale.t("ux_territory_detail_reinforce_cost") % cost)
	var sprev: Dictionary = CKTerritory.stockade_preview(_pick)
	if not stockade:
		if bool(sprev.get("credit", false)):
			lines.append(Locale.t("ux_territory_detail_stockade_free"))
		else:
			lines.append(Locale.t("ux_territory_detail_stockade_cost") % int(sprev.get("cost", 0)))
	if th.is_empty():
		lines.append(Locale.t("ux_territory_detail_calm"))
	else:
		var months := int(th.get("months", 0))
		var rival := str(th.get("rival", "?"))
		var scouted := bool(th.get("scouted", false))
		var bribed := bool(th.get("bribed", false))
		var phase := Locale.t("ux_territory_phase_imminent") if months >= 1 else Locale.t("ux_territory_phase_declared")
		lines.append(Locale.t("ux_territory_detail_threat") % [rival, months, phase])
		if scouted:
			lines.append(Locale.t("ux_territory_detail_scouted"))
		if bribed:
			lines.append(Locale.t("ux_territory_detail_bribed"))
	_detail.text = "\n".join(lines)
	_btn_reinforce.disabled = not bool(prev.get("craftable", false))
	var spick: Dictionary = CKTerritory.stockade_preview(_pick)
	_btn_stockade.disabled = not bool(spick.get("craftable", false))
	if bool(spick.get("credit", false)) and not stockade:
		_btn_stockade.text = Locale.t("ux_territory_stockade_free")
	else:
		_btn_stockade.text = Locale.t("ux_territory_stockade")
	_btn_alert.disabled = th.is_empty()
	_btn_atlas.disabled = str(s.get("anchor", "")) == ""


func _on_reinforce() -> void:
	if _pick == "":
		return
	var r: Dictionary = CKTerritory.reinforce(_pick)
	_msg.add_theme_color_override("font_color", UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	_msg.text = str(r.get("msg", ""))
	_refresh()


func _on_stockade() -> void:
	if _pick == "":
		return
	var r: Dictionary = CKTerritory.build_stockade(_pick)
	_msg.add_theme_color_override("font_color", UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	_msg.text = str(r.get("msg", ""))
	_refresh()


func _on_alert() -> void:
	if _pick == "":
		return
	var queued := CKTerritory.hub_requeue_siege_alert_site(_pick)
	if queued == "":
		_msg.add_theme_color_override("font_color", UIKit.DANGER)
		_msg.text = Locale.t("ux_territory_alert_fail")
		return
	# Same path as HubTodo chip: atlas consumes World.last_siege_alert → SiegeAlertModal.
	var s: Dictionary = CKTerritory.site(_pick)
	var anchor := str(s.get("anchor", ""))
	if anchor != "":
		GameState.set_meta("atlas_select", anchor)
	GameState.set_meta("atlas_territory_site", _pick)
	CKNav.go("res://scenes/hub/atlas_view.tscn", {"site": _pick})


func _on_atlas() -> void:
	if _pick == "":
		return
	var s: Dictionary = CKTerritory.site(_pick)
	var anchor := str(s.get("anchor", ""))
	if anchor == "":
		_msg.add_theme_color_override("font_color", UIKit.DANGER)
		_msg.text = Locale.t("ux_territory_atlas_fail")
		return
	GameState.set_meta("atlas_select", anchor)
	GameState.set_meta("atlas_territory_site", _pick)
	CKNav.go("res://scenes/hub/atlas_view.tscn", {"site": _pick})


func _on_reclaim_goto() -> void:
	var focused := CKTerritory.hub_focus_reclaim()
	if focused == "":
		_msg.add_theme_color_override("font_color", UIKit.DANGER)
		_msg.text = Locale.t("ux_territory_reclaim_fail")
		return
	CKNav.go("res://scenes/hub/atlas_view.tscn", {"site": focused})

