import bpy, mathutils, sys, math
src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.lower().startswith('body')][0]
mw = ob.matrix_world; inv = mw.inverted()
H, y0 = 1.835, -0.019
cx, cz = 0.003, 0.050
R = 0.068
moved = 0
for v in ob.data.vertices:
    w = mw @ v.co
    gx, gy, gz = w.x, w.z, -w.y
    hy = (gy - y0) / H
    if not (0.835 < hy < 0.885):
        continue
    dx, dz = gx - cx, gz - cz
    r = math.hypot(dx, dz)
    if r <= R or r > 0.16:
        continue
    # fade in from the bottom of the band (shoulder line stays), full at jaw
    wt = min(1.0, (hy - 0.835) / 0.02) * min(1.0, (0.885 - hy) / 0.008 + 0.0001)
    wt = max(0.0, min(1.0, wt))
    nr = r + (R - r) * wt
    nx, nz = cx + dx / r * nr, cz + dz / r * nr
    v.co = inv @ mathutils.Vector((nx, -nz, gy))
    moved += 1
print("MOVED", moved)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=True, export_yup=True)
