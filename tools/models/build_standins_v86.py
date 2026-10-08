"""v8.6 stand-in 3D units (Blender 4.2, run: blender -b -P build_standins_v86.py -- <out_dir> [archetype...]).
Contemporary-fantasy frosted-chrome armor kit on a shared humanoid armature (rigid skin) + shared action set:
idle, advance, attack, skill, hit, dodge, crit, death. Materials are named slots (armor/cloth/trim/visor/skin/
leather/weapon) so Godot recolors per character/team. Hunyuan3D GLBs (when farmed on m173) are auto-rigged onto
this SAME armature (see rig_hunyuan_v86.py) and reuse these actions."""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix, Euler
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if (argv and __name__ == "__main__") else "/tmp/standins"
WANT = argv[1:] if __name__ == "__main__" else []
os.makedirs(OUT, exist_ok=True)
R = math.radians

ARCH = {
    # name: (weapon, extras)
    "knight_sword": ("sword", {"cape": True, "plume": True, "pauldron": 1.25}),
    "ranger_bow": ("bow", {"hood": True, "pauldron": 0.7, "light": True}),
    "militia_spear": ("spear", {"pauldron": 0.9, "cap": True}),
    "militia_shield": ("sword", {"shield": True, "pauldron": 0.9, "cap": True}),
    "bandit_axe": ("axe", {"hood": True, "pauldron": 0.8, "light": True, "mask": True}),
    "bandit_bow": ("bow", {"hood": True, "pauldron": 0.6, "light": True, "mask": True}),
}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, col, metal=0.0, rough=0.6, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 3.0
    return m

MATS = {}
def build_mats():
    MATS["armor"] = mat("armor", (0.74, 0.79, 0.86), 0.85, 0.28)
    MATS["cloth"] = mat("cloth", (0.12, 0.15, 0.20), 0.0, 0.85)
    MATS["trim"] = mat("trim", (0.43, 0.83, 1.0), 0.2, 0.3, (0.43, 0.83, 1.0))
    MATS["visor"] = mat("visor", (0.6, 0.9, 1.0), 0.0, 0.2, (0.6, 0.9, 1.0))
    MATS["skin"] = mat("skin", (0.78, 0.62, 0.52), 0.0, 0.55)
    MATS["leather"] = mat("leather", (0.20, 0.17, 0.15), 0.0, 0.7)
    MATS["weapon"] = mat("weapon", (0.86, 0.90, 0.95), 1.0, 0.18)

PARTS = []  # (obj, bone)
def add(obj, bone, m):
    obj.data.materials.clear()
    obj.data.materials.append(MATS[m])
    PARTS.append((obj, bone))
    return obj

def taper_box(name, w0, d0, w1, d1, h, z0, x=0.0, y=0.0, bevel=0.012):
    bm = bmesh.new()
    vs = []
    for (w, d, z) in ((w0, d0, z0), (w1, d1, z0 + h)):
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(bm.verts.new((x + sx * w / 2, y + sy * d / 2, z)))
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    for t in f:
        bm.faces.new([vs[i] for i in t])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    if bevel > 0:
        md = ob.modifiers.new("bev", "BEVEL"); md.width = bevel; md.segments = 2; md.limit_method = "ANGLE"
    return ob

def cyl(name, r0, r1, p0, p1, verts=12):
    p0 = Vector(p0); p1 = Vector(p1)
    d = p1 - p0
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=d.length, location=(p0 + p1) / 2)
    ob = bpy.context.active_object; ob.name = name
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    md = ob.modifiers.new("bev", "BEVEL"); md.width = 0.006; md.segments = 1
    return ob

def sph(name, r, loc, scale=(1, 1, 1), seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    ob = bpy.context.active_object; ob.name = name; ob.scale = scale
    return ob

# --- skeleton (Blender: Z up, character faces -Y)
BONES = [
    ("root", (0, 0, 0), (0, 0, 0.3), None),
    ("hips", (0, 0, 0.98), (0, 0, 1.10), "root"),
    ("spine", (0, 0, 1.10), (0, 0, 1.28), "hips"),
    ("chest", (0, 0, 1.28), (0, 0, 1.45), "spine"),
    ("neck", (0, 0, 1.45), (0, 0, 1.53), "chest"),
    ("head", (0, 0, 1.53), (0, 0, 1.78), "neck"),
]
for s, sx in (("L", 1), ("R", -1)):
    BONES += [
        (f"upper_arm.{s}", (sx * 0.21, 0, 1.41), (sx * 0.27, 0, 1.13), "chest"),
        (f"forearm.{s}", (sx * 0.27, 0, 1.13), (sx * 0.31, -0.02, 0.88), f"upper_arm.{s}"),
        (f"hand.{s}", (sx * 0.31, -0.02, 0.88), (sx * 0.32, -0.03, 0.79), f"forearm.{s}"),
        (f"thigh.{s}", (sx * 0.10, 0, 0.97), (sx * 0.11, 0, 0.53), "hips"),
        (f"shin.{s}", (sx * 0.11, 0, 0.53), (sx * 0.11, 0.02, 0.09), f"thigh.{s}"),
        (f"foot.{s}", (sx * 0.11, 0.02, 0.09), (sx * 0.11, -0.14, 0.03), f"shin.{s}"),
    ]

def build_armature():
    arm = bpy.data.armatures.new("Rig"); ob = bpy.data.objects.new("Rig", arm)
    bpy.context.collection.objects.link(ob); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for (n, h, t, p) in BONES:
        b = arm.edit_bones.new(n); b.head = h; b.tail = t; b.roll = 0
        if p: b.parent = arm.edit_bones[p]; b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob

def build_weapon(weapon, hr=(-0.315, -0.025, 0.85), hl=(0.315, -0.025, 0.85), shield=False, quiver=True):
    """weapon kit around fist positions hr (right) / hl (left); reused by rig_mesh_v87.py on farmed bodies"""
    hx, hy, hz = hr
    lx, ly, lz = hl
    if weapon == "sword":
        add(taper_box("grip", 0.03, 0.03, 0.03, 0.03, 0.16, hz - 0.08, x=hx, y=hy, bevel=0.0), "hand.R", "leather")
        add(taper_box("guard", 0.20, 0.04, 0.20, 0.04, 0.03, hz + 0.08, x=hx, y=hy, bevel=0.005), "hand.R", "trim")
        add(taper_box("blade", 0.055, 0.012, 0.012, 0.004, 0.82, hz + 0.11, x=hx, y=hy, bevel=0.002), "hand.R", "weapon")
    elif weapon == "axe":
        add(taper_box("haft", 0.035, 0.035, 0.03, 0.03, 0.75, hz - 0.20, x=hx, y=hy, bevel=0.0), "hand.R", "leather")
        add(taper_box("axehead", 0.04, 0.24, 0.012, 0.30, 0.20, hz + 0.40, x=hx, y=hy - 0.10, bevel=0.004), "hand.R", "weapon")
    elif weapon == "spear":
        add(cyl("shaft", 0.018, 0.016, (hx, hy, hz - 0.55), (hx, hy, hz + 1.05)), "hand.R", "leather")
        add(taper_box("spearhead", 0.06, 0.012, 0.004, 0.004, 0.26, hz + 1.05, x=hx, y=hy, bevel=0.002), "hand.R", "weapon")
        add(cyl("spear_ring", 0.026, 0.026, (hx, hy, hz + 1.0), (hx, hy, hz + 1.05)), "hand.R", "trim")
    elif weapon == "bow":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.014, location=(lx + 0.5, ly - 0.0, lz))
        bw = bpy.context.active_object; bw.name = "bow"; bw.rotation_euler = (R(90), 0, 0)
        bpy.ops.object.mode_set(mode="EDIT"); bm = bmesh.from_edit_mesh(bw.data)
        cut = [v for v in bm.verts if (bw.matrix_world @ v.co).x > lx + 0.12]
        bmesh.ops.delete(bm, geom=cut, context="VERTS"); bmesh.update_edit_mesh(bw.data); bpy.ops.object.mode_set(mode="OBJECT")
        add(bw, "hand.L", "weapon")
        add(cyl("bowstring", 0.003, 0.003, (lx + 0.13, ly, lz + 0.50), (lx + 0.13, ly, lz - 0.50), 6), "hand.L", "trim")
        if quiver:
            add(cyl("quiver", 0.05, 0.05, (0.08, 0.16, 1.05), (0.16, 0.18, 1.48)), "chest", "leather")
    if shield:
        add(taper_box("shield", 0.36, 0.05, 0.30, 0.05, 0.48, lz - 0.05, x=lx + 0.045, y=ly - 0.035, bevel=0.03), "forearm.L", "armor")
        add(taper_box("shield_mark", 0.05, 0.06, 0.05, 0.06, 0.32, lz + 0.03, x=lx + 0.045, y=ly - 0.045, bevel=0.0), "forearm.L", "trim")

def build_body(arch):
    weapon, ex = ARCH[arch]
    light = ex.get("light", False)
    am = "leather" if light else "armor"
    # torso / pelvis
    add(taper_box("pelvis", 0.30, 0.20, 0.34, 0.22, 0.16, 0.92), "hips", am)
    add(taper_box("skirt", 0.40, 0.30, 0.32, 0.22, 0.30, 0.66, bevel=0.02), "hips", "cloth")
    add(taper_box("abdomen", 0.28, 0.19, 0.32, 0.21, 0.20, 1.08), "spine", am)
    add(taper_box("cuirass", 0.34, 0.24, 0.44, 0.26, 0.20, 1.26, bevel=0.03), "chest", am)
    add(taper_box("collar", 0.26, 0.20, 0.20, 0.16, 0.06, 1.45), "chest", "trim" if not light else "leather")
    add(taper_box("chest_line", 0.02, 0.02, 0.02, 0.02, 0.30, 1.12, y=-0.125, bevel=0.0), "chest", "trim")
    # head
    add(sph("head", 0.105, (0, -0.01, 1.62)), "head", "skin")
    if ex.get("hood"):
        add(sph("hood", 0.122, (0, 0.018, 1.645), (0.98, 1.05, 1.10)), "head", "cloth")
        add(taper_box("hood_rim", 0.20, 0.03, 0.17, 0.03, 0.17, 1.55, y=-0.098, bevel=0.01), "head", "cloth")
        add(taper_box("eyes", 0.11, 0.012, 0.115, 0.012, 0.016, 1.635, y=-0.112, bevel=0.0), "head", "visor")
        if ex.get("mask"):
            add(taper_box("mask", 0.15, 0.04, 0.16, 0.04, 0.07, 1.555, y=-0.104, bevel=0.01), "head", "leather")
    else:
        add(sph("helm", 0.128, (0, 0.0, 1.645), (0.95, 1.05, 1.08)), "head", "armor")
        add(taper_box("visor", 0.16, 0.02, 0.17, 0.02, 0.022, 1.625, y=-0.128, bevel=0.0), "head", "visor")
        if ex.get("plume"):
            add(taper_box("crest", 0.018, 0.22, 0.012, 0.16, 0.08, 1.74, bevel=0.004), "head", "trim")
        if ex.get("cap"):
            add(cyl("brim", 0.15, 0.15, (0, 0, 1.585), (0, 0, 1.6), 16), "head", "armor")
    pk = ex.get("pauldron", 1.0)
    for s, sx in (("L", 1), ("R", -1)):
        add(sph(f"pauldron.{s}", 0.10 * pk, (sx * 0.23, 0, 1.43), (1.1, 1.0, 0.75)), "chest", am)
        add(taper_box(f"pauldron_trim.{s}", 0.17 * pk, 0.17 * pk, 0.17 * pk, 0.17 * pk, 0.012, 1.385, x=sx * 0.235, bevel=0.0), "chest", "trim")
        add(cyl(f"uarm.{s}", 0.055, 0.048, (sx * 0.22, 0, 1.40), (sx * 0.27, 0, 1.14)), f"upper_arm.{s}", "cloth")
        add(cyl(f"farm.{s}", 0.052, 0.042, (sx * 0.27, 0, 1.14), (sx * 0.31, -0.02, 0.89)), f"forearm.{s}", am)
        add(cyl(f"gaunt.{s}", 0.058, 0.05, (sx * 0.30, -0.015, 0.95), (sx * 0.31, -0.02, 0.89)), f"forearm.{s}", "trim" if not light else "leather")
        add(sph(f"hand.{s}", 0.045, (sx * 0.315, -0.025, 0.85), (0.9, 1.0, 1.2)), f"hand.{s}", "leather")
        add(cyl(f"thigh.{s}", 0.075, 0.062, (sx * 0.10, 0, 0.95), (sx * 0.11, 0, 0.54)), f"thigh.{s}", "cloth")
        add(sph(f"knee.{s}", 0.06, (sx * 0.11, -0.03, 0.53), (1, 0.9, 1)), f"shin.{s}", am)
        add(cyl(f"greave.{s}", 0.062, 0.05, (sx * 0.11, 0, 0.52), (sx * 0.11, 0.01, 0.12)), f"shin.{s}", am)
        add(taper_box(f"boot.{s}", 0.10, 0.22, 0.09, 0.16, 0.10, 0.0, x=sx * 0.11, y=-0.04), f"foot.{s}", "leather")
    if ex.get("cape"):
        # curved tapered drape from the shoulder line, hanging behind (+Y is back)
        bm = bmesh.new(); rows, cols = 8, 6; grid = []
        for i in range(rows + 1):
            t = i / rows
            z = 1.43 - t * 0.86
            w = 0.36 + 0.18 * t
            yb = 0.13 + 0.10 * t + 0.03 * math.sin(t * math.pi)
            row = []
            for j in range(cols + 1):
                u = j / cols - 0.5
                row.append(bm.verts.new((u * w, yb + 0.06 * (u * 2) ** 2, z)))
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        me = bpy.data.meshes.new("cape"); bm.to_mesh(me); bm.free()
        cp = bpy.data.objects.new("cape", me); bpy.context.collection.objects.link(cp)
        md = cp.modifiers.new("sol", "SOLIDIFY"); md.thickness = 0.01
        add(cp, "chest", "cloth")
    build_weapon(weapon, shield=bool(ex.get("shield")))

def bind(rig):
    for ob, bone in PARTS:
        bpy.context.view_layer.objects.active = ob
        for m in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
        vg = ob.vertex_groups.new(name=bone)
        vg.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0][0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.active_object; body.name = "Body"
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_auto_smooth(angle=R(40))
    except Exception:
        pass
    md = body.modifiers.new("Armature", "ARMATURE"); md.object = rig
    body.parent = rig
    return body

# --- actions: dict bone -> euler(deg) keyed at frames
def pose_action(rig, name, keys, loop=False):
    act = bpy.data.actions.new(name)
    rig.animation_data_create(); rig.animation_data.action = act
    pb = rig.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    allb = set()
    for f, pose in keys:
        allb |= set(pose.keys())
    for f, pose in keys:
        for bn in allb:
            v = pose.get(bn, (0, 0, 0))
            if bn == "root_loc":
                pb["root"].location = v
                pb["root"].keyframe_insert("location", frame=f)
                continue
            pb[bn].rotation_euler = Euler([R(a) for a in v], "XYZ")
            pb[bn].keyframe_insert("rotation_euler", frame=f)
    act.use_fake_user = True
    tr = rig.animation_data.nla_tracks.new(); tr.name = name
    st = tr.strips.new(name, int(keys[0][0]), act); st.name = name
    rig.animation_data.action = None
    for b in pb:
        b.rotation_euler = (0, 0, 0); b.location = (0, 0, 0)
    return act

def actions(rig, weapon):
    # sign conventions verified by render QA: arm X+ swings forward/up for down-pointing arm bones
    ready = {"upper_arm.R": (20, 0, -8), "forearm.R": (45, 0, 0), "upper_arm.L": (12, 0, 8), "forearm.L": (30, 0, 0),
             "thigh.L": (8, 0, 0), "thigh.R": (-6, 0, 0), "shin.L": (10, 0, 0), "shin.R": (6, 0, 0), "chest": (4, 0, 0)}
    if weapon == "bow":
        ready.update({"upper_arm.L": (70, 0, 10), "forearm.L": (10, 0, 0), "upper_arm.R": (40, 0, -10), "forearm.R": (80, 0, 0)})
    if weapon == "spear":
        ready.update({"upper_arm.R": (35, 0, -10), "forearm.R": (60, 0, 0), "upper_arm.L": (40, 0, 20), "forearm.L": (50, 0, 0)})
    def P(**over):
        d = dict(ready); d.update({k.replace("__", "."): v for k, v in over.items()}); return d
    breathe = P(chest=(6, 0, 0), upper_arm__R=(22, 0, -9))
    pose_action(rig, "idle", [(1, P()), (24, breathe), (48, P())], True)
    run_a = P(thigh__L=(-35, 0, 0), thigh__R=(30, 0, 0), shin__L=(20, 0, 0), shin__R=(55, 0, 0), chest=(14, 0, 0))
    run_b = P(thigh__L=(30, 0, 0), thigh__R=(-35, 0, 0), shin__L=(55, 0, 0), shin__R=(20, 0, 0), chest=(14, 0, 0))
    pose_action(rig, "advance", [(1, run_a), (7, run_b), (13, run_a)], True)
    if weapon in ("sword", "axe"):
        wind = P(upper_arm__R=(160, 0, -30), forearm__R=(60, 0, 0), chest=(-8, 0, 25), spine=(0, 0, 10))
        strike = P(upper_arm__R=(60, 0, 20), forearm__R=(5, 0, 0), chest=(22, 0, -30), spine=(8, 0, -12), thigh__L=(-30, 0, 0), shin__L=(30, 0, 0))
        follow = P(upper_arm__R=(20, 0, 35), forearm__R=(10, 0, 0), chest=(18, 0, -38), thigh__L=(-30, 0, 0), shin__L=(30, 0, 0))
    elif weapon == "spear":
        wind = P(upper_arm__R=(10, 0, -20), forearm__R=(100, 0, 0), chest=(-6, 0, 30), thigh__R=(-20, 0, 0))
        strike = P(upper_arm__R=(85, 0, 0), forearm__R=(5, 0, 0), upper_arm__L=(75, 0, 10), forearm__L=(10, 0, 0), chest=(20, 0, -15), thigh__L=(-40, 0, 0), shin__L=(25, 0, 0))
        follow = P(upper_arm__R=(80, 0, 0), forearm__R=(10, 0, 0), chest=(16, 0, -12), thigh__L=(-35, 0, 0), shin__L=(25, 0, 0))
    else:  # bow
        wind = P(upper_arm__L=(88, 0, 4), forearm__L=(0, 0, 0), upper_arm__R=(88, 0, -30), forearm__R=(150, 0, 0), chest=(0, 0, 20))
        strike = P(upper_arm__L=(90, 0, 4), forearm__L=(0, 0, 0), upper_arm__R=(70, 0, -60), forearm__R=(40, 0, 0), chest=(0, 0, 22))
        follow = P(upper_arm__L=(85, 0, 4), forearm__L=(0, 0, 0), upper_arm__R=(50, 0, -40), forearm__R=(60, 0, 0), chest=(0, 0, 15))
    pose_action(rig, "attack", [(1, P()), (8, wind), (12, strike), (18, follow), (30, P())])  # impact f12
    raise_ = P(upper_arm__R=(175, 0, -5), forearm__R=(10, 0, 0), upper_arm__L=(150, 0, 15), chest=(-15, 0, 0), spine=(-6, 0, 0))
    slam = P(upper_arm__R=(70, 0, 0), forearm__R=(0, 0, 0), upper_arm__L=(60, 0, 10), chest=(30, 0, 0), spine=(10, 0, 0), thigh__L=(-45, 0, 0), shin__L=(40, 0, 0), thigh__R=(15, 0, 0))
    pose_action(rig, "skill", [(1, P()), (12, raise_), (16, raise_), (20, slam), (34, P())])  # impact f20
    recoil = P(chest=(-22, 0, 8), spine=(-10, 0, 0), head=(-18, 0, 0), upper_arm__R=(-10, 0, -25), upper_arm__L=(-10, 0, 25), thigh__R=(-15, 0, 0))
    pose_action(rig, "hit", [(1, P()), (4, recoil), (16, P())])
    lean = P(hips=(0, 0, 0), spine=(0, -22, 0), chest=(-10, -16, 0), thigh__L=(-10, -20, 0), thigh__R=(10, 15, 0), shin__L=(25, 0, 0))
    pose_action(rig, "dodge", [(1, P()), (6, lean), (10, lean), (18, P())])
    spin = P(chest=(0, 0, 70), spine=(0, 0, 40), upper_arm__R=(100, 0, -60), forearm__R=(20, 0, 0), thigh__R=(-25, 0, 0))
    big = P(upper_arm__R=(50, 0, 40), forearm__R=(0, 0, 0), chest=(28, 0, -45), spine=(10, 0, -25), thigh__L=(-50, 0, 0), shin__L=(45, 0, 0), thigh__R=(20, 0, 0))
    pose_action(rig, "crit", [(1, P()), (8, spin), (13, big), (24, big), (36, P())])  # impact f13
    kneel = P(thigh__L=(-70, 0, 0), thigh__R=(-60, 0, 0), shin__L=(110, 0, 0), shin__R=(100, 0, 0), chest=(25, 0, 0), head=(20, 0, 0), upper_arm__R=(-5, 0, -20), upper_arm__L=(-5, 0, 20), root_loc=(0, 0, -0.35))
    down = dict(kneel); down.update({"spine": (40, 0, 0), "chest": (45, 0, 0), "root_loc": (0, 0, -0.62)})
    pose_action(rig, "death", [(1, P(root_loc=(0, 0, 0))), (10, kneel), (22, down), (40, down)])

def qa_render(path):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"; scn.display.shading.color_type = "MATERIAL"
    scn.render.resolution_x = 360; scn.render.resolution_y = 480
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam)
    cam.location = (1.9, -2.6, 1.35); cam.rotation_euler = (R(84), 0, R(36)); scn.camera = cam
    scn.render.filepath = path; bpy.ops.render.render(write_still=True)

def build(arch):
    reset(); build_mats(); PARTS.clear()
    rig = build_armature()
    build_body(arch)
    bind(rig)
    actions(rig, ARCH[arch][0])
    bpy.context.scene.render.fps = 24
    for f, name in ((1, "rest"),):
        pass
    out = os.path.join(OUT, f"{arch}.glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_apply=False, export_yup=True, export_skins=True, export_materials="EXPORT")
    print("GLB", out, os.path.getsize(out))
    return rig

if __name__ == "__main__":
    for a in (WANT or list(ARCH.keys())):
        build(a)
