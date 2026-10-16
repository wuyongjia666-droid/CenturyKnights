#!/usr/bin/env python3
"""Attach Hunyuan cloud bust HEAD (bisect neck cut) onto cast_leader body."""
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
    "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.prev_collar.glb",
)
if not BODY or not os.path.isfile(BODY):
    for cand in [
        "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.prev_collar.glb",
        "/workspace/CenturyKnights/project/assets/models/units/cast_leader.glb",
    ]:
        if os.path.isfile(cand):
            BODY = cand
            break
OUT = arg(
    "out",
    "/workspace/board_figure_p1_review/captain_v2/attached/cast_leader_hunyuan_head__board.glb",
)
HEAD_TRIS = int(arg("head-tris", "12000") or "12000")
RENDER_DIR = arg("render-dir", "/workspace/board_figure_p1_review/captain_v2/attached")
os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
if RENDER_DIR:
    os.makedirs(RENDER_DIR, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def world_coords(ob):
    mw = ob.matrix_world
    return [mw @ v.co for v in ob.data.vertices]


def apply_xf(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def decimate_to_tris(ob, target_tris: int, label: str = ""):
    n = max(1, len(ob.data.polygons))
    if n <= target_tris:
        print(f"DECIMATE {label or ob.name}: already {n} <= {target_tris}")
        return
    md = ob.modifiers.new("decimate_head", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = max(0.0005, target_tris / float(n))
    md.use_collapse_triangulate = True
    select_only(ob)
    bpy.ops.object.modifier_apply(modifier=md.name)
    print(f"DECIMATE {label or ob.name}: {n} -> {len(ob.data.polygons)} (target {target_tris})")


def delete_verts_world_z_ge(ob, z_cut: float):
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


def bisect_keep_above(ob, z_cut: float):
    """Bisect on global Z plane; clear geometry below the plane; fill cut."""
    select_only(ob)
    # Object should already have transforms applied so local≈world
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(
        plane_co=(0.0, 0.0, z_cut),
        plane_no=(0.0, 0.0, 1.0),
        clear_inner=True,  # remove below plane
        clear_outer=False,
        use_fill=True,
        threshold=0.0001,
    )
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.delete_loose()
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    print(f"BISECT keep z>={z_cut:.4f}: tris={len(ob.data.polygons)} verts={len(ob.data.vertices)}")


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


def setup_world():
    for o in list(bpy.data.objects):
        if o.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(o, do_unlink=True)

    def area(name, energy, loc, size=2.5):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.size = size
        ob = bpy.data.objects.new(name, light)
        ob.location = loc
        bpy.context.collection.objects.link(ob)

    area("Key", 160, (1.8, -2.4, 2.6))
    area("Fill", 50, (-2.2, -1.2, 1.9), 3.5)
    area("Rim", 80, (0.3, 2.8, 2.2), 2.0)
    world = bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.70, 0.72, 0.74, 1)
    bg.inputs[1].default_value = 0.9
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render_view(path, cam, eye, target, res=(960, 1200), lens=50):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
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
    print("OUT", OUT)
    reset()

    bpy.ops.import_scene.gltf(filepath=BODY)
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.lower().startswith("body"))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    weapon = next((o for o in bpy.data.objects if o.type == "MESH" and "weapon" in o.name.lower()), None)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.lower().startswith("ico"):
            bpy.data.objects.remove(o, do_unlink=True)

    neck_world = arm.matrix_world @ arm.pose.bones["neck"].head
    head_world = arm.matrix_world @ arm.pose.bones["head"].head
    print("neck", tuple(round(x, 4) for x in neck_world), "head", tuple(round(x, 4) for x in head_world))

    body_cut_z = float(neck_world.z + 0.055)
    delete_verts_world_z_ge(body, body_cut_z)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BUST)
    bust = next(o for o in bpy.data.objects if o not in before and o.type == "MESH")
    bust.name = "Head"
    apply_xf(bust)

    coords = world_coords(bust)
    zmin = min(c.z for c in coords)
    zmax = max(c.z for c in coords)
    # Neck narrowest ~0.61 on original; cut there (keeps head+hair only)
    if 0.7 < (zmax - zmin) < 1.0:
        z_cut_bust = zmin + 0.600
    else:
        z_cut_bust = zmin + 0.74 * (zmax - zmin)
    print(f"bust z[{zmin:.3f},{zmax:.3f}] neck_cut={z_cut_bust:.3f}")

    # Pre-decimate a bit for speed, but keep enough for clean bisect
    decimate_to_tris(bust, 250000, "pre")
    bisect_keep_above(bust, z_cut_bust)
    decimate_to_tris(bust, HEAD_TRIS, "final")
    select_only(bust)
    bpy.ops.object.shade_smooth()

    coords = world_coords(bust)
    hzmin = min(c.z for c in coords)
    hzmax = max(c.z for c in coords)
    hx = sum(c.x for c in coords) / len(coords)
    hy = sum(c.y for c in coords) / len(coords)
    head_h = hzmax - hzmin
    head_w = max(c.x for c in coords) - min(c.x for c in coords)
    print(f"raw head h={head_h:.3f} w={head_w:.3f} tris={len(bust.data.polygons)}")
    if head_h < 0.12 or head_w < 0.10:
        raise RuntimeError(f"Head cut looks wrong (h={head_h:.3f} w={head_w:.3f}); aborting")

    target_h = 0.26
    scale = target_h / head_h
    # If width after scale would be huge (>0.28), clamp
    if head_w * scale > 0.28:
        scale = 0.28 / head_w
        print(f"clamp scale by width -> {scale:.3f}")
    print(f"scale={scale:.3f}")

    for v in bust.data.vertices:
        v.co.x = (v.co.x - hx) * scale
        v.co.y = (v.co.y - hy) * scale
        v.co.z = (v.co.z - hzmin) * scale
    bust.data.update()
    bust.location = Vector((float(head_world.x), float(head_world.y), body_cut_z - 0.015))
    bust.rotation_euler = (0, 0, 0)
    apply_xf(bust)

    coords = world_coords(bust)
    cy = sum(c.y for c in coords) / len(coords)
    front = [c for c in coords if c.z > body_cut_z + 0.08]
    if front:
        y_pos = max(c.y for c in front) - cy
        y_neg = cy - min(c.y for c in front)
        print(f"face y+={y_pos:.3f} y-={y_neg:.3f}")
        if y_pos > y_neg * 1.08:
            bust.rotation_euler[2] = math.pi
            apply_xf(bust)
            print("ROTATED 180 so face -Y")

    ensure_head_vgroup(bust, arm, "head")

    body_tris = len(body.data.polygons)
    head_tris = len(bust.data.polygons)
    weap_tris = len(weapon.data.polygons) if weapon else 0
    coords = world_coords(bust)
    print(f"STATS body={body_tris} head={head_tris} weapon={weap_tris} total={body_tris+head_tris+weap_tris}")
    print(
        "HEAD z",
        round(min(c.z for c in coords), 3),
        round(max(c.z for c in coords), 3),
        "w",
        round(max(c.x for c in coords) - min(c.x for c in coords), 3),
    )

    bpy.ops.object.select_all(action="DESELECT")
    for o in (body, bust, arm):
        o.select_set(True)
    if weapon:
        weapon.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=True,
        export_yup=True,
        export_apply=False,
    )
    print("WROTE", OUT, os.path.getsize(OUT))

    if RENDER_DIR:
        dest = os.path.join(RENDER_DIR, "cast_leader_hunyuan_head__board.glb")
        if os.path.abspath(dest) != os.path.abspath(OUT):
            shutil.copy2(OUT, dest)
        # also export head-only for inspection
        head_only = os.path.join(RENDER_DIR, "captain_head_only.glb")
        bpy.ops.object.select_all(action="DESELECT")
        bust.select_set(True)
        bpy.context.view_layer.objects.active = bust
        bpy.ops.export_scene.gltf(
            filepath=head_only,
            export_format="GLB",
            use_selection=True,
            export_yup=True,
        )
        print("WROTE", head_only)

        cam = setup_world()
        target = Vector((0.0, float(head_world.y), 1.15))
        face_t = Vector((0.0, float(head_world.y) - 0.02, body_cut_z + 0.13))
        render_view(os.path.join(RENDER_DIR, "figure_front.png"), cam, Vector((0, -2.7, 1.25)), target)
        render_view(os.path.join(RENDER_DIR, "figure_35deg.png"), cam, Vector((1.55, -2.2, 1.3)), target)
        render_view(
            os.path.join(RENDER_DIR, "face_closeup.png"),
            cam,
            Vector((0.0, -0.55, face_t.z)),
            face_t,
            (900, 900),
            65,
        )
    print("DONE")


if __name__ == "__main__":
    main()
