class_name CKDeployReserve
extends RefCounted
## P2 预备换人：厅堂 4/5 购买能力；从地图边缘进场，不占死者格。

const ENTRY := "map_edge"
const HALL_LEVELS_WITH_RESERVE := [4, 5]


static func entry_mode() -> String:
	return ENTRY


static func enters_from_edge() -> bool:
	return ENTRY == "map_edge"


static func hall_grants_reserve(host = null) -> bool:
	var h = host if host != null else GameState
	var lv := CKEconomyState.building_level(h, "hall")
	return lv in HALL_LEVELS_WITH_RESERVE or lv >= 4


static func can_appoint(host = null) -> bool:
	return hall_grants_reserve(host)


static func appointed_id(host = null) -> String:
	var h = host if host != null else GameState
	return str(h.house_mods.get("reserve_id", ""))


static func appoint(host, cid: String) -> Dictionary:
	if not can_appoint(host):
		return {"ok": false, "msg": Locale.t("reserve_no_hall")}
	var c: CKCharacter = host.characters.get(cid)
	if c == null or not c.alive or not c.in_roster:
		return {"ok": false, "msg": Locale.t("reserve_need_roster")}
	if cid in host.deploy_ids:
		return {"ok": false, "msg": Locale.t("reserve_already")}
	host.house_mods["reserve_id"] = cid
	host.mark_dirty()
	return {"ok": true, "msg": Locale.t("reserve_set") % c.name}


static func clear(host) -> void:
	host.house_mods.erase("reserve_id")


static func edge_cells(map_w: int, map_h: int, blocked: Dictionary = {}) -> Array:
	## Returns walkable edge cells (x,y) around the map border.
	var out: Array = []
	for x in range(map_w):
		for y in [0, map_h - 1]:
			var k := "%d,%d" % [x, y]
			if not bool(blocked.get(k, false)):
				out.append(Vector2i(x, y))
	for y2 in range(1, map_h - 1):
		for x2 in [0, map_w - 1]:
			var k2 := "%d,%d" % [x2, y2]
			if not bool(blocked.get(k2, false)):
				out.append(Vector2i(x2, y2))
	return out


static func pick_entry_cell(map_w: int, map_h: int, team_cells: Array, blocked: Dictionary = {}) -> Vector2i:
	## Prefer edge cell nearest to any allied cell; never the fallen cell.
	var edges := edge_cells(map_w, map_h, blocked)
	if edges.is_empty():
		return Vector2i(-1, -1)
	if team_cells.is_empty():
		return edges[0]
	var best: Vector2i = edges[0]
	var best_d := 999999
	for e in edges:
		for t in team_cells:
			var d: int = abs(e.x - t.x) + abs(e.y - t.y)
			if d < best_d:
				best_d = d
				best = e
	return best


static func try_swap_in(battle, fallen_unit) -> Dictionary:
	## Call when an ally falls or is withdrawn. Once per battle.
	if battle == null:
		return {"ok": false, "msg": Locale.t("reserve_no_battle")}
	if bool(battle.get_meta("reserve_used", false)):
		return {"ok": false, "msg": Locale.t("reserve_used")}
	if not can_appoint():
		return {"ok": false, "msg": Locale.t("reserve_no_cap")}
	var rid := appointed_id()
	if rid == "":
		return {"ok": false, "msg": Locale.t("reserve_unset")}
	var c: CKCharacter = GameState.characters.get(rid)
	if c == null or not c.alive:
		return {"ok": false, "msg": Locale.t("reserve_dead")}
	var map_w := int(battle.get("map_w")) if battle.get("map_w") != null else 12
	var map_h := int(battle.get("map_h")) if battle.get("map_h") != null else 8
	var blocked := {}
	var team_cells: Array = []
	if battle.has_method("iter_units"):
		pass
	# Best-effort: read units array if present
	var units = battle.get("units")
	if typeof(units) == TYPE_ARRAY:
		for u in units:
			if u == null:
				continue
			var cell = u.get("cell")
			if cell != null:
				blocked["%d,%d" % [cell.x, cell.y]] = true
				if str(u.get("team", "")) == "player" and (fallen_unit == null or u != fallen_unit):
					team_cells.append(cell)
	# Never use fallen cell
	if fallen_unit != null and fallen_unit.get("cell") != null:
		var fc = fallen_unit.cell
		blocked["%d,%d" % [fc.x, fc.y]] = true
	var entry := pick_entry_cell(map_w, map_h, team_cells, blocked)
	if entry.x < 0:
		return {"ok": false, "msg": Locale.t("reserve_no_edge")}
	battle.set_meta("reserve_used", true)
	battle.set_meta("reserve_entry", entry)
	return {
		"ok": true,
		"msg": Locale.t("reserve_enter") % c.name,
		"cid": rid,
		"cell": entry,
		"entry_mode": ENTRY,
	}
