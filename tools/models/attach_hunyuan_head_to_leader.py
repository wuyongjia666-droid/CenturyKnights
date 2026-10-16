#!/usr/bin/env python3
"""High-quality Hunyuan head → cast_leader attach.

Preserves bust UVs/albedo for presentation LOD (~80–150k).
Board LOD (~25–40k): soft multi-step collapse FROM the ~120k LOD0 (keeps UVs/albedo).
Optional --board-remesh uses voxel remesh + bake (denser voxel); avoid collapsing 1.5M→12k.

blender --background --python tools/models/attach_hunyuan_head_to_leader.py -- \\
  [--bust PATH] [--body PATH] [--out PATH] [--out-lod0 PATH] [--render-dir DIR]
  [--lod0-tris N] [--board-tris N]
"""
from __future__ import annotations

import math
import os
import shutil
import sys

import bmesh
import bpy
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def arg(name: str, default: str | None = None) -> str | None:
    key = f"--{name}"
    if key in ARGV:
        i = ARGV.index(key)
        return ARGV[i + 1] if i + 1 < len(ARGV) else default
    for a in ARGV:
        if a.startswith(key + "="):
            return a.split("=", 1)[1]
    return default


BUST = arg(
    "bust",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_cloud/captain_v8_hero_leader_hunyuan_v31.glb",
)
BODY = arg(
    "body",
    "/workspace/board_figure_p1_review/captain_v2/attached/cast_leader__board.prev_collar.glb",
)
OUT = arg(
    "out",
    "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.glb",
)
OUT_LOD0 = arg(
    "out-lod0",
    "/workspace/board_figure_p1_review/captain_v2/attached_v2/cast_leader_hunyuan_head_lod0.glb",
)
RENDER_DIR = arg("render-dir", "/workspace/board_figure_p1_review/captain_v2/attached_v2")
LOD0_TRIS = int(arg("lod0-tris", "120000") or "120000")
BOARD_TRIS = int(arg("board-tris", "32000") or "32000")
TEX_BOARD = int(arg("tex-board", "2048") or "2048")  # keep 2k for face quality on board

os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
os.makedirs(RENDER_DIR, exist_ok=True)
if OUT_LOD0:
    os.makedirs(os.path.dirname(OUT_LOD0) or ".", exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def apply_xf(ob):
    select_only(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def world_coords(ob):
    mw = ob.matrix_world
    return [mw @ v.co for v in ob.data.vertices]


def mesh_stats(ob, label=""):
    coords = world_coords(ob)
    print(
        f"STATS {label or ob.name}: tris={len(ob.data.polygons)} verts={len(ob.data.vertices)} "
        f"z=[{min(c.z for c in coords):.3f},{max(c.z for c in coords):.3f}] "
        f"w={max(c.x for c in coords)-min(c.x for c in coords):.3f} "
        f"d={max(c.y for c in coords)-min(c.y for c in coords):.3f}"
    )


def soft_collapse(ob, target_tris: int, label: str = ""):
    n = max(1, len(ob.data.polygons))
    if n <= target_tris:
        print(f"COLLAPSE {label or ob.name}: already {n} <= {target_tris}")
        return
    ratio = max(0.01, target_tris / float(n))  # never go below 1% in one step
    # Multi-step if ratio is tiny (prevents cracky single jump)
    steps = 1
    r = ratio
    while r < 0.25 and steps < 4:
        steps += 1
        r = ratio ** (1.0 / steps)
    cur = n
    for i in range(steps):
        cur_n = len(ob.data.polygons)
        if cur_n <= target_tris:
            break
        # last step aims exactly; intermediate geometric
        if i == steps - 1:
            step_ratio = max(0.05, target_tris / float(cur_n))
        else:
            step_ratio = max(0.25, (target_tris / float(cur_n)) ** (1.0 / (steps - i)))
        md = ob.modifiers.new(f"dec_{label}_{i}", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = min(0.95, step_ratio)
        md.use_collapse_triangulate = False  # preserve UV better
        select_only(ob)
        bpy.ops.object.modifier_apply(modifier=md.name)
        print(f"COLLAPSE {label} step{i}: {cur_n} -> {len(ob.data.polygons)} (ratio={md.ratio:.3f})")
    # final nudge
    cur_n = len(ob.data.polygons)
    if cur_n > target_tris * 1.08:
        md = ob.modifiers.new(f"dec_{label}_final", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = target_tris / float(cur_n)
        md.use_collapse_triangulate = False
        select_only(ob)
        bpy.ops.object.modifier_apply(modifier=md.name)
        print(f"COLLAPSE {label} final: {cur_n} -> {len(ob.data.polygons)}")


def bisect_keep_above(ob, z_cut: float):
    select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(
        plane_co=(0.0, 0.0, z_cut),
        plane_no=(0.0, 0.0, 1.0),
        clear_inner=True,
        clear_outer=False,
        use_fill=True,
        threshold=0.0001,
    )
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.delete_loose()
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    print(f"BISECT keep z>={z_cut:.4f}: tris={len(ob.data.polygons)}")


def delete_body_head(ob, z_cut: float):
    mw = ob.matrix_world
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    kill = [v for v in bm.verts if (mw @ v.co).z >= z_cut]
    print(f"BODY kill z>={z_cut:.4f}: {len(kill)}/{len(bm.verts)}")
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def ensure_uv(ob):
    if not ob.data.uv_layers:
        select_only(ob)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        print("UV smart_project created")


def duplicate_object(ob, name: str):
    dup = ob.copy()
    dup.data = ob.data.copy()
    dup.name = name
    bpy.context.collection.objects.link(dup)
    return dup


def voxel_remesh_to_tris(ob, target_tris: int):
    """Voxel remesh then mild collapse to hit budget. Destroys UV — bake after."""
    # Estimate voxel size from bbox and target
    coords = world_coords(ob)
    sx = max(c.x for c in coords) - min(c.x for c in coords)
    sy = max(c.y for c in coords) - min(c.y for c in coords)
    sz = max(c.z for c in coords) - min(c.z for c in coords)
    # surface area approx
    area = 2 * (sx * sy + sy * sz + sz * sx)
    # tris ≈ area / (voxel^2) * k ; tune voxel
    voxel = math.sqrt(max(area, 1e-6) / max(target_tris * 0.55, 1.0))
    voxel = max(0.0025, min(0.012, voxel))
    print(f"REMESH voxel={voxel:.5f} target_tris={target_tris} bbox=({sx:.3f},{sy:.3f},{sz:.3f})")
    md = ob.modifiers.new("voxel", "REMESH")
    md.mode = "VOXEL"
    md.voxel_size = voxel
    md.adaptivity = 0.0
    select_only(ob)
    bpy.ops.object.modifier_apply(modifier=md.name)
    print(f"REMESH after voxel: {len(ob.data.polygons)} tris")
    # smooth a bit
    md = ob.modifiers.new("smooth", "SMOOTH")
    md.factor = 0.5
    md.iterations = 4
    bpy.ops.object.modifier_apply(modifier=md.name)
    # collapse gently if still over budget
    if len(ob.data.polygons) > target_tris * 1.15:
        soft_collapse(ob, target_tris, "board_after_voxel")
    elif len(ob.data.polygons) < target_tris * 0.6:
        # too coarse — leave; can't easily densify without redoing
        print("WARN remesh under target; leave denser next time")
    ensure_uv(ob)
    select_only(ob)
    bpy.ops.object.shade_smooth()


def find_principled(mat):
    if not mat or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return n
    return None


def find_image_from_input(sock):
    if sock is None or not sock.links:
        return None
    n = sock.links[0].from_node
    if n.type == "TEX_IMAGE":
        return n.image
    if n.type == "NORMAL_MAP" and n.inputs.get("Color") and n.inputs["Color"].links:
        nn = n.inputs["Color"].links[0].from_node
        if nn.type == "TEX_IMAGE":
            return nn.image
    return None


def bake_maps(high: bpy.types.Object, low: bpy.types.Object, size: int, out_dir: str):
    """Bake Diffuse color + Normal from high → low. Returns (albedo_img, normal_img)."""
    ensure_uv(low)
    # Create images + assign to low material
    alb = bpy.data.images.new("HeadAlbedoBake", width=size, height=size, alpha=False)
    nrm = bpy.data.images.new("HeadNormalBake", width=size, height=size, alpha=False)

    mat = bpy.data.materials.new("HeadBoardBaked")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex_a = nt.nodes.new("ShaderNodeTexImage")
    tex_a.image = alb
    tex_a.name = "BakeAlbedo"
    tex_n = nt.nodes.new("ShaderNodeTexImage")
    tex_n.image = nrm
    tex_n.name = "BakeNormal"
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex_a.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    # clear mats on low, assign
    low.data.materials.clear()
    low.data.materials.append(mat)

    # Scene bake settings
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.margin = 8
    scene.render.bake.cage_extrusion = 0.05
    scene.render.bake.max_ray_distance = 0.08

    def do_bake(img, bake_type, pass_filter=None):
        # select bake image node
        for n in nt.nodes:
            n.select = False
        node = nt.nodes["BakeAlbedo" if bake_type == "DIFFUSE" else "BakeNormal"]
        node.select = True
        nt.nodes.active = node
        bpy.ops.object.select_all(action="DESELECT")
        high.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        if bake_type == "DIFFUSE":
            bpy.ops.object.bake(
                type="DIFFUSE",
                pass_filter={"COLOR"},
                use_selected_to_active=True,
                cage_extrusion=0.05,
                margin=8,
            )
        else:
            bpy.ops.object.bake(
                type="NORMAL",
                normal_space="TANGENT",
                use_selected_to_active=True,
                cage_extrusion=0.05,
                margin=8,
            )
        path = os.path.join(out_dir, f"head_board_{bake_type.lower()}.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        print("BAKED", path)

    do_bake(alb, "DIFFUSE")
    do_bake(nrm, "NORMAL")
    return alb, nrm


def ensure_head_vgroup(ob, arm, bone_name="head"):
    if bone_name not in arm.data.bones:
        bone_name = list(arm.data.bones)[0].name
    while ob.vertex_groups:
        ob.vertex_groups.remove(ob.vertex_groups[0])
    vg = ob.vertex_groups.new(name=bone_name)
    idxs = list(range(len(ob.data.vertices)))
    if idxs:
        vg.add(idxs, 1.0, "REPLACE")
    for m in list(ob.modifiers):
        if m.type == "ARMATURE":
            ob.modifiers.remove(m)
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    ob.parent = arm


def place_head(ob, head_world, body_cut_z, target_h=0.25, max_w=0.22):
    coords = world_coords(ob)
    hzmin = min(c.z for c in coords)
    hzmax = max(c.z for c in coords)
    hx = sum(c.x for c in coords) / len(coords)
    hy = sum(c.y for c in coords) / len(coords)
    head_h = hzmax - hzmin
    head_w = max(c.x for c in coords) - min(c.x for c in coords)
    scale = target_h / max(head_h, 1e-6)
    if head_w * scale > max_w:
        scale = max_w / head_w
        print(f"scale clamped by width -> {scale:.3f}")
    print(f"place_head raw_h={head_h:.3f} raw_w={head_w:.3f} scale={scale:.3f}")
    for v in ob.data.vertices:
        v.co.x = (v.co.x - hx) * scale
        v.co.y = (v.co.y - hy) * scale
        v.co.z = (v.co.z - hzmin) * scale
    ob.data.update()
    # seat: neck stub slightly into body collar
    ob.location = Vector((float(head_world.x), float(head_world.y), body_cut_z - 0.025))
    ob.rotation_euler = (0, 0, 0)
    apply_xf(ob)
    # face toward -Y
    coords = world_coords(ob)
    cy = sum(c.y for c in coords) / len(coords)
    band = [c for c in coords if c.z > body_cut_z + 0.08]
    if band:
        y_pos = max(c.y for c in band) - cy
        y_neg = cy - min(c.y for c in band)
        print(f"face y+={y_pos:.3f} y-={y_neg:.3f}")
        if y_pos > y_neg * 1.05:
            ob.rotation_euler[2] = math.pi
            apply_xf(ob)
            print("ROTATED 180 → face -Y")


def export_selection(path, objects, arm):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        if o:
            o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=True,
        export_yup=True,
        export_apply=False,
        export_image_format="AUTO",
    )
    print("WROTE", path, os.path.getsize(path))


def setup_world():
    for o in list(bpy.data.objects):
        if o.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(o, do_unlink=True)

    def area(name, energy, loc, size=2.0):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.size = size
        ob = bpy.data.objects.new(name, light)
        ob.location = loc
        bpy.context.collection.objects.link(ob)

    area("Key", 140, (1.6, -2.2, 2.4), 2.0)
    area("Fill", 45, (-2.0, -1.0, 1.8), 3.0)
    area("Rim", 70, (0.2, 2.5, 2.0), 2.0)
    world = bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.70, 0.72, 0.74, 1)
    bg.inputs[1].default_value = 0.85
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render_view(path, cam, eye, target, res=(960, 1200), lens=50, samples=48):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    cam.location = eye
    cam.data.lens = lens
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print("RENDER", path)


def main():
    print("BUST", BUST)
    print("BODY", BODY)
    print("OUT", OUT, "LOD0", OUT_LOD0)
    print("LOD0_TRIS", LOD0_TRIS, "BOARD_TRIS", BOARD_TRIS)
    reset()

    # --- body ---
    bpy.ops.import_scene.gltf(filepath=BODY)
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.lower().startswith("body"))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    weapon = next((o for o in bpy.data.objects if o.type == "MESH" and "weapon" in o.name.lower()), None)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.lower().startswith("ico"):
            bpy.data.objects.remove(o, do_unlink=True)

    neck_world = arm.matrix_world @ arm.pose.bones["neck"].head
    head_world = arm.matrix_world @ arm.pose.bones["head"].head
    body_cut_z = float(neck_world.z + 0.05)
    print("neck", tuple(round(x, 4) for x in neck_world), "cut", body_cut_z)
    delete_body_head(body, body_cut_z)

    # --- bust / head high ---
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BUST)
    bust = next(o for o in bpy.data.objects if o not in before and o.type == "MESH")
    bust.name = "HeadHighSrc"
    apply_xf(bust)
    mesh_stats(bust, "bust_full")

    coords = world_coords(bust)
    zmin = min(c.z for c in coords)
    zmax = max(c.z for c in coords)
    # neck ~0.60 on original 0.8m bust
    z_cut = zmin + 0.600 if 0.7 < (zmax - zmin) < 1.0 else zmin + 0.74 * (zmax - zmin)
    print(f"neck_cut={z_cut:.4f}")

    # Soft pre-decimate whole bust so head lands ~LOD0 budget after cut
    # Head ≈ 12% of tris → pre target ≈ LOD0_TRIS / 0.12
    pre_target = min(len(bust.data.polygons), max(int(LOD0_TRIS / 0.11), LOD0_TRIS * 6))
    soft_collapse(bust, pre_target, "pre_bust")
    bisect_keep_above(bust, z_cut)
    mesh_stats(bust, "head_after_cut")

    # Presentation LOD: gentle collapse to LOD0_TRIS, KEEP UVs + original materials
    soft_collapse(bust, LOD0_TRIS, "lod0")
    select_only(bust)
    bpy.ops.object.shade_smooth()
    bust.name = "HeadLOD0"
    mesh_stats(bust, "lod0")

    # Place LOD0 (shared placement for both)
    place_head(bust, head_world, body_cut_z, target_h=0.25, max_w=0.215)

    # Duplicate for board remesh BEFORE we might alter materials on board copy
    head_board = duplicate_object(bust, "HeadBoard")
    # Hide LOD0 from board export path; keep for lod0 export + bake source
    # Remesh board copy
    voxel_remesh_to_tris(head_board, BOARD_TRIS)
    mesh_stats(head_board, "board_remeshed")

    # Bake from LOD0 (textured) → board
    try:
        bake_maps(bust, head_board, TEX_BOARD, RENDER_DIR)
    except Exception as e:
        print("BAKE FAILED:", e)
        # fallback: copy materials from high (won't match remesh UV — still try keep color)
        if bust.data.materials:
            head_board.data.materials.clear()
            for m in bust.data.materials:
                head_board.data.materials.append(m)

    # Weight both heads
    ensure_head_vgroup(bust, arm, "head")
    ensure_head_vgroup(head_board, arm, "head")

    # Export LOD0 figure (body + lod0 head + weapon)
    if OUT_LOD0:
        # temporarily hide board head
        head_board.hide_set(True)
        export_selection(OUT_LOD0, [body, bust, weapon], arm)
        head_board.hide_set(False)
        # also head-only high
        head_only = os.path.join(RENDER_DIR, "captain_head_lod0_only.glb")
        bpy.ops.object.select_all(action="DESELECT")
        bust.select_set(True)
        bpy.context.view_layer.objects.active = bust
        bpy.ops.export_scene.gltf(filepath=head_only, export_format="GLB", use_selection=True, export_yup=True)
        print("WROTE", head_only)

    # Export board figure (body + board head + weapon) — hide LOD0 head
    bust.hide_set(True)
    export_selection(OUT, [body, head_board, weapon], arm)
    review_board = os.path.join(RENDER_DIR, "cast_leader_hunyuan_head__board.glb")
    if os.path.abspath(review_board) != os.path.abspath(OUT):
        shutil.copy2(OUT, review_board)

    # Resize oversize images on board export already baked at TEX_BOARD
    # Renders: unhide appropriate head
    bust.hide_set(True)
    head_board.hide_set(False)
    cam = setup_world()
    target = Vector((0.0, float(head_world.y), 1.15))
    # face target
    hc = world_coords(head_board)
    face_z = min(c.z for c in hc) + 0.45 * (max(c.z for c in hc) - min(c.z for c in hc))
    front_y = min(c.y for c in hc)
    face_t = Vector((0.0, front_y + 0.05, face_z))

    render_view(os.path.join(RENDER_DIR, "figure_front.png"), cam, Vector((0, -2.7, 1.25)), target, samples=40)
    render_view(os.path.join(RENDER_DIR, "figure_35deg.png"), cam, Vector((1.55, -2.2, 1.3)), target, samples=40)
    # closeups — horizontal
    import math as _m
    from mathutils import Euler
    cam.rotation_euler = Euler((_m.radians(90), 0, 0), "XYZ")
    cam.location = Vector((0.0, front_y - 0.50, face_z))
    cam.data.lens = 90
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.cycles.samples = 64
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup_board.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup_board")

    # Also render LOD0 face closeup for quality proof
    head_board.hide_set(True)
    bust.hide_set(False)
    hc = world_coords(bust)
    face_z = min(c.z for c in hc) + 0.45 * (max(c.z for c in hc) - min(c.z for c in hc))
    front_y = min(c.y for c in hc)
    cam.location = Vector((0.0, front_y - 0.50, face_z))
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup_lod0.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup_lod0")

    # 35° lod0
    cam.location = Vector((0.32, front_y - 0.42, face_z + 0.01))
    target2 = Vector((0.0, front_y + 0.04, face_z))
    cam.rotation_euler = (target2 - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup_lod0_35.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup_lod0_35")

    print("DONE")
    print("LOD0_TRIS_FINAL", len(bust.data.polygons), "BOARD_TRIS_FINAL", len(head_board.data.polygons))


if __name__ == "__main__":
    main()
