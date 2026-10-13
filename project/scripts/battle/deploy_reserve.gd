class_name CKDeployReserve
extends RefCounted
## 预备换人（提案 P2）：厅堂 4 级起，开战前指定一名没出战的在册者。
## 每场一次，有我方出战者倒下时，他从离队友最近、能走、没人站的地图边缘进场，不落在死者格子上。

const ENTRY := "map_edge"
const HALL_MIN := 4
const KEY := "reserve_id"


static func enters_from_edge() -> bool:
	return ENTRY == "map_edge"


static func unlocked(host = null) -> bool:
	var h = host if host != null else GameState
	return CKEconomyState.building_level(h, "hall") >= HALL_MIN


static func appointed_id(host = null) -> String:
	var h = host if host != null else GameState
	var rid := str(h.house_mods.get(KEY, ""))
	var c = h.characters.get(rid)
	if c == null or not c.alive or not c.in_roster or rid in h.deploy_ids:
		return ""
	return rid


static func candidates(host = null) -> Array:
	var h = host if host != null else GameState
	var out: Array = []
	for c in h.roster():
		if c != null and c.alive and str(c.id) not in h.deploy_ids:
			out.append(c)
	return out


## 部署页按钮：没解锁/没人可选时给原因；否则在「不设 → 候选1 → 候选2 …」之间轮换。
static func cycle(host = null) -> Dictionary:
	var h = host if host != null else GameState
	if not unlocked(h):
		return {"ok": false, "msg": Locale.t("rs_8c3d6edd") % HALL_MIN}
	var cs := candidates(h)
	if cs.is_empty():
		h.house_mods.erase(KEY)
		return {"ok": false, "msg": Locale.t("rs_da90800a")}
	var cur := appointed_id(h)
	var idx := -1
	for i in cs.size():
		if str(cs[i].id) == cur:
			idx = i
	if idx + 1 >= cs.size():
		h.house_mods.erase(KEY)
		return {"ok": true, "msg": Locale.t("rs_5cb38929")}
	var nxt = cs[idx + 1]
	h.house_mods[KEY] = str(nxt.id)
	return {"ok": true, "msg": Locale.t("rs_68565d5b") % nxt.name}


static func button_text(host = null) -> String:
	var h = host if host != null else GameState
	if not unlocked(h):
		return Locale.t("rs_3aee9149") % HALL_MIN
	var rid := appointed_id(h)
	return Locale.t("rs_ef01b731") % (h.characters[rid].name if rid != "" else Locale.t("rs_8e7438ad"))


## 我方有人倒下时调用。成功返回一个可以直接 append 进 battle.units 的单位；否则返回空字典。
static func try_swap_in(battle, fallen) -> Dictionary:
	if battle == null or fallen == null or str(fallen.get("team")) != "player":
		return {}
	if bool(battle.get_meta("reserve_used", false)):
		return {}
	if not unlocked():
		return {}
	var rid := appointed_id()
	if rid == "":
		return {}
	var c: CKCharacter = GameState.characters[rid]
	var units: Array = battle.get("units")
	for u in units:
		if u.get("char") == c:
			return {}
	var cell := entry_cell(battle.get("terrain"), units, fallen.get("pos"))
	if cell.x < 0:
		return {}
	battle.set_meta("reserve_used", true)
	return {"char": c, "pos": cell, "team": "player", "done": true}


static func entry_cell(terrain: Array, units: Array, fallen_pos) -> Vector2i:
	var h := terrain.size()
	if h == 0:
		return Vector2i(-1, -1)
	var w: int = terrain[0].size()
	var taken := {}
	var mates: Array = []
	for u in units:
		var alive: bool = u.get("char") != null and int(u["char"].hp) > 0
		if alive:
			taken[u["pos"]] = true
			if str(u.get("team")) == "player":
				mates.append(u["pos"])
	if fallen_pos != null:
		taken[fallen_pos] = true
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in h:
		for x in w:
			if x != 0 and y != 0 and x != w - 1 and y != h - 1:
				continue
			var p := Vector2i(x, y)
			if taken.has(p) or str(terrain[y][x]) in ["water", "wall", "void"]:
				continue
			var d := 999
			for m in mates:
				d = mini(d, absi(m.x - x) + absi(m.y - y))
			if d < best_d:
				best_d = d
				best = p
	return best


## battle_controller 只调这一句：成功就把预备加进 units、发技能、写日志。
static func swap_into(battle, fallen) -> void:
	var sub := try_swap_in(battle, fallen)
	if sub.is_empty():
		return
	battle.units.append(sub)
	if battle.has_method("_arm_spawned"):
		battle._arm_spawned(sub)
	if battle.has_method("_log"):
		battle._log(Locale.t("rs_e287c5ce") % sub.char.name)
