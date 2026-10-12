extends Node
## Audit #9/#11/#12: title, continue failure, grouped settings with battle-anim modes, credits sources.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL menu a1: ", err)
		get_tree().quit(1)
	else:
		print("MENU A1 PASS")
		get_tree().quit(0)

func _labels(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	return out

func _run() -> String:
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var txt := _labels(menu)
	if txt.find("同型") >= 0:
		return "title still says 同型"
	if (menu.find_child("VersionLabel", true, false) as Label).text.find("9.1") < 0:
		return "no version"
	menu._loading = true
	menu._on_continue()
	menu._loading = false
	if (menu.find_child("MenuMsg", true, false) as Label).text != "" and CKSaveSlots.latest_slot() != "":
		return "repeat tap should be ignored"
	menu.queue_free()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var st = load("res://scenes/ui/settings.tscn").instantiate()
	add_child(st)
	await get_tree().process_frame
	for g in ["a1_set_view", "a1_set_motion", "a1_set_sound", "a1_set_battle", "a1_set_help"]:
		if st.find_child("Group_" + g, true, false) == null:
			return "missing group %s" % g
	for n in ["VolMaster", "VolMusic", "VolSFX", "BattleAnim", "UiScale", "Colorblind"]:
		var c := st.find_child(n, true, false) as Control
		if c == null:
			return "missing %s" % n
		if c.custom_minimum_size.y < 48:
			return "%s under 48" % n
	st.set_anim_mode("off")
	if bool(GameState.settings.cutscenes) or st.anim_mode() != "off":
		return "off mode"
	st.set_anim_mode("key")
	if not bool(GameState.settings.cutscenes) or CutsceneTimeline.resolve_mode(GameState.settings) != "key":
		return "key mode"
	st.set_anim_mode("bogus")
	if st.anim_mode() != "full":
		return "bad mode fallback"
	if st.find_child("SettingsColumn", true, false) == null or st.find_child("SettingsColumnRight", true, false) == null:
		return "settings should use two columns"
	st.queue_free()
	var cr = load("res://scenes/ui/credits.tscn").instantiate()
	add_child(cr)
	await get_tree().process_frame
	var ct := _labels(cr)
	for k in ["a1_cr_art_h", "a1_cr_music_h", "a1_cr_engine_h"]:
		if ct.find(Locale.t(k)) < 0:
			return "credits missing %s" % k
	return ""
