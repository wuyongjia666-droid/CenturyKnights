extends Node
## Y1-B: train (旗塾) empty promo list exposes named ToTitlePromote under DynPromoList
## (empty box already has why-text; this knife adds the tap CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL train promo empty cta: ", err)
		get_tree().quit(1)
	else:
		print("TRAIN PROMO EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	## Force no promote_to for anyone in roster (terminal jobs).
	for ch in GameState.roster():
		ch.job_id = "veteran"

	var page: Control = load("res://scenes/hub/train.tscn").instantiate()
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
	var promo := page.find_child("DynPromoList", true, false)
	if promo == null:
		return "DynPromoList missing"
	var none_zh := Locale.t("lb_train_promo_none")
	var found_empty := false
	for n in promo.find_children("*", "Label", true, false):
		if str((n as Label).text).find(none_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_train_promo_none) missing"

	var cta: Button = page.find_child("ToTitlePromote", true, false) as Button
	if cta == null:
		return "ToTitlePromote missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToTitlePromote not visible"
	if cta.disabled:
		return "ToTitlePromote disabled"
	var want := Locale.t("lb_train_to_title_promote")
	if cta.text != want:
		return "ToTitlePromote text want=%s got=%s" % [want, cta.text]
	if not promo.is_ancestor_of(cta):
		return "ToTitlePromote not under DynPromoList"
	cta.pressed.emit()
	print("train-promo-empty ok ToTitlePromote under_promo=1")
	return ""
