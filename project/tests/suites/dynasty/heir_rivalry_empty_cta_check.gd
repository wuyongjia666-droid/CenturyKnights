extends Node
## Y1-B / audit #30: heir_rivalry with no eligible heirs shows EmptyHost why
## + named ToMarriage / ToTavern under EmptyActions (no quarrel Move_*).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL heir empty cta: ", err)
		get_tree().quit(1)
	else:
		print("HEIR EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Guarantee no eligible heirs (alive child/lineage_path, age >= 8).
	for ch in GameState.characters.values():
		if ch == null:
			continue
		if ch.is_child or GameState.lineage_path.has(ch.id):
			ch.alive = false
		## Adults on roster must not count as heirs for the trial filter.
		if int(ch.age) >= 8 and (ch.is_child or GameState.lineage_path.has(ch.id)):
			ch.alive = false

	var page: Control = load("res://scenes/hub/heir_rivalry.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame

	var err := _audit(page)
	page.queue_free()
	return err


func _audit(page: Control) -> String:
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	var none_zh := Locale.t("lb_heir_none")
	var why_zh := Locale.t("lb_heir_none_why")
	var how_zh := Locale.t("lb_heir_none_how")
	var seen := {"title": false, "why": false, "how": false}
	for n in host.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		if tx.find(none_zh) >= 0:
			seen["title"] = true
		if tx.find(why_zh) >= 0:
			seen["why"] = true
		if tx.find(how_zh) >= 0:
			seen["how"] = true
	for k in seen:
		if not seen[k]:
			return "empty feel missing %s" % k

	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	if not host.is_ancestor_of(acts):
		return "EmptyActions not under EmptyHost"

	var to_m: Button = page.find_child("ToMarriage", true, false) as Button
	if to_m == null:
		return "ToMarriage missing"
	if not to_m.visible or to_m.disabled:
		return "ToMarriage not usable"
	if not acts.is_ancestor_of(to_m):
		return "ToMarriage not under EmptyActions"
	var want_m := Locale.t("lb_heir_to_marriage")
	if to_m.text != want_m:
		return "ToMarriage text want=%s got=%s" % [want_m, to_m.text]

	var to_t: Button = page.find_child("ToTavern", true, false) as Button
	if to_t == null:
		return "ToTavern missing"
	if not to_t.visible or to_t.disabled:
		return "ToTavern not usable"
	if not acts.is_ancestor_of(to_t):
		return "ToTavern not under EmptyActions"
	var want_t := Locale.t("lb_heir_to_tavern")
	if to_t.text != want_t:
		return "ToTavern text want=%s got=%s" % [want_t, to_t.text]

	## Quarrel / settle moves must stay off when there is nobody to trial.
	for k in ["mediate", "a", "b", "duel"]:
		if page.find_child("Move_" + k, true, false) != null:
			return "Move_%s present in empty state" % k
	if page.find_child("ToInheritance", true, false) != null:
		return "ToInheritance should not show on empty"

	to_m.pressed.emit()
	to_t.pressed.emit()
	print("heir-empty ok EmptyHost ToMarriage+ToTavern")
	return ""
