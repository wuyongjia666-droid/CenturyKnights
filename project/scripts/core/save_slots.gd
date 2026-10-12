class_name CKSaveSlots
extends Control
## Load-game list. Continue on the main menu uses the newest slot.

const SCENE := "res://scenes/ui/save_slots.tscn"

static func latest_slot() -> String:
	var best := ""
	var best_time := -1
	for slot in CKSaveService.SLOTS:
		var path := CKSaveService.body_path(slot)
		if not FileAccess.file_exists(path):
			continue
		var modified := int(FileAccess.get_modified_time(path))
		if modified >= best_time:
			best_time = modified
			best = slot
	return best

static func continue_line(slot: String) -> String:
	if slot == "":
		return Locale.t("menu_no_save")
	if not FileAccess.file_exists(CKSaveService.body_path(slot)):
		return Locale.t("menu_slot_empty")
	var meta := CKSaveService.read_meta(slot)
	if meta.is_empty():
		return Locale.t("menu_slot_empty")
	var leader := Locale.latin(str(meta.get("leader", "")), "Leader")
	return Locale.t("menu_continue_summary", [
		leader,
		int(meta.get("year", 1)),
		int(meta.get("month", 1)),
		int(meta.get("chapter", 0)),
	])

static func enter_loaded(tree: SceneTree) -> void:
	UnitArt.clear_cache()
	if GameState.flag("hub_open") or GameState.chapter0_beat >= "0.3":
		CKNav.home()
	else:
		CKNav.replace("res://scenes/story/chapter0.tscn")

var _msg: Label
var _loading := false

func _ready() -> void:
	_build()
	UIFX.fade_in(self, 0.25)
	UIFX.wire_tree(self)

## Audit #10: one card per slot — crest, house, chapter, in-game date, real time, play time.
## Empty slots say 空 and cannot be tapped; an unreadable slot says so.
static func card_info(slot: String) -> Dictionary:
	var path := CKSaveService.body_path(slot)
	if not FileAccess.file_exists(path):
		return {"state": "empty"}
	var meta := CKSaveService.read_meta(slot)
	if meta.is_empty():
		return {"state": "broken"}
	var t := int(meta.get("saved_unix", 0))
	if t <= 0:
		t = int(FileAccess.get_modified_time(path))
	var secs := int(meta.get("play_seconds", 0))
	return {
		"state": "ok",
		"house": str(meta.get("surname", "")),
		"leader": str(meta.get("leader", "")),
		"chapter": int(meta.get("chapter", 0)),
		"year": int(meta.get("year", 1)),
		"month": int(meta.get("month", 1)),
		"when": Time.get_datetime_string_from_unix_time(t + _tz_bias(), true).substr(0, 16) if t > 0 else "",
		"play": Locale.t("a1_slot_play") % [secs / 3600, (secs / 60) % 60],
		"banner": meta.get("banner_spec", {}),
	}

static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func _build() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, Locale.t("menu_load"), [], Locale.t("slot_back"), _back)
	_msg = UIKit.body_label("", UIKit.DANGER, 14)
	_msg.name = "SlotMsg"
	_msg.position = Vector2(48, 64)
	_msg.size = Vector2(1184, 22)
	add_child(_msg)
	var scroll := ScrollContainer.new()
	scroll.name = "SlotScroll"
	scroll.position = Vector2(48, 92)
	scroll.size = Vector2(1184, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "SlotColumn"
	col.custom_minimum_size = Vector2(1184, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	var any := false
	for slot in CKSaveService.SLOTS:
		var card := _card(str(slot))
		col.add_child(card)
		any = any or card.get_meta("state") == "ok"
	if not any:
		_msg.text = Locale.t("a1_slot_none")
		_msg.add_theme_color_override("font_color", UIKit.TEXT_DIM)

func _card(slot: String) -> PanelContainer:
	var info := card_info(slot)
	var st := str(info.state)
	var p := PanelContainer.new()
	p.name = "SlotRow_%s" % slot
	p.set_meta("state", st)
	p.custom_minimum_size = Vector2(1184, 104)
	p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.03 if st == "ok" else 0.012), Color(1, 1, 1, 0.10 if st == "ok" else 0.05), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	p.add_child(row)
	var crest := TextureRect.new()
	crest.custom_minimum_size = Vector2(64, 88)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if st == "ok" and info.banner is Dictionary and not (info.banner as Dictionary).is_empty():
		crest.texture = UnitArt.banner_layers(info.banner, 64, 88)
	crest.modulate = Color(1, 1, 1, 1.0 if st == "ok" else 0.2)
	row.add_child(crest)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(txt)
	var head := UIKit.title_label(Locale.t("slot_%s" % slot), 18, UIKit.TEXT if st == "ok" else UIKit.TEXT_FAINT)
	txt.add_child(head)
	var line := ""
	match st:
		"empty":
			line = Locale.t("a1_slot_empty")
		"broken":
			line = Locale.t("a1_slot_broken")
		_:
			line = Locale.t("a1_slot_line") % [Locale.latin(str(info.house), "House"), Locale.latin(str(info.leader), "Leader"), int(info.chapter), int(info.year), int(info.month)]
	var l1 := UIKit.body_label(line, UIKit.TEXT_DIM if st == "ok" else UIKit.TEXT_FAINT, 15)
	l1.name = "Line"
	txt.add_child(l1)
	if st == "ok":
		txt.add_child(UIKit.body_label(Locale.t("a1_slot_when") % [str(info.when), str(info.play)], UIKit.TEXT_FAINT, 13))
	var load_word := Locale.t("a1_slot_empty_btn") if st == "empty" else Locale.t("menu_load")
	var load := UIKit.make_accent_button(Locale.t("menu_load"), 160) if st == "ok" else UIKit.make_button(load_word, 160)
	load.name = "Load_%s" % slot
	load.custom_minimum_size = Vector2(160, 48)
	load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load.disabled = st == "empty"
	load.pressed.connect(_load.bind(slot))
	row.add_child(load)
	return p

func _load(slot: String) -> void:
	if _loading:
		return
	_loading = true
	if GameState.load_from_slot(slot):
		enter_loaded(get_tree())
		return
	_loading = false
	_msg.text = Locale.t("a1_slot_fail")
	_msg.add_theme_color_override("font_color", UIKit.DANGER)
	Sfx.miss()

func _back() -> void:
	CKNav.replace(CKNav.TITLE)
