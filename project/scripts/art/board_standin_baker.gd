class_name CKBoardStandinBaker
extends Node
## Offscreen bake of formal board figures into 2D stand-ins (pawn-redesign-opus §3.8).
## Call bake_roster(units) once at battle start when 3D is off or DeviceProfile.is_low_end().

const W := 160
const H := 200

func bake_one(c, team: String, tmpl: String = "") -> Texture2D:
	if DisplayServer.get_name() == "headless" or c == null:
		return CKBoardFigure.standin_texture(c, team, tmpl)
	var h := CKBoardFigure.standin_hash(c, team, tmpl)
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var fig := CKBoardFigure.build(c, team, tmpl)
	fig.rotation_degrees.y = 35.0
	world.add_child(fig)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.15
	cam.current = true
	world.add_child(cam)
	cam.global_position = Vector3(0, 1.55, 2.35)
	cam.look_at(Vector3(0, 0.92, 0), Vector3.UP)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.76, 0.86)
	e.ambient_light_energy = 0.55
	we.environment = e
	world.add_child(we)
	for i in 4:
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return CKBoardFigure.standin_texture(c, team, tmpl)
	var tex := ImageTexture.create_from_image(img)
	CKBoardFigure.store_standin(h, tex)
	return tex


func bake_roster(entries: Array) -> void:
	## entries: [{char, team, template}]
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		await bake_one(e.get("char"), str(e.get("team", "player")), str(e.get("template", "")))
