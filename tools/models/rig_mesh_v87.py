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
OPT = {"sheet": "", "weapon": "sword", "shield": "0", "quiver": "0", "tris": "18000", "tex": "1024", "yaw": "0", "qa": "", "part": "body", "rim": "ally"}
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

def decimate(ob):
    tris = int(OPT["tris"]); cur = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if cur > tris:
        md = ob.modifiers.new("dec", "DECIMATE"); md.ratio = tris / cur; md.use_collapse_triangulate = True
        sel_only(ob); bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.shade_smooth()
    log("tris", cur, "->", sum(len(p.vertices) - 2 for p in ob.data.polygons))

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
    out.filepath_raw = "/tmp/_albedo_v87.png"; out.file_format = "PNG"; out.save()
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
        cand = co[(co[:, 0] * sx > 0.14 * H) & (co[:, 2] > 0.35 * H)]
        if len(cand):
            d = np.linalg.norm(cand - np.array(sh[:]), axis=1); tip = Vector(cand[int(np.argmax(d))])
        else:
            tip = sh + Vector((sx * 0.1, 0, -0.55))
        # pull the tip inside the hand volume a little
        J["shoulder." + s] = sh
        J["elbow." + s] = sh.lerp(tip, 0.42); J["wrist." + s] = sh.lerp(tip, 0.80); J["handtip." + s] = sh.lerp(tip, 0.95)
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

def skin(ob, rig):
    # heat weights on a watertight voxel proxy, transferred to the real mesh (robust on farmed/non-manifold meshes)
    proxy = ob.copy(); proxy.data = ob.data.copy(); bpy.context.collection.objects.link(proxy)
    proxy.modifiers.clear()
    md = proxy.modifiers.new("vox", "REMESH"); md.mode = "VOXEL"; md.voxel_size = 0.014
    sel_only(proxy); bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.select_all(action="DESELECT"); proxy.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    ok = True
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception as e:
        ok = False; log("heat failed", e)
    nonzero = sum(1 for v in proxy.data.vertices if len(v.groups))
    if not ok or nonzero < 0.9 * len(proxy.data.vertices):
        log("heat coverage", nonzero, "/", len(proxy.data.vertices), "-> envelope fallback")
        proxy.vertex_groups.clear()
        bpy.ops.object.select_all(action="DESELECT"); proxy.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
    for b in rig.data.bones:
        if b.name not in ob.vertex_groups: ob.vertex_groups.new(name=b.name)
    dt = ob.modifiers.new("dt", "DATA_TRANSFER"); dt.object = proxy; dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}; dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
    sel_only(ob); bpy.ops.object.modifier_apply(modifier=dt.name)
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
    J = landmarks(ob); rig = build_fitted_rig(J); skin(ob, rig); repose_to_canonical(ob, rig)
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
