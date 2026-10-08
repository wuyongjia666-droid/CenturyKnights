"""Render key frames of every action of a GLB (workbench) -> contact sheet frames in OUT."""
import bpy, sys, os, math
argv = sys.argv[sys.argv.index("--") + 1:]
glb, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
scn = bpy.context.scene
scn.render.engine = "CYCLES"; scn.cycles.device = "CPU"; scn.cycles.samples = 12; scn.cycles.use_denoising = False
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
sun.data.energy = 4.0; sun.rotation_euler = (math.radians(50), 0, math.radians(140))
scn.render.resolution_x = 300; scn.render.resolution_y = 400
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam)
cam.location = (2.3, -2.3, 1.25); cam.rotation_euler = (math.radians(85), 0, math.radians(45)); scn.camera = cam
keys = {"idle": 1, "advance": 4, "attack": 8, "attack_i": 12, "skill": 14, "skill_i": 20, "hit": 4, "dodge": 7, "crit": 8, "crit_i": 13, "death": 30}
if rig.animation_data:
    for tr in rig.animation_data.nla_tracks: tr.mute = True
for k, f in keys.items():
    an = k.replace("_i", "")
    act = bpy.data.actions.get(an) or next((a for a in bpy.data.actions if a.name.startswith(an)), None)
    if not act: print("noact", an); continue
    rig.animation_data.action = act
    scn.frame_set(f)
    scn.render.filepath = os.path.join(out, f"{k}.png"); bpy.ops.render.render(write_still=True)
print("QA_DONE")
