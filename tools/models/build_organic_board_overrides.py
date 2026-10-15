#!/usr/bin/env python3
"""Build organic formal board-figure overrides from Hunyuan / farm_cast.

NO cube/cylinder face stacks. Pipeline:
  1. Prefer high-res hy_* in farm_inbox; else farm_cast retopo.
  2. Collapse-decimate (preserves organic silhouette vs voxel).
  3. Shade smooth + light Laplacian smooth.
  4. Board head enlarge (~1.28× above neck) for 38° readability.
  5. Spatial vertex-colour slots (R=slot G=AO B=flags).
  6. Write compose_*.glb into tools/models/board_parts/ for generator override.

Also writes organic body_m / head_m / outfit_* region splits when possible.

  blender -b -P tools/models/build_organic_board_overrides.py
"""
from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "tools/models/board_parts/farm_inbox"
FARM = ROOT / "project/assets/models/board/farm_cast"
OUT = ROOT / "tools/models/board_parts"
PREVIEW = ROOT / "docs/art/review/board_figure_p1/organic_preview"
MODEL_H = 1.85
TARGET = 5600
NECK_Z = 1.48  # around chin/neck for 5.45 heads @ 1.85m

SLOT = {
    "hair": 0, "skin": 1, "eye": 2, "coat": 3, "coat_dark": 4, "apron": 5,
    "sash": 6, "metal": 7, "blade": 8, "house": 9, "crest": 10, "cape": 11,
    "trousers": 12, "boots": 13, "leather": 14, "wood": 15, "accent": 16,
}

# (compose_name, preferred_sources in order, outfit_override_name, notes)
FIGURES = [
    # Prefer high-res hy when present (proper manifold remesh). Else farm_cast.
    ("compose_captain", ["hy_leader_m.glb", "leader_m.glb"], "outfit_captain", "ally"),
    ("compose_hunter", ["hunter_m.glb"], "outfit_hunter", "ally"),
    ("compose_bandit_weak", ["bandit_weak.glb", "bandit.glb"], "outfit_bandit_weak", "enemy"),
    ("compose_bandit", ["hy_bandit.glb", "bandit.glb"], "outfit_bandit_bandit", "enemy"),
    ("compose_bandit_archer", ["hy_bandit_archer.glb", "bandit_archer.glb"], "outfit_bandit_archer", "enemy"),
    ("compose_bandit_chief", ["bandit_chief.glb", "hy_bandit.glb", "bandit.glb"], "outfit_bandit_chief", "enemy"),
]


def log(*a):
    print("[organic_overrides]", *a, flush=True)


def tris(ob) -> int:
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def find_src(names: list[str]) -> Path | None:
    for n in names:
        for base in (INBOX, FARM):
            p = base / n
            if p.is_file() and p.stat().st_size > 1000:
                return p
    return None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_join(src: Path):
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name not in before]
    if not meshes:
        raise RuntimeError(f"no mesh in {src}")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def apply_mod(ob, md_name: str):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=md_name)
    except Exception as e:
        log("mod fail", md_name, e)
        if md_name in ob.modifiers:
            ob.modifiers.remove(ob.modifiers[md_name])


def normalize_height(ob):
    coords = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector(tuple(min(c[i] for c in coords) for i in range(3)))
    mx = Vector(tuple(max(c[i] for c in coords) for i in range(3)))
    h = max(1e-6, mx.z - mn.z)
    s = MODEL_H / h
    ob.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    coords = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector(tuple(min(c[i] for c in coords) for i in range(3)))
    mx = Vector(tuple(max(c[i] for c in coords) for i in range(3)))
    ob.location = (-0.5 * (mn.x + mx.x), -0.5 * (mn.y + mx.y), -mn.z)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


def collapse_to(ob, target: int):
    """Always produce a welded manifold. farm_cast exports were nearly unwelded tris."""
    t0 = tris(ob)
    log("start tris", t0, "verts", len(ob.data.vertices))
    # 1) Weld whatever we have
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    log("after weld", tris(ob), "verts", len(ob.data.vertices))
    # 2) Voxel remesh → guaranteed manifold (even if farm_cast was broken)
    for vs in (0.014, 0.018, 0.022, 0.028, 0.035):
        md = ob.modifiers.new("VR", "REMESH")
        md.mode = "VOXEL"
        md.voxel_size = vs
        md.adaptivity = 0.0
        apply_mod(ob, md.name)
        t = tris(ob)
        log(f"voxel {vs}", t, "verts", len(ob.data.vertices))
        if 2000 <= t <= target * 3.5:
            break
        if t < 2000:
            # too coarse — undo by stopping; last pass may be coarse
            break
    t = tris(ob)
    if t > target:
        md = ob.modifiers.new("D", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.05, min(0.95, target / float(max(1, t))))
        md.use_collapse_triangulate = True
        apply_mod(ob, md.name)
        log("collapse", tris(ob))
    if tris(ob) > 7000:
        md = ob.modifiers.new("Dcap", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.05, 6500 / float(tris(ob)))
        apply_mod(ob, md.name)
        log("cap", tris(ob))
    bpy.ops.object.shade_smooth()
    # Very light smooth only — heavy Lap melted holes in the solid.
    md = ob.modifiers.new("Lap", "LAPLACIANSMOOTH")
    md.iterations = 2
    md.lambda_factor = 0.15
    md.use_volume_preserve = True
    apply_mod(ob, md.name)
    bpy.ops.object.shade_smooth()
    # Weld again after smooth
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    log("final geometry", tris(ob), "verts", len(ob.data.vertices))


def fill_holes(ob, sides: int = 200):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.fill_holes(sides=sides)
    except Exception as e:
        log("fill_holes", e)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()



def enhance_face(ob):
    """Boolean-union small organic face masses (nose/brow/chin) — not cubes."""
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmax = max(zs)
    # Head front center
    head = [v for v in me.vertices if v.co.z >= NECK_Z]
    if len(head) < 30:
        return
    cx = sum(v.co.x for v in head) / len(head)
    # Face looks -Y
    face_y = min(v.co.y for v in head) - 0.01
    cz_face = NECK_Z + 0.14
    # Build metaball face kit then boolean
    bpy.ops.object.metaball_add(type="ELLIPSOID", radius=0.028, location=(cx, face_y, cz_face + 0.02))
    mb = bpy.context.active_object
    mb.data.resolution = 0.02
    el = mb.data.elements
    el[0].size_x, el[0].size_y, el[0].size_z = 0.7, 1.6, 1.0  # nose
    e = el.new(); e.type = "ELLIPSOID"; e.radius = 0.04; e.co = (cx, face_y + 0.02, cz_face + 0.08)
    e.size_x, e.size_y, e.size_z = 1.8, 0.55, 0.4  # brow
    e = el.new(); e.type = "BALL"; e.radius = 0.035; e.co = (cx, face_y + 0.01, cz_face - 0.06)  # chin tip
    e = el.new(); e.type = "BALL"; e.radius = 0.03; e.co = (cx + 0.045, face_y + 0.02, cz_face)
    e = el.new(); e.type = "BALL"; e.radius = 0.03; e.co = (cx - 0.045, face_y + 0.02, cz_face)
    bpy.ops.object.convert(target="MESH")
    face = bpy.context.active_object
    face.name = "FaceBoost"
    # Boolean union onto body
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    md = ob.modifiers.new("FaceBool", "BOOLEAN")
    md.operation = "UNION"
    md.solver = "FAST"
    md.object = face
    try:
        apply_mod(ob, md.name)
    except Exception as e:
        log("face bool", e)
        if md.name in ob.modifiers:
            ob.modifiers.remove(md)
    bpy.data.objects.remove(face, do_unlink=True)
    # Keep tris budget
    if tris(ob) > 7000:
        md = ob.modifiers.new("Df", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = 6500 / float(tris(ob))
        apply_mod(ob, md.name)
    bpy.ops.object.shade_smooth()
    log("face enhance", tris(ob))


def enlarge_head(ob, factor: float = 1.28):
    """Scale vertices above neck radially from head center (board readability)."""
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmax = max(zs)
    neck = NECK_Z
    # Head center approx
    head_vs = [v for v in me.vertices if v.co.z >= neck]
    if len(head_vs) < 20:
        return
    cx = sum(v.co.x for v in head_vs) / len(head_vs)
    cy = sum(v.co.y for v in head_vs) / len(head_vs)
    cz = sum(v.co.z for v in head_vs) / len(head_vs)
    for v in me.vertices:
        if v.co.z < neck:
            continue
        # Smooth blend from neck to crown
        w = (v.co.z - neck) / max(1e-4, zmax - neck)
        w = max(0.0, min(1.0, w))
        w = w * w * (3 - 2 * w)  # smoothstep
        f = 1.0 + (factor - 1.0) * w
        v.co.x = cx + (v.co.x - cx) * f
        v.co.y = cy + (v.co.y - cy) * f
        v.co.z = cz + (v.co.z - cz) * f
    me.update()
    # Re-seat feet after head growth may shift bbox slightly
    normalize_height(ob)


def paint_slots(ob, kind: str):
    """Spatial slot paint on POINT domain (keeps manifold through glTF)."""
    me = ob.data
    while me.color_attributes:
        me.color_attributes.remove(me.color_attributes[0])
    attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    me.update()
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    # Average normals per vertex from adjacent polys
    vnorm = [Vector((0, 0, 0)) for _ in me.vertices]
    vcount = [0] * len(me.vertices)
    for poly in me.polygons:
        for vi in poly.vertices:
            vnorm[vi] += poly.normal
            vcount[vi] += 1
    for i in range(len(me.vertices)):
        if vcount[i]:
            vnorm[i] = (vnorm[i] / vcount[i]).normalized()
        v = me.vertices[i]
        cz = v.co.z
        cx = v.co.x
        cy = v.co.y
        n = vnorm[i]
        t = (cz - zmin) / max(1e-6, zmax - zmin)
        ao = 0.78 + 0.22 * max(0.0, min(1.0, cz / 1.25))
        front = -n.y
        up = n.z
        out = math.sqrt(n.x * n.x + n.y * n.y)
        slot = "coat"
        flags = 0.0
        if t < 0.10:
            slot = "boots"; ao *= 0.92
        elif t < 0.38:
            slot = "trousers"; ao *= 0.90
        elif cz >= NECK_Z - 0.02:
            face_band = NECK_Z + 0.08 < cz < NECK_Z + 0.22
            if face_band and front > 0.35 and abs(cx) < 0.09:
                slot = "eye" if (up < 0.15 and front > 0.55) else "skin"
            elif cz > NECK_Z + 0.22 and (up > 0.25 or front < 0.15 or cy > 0.02):
                slot = "hair"
            elif front > 0.25 and cz < NECK_Z + 0.28:
                slot = "skin"
            else:
                slot = "hair"
        else:
            if n.y > 0.45 and t > 0.40 and abs(cx) > 0.05:
                slot = "cape" if kind == "ally" else "coat_dark"
            elif cz > NECK_Z - 0.12 and cz < NECK_Z + 0.05:
                slot = "coat_dark"
            elif 0.95 < cz < 1.08 and abs(cy) < 0.12:
                slot = "house" if kind == "ally" else "sash"
            elif abs(cx) > 0.22 and 1.05 < cz < 1.35:
                slot = "leather"
            elif t > 0.55 and out > 0.85 and abs(cx) > 0.18 and cz > 1.25:
                slot = "metal"; flags = 0.25
            elif abs(cx) > 0.28 and 0.85 < cz < 1.25 and front > -0.2:
                slot = "skin"
            elif up < -0.35 and t > 0.40:
                slot = "coat_dark"
            else:
                slot = "coat"
        sid = SLOT[slot]
        attr.data[i].color = (sid / 255.0, max(0.55, min(1.0, ao)), flags, 1.0)
    me.update()
    bpy.ops.object.shade_smooth()


def strip_extras(ob):
    ob.data.materials.clear()
    while ob.data.uv_layers:
        ob.data.uv_layers.remove(ob.data.uv_layers[0])


def export_glb(ob, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    # solo scene objects except this
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o, do_unlink=True)
    ob.name = path.stem
    if ob.data:
        ob.data.name = path.stem
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=False,
        export_normals=True,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
    )
    log("wrote", path.name, "tris", tris(ob), "bytes", path.stat().st_size)


def render_preview(ob, path: Path, title: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    # simple clay+slot viz: use vertex color as base via attribute
    mat = bpy.data.materials.new("prev")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.78, 0.74, 0.68, 1)
    bsdf.inputs["Roughness"].default_value = 0.48
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    # Frame full figure including crown.
    zs = [v.co.z for v in ob.data.vertices]
    zc = 0.5 * (min(zs) + max(zs))
    cam.location = (2.05, -3.6, zc + 0.15)
    direction = Vector((0.0, 0.0, zc)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 50
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "SUN"))
    light.data.energy = 2.6
    light.rotation_euler = (math.radians(48), 0, math.radians(-35))
    bpy.context.collection.objects.link(light)
    fill = bpy.data.objects.new("F", bpy.data.lights.new("F", "AREA"))
    fill.data.energy = 55
    fill.data.size = 2.5
    fill.location = (-1.4, 1.2, 2.2)
    bpy.context.collection.objects.link(fill)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 28
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 420
    sc.render.resolution_y = 560
    sc.render.film_transparent = True
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    log("preview", title, path.name)


def build_one(compose_name: str, sources: list[str], outfit_name: str, kind: str):
    src = find_src(sources)
    if src is None:
        log("SKIP no source", compose_name, sources)
        return None
    log("===", compose_name, "from", src)
    reset()
    ob = import_join(src)
    normalize_height(ob)
    collapse_to(ob, TARGET)
    fill_holes(ob)
    normalize_height(ob)
    enlarge_head(ob, 1.30 if kind == "ally" else 1.24)
    # Face metaball boolean disabled: FAST boolean left overlapping faces → Godot z-fight.
    # Rely on farm_cast face planes + head enlarge + slot paint for readability.
    fill_holes(ob)
    # Force smooth consistent normals
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.mesh.remove_doubles(threshold=0.0015)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    paint_slots(ob, kind)
    strip_extras(ob)
    # duplicate for outfit override name (same mesh — assemble uses compose only)
    compose_path = OUT / f"{compose_name}.glb"
    export_glb(ob, compose_path)
    # preview
    reset()
    bpy.ops.import_scene.gltf(filepath=str(compose_path))
    ob3 = [o for o in bpy.data.objects if o.type == "MESH"][0]
    render_preview(ob3, PREVIEW / f"{compose_name}.png", compose_name)
    return compose_path


def build_organic_body_head():
    """Metaball organic body_m + head_m for modular fallback (not cubes)."""
    reset()
    # ---- head via metaballs ----
    bpy.ops.object.metaball_add(type="BALL", radius=0.14, location=(0, -0.02, 1.68))
    mb = bpy.context.active_object
    mb.data.resolution = 0.04
    mb.data.render_resolution = 0.04
    # jaw
    bpy.ops.object.metaball_add(type="ELLIPSOID", radius=0.10, location=(0, -0.04, 1.58))
    bpy.context.active_object.data.elements[0].size_x = 1.15
    bpy.context.active_object.data.elements[0].size_y = 0.95
    bpy.context.active_object.data.elements[0].size_z = 0.75
    # nose
    bpy.ops.object.metaball_add(type="ELLIPSOID", radius=0.035, location=(0, -0.145, 1.64))
    bpy.context.active_object.data.elements[0].size_y = 1.4
    bpy.context.active_object.data.elements[0].size_z = 0.9
    # brow
    bpy.ops.object.metaball_add(type="ELLIPSOID", radius=0.06, location=(0, -0.10, 1.70))
    bpy.context.active_object.data.elements[0].size_x = 1.6
    bpy.context.active_object.data.elements[0].size_y = 0.7
    bpy.context.active_object.data.elements[0].size_z = 0.45
    # convert all metaballs — join by converting family
    # Blender metaballs of same family: set family on first
    # Simpler: convert each to mesh then boolean union
    metas = [o for o in bpy.data.objects if o.type == "META"]
    # Use one metaball object with multiple elements instead
    reset()
    bpy.ops.object.metaball_add(type="BALL", radius=0.145, location=(0, -0.02, 1.68))
    mobj = bpy.context.active_object
    mobj.data.resolution = 0.035
    mobj.data.render_resolution = 0.035
    el = mobj.data.elements
    # jaw
    e = el.new()
    e.type = "ELLIPSOID"
    e.radius = 0.11
    e.co = (0, -0.035, 1.575)
    e.size_x, e.size_y, e.size_z = 1.2, 1.0, 0.8
    # chin
    e = el.new(); e.type = "BALL"; e.radius = 0.045; e.co = (0, -0.08, 1.52)
    # nose
    e = el.new(); e.type = "ELLIPSOID"; e.radius = 0.032; e.co = (0, -0.15, 1.635)
    e.size_x, e.size_y, e.size_z = 0.7, 1.5, 0.95
    # brow
    e = el.new(); e.type = "ELLIPSOID"; e.radius = 0.055; e.co = (0, -0.11, 1.705)
    e.size_x, e.size_y, e.size_z = 1.7, 0.65, 0.4
    # cheeks
    e = el.new(); e.type = "BALL"; e.radius = 0.05; e.co = (0.07, -0.08, 1.60)
    e = el.new(); e.type = "BALL"; e.radius = 0.05; e.co = (-0.07, -0.08, 1.60)
    # convert
    bpy.ops.object.convert(target="MESH")
    head = bpy.context.active_object
    head.name = "head_m"
    # decimate if needed
    if tris(head) > 900:
        md = head.modifiers.new("D", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = 800 / float(tris(head))
        apply_mod(head, md.name)
    bpy.ops.object.shade_smooth()
    # paint skin + eye recesses
    me = head.data
    me.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    attr = me.color_attributes[0]
    for poly in me.polygons:
        n = poly.normal
        cz = sum(me.vertices[me.loops[li].vertex_index].co.z for li in poly.loop_indices) / len(poly.loop_indices)
        cy = sum(me.vertices[me.loops[li].vertex_index].co.y for li in poly.loop_indices) / len(poly.loop_indices)
        slot = "skin"
        if -n.y > 0.55 and 1.62 < cz < 1.70 and cy < -0.05:
            slot = "eye"
        ao = 0.88 + 0.1 * (cz - 1.5)
        col = (SLOT[slot] / 255.0, max(0.7, min(1.0, ao)), 0.0, 1.0)
        for li in poly.loop_indices:
            attr.data[li].color = col
    export_glb(head, OUT / "head_m.glb")

    # ---- body via metaballs ----
    reset()
    bpy.ops.object.metaball_add(type="ELLIPSOID", radius=0.22, location=(0, 0, 1.22))
    mobj = bpy.context.active_object
    mobj.data.resolution = 0.045
    mobj.data.render_resolution = 0.045
    el = mobj.data.elements
    el[0].size_x, el[0].size_y, el[0].size_z = 1.15, 0.7, 1.35  # torso
    # pelvis
    e = el.new(); e.type = "ELLIPSOID"; e.radius = 0.18; e.co = (0, 0, 0.95)
    e.size_x, e.size_y, e.size_z = 1.2, 0.75, 0.7
    # legs
    for sx in (-1, 1):
        e = el.new(); e.type = "CAPSULE"; e.radius = 0.09; e.co = (sx * 0.11, 0, 0.55)
        e.size_z = 2.2
        e = el.new(); e.type = "CAPSULE"; e.radius = 0.075; e.co = (sx * 0.12, 0.02, 0.22)
        e.size_z = 1.6
        e = el.new(); e.type = "BALL"; e.radius = 0.07; e.co = (sx * 0.12, 0.06, 0.04)  # feet
    # arms
    for sx in (-1, 1):
        e = el.new(); e.type = "CAPSULE"; e.radius = 0.065; e.co = (sx * 0.32, 0, 1.28)
        e.size_x = 2.0; e.size_z = 0.7
        e = el.new(); e.type = "CAPSULE"; e.radius = 0.055; e.co = (sx * 0.42, -0.02, 1.05)
        e.size_z = 1.5
        e = el.new(); e.type = "BALL"; e.radius = 0.055; e.co = (sx * 0.45, -0.04, 0.88)  # hands
    # shoulders
    e = el.new(); e.type = "ELLIPSOID"; e.radius = 0.16; e.co = (0, 0, 1.40)
    e.size_x, e.size_y, e.size_z = 1.6, 0.7, 0.55
    bpy.ops.object.convert(target="MESH")
    body = bpy.context.active_object
    body.name = "body_m"
    normalize_height(body)
    # scale body to leave head room — body alone feet to shoulder ~1.45
    if tris(body) > 2200:
        md = body.modifiers.new("D", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = 2000 / float(tris(body))
        apply_mod(body, md.name)
    bpy.ops.object.shade_smooth()
    me = body.data
    me.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    attr = me.color_attributes[0]
    for poly in me.polygons:
        idxs = [me.loops[li].vertex_index for li in poly.loop_indices]
        cz = sum(me.vertices[i].co.z for i in idxs) / len(idxs)
        cx = abs(sum(me.vertices[i].co.x for i in idxs) / len(idxs))
        if cz < 0.12:
            slot = "boots"
        elif cz < 0.95:
            slot = "trousers"
        elif cx > 0.35 and cz < 1.15:
            slot = "skin"  # hands
        else:
            slot = "skin"
        ao = 0.80 + 0.18 * min(1.0, cz / 1.3)
        col = (SLOT[slot] / 255.0, ao, 0.0, 1.0)
        for li in poly.loop_indices:
            attr.data[li].color = col
    export_glb(body, OUT / "body_m.glb")
    # body_f: slightly narrower copy
    reset()
    bpy.ops.import_scene.gltf(filepath=str(OUT / "body_m.glb"))
    bf = [o for o in bpy.data.objects if o.type == "MESH"][0]
    for v in bf.data.vertices:
        v.co.x *= 0.92
        if 0.9 < v.co.z < 1.35:
            v.co.x *= 0.95
    bf.name = "body_f"
    export_glb(bf, OUT / "body_f.glb")
    # head_f copy
    reset()
    bpy.ops.import_scene.gltf(filepath=str(OUT / "head_m.glb"))
    hf = [o for o in bpy.data.objects if o.type == "MESH"][0]
    for v in hf.data.vertices:
        v.co.x *= 0.94
        v.co.z = 1.55 + (v.co.z - 1.55) * 0.98
    hf.name = "head_f"
    export_glb(hf, OUT / "head_f.glb")
    log("organic body/head done")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    built = []
    for compose, sources, outfit, kind in FIGURES:
        p = build_one(compose, sources, outfit, kind)
        if p:
            built.append(p.name)
    # body/head metaball fallback deferred — compose_* is the P1 deliverable
    # build_organic_body_head()
    log("DONE overrides", built)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        log("FATAL", e)
        import traceback
        traceback.print_exc()
        raise SystemExit(1)
