"""v8.7 farmed hair MODULE: Hunyuan3D mesh of a faceless mannequin wearing one hairstyle -> hair cap in HEAD-BONE space.
  blender -b -P hair_module_v87.py -- in.glb out.glb --plate front_plate.png --style <id> [--qa qa.png] [--tris 7000]
Head-bone space (same as unit_model.attach_modules / build_head_modules_v87): origin = head bone head, Z up along the
bone, face toward -Y. Calibrated on the rigged farmed bald heads (rig_mesh_v87, H=1.78): chin z~-0.02, crown z~0.249,
half-width ~0.10, face front y~-0.135.
Steps: import/join/clean -> voxel re-skin + decimate -> landmarks (crown, chin from the centre-column front profile,
face front) -> map to head space -> cut the mannequin FACE (front-facing, below the brow, inside the cheek line) and NECK
/SHOULDERS (inside the neck cylinder below the chin; shoulder span) -> keep largest shells -> inflate 3% off the skull
(no z-fight with the bald scalp) -> greyscale strand albedo projected from the front plate (tinted by genome at runtime)
-> material "hair" -> GLB."""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
IN, OUT = argv[0], argv[1]
OPT = {"plate": "", "qa": "", "tris": "7000", "style": ""}
i = 2
while i < len(argv):
    OPT[argv[i].lstrip("-")] = argv[i + 1]; i += 2
CHIN_Z, CROWN_Z, FACE_Y, HALF_W = -0.02, 0.249, -0.135, 0.10
SKULL_C = Vector((0.0, -0.03, 0.115))
# per-style plate calibration (measured on the style-locked hair plates, docs/art/review/hair_plates_grid_v87.png):
# chin row as a fraction of the subject bbox from the top, and hair volume above the skull as a fraction of chin->top.
# Hunyuan keeps the front silhouette, so the mesh bbox maps 1:1 onto the plate subject bbox.
STYLE_CAL = {"bob": (0.72, 0.06), "crop": (0.68, 0.08), "crown": (0.75, 0.08), "long": (0.64, 0.05),
             "messy": (0.73, 0.12), "pony": (0.66, 0.24), "swept": (0.70, 0.13), "tied": (0.675, 0.06)}

def log(*a): print("[hair_v87]", *a, flush=True)

def sel_only(ob):
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob

def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=IN)
    ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH": bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms: o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1: bpy.ops.object.join()
    ob = bpy.context.active_object; ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # voxel re-skin (closes surface-net cracks), then decimate to budget
    co = np.array([v.co[:] for v in ob.data.vertices]); ext = (co.max(0) - co.min(0)).max()
    md = ob.modifiers.new("vox", "REMESH"); md.mode = "VOXEL"; md.voxel_size = ext / 260
    bpy.ops.object.modifier_apply(modifier=md.name)
    keep_largest(ob, 0.02)
    tgt = int(OPT["tris"]) * 2  # pre-cut budget (the cut removes ~half)
    for _ in range(6):
        n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        if n <= tgt * 1.05: break
        md = ob.modifiers.new("dec", "DECIMATE"); md.ratio = max(0.05, tgt / n)
        bpy.ops.object.modifier_apply(modifier=md.name)
    log("import", IN, "faces", len(ob.data.polygons))
    return ob

def keep_largest(ob, frac):
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
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
    n = len(bm.verts)
    kill = [v for c in comps if len(c) < frac * n for v in c]
    if kill: bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return len(comps)

def landmarks(co):
    """crown = max z; chin = where the centre-column front profile steps back (face -> neck) scanning downward."""
    top = co[:, 2].max(); bot = co[:, 2].min(); Hh = top - bot
    W = co[:, 0].max() - co[:, 0].min()
    col = co[np.abs(co[:, 0] - np.median(co[:, 0])) < 0.05 * W]
    zs = np.arange(top - 0.25 * Hh, bot + 0.05 * Hh, -0.01 * Hh)
    prof = []
    for z in zs:
        s = col[(col[:, 2] <= z) & (col[:, 2] > z - 0.012 * Hh)]
        prof.append(s[:, 1].min() if len(s) else np.nan)
    prof = np.array(prof)
    face_y = np.nanmin(prof[: max(3, len(prof) // 2)])
    depth = co[:, 1].max() - co[:, 1].min()
    chin = None
    for k in range(3, len(prof)):
        if np.isnan(prof[k]): continue
        # neck: the front surface has stepped back by > 18% of the head depth relative to the face front
        if prof[k] - face_y > 0.18 * depth and zs[k] < top - 0.45 * Hh:
            chin = zs[k] + 0.01 * Hh; break
    if chin is None:
        chin = top - 0.62 * Hh; log("chin fallback")
    return top, chin, face_y, np.median(co[:, 0])

def to_head_space(ob):
    co = np.array([v.co[:] for v in ob.data.vertices])
    top, bot = co[:, 2].max(), co[:, 2].min()
    cx = 0.5 * (co[:, 0].max() + co[:, 0].min())
    if OPT["style"] in STYLE_CAL:
        cf, vol = STYLE_CAL[OPT["style"]]
        chin = top - cf * (top - bot)
    else:
        top, chin, _, cx = landmarks(co); vol = 0.07
    hh = top - chin
    # face front = front-most centre-column point on the LOWER face (below any fringe/bangs)
    W = co[:, 0].max() - co[:, 0].min()
    band = co[(np.abs(co[:, 0] - cx) < 0.06 * W) & (co[:, 2] > chin + 0.12 * hh) & (co[:, 2] < chin + 0.42 * hh)]
    face_y = float(band[:, 1].min()) if len(band) else float(co[:, 1].min())
    s = (CROWN_Z - CHIN_Z) / (hh * (1.0 - vol))
    for v in ob.data.vertices:
        p = v.co
        v.co = Vector(((p.x - cx) * s, (p.y - face_y) * s + FACE_Y, (p.z - chin) * s + CHIN_Z))
    ob.data.update()
    log("map top %.3f chin %.3f face_y %.3f scale %.4f style %s" % (top, chin, face_y, s, OPT["style"] or "auto"))

def roughness(bm):
    """per-vertex strand relief: 1 - n.(2-ring mean normal), relaxed 3x. Mannequin skin ~0, farmed hair clumps >> 0."""
    bm.verts.ensure_lookup_table(); bm.normal_update()
    dev = np.zeros(len(bm.verts))
    for v in bm.verts:
        ring = set([v])
        for e in v.link_edges:
            w = e.other_vert(v); ring.add(w)
            for e2 in w.link_edges: ring.add(e2.other_vert(w))
        n = Vector((0, 0, 0))
        for w in ring: n += w.normal
        if n.length > 0: dev[v.index] = 1.0 - v.normal.dot(n.normalized())
    for _ in range(3):
        nd = dev.copy()
        for v in bm.verts:
            nb = [e.other_vert(v).index for e in v.link_edges]
            if nb: nd[v.index] = 0.5 * dev[v.index] + 0.5 * dev[nb].mean()
        dev = nd
    return dev

BELOW_CHIN = {"tied": "back", "pony": "back", "long": "sides", "bob": "sides"}

def cut(ob):
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.normal_update()
    dev = roughness(bm)
    co = np.array([v.co[:] for v in bm.verts])
    skin_ref = dev[(co[:, 1] < -0.10) & (np.abs(co[:, 0]) < 0.04) & (co[:, 2] > 0.02) & (co[:, 2] < 0.10)]
    hair_ref = dev[co[:, 2] > 0.21]
    t = float(np.sqrt(max(1e-6, np.median(skin_ref) if len(skin_ref) else 0.002) * max(1e-6, np.median(hair_ref))))
    log("roughness skin %.4f hair %.4f -> thr %.4f" % (np.median(skin_ref) if len(skin_ref) else -1, np.median(hair_ref), t))
    mode = BELOW_CHIN.get(OPT["style"], "none")
    brow = 0.155; kill = []
    for v in bm.verts:
        p = v.co; d = dev[v.index]
        smooth = d < t
        face = (p.z < brow) and (p.z > CHIN_Z - 0.04) and (abs(p.x) < 0.085) and (p.y < SKULL_C.y - 0.04)
        skin_low = smooth and p.z < 0.13                      # nape / sides / neck skin the farm invented
        below = p.z < CHIN_Z + 0.01
        keep_below = False
        if below:
            if mode == "back": keep_below = (p.y > SKULL_C.y + 0.07) and not smooth
            elif mode == "sides": keep_below = (p.z > CHIN_Z - 0.12) and (abs(p.x) > 0.07 or p.y > SKULL_C.y + 0.07) and not smooth
        if face or skin_low or (below and not keep_below): kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(me); bm.free(); me.update()
    shells = keep_largest(ob, 0.03)
    for v in me.vertices:
        d = v.co - SKULL_C; v.co = SKULL_C + d * 1.03
    me.update()
    log("cut verts", len(kill), "shells", shells, "faces", len(me.polygons), "below-chin", mode)

def albedo(ob):
    mat = bpy.data.materials.new("hair"); mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.55
    if OPT["plate"]:
        img = bpy.data.images.load(os.path.abspath(OPT["plate"]))
        w, h = img.size
        px = np.array(img.pixels[:]).reshape(h, w, -1)[:, :, :3]
        # plate framing: subject bbox (non-background) -> head-space x/z
        bg = np.median(np.concatenate([px[0], px[-1], px[:, 0], px[:, -1]]), 0)
        m = np.abs(px - bg).sum(-1) > 0.08
        ys, xs = np.where(m)
        co = np.array([v.co[:] for v in ob.data.vertices])
        x0, x1, z0, z1 = co[:, 0].min(), co[:, 0].max(), co[:, 2].min(), co[:, 2].max()
        u0, u1 = xs.min() / w, xs.max() / w; v0, v1 = ys.min() / h, ys.max() / h   # pixel rows from the bottom
        uv = ob.data.uv_layers.new(name="UVMap")
        for lp in ob.data.loops:
            p = ob.data.vertices[lp.vertex_index].co
            uv.data[lp.index].uv = (u0 + (p.x - x0) / max(1e-6, x1 - x0) * (u1 - u0), v1 - (z1 - p.z) / max(1e-6, z1 - z0) * (v1 - v0))
        # greyscale, contrast-normalised strand texture (genome colour multiplies it in Godot)
        g = px.mean(-1); g = np.clip((g - np.percentile(g[m], 5)) / max(1e-3, np.percentile(g[m], 95) - np.percentile(g[m], 5)), 0, 1)
        g = 0.45 + 0.55 * g
        out = bpy.data.images.new("hair_albedo", w, h, alpha=False)
        rgba = np.dstack([g, g, g, np.ones_like(g)]).astype(np.float32)
        out.pixels[:] = rgba.ravel(); out.file_format = "JPEG"
        out.filepath_raw = os.path.join(__import__("tempfile").mkdtemp(prefix="ckhair_"), "hair_albedo.jpg"); out.save(); out.pack()
        t = mat.node_tree.nodes.new("ShaderNodeTexImage"); t.image = out
        mat.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
    ob.data.materials.clear(); ob.data.materials.append(mat)

def qa(ob, path):
    scn = bpy.context.scene; scn.render.engine = "CYCLES"; scn.cycles.samples = 16; scn.cycles.device = "CPU"
    scn.render.resolution_x, scn.render.resolution_y = 900, 300
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=SKULL_C); sk = bpy.context.active_object
    sk.scale = (0.10, 0.12, 0.13); m = bpy.data.materials.new("skin"); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.62, 0.55, 1); sk.data.materials.append(m)
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1)
    L = bpy.data.lights.new("k", "SUN"); L.energy = 3.5; lo = bpy.data.objects.new("k", L); scn.collection.objects.link(lo); lo.rotation_euler = (math.radians(50), 0, math.radians(-40))
    cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = 0.42; co = bpy.data.objects.new("c", cam); scn.collection.objects.link(co); scn.camera = co
    import tempfile
    tiles = []
    for k, (loc, rot) in enumerate([((0, -2, 0.11), (90, 0, 0)), ((2, 0, 0.11), (90, 0, 90)), ((0, 2, 0.11), (90, 0, 180))]):
        co.location = loc; co.rotation_euler = tuple(math.radians(a) for a in rot)
        scn.render.resolution_x = scn.render.resolution_y = 300
        f = os.path.join(tempfile.mkdtemp(), "t.png"); scn.render.filepath = f; bpy.ops.render.render(write_still=True); tiles.append(f)
    imgs = [bpy.data.images.load(f) for f in tiles]
    W = 900; Hh = 300; out = np.zeros((Hh, W, 4), np.float32)
    for k, im in enumerate(imgs):
        out[:, k * 300:(k + 1) * 300] = np.array(im.pixels[:]).reshape(300, 300, 4)
    o = bpy.data.images.new("qa", W, Hh); o.pixels[:] = out.ravel(); o.filepath_raw = path; o.file_format = "PNG"; o.save()
    bpy.data.objects.remove(sk, do_unlink=True)

ob = load(); to_head_space(ob); cut(ob); ob.name = "hair"; albedo(ob)
for poly in ob.data.polygons: poly.use_smooth = True
sel_only(ob)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_jpeg_quality=88)
log("GLB", OUT, os.path.getsize(OUT))
if OPT["qa"]: qa(ob, OPT["qa"])
