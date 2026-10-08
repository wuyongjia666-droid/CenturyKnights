extends Node
## CORE-03: corrupt slots fall back to a backup, legacy schemas migrate, slots stay separate.

const FIXTURES := "res://tests/suites/core/fixtures"

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	_clear_slots()
	_interrupt(fails)
	_corrupt("save_trunc.json", fails)
	_corrupt("save_garbage.json", fails)
	_corrupt("save_empty.json", fails)
	_legacy("save_v87.json", "v8.7", 40, fails)
	_legacy("save_v88.json", "v8.8", 48, fails)
	_legacy("save_v91.json", "v9.1", 321, fails)
	_slots(fails)
	_meta_without_body(fails)
	_clear_slots()
	if fails.is_empty():
		print("SAVE CORRUPTION PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL save-corruption: ", f)
	get_tree().quit(1)

func _interrupt(fails: Array) -> void:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.silver = 111
	if not GameState.save_to_slot("manual_0"):
		fails.append("interrupt first save")
		return
	var tmp := CKSaveService.body_path("manual_0") + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		fails.append("interrupt tmp")
		return
	f.store_string("{\"schema\":\"v9.2\",\"silver\":999}")
	f.flush()
	f.close()
	if not GameState.load_from_slot("manual_0"):
		fails.append("interrupt load")
		return
	if GameState.silver != 111:
		fails.append("interrupt kept %d" % GameState.silver)
	if FileAccess.file_exists(tmp) == false:
		fails.append("tmp was consumed")

func _corrupt(file_name: String, fails: Array) -> void:
	_clear_slots()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.silver = 111
	if not GameState.save_to_slot("manual_0"):
		fails.append("%s seed" % file_name)
		return
	GameState.silver = 222
	if not GameState.save_to_slot("manual_0"):
		fails.append("%s second" % file_name)
		return
	var body := FileAccess.get_file_as_string("%s/%s" % [FIXTURES, file_name])
	var out := FileAccess.open(CKSaveService.body_path("manual_0"), FileAccess.WRITE)
	if out == null:
		fails.append("%s overwrite" % file_name)
		return
	out.store_string(body)
	out.close()
	if not GameState.load_from_slot("manual_0"):
		fails.append("%s load" % file_name)
		return
	if GameState.silver != 111:
		fails.append("%s silver %d" % [file_name, GameState.silver])
	if GameState.save_notice != Locale.t("save_corrupt_rollback"):
		fails.append("%s notice %s" % [file_name, GameState.save_notice])
	if GameState.save_backup_used != "bak1":
		fails.append("%s backup %s" % [file_name, GameState.save_backup_used])

func _legacy(file_name: String, schema: String, silver: int, fails: Array) -> void:
	_clear_slots()
	var body := FileAccess.get_file_as_string("%s/%s" % [FIXTURES, file_name])
	var out := FileAccess.open(CKSaveService.body_path("manual_1"), FileAccess.WRITE)
	if out == null:
		fails.append("%s write" % schema)
		return
	out.store_string(body)
	out.close()
	if not GameState.load_from_slot("manual_1"):
		fails.append("%s load %s" % [schema, GameState.save_notice])
		return
	if GameState.silver != silver:
		fails.append("%s silver %d" % [schema, GameState.silver])
	var want := Locale.t("save_migrated", [schema])
	if GameState.save_notice != want:
		fails.append("%s notice %s" % [schema, GameState.save_notice])
	if str(GameState.build_save_data().get("schema", "")) != "v9.2":
		fails.append("%s resave schema" % schema)

func _slots(fails: Array) -> void:
	_clear_slots()
	for i in 3:
		GameState.new_game("团%d" % i, "灰旗", GameState.crest_color)
		GameState.silver = 100 + i
		GameState.play_seconds = 10.0 + i
		if not GameState.save_to_slot("manual_%d" % i):
			fails.append("slot %d save" % i)
			return
	for i in 3:
		if not GameState.load_from_slot("manual_%d" % i):
			fails.append("slot %d load" % i)
			return
		if GameState.silver != 100 + i:
			fails.append("slot %d silver %d" % [i, GameState.silver])
		var meta := CKSaveService.read_meta("manual_%d" % i)
		if str(meta.get("leader", "")) == "":
			fails.append("slot %d leader" % i)
		if int(meta.get("chapter", -1)) < 0:
			fails.append("slot %d chapter" % i)
		if not is_equal_approx(float(meta.get("play_seconds", -1)), 10.0 + i):
			fails.append("slot %d play" % i)
		if str(meta.get("schema", "")) != "v9.2":
			fails.append("slot %d schema" % i)
		var path := CKSaveService.body_path("manual_%d" % i)
		if str(meta.get("sha256", "")) != FileAccess.get_sha256(path):
			fails.append("slot %d sha" % i)
		if int(meta.get("bytes", -1)) != FileAccess.get_file_as_bytes(path).size():
			fails.append("slot %d bytes" % i)

func _meta_without_body(fails: Array) -> void:
	var meta := CKSaveService.read_meta("manual_0")
	var leader := str(meta.get("leader", ""))
	var out := FileAccess.open(CKSaveService.body_path("manual_0"), FileAccess.WRITE)
	if out == null:
		fails.append("meta smash")
		return
	out.store_string("%%%%")
	out.close()
	var again := CKSaveService.read_meta("manual_0")
	if str(again.get("leader", "")) != leader or leader == "":
		fails.append("meta unreadable after smash")
	if str(again.get("version", "missing")) == "missing":
		fails.append("meta version")

func _clear_slots() -> void:
	for slot in CKSaveService.SLOTS:
		for suffix in ["", ".tmp", ".bak1", ".bak2", ".bak3", ".meta.json", ".meta.json.tmp", ".meta.json.bak1", ".meta.json.bak2", ".meta.json.bak3"]:
			var path: String = CKSaveService.body_path(slot) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
