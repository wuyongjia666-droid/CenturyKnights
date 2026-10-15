#!/usr/bin/env python3
"""Retopo Hunyuan farm GLBs for board pieces (voxel remesh → collapse).

Target: ≤7k tris (default 5500), height 1.85m, feet at z=0, no textures.
Does NOT use PR #301 modular kit — whole-mesh farm_cast overrides.

  blender -b -P tools/models/retopo_farm_hunyuan.py -- <src.glb> <dst.glb> [tris]
"""
from __future__ import annotations
import bpy, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if len(argv) < 2:
    raise SystemExit("usage: blender -b -P retopo_farm_hunyuan.py -- src.glb dst.glb [tris]")
SRC, DST = argv[0], argv[1]
TARGET = int(argv[2]) if len(argv) > 2 else 5500
MODEL_H = 1.85

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("no mesh in " + SRC)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = "FarmCast"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)

print("start", tris(ob))
for vs in (0.025, 0.03, 0.035, 0.04, 0.05):
    m = ob.modifiers.new("VR", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = vs
    m.adaptivity = 0.0
    bpy.context.view_layer.objects.active = ob
    try:
        bpy.ops.object.modifier_apply(modifier=m.name)
    except Exception as e:
        print("remesh fail", e)
        if m.name in ob.modifiers:
            ob.modifiers.remove(m)
        continue
    t = tris(ob)
    print(f"voxel {vs} -> {t}")
    if t <= TARGET * 3:
        break

t = tris(ob)
if t > TARGET:
    m = ob.modifiers.new("D", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = max(0.05, TARGET / float(t))
    bpy.ops.object.modifier_apply(modifier=m.name)
    print("decimate ->", tris(ob))

coords = [ob.matrix_world @ v.co for v in ob.data.vertices]
mn = Vector(tuple(min(c[i] for c in coords) for i in range(3)))
mx = Vector(tuple(max(c[i] for c in coords) for i in range(3)))
s = MODEL_H / max(1e-6, mx.z - mn.z)
ob.scale = (s, s, s)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
coords = [ob.matrix_world @ v.co for v in ob.data.vertices]
mn = Vector(tuple(min(c[i] for c in coords) for i in range(3)))
mx = Vector(tuple(max(c[i] for c in coords) for i in range(3)))
ob.location = (-0.5 * (mn.x + mx.x), -0.5 * (mn.y + mx.y), -mn.z)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
ob.data.materials.clear()
while ob.data.uv_layers:
    ob.data.uv_layers.remove(ob.data.uv_layers[0])
t = tris(ob)
zs = [v.co.z for v in ob.data.vertices]
print(f"FINAL {os.path.basename(DST)} tris={t} h={max(zs) - min(zs):.3f}")
os.makedirs(os.path.dirname(os.path.abspath(DST)) or ".", exist_ok=True)
for o in list(bpy.context.scene.objects):
    if o != ob:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.export_scene.gltf(
    filepath=DST,
    export_format="GLB",
    export_apply=True,
    export_texcoords=False,
    export_normals=True,
    export_materials="NONE",
)
print("size", os.path.getsize(DST))
