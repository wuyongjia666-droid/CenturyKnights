extends Node
## P0 playtest: once the captain is married (incl. the ch0 "skip, just marry" path), the
## marriage page must show the spouse — no candidate tabs, no leftover candidate card.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL married view: ", err)
		get_tree().quit(1)
	else:
		print("MARRIED VIEW PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = "m"
	GameState.reputation["ashland"] = 0
	var ch0 = load("res://scenes/story/chapter_player.tscn").instantiate()
	ch0.chapter_path = "res://data/story/chapters/ch0.json"
	ch0.lock_path = true
	ch0.suppress_scene_change = true
	add_child(ch0)
	await get_tree().process_frame
	ch0._auto_marry()
	ch0.queue_free()
	if lead.spouse_id == "":
		return "auto marry did nothing"
	var sp: CKCharacter = GameState.characters.get(lead.spouse_id)
	var page = load("res://scenes/hub/marriage.tscn").instantiate()
	add_child(page)
	for i in 4:
		await get_tree().process_frame
	if page._selected != sp:
		return "center/right card is %s, not spouse %s" % [page._selected.name if page._selected else "null", sp.name]
	if not page.is_married_view():
		return "page not in married view"
	for b in page._tabs.get_children():
		if b is Button and b.has_meta("cand") and not b.is_queued_for_deletion():
			return "candidate tab still shown: " + str(b.text)
	var banner = page._tabs.get_node_or_null("MarriedBanner")
	if banner == null or not str(banner.text).contains(sp.name):
		return "no married banner naming the spouse"
	var reroll = page.get_node_or_null("MarriageActions/Reroll")
	if reroll != null and reroll.visible:
		return "re-roll (再议) still visible"
	if not page._marry_btn.disabled:
		return "contract button still enabled"
	var names := []
	for n in page.find_children("CardName", "", true, false):
		names.append(str(n.text))
	if not names.has(sp.name):
		return "spouse card missing (cards: %s)" % [names]
	if page.find_children("HeirPreview", "", true, false).is_empty():
		return "heir outlook missing"
	var foot = page.get_node_or_null("StitchFooter")
	if foot != null:
		for n in foot.find_children("*", "Label", true, false):
			if str(n.text) in ["缔约", "再议", "切换候选"] and n.is_visible_in_tree():
				return "footer hint %s still shown when married" % n.text
	## Gendered titles: a female noble reads 女男爵 etc., male/neutral keeps 男爵.
	var want := {"knight": "女勋士", "baron": "女男爵", "viscount": "女子爵", "count": "女伯爵", "duke": "女侯爵"}
	for rid in want:
		if CKCharacter.rank_label(rid, "f") != want[rid]:
			return "female %s reads %s" % [rid, CKCharacter.rank_label(rid, "f")]
		if CKCharacter.rank_label(rid, "m") != CKCharacter.RANK_NAMES[rid]:
			return "male %s reads %s" % [rid, CKCharacter.rank_label(rid, "m")]
	sp.rank = "baron"
	if sp.gender == "f" and sp.rank_name() != "女男爵":
		return "spouse rank_name %s" % sp.rank_name()
	if CKCourt.ladder_zh("count", "f") != "女伯爵":
		return "court ladder not gendered"
	return ""
