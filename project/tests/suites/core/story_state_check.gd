extends Node
## CORE-01: chapter fields live in CKStoryState, old names still read and write, v9.1 saves migrate.

const FIXTURE := "res://tests/suites/core/fixtures/save_v91.json"
const SOURCE := "res://autoload/game_state.gd"
const BASELINE_LINES := 3468

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = await run(self)
	if fails.is_empty():
		print("STORY STATE PASS load_count=%d" % CKStoryState.load_count)
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL story: ", f)
	get_tree().quit(1)

static func run(host: Node):
	var fails: Array = []
	var boot := CKStoryState.load_count
	await host.get_tree().process_frame
	_src(fails)
	if boot > 1:
		fails.append("boot parsed %d chapter files" % boot)
	var menu_ps = load("res://scenes/ui/main_menu.tscn")
	if menu_ps == null:
		fails.append("main menu missing")
	else:
		var menu = menu_ps.instantiate()
		host.add_child(menu)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		if CKStoryState.load_count > 1:
			fails.append("menu startup parsed %d chapter files" % CKStoryState.load_count)
		menu.queue_free()
	var before := CKStoryState.load_count
	var chapter = GameState.data_chapter11
	if chapter.get("beats", []).size() < 1:
		fails.append("chapter 11 json empty")
	if CKStoryState.load_count != before + 1:
		fails.append("lazy parse %d -> %d" % [before, CKStoryState.load_count])
	var cached := CKStoryState.load_count
	GameState.story.chapter_data(11)
	if CKStoryState.load_count != cached:
		fails.append("chapter 11 reparsed")
	GameState.chapter4_beat = "4.6"
	if str(GameState.chapter4_beat) != "4.6" or GameState.story.beat(4) != "4.6":
		fails.append("shim beat write/read got %s" % str(GameState.chapter4_beat))
	GameState.chapter0_flags["married"] = true
	if not GameState.flag("married"):
		fails.append("flag shim did not mutate the live dictionary")
	_fixture(fails)
	GameState.new_game("烬行", "灰旗", str(GameState.crest_color))
	if GameState.story.current_chapter() != 0 or GameState.story.unlocked_count() != 1:
		fails.append("fresh chapter cursor %d / %d" % [GameState.story.current_chapter(), GameState.story.unlocked_count()])
	if str(GameState.chapter0_beat) != "0.0":
		fails.append("new_game beat %s" % str(GameState.chapter0_beat))
	GameState.chapter5_beat = "5.3"
	if GameState.story.current_chapter() != 5 or GameState.story.unlocked_count() != 6:
		fails.append("progress cursor %d / %d" % [GameState.story.current_chapter(), GameState.story.unlocked_count()])
	return fails

static func _src(fails: Array) -> void:
	var txt := FileAccess.get_file_as_string(SOURCE)
	if txt == "":
		fails.append("game_state source unreadable")
		return
	var re := RegEx.new()
	re.compile("^var (data_chapter|chapter)[0-9]+")
	var bad := 0
	for line in txt.split("\n"):
		if re.search(line) != null:
			bad += 1
	if bad != 0:
		fails.append("chapter field declarations %d" % bad)
	var n := txt.count("\n")
	if BASELINE_LINES - n < 900:
		fails.append("line drop %d" % (BASELINE_LINES - n))

static func _fixture(fails: Array) -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if typeof(fixture) != TYPE_DICTIONARY:
		fails.append("fixture is not an object")
		return
	if not GameState.apply_save_data(fixture):
		fails.append("apply v9.1 fixture")
		return
	for i in CKStoryState.CHAPTER_COUNT:
		var want := str(fixture.get("chapter%d_beat" % i, ""))
		var got := str(GameState.get("chapter%d_beat" % i))
		if got != want:
			fails.append("beat %d got %s want %s" % [i, got, want])
			return
	if str(GameState.chapter0_beat) != str(fixture["chapter0_beat"]):
		fails.append("dot chapter0")
	if str(GameState.chapter234_beat) != str(fixture["chapter234_beat"]):
		fails.append("dot chapter234")
	if not GameState.flag("married") or not bool(GameState.chapter0_flags.get("chapter3_done", false)):
		fails.append("fixture flags")
	if GameState.silver != 321:
		fails.append("fixture silver %d" % GameState.silver)
	if not GameState.save_game():
		fails.append("resave")
		return
	var written = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	if typeof(written) != TYPE_DICTIONARY:
		fails.append("resave json")
		return
	var block = written.get("story", {})
	if typeof(block) != TYPE_DICTIONARY or typeof(block.get("beats", null)) != TYPE_DICTIONARY:
		fails.append("story.beats missing")
		return
	if written.has("chapter7_beat"):
		fails.append("legacy beat key still written")
	if str(block["beats"].get("7", "")) != str(fixture["chapter7_beat"]):
		fails.append("saved beat 7")
	GameState.chapter7_beat = "7.0"
	GameState.chapter200_beat = "200.0"
	if not GameState.load_game():
		fails.append("reload")
		return
	for i in CKStoryState.CHAPTER_COUNT:
		var want2 := str(fixture.get("chapter%d_beat" % i, ""))
		var got2 := str(GameState.get("chapter%d_beat" % i))
		if got2 != want2:
			fails.append("reload beat %d got %s want %s" % [i, got2, want2])
			return
	if not GameState.flag("chapter3_done"):
		fails.append("reload flag")
