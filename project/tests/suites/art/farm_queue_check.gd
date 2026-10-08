extends Node
## ART-03: v92 farm queues cover the missing cities, every item, and the dry-run gate.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL farm queue: ", err)
		get_tree().quit(1)
	get_tree().quit(0)

func _repo() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..")

func _read(rel: String) -> Dictionary:
	var path := _repo().path_join(rel)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _run() -> String:
	var cities: Array = _read("tools/farm_queue/v92_cities.json").get("jobs", [])
	var items: Array = _read("tools/farm_queue/v92_items.json").get("jobs", [])
	var smiths: Array = _read("tools/farm_queue/v92_smiths.json").get("jobs", [])
	var scenes: Array = _read("tools/farm_queue/v92_scenes.json").get("jobs", [])
	var expr: Array = _read("tools/farm_queue/v92_expressions.json").get("jobs", [])
	var castle: Array = _read("tools/farm_queue/v92_castle.json").get("jobs", [])
	var estates: Array = _read("tools/farm_queue/v92_estates.json").get("jobs", [])
	if cities.size() != 35:
		return "cities %d" % cities.size()
	if items.size() != 223:
		return "items %d" % items.size()
	if smiths.size() != 11:
		return "smiths %d" % smiths.size()
	if scenes.size() != 50 or expr.size() != 60 or castle.size() != 28 or estates.size() != 55:
		return "side queues"
	var redraw := 0
	for row in cities:
		if row.get("redraw", false):
			redraw += 1
	if redraw != 8:
		return "redraws %d" % redraw
	var world_text := FileAccess.get_file_as_string(_repo().path_join("project/data/world_items_v87.json"))
	var catalog = JSON.parse_string(world_text)
	var want := {}
	for item in catalog.get("items", []):
		want[str(item.get("id", ""))] = true
	if want.size() != 223:
		return "catalog"
	for row in items:
		var iid := str(row.get("item_id", ""))
		if not want.has(iid):
			return "unknown item " + iid
		want.erase(iid)
	if not want.is_empty():
		return "missing items %d" % want.size()
	var out: Array = []
	var code := OS.execute("python3", [_repo().path_join("tools/farm_queue/validate_queue_v92.py")], out, true)
	var text := " ".join(out)
	if code != 0 or text.find("QUEUE PASS") < 0:
		return "validator %d %s" % [code, text.left(240)]
	print("FARM QUEUE PASS cities=35 redraws=8 smiths=11 items=223 scenes=50 expressions=60 castle=28 estates=55")
	return ""
