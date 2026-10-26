extends Node
## Fat deepen: party panel uses seal_bypass_chip (locale + API).

const ORIGIN := "sy_capital"
const DEST := "sy_ridge"

var fails: Array = []

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	await get_tree().process_frame
	await run_all()

func run_all() -> void:
	_api_locale_and_chip()
	if fails.is_empty():
		print("PARTY SEAL ROW PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL party seal row: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func _api_locale_and_chip() -> void:
	GameState.new_game("侧栏旁路", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	Calendar.year = 1
	Calendar.month = 1
	World.day = 1
	World.pos = ORIGIN
	World.travel = {}
	World.march_hold = {}
	World.seal_detour = {}
	_ok(Locale.t("atlas_chip_seal_bypass") != "atlas_chip_seal_bypass", "locale bypass")
	_ok(Locale.t("atlas_chip_seal_days") % 3 != "", "locale days")
	_ok(not bool(World.seal_bypass_chip().get("show", false)), "hidden baseline")
	var cmp: Dictionary = CKRoadSeal.compare(DEST)
	var path: Array = cmp.get("detour", {}).get("path", [])
	_ok(CKRoadSeal.seal_active() and path.size() >= 3, "detour")
	if path.size() < 3:
		return
	World.note_seal_detour(DEST, path)
	World.hold_march(DEST)
	GameState.food = World.food_per_day() * 20
	var c: Dictionary = World.seal_bypass_chip()
	_ok(bool(c.get("show", false)), "chip show for party row")
	_ok(int(c.get("seal_need", 0)) > 0, "seal_need")
