extends Node
## NAR-05：第 1 年城堡入口不超过六扇，十五个系统有灯引和百科，
## 关掉新手高亮后不再出现 coach mark。

const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const Tips := preload("res://scripts/ui/widgets/tips_registry.gd")
const Codex := preload("res://scripts/ui/widgets/help_codex.gd")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL onboarding: ", err)
		get_tree().quit(1)
	else:
		print("ONBOARDING PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if int(Calendar.year) != 1:
		return "year %d" % int(Calendar.year)
	UnlockSchedule.install()
	var open := 0
	for id in UnlockSchedule.known_entries():
		var on := Todo.is_unlocked(str(id))
		if on and not str(id) in UnlockSchedule.load_data().get("always", []):
			open += 1
		if on != UnlockSchedule.allows(str(id)):
			return "interface mismatch " + str(id)
	if open > 6:
		return "year-one doors %d" % open
	if open < 6:
		return "year-one doors %d" % open
	if not Todo.is_unlocked("deploy"):
		return "deploy locked"
	if not Todo.is_unlocked("marriage") or not Todo.is_unlocked("lineage"):
		return "six-door rule: marriage and lineage open in year one"
	if Todo.is_unlocked("atlas") or Todo.is_unlocked("train"):
		return "atlas/train open before their flags"
	GameState.set_flag("e1_01_fought", true)
	if not Todo.is_unlocked("train") or not Todo.is_unlocked("skills"):
		return "train/skills ignored e1_01"
	# every unlock flag must be set somewhere (J7: e2_holdings was never set)
	for f in UnlockSchedule.flags():
		if not _flag_is_set_somewhere(str(f)):
			return "unlock flag %s is never set" % f
	if Todo.is_unlocked("not_a_real_entry"):
		return "unknown open"
	var heir := CharacterFactory.make_ally_tutor()
	heir.parent_ids = ["p1", "p2"]
	heir.alive = true
	GameState.characters[heir.id] = heir
	if not Todo.is_unlocked("rite"):
		return "rite ignored the heir"
	var systems: Array = UnlockSchedule.system_ids()
	if systems.size() < 15:
		return "systems %d" % systems.size()
	var tips: Dictionary = {}
	for tip in Tips.all_tips():
		tips[str(tip.get("id", ""))] = str(tip.get("text", ""))
	if Codex.entry_count() < 6 + systems.size():
		return "codex %d" % Codex.entry_count()
	for sid in systems:
		var found := false
		for tip_id in tips.keys():
			if str(tip_id).begins_with(sid):
				found = true
				var text := str(tips[tip_id])
				if _hanzi(text) > 60 or text.find("系统") >= 0:
					return "tip %s %s" % [tip_id, text]
		if not found:
			return "missing tutorial " + str(sid)
	if not tips.has("deploy_count") or not tips.has("deploy_leave"):
		return "deploy sequence missing"
	var prev = GameState.settings.get("tutorial_highlight", true)
	GameState.settings["tutorial_highlight"] = false
	Tips.clear_seen()
	var tavern = load("res://scenes/hub/tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	if Tips.maybe_present(tavern):
		GameState.settings["tutorial_highlight"] = prev
		return "coach shown while highlight off"
	tavern.queue_free()
	GameState.settings["tutorial_highlight"] = true
	Tips.clear_seen()
	var tavern_on = load("res://scenes/hub/tavern.tscn").instantiate()
	add_child(tavern_on)
	await get_tree().process_frame
	if not Tips.maybe_present(tavern_on):
		GameState.settings["tutorial_highlight"] = prev
		return "coach missing while highlight on"
	if Tips.maybe_present(tavern_on):
		GameState.settings["tutorial_highlight"] = prev
		return "coach repeated"
	tavern_on.queue_free()
	GameState.settings["tutorial_highlight"] = prev
	print("OK year-one=%d systems=%d" % [open, systems.size()])
	return ""

func _hanzi(text: String) -> int:
	var n := 0
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			n += 1
	return n

func _flag_is_set_somewhere(flag: String) -> bool:
	for path in ["res://scripts/characters/family_state.gd", "res://scripts/story/chapter_player.gd",
			"res://scripts/battle/battle_controller.gd", "res://scripts/hub/castle_hub.gd", "res://autoload/game_state.gd"]:
		if FileAccess.get_file_as_string(path).find('"%s"' % flag) >= 0:
			return true
	var dir := DirAccess.open("res://data/story/chapters")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json") and FileAccess.get_file_as_string("res://data/story/chapters/" + f).find('"%s"' % flag) >= 0:
				return true
	return false
