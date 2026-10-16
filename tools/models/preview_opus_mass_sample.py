#!/usr/bin/env python3
"""Render Opus mass-path samples: generic body, shared grunt face, captain face on body_m.

No Hunyuan, no soft-collapse. Uses board_figures_v1 kit + compose_captain head slice.
Output: docs/art/review/board_figure_opus_mass/
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "project/assets/models/board/board_figures_v1.glb"
COMPOSE_CAPTAIN = ROOT / "tools/models/board_parts/compose_captain.glb"
OUT = ROOT / "docs/art/review/board_figure_opus_mass"
SLOT_PALETTE = {
    0: (0.22, 0.16, 0.12, 1),   # hair
    1: (0.82, 0.66, 0.54, 1),   # skin
    2: (0.10, 0.10, 0.12, 1),   # eye
    3: (0.48, 0.52, 0.58, 1),   # coat
    4: (0.18, 0.20, 0.26, 1),   # coat_dark
    5: (0.40, 0.36, 0.32, 1),   # apron
    12: (0.16, 0.18, 0.22, 1),  # trousers
    13: (0.10, 0.09, 0.09, 1),  # boots
}


def log(*a):
    print("[opus_mass]", *a, flush=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_gltf(path: Path):
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]


def find_mesh(name_prefix: str):
    for o in bpy.data.objects:
        if o.type == "MESH" and (o.name == name_prefix or o.name.startswith(name_prefix + ".")):
            return o
    return None


def slot_mat(name: str):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out_n = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    # Map slot index (stored in R as i/255) via color ramp
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = SLOT_PALETTE[0]
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.5, 0.5, 0.55, 1)
    for idx, col in SLOT_PALETTE.items():
        if idx == 0:
            continue
        e = ramp.color_ramp.elements.new(idx / 255.0)
        e.color = col
    nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Red"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
    return mat


def apply_mat(ob, mat):
    if ob.type != "MESH":
        return
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def setup_world(grey=(0.55, 0.57, 0.60)):
    world = bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*grey, 1)
    bg.inputs[1].default_value = 1.0


def add_sun(energy=2.6, rot=(50, 15, 30)):
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "SUN"))
    bpy.context.collection.objects.link(light)
    light.rotation_euler = tuple(math.radians(x) for x in rot)
    light.data.energy = energy
    return light


def look_at(cam, target, eye):
    cam.location = eye
    direction = Vector(target) - Vector(eye)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_png(path: Path, res=(720, 900), samples=36):
    path.parent.mkdir(parents=True, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = str(path)
    sc.render.image_settings.file_format = "PNG"
    sc.render.film_transparent = False
    bpy.ops.render.render(write_still=True)
    log("wrote", path.relative_to(ROOT), "bytes", path.stat().st_size)


def hide_all_except(keep):
    keep_set = set(keep)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in keep_set
            o.hide_viewport = o not in keep_set


def join_objects(objs, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_viewport = False
        o.hide_render = False
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


def slice_head_from_compose(compose_ob, chin_y=1.42):
    """Duplicate compose and delete verts below chin_y (world Z up after glTF)."""
    bpy.ops.object.select_all(action="DESELECT")
    compose_ob.select_set(True)
    bpy.context.view_layer.objects.active = compose_ob
    bpy.ops.object.duplicate()
    head = bpy.context.active_object
    head.name = "captain_head_slice"
    # Ensure object mode then edit
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh = head.data
    # glTF Y-up: height is +Y in Blender after import typically
    # Check axis by bbox
    bbox = [head.matrix_world @ Vector(c) for c in head.bound_box]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    # Prefer axis with larger extent near human height
    use_z = (max(zs) - min(zs)) > (max(ys) - min(ys))
    axis = 2 if use_z else 1
    # chin threshold: keep top ~head_h of figure
    mx = max(v[axis] for v in bbox)
    mn = min(v[axis] for v in bbox)
    # head is top ~18% of height
    cut = mn + (mx - mn) * 0.78
    log("slice axis", "Z" if use_z else "Y", "cut", round(cut, 3), "range", round(mn, 3), round(mx, 3))
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    to_del = []
    for v in bm.verts:
        w = head.matrix_world @ v.co
        if w[axis] < cut:
            to_del.append(v)
    bmesh.ops.delete(bm, geom=to_del, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    log("captain head tris", len(mesh.polygons))
    return head


def make_camera(eye, target):
    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    look_at(cam, target, eye)
    return cam


def scene_kit_parts(names):
    reset()
    import_gltf(KIT)
    mat = slot_mat("kit")
    found = []
    for n in names:
        ob = find_mesh(n)
        if ob is None:
            log("MISSING", n)
            continue
        apply_mat(ob, mat)
        found.append(ob)
    setup_world()
    add_sun()
    return found


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # 1) generic male body
    bodies = scene_kit_parts(["body_m"])
    if not bodies:
        raise SystemExit("body_m missing")
    make_camera(eye=(1.8, -2.4, 1.35), target=(0.0, 0.0, 0.95))
    hide_all_except(bodies)
    render_png(OUT / "01_generic_body_m.png")

    # 2) shared grunt face closeup (head_m)
    heads = scene_kit_parts(["head_m"])
    if not heads:
        raise SystemExit("head_m missing")
    make_camera(eye=(0.55, -0.85, 1.62), target=(0.0, 0.0, 1.55))
    hide_all_except(heads)
    render_png(OUT / "02_shared_grunt_face_head_m.png", res=(720, 720))

    # 3) shared grunt on generic body (mass path demo)
    parts = scene_kit_parts(["body_m", "head_m", "hair_messy", "outfit_bandit_weak"])
    if len(parts) < 3:
        raise SystemExit(f"grunt assemble incomplete: {[p.name for p in parts]}")
    joined = join_objects(parts, "grunt_on_body")
    apply_mat(joined, slot_mat("grunt"))
    setup_world()
    add_sun()
    make_camera(eye=(1.9, -2.5, 1.4), target=(0.0, 0.0, 0.95))
    hide_all_except([joined])
    render_png(OUT / "03_shared_grunt_on_generic_body.png")

    # 4) captain face on generic body: body_m + head slice from compose_captain + outfit_captain
    reset()
    kit_meshes = import_gltf(KIT)
    body = find_mesh("body_m")
    outfit = find_mesh("outfit_captain")
    hair = find_mesh("hair_swept") or find_mesh("hair_crop")
    compose_meshes = import_gltf(COMPOSE_CAPTAIN)
    compose = compose_meshes[0]
    for o in compose_meshes[1:]:
        bpy.data.objects.remove(o, do_unlink=True)
    head = slice_head_from_compose(compose)
    # hide full compose
    compose.hide_render = True
    compose.hide_viewport = True
    mat = slot_mat("captain")
    keep = [body, head]
    if outfit:
        keep.append(outfit)
    if hair:
        keep.append(hair)
    for o in keep:
        if o:
            apply_mat(o, mat)
    joined = join_objects([o for o in keep if o], "captain_face_on_body_m")
    apply_mat(joined, mat)
    setup_world()
    add_sun()
    make_camera(eye=(1.9, -2.5, 1.4), target=(0.0, 0.0, 0.95))
    hide_all_except([joined])
    render_png(OUT / "04_captain_face_on_generic_body.png")

    # 5) face closeup of that assemble
    make_camera(eye=(0.55, -0.9, 1.62), target=(0.0, 0.0, 1.55))
    render_png(OUT / "05_captain_face_closeup_on_body.png", res=(720, 720))

    # write README
    readme = OUT / "README.md"
    readme.write_text(
        """# Opus 量产样板（2026-10-16）

默认量产 = 通用身 + 共享/独特脸 + 职业壳（见 `docs/design/pawn-redesign-opus.md` §5，`captain-base-model-plan.md` §3）。
**未**跑混元云端；**未** soft COLLAPSE。

| 图 | 内容 |
|---|---|
| `01_generic_body_m.png` | 套件 `body_m`（通用男身） |
| `02_shared_grunt_face_head_m.png` | 共享脸 `head_m` 近景 |
| `03_shared_grunt_on_generic_body.png` | `body_m` + `head_m` + `hair_messy` + `outfit_bandit_weak` |
| `04_captain_face_on_generic_body.png` | `body_m` + 从 `compose_captain` 切下的头 + `outfit_captain` |
| `05_captain_face_closeup_on_body.png` | 上项脸近景 |

生成：`blender --background --python tools/models/preview_opus_mass_sample.py`
""",
        encoding="utf-8",
    )
    log("DONE", OUT)


if __name__ == "__main__":
    main()
