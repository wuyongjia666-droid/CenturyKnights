"""Fake 'Hunyuan output' for pipeline tests: stand-in knight posed in an A-pose (arms 35deg), no weapon, voxel-remeshed
into one unrigged surface, arbitrary scale/offset, plus a FRONT|BACK turnaround sheet rendered on #D9DEE3.
  blender -b -P make_test_body_v87.py -- <out_dir>"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_standins_v86 as K
out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
K.reset(); K.build_mats(); K.PARTS.clear()
rig = K.build_armature()
K.ARCH["test"] = ("none", {"cape": False, "pauldron": 1.1})
_bw = K.build_weapon
K.build_weapon = lambda *a, **k: None
K.build_body("test")
K.build_weapon = _bw
body = K.bind(rig)
bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode="POSE")
for s, sx in (("L", 1), ("R", -1)):
    pb = rig.pose.bones[f"upper_arm.{s}"]; pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, sx * math.radians(-23), 0)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_apply(modifier="Armature")
body.parent = None
bpy.data.objects.remove(rig, do_unlink=True)
# sheet render (front cam at -Y, back cam at +Y), ortho, plate bg
scn = bpy.context.scene
scn.render.engine = "CYCLES"; scn.cycles.device = "CPU"; scn.cycles.samples = 16; scn.cycles.use_denoising = False
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.69, 0.73, 0.77, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
scn.view_settings.view_transform = "Standard"
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(40), 0, math.radians(-45))
scn.render.resolution_x = 768; scn.render.resolution_y = 1024
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); scn.collection.objects.link(cam); scn.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.2
for name, loc, rot in (("front", (0, -5, 0.95), (math.radians(90), 0, 0)), ("back", (0, 5, 0.95), (math.radians(90), 0, math.radians(180)))):
    cam.location = loc; cam.rotation_euler = rot
    scn.render.filepath = os.path.join(out, f"_{name}.png"); bpy.ops.render.render(write_still=True)
a = bpy.data.images.load(os.path.join(out, "_front.png")); b = bpy.data.images.load(os.path.join(out, "_back.png"))
import numpy as np
pa = np.array(a.pixels[:]).reshape(1024, 768, 4); pb_ = np.array(b.pixels[:]).reshape(1024, 768, 4)
sheet = bpy.data.images.new("sheet", 1536, 1024); sheet.pixels = np.concatenate([pa, pb_], 1).flatten().tolist()
sheet.filepath_raw = os.path.join(out, "sheet.png"); sheet.file_format = "PNG"; sheet.save()
# make it look like a farmed mesh: one voxel surface, no materials/rig, odd transform
md = body.modifiers.new("vox", "REMESH"); md.mode = "VOXEL"; md.voxel_size = 0.012
bpy.ops.object.modifier_apply(modifier=md.name)
body.vertex_groups.clear(); body.data.materials.clear()
body.scale = (1.31, 1.31, 1.31); body.location = (0.4, -0.2, 0.25)
bpy.ops.object.select_all(action="DESELECT"); body.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "raw_body.glb"), export_format="GLB", use_selection=True, export_materials="NONE")
print("TEST", os.path.join(out, "raw_body.glb"), len(body.data.polygons))
