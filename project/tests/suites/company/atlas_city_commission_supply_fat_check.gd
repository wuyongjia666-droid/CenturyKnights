extends Node
## Fat knife #5: 大地图城·委托·补给闭环 —
## ≥2 可进城市 playable surface → 接委托 → 行程预览 → 补给/物产 → 交委托 → 奖励卡可读。
## Deepens atlas_commission_supply_loop / playable atlas; one fat PR; no EmptyHost.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const QUESTS_SCN := preload("res://scenes/hub/quests.tscn")
const HOME := "ash_capital"
const MARKER := "ATLAS CITY COMMISSION SUPPLY FAT PASS"
const SHOT_DIR := "user://atlas_city_commission_supply_shots"
const DESK := Vector2i(1600, 900)

var _shot_n := 0
var _qid := ""
var _good := ""
var _qty := 0
var _supply := ""


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL atlas city commission supply fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(DESK)
	await _settle(2)
	err = _api_playable_cities()
	if err != "":
		return err
	err = _api_full_loop_reward()
	if err != "":
		return err
	err = await _ui_city_board_march_and_reward()
	if err != "":
		return err
	err = await _ui_atlas_march_and_reward_modal()
	if err != "":
		return err
	err = await _ui_quests_reward_line()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var err := _algebra_sources()
	if err != "":
		return err
	return _algebra_locale()


func _algebra_sources() -> String:
	var world := FileAccess.get_file_as_string("res://autoload/world.gd")
	var city := FileAccess.get_file_as_string("res://scripts/hub/city.gd")
	var atlas := FileAccess.get_file_as_string("res://scripts/hub/atlas_view.gd")
	var quests := FileAccess.get_file_as_string("res://scripts/hub/quests.gd")
	if world.find("func city_playable_surface") < 0:
		return "world missing city_playable_surface"
	if world.find("func active_commission_march_preview") < 0:
		return "world missing active_commission_march_preview"
	if world.find("func commission_reward_summary") < 0:
		return "world missing commission_reward_summary"
	if world.find("_stamp_commission_reward") < 0:
		return "world missing _stamp_commission_reward"
	if city.find("CommissionRewardCard") < 0:
		return "city missing CommissionRewardCard"
	if city.find("CityPlayableSurface") < 0:
		return "city missing CityPlayableSurface"
	if city.find("CommissionMarchStrip") < 0:
		return "city missing CommissionMarchStrip"
	if atlas.find("CommissionRewardModal") < 0:
		return "atlas missing CommissionRewardModal"
	if atlas.find("active_commission_march_preview") < 0:
		return "atlas missing march preview wiring"
	if quests.find("LastCommissionReward") < 0:
		return "quests missing LastCommissionReward"
	return ""


func _algebra_locale() -> String:
	for key in [
		"atlas_commission_reward_summary",
		"atlas_commission_reward_body",
		"atlas_commission_march_strip",
		"city_playable_surface_line",
		"wq_last_reward_line",
	]:
		if Locale.t(key) == key or Locale.t(key) == "...":
			return "locale missing %s" % key
	return ""


func _setup() -> void:
	GameState.new_game("城委托补给", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.active.clear()
	World.cargo.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.city_visit = {}
	World.last_city_sortie.clear()
	World.last_commission_reward = {}
	World.pos = HOME
	World.visited[HOME] = true
	World.rep_city[HOME] = 40
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 5000
	GameState.food = 200
	GameState.iron = 20
	GameState.morale = 80


func _make_gather() -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("atlas-city-commission-supply-fat")
	var q: Dictionary = {}
	for _i in 40:
		q = World._make_quest(HOME, "gather", 1, r)
		if q.is_empty():
			continue
		var supply := str(q.get("supply_city", ""))
		if supply != "" and supply != HOME and World.nodes.has(supply):
			return q
	return q


func _post(q: Dictionary) -> void:
	World._ensure_board(HOME)
	World.boards[HOME].offers.append(q)


func _go(dest: String) -> void:
	for _i in 24:
		if not World.encounter.is_empty():
			World.on_battle_end(true)
			continue
		if World.pos == dest and not World.is_traveling():
			break
		World.travel_to(dest)
	if not World.encounter.is_empty():
		World.on_battle_end(true)


func _api_playable_cities() -> String:
	_setup()
	var ok_cities: Array = []
	for id in ["ash_capital", "tide_bridge", "ash_market", "reed_ford"]:
		if not World.nodes.has(id):
			continue
		var surf: Dictionary = World.city_playable_surface(id)
		if bool(surf.get("ok", false)):
			ok_cities.append(id)
			if not (bool(surf.get("smith", false)) or bool(surf.get("board", false)) or bool(surf.get("produce", false))):
				return "playable surface flags empty for %s" % id
	if ok_cities.size() < 2:
		return "need ≥2 playable cities got %s" % str(ok_cities)
	print("api playable cities ok: ", ok_cities)
	return ""


## Split for gdlint max-returns.
func _api_full_loop_reward() -> String:
	_setup()
	var q := _make_gather()
	if q.is_empty():
		return "api make gather failed"
	_post(q)
	_qid = str(q.id)
	_good = str(q.good)
	_qty = int(q.qty)
	_supply = World.gather_supply_city(q)
	if _supply == "" or not World.nodes.has(_supply):
		return "api supply missing"
	var acc: Dictionary = World.accept_quest(HOME, _qid)
	if not bool(acc.get("ok", false)):
		return "api accept fail: %s" % acc.get("msg", "")
	var err := _api_assert_march_and_buy()
	if err != "":
		return err
	err = _api_assert_turnin_reward()
	if err != "":
		return err
	print("api full loop reward ok")
	return ""


func _api_assert_march_and_buy() -> String:
	var march: Dictionary = World.active_commission_march_preview()
	if march.is_empty() or str(march.get("guide", "")) != _supply:
		return "api march preview guide want %s got %s" % [_supply, march]
	if int(march.get("days", -1)) < 0:
		return "api march days missing"
	_go(_supply)
	World.visited[_supply] = true
	if not World.market.has(_supply):
		World._init_market(_supply)
	World.market[_supply][_good] = maxi(_qty, int(World.market[_supply].get(_good, 0)))
	var buy: Dictionary = World.gather_buy_here()
	if not bool(buy.get("ok", false)):
		return "api gather_buy fail: %s" % buy.get("msg", "")
	_go(HOME)
	return ""


func _api_assert_turnin_reward() -> String:
	var silver0 := int(GameState.silver)
	var rep0 := World.rep_of(HOME)
	var tr: Dictionary = World.turn_in(_qid)
	if not bool(tr.get("ok", false)):
		return "api turn_in fail: %s" % tr.get("msg", "")
	if World.last_commission_reward.is_empty():
		return "api last_commission_reward empty"
	if not tr.has("reward"):
		return "api turn_in missing reward payload"
	if int(World.last_commission_reward.get("silver", 0)) <= 0:
		return "api reward silver ≤0"
	if int(GameState.silver) <= silver0:
		return "api silver not credited"
	if World.rep_of(HOME) <= rep0:
		return "api rep not credited"
	var summary := World.commission_reward_summary()
	if summary == "" or summary.find("+") < 0:
		return "api commission_reward_summary blank: %s" % summary
	World.dismiss_commission_reward()
	if not World.last_commission_reward.is_empty():
		return "api dismiss left residue"
	return ""



func _ui_city_board_march_and_reward() -> String:
	_setup()
	var q := _make_gather()
	if q.is_empty():
		return "ui city make fail"
	_post(q)
	_qid = str(q.id)
	_good = str(q.good)
	_qty = int(q.qty)
	_supply = World.gather_supply_city(q)
	GameState.set_meta("city_id", HOME)
	GameState.set_meta("city_tab", "overview")
	var page = CITY_SCN.instantiate()
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	await _settle(8)
	var surf_chip := page.find_child("CityPlayableSurface", true, false)
	if surf_chip == null:
		page.queue_free()
		await _settle(2)
		return "CityPlayableSurface missing on overview"
	await _shot("city_playable_overview")
	if page.has_method("_set_tab"):
		page.call("_set_tab", "board")
	page.set("_sel_quest", _qid)
	if page.has_method("_render_tab"):
		page.call("_render_tab")
	await _settle(6)
	var march_row := page.find_child("BoardSupplyMarch", true, false)
	if march_row == null:
		page.queue_free()
		await _settle(2)
		return "BoardSupplyMarch missing on board"
	var acc: Dictionary = World.accept_quest(HOME, _qid)
	if not bool(acc.get("ok", false)):
		page.queue_free()
		await _settle(2)
		return "ui accept fail: %s" % acc.get("msg", "")
	if page.has_method("_render_tab"):
		page.call("_render_tab")
	await _settle(4)
	var strip := page.find_child("CommissionMarchStrip", true, false)
	if strip == null:
		page.queue_free()
		await _settle(2)
		return "CommissionMarchStrip missing after accept"
	await _shot("city_board_march")
	# Complete gather off-UI then turn in via city CTA path.
	_go(_supply)
	World.visited[_supply] = true
	if not World.market.has(_supply):
		World._init_market(_supply)
	World.market[_supply][_good] = maxi(_qty, int(World.market[_supply].get(_good, 0)))
	var buy: Dictionary = World.gather_buy_here()
	if not bool(buy.get("ok", false)):
		page.queue_free()
		await _settle(2)
		return "ui buy fail: %s" % buy.get("msg", "")
	_go(HOME)
	World.pos = HOME
	if page.has_method("_do"):
		page.call("_do", World.turn_in(_qid))
	else:
		World.turn_in(_qid)
	await _settle(8)
	var card := page.find_child("CommissionRewardCard", true, false)
	var panel := page.find_child("CommissionRewardPanel", true, false)
	var ok_btn := page.find_child("CommissionRewardOk", true, false)
	var err := ""
	if card == null or panel == null:
		err = "CommissionRewardCard/Panel missing after city turn_in"
	elif ok_btn == null:
		err = "CommissionRewardOk missing"
	else:
		var body := page.find_child("CommissionRewardText", true, false) as Label
		if body == null or body.text.find("+") < 0:
			err = "CommissionRewardText missing silver/rep"
		else:
			await _shot("city_commission_reward")
			ok_btn.pressed.emit()
			await _settle(4)
			if not World.last_commission_reward.is_empty():
				err = "dismiss did not clear last_commission_reward"
			elif page.find_child("CommissionRewardPanel", true, false) != null:
				err = "reward panel still present after dismiss"
	page.queue_free()
	await _settle(2)
	if err != "":
		return err
	print("ui city board+reward ok")
	return ""


func _ui_atlas_march_and_reward_modal() -> String:
	_setup()
	var q := _make_gather()
	if q.is_empty():
		return "ui atlas make fail"
	_post(q)
	_qid = str(q.id)
	_good = str(q.good)
	_qty = int(q.qty)
	_supply = World.gather_supply_city(q)
	var acc: Dictionary = World.accept_quest(HOME, _qid)
	if not bool(acc.get("ok", false)):
		return "atlas accept fail"
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	await _settle(10)
	if atlas.has_method("_select_node"):
		atlas.call("_select_node", _supply)
	await _settle(6)
	var note := atlas.find_child("CommissionMarchNote", true, false)
	var strip := atlas.find_child("CommissionMarchStrip", true, false)
	if note == null and strip == null:
		atlas.queue_free()
		await _settle(2)
		return "atlas missing CommissionMarchNote and CommissionMarchStrip"
	await _shot("atlas_commission_march")
	atlas.queue_free()
	await _settle(2)
	# Finish loop + stamp reward, then open atlas to show modal.
	_go(_supply)
	World.visited[_supply] = true
	if not World.market.has(_supply):
		World._init_market(_supply)
	World.market[_supply][_good] = maxi(_qty, int(World.market[_supply].get(_good, 0)))
	var buy: Dictionary = World.gather_buy_here()
	if not bool(buy.get("ok", false)):
		return "atlas buy fail: %s" % buy.get("msg", "")
	_go(HOME)
	var tr: Dictionary = World.turn_in(_qid)
	if not bool(tr.get("ok", false)):
		return "atlas turn_in fail"
	if World.last_commission_reward.is_empty():
		return "atlas reward empty after turn_in"
	World.last_commission_reward["shown"] = false
	atlas = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	await _settle(8)
	if atlas.has_method("_check_commission_reward"):
		atlas.call("_check_commission_reward")
	await _settle(8)
	var modal := atlas.find_child("CommissionRewardModal", true, false)
	var ok_btn := atlas.find_child("CommissionRewardOk", true, false) as Button
	var err := ""
	if modal == null:
		err = "CommissionRewardModal missing"
	elif ok_btn == null:
		err = "atlas CommissionRewardOk missing"
	else:
		await _shot("atlas_commission_reward")
		ok_btn.pressed.emit()
		await _settle(4)
		if not World.last_commission_reward.is_empty():
			err = "atlas dismiss left reward"
		elif atlas.find_child("CommissionRewardModal", true, false) != null:
			err = "atlas reward modal still present"
	atlas.queue_free()
	await _settle(2)
	if err != "":
		return err
	print("ui atlas march+reward ok")
	return ""


func _ui_quests_reward_line() -> String:
	_setup()
	World.last_commission_reward = {
		"quest_id": "q_test",
		"title": "试委托",
		"kind": "gather",
		"silver": 42,
		"rep": 3,
		"reward_good": "",
		"reward_qty": 0,
		"issuer": HOME,
		"issuer_name": "灰烬都",
		"turn_in": HOME,
		"turn_in_name": "灰烬都",
		"day": 1,
		"extra": "",
		"shown": true,
	}
	var page = QUESTS_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	var line := page.find_child("LastCommissionReward", true, false) as Label
	var err := ""
	if line == null:
		err = "LastCommissionReward missing"
	elif line.text.find("42") < 0 and line.text.find("试委托") < 0:
		err = "LastCommissionReward text blank: %s" % line.text
	page.queue_free()
	await _settle(2)
	if err != "":
		return err
	print("ui quests reward line ok")
	return ""


func _shot(tag: String) -> void:
	_shot_n += 1
	print("shot begin %s" % tag)
	var vp := get_viewport()
	if vp == null:
		print("shot skip no vp %s" % tag)
		return
	await get_tree().process_frame
	var tex = vp.get_texture()
	if tex == null:
		print("shot skip no tex %s" % tag)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("shot skip no img %s" % tag)
		return
	var path := "%s/%02d_%s.png" % [SHOT_DIR, _shot_n, tag]
	var serr := img.save_png(path)
	print("shot %s err=%s size=%s" % [path, serr, img.get_size()])


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
