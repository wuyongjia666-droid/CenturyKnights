class_name AtlasArt
extends RefCounted
## v8 world atlas + battle biome plate resolver (2026 contemporary fantasy)

const ATLAS_JSON := "res://data/atlas_v8.json"
const ART := "res://assets/art/atlas/"
const BATTLE := "res://assets/art/battle/"
const HUB := "res://assets/art/ui/"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and ResourceLoader.exists(ATLAS_JSON):
		var f := FileAccess.open(ATLAS_JSON, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_data = parsed
	return _data

static func plate_path(label: String, folder: String = ART) -> String:
	var png := folder + label + ".png"
	if ResourceLoader.exists(png):
		return png
	# farm ingest may land under ui/ temporarily
	var alt := "res://assets/art/ui/" + label + ".png"
	if ResourceLoader.exists(alt):
		return alt
	return ""

static func world_plate() -> String:
	return plate_path(str(data().get("world_plate", "v8_atlas_world")))

static func nation_plate(nation_id: String) -> String:
	return plate_path("v8_atlas_nation_%s" % nation_id)

static func scene_plate(scene_id: String) -> String:
	return plate_path("v8_scene_%s" % scene_id, "res://assets/art/scenes/")

static func biome_for_map(map_id: String) -> String:
	## Map 400 fights → 14 biomes by id keywords
	var id := map_id.to_lower()
	var rules := [
		["fog", "fog"], ["mist", "fog"],
		["ford", "ford"], ["river", "ford"], ["ferry", "ford"], ["shore", "ford"], ["reef", "ford"], ["sea", "harbor"], ["harbor", "harbor"], ["quay", "harbor"], ["isle", "harbor"],
		["snow", "snow"], ["frost", "snow"], ["ice", "snow"],
		["marsh", "marsh"], ["swamp", "marsh"],
		["forge", "forge"], ["furnace", "forge"],
		["shrine", "shrine"], ["rite", "shrine"],
		["archive", "archive"], ["vault", "archive"],
		["gate", "fort"], ["keep", "fort"], ["wall", "fort"], ["redoubt", "fort"], ["camp", "nightcamp"], ["night", "nightcamp"],
		["hill", "hill"], ["ridge", "hill"], ["plain", "plain"], ["field", "plain"], ["grass", "plain"],
		["pass", "pass"], ["gorge", "pass"], ["peak", "pass"],
		["urban", "urban"], ["street", "urban"], ["bell", "urban"], ["hall", "urban"],
	]
	for pair in rules:
		if id.find(pair[0]) >= 0:
			return pair[1]
	return "plain"

static func battle_backdrop_for_map(map_id: String) -> String:
	var bio := biome_for_map(map_id)
	var path := "res://assets/art/battle/v8_battle_biome_%s.png" % bio
	if ResourceLoader.exists(path):
		return path
	# fallback legacy
	if ResourceLoader.exists("res://assets/art/ui/battle_backdrop.png"):
		return "res://assets/art/ui/battle_backdrop.png"
	return ""
