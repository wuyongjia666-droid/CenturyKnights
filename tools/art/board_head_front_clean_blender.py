import bpy, math, mathutils, sys
src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.lower().startswith('body')][0]
me = ob.data
# glTF (x, y_up, z_fwd) -> Blender (x, -z, y)
cx, yc, zc = -0.0076, 1.650, 0.036
rx, ry, rz = 0.080, 0.115, 0.115
moved = 0
mw = ob.matrix_world
inv = mw.inverted()
for v in me.vertices:
    w = mw @ v.co
    gx, gy, gz = w.x, w.z, -w.y
    if not (1.545 < gy < 1.725):
        continue
    dx, dy, dz = gx - cx, gy - yc, gz - zc
    if dz <= 0.0 or abs(dx) > 0.075:
        continue
    # weight: full in the face core, fade toward edges
    wx = max(0.0, 1.0 - max(0.0, abs(dx) - 0.045) / 0.03)
    wy = max(0.0, 1.0 - max(0.0, abs(dy) - 0.06) / 0.03)
    wt = wx * wy
    if wt <= 0:
        continue
    d = mathutils.Vector((dx / rx, dy / ry, dz / rz))
    if d.length < 1e-6:
        continue
    s = 1.0 / d.length
    tx, ty, tz = cx + dx * s, yc + dy * s, zc + dz * s
    nx, ny, nz = gx + (tx - gx) * wt, gy + (ty - gy) * wt, gz + (tz - gz) * wt
    v.co = inv @ mathutils.Vector((nx, -nz, ny))
    moved += 1
print("MOVED", moved)
# smooth the patch a little
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=True, export_yup=True)
