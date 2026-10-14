extends Node
## Regression: founding/hub input lag roots — MobileChrome coalesce, portrait clear_mem
## must not wipe the bank disk index, and naming must not clear caches on every preview.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL input_lag: ", err)
		get_tree().quit(1)
		return
	print("INPUT LAG CHECK PASS")
	get_tree().quit(0)

func _run() -> String:
	# 1) clear_mem must not force a bank re-list (warm stays hot).
	CKPortraitBank.clear_cache()
	CKPortraitBank.warm_disk_index()
	var t0 := Time.get_ticks_msec()
	CKPortraitBank.warm_disk_index()
	var warm_hot := Time.get_ticks_msec() - t0
	CKGenomePortrait.clear_mem()
	t0 = Time.get_ticks_msec()
	CKPortraitBank.warm_disk_index()
	var after_clear := Time.get_ticks_msec() - t0
	# After clear_mem the second warm must stay cheap (index intact). A wipe rebuilds ~9k entries.
	if after_clear > maxi(800, warm_hot * 20 + 200):
		return "clear_mem likely wiped disk index (warm %dms → after clear_mem %dms)" % [warm_hot, after_clear]

	# 2) MobileChrome coalesces apply
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not MobileChrome.has_method("_schedule_apply"):
		return "MobileChrome missing _schedule_apply coalesce helper"
	MobileChrome._apply_pending = false
	MobileChrome._schedule_apply()
	if not bool(MobileChrome._apply_pending):
		return "_schedule_apply did not set _apply_pending"
	MobileChrome._schedule_apply()
	MobileChrome._schedule_apply()
	if not bool(MobileChrome._apply_pending):
		return "coalesce lost _apply_pending"

	# 3) Naming preview must not nuke caches; keystrokes use _on_name_typed.
	var src := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	if src.find("func _on_name_typed") < 0:
		return "naming missing _on_name_typed (keystrokes must not rebuild portraits)"
	var i := src.find("func _refresh_preview_art")
	if i < 0:
		return "naming missing _refresh_preview_art"
	var j := src.find("\nfunc ", i + 10)
	var body := src.substr(i, j - i)
	var code := ""
	for line in body.split("\n"):
		var cut := line.find("##")
		if cut >= 0:
			line = line.substr(0, cut)
		code += line + "\n"
	if code.find("UnitArt.clear_cache()") >= 0 or code.find("CKGenomePortrait.clear_mem()") >= 0:
		return "_refresh_preview_art still nukes portrait caches"
	return ""

