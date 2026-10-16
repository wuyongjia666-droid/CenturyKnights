#!/usr/bin/env python3
"""Path B: voxel remesh + bake albedo/normal from Hunyuan fullbody → board GLB.

blender --background --python tools/models/remesh_bake_hunyuan_board.py -- \\
  [--src PATH] [--out PATH] [--render-dir DIR] [--voxel F] [--target-tris N]
  [--bake-high-tris N] [--height F] [--tex N]
"""
from __future__ import annotations

import math
import os
import sys
import traceback

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


SRC = arg(
    "src",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/captain_farm_front_fullbody.glb",
)
OUT = arg(
    "out",
    "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.glb",
)
RENDER = arg(
    "render-dir",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready_v2",
)
VOXEL = float(arg("voxel", "0.009") or "0.009")
TARGET = int(arg("target-tris", "70000") or "70000")
BAKE_HIGH = int(arg("bake-high-tris", "280000") or "280000")
HEIGHT = float(arg("height", "1.85") or "1.85")
TEX = int(arg("tex", "2048") or "2048")

os.makedirs(RENDER, exist_ok=True)
os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)


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


def soft_collapse(ob, target_tris: int, label: str = ""):
    while len(ob.data.polygons) > target_tris * 1.05:
        cur = len(ob.data.polygons)
        if cur > target_tris * 4:
            aim = int(cur * 0.40)
        elif cur > target_tris * 2.2:
            aim = int(cur * 0.45)
        else:
            aim = target_tris
        aim = max(target_tris, aim)
        ratio = max(0.08, aim / float(cur))
        md = ob.modifiers.new(f"dec_{label}_{cur}", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = min(0.95, ratio)
        md.use_collapse_triangulate = False
        select_only(ob)
        bpy.ops.object.modifier_apply(modifier=md.name)
        print(f"COLLAPSE {label}: {cur} -> {len(ob.data.polygons)} r={md.ratio:.3f}")
        if len(ob.data.polygons) >= cur:
            print("WARN stall")
            break


def normalize(ob, target_h: float):
    apply_xf(ob)
    coords = world_coords(ob)
    zmin = min(c.z for c in coords)
    zmax = max(c.z for c in coords)
    h = zmax - zmin
    s = target_h / max(h, 1e-6)
    cx = sum(c.x for c in coords) / len(coords)
    cy = sum(c.y for c in coords) / len(coords)
    for v in ob.data.vertices:
        v.co.x = (v.co.x - cx) * s
        v.co.y = (v.co.y - cy) * s
        v.co.z = (v.co.z - zmin) * s
    ob.data.update()
    apply_xf(ob)
    coords = world_coords(ob)
    z0 = max(c.z for c in coords)
    band = [c for c in coords if c.z > z0 * 0.75]
    cy = sum(c.y for c in band) / len(band)
    if max(c.y for c in band) - cy > cy - min(c.y for c in band):
        ob.rotation_euler[2] = math.pi
        apply_xf(ob)
        print("ROTATED face -Y")
    coords = world_coords(ob)
    print(
        f"NORMALIZED h={max(c.z for c in coords)-min(c.z for c in coords):.3f} "
        f"tris={len(ob.data.polygons)}"
    )


def voxel_remesh(ob, voxel_size: float):
    select_only(ob)
    # Ensure mesh is manifold-ish for remesh; Voxel Remesh ops on mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # merge by distance tiny to reduce duplicate verts
    try:
        bpy.ops.mesh.remove_doubles(threshold=0.0001)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")
    md = ob.modifiers.new("VoxelRemesh", "REMESH")
    md.mode = "VOXEL"
    md.voxel_size = voxel_size
    md.adaptivity = 0.0
    select_only(ob)
    bpy.ops.object.modifier_apply(modifier=md.name)
    print(f"VOXEL remesh size={voxel_size} -> tris={len(ob.data.polygons)} verts={len(ob.data.vertices)}")


def smart_uv(ob):
    select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("UV smart_project done", bool(ob.data.uv_layers))


def make_bake_material(ob, albedo_img, normal_img):
    mat = bpy.data.materials.new("BoardBakeMat")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex_a = nt.nodes.new("ShaderNodeTexImage")
    tex_a.image = albedo_img
    tex_a.name = "BakeAlbedoTarget"
    tex_n = nt.nodes.new("ShaderNodeTexImage")
    tex_n.image = normal_img
    tex_n.name = "BakeNormalTarget"
    nrm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex_a.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex_n.outputs["Color"], nrm.inputs["Color"])
    nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return mat, tex_a, tex_n


def bake_maps(high, low, albedo_img, normal_img, mat, tex_a, tex_n):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.04
    scene.render.bake.margin = 8
    scene.cycles.bake_type = "DIFFUSE"
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True

    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low

    # Albedo bake — active image node = albedo target
    for n in mat.node_tree.nodes:
        n.select = False
    tex_a.select = True
    mat.node_tree.nodes.active = tex_a
    print("BAKE diffuse...")
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True)
    print("BAKE diffuse done")

    # Normal bake
    scene.cycles.bake_type = "NORMAL"
    scene.render.bake.normal_space = "TANGENT"
    for n in mat.node_tree.nodes:
        n.select = False
    tex_n.select = True
    mat.node_tree.nodes.active = tex_n
    print("BAKE normal...")
    bpy.ops.object.bake(type="NORMAL", use_clear=True)
    print("BAKE normal done")


def export_glb(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        o.hide_set(False)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_image_format="AUTO",
    )
    print("WROTE", path, os.path.getsize(path))


def setup_lights_cam():
    for o in list(bpy.data.objects):
        if o.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(o, do_unlink=True)

    def area(name, energy, loc, size=2.0):
        L = bpy.data.lights.new(name, "AREA")
        L.energy = energy
        L.size = size
        o = bpy.data.objects.new(name, L)
        o.location = loc
        bpy.context.collection.objects.link(o)

    area("Key", 170, (1.6, -2.2, 2.4), 2.0)
    area("Fill", 50, (-2.0, -1.0, 1.6), 3.0)
    area("Rim", 75, (0.2, 2.4, 2.0), 2.0)
    w = bpy.data.worlds.new("W")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.72, 0.73, 0.75, 1)
    bg.inputs[1].default_value = 0.9
    cam_d = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_d)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render_views(mesh, cam, out_dir):
    coords = world_coords(mesh)
    zmax = max(c.z for c in coords)
    zmin = min(c.z for c in coords)
    target = Vector((0, 0, zmax * 0.52))
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = True

    def rv(path, eye, lens=50, res=(900, 1120), samples=40):
        cam.location = eye
        cam.data.lens = lens
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        sc.cycles.samples = samples
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.filepath = path
        sc.render.image_settings.file_format = "PNG"
        bpy.ops.render.render(write_still=True)
        print("RENDER", path)

    rv(os.path.join(out_dir, "figure_front.png"), Vector((0, -2.9, zmax * 0.55)))
    rv(os.path.join(out_dir, "figure_35deg.png"), Vector((1.65, -2.4, zmax * 0.58)))
    head = [c for c in coords if c.z > zmax - 0.14 * (zmax - zmin)]
    cx = sum(c.x for c in head) / len(head)
    cy = sum(c.y for c in head) / len(head)
    cz = sum(c.z for c in head) / len(head)
    front_y = min(c.y for c in head)
    eye = Vector((cx, front_y - 0.40, cz + 0.01))
    tgt = Vector((cx, cy, cz))
    cam.location = eye
    cam.data.lens = 85
    cam.rotation_euler = (tgt - eye).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 900
    sc.cycles.samples = 48
    sc.render.filepath = os.path.join(out_dir, "face_closeup.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup")


def main():
    print("PATH_B remesh+bake", "voxel", VOXEL, "target", TARGET, "high", BAKE_HIGH)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    high = next(o for o in bpy.data.objects if o.type == "MESH")
    high.name = "High"
    print("IMPORT", len(high.data.polygons), "uv", bool(high.data.uv_layers))
    normalize(high, HEIGHT)

    # Soft reduce high for RAM / bake speed (keep UV+textures)
    soft_collapse(high, BAKE_HIGH, "bake_high")
    print("HIGH_FINAL", len(high.data.polygons))
    select_only(high)
    bpy.ops.object.shade_smooth()

    # Duplicate → Low remesh (destroys UV — expected)
    low = high.copy()
    low.data = high.data.copy()
    low.name = "Low"
    bpy.context.collection.objects.link(low)
    # Strip materials on low before remesh (cleaner)
    low.data.materials.clear()

    voxel_remesh(low, VOXEL)
    # If too dense, soft collapse AFTER remesh (manifold, less shatter than raw Hunyuan collapse)
    if len(low.data.polygons) > TARGET * 1.15:
        soft_collapse(low, TARGET, "post_remesh")
    print("LOW_FINAL", len(low.data.polygons))

    if len(low.data.polygons) < 20000:
        raise RuntimeError(f"remesh landed too low: {len(low.data.polygons)}")

    smart_uv(low)
    select_only(low)
    bpy.ops.object.shade_smooth()

    albedo = bpy.data.images.new("BoardAlbedo", width=TEX, height=TEX, alpha=False)
    normal = bpy.data.images.new("BoardNormal", width=TEX, height=TEX, alpha=False)
    # Normal default flat
    pixels = [0.5, 0.5, 1.0, 1.0] * (TEX * TEX)
    normal.pixels = pixels

    mat, tex_a, tex_n = make_bake_material(low, albedo, normal)
    try:
        bake_maps(high, low, albedo, normal, mat, tex_a, tex_n)
    except Exception:
        traceback.print_exc()
        print("BAKE_FAILED — abort path B")
        raise

    albedo.pack()
    normal.pack()

    # Hide high, export low
    high.hide_set(True)
    low.hide_set(False)
    export_glb(OUT, [low])
    review = os.path.join(RENDER, "cast_leader__board.glb")
    if os.path.abspath(review) != os.path.abspath(OUT):
        import shutil

        shutil.copy2(OUT, review)

    cam = setup_lights_cam()
    high.hide_set(True)
    render_views(low, cam, RENDER)

    # Also render high face as face_src reference from this session's high
    high.hide_set(False)
    low.hide_set(True)
    coords = world_coords(high)
    zmax = max(c.z for c in coords)
    zmin = min(c.z for c in coords)
    head = [c for c in coords if c.z > zmax - 0.14 * (zmax - zmin)]
    cx = sum(c.x for c in head) / len(head)
    cy = sum(c.y for c in head) / len(head)
    cz = sum(c.z for c in head) / len(head)
    front_y = min(c.y for c in head)
    eye = Vector((cx, front_y - 0.40, cz + 0.01))
    tgt = Vector((cx, cy, cz))
    cam.location = eye
    cam.data.lens = 85
    cam.rotation_euler = (tgt - eye).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    sc.render.resolution_x = sc.render.resolution_y = 900
    sc.cycles.samples = 32
    sc.render.filepath = os.path.join(RENDER, "face_src.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_src")

    print(
        "DONE_PATH_B",
        "low_tris",
        len(low.data.polygons),
        "high_tris",
        len(high.data.polygons),
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
