#!/usr/bin/env python3
"""Render Opus mass-path samples (no Hunyuan, no soft-collapse, no head-attach weld).

Recipe: generic body + kit cranial head (generator planes) + job shell.
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


def render_png(path: Path, res=(720, 900), samples=48):
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


def bbox_center_top(ob):
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    xs = [v.x for v in bb]
    ys = [v.y for v in bb]
    zs = [v.z for v in bb]
    # glTF often Y-up in Blender after import
    if (max(zs) - min(zs)) >= (max(ys) - min(ys)):
        return (0.5 * (min(xs) + max(xs)), 0.5 * (min(ys) + max(ys)), 0.5 * (min(zs) + max(zs))), max(zs)
    return (0.5 * (min(xs) + max(xs)), 0.5 * (min(ys) + max(ys)), 0.5 * (min(zs) + max(zs))), max(ys)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if not KIT.is_file():
        raise SystemExit(f"missing kit {KIT}")

    # 1) generic male body
    bodies = scene_kit_parts(["body_m"])
    if not bodies:
        raise SystemExit("body_m missing")
    make_camera(eye=(1.8, -2.4, 1.35), target=(0.0, 0.0, 0.95))
    hide_all_except(bodies)
    render_png(OUT / "01_generic_body_m.png")

    # 2) shared grunt face — generator cranial head_m (planes), NOT organic override
    heads = scene_kit_parts(["head_m"])
    if not heads:
        raise SystemExit("head_m missing")
    ctr, top = bbox_center_top(heads[0])
    make_camera(eye=(ctr[0] + 0.55, ctr[1] - 0.85, top - 0.05), target=(ctr[0], ctr[1], top - 0.08))
    hide_all_except(heads)
    render_png(OUT / "02_shared_grunt_face_head_m.png", res=(720, 720))

    # 3) mass path: body + shared head + hair + bandit shell + club
    parts = scene_kit_parts(
        ["body_m", "head_m", "hair_messy", "outfit_bandit_weak", "weapon_club"]
    )
    if len(parts) < 4:
        raise SystemExit(f"grunt assemble incomplete: {[p.name for p in parts]}")
    joined = join_objects(parts, "grunt_mass")
    apply_mat(joined, slot_mat("grunt"))
    setup_world()
    add_sun()
    make_camera(eye=(1.9, -2.5, 1.4), target=(0.0, 0.0, 0.95))
    hide_all_except([joined])
    render_png(OUT / "03_shared_grunt_on_generic_body.png")

    # 3b) same assemble closer on head (shared face readability)
    make_camera(eye=(0.7, -1.1, 1.55), target=(0.0, 0.05, 1.48))
    render_png(OUT / "03b_kit_assemble_grunt.png", res=(720, 900))

    # 4) captain shell path (kit): body + shared/unique-slot head + outfit_captain + hair + sword
    #    No compose head-slice weld. Unique captain face later = replace head_m part.
    parts = scene_kit_parts(
        ["body_m", "head_m", "hair_swept", "outfit_captain", "weapon_sword"]
    )
    if len(parts) < 4:
        raise SystemExit(f"captain kit assemble incomplete: {[p.name for p in parts]}")
    joined = join_objects(parts, "captain_kit_mass")
    apply_mat(joined, slot_mat("captain"))
    setup_world()
    add_sun()
    make_camera(eye=(1.9, -2.5, 1.4), target=(0.0, 0.0, 0.95))
    hide_all_except([joined])
    render_png(OUT / "04_captain_kit_on_generic_body.png")

    # 5) captain kit head closeup
    make_camera(eye=(0.55, -0.9, 1.62), target=(0.0, 0.0, 1.55))
    render_png(OUT / "05_captain_kit_face_closeup.png", res=(720, 720))

    # 6) optional: compose_bandit_weak whole-mesh LOOK (t1 organic, not mass weld)
    comps = scene_kit_parts(["compose_bandit_weak"])
    if comps:
        make_camera(eye=(1.9, -2.5, 1.4), target=(0.0, 0.0, 0.95))
        hide_all_except(comps)
        render_png(OUT / "06_compose_bandit_weak_look.png")

    readme = OUT / "README.md"
    readme.write_text(
        """# Opus 量产样板（2026-10-16 夜）

配方见 `docs/design/board-figure-mass-recipe.md`。

- **未**跑混元云端；**未** soft COLLAPSE；**未**接头焊身。
- `head_m` = 生成器颅面（`planes`），有机塌脸覆盖已迁入 `board_parts/_qa_fail/`。

| 图 | 内容 | 目视 QA |
|---|---|---|
| `01_generic_body_m.png` | 套件 `body_m` | 通用男身（无头） |
| `02_shared_grunt_face_head_m.png` | 生成器 `head_m` 近景 | 共享脸颅面 |
| `03_shared_grunt_on_generic_body.png` | body+head+hair+山贼壳+club | 量产组装 |
| `03b_kit_assemble_grunt.png` | 同上头近景 | 共享脸可读性 |
| `04_captain_kit_on_generic_body.png` | body+head+hair+captain壳+sword | 团长量产壳（头仍共享颅面；独特脸=整件换 head） |
| `05_captain_kit_face_closeup.png` | 上项头近景 | 同共享颅面 |
| `06_compose_bandit_weak_look.png` | t1 有机 compose LOOK | 对照用，非焊身 |

Godot 过目卡（已有）：`docs/art/review/board_figure_p1/cards/`。

生成：`blender --background --python tools/models/preview_opus_mass_sample.py`
""",
        encoding="utf-8",
    )
    log("DONE", OUT)


if __name__ == "__main__":
    main()
