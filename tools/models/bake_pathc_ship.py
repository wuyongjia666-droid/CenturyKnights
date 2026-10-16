import bpy, bmesh, json, sys
TARGET=12000; VOX=1.85/400; RES=512
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="/workspace/pathc_ship/master_cast_leader.glb")
hi=[o for o in bpy.data.objects if o.type=='MESH'][0]; hi.name="HI"
lo=hi.copy(); lo.data=hi.data.copy(); lo.name="cast_leader"; bpy.context.collection.objects.link(lo)
lo.data.materials.clear()
for uv in list(lo.data.uv_layers): lo.data.uv_layers.remove(uv)
bpy.context.view_layer.objects.active=lo
m=lo.modifiers.new("vox","REMESH"); m.mode='VOXEL'; m.voxel_size=VOX; m.adaptivity=0
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True)
bpy.ops.object.modifier_apply(modifier="vox")
tris0=sum(len(p.vertices)-2 for p in lo.data.polygons); print("VOXTRIS",tris0)
d=lo.modifiers.new("dec","DECIMATE"); d.ratio=TARGET/tris0; d.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier="dec")
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()
tris=len(lo.data.polygons); print("TRIS",tris)
img=bpy.data.images.new("cast_leader_albedo",RES,RES)
mat=bpy.data.materials.new("cast_leader_pathc_ship"); mat.use_nodes=True
nt=mat.node_tree; tex=nt.nodes.new("ShaderNodeTexImage"); tex.image=img
nt.links.new(tex.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value=0.8
nt.nodes.active=tex; lo.data.materials.append(mat)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=4; sc.cycles.device='CPU'
bk=sc.render.bake; bk.use_selected_to_active=True; bk.use_cage=False; bk.cage_extrusion=0.02; bk.max_ray_distance=0.05; bk.margin=8
bk.use_pass_direct=False; bk.use_pass_indirect=False; bk.use_pass_color=True
bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=lo
bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'})
img.filepath_raw="/workspace/pathc_ship/cast_leader_albedo.png"; img.file_format='PNG'; img.save()
bpy.data.objects.remove(hi)
bpy.ops.export_scene.gltf(filepath="/workspace/pathc_ship/cast_leader.glb", export_format='GLB', export_image_format='JPEG', export_jpeg_quality=88, export_apply=True, export_materials='EXPORT', export_yup=True)
json.dump({"voxel_size":VOX,"vox_tris":tris0,"tris":tris},open("/workspace/pathc_ship/bake_stats.json","w"))
