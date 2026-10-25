extends Node
## Mobile E2E: winter snow rations + MarchRationRow on atlas.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas march ration: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS MARCH RATION SEASON PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	Calendar.month = 1
	World.pos = "sy_frostfort"
	var page := await _mount_atlas()
	var row: Node = page.find_child("MarchRationRow", true, false)
	if row == null:
		page.queue_free()
		return "MarchRationRow missing"
	var info: Dictionary = World.food_ration_info()
	if str(info.season_id) != "winter":
		page.queue_free()
		return "season not winter"
	if str(info.biome) != "snow":
		page.queue_free()
		return "biome not snow"
	if int(info.mod_pct) <= 0:
		page.queue_free()
		return "mod_pct not positive on winter snow"
	if World.food_per_day() < int(info.base):
		page.queue_free()
		return "per_day below base"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("RationMob", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 100
	GameState.silver = 400
	GameState.morale = 70
	World.travel = {}
	# pad party so winter/snow ceil is visible
	for i in 4:
		var cid := "mob_ration_%d" % i
		var c := CKCharacter.new()
		c.id = cid
		c.name = "M%d" % i
		c.alive = true
		c.in_roster = true
		c.age = 20
		c.stats = {"str": 10, "agi": 10, "vit": 10, "wil": 10, "per": 10, "skl": 10}
		GameState.characters[cid] = c

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame

func _mount_atlas() -> Node:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 14:
		await get_tree().process_frame
	return page
