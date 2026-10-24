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
	var err := _audit_empty(page)
	if err != "":
		return err
	err = _audit_ctas(page)
	if err != "":
		return err
	err = _audit_no_quarrel(page)
	if err != "":
		return err
	print("heir-empty ok EmptyHost ToMarriage+ToTavern")
	return ""


func _audit_empty(page: Control) -> String:
	var host := page.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing"
	var bits := {
		"title": Locale.t("lb_heir_none"),
		"why": Locale.t("lb_heir_none_why"),
		"how": Locale.t("lb_heir_none_how"),
	}
	var seen := {"title": false, "why": false, "how": false}
	for n in host.find_children("*", "Label", true, false):
		var tx := str((n as Label).text)
		for k in bits:
			if tx.find(str(bits[k])) >= 0:
				seen[k] = true
	for k in seen:
		if not seen[k]:
			return "empty feel missing %s" % k
	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	if not host.is_ancestor_of(acts):
		return "EmptyActions not under EmptyHost"
	return ""


func _audit_ctas(page: Control) -> String:
	var acts := page.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var pairs := [
		["ToMarriage", "lb_heir_to_marriage"],
		["ToTavern", "lb_heir_to_tavern"],
	]
	for pair in pairs:
		var cta: Button = page.find_child(str(pair[0]), true, false) as Button
		if cta == null:
			return "%s missing" % pair[0]
		if not cta.visible or cta.disabled:
			return "%s not usable" % pair[0]
		if not acts.is_ancestor_of(cta):
			return "%s not under EmptyActions" % pair[0]
		var want := Locale.t(str(pair[1]))
		if cta.text != want:
			return "%s text want=%s got=%s" % [pair[0], want, cta.text]
		cta.pressed.emit()
	return ""


func _audit_no_quarrel(page: Control) -> String:
	for k in ["mediate", "a", "b", "duel"]:
		if page.find_child("Move_" + k, true, false) != null:
			return "Move_%s present in empty state" % k
	if page.find_child("ToInheritance", true, false) != null:
		return "ToInheritance should not show on empty"
	return ""
