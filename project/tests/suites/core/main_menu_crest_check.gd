extends Node
## Fat heraldry E2E: main_menu ShellCrestStrip + CastleArms, desktop + mobile.

const SCN := "res://scenes/ui/main_menu.tscn"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("MAIN MENU CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL main_menu crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("壳徽", "灰旗", GameState.crest_color)
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
