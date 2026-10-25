extends Node
## Fat heraldry E2E: deploy muster strip + DeployArms/FocusArms; train RowArms;
## title ladder MusterCrestStrip + LadderBadge + LeaderArms. Desktop + mobile.

const DEPLOY_SCN := preload("res://scenes/hub/deploy.tscn")
const TRAIN_SCN := preload("res://scenes/hub/train.tscn")
const TITLE_SCN := preload("res://scenes/hub/title_promote.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("DEPLOY TRAIN CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL deploy train crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("出征", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	## Ensure at least the leader is deployable.
	var leader = GameState.get_leader()
	if leader != null and not (leader.id in GameState.deploy_ids):
		GameState.deploy_ids = [leader.id]

func _assert_muster(page: Node, where: String) -> void:
	var strip := page.find_child("MusterCrestStrip", true, false)
	_ok(strip != null, "%s MusterCrestStrip" % where)
	if strip == null:
		return
	var ca := strip.find_child("CastleArms", true, false)
	var la := strip.find_child("LeaderArms", true, false)
	_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
	_ok(la != null and str(la.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s LeaderArms kind" % where)
	if ca != null and la != null:
		_ok(str(ca.get_meta("arms_core", "")) != str(la.get_meta("arms_core", "")), "%s 团徽≠族徽" % where)

func _collect(n: Node, name: String, out: Array) -> void:
	if n.name == name:
		out.append(n)
	for c in n.get_children():
		_collect(c, name, out)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var leader = GameState.get_leader()
	var fam := CKHeraldry.core_key(GameState.arms_for_character(leader))

	var dep: Control = DEPLOY_SCN.instantiate()
	get_tree().root.add_child(dep)
	await _settle(12)
	_assert_muster(dep, "desk-deploy")
	var darms := []
	_collect(dep, "DeployArms", darms)
	_ok(darms.size() >= 1, "desk-deploy DeployArms count")
	var saw_fam := false
	for a in darms:
		var k := str(a.get_meta("arms_kind", ""))
		_ok(k in ["gen2_06", "gen2_35"], "desk-deploy DeployArms kind")
		if k == "gen2_06":
			saw_fam = true
			_ok(str(a.get_meta("arms_core", "")) == fam, "desk-deploy leader DeployArms core")
	_ok(saw_fam, "desk-deploy saw 族徽")
	var fa := dep.find_child("FocusArms", true, false)
	_ok(fa != null and str(fa.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "desk-deploy FocusArms")
	dep.queue_free()
	await _settle(2)

	var train: Control = TRAIN_SCN.instantiate()
	get_tree().root.add_child(train)
	await _settle(12)
	_assert_muster(train, "desk-train")
	var rows := []
	_collect(train, "RowArms", rows)
	## Pupils / tutors / promo rows — may be empty early-game; API strip still asserted.
	for a in rows:
		_ok(str(a.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "desk-train RowArms kind")
	train.queue_free()
	await _settle(2)

	var title: Control = TITLE_SCN.instantiate()
	get_tree().root.add_child(title)
	await _settle(12)
	_assert_muster(title, "desk-title")
	var badges := []
	_collect(title, "LadderBadge", badges)
	_ok(badges.size() >= 4, "desk-title LadderBadge count")
	var tla := title.find_child("LeaderArms", true, false)
	_ok(tla != null and str(tla.get_meta("arms_core", "")) == fam, "desk-title LeaderArms")
	_ok(str(tla.get_meta("arms_core", "")) != ban if tla else false, "desk-title LeaderArms ≠ 团徽")
	title.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var dep: Control = DEPLOY_SCN.instantiate()
	get_tree().root.add_child(dep)
	await _settle(8)
	if dep.has_method("apply_mobile_layout"):
		dep.apply_mobile_layout()
		await _settle(10)
	_assert_muster(dep, "mob-deploy")
	var strip := dep.find_child("MusterCrestStrip", true, false) as Control
	if strip != null:
		_ok(strip.position.x >= 200.0, "mob-deploy muster right-anchored")
	var darms := []
	_collect(dep, "DeployArms", darms)
	_ok(darms.size() >= 1, "mob-deploy DeployArms")
	var fa := dep.find_child("FocusArms", true, false)
	_ok(fa != null, "mob-deploy FocusArms")
	dep.queue_free()
	await _settle(2)

	var train: Control = TRAIN_SCN.instantiate()
	get_tree().root.add_child(train)
	await _settle(8)
	if train.has_method("apply_mobile_layout"):
		train.apply_mobile_layout()
		await _settle(8)
	_assert_muster(train, "mob-train")
	train.queue_free()
	await _settle(2)

	var title: Control = TITLE_SCN.instantiate()
	get_tree().root.add_child(title)
	await _settle(8)
	if title.has_method("apply_mobile_layout"):
		title.apply_mobile_layout()
		await _settle(8)
	_assert_muster(title, "mob-title")
	var badges := []
	_collect(title, "LadderBadge", badges)
	_ok(badges.size() >= 4, "mob-title LadderBadge")
	title.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
