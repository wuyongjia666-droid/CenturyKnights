import bpy, bmesh, json, sys
import sys
A=sys.argv[sys.argv.index("--")+1:]
SRC,OUT,TARGET=A[0],A[1],int(A[2]); VOX=1.85/400; RES=512; STEM=OUT.split("/")[-1][:-4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
hi=[o for o in bpy.data.objects if o.type=='MESH'][0]; hi.name="HI"
lo=hi.copy(); lo.data=hi.data.copy(); lo.name=STEM; bpy.context.collection.objects.link(lo)
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
img=bpy.data.images.new(STEM+"_albedo",RES,RES)
mat=bpy.data.materials.new(STEM+"_pathc_ship"); mat.use_nodes=True
nt=mat.node_tree; tex=nt.nodes.new("ShaderNodeTexImage"); tex.image=img
nt.links.new(tex.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value=0.8
nt.nodes.active=tex; lo.data.materials.append(mat)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=4; sc.cycles.device='CPU'
bk=sc.render.bake; bk.use_selected_to_active=True; bk.use_cage=False; bk.cage_extrusion=0.02; bk.max_ray_distance=0.05; bk.margin=8
bk.use_pass_direct=False; bk.use_pass_indirect=False; bk.use_pass_color=True
bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=lo
for m in hi.data.materials:
    t=m.node_tree; P=[n for n in t.nodes if n.type=='BSDF_PRINCIPLED'][0]
    bc=P.inputs['Base Color'].links[0].from_socket
    mt=P.inputs['Metallic'].links[0].from_socket if P.inputs['Metallic'].links else None
    # perceived metal: luminance of base lifted toward silver only where metallic AND base is greyish-bright
    lift=t.nodes.new('ShaderNodeMix'); lift.data_type='RGBA'
    t.links.new(bc, lift.inputs[6]); lift.inputs[7].default_value=(0.60,0.62,0.66,1); lift.inputs[0].default_value=0.5
    mr=t.nodes.new('ShaderNodeMapRange'); mr.inputs[1].default_value=0.85; mr.inputs[2].default_value=1.0
    rgbbw=t.nodes.new('ShaderNodeRGBToBW'); t.links.new(bc, rgbbw.inputs[0])
    lr=t.nodes.new('ShaderNodeMapRange'); lr.inputs[1].default_value=0.12; lr.inputs[2].default_value=0.30
    t.links.new(rgbbw.outputs[0], lr.inputs[0])
    mul=t.nodes.new('ShaderNodeMath'); mul.operation='MULTIPLY'
    if mt: t.links.new(mt, mr.inputs[0])
    else: mr.inputs[0].default_value=0
    t.links.new(mr.outputs[0], mul.inputs[0]); t.links.new(lr.outputs[0], mul.inputs[1])
    mx=t.nodes.new('ShaderNodeMix'); mx.data_type='RGBA'; t.links.new(mul.outputs[0], mx.inputs[0])
    t.links.new(bc, mx.inputs[6]); t.links.new(lift.outputs[2], mx.inputs[7])
    em=t.nodes.new('ShaderNodeEmission'); t.links.new(mx.outputs[2], em.inputs[0])
    out=[n for n in t.nodes if n.type=='OUTPUT_MATERIAL'][0]; t.links.new(em.outputs[0], out.inputs[0])
bpy.ops.object.bake(type='EMIT')
img.filepath_raw=OUT[:-4]+"_albedo.png"; img.file_format='PNG'; img.save()
bpy.data.objects.remove(hi)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=88, export_apply=True, export_materials='EXPORT', export_yup=True)
json.dump({"voxel_size":VOX,"vox_tris":tris0,"tris":tris},open(OUT[:-4]+"_stats.json","w"))
