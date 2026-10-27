class_name CKTodoCenter
extends RefCounted
## UX-06：本月待办注册表。各领域用 register() 追加事项，城堡只读 snapshot()。
## 主线读 CKStoryState 的节拍，场景路径交给 StoryCatalog。

static var _extra: Array = []
static var _mainline_cache: Array = []

static func reset_for_tests() -> void:
	_extra.clear()

static func register(category: String, group: String, label: String, count: int, link: String = "") -> void:
	_extra.append({
		"category": category,
		"group": group,
		"label": label,
		"count": count,
		"link": link,
	})

## UX T4: each chip opens the thing itself. Rows without a link (or a missing scene) stay plain chips.
const LINKS := {
	"quests": "res://scenes/hub/quests.tscn",
	"injured": "res://scenes/hub/roster.tscn",
	"sui_ke": "res://scenes/hub/sui_yearcard.tscn",
	"territory_threat": "res://scenes/hub/atlas_view.tscn",
	"stockade_credit": "res://scenes/hub/territory_ledger.tscn",
	"territory_reclaim": "res://scenes/hub/atlas_view.tscn",
	"territory_unrest": "res://scenes/hub/territory_ledger.tscn",
}


## Before CKNav.go on a chip: re-queue siege alert / focus reclaim atlas site.
static func prepare_nav(item: Dictionary) -> void:
	var cat := str(item.get("category", ""))
	if cat == "territory_threat":
		CKTerritory.hub_requeue_siege_alert()
	elif cat == "territory_reclaim":
		CKTerritory.hub_focus_reclaim()

static func link_for(item: Dictionary) -> String:
	var link := str(item.get("link", ""))
	if link == "" or not ResourceLoader.exists(link):
		return ""
	return link

static func is_unlocked(entry: String) -> bool:
	# NAR-05 的日程。未知入口仍是锁上的。
	UnlockSchedule.install()
	return UnlockSchedule.allows(entry)

static func narrow_scale(width: float) -> float:
	if width >= 1200.0 or width < 64.0:
		return 1.0
	return width / 1280.0

static func count_for(group_id: String) -> int:
	var n := 0
	for item in snapshot():
		if str(item.get("group", "")) == group_id:
			n += maxi(0, int(item.get("count", 0)))
	return n

## Proposal §4.9 (audit P1-1): count only what has a deadline, is unread, or blocks the way.
## Catalog length, unfinished works, suitor count and hp below max are not to-dos.
## Locked entries never count. Works and pledges finish on the spot in this build, so they have no row.
static func snapshot() -> Array:
	var rows: Array = []
	if is_unlocked("quests"):
		rows.append(_row("quests", "civil", Locale.t("ux_todo_quests"), _quest_count()))
	rows.append(_row("injured", "military", Locale.t("ux_todo_injured"), _injured_count()))
	rows.append(_row("festival", "home", Locale.t("ux_todo_festival"), _festival_count()))
	rows.append(_row("sui_ke", "family", Locale.t("ux_todo_sui_ke"), CKSuiKe.inbox_count()))
	var threat_n := CKTerritory.threatened_owned().size()
	if threat_n > 0:
		var row := _row("territory_threat", "military", Locale.t("ux_todo_territory_threat"), threat_n)
		row["severity"] = "block"
		rows.append(row)
	var credit_n := CKTerritory.stockade_credit_count()
	if credit_n > 0:
		rows.append(_row("stockade_credit", "military", Locale.t("ux_todo_stockade_credit"), credit_n))
	# §21 lost→reclaim commission still open — castle chip deep-links atlas focus.
	var reclaim_n := CKTerritory.pending_reclaim_ids().size()
	if reclaim_n > 0:
		var rrow := _row("territory_reclaim", "military", Locale.t("ux_todo_territory_reclaim"), reclaim_n)
		rrow["urgency"] = "block"
		rows.append(rrow)
	# §22 民心未附 — castle chip deep-links territory ledger for 安抚.
	var unrest_n := CKTerritory.unrest_owned_ids().size()
	if unrest_n > 0:
		var urow := _row("territory_unrest", "military", Locale.t("ux_todo_territory_unrest"), unrest_n)
		urow["urgency"] = "block"
		rows.append(urow)
	var birth := _birth_todo()
	if not birth.is_empty():
		rows.append(birth)
	for extra in _extra:
		if extra is Dictionary:
			rows.append((extra as Dictionary).duplicate())
	return rows

static func _row(category: String, group: String, label: String, count: int) -> Dictionary:
	return {"category": category, "group": group, "label": label, "count": count, "link": str(LINKS.get(category, ""))}

## Castle battle contracts waiting to fight, plus in-hand world commissions on the atlas.
static func _quest_count() -> int:
	var n := World.active.size()
	if str(GameState.get_meta("active_quest_id", "")) != "":
		n += 1
	return n

static func any_due() -> bool:
	for item in snapshot():
		if int(item.get("count", 0)) > 0:
			return true
	return false

static func _injured_count() -> int:
	var n := 0
	for c in GameState.roster():
		if c.injured or not CKInjury.record(c).is_empty():
			n += 1
	return n

## Ch0 pregnancy wait: remind the player the child is coming and that mainline is still open.
static func _birth_todo() -> Dictionary:
	if GameState.flag("child_born") or GameState.flag("chapter0_done"):
		return {}
	var left := -1
	for c in GameState.characters.values():
		if c != null and c.alive and int(c.pregnant_months) >= 0:
			left = int(c.pregnant_months) if left < 0 else mini(left, int(c.pregnant_months))
	if left < 0:
		return {}
	var label := Locale.t("ux_todo_birth_soon") if left <= 1 else Locale.t("ux_todo_birth")
	return {
		"category": "birth",
		"group": "home",
		"label": label,
		"count": 1,
		"link": StoryCatalog.chapter0_scene(),
	}

static func _festival_count() -> int:
	var m := int(Calendar.month)
	if m == 3 or m == Calendar.SPRING_MONTH or m == Calendar.HARVEST_MONTH or m == 9:
		return 1
	return 0

static func mainline_rows() -> Array:
	if not _mainline_cache.is_empty():
		return _mainline_cache
	var built: Array = []
	for entry in StoryCatalog.mainline_entries():
		var path := str(entry.get("path", ""))
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		var beats: Array = data.get("beats", [])
		var last := ""
		if not beats.is_empty() and typeof(beats[beats.size() - 1]) == TYPE_DICTIONARY:
			last = str((beats[beats.size() - 1] as Dictionary).get("id", ""))
		var id := str(entry.get("id", ""))
		if StoryCatalog.is_content_season_id(id):
			continue
		built.append({
			"id": id,
			"title": str(entry.get("title", id)),
			"index": int(data.get("legacy_index", 0)),
			"last_beat": last,
			"era": _era_of(id),
		})
	built.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))
	_mainline_cache = built
	return _mainline_cache

static func mainline_target() -> Dictionary:
	var rows := mainline_rows()
	var story := _story()
	if rows.is_empty():
		return {"id": "ch0", "title": "", "index": 0, "era": 0, "place": 1, "done": false, "last_beat": ""}
	var place := 1
	for row in rows:
		if not _finished(row, story):
			var out: Dictionary = (row as Dictionary).duplicate()
			out["place"] = place
			out["done"] = false
			if story != null:
				out["story_chapter"] = story.current_chapter()
			return out
		place += 1
	var last: Dictionary = (rows[rows.size() - 1] as Dictionary).duplicate()
	last["place"] = rows.size()
	last["done"] = true
	if story != null:
		last["story_chapter"] = story.current_chapter()
	return last

static func _story() -> CKStoryState:
	return GameState.story as CKStoryState

static func _era_of(id: String) -> int:
	if id.length() >= 2 and id.begins_with("e") and id.substr(1, 1).is_valid_int():
		return int(id.substr(1, 1))
	return 0

static func _finished(row: Dictionary, story: CKStoryState) -> bool:
	# 第零章看旗标。其余章看 CKStoryState 里记下的最后一拍。
	if str(row.get("id", "")) == "ch0":
		return GameState.flag("chapter0_done")
	if story == null:
		return false
	var idx := int(row.get("index", 0))
	var beat := story.beat(idx)
	var last := str(row.get("last_beat", ""))
	if last == "" or beat == story.default_beat(idx):
		return false
	return beat == last
