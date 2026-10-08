"""v8.7 farmed-mesh -> game unit. Blender 4.2 headless:
  blender -b -P rig_mesh_v87.py -- in.glb out.glb [--sheet turnaround.png] [--weapon sword|axe|spear|bow|none]
          [--shield 0|1] [--quiver 0|1] [--tris 18000] [--tex 1024] [--yaw 0] [--qa qa_prefix] [--part body|outfit|head]
Pipeline: import -> drop junk -> join -> merge/clean islands -> normalise (feet z=0, centred, H=1.78, front -Y)
 -> decimate to budget -> (optional) albedo projected from the style-locked FRONT|BACK turnaround and baked to one UV atlas
 -> landmark auto-rig (proxy heat weights -> data transfer) -> re-pose limbs onto the canonical stand-in bone directions
 -> rebuild rest = canonical -> shared weapon kit + the SAME NLA actions as build_standins_v86 -> GLB (+ QA renders)."""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_standins_v86 as K

H = 1.78
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
IN, OUT = argv[0], argv[1]
OPT = {"sheet": "", "weapon": "sword", "shield": "0", "quiver": "0", "tris": "18000", "tex": "1024", "yaw": "0", "qa": "", "part": "body", "rim": "ally", "dump": ""}
i = 2
while i < len(argv):
    OPT[argv[i].lstrip("-")] = argv[i + 1]; i += 2
CANON = {n: (Vector(h), Vector(t), p) for (n, h, t, p) in K.BONES}

def log(*a): print("[rig_v87]", *a, flush=True)

def sel_only(ob):
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob

# ---------------------------------------------------------------- import + cleanup
def import_clean():
    K.reset()
    bpy.ops.import_scene.gltf(filepath=IN)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1: bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = "Src"
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # drop small islands (< 0.5% of verts): floaters from marching/surface-net
    bm.verts.ensure_lookup_table(); seen = set(); islands = []
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; comp = []; seen.add(v.index)
        while stack:
            x = stack.pop(); comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen: seen.add(y.index); stack.append(y)
        islands.append(comp)
    n = len(bm.verts); kill = [v for c in islands if len(c) < 0.005 * n for v in c]
    if kill: bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(ob.data); bm.free()
    log("import", IN, "islands", len(islands), "dropped verts", len(kill), "faces", len(ob.data.polygons))
    return ob

def normalise(ob):
    yaw = float(OPT["yaw"])
    if yaw:
        ob.rotation_euler = (0, 0, math.radians(yaw)); sel_only(ob); bpy.ops.object.transform_apply(rotation=True)
    co = np.array([v.co[:] for v in ob.data.vertices])
    mn, mx = co.min(0), co.max(0)
    s = H / (mx[2] - mn[2])
    c = (mn + mx) / 2
    for v in ob.data.vertices:
        p = (Vector(v.co) - Vector((c[0], c[1], mn[2]))) * s
        v.co = p
    # centre x/y on the torso (median of the 0.55H..0.75H slice), not the bbox (asymmetric capes/weapons)
    co = np.array([v.co[:] for v in ob.data.vertices])
    sl = co[(co[:, 2] > 0.55 * H) & (co[:, 2] < 0.75 * H)]
    off = Vector((np.median(sl[:, 0]), np.median(sl[:, 1]), 0))
    for v in ob.data.vertices: v.co = Vector(v.co) - off
    ob.data.update()
    log("normalised scale", round(s, 4))

def _tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)

def decimate(ob):
    tris = int(OPT["tris"]); cur0 = _tris(ob)
    ob.data.validate(clean_customdata=False)
    sel_only(ob)
    if cur0 > tris * 3:
        # farmed surface-net meshes: uniform voxel re-skin (closes thin double walls) -> outer shell -> collapse works
        md = ob.modifiers.new("rv", "REMESH"); md.mode = "VOXEL"; md.voxel_size = float(OPT.get("voxel", "0.0075"))
        bpy.ops.object.modifier_apply(modifier=md.name)
        bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table(); seen = set(); comps = []
        for v in bm.verts:
            if v.index in seen: continue
            st = [v]; comp = []; seen.add(v.index)
            while st:
                x = st.pop(); comp.append(x)
                for e in x.link_edges:
                    y = e.other_vert(x)
                    if y.index not in seen: seen.add(y.index); st.append(y)
            comps.append(comp)
        comps.sort(key=lambda c: -len(c))
        kill = [v for c in comps[1:] if len(c) < 0.02 * len(bm.verts) for v in c]
        if kill: bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(ob.data); bm.free()
        log("voxel re-skin", cur0, "->", _tris(ob), "shells", len(comps))
    for _ in range(6):
        cur = _tris(ob)
        if cur <= tris * 1.05: break
        md = ob.modifiers.new("dec", "DECIMATE"); md.ratio = max(0.05, tris / cur); md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=md.name)
        if _tris(ob) > cur * 0.97:  # stalled on non-manifold borders: weld + retry
            bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002); bm.to_mesh(ob.data); bm.free()
    bpy.ops.object.shade_smooth()
    log("tris", cur0, "->", _tris(ob))

# ---------------------------------------------------------------- albedo projection from turnaround sheet
def sheet_boxes(img):
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]  # top-down rows
    boxes = []
    for x0, x1 in ((0, w // 2), (w // 2, w)):
        half = px[:, x0:x1]
        border = np.concatenate([half[0], half[-1], half[:, 0], half[:, -1]])
        bg = np.median(border, 0)
        m = np.abs(half - bg).sum(-1) > 0.12
        rows = np.where(m.mean(1) > 0.004)[0]; cols = np.where(m.mean(0) > 0.004)[0]
        top, bot = rows.min(), rows.max()
        # horizontal centre from the torso band (rows 30-55% of figure) to ignore asymmetric arms/props
        band = m[int(top + 0.30 * (bot - top)):int(top + 0.55 * (bot - top))]
        bc = np.where(band.mean(0) > 0.05)[0]
        cx = (bc.min() + bc.max()) / 2 if len(bc) else (cols.min() + cols.max()) / 2
        boxes.append((x0 + cx, top, bot))
    return boxes, w, h

def project_albedo(ob):
    img = bpy.data.images.load(os.path.abspath(OPT["sheet"]))
    boxes, w, h = sheet_boxes(img)
    (fcx, ft, fb), (bcx, bt, bb) = boxes
    me = ob.data
    uvf = me.uv_layers.new(name="proj_front"); uvb = me.uv_layers.new(name="proj_back")
    sf = (fb - ft) / H; sb = (bb - bt) / H
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uvf.data[loop.index].uv = ((fcx + co.x * sf) / w, 1 - (fb - co.z * sf) / h)
        uvb.data[loop.index].uv = ((bcx - co.x * sb) / w, 1 - (bb - co.z * sb) / h)
    # bake target atlas
    atlas = me.uv_layers.new(name="UVMap"); me.uv_layers.active = atlas
    sel_only(ob); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    tex = int(OPT["tex"])
    out = bpy.data.images.new("albedo", tex, tex, alpha=False)
    m = bpy.data.materials.new("projmat"); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    def N(t, **kw):
        n = nt.nodes.new(t)
        for k, v in kw.items(): setattr(n, k, v)
        return n
    tf = N("ShaderNodeTexImage", image=img, extension="EXTEND"); tb = N("ShaderNodeTexImage", image=img, extension="EXTEND")
    uf = N("ShaderNodeUVMap", uv_map="proj_front"); ub = N("ShaderNodeUVMap", uv_map="proj_back")
    nt.links.new(uf.outputs[0], tf.inputs[0]); nt.links.new(ub.outputs[0], tb.inputs[0])
    geo = N("ShaderNodeNewGeometry"); sep = N("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    # w_back = smoothstep(-0.25, 0.25, n.y)  (front faces -Y)
    mr = N("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP"); mr.inputs[1].default_value = -0.25; mr.inputs[2].default_value = 0.25
    nt.links.new(sep.outputs[1], mr.inputs[0])
    mix = N("ShaderNodeMix", data_type="RGBA"); nt.links.new(mr.outputs[0], mix.inputs[0])
    nt.links.new(tf.outputs[0], mix.inputs[6]); nt.links.new(tb.outputs[0], mix.inputs[7])
    em = N("ShaderNodeEmission"); nt.links.new(mix.outputs[2], em.inputs[0])
    o = N("ShaderNodeOutputMaterial"); nt.links.new(em.outputs[0], o.inputs[0])
    tgt = N("ShaderNodeTexImage", image=out); nt.nodes.active = tgt
    me.materials.clear(); me.materials.append(m)
    scn = bpy.context.scene; scn.render.engine = "CYCLES"; scn.cycles.samples = 1; scn.cycles.device = "CPU"
    scn.render.bake.margin = 6
    bpy.ops.object.bake(type="EMIT")
    out.filepath_raw = os.path.join(__import__("tempfile").mkdtemp(prefix="ckrig_"), "_albedo_v87.png")  # per-process (parallel-safe), stable name; out.file_format = "PNG"; out.save()
    out.pack()
    # final material: the "body" BaseMaterial keeps its texture in Godot (unit_model duplicates + adds rim)
    fm = bpy.data.materials.new("body"); fm.use_nodes = True
    bsdf = fm.node_tree.nodes["Principled BSDF"]; t = fm.node_tree.nodes.new("ShaderNodeTexImage"); t.image = out
    fm.node_tree.links.new(t.outputs[0], bsdf.inputs["Base Color"]); bsdf.inputs["Roughness"].default_value = 0.62
    me.materials.clear(); me.materials.append(fm)
    me.uv_layers.remove(me.uv_layers["proj_front"]); me.uv_layers.remove(me.uv_layers["proj_back"])
    log("albedo baked", tex, "front cx/top/bot", round(fcx), ft, fb, "back", round(bcx), bt, bb)

def plain_material(ob):
    me = ob.data
    if not me.materials:
        me.materials.append(bpy.data.materials.new("body"))
    else:
        me.materials[0].name = "body"
    if not me.uv_layers:
        sel_only(ob); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(); bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- landmarks -> fitted armature
def _arm_points(co, sx):
    """trace the free-hanging arm on one side top->down. Seed = outermost substantial |x| run just below the
    shoulder; then follow a +-7cm window around the running arm centre (robust to sparse decimated verts and
    fragmented runs). Coat hems/flaps are never reached because the window only moves with the arm.
    Returns (points, per-slice runs top->down; last = hand)."""
    side = co[(co[:, 0] * sx > 0.02) & (co[:, 2] > 0.30 * H) & (co[:, 2] < 0.80 * H)]
    side = np.c_[np.abs(side[:, 0]), side[:, 1:]] * np.array([1, 1, 1])
    step = 0.01 * H; c = None
    for z0 in np.arange(0.74 * H, 0.66 * H, -step):  # seed band
        sl = side[(side[:, 2] >= z0 - step) & (side[:, 2] < z0)]
        if len(sl) < 6: continue
        ax = np.sort(sl[:, 0]); k = np.where(np.diff(ax) > 0.022)[0]
        runs = np.split(ax, k + 1); runs = [r for r in runs if len(r) >= 4]
        if len(runs) >= 2 and np.mean(runs[-1]) > 0.13 * H: c = float(np.mean(runs[-1])); break
    if c is None: return np.zeros((0, 3)), []
    out = []; miss = 0; z0 = 0.74 * H
    while z0 > 0.40 * H:  # A-pose hands sit ~0.45-0.5H; below that the window only finds coat strands
        sl = side[(side[:, 2] >= z0 - step) & (side[:, 2] < z0)]
        w = sl[np.abs(sl[:, 0] - c) < 0.07]
        if len(w) >= 2:
            miss = 0; c = float(np.mean(w[:, 0])); out.append(w)
        else:
            miss += 1
            if miss >= 3: break
        z0 -= step
    out = [np.c_[r[:, 0] * sx, r[:, 1:]] for r in out]
    return (np.concatenate(out) if out else np.zeros((0, 3))), out

def landmarks(ob):
    co = np.array([v.co[:] for v in ob.data.vertices])
    J = {}
    knee_band = co[(co[:, 2] > 0.25 * H) & (co[:, 2] < 0.33 * H)]
    for s, sx in (("L", 1), ("R", -1)):
        side = knee_band[knee_band[:, 0] * sx > 0.01]
        lx = float(np.median(side[:, 0])) if len(side) else sx * 0.11
        ly = float(np.median(side[:, 1])) if len(side) else 0.0
        J["hip." + s] = Vector((lx * 0.92, 0, 0.545 * H)); J["knee." + s] = Vector((lx, ly, 0.30 * H))
        J["ankle." + s] = Vector((lx, ly + 0.01, 0.05 * H)); J["toe." + s] = J["ankle." + s] + Vector((0, -0.09 * H, -0.03 * H))
        sh = Vector((sx * 0.118 * H, 0, 0.792 * H))
        cand, runs = _arm_points(co, sx)
        if len(cand) >= 30 and len(runs) >= 6:
            tip = Vector(np.mean(np.concatenate(runs[-2:]), axis=0))
        else:  # arms fused to the coat/body: canonical stand-in direction
            log("arm", s, "not separable -> canonical direction")
            tip = sh + Vector((sx * 0.062 * H, -0.017 * H, -0.35 * H))
        # reject coat-fused tips (too inboard or still above the elbow height) and fall back to canonical A-pose
        if abs(tip.x) < 0.30 or tip.z > sh.z - 0.18:
            log("arm", s, "tip rejected", tuple(round(c, 3) for c in tip), "-> canonical")
            tip = sh + Vector((sx * 0.062 * H, -0.017 * H, -0.35 * H))
        log("arm", s, "tip", tuple(round(c, 3) for c in tip), "pts", len(cand))
        J["shoulder." + s] = sh
        J["elbow." + s] = sh.lerp(tip, 0.42); J["wrist." + s] = sh.lerp(tip, 0.80); J["handtip." + s] = sh.lerp(tip, 0.95)
    # A-pose bodies are symmetric: a trace that wandered onto the coat (tip far inboard of the other side) is mirrored
    tl, tr = J["handtip.L"], J["handtip.R"]
    for bad, good in (("R", "L"), ("L", "R")):
        if abs(J["handtip." + good].x) - abs(J["handtip." + bad].x) > 0.12:
            sh = J["shoulder." + bad]; tip = J["handtip." + good].copy(); tip.x = -tip.x
            tip = sh + (tip - sh) / 0.95  # handtip sits at 0.95 of shoulder->tip
            J["elbow." + bad] = sh.lerp(tip, 0.42); J["wrist." + bad] = sh.lerp(tip, 0.80); J["handtip." + bad] = sh.lerp(tip, 0.95)
            log("arm", bad, "mirrored from", good)
    torso = co[(co[:, 2] > 0.55 * H) & (co[:, 2] < 0.80 * H) & (np.abs(co[:, 0]) < 0.10 * H)]
    ty = float(np.median(torso[:, 1])) if len(torso) else 0.0
    head = co[co[:, 2] > 0.88 * H]
    hy = float(np.median(head[:, 1])) if len(head) else ty
    J.update({"pelvis": Vector((0, ty, 0.55 * H)), "spine": Vector((0, ty, 0.62 * H)), "chest": Vector((0, ty, 0.72 * H)),
              "neck": Vector((0, ty, 0.815 * H)), "head": Vector((0, hy, 0.86 * H)), "top": Vector((0, hy, H))})
    return J

FIT = {  # bone: (head joint, tail joint)
    "hips": ("pelvis", "spine"), "spine": ("spine", "chest"), "chest": ("chest", "neck"), "neck": ("neck", "head"), "head": ("head", "top"),
}
for _s in "LR":
    FIT.update({f"upper_arm.{_s}": (f"shoulder.{_s}", f"elbow.{_s}"), f"forearm.{_s}": (f"elbow.{_s}", f"wrist.{_s}"),
                f"hand.{_s}": (f"wrist.{_s}", f"handtip.{_s}"), f"thigh.{_s}": (f"hip.{_s}", f"knee.{_s}"),
                f"shin.{_s}": (f"knee.{_s}", f"ankle.{_s}"), f"foot.{_s}": (f"ankle.{_s}", f"toe.{_s}")})

def build_fitted_rig(J):
    arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
    bpy.context.collection.objects.link(rig); sel_only(rig); bpy.ops.object.mode_set(mode="EDIT")
    for (n, h, t, p) in K.BONES:
        b = arm.edit_bones.new(n)
        if n == "root": b.head, b.tail = Vector((0, 0, 0)), Vector((0, 0, 0.3))
        else: b.head, b.tail = J[FIT[n][0]], J[FIT[n][1]]
        b.roll = 0
        if p: b.parent = arm.edit_bones[p]; b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig

def _seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length

def distance_weights(ob, rig):
    """anatomically gated inverse-distance-to-bone weights (A-pose humanoid), smoothed. Limb bones only bind their
    side; arm bones only bind outside the shoulder line, leg bones only below the hips."""
    ob.vertex_groups.clear()
    bones = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones if b.name != "root"]
    groups = {n: ob.vertex_groups.new(name=n) for n, _, _ in bones}
    sh_x = rig.data.bones["upper_arm.L"].head_local.x * 0.85
    hip_z = rig.data.bones["thigh.L"].head_local.z
    for v in ob.data.vertices:
        p = v.co; cand = []
        for n, a, b in bones:
            side = n[-1] if n[-2] == "." else ""
            if side == "L" and p.x < -0.02: continue
            if side == "R" and p.x > 0.02: continue
            if n.startswith(("upper_arm", "forearm", "hand")) and abs(p.x) < sh_x: continue
            if n.startswith(("thigh", "shin", "foot")) and p.z > hip_z + 0.05: continue
            if n in ("hips", "spine", "chest", "neck", "head") and abs(p.x) > sh_x * 1.25 and p.z > hip_z: continue
            cand.append((_seg_dist(p, a, b), n))
        cand.sort()
        cand = cand[:3] or [(1.0, "chest")]
        ws = [(1.0 / max(1e-4, d) ** 4, n) for d, n in cand]
        tot = sum(w for w, _ in ws)
        for w, n in ws:
            groups[n].add([v.index], w / tot, "REPLACE")
    sel_only(ob); bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=4)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    for md in list(ob.modifiers):
        if md.type == "ARMATURE": ob.modifiers.remove(md)
    ob.parent = rig; am = ob.modifiers.new("Armature", "ARMATURE"); am.object = rig

def _strip_arm_from_skirt(ob, rig):
    """A-pose hands hang beside coats/skirts: nearest-transfer gives those cloth verts hand/forearm weights and they
    tear off when the arm swings. Arm weights are only legal outboard of the wrist line or above the elbow."""
    arm = [g.index for g in ob.vertex_groups if g.name.startswith(("upper_arm", "forearm", "hand"))]
    if not arm: return
    b = rig.data.bones
    wx = abs(b["hand.L"].head_local.x); ez = b["forearm.L"].head_local.z
    legs = {g.name: g for g in ob.vertex_groups}
    n = 0
    for v in ob.data.vertices:
        if v.co.z > ez or abs(v.co.x) > wx - 0.05: continue
        moved = 0.0
        for ge in v.groups:
            if ge.group in arm and ge.weight > 0:
                moved += ge.weight; ge.weight = 0.0
        if moved > 0:
            side = "L" if v.co.x >= 0 else "R"
            tgt = legs["thigh." + side] if v.co.z < b["thigh.L"].head_local.z else legs["hips"]
            tgt.add([v.index], moved, "ADD"); n += 1
    log("skirt verts freed from arm weights", n)

def _arm_proximity_guard(ob, rig):
    """arm weights are only legal close to the arm itself: fade them out between 0.04H and 0.07H from the side's
    upper_arm/forearm/hand segments and hand the rest to the torso/leg bone. Stops capes, coat backs and wide
    pauldrons being dragged into slabs when the arm swings overhead (glTF export == Blender QA)."""
    b = rig.data.bones; G = {g.name: g for g in ob.vertex_groups}
    segs = {s: [(b[n + "." + s].head_local, b[n + "." + s].tail_local) for n in ("upper_arm", "forearm", "hand")] for s in "LR"}
    armidx = {G[n + "." + s].index: s for s in "LR" for n in ("upper_arm", "forearm", "hand") if n + "." + s in G}
    r_in, r_out = 0.04 * H, 0.07 * H
    hip_z = b["thigh.L"].head_local.z; sp_z = b["spine"].head_local.z; ch_z = b["chest"].head_local.z
    n = 0
    for v in ob.data.vertices:
        moved = 0.0
        for ge in v.groups:
            sd = armidx.get(ge.group)
            if sd is None or ge.weight <= 0: continue
            d = min(_seg_dist(v.co, a, t) for a, t in segs[sd])
            f = min(1.0, max(0.0, (d - r_in) / (r_out - r_in)))
            if f > 0: moved += ge.weight * f; ge.weight *= (1 - f)
        if moved > 1e-4:
            z = v.co.z; side = "L" if v.co.x >= 0 else "R"
            tgt = "chest" if z >= ch_z else "spine" if z >= sp_z else "hips" if z >= hip_z else "thigh." + side
            G[tgt].add([v.index], moved, "ADD"); n += 1
    log("arm proximity guard moved", n)

def skin(ob, rig):
    # heat weights on a watertight voxel proxy, transferred to the real mesh (robust on farmed/non-manifold meshes)
    proxy = ob.copy(); proxy.data = ob.data.copy(); bpy.context.collection.objects.link(proxy)
    proxy.modifiers.clear()
    md = proxy.modifiers.new("vox", "REMESH"); md.mode = "VOXEL"; md.voxel_size = 0.016
    sel_only(proxy); bpy.ops.object.modifier_apply(modifier=md.name)
    # keep only the OUTER shell (surface-net thin walls leave inner cavity shells that break the heat solve)
    bm = bmesh.new(); bm.from_mesh(proxy.data); bm.verts.ensure_lookup_table()
    seen = set(); comps = []
    for v in bm.verts:
        if v.index in seen: continue
        st = [v]; comp = []; seen.add(v.index)
        while st:
            x = st.pop(); comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen: seen.add(y.index); st.append(y)
        comps.append(comp)
    comps.sort(key=lambda c: -len(c))
    kill = [v for c in comps[1:] for v in c]
    if kill: bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(proxy.data); bm.free()
    log("proxy shells", len(comps), "kept", len(proxy.data.vertices))
    bpy.ops.object.select_all(action="DESELECT"); proxy.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    ok = True
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception as e:
        ok = False; log("heat failed", e)
    nonzero = sum(1 for v in proxy.data.vertices if len(v.groups))
    if not ok or nonzero < 0.9 * len(proxy.data.vertices):
        log("heat coverage", nonzero, "/", len(proxy.data.vertices), "-> gated bone-distance weights")
        distance_weights(proxy, rig)
    for b in rig.data.bones:
        if b.name not in ob.vertex_groups: ob.vertex_groups.new(name=b.name)
    dt = ob.modifiers.new("dt", "DATA_TRANSFER"); dt.object = proxy; dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}; dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
    sel_only(ob); bpy.ops.object.modifier_apply(modifier=dt.name)
    _strip_arm_from_skirt(ob, rig)
    _arm_proximity_guard(ob, rig)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    # glTF keeps 4 influences/vertex: limit + renormalise HERE so Blender QA == exported GLB (no torn cloth sheets)
    bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.03)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.data.objects.remove(proxy, do_unlink=True)
    ob.parent = rig; am = ob.modifiers.new("Armature", "ARMATURE"); am.object = rig
    log("skinned", len(ob.vertex_groups), "groups")

def repose_to_canonical(ob, rig):
    """rotate fitted limbs so every bone points along its stand-in direction, bake mesh, rebuild rest = canonical dirs"""
    sel_only(rig); bpy.ops.object.mode_set(mode="POSE")
    order = [n for (n, _, _, _) in K.BONES]
    for n in order:
        if n == "root": continue
        pb = rig.pose.bones[n]
        bpy.context.view_layer.update()
        cur = (pb.tail - pb.head).normalized()
        want = (CANON[n][1] - CANON[n][0]).normalized()
        q = cur.rotation_difference(want)
        M = pb.matrix.copy(); head = M.translation.copy()
        R = q.to_matrix().to_4x4()
        pb.matrix = Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ M
    bpy.context.view_layer.update()
    posed = {pb.name: (pb.head.copy(), (pb.tail - pb.head).length) for pb in rig.pose.bones}
    bpy.ops.object.mode_set(mode="OBJECT")
    sel_only(ob); bpy.ops.object.modifier_apply(modifier="Armature")
    sel_only(rig); bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        if eb.name == "root": continue
        h, L = posed[eb.name]; d = (CANON[eb.name][1] - CANON[eb.name][0]).normalized()
        eb.head = h; eb.tail = h + d * L; eb.roll = 0
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.ops.object.mode_set(mode="OBJECT")
    am = ob.modifiers.new("Armature", "ARMATURE"); am.object = rig
    log("re-posed to canonical rest")

def weapons(ob, rig):
    w = OPT["weapon"]
    if w == "none": return
    hb = rig.data.bones
    hr = hb["hand.R"].head_local + 0.35 * (hb["hand.R"].tail_local - hb["hand.R"].head_local)
    hl = hb["hand.L"].head_local + 0.35 * (hb["hand.L"].tail_local - hb["hand.L"].head_local)
    ob.name = "BodyMesh"
    K.PARTS.clear(); K.build_mats()
    K.build_weapon(w, hr=tuple(hr), hl=tuple(hl), shield=OPT["shield"] == "1", quiver=OPT["quiver"] == "1")
    if K.PARTS:
        wob = K.bind(rig); wob.name = "Weapon"
    log("weapon", w, "hr", tuple(round(x, 3) for x in hr))

def qa(rig, prefix):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"; scn.cycles.device = "CPU"; scn.cycles.samples = 12; scn.cycles.use_denoising = False
    scn.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("qaw"); scn.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    sun = bpy.data.objects.new("qasun", bpy.data.lights.new("qasun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 3.5; sun.rotation_euler = (math.radians(40), 0, math.radians(-45))
    scn.render.resolution_x = 300; scn.render.resolution_y = 400; scn.render.film_transparent = False
    cam = bpy.data.objects.new("qacam", bpy.data.cameras.new("qacam")); scn.collection.objects.link(cam)
    cam.location = (1.9, -2.6, 1.15); cam.rotation_euler = (math.radians(84), 0, math.radians(36)); scn.camera = cam
    tracks = rig.animation_data.nla_tracks
    shots = [("rest", None, 1)] + [(t.name, t.name, f) for t in tracks for f in ({"attack": [12], "skill": [20], "crit": [13], "death": [30], "hit": [4], "dodge": [8], "idle": [24], "advance": [7]}.get(t.name, [1]))]
    for name, track, f in shots:
        for t in tracks: t.mute = (t.name != track)
        scn.frame_set(f); scn.render.filepath = f"{prefix}_{name}.png"; bpy.ops.render.render(write_still=True)
    for t in tracks: t.mute = False

def main():
    ob = import_clean(); normalise(ob); decimate(ob)
    if OPT["sheet"]: project_albedo(ob)
    else: plain_material(ob)
    J = landmarks(ob)
    if OPT["dump"]:  # debug: verts + joints for a silhouette overlay (tools/models/plot_landmarks)
        np.savez(OPT["dump"], co=np.array([v.co[:] for v in ob.data.vertices]), names=np.array(list(J)),
                 J=np.array([J[k][:] for k in J])); log("dumped", OPT["dump"]); return
    rig = build_fitted_rig(J); skin(ob, rig); repose_to_canonical(ob, rig)
    ob.name = "Body"
    weapons(ob, rig)
    ob.name = "Body"
    K.actions(rig, OPT["weapon"] if OPT["weapon"] != "none" else "sword")
    bpy.context.scene.render.fps = 24
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_apply=False, export_yup=True, export_skins=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=90)
    log("GLB", OUT, os.path.getsize(OUT))
    if OPT["qa"]: qa(rig, OPT["qa"])

main()
