extends Node
## CORE-08: one battle and one month land in the local stats file.

const HUB := "res://scenes/hub/castle_hub.tscn"

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	CKPlayStats.reset()
	CKPlayStats.set_tracking(false)
	CKPlayStats.add_time(15.0, HUB)
	CKPlayStats.add_time(3.0, "res://scenes/battle/battle.tscn")
	var dummy := DummyBattle.new()
	add_child(dummy)
	dummy.battle_finished.emit({})
	Calendar.advance(1)
	await get_tree().process_frame
	Calendar.advance(3)
	await get_tree().process_frame
	CKPlayStats.flush()
	var raw = JSON.parse_string(FileAccess.get_file_as_string(CKPlayStats.PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		_fails.append("stats file missing")
	else:
		_eq(int(raw.get("battles", 0)), 1, "battles")
		_eq(int(raw.get("battle_turns", 0)), 6, "battle turns")
		_eq(int(raw.get("months", 0)), 4, "months")
		_eq(int(raw.get("month_skips", 0)), 1, "month skips")
		if not is_equal_approx(float(raw.get("total_seconds", 0.0)), 18.0):
			_fails.append("total seconds %s" % str(raw.get("total_seconds")))
		var hubs: Dictionary = raw.get("hub_seconds", {})
		if not is_equal_approx(float(hubs.get(HUB, 0.0)), 15.0):
			_fails.append("hub seconds %s" % str(hubs))
		if hubs.has("res://scenes/battle/battle.tscn"):
			_fails.append("battle scene counted as a hub")
	var exported := CKPlayStats.export_json()
	var exp = JSON.parse_string(FileAccess.get_file_as_string(exported))
	if typeof(exp) != TYPE_DICTIONARY:
		_fails.append("export missing")
	else:
		if not is_equal_approx(float(exp.get("battle_turns_avg", 0.0)), 6.0):
			_fails.append("average turns")
		if str(exp.get("title", "")) != Locale.t("playstats_title"):
			_fails.append("export title")
	var src := FileAccess.get_file_as_string("res://scripts/core/playstats.gd")
	for tok in ["HTTPRequest", "WebSocket", "PacketPeer", "http://", "https://"]:
		if src.find(tok) >= 0:
			_fails.append("network token %s" % tok)
	CKPlayStats.reset()
	if _fails.is_empty():
		print("PLAYSTATS PASS")
		get_tree().quit(0)
		return
	for f in _fails:
		print("FAIL playstats: ", f)
	get_tree().quit(1)

func _eq(got: int, want: int, label: String) -> void:
	if got != want:
		_fails.append("%s %d != %d" % [label, got, want])

class DummyBattle extends Node:
	signal battle_finished(result)
	var _round_no := 6
