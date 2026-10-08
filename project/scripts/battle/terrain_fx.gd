class_name TerrainFx
extends RefCounted
## Height, weather, interactive cells, and scout-map vision. Data only.

const HEIGHT_MIN := 0
const HEIGHT_MAX := 3
const HIT_PER_LEVEL := 6
const RAIN_RANGED_HIT := -12
const SNOW_MOVE_EXTRA := 1
const FOG_VISION := 2
const SCOUT_VISION := 4
const OPEN_VISION := 99


static func clamp_height(h: int) -> int:
	return clampi(h, HEIGHT_MIN, HEIGHT_MAX)


static func height_delta_hit(atk_h: int, def_h: int) -> int:
	return (clamp_height(atk_h) - clamp_height(def_h)) * HIT_PER_LEVEL


static func range_bonus(height: int) -> int:
	return 1 if clamp_height(height) >= 2 else 0


static func weather_hit(weather: String, atk_type: String) -> int:
	if weather == "rain" and atk_type == "ranged":
		return RAIN_RANGED_HIT
	return 0


static func weather_move_extra(weather: String) -> int:
	return SNOW_MOVE_EXTRA if weather == "snow" else 0


static func vision_range(scout: bool, weather: String) -> int:
	if not scout:
		return OPEN_VISION
	if weather == "fog":
		return FOG_VISION
	return SCOUT_VISION


static func sees(a: Vector2i, b: Vector2i, radius: int) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) <= radius


static func seen_by(watchers: Array, cell: Vector2i, radius: int) -> bool:
	for w in watchers:
		var pos: Vector2i = w
		if sees(pos, cell, radius):
			return true
	return false


static func blocks(kind: String, state: String) -> bool:
	if kind == "door":
		return state == "closed"
	if kind == "bridge":
		return state == "up"
	if kind == "fence":
		return state == "up"
	return false


static func can_use(kind: String, state: String) -> bool:
	if kind == "door":
		return state == "closed" or state == "open"
	if kind == "bridge":
		return state == "up" or state == "down"
	if kind == "fire":
		return state == "lit"
	if kind == "fence":
		return state == "up"
	return false


static func interact(kind: String, state: String) -> String:
	if kind == "door":
		return "open" if state == "closed" else "closed"
	if kind == "bridge":
		return "down" if state == "up" else "up"
	if kind == "fire":
		return "out"
	if kind == "fence":
		return "broken"
	return state
