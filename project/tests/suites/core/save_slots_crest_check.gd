extends Node
## Fat heraldry E2E: save_slots ShellCrestStrip + SlotArms from save meta crest, desk + mobile.

const SCN := "res://scenes/ui/save_slots.tscn"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	await _run_meta_crest()
	if _fails.is_empty():
		print("SAVE SLOTS CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL save_slots crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot(crest: String = "") -> void:
	var hx := crest if crest != "" else GameState.crest_color
	GameState.new_game("壳徽", "灰旗", hx)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false


func _assert_shell(host: Node, where: String) -> void:
	var strip = host.find_child("ShellCrestStrip", true, false)
	_ok(strip != null, "%s ShellCrestStrip" % where)
	if strip != null:
		_ok(strip.find_child("CastleArms", true, false) != null, "%s strip CastleArms" % where)
		_ok(strip.find_child("CastleBanner", true, false) != null, "%s strip CastleBanner" % where)
	_ok(host.find_child("CastleArms", true, false) != null, "%s CastleArms header" % where)
	var row = host.find_child("SlotRow_manual_0", true, false)
	_ok(row != null, "%s SlotRow" % where)
	if row != null:
		_ok(row.find_child("SlotArms", true, false) != null, "%s SlotArms" % where)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = (load(SCN) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	_assert_shell(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = (load(SCN) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(6)
	_assert_shell(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")


func _run_meta_crest() -> void:
	## SlotArms must render the crest written into that slot's meta, not live GameState.
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var slot := "manual_0"
	var crest_a := "#c45c26"
	_boot(crest_a)
	_ok(GameState.save_to_slot(slot), "meta save_to_slot")
	var meta := CKSaveService.read_meta(slot)
	_ok(str(meta.get("crest_color", "")) == crest_a, "meta crest_color persisted")
	## Flip live crest so a live-only attach would diverge.
	GameState.crest_color = "#6ed4ff"
	GameState.banner_spec = BannerSpec.from_crest(GameState.crest_color)
	var page: Control = (load(SCN) as PackedScene).instantiate()
	get_tree().root.add_child(page)
	await _settle(12)
	var row = page.find_child("SlotRow_%s" % slot, true, false)
	_ok(row != null, "meta SlotRow")
	if row != null:
		var arms = row.find_child("SlotArms", true, false)
		_ok(arms != null, "meta SlotArms")
		if arms != null:
			_ok(str(arms.get_meta("arms_kind", "")) == "lb_slot_arms", "meta SlotArms kind")
			var want := CKHeraldry.core_key(CKHeraldry.from_crest(crest_a))
			_ok(str(arms.get_meta("arms_core", "")) == want, "meta SlotArms core from slot crest")
	page.queue_free()
	await _settle(2)
