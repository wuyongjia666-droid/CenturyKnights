#!/usr/bin/env python3
"""Organic board overrides — HEAD PRESERVED + hair modules + body LOD (no head voxel).

Pipeline:
  1. Head from Hunyuan (preferred) — aggressive weld + collapse ONLY (never voxel).
  2. Body from farm_cast (preferred) — voxel board LOD + bisect rings + FACE-domain slots.
  3. Export compose_* = body-only; head_m/head_f from captain hy head.
  4. Runtime CKBoardFigure attaches head_* + hair_* with compose body.

  blender -b -P tools/models/build_organic_board_overrides.py
"""
from __future__ import annotations

import math
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "tools/models/board_parts/farm_inbox"
FARM = ROOT / "project/assets/models/board/farm_cast"
OUT = ROOT / "tools/models/board_parts"
PREVIEW = ROOT / "docs/art/review/board_figure_p1/organic_preview"
MODEL_H = 1.85
BODY_TARGET = 3000
HEAD_TARGET = 1800
NECK_FRAC = 0.80

SLOT = {
    "hair": 0, "skin": 1, "eye": 2, "coat": 3, "coat_dark": 4, "apron": 5,
    "sash": 6, "metal": 7, "blade": 8, "house": 9, "crest": 10, "cape": 11,
    "trousers": 12, "boots": 13, "leather": 14, "wood": 15, "accent": 16,
}

# (name, head_sources, body_sources, kind, export_shared_head)
FIGURES = [
    ("compose_captain",
     ["hy_leader_m.glb", "leader_m.glb"],
     ["leader_m.glb", "hy_leader_m.glb"],
     "ally", True),
    ("compose_hunter",
     ["hunter_m.glb"], ["hunter_m.glb"],
     "ally", False),
    ("compose_bandit_weak",
     ["bandit_weak.glb", "bandit.glb"],
     ["bandit_weak.glb", "bandit.glb"],
     "enemy", False),
    ("compose_bandit",
     ["hy_bandit.glb", "bandit.glb"],
     ["bandit.glb", "hy_bandit.glb"],
     "enemy", False),
    ("compose_bandit_archer",
     ["hy_bandit_archer.glb", "bandit_archer.glb"],
     ["bandit_archer.glb", "hy_bandit_archer.glb"],
     "enemy", False),
    ("compose_bandit_chief",
     ["bandit_chief.glb", "hy_bandit.glb", "bandit.glb"],
     ["bandit_chief.glb", "bandit.glb"],
     "enemy", False),
]


def log(*a):
    print("[organic_overrides]", *a, flush=True)


def tris(ob) -> int:
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def find_src(names):
    for n in names:
        for base in (INBOX, FARM):
            p = base / n
            if p.is_file() and p.stat().st_size > 1000:
                return p
    return None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def apply_mod(ob, name):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=name)
    except Exception as e:
        log("mod fail", name, e)
        if name in ob.modifiers:
            ob.modifiers.remove(ob.modifiers[name])


def _weld(ob, thr=0.0015):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=thr)
    try:
        bpy.ops.mesh.normals_make_consistent(inside=False)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")


def import_join(src: Path):
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh " + str(src))
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.active_object


def normalize_height(ob):
    zs = [v.co.z for v in ob.data.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(1e-4, zmax - zmin)
    s = MODEL_H / h
    for v in ob.data.vertices:
        v.co *= s
    zs = [v.co.z for v in ob.data.vertices]
    zmin = min(zs)
    for v in ob.data.vertices:
        v.co.z -= zmin
    ob.data.update()


def neck_z_of(ob) -> float:
    zs = [v.co.z for v in ob.data.vertices]
    return min(zs) + (max(zs) - min(zs)) * NECK_FRAC


def split_head_body(ob):
    """Bisect at neck with filled caps — clean planar seam."""
    neck = neck_z_of(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.duplicate()
    head = bpy.context.active_object
    head.name = "HeadCut"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(
        plane_co=(0, 0, neck), plane_no=(0, 0, 1),
        clear_inner=True, clear_outer=False, use_fill=True,
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    body = ob
    body.name = "BodyCut"
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(
        plane_co=(0, 0, neck), plane_no=(0, 0, 1),
        clear_inner=False, clear_outer=True, use_fill=True,
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    log("split neck", round(neck, 3), "head", tris(head), "body", tris(body))
    return head, body


def refine_head(head):
    """NO voxel. Aggressive weld (hy is loose tris) + collapse. Face volumes."""
    for thr in (0.0015, 0.003, 0.005, 0.008):
        _weld(head, thr)
        log("head weld", thr, "tris", tris(head), "verts", len(head.data.vertices))
        if tris(head) < 50000 and len(head.data.vertices) < tris(head) * 0.7:
            break
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    t = tris(head)
    log("head start", t, "verts", len(head.data.vertices))
    guard = 0
    while tris(head) > HEAD_TARGET * 4 and guard < 6:
        before = tris(head)
        md = head.modifiers.new("Dh", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = 0.35
        md.use_collapse_triangulate = True
        apply_mod(head, md.name)
        log("head pre-collapse", before, "->", tris(head))
        guard += 1
        if tris(head) >= before * 0.95:
            break
    guard2 = 0
    while tris(head) > HEAD_TARGET and guard2 < 8:
        before = tris(head)
        md = head.modifiers.new("Dh2", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.08, min(0.55, HEAD_TARGET / float(before)))
        md.use_collapse_triangulate = True
        apply_mod(head, md.name)
        log("head target-collapse", before, "->", tris(head))
        guard2 += 1
        if tris(head) >= before * 0.98:
            break
    bpy.ops.object.shade_smooth()
    md = head.modifiers.new("Lap", "LAPLACIANSMOOTH")
    md.iterations = 2
    md.lambda_factor = 0.08
    md.use_volume_preserve = True
    apply_mod(head, md.name)
    _weld(head, 0.0008)
    bpy.ops.object.shade_smooth()
    zs = [v.co.z for v in head.data.vertices]
    zmin, zmax = min(zs), max(zs)
    cx = sum(v.co.x for v in head.data.vertices) / len(head.data.vertices)
    cy = sum(v.co.y for v in head.data.vertices) / len(head.data.vertices)
    cz = sum(v.co.z for v in head.data.vertices) / len(head.data.vertices)
    for v in head.data.vertices:
        w = (v.co.z - zmin) / max(1e-4, zmax - zmin)
        w = w * w * (3 - 2 * w)
        f = 1.0 + 0.16 * w
        v.co.x = cx + (v.co.x - cx) * f
        v.co.y = cy + (v.co.y - cy) * f
        v.co.z = cz + (v.co.z - cz) * f
    head.data.update()
    sculpt_face_head(head)
    # Fix shattered/inverted faces from weld+sculpt
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    try:
        bpy.ops.mesh.fill_holes(sides=8)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    paint_head(head)
    for v in head.data.vertices:
        v.co.z -= 0.025
    head.data.update()
    log("head final", tris(head), "verts", len(head.data.vertices))
    return head


def sculpt_face_head(ob):
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(0.05, zmax - zmin)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    nose_z = zmin + 0.44 * h
    brow_z = zmin + 0.58 * h
    cheek_z = zmin + 0.40 * h
    chin_z = zmin + 0.14 * h
    mouth_z = zmin + 0.26 * h
    for v in me.vertices:
        front_w = max(0.0, min(1.0, (cy + 0.03 - v.co.y) / 0.14))
        if front_w <= 0.04:
            continue
        dx = v.co.x - cx
        nd = math.sqrt(dx * dx + (v.co.z - nose_z) ** 2)
        nr = 0.07 * h / 0.35
        if nd < nr and front_w > 0.25:
            k = (1.0 - nd / nr) ** 2 * front_w
            v.co.y -= 0.038 * k
            v.co.z += 0.01 * k
        if abs(dx) < 0.11 and abs(v.co.z - brow_z) < 0.05 * h / 0.35 and front_w > 0.15:
            k = (1.0 - abs(v.co.z - brow_z) / (0.05 * h / 0.35)) * front_w
            v.co.y -= 0.018 * k
            v.co.z += 0.012 * k
        if 0.028 < abs(dx) < 0.12 and abs(v.co.z - cheek_z) < 0.06 * h / 0.35 and front_w > 0.15:
            k = (1.0 - abs(v.co.z - cheek_z) / (0.06 * h / 0.35)) * front_w
            v.co.x += math.copysign(0.016 * k, dx)
            v.co.y -= 0.012 * k
        if v.co.z < zmin + 0.30 * h and front_w > 0.12:
            k = front_w * (1.0 - (v.co.z - zmin) / (0.30 * h))
            if abs(dx) > 0.018:
                v.co.x += math.copysign(0.022 * k, dx)
            if abs(dx) < 0.055 and abs(v.co.z - chin_z) < 0.06 * h / 0.35:
                v.co.y -= 0.022 * k
        if abs(dx) < 0.045 and abs(v.co.z - mouth_z) < 0.025 * h / 0.35 and front_w > 0.35:
            k = (1.0 - abs(v.co.z - mouth_z) / (0.025 * h / 0.35)) * front_w
            v.co.y += 0.012 * k
        for sx in (-1, 1):
            ex, ez = cx + sx * 0.04, zmin + 0.50 * h
            ed = math.sqrt((v.co.x - ex) ** 2 + (v.co.z - ez) ** 2)
            er = 0.032 * h / 0.35
            if ed < er and front_w > 0.3:
                k = (1.0 - ed / er) ** 2 * front_w
                v.co.y += 0.010 * k
    me.update()


def paint_head(ob):
    me = ob.data
    while me.color_attributes:
        me.color_attributes.remove(me.color_attributes[0])
    attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(0.05, zmax - zmin)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    y_front = min(v.co.y for v in me.vertices)
    y_back = max(v.co.y for v in me.vertices)
    y_mid = y_front + 0.55 * (y_back - y_front)
    eye_r = 0.028 * h / 0.35
    eyes = [(cx - 0.042, zmin + 0.50 * h), (cx + 0.042, zmin + 0.50 * h)]
    for i, v in enumerate(me.vertices):
        slot = "skin"
        if v.co.y <= y_mid:
            for ex, ez in eyes:
                if (v.co.x - ex) ** 2 + (v.co.z - ez) ** 2 <= eye_r * eye_r:
                    slot = "eye"
                    break
        ao = 0.88 + 0.12 * ((v.co.z - zmin) / h)
        attr.data[i].color = (SLOT[slot] / 255.0, ao, 0.0, 1.0)
    me.update()
    bpy.ops.object.shade_smooth()


def refine_body(body, kind: str):
    """Body MAY voxel; bisect AFTER final decimate; FACE paint."""
    _weld(body, 0.002)
    t0 = tris(body)
    log("body start", t0)
    if t0 > 20000:
        for vs in (0.014, 0.018, 0.022, 0.028):
            md = body.modifiers.new("VR", "REMESH")
            md.mode = "VOXEL"
            md.voxel_size = vs
            apply_mod(body, md.name)
            log("body voxel", vs, tris(body))
            if 4000 <= tris(body) <= 16000:
                break
    if tris(body) > BODY_TARGET:
        md = body.modifiers.new("D", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.05, BODY_TARGET / float(tris(body)))
        apply_mod(body, md.name)
    bpy.ops.object.shade_smooth()
    md = body.modifiers.new("Lap", "LAPLACIANSMOOTH")
    md.iterations = 2
    md.lambda_factor = 0.10
    md.use_volume_preserve = True
    apply_mod(body, md.name)
    _weld(body, 0.001)
    if tris(body) > 3600:
        md = body.modifiers.new("Dcap", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = 3200 / float(tris(body))
        apply_mod(body, md.name)
        _weld(body, 0.001)
    zs = [v.co.z for v in body.data.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(1e-6, zmax - zmin)
    rings = (zmin + 0.12 * h, zmin + 0.42 * h, zmax - 0.045 * h, zmax - 0.012 * h)
    bpy.context.view_layer.objects.active = body
    for zc in rings:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.bisect(
            plane_co=(0, 0, zc), plane_no=(0, 0, 1),
            clear_inner=False, clear_outer=False, use_fill=False,
        )
        bpy.ops.object.mode_set(mode="OBJECT")
    paint_body(body, kind)
    log("body final", tris(body))
    return body


def _slot_at_body(z, ax, tz, z_boot, z_waist, z_collar_lo, z_collar_hi, cy, y, eps=1e-5):
    if z < z_boot - eps:
        return "boots"
    if z < z_waist - eps:
        return "trousers"
    if ax > 0.32 and 0.50 < tz < 0.72:
        return "skin"
    if z >= z_collar_hi - eps and y < cy + 0.02 and ax < 0.10:
        return "skin"
    if z >= z_collar_lo - eps:
        return "coat_dark"
    return "coat"


def _edge_split_rings(ob, ring_zs, tol=0.008):
    """Duplicate verts on ring planes so POINT colours don't interpolate across bands."""
    me = ob.data
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in me.vertices:
        v.select = any(abs(v.co.z - zc) < tol for zc in ring_zs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="VERT")
    try:
        bpy.ops.mesh.edge_split()
    except Exception as e:
        log("edge_split fail", e)
    bpy.ops.object.mode_set(mode="OBJECT")


def paint_body(ob, kind: str):
    """POINT slots after edge-split rings — Godot shader needs POINT colours."""
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(1e-6, zmax - zmin)
    z_boot = zmin + 0.12 * h
    z_waist = zmin + 0.42 * h
    z_collar_lo = zmax - 0.045 * h
    z_collar_hi = zmax - 0.012 * h
    _edge_split_rings(ob, (z_boot, z_waist, z_collar_lo, z_collar_hi))
    me = ob.data
    while me.color_attributes:
        me.color_attributes.remove(me.color_attributes[0])
    attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    counts = Counter()
    for i, v in enumerate(me.vertices):
        tz = (v.co.z - zmin) / h
        ax = abs(v.co.x - cx)
        slot = _slot_at_body(v.co.z, ax, tz, z_boot, z_waist, z_collar_lo, z_collar_hi, cy, v.co.y)
        ao = 0.78 + 0.22 * tz
        if slot in ("trousers", "boots"):
            ao *= 0.92
        if slot == "coat_dark":
            ao *= 0.85
        attr.data[i].color = (SLOT[slot] / 255.0, max(0.55, min(1.0, ao)), 0.0, 1.0)
        counts[slot] += 1
    me.update()
    bpy.ops.object.shade_smooth()
    log("body POINT", dict(counts))


def strip(ob):
    ob.data.materials.clear()
    while ob.data.uv_layers:
        ob.data.uv_layers.remove(ob.data.uv_layers[0])


def export_glb(ob, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    ob.name = path.stem
    if ob.data:
        ob.data.name = path.stem
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


def render_preview_pair(head, body, path: Path, hair_style: str = "crop"):
    path.parent.mkdir(parents=True, exist_ok=True)
    hair_src = ROOT / "project/assets/models/modules" / f"hair_{hair_style}.glb"
    hair = None
    if hair_src.is_file():
        before = {o.name for o in bpy.data.objects}
        bpy.ops.import_scene.gltf(filepath=str(hair_src))
        new = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
        if new:
            bpy.ops.object.select_all(action="DESELECT")
            for o in new:
                o.select_set(True)
            bpy.context.view_layer.objects.active = new[0]
            if len(new) > 1:
                bpy.ops.object.join()
            hair = bpy.context.active_object
            hz = [v.co.z for v in head.data.vertices]
            hx = [v.co.x for v in head.data.vertices]
            hy = [v.co.y for v in head.data.vertices]
            hzs = [v.co.z for v in hair.data.vertices]
            head_top = max(hz)
            head_bot = min(hz)
            head_h = max(0.05, head_top - head_bot)
            hair_span = max(hzs) - min(hzs)
            scale = (head_h * 0.70) / max(0.05, hair_span)
            hair.scale = (scale * 1.05, scale * 1.05, scale)
            bpy.ops.object.transform_apply(scale=True)
            hzs = [v.co.z for v in hair.data.vertices]
            target_bot = head_bot + 0.35 * head_h
            hair.location.z += target_bot - min(hzs)
            hxs = [v.co.x for v in hair.data.vertices]
            hys = [v.co.y for v in hair.data.vertices]
            hair.location.x += (sum(hx) / len(hx)) - (sum(hxs) / len(hxs))
            hair.location.y += (sum(hy) / len(hy)) - (sum(hys) / len(hys)) - 0.02
            bpy.ops.object.transform_apply(location=True)
            me = hair.data
            while me.color_attributes:
                me.color_attributes.remove(me.color_attributes[0])
            attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
            for i in range(len(me.vertices)):
                attr.data[i].color = (0.0, 0.9, 0.0, 1.0)
            me.update()

    parts = [o for o in (body, head, hair) if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    fig = bpy.context.active_object
    fig.name = "PreviewFig"

    mat = bpy.data.materials.new("prev")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out_n = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.12, 0.09, 0.08, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.5, 0.55, 0.6, 1)
    e = ramp.color_ramp.elements.new(1 / 255)
    e.color = (0.85, 0.68, 0.55, 1)
    e = ramp.color_ramp.elements.new(2 / 255)
    e.color = (0.05, 0.04, 0.06, 1)
    e = ramp.color_ramp.elements.new(3 / 255)
    e.color = (0.45, 0.48, 0.55, 1)
    e = ramp.color_ramp.elements.new(4 / 255)
    e.color = (0.28, 0.30, 0.38, 1)
    e = ramp.color_ramp.elements.new(12 / 255)
    e.color = (0.2, 0.24, 0.32, 1)
    e = ramp.color_ramp.elements.new(13 / 255)
    e.color = (0.12, 0.10, 0.10, 1)
    nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Red"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
    fig.data.materials.clear()
    fig.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (2.2, -2.8, 1.7)
    # Aim at mid-figure
    from mathutils import Vector as V
    direction = V((0.0, 0.0, 1.0)) - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    light_data = bpy.data.lights.new("L", "SUN")
    light_data.energy = 2.5
    light = bpy.data.objects.new("L", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(50), math.radians(15), math.radians(30))
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 28
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 512
    sc.render.resolution_y = 640
    sc.render.filepath = str(path)
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    log("preview", path.name)


def build_one(compose_name, head_sources, body_sources, kind, export_shared_head):
    head_src = find_src(head_sources)
    body_src = find_src(body_sources)
    if not head_src or not body_src:
        log("SKIP", compose_name, "head", head_src, "body", body_src)
        return
    log("===", compose_name, "head", head_src.name, "body", body_src.name)

    reset()
    hob = import_join(head_src)
    normalize_height(hob)
    _weld(hob, 0.002)
    head, discard_body = split_head_body(hob)
    if discard_body and discard_body != head:
        bpy.data.objects.remove(discard_body, do_unlink=True)
    refine_head(head)
    strip(head)
    head_path_tmp = OUT / f"_tmp_{compose_name}_head.glb"
    export_glb(head, head_path_tmp)

    if export_shared_head:
        export_glb(head, OUT / "head_m.glb")
        reset()
        bpy.ops.import_scene.gltf(filepath=str(OUT / "head_m.glb"))
        hf = [o for o in bpy.data.objects if o.type == "MESH"][0]
        for v in hf.data.vertices:
            v.co.x *= 0.94
        export_glb(hf, OUT / "head_f.glb")

    reset()
    bob = import_join(body_src)
    normalize_height(bob)
    _weld(bob, 0.002)
    discard_head, body = split_head_body(bob)
    if discard_head and discard_head != body:
        bpy.data.objects.remove(discard_head, do_unlink=True)
    refine_body(body, kind)
    strip(body)
    export_glb(body, OUT / f"{compose_name}.glb")

    reset()
    bpy.ops.import_scene.gltf(filepath=str(OUT / f"{compose_name}.glb"))
    body2 = [o for o in bpy.data.objects if o.type == "MESH"][0]
    hp = head_path_tmp if head_path_tmp.is_file() else (OUT / "head_m.glb")
    if not hp.is_file():
        log("preview without head")
        return
    bpy.ops.import_scene.gltf(filepath=str(hp))
    heads = [o for o in bpy.data.objects if o.type == "MESH" and o != body2]
    head2 = heads[-1]
    style = "swept" if "captain" in compose_name else ("messy" if kind == "ally" else "crop")
    render_preview_pair(head2, body2, PREVIEW / f"{compose_name}.png", style)
    if head_path_tmp.is_file() and head_path_tmp.name.startswith("_tmp_"):
        head_path_tmp.unlink(missing_ok=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for name, head_s, body_s, kind, exp_h in FIGURES:
        build_one(name, head_s, body_s, kind, export_shared_head=exp_h)
    log("DONE")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        log("FATAL", e)
        import traceback
        traceback.print_exc()
        raise SystemExit(1)
