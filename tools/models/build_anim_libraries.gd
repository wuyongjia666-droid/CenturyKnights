extends SceneTree
## Turns archetypes_v92.json into one AnimationLibrary per weapon prototype.

func _init() -> void:
	var path := "res://assets/models/anim/archetypes_v92.json"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("archetype json missing")
		quit(1)
		return
	var data: Dictionary = parsed
	var root := str(data.get("track_root", "Rig/Skeleton3D"))
	var arches: Dictionary = data.get("archetypes", {})
	for arch_name in arches.keys():
		var lib := _library(arches[arch_name], root)
		var dest := "res://assets/models/anim/%s.res" % str(arch_name)
		var err: int = ResourceSaver.save(lib, dest)
		if err != OK:
			push_error("save %s failed %s" % [dest, err])
			quit(1)
			return
		print("SAVED ", dest)
	quit(0)

func _library(spec: Dictionary, root: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for action_name in spec.keys():
		var clip: Dictionary = spec[action_name]
		lib.add_animation(str(action_name), _animation(clip, root))
	return lib

func _animation(clip: Dictionary, root: String) -> Animation:
	var anim := Animation.new()
	anim.length = float(clip.get("length", 1.0))
	if bool(clip.get("loop", false)):
		anim.loop_mode = Animation.LOOP_LINEAR
	if clip.has("impact"):
		anim.set_meta("impact", float(clip["impact"]))
	var keys: Array = clip.get("keys", [])
	var bones := {}
	var has_root := false
	for key in keys:
		var pose: Dictionary = key.get("bones", {})
		for bone_name in pose.keys():
			bones[str(bone_name)] = true
		if key.has("root"):
			has_root = true
	for bone_name in bones.keys():
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [root, str(bone_name)]))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		for key in keys:
			var pose: Dictionary = key.get("bones", {})
			if not pose.has(bone_name):
				continue
			var xyz: Array = pose[bone_name]
			var euler := Vector3(deg_to_rad(float(xyz[0])), deg_to_rad(float(xyz[1])), deg_to_rad(float(xyz[2])))
			anim.rotation_track_insert_key(track, float(key.get("t", 0.0)), Quaternion.from_euler(euler))
	if has_root:
		var track_p := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(track_p, NodePath("%s:root" % root))
		for key in keys:
			var loc: Array = key.get("root", [0, 0, 0])
			anim.position_track_insert_key(track_p, float(key.get("t", 0.0)), Vector3(float(loc[0]), float(loc[1]), float(loc[2])))
	return anim
