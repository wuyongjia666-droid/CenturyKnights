extends Node
## P3 mobile gate (pawn-redesign-opus §3.8 / §7.3): CK_FORCE_MOBILE caps, halo preference,
## idle refresh contracts. Named mobile_* so ci_godot_run.sh sets CK_FORCE_MOBILE=1.
## Real-device fps / halo ms are NOT measured here (llvmpipe); see docs §7.3.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL mobile unit layer: ", err)
		get_tree().quit(1)
		return
	print("MOBILE UNIT LAYER PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _profile()
	if err == "":
		err = _source_contracts()
	if err == "":
		err = _tiers()
	return err

func _profile() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile.is_mobile()"
	if DeviceProfile.max_board_units_3d() != 24:
		return "mobile cap want 24 got %d" % DeviceProfile.max_board_units_3d()
	if CKUnitLayer3D.max_units() != 24:
		return "CKUnitLayer3D.max_units want 24"
	if not DeviceProfile.prefer_halo_in_viewport():
		return "mobile should prefer halo-in-viewport blit"
	if CKUnitLayer3D.IDLE_HZ < 12.0 or CKUnitLayer3D.IDLE_HZ > 15.0:
		return "IDLE_HZ out of 12–15"
	return ""

func _source_contracts() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/battle/unit_layer_3d.gd")
	if src.find("_refresh_update_mode") < 0:
		return "missing idle refresh"
	if src.find("UPDATE_ONCE") < 0 or src.find("UPDATE_DISABLED") < 0:
		return "missing throttled update modes"
	if src.find("_blit_vp") < 0:
		return "missing mobile halo blit SubViewport"
	if src.find("board_halo.gdshader") < 0:
		return "missing halo shader wire"
	return ""

func _tiers() -> String:
	var prev_le := OS.get_environment("CK_FORCE_LOW_END")
	OS.set_environment("CK_FORCE_LOW_END", "1")
	GameState.settings.erase("board_units_3d")
	var bad := ""
	if DeviceProfile.board_3d_default() or CKUnitLayer3D.default_on():
		bad = "low-end should default to stand-ins"
	OS.set_environment("CK_FORCE_LOW_END", "0")
	if bad == "" and not DeviceProfile.board_3d_default():
		bad = "mid/high mobile should default to realtime 3D"
	OS.set_environment("CK_FORCE_LOW_END", prev_le)
	GameState.settings["board_units_3d"] = true
	if bad == "" and DisplayServer.get_name() != "headless" and CKUnitLayer3D.enabled(25):
		bad = "25 units must exceed mobile cap"
	GameState.settings.erase("board_units_3d")
	return bad
