#!/usr/bin/env python3
"""Polish cast_leader__board after Hunyuan head attach — neck / cold-grey coat / thick sword.

Does NOT touch head topology, UVs, or Hunyuan albedo/normal textures.

blender --background --python tools/models/polish_captain_board.py -- \\
  [--src PATH] [--out PATH] [--render-dir DIR]
  [--head-scale F] [--head-seat F]
  [--coat-grey R,G,B] [--frost-hi F]
  [--sword-thick-y F] [--sword-thick-x F]
"""
from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

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


SRC = arg("src", "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.glb")
OUT = arg("out", SRC)
RENDER_DIR = arg("render-dir", "/workspace/board_figure_p1_review/captain_v2/attached_v3")
HEAD_SCALE = float(arg("head-scale", "1.08") or "1.08")
HEAD_SEAT = float(arg("head-seat", "0.028") or "0.028")  # lower into collar
# Portrait cold grey (~lapel/coat): aim mid readable cold grey for board
COAT = arg("coat-grey", "88,92,104")  # cool grey RGB 0-255
FROST_HI = float(arg("frost-hi", "155") or "155")  # luminance above this remaps toward coat
SWORD_Y = float(arg("sword-thick-y", "3.2") or "3.2")  # blade thin axis
SWORD_X = float(arg("sword-thick-x", "1.45") or "1.45")
COLLAR_LIFT = float(arg("collar-lift", "0.018") or "0.018")

os.makedirs(RENDER_DIR, exist_ok=True)
coat_rgb = tuple(int(x) / 255.0 for x in COAT.split(","))


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


def recolor_body_albedo(body, target_rgb, frost_hi_lum: float):
    """Remap frost-white coat pixels on body albedo toward cold grey; keep darks/skinish."""
    mat = body.data.materials[0] if body.data.materials else None
    if not mat or not mat.use_nodes:
        print("WARN no body material")
        return
    img = None
    tex_node = None
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            img = n.image
            tex_node = n
            break
    if img is None:
        print("WARN no body albedo image — tint Principled only")
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*target_rgb, 1.0)
        return

    # Ensure pixels loaded
    if not img.pixels:
        print("WARN empty pixels")
        return
    w, h = img.size[0], img.size[1]
    px = list(img.pixels)  # RGBA flat
    tr, tg, tb = target_rgb
    changed = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        # skip near-black (boots/gaps) and strong cyan/mint trim (keep accent)
        if lum < 0.08:
            continue
        # mint/frost trim: high B relative — gently cool but don't kill
        is_bright_coat = lum >= (frost_hi_lum / 255.0)
        is_mid_coat = 0.35 <= lum < (frost_hi_lum / 255.0) and abs(r - g) < 0.08 and abs(g - b) < 0.12
        if not (is_bright_coat or is_mid_coat):
            continue
        # stronger remap for brighter frost
        t = 0.0
        if is_bright_coat:
            t = min(1.0, (lum - frost_hi_lum / 255.0) / 0.35 + 0.55)
            t = max(0.55, min(0.92, t))
        else:
            t = 0.35
        # preserve a bit of local variation
        nr = r * (1 - t) + tr * t
        ng = g * (1 - t) + tg * t
        nb = b * (1 - t) + tb * t
        # keep slight cool bias
        nb = min(1.0, nb + 0.02)
        px[i], px[i + 1], px[i + 2] = nr, ng, nb
        changed += 1
    img.pixels = px
    img.update()
    # save sibling for Godot
    out_tex = os.path.join(
        os.path.dirname(OUT) if OUT.endswith(".glb") else RENDER_DIR,
        "cast_leader__board__albedo_coldgrey.png",
    )
    # Prefer next to glb in units/
    units = "/workspace/CenturyKnights/project/assets/models/units"
    out_tex = os.path.join(units, "cast_leader__board__albedo_coldgrey.png")
    img.filepath_raw = out_tex
    img.file_format = "PNG"
    img.save()
    print(f"COAT recolored pixels={changed} -> {out_tex}")
    # also set base color multiply slightly cool
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.92, 0.94, 1.0, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.72
        bsdf.inputs["Metallic"].default_value = 0.0


def lift_collar(body, z_min: float, z_max: float, lift: float):
    """Raise upper collar verts a bit to wrap the neck stub."""
    mw = body.matrix_world
    inv = mw.inverted()
    moved = 0
    for v in body.data.vertices:
        w = mw @ v.co
        if z_min <= w.z <= z_max:
            # more lift at top of band
            t = (w.z - z_min) / max(1e-6, z_max - z_min)
            # only outer-ish collar (away from spine center a bit) — all verts in band ok
            w.z += lift * (0.35 + 0.65 * t)
            v.co = inv @ w
            moved += 1
    body.data.update()
    print(f"COLLAR lift moved={moved} lift={lift}")


def seat_and_scale_head(head, scale: float, seat: float):
    """Uniform scale about head center XY / bottom Z, then lower into collar. No mesh edit."""
    coords = world_coords(head)
    cx = sum(c.x for c in coords) / len(coords)
    cy = sum(c.y for c in coords) / len(coords)
    zmin = min(c.z for c in coords)
    # scale in local after moving pivot
    select_only(head)
    # apply current transforms first
    apply_xf(head)
    coords = world_coords(head)
    cx = sum(c.x for c in coords) / len(coords)
    cy = sum(c.y for c in coords) / len(coords)
    zmin = min(c.z for c in coords)
    for v in head.data.vertices:
        # head data is already world-applied
        v.co.x = cx + (v.co.x - cx) * scale
        v.co.y = cy + (v.co.y - cy) * scale
        v.co.z = zmin + (v.co.z - zmin) * scale
    head.data.update()
    # seat down
    for v in head.data.vertices:
        v.co.z -= seat
    head.data.update()
    print(f"HEAD scale={scale} seat={seat} z=[{min(v.co.z for v in head.data.vertices):.3f},"
          f"{max(v.co.z for v in head.data.vertices):.3f}]")


def thicken_sword(weapon, thick_y: float, thick_x: float):
    """Scale blade cross-section about local center; keep length (Z) and hands clear."""
    coords = [v.co.copy() for v in weapon.data.vertices]
    cx = sum(c.x for c in coords) / len(coords)
    cy = sum(c.y for c in coords) / len(coords)
    # Y is the thin axis on this asset
    for v in weapon.data.vertices:
        v.co.y = cy + (v.co.y - cy) * thick_y
        v.co.x = cx + (v.co.x - cx) * thick_x
    weapon.data.update()
    print(f"SWORD thick_y={thick_y} thick_x={thick_x} dim={list(weapon.dimensions)}")


def drop_ico():
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.lower().startswith("ico"):
            bpy.data.objects.remove(o, do_unlink=True)


def export_glb(path, body, head, weapon, arm, plug=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (body, head, arm):
        o.select_set(True)
    if weapon:
        weapon.select_set(True)
    if plug:
        plug.select_set(True)
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

    area("Key", 150, (1.6, -2.2, 2.4), 2.0)
    area("Fill", 48, (-2.0, -1.0, 1.8), 3.0)
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
    print("SRC", SRC)
    print("OUT", OUT)
    print("COAT", coat_rgb, "HEAD", HEAD_SCALE, HEAD_SEAT, "SWORD", SWORD_Y, SWORD_X)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    drop_ico()

    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.lower().startswith("body"))
    head = next(
        o
        for o in bpy.data.objects
        if o.type == "MESH" and ("head" in o.name.lower() or o.name.startswith("Head"))
    )
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    weapon = next((o for o in bpy.data.objects if o.type == "MESH" and "weapon" in o.name.lower()), None)
    print("HEAD tris (untouched topology)", len(head.data.polygons))

    # 1) coat
    recolor_body_albedo(body, coat_rgb, FROST_HI)

    # 2) collar lift then seat head
    lift_collar(body, z_min=1.38, z_max=1.50, lift=COLLAR_LIFT)
    seat_and_scale_head(head, scale=HEAD_SCALE, seat=HEAD_SEAT)

    # 2b) dark neck plug (hides hollow after optional cap delete; sits in collar)
    import bmesh
    # delete downward neck-cap faces if any remain
    mw = head.matrix_world
    bm = bmesh.new(); bm.from_mesh(head.data); bm.normal_update()
    coords = [mw @ v.co for v in head.data.vertices]
    zmin = min(c.z for c in coords)
    kill = []
    for f in bm.faces:
        n = (mw.to_3x3() @ f.normal).normalized()
        cz = sum((mw @ v.co).z for v in f.verts) / 3.0
        if n.z < -0.35 and cz < zmin + 0.04:
            kill.append(f)
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(head.data); print(f"NECK cap faces removed {len(kill)}")
    bm.free(); head.data.update()
    cx = sum((head.matrix_world @ v.co).x for v in head.data.vertices) / len(head.data.vertices)
    cy = sum((head.matrix_world @ v.co).y for v in head.data.vertices) / len(head.data.vertices)
    zmin = min((head.matrix_world @ v.co).z for v in head.data.vertices)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.042, depth=0.055, location=(cx, cy, zmin + 0.005))
    plug = bpy.context.active_object
    plug.name = "NeckPlug"
    pm = bpy.data.materials.new("NeckPlugMat"); pm.use_nodes = True
    pbsdf = pm.node_tree.nodes["Principled BSDF"]
    pbsdf.inputs["Base Color"].default_value = (0.08, 0.09, 0.11, 1)
    pbsdf.inputs["Roughness"].default_value = 0.9
    plug.data.materials.append(pm)
    vg = plug.vertex_groups.new(name="head")
    vg.add(list(range(len(plug.data.vertices))), 1.0, "REPLACE")
    md = plug.modifiers.new("Armature", "ARMATURE"); md.object = arm; plug.parent = arm
    for v in plug.data.vertices:
        v.co.z -= 0.02
    plug.data.update()

    # 3) sword
    if weapon:
        thicken_sword(weapon, SWORD_Y, SWORD_X)

    plug = next((o for o in bpy.data.objects if o.name == "NeckPlug"), None)
    export_glb(OUT, body, head, weapon, arm, plug)
    review = os.path.join(RENDER_DIR, "cast_leader_hunyuan_head__board.glb")
    if os.path.abspath(review) != os.path.abspath(OUT):
        export_glb(review, body, head, weapon, arm, plug)

    # renders
    cam = setup_world()
    hc = world_coords(head)
    face_z = min(c.z for c in hc) + 0.45 * (max(c.z for c in hc) - min(c.z for c in hc))
    front_y = min(c.y for c in hc)
    neck_z = min(c.z for c in hc) + 0.02
    target = Vector((0.0, -0.12, 1.15))

    render_view(os.path.join(RENDER_DIR, "figure_front.png"), cam, Vector((0, -2.7, 1.25)), target, samples=40)
    render_view(os.path.join(RENDER_DIR, "figure_35deg.png"), cam, Vector((1.55, -2.2, 1.3)), target, samples=40)

    # face closeup — confirm face still OK
    cam.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    cam.location = Vector((0.0, front_y - 0.48, face_z))
    cam.data.lens = 90
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.cycles.samples = 64
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup")

    # neck closeup
    cam.location = Vector((0.05, front_y - 0.42, neck_z + 0.04))
    cam.data.lens = 85
    neck_t = Vector((0.0, front_y + 0.02, neck_z + 0.03))
    cam.rotation_euler = (neck_t - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RENDER_DIR, "neck_closeup.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER neck_closeup")

    # coat color check — mid torso framing
    cam.location = Vector((0.0, -1.6, 1.15))
    cam.data.lens = 55
    cam.rotation_euler = (Vector((0, -0.1, 1.15)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = 900, 1100
    scene.render.filepath = os.path.join(RENDER_DIR, "coat_front.png")
    bpy.ops.render.render(write_still=True)
    print("DONE polish")


if __name__ == "__main__":
    main()
