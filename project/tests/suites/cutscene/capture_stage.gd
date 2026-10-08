extends Node
## Contact sheet of the 14 biome stages. CK_CUTSCENE_OUT sets the folder.

const CELL_W := 320
const CELL_H := 180

func _ready() -> void:
	var dir := OS.get_environment("CK_CUTSCENE_OUT")
	if dir == "":
		dir = "/tmp/ck_stage"
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.72)
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 16)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color8(26, 36, 51)
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.look_at_from_position(Vector3(0, 2.4, 8.5), Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	world.add_child(cam)
	var sheet := Image.create(CELL_W * 4, CELL_H * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(7, 8, 12))
	var ids: Array = CutsceneStage.biome_ids()
	var font: Font = load("res://assets/fonts/NotoSansSC-Bold-ck.otf")
	for i in ids.size():
		var id := str(ids[i])
		var stage := CutsceneStage.build(world, id, false)
		var fog: Dictionary = CutsceneStage.fog_for(id)
		e.background_color = fog.get("color", Color8(16, 19, 26))
		e.fog_enabled = true
		e.fog_light_color = fog.get("color", Color8(16, 19, 26))
		e.fog_density = float(fog.get("density", 0.03))
		var label := Label3D.new()
		label.text = id
		label.font = font
		label.font_size = 48
		label.pixel_size = 0.01
		label.modulate = Color8(244, 247, 251)
		label.outline_modulate = Color8(10, 14, 20)
		label.outline_size = 8
		label.position = Vector3(0, 3.2, -2)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		for _k in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img == null:
			print("CAPTURE FAIL image")
			get_tree().quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL_W, CELL_H, Image.INTERPOLATE_LANCZOS)
		var col := i % 4
		var row := int(i / 4)
		sheet.blit_rect(img, Rect2i(0, 0, CELL_W, CELL_H), Vector2i(col * CELL_W, row * CELL_H))
		stage.queue_free()
		label.queue_free()
		await get_tree().process_frame
	var path := dir.path_join("biomes.png")
	if sheet.save_png(path) != OK:
		print("CAPTURE FAIL save")
		get_tree().quit(1)
		return
	print("still ", path)
	print("CAPTURE OK ", dir)
	get_tree().quit(0)
