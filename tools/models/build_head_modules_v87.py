"""v8.7 modular head attachments (Blender 4.2):  blender -b -P build_head_modules_v87.py -- <out_dir> [--qa]
Static meshes in HEAD-BONE space (origin = head bone head, Z up along the bone, face toward -Y), canonical skull
(build_standins/rig_mesh_v87 rest: head bone 1.531 -> 1.78 m). Godot attaches them with BoneAttachment3D("head") and
scales by (head bone length / 0.249). Materials: "hair" (neutral, tinted to the genome hair colour at runtime),
"skin" (ear tips, tinted to genome skin), "trim" (emissive frost), "frost_metal"."""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/head_modules"
QA = "--qa" in argv
os.makedirs(OUT, exist_ok=True)
R = math.radians
SK_C = Vector((0, 0.005, 0.125))   # skull centre (head-bone space)
SK_R = Vector((0.092, 0.104, 0.112))

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, col, rough=0.5, metal=0.0, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = 2.5
    return m

def obj_from_bm(bm, name, material):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material)
    return ob

def cap(front_z=0.135, back_z=0.03, side_z=0.07, scale=1.10, thick=0.014, part_x=None):
    """skull shell above a hairline: high at the forehead, low at the nape, ears free"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=24, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * SK_R.x * scale, v.co.y * SK_R.y * scale, v.co.z * SK_R.z * scale)) + SK_C
    kill = []
    for v in bm.verts:
        p = v.co - SK_C
        ang = math.atan2(p.x, -p.y)  # 0 = front, +-pi = back
        t = abs(ang) / math.pi       # 0 front .. 1 back
        side = math.sin(abs(ang)) ** 2
        line = (1 - t) * front_z + t * back_z
        line = line * (1 - side) + side_z * side if t < 0.75 else line
        if v.co.z < line:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    ob = obj_from_bm(bm, "cap", MH)
    md = ob.modifiers.new("solid", "SOLIDIFY"); md.thickness = thick; md.offset = 1
    return ob

def clump(p0, p1, r0, r1, bend=Vector((0, 0, 0)), seg=8, ring=8, name="clump"):
    """tapered curved strand clump p0->p1 with a mid bend"""
    bm = bmesh.new(); p0 = Vector(p0); p1 = Vector(p1)
    rings = []
    for i in range(seg + 1):
        t = i / seg
        c = p0.lerp(p1, t) + bend * math.sin(math.pi * t)
        nxt = p0.lerp(p1, min(1, t + 0.01)) + bend * math.sin(math.pi * min(1, t + 0.01))
        d = (nxt - c).normalized() if i < seg else (p1 - (p0.lerp(p1, 0.99) + bend * math.sin(math.pi * 0.99))).normalized()
        q = Vector((0, 0, 1)).rotation_difference(d)
        r = r0 + (r1 - r0) * t
        rings.append([bm.verts.new(c + q @ Vector((math.cos(a) * r, math.sin(a) * r * 0.55, 0))) for a in [2 * math.pi * k / ring for k in range(ring)]])
    for i in range(seg):
        for k in range(ring):
            bm.faces.new([rings[i][k], rings[i][(k + 1) % ring], rings[i + 1][(k + 1) % ring], rings[i + 1][k]])
    tip = bm.verts.new(rings[-1][0].co.lerp(rings[-1][ring // 2].co, 0.5))
    for k in range(ring):
        bm.faces.new([rings[-1][k], rings[-1][(k + 1) % ring], tip])
    return obj_from_bm(bm, name, MH)

def on_skull(theta, phi, s=1.08):
    """point on the scaled skull: theta = azimuth (0 front, + toward +x), phi = elevation"""
    d = Vector((math.sin(theta) * math.cos(phi), -math.cos(theta) * math.cos(phi), math.sin(phi)))
    return SK_C + Vector((d.x * SK_R.x * s, d.y * SK_R.y * s, d.z * SK_R.z * s))

def fringe(n, spread, phi0, drop, fwd=0.03, r0=0.016, side_sweep=0.0):
    obs = []
    for i in range(n):
        th = -spread / 2 + spread * i / max(1, n - 1)
        p0 = on_skull(th, phi0)
        p1 = p0 + Vector((math.sin(th) * 0.02 + side_sweep, -fwd, -drop))
        obs.append(clump(p0, p1, r0, 0.002, bend=Vector((0, -0.012, 0.004))))
    return obs

def finish(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = name
    bpy.ops.object.shade_smooth()
    md = ob.modifiers.new("sub", "SUBSURF"); md.levels = 1
    bpy.ops.object.modifier_apply(modifier=md.name)
    return ob

def style(sid):
    o = [cap()]
    if sid == "crop":
        o = [cap(front_z=0.15, back_z=0.06, side_z=0.10, scale=1.06, thick=0.012)]
        o += fringe(9, 1.6, 0.55, 0.02, fwd=0.015, r0=0.014)
    elif sid == "swept":
        o = [cap(front_z=0.14, back_z=0.07, side_z=0.11, scale=1.06)]
        for i in range(11):
            th = -0.7 + 1.4 * i / 10
            p0 = on_skull(th, 0.75, 1.10); p1 = on_skull(th * 1.3 + math.copysign(0.2, th), 0.15, 1.18) + Vector((0, 0.06, 0.02))
            o.append(clump(p0, p1, 0.024, 0.004, bend=Vector((0, 0.0, 0.03))))
    elif sid == "tied":
        o += fringe(7, 1.4, 0.45, 0.05, fwd=0.02)
        base = on_skull(math.pi, 0.0, 1.05)
        o.append(clump(base, base + Vector((0, 0.05, -0.20)), 0.03, 0.008, bend=Vector((0, 0.025, 0))))
    elif sid == "messy":
        o += fringe(9, 1.9, 0.5, 0.075, fwd=0.03, r0=0.02)
        for i in range(10):
            th = 2 * math.pi * i / 10
            p0 = on_skull(th, 0.9, 1.08); p1 = on_skull(th + 0.3, 0.35, 1.25)
            o.append(clump(p0, p1, 0.022, 0.003, bend=Vector((0, 0, 0.03))))
    elif sid == "long":
        o += fringe(8, 1.5, 0.5, 0.07, fwd=0.03, side_sweep=0.0)
        for i in range(15):
            th = math.pi * (0.35 + 1.3 * i / 14)
            p0 = on_skull(th, 0.25, 1.08); p1 = p0 + Vector((math.sin(th) * 0.05, 0.03, -0.36))
            o.append(clump(p0, p1, 0.03, 0.006, bend=Vector((math.sin(th) * 0.02, 0.025, 0))))
    elif sid == "pony":
        o += fringe(6, 1.3, 0.5, 0.06, fwd=0.025)
        base = on_skull(math.pi, 0.75, 1.08)
        o.append(clump(base, base + Vector((0, 0.10, -0.30)), 0.035, 0.006, bend=Vector((0, 0.06, 0.04)), seg=12))
        o.append(clump(on_skull(0.95, 0.05), on_skull(0.95, 0.05) + Vector((0.01, -0.01, -0.12)), 0.01, 0.002))
        o.append(clump(on_skull(-0.95, 0.05), on_skull(-0.95, 0.05) + Vector((-0.01, -0.01, -0.12)), 0.01, 0.002))
    elif sid == "bob":
        o += fringe(9, 1.5, 0.48, 0.065, fwd=0.03)
        for i in range(16):
            th = math.pi * (0.28 + 1.44 * i / 15)
            p0 = on_skull(th, 0.35, 1.10); p1 = p0 + Vector((math.sin(th) * 0.03, -math.cos(th) * 0.02, -0.15))
            o.append(clump(p0, p1, 0.032, 0.012, bend=Vector((math.sin(th) * 0.02, 0, 0))))
    elif sid == "crown":
        o += fringe(5, 1.2, 0.5, 0.04, fwd=0.02)
        bm = bmesh.new(); bmesh.ops.create_circle(bm, segments=1, radius=0.0)
        bm.free()
        for i in range(18):  # braid ring of overlapping clumps
            a0 = 2 * math.pi * i / 18; a1 = 2 * math.pi * (i + 1.4) / 18
            p0 = on_skull(a0, 0.55, 1.15); p1 = on_skull(a1, 0.55, 1.15)
            o.append(clump(p0, p1, 0.022, 0.016, bend=Vector((0, 0, 0.012)), seg=4))
        o.append(clump(on_skull(0.9, 0.0), on_skull(0.9, 0.0) + Vector((0.01, -0.01, -0.14)), 0.009, 0.002))
    return finish(o, "Hair_" + sid)

def ears():
    objs = []
    for sx in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.016, radius2=0.0, depth=0.055)
        for v in bm.verts:
            v.co.y *= 0.45
        ob = obj_from_bm(bm, "ear", MS)
        ob.location = (sx * (SK_R.x + 0.006), 0.012, 0.085)
        ob.rotation_euler = (R(-25), sx * R(62), 0)
        objs.append(ob)
    return finish(objs, "EarTips_crest")

def circlet():
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.05, major_segments=48, minor_segments=8)
    ob = bpy.context.active_object
    ob.scale = (SK_R.x * 1.16, SK_R.y * 1.16, SK_R.x * 1.16); ob.location = SK_C + Vector((0, -0.004, 0.035)); ob.rotation_euler = (R(-12), 0, 0)
    ob.data.materials.append(MM)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.014, location=SK_C + Vector((0, -SK_R.y * 1.18, 0.05)))
    gem = bpy.context.active_object; gem.scale = (0.7, 0.5, 1.3); gem.data.materials.append(MT)
    return finish([ob, gem], "Circlet_rime")

def export(ob, name):
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    p = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", use_selection=True, export_yup=True, export_materials="EXPORT")
    print("MODULE", p, len(ob.data.polygons))

STYLES = ["crop", "swept", "tied", "messy", "long", "pony", "bob", "crown"]
reset()
MH = mat("hair", (0.75, 0.77, 0.80), 0.45)
MS = mat("skin", (0.85, 0.70, 0.62), 0.55)
MM = mat("frost_metal", (0.80, 0.85, 0.92), 0.25, 0.9)
MT = mat("trim", (0.43, 0.83, 1.0), 0.3, 0.0, (0.43, 0.83, 1.0))
made = []
for s in STYLES:
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    export(style(s), "hair_" + s)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
export(ears(), "ears_crest")
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
export(circlet(), "honor_rime_circlet")

if QA:
    # contact sheet: each module on a grey skull, Cycles CPU, key upper-left (style lock)
    reset()
    scn = bpy.context.scene; scn.render.engine = "CYCLES"; scn.cycles.device = "CPU"; scn.cycles.samples = 16; scn.cycles.use_denoising = False
    scn.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun); sun.data.energy = 3.5; sun.rotation_euler = (R(40), 0, R(-45))
    skin = mat("qa_skin", (0.85, 0.70, 0.62), 0.55)
    cols = {"crop": (0.10, 0.10, 0.12), "swept": (0.36, 0.29, 0.25), "tied": (0.55, 0.23, 0.20), "messy": (0.79, 0.69, 0.52), "long": (0.85, 0.89, 0.93), "pony": (0.10, 0.10, 0.12), "bob": (0.79, 0.69, 0.52), "crown": (0.85, 0.89, 0.93)}
    for i, s in enumerate(STYLES + ["ears_crest", "honor_rime_circlet"]):
        x = (i % 5) * 0.42; z = -(i // 5) * 0.5
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(x + SK_C.x, SK_C.y, z + SK_C.z)); sk = bpy.context.active_object
        sk.scale = SK_R; sk.data.materials.append(skin); bpy.ops.object.shade_smooth()
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, ("hair_" + s if s in STYLES else s) + ".glb"))
        for o in bpy.context.selected_objects:
            o.location.x += x; o.location.z += z
            if s in cols:
                m = mat("qa_hair_" + s, cols[s], 0.45); o.data.materials.clear(); o.data.materials.append(m)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.3; cam.location = (0.85, -3.0, -0.1); cam.rotation_euler = (R(84), 0, R(-6))
    scn.render.resolution_x = 1200; scn.render.resolution_y = 560
    scn.render.filepath = os.path.join(OUT, "qa_head_modules.png"); bpy.ops.render.render(write_still=True)
