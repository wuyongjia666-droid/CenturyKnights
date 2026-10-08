extends Node
## Headless boot and scene-load budget. Numbers may grow by 20% before this fails.
## chapter_json_parses is reported always. The <=10 gate waits until CKStoryState exists (CORE-01).

const SCENES := {
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"castle_hub": "res://scenes/hub/castle_hub.tscn",
	"battle": "res://scenes/battle/battle.tscn",
	"atlas_view": "res://scenes/hub/atlas_view.tscn",
}

func _ready() -> void:
	await get_tree().process_frame
	var boot_ms := Time.get_ticks_msec()
	var scene_ms := {}
	for name in SCENES.keys():
		scene_ms[name] = await _load_ms(str(SCENES[name]))
	var static_mem := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var texture_mem := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var parses := _chapter_parses()
	var report := {
		"boot_ms": boot_ms,
		"scenes_ms": scene_ms,
		"memory_static_bytes": static_mem,
		"texture_mem_bytes": texture_mem,
		"chapter_json_parses": parses,
		"chapter_json_gate": "active" if _story_state_present() else "deferred-until-core-01",
	}
	var out := JSON.stringify(report)
	var f := FileAccess.open("/tmp/ck_perf.json", FileAccess.WRITE)
	if f:
		f.store_string(out)
		f.close()
	print("PERF JSON ", out)
	var err := _check(report)
	if err != "":
		print("PERF FAIL ", err)
		get_tree().quit(1)
		return
	print("PERF PASS boot=%d main_menu=%d castle_hub=%d battle=%d atlas_view=%d parses=%d" % [
		boot_ms, int(scene_ms["main_menu"]), int(scene_ms["castle_hub"]), int(scene_ms["battle"]), int(scene_ms["atlas_view"]), parses])
	get_tree().quit(0)

func _load_ms(path: String) -> int:
	var t0 := Time.get_ticks_msec()
	var packed = load(path)
	if packed == null:
		push_error("missing " + path)
		return 999999
	var node = packed.instantiate()
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	var ms := Time.get_ticks_msec() - t0
	node.queue_free()
	await get_tree().process_frame
	return ms

func _chapter_parses() -> int:
	if _story_state_present():
		var script = load("res://scripts/core/story_state.gd")
		if script != null and "load_count" in script:
			return int(script.load_count)
	var n := 0
	for i in 235:
		var data = GameState.get("data_chapter%d" % i)
		if data is Dictionary and not (data as Dictionary).is_empty():
			n += 1
	return n

func _story_state_present() -> bool:
	return FileAccess.file_exists("res://scripts/core/story_state.gd")

func _budget_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tools/ci/perf_budget.json")

func _check(report: Dictionary) -> String:
	var path := _budget_path()
	if not FileAccess.file_exists(path):
		return "missing " + path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "budget is not an object"
	var budget: Dictionary = parsed
	var slack := float(budget.get("slack", 1.2))
	if int(report["boot_ms"]) > int(float(budget["boot_ms"]) * slack):
		return "boot_ms %d > %d" % [int(report["boot_ms"]), int(float(budget["boot_ms"]) * slack)]
	var scenes: Dictionary = report["scenes_ms"]
	var limits: Dictionary = budget["scenes_ms"]
	for name in scenes.keys():
		if int(scenes[name]) > int(float(limits[name]) * slack):
			return "%s %d > %d" % [name, int(scenes[name]), int(float(limits[name]) * slack)]
	if int(report["memory_static_bytes"]) > int(float(budget["memory_static_bytes"]) * slack):
		return "memory_static"
	if int(report["texture_mem_bytes"]) > int(float(budget["texture_mem_bytes"]) * slack):
		return "texture_mem"
	if _story_state_present() and int(report["chapter_json_parses"]) > 10:
		return "chapter_json_parses %d > 10" % int(report["chapter_json_parses"])
	return ""
