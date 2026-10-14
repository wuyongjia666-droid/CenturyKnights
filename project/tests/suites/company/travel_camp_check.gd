extends Node
## Improve #2: overnight camp offers 休整 / 巡哨 / 吃饭; watch softens the next leg.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL travel camp: ", err)
		get_tree().quit(1)
		return
	print("TRAVEL CAMP PASS")
	get_tree().quit(0)

func _run() -> String:
	GameState.new_game("扎营", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rng.seed = 7
	GameState.food = 40
	GameState.morale = 50
	var err := _check_rest()
	if err != "":
		return err
	err = _check_watch()
	if err != "":
		return err
	err = _check_meal()
	if err != "":
		return err
	return _check_watch_consumed()

func _check_rest() -> String:
	var dest := "stone_slope"
	var st: Dictionary = World.begin_travel(dest)
	if not bool(st.get("ok", false)):
		return "begin_travel failed: %s" % str(st.get("msg", st))
	var info: Dictionary = World.step_travel()
	var ev: Dictionary = info.get("event", {})
	if str(ev.get("id", "")) != "camp_night":
		return "expected camp_night, got %s" % str(ev.get("id", ev))
	if int(ev.get("options", []).size()) != 3:
		return "camp options %d" % int(ev.get("options", []).size())
	var before_food := GameState.food
	var before_morale := GameState.morale
	var r: Dictionary = World.choose_event(0)
	if not bool(r.get("ok", false)):
		return "rest rejected: %s" % str(r.get("msg", ""))
	if GameState.food >= before_food:
		return "rest did not spend food (%d → %d)" % [before_food, GameState.food]
	if GameState.morale <= before_morale:
		return "rest did not raise morale (%d → %d)" % [before_morale, GameState.morale]
	if World.pos != dest:
		return "rest did not arrive at %s (pos=%s)" % [dest, World.pos]
	return ""

func _check_watch() -> String:
	GameState.food = maxi(GameState.food, 20)
	var nxt := _neighbor(World.pos)
	if nxt == "":
		return "no neighbor from %s" % World.pos
	var st: Dictionary = World.begin_travel(nxt)
	if not bool(st.get("ok", false)):
		return "watch begin failed: %s" % str(st.get("msg", st))
	var info: Dictionary = World.step_travel()
	if str(info.get("event", {}).get("id", "")) != "camp_night":
		return "watch camp missing: %s" % str(info.get("event", {}))
	var r: Dictionary = World.choose_event(1)
	if not bool(r.get("ok", false)):
		return "watch rejected: %s" % str(r.get("msg", ""))
	if not bool(World.road_flags.get("camp_watch", false)):
		return "camp_watch flag missing after watch"
	return ""

func _check_meal() -> String:
	GameState.food = maxi(GameState.food, 20)
	var before_m := GameState.morale
	var nxt2 := _neighbor(World.pos)
	if nxt2 == "":
		return "no meal neighbor"
	var st: Dictionary = World.begin_travel(nxt2)
	if not bool(st.get("ok", false)):
		return "meal begin failed: %s" % str(st.get("msg", st))
	var info: Dictionary = World.step_travel()
	if str(info.get("event", {}).get("id", "")) != "camp_night":
		return "meal camp missing: %s" % str(info.get("event", {}))
	var r: Dictionary = World.choose_event(2)
	if not bool(r.get("ok", false)):
		return "meal rejected: %s" % str(r.get("msg", ""))
	if GameState.morale < before_m + 2:
		return "meal morale %d → %d" % [before_m, GameState.morale]
	return ""

func _check_watch_consumed() -> String:
	World.events_enabled = true
	World.road_flags["camp_watch"] = true
	World.rng.seed = 1
	World._roll_event({"danger": 0, "kind": "road", "days": 1}, "hq", "stone_slope")
	if bool(World.road_flags.get("camp_watch", false)):
		return "camp_watch was not consumed by event roll"
	World.pending_event = {}
	return ""

func _neighbor(from_id: String) -> String:
	for road in World.data.get("roads", []):
		var a := str(road.get("a", ""))
		var b := str(road.get("b", ""))
		if a == from_id:
			return b
		if b == from_id:
			return a
	return ""
