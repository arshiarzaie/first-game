"""
Builds genuine 3D fantasy world architecture, obstacles, floating islands,
volumetric 3D cloud clusters, orbs, and the monumental Abyssal Crystal Portal
in real Blender 5.0 (`web3d/public/models/props.glb`).
"""

import math
import os
import bpy
import bmesh
from mathutils import Vector, Euler, Matrix


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, rgba, roughness=0.45, metallic=0.05, em_rgb=None, em_str=0.0):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if em_rgb and em_str > 0 and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*em_rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = em_str
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def make_crystal_prism_bm(bm, base_pt, dir_vec, length, radius, sides=6, mat_idx=0):
    d = Vector(dir_vec).normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.92 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    v = d.cross(u).normalized()
    b0 = Vector(base_pt)
    b1 = b0 + d * (length * 0.74)
    tip = b0 + d * length

    ring0, ring1 = [], []
    for k in range(sides):
        ang = (k / sides) * 2.0 * math.pi
        off = u * math.cos(ang) + v * math.sin(ang)
        ring0.append(bm.verts.new(b0 + off * radius))
        ring1.append(bm.verts.new(b1 + off * (radius * 0.82)))
    v_bot = bm.verts.new(b0)
    v_tip = bm.verts.new(tip)

    for k in range(sides):
        kn = (k + 1) % sides
        for fverts in (
            [v_bot, ring0[kn], ring0[k]],
            [ring0[k], ring0[kn], ring1[kn], ring1[k]],
            [ring1[k], ring1[kn], v_tip],
        ):
            f = bm.faces.new(fverts)
            f.material_index = mat_idx
            f.smooth = False


def add_box_bm(bm, center, size_xyz, taper_top=1.0, mat_idx=0):
    cx, cy, cz = center
    sx, sy, sz = size_xyz[0] * 0.5, size_xyz[1] * 0.5, size_xyz[2] * 0.5
    tx, ty = sx * taper_top, sy * taper_top
    pts = [
        (cx - sx, cy - sy, cz - sz),
        (cx + sx, cy - sy, cz - sz),
        (cx + sx, cy + sy, cz - sz),
        (cx - sx, cy + sy, cz - sz),
        (cx - tx, cy - ty, cz + sz),
        (cx + tx, cy - ty, cz + sz),
        (cx + tx, cy + ty, cz + sz),
        (cx - tx, cy + ty, cz + sz),
    ]
    vs = [bm.verts.new(p) for p in pts]
    quads = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5),
        (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    for q in quads:
        f = bm.faces.new([vs[i] for i in q])
        f.material_index = mat_idx
        f.smooth = False


def finish_obj(name, bm, mats):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_crystal_portal(mats):
    """
    Monumental 3D Abyssal Crystal Portal Gateway!
    Spans X = [-4.4 .. +4.4], clear arched opening X = [-3.0 .. +3.0], height Z = 7.2m!
    """
    bm = bmesh.new()
    # Left & Right carved stone pedestals (mat 0 = stone, mat 1 = crystal, mat 2 = glowing core)
    for side in (-1.0, 1.0):
        px = side * 3.55
        add_box_bm(bm, (px, 0.0, 0.35), (1.75, 1.55, 0.70), taper_top=0.90, mat_idx=0)
        add_box_bm(bm, (px, 0.0, 0.85), (1.42, 1.25, 0.35), taper_top=0.86, mat_idx=0)
        # Flanking outer crystal spires!
        spire_specs = [
            ((px + side * 0.45,  0.15, 0.85), (side * 0.24,  0.04, 1.0), 3.6, 0.38),
            ((px - side * 0.20, -0.22, 0.90), (side * 0.08, -0.06, 1.0), 4.4, 0.42),
            ((px + side * 0.65, -0.18, 0.75), (side * 0.36, -0.05, 1.0), 2.5, 0.30),
            ((px + side * 0.15,  0.32, 0.85), (side * 0.15,  0.10, 1.0), 3.1, 0.32),
        ]
        for bpt, dv, L, R in spire_specs:
            make_crystal_prism_bm(bm, bpt, dv, L, R, sides=6, mat_idx=1)

    # Grand Faceted Crystal Archway Segments (14 segments around Gothic-arch curve!)
    N = 14
    rings = []
    for i in range(N + 1):
        u = i / N  # 0..1 from left pedestal to right pedestal
        ang = math.pi * (1.0 - u)
        cx = math.cos(ang) * 3.45
        # Pointed gothic apex lift near u=0.5!
        arch_z = 0.95 + math.sin(ang) * 5.35 + (1.0 - abs(u - 0.5) * 2.0) ** 1.6 * 0.85
        tang = Vector((math.sin(ang) * 3.45, 0.0, math.cos(ang) * 5.35)).normalized()
        rad_out = Vector((math.cos(ang), 0.0, math.sin(ang))).normalized()
        thick = 0.52 + 0.16 * math.sin(ang)
        depth = 0.58
        # 6-sided faceted crystal cross-section
        prof = [
            rad_out * thick,
            rad_out * (thick * 0.35) + Vector((0, depth, 0)),
            -rad_out * (thick * 0.65) + Vector((0, depth * 0.55, 0)),
            -rad_out * (thick * 0.85),
            -rad_out * (thick * 0.65) - Vector((0, depth * 0.55, 0)),
            rad_out * (thick * 0.35) - Vector((0, depth, 0)),
        ]
        center_v = Vector((cx, 0.0, arch_z))
        rings.append([bm.verts.new(center_v + p) for p in prof])

    for i in range(N):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(6):
            kn = (k + 1) % 6
            f = bm.faces.new([r0[k], r0[kn], r1[kn], r1[k]])
            f.material_index = 2 if k in (2, 3, 4) else 1
            f.smooth = False

    # Radiant Crown Keystone Diamond at Apex!
    make_crystal_prism_bm(bm, (0.0, 0.0, 6.55), (0, 0, 1), 1.25, 0.46, sides=6, mat_idx=2)
    make_crystal_prism_bm(bm, (0.0, 0.0, 6.55), (0, 0, -1), 0.85, 0.42, sides=6, mat_idx=2)

    return finish_obj("CrystalPortal", bm, [mats["stone"], mats["portal_crystal"], mats["portal_glow"]])


def build_obstacle_spikes(mats):
    """Low Jump Obstacle: Rocky Plinth + 7 Razor-Faceted Crystal Shards (height ~1.12m, width ~1.65m)."""
    bm = bmesh.new()
    add_box_bm(bm, (0.0, 0.0, 0.14), (1.55, 1.15, 0.28), taper_top=0.84, mat_idx=0)
    shards = [
        (( 0.00,  0.00, 0.16), ( 0.00, -0.06, 1.0), 1.02, 0.24),
        ((-0.38,  0.04, 0.14), (-0.28,  0.05, 1.0), 0.86, 0.20),
        (( 0.38, -0.04, 0.14), ( 0.28, -0.05, 1.0), 0.88, 0.20),
        ((-0.62, -0.08, 0.12), (-0.46, -0.10, 1.0), 0.64, 0.16),
        (( 0.62,  0.08, 0.12), ( 0.46,  0.10, 1.0), 0.66, 0.16),
        ((-0.18, -0.22, 0.14), (-0.12, -0.28, 1.0), 0.72, 0.17),
        (( 0.20,  0.22, 0.14), ( 0.12,  0.28, 1.0), 0.70, 0.17),
    ]
    for bpt, dv, L, R in shards:
        make_crystal_prism_bm(bm, bpt, dv, L, R, sides=6, mat_idx=1)
    return finish_obj("ObstacleSpikes", bm, [mats["dark_stone"], mats["accent_crystal"]])


def build_obstacle_arch(mats):
    """
    High Slide/Roll Obstacle: True 3D Carved Stone Archway!
    Clear opening underneath lintel: Z = [0.0 .. 1.18m] so rolling Soul passes
    100% cleanly underneath in real 3D space while standing Soul collides!
    """
    bm = bmesh.new()
    for side in (-1.0, 1.0):
        px = side * 0.92
        # Base plinth + column + capital
        add_box_bm(bm, (px, 0.0, 0.16), (0.48, 0.56, 0.32), taper_top=0.88, mat_idx=0)
        add_box_bm(bm, (px, 0.0, 0.82), (0.34, 0.40, 1.05), taper_top=0.94, mat_idx=0)
        add_box_bm(bm, (px, 0.0, 1.42), (0.46, 0.50, 0.20), taper_top=1.08, mat_idx=0)
    # Heavy carved cross-lintel bar (underside at Z = 1.24m, top at Z = 2.15m!)
    add_box_bm(bm, (0.0, 0.0, 1.62), (2.42, 0.56, 0.72), taper_top=0.94, mat_idx=0)
    add_box_bm(bm, (0.0, 0.0, 2.08), (2.58, 0.64, 0.22), taper_top=0.88, mat_idx=0)
    # Glowing Rune Strip along front & back of lintel (warns player visually to roll under!)
    add_box_bm(bm, (0.0, -0.29, 1.56), (1.75, 0.05, 0.20), taper_top=1.0, mat_idx=1)
    add_box_bm(bm, (0.0,  0.29, 1.56), (1.75, 0.05, 0.20), taper_top=1.0, mat_idx=1)
    # Top crystal crest
    make_crystal_prism_bm(bm, (0.0, 0.0, 2.16), (0, 0, 1), 0.62, 0.22, sides=6, mat_idx=1)
    return finish_obj("ObstacleArch", bm, [mats["stone"], mats["rune_gold"]])


def build_obstacle_monolith(mats):
    """Full-Lane Towering Rune Obelisk (must switch lanes or bounce over on sky cloud; height ~3.35m)."""
    bm = bmesh.new()
    add_box_bm(bm, (0.0, 0.0, 0.22), (1.58, 1.48, 0.44), taper_top=0.88, mat_idx=0)
    add_box_bm(bm, (0.0, 0.0, 1.52), (1.22, 1.14, 2.20), taper_top=0.76, mat_idx=0)
    # Glowing carved rune bands
    for rz, rw in [(0.95, 1.18), (1.65, 1.08), (2.25, 0.98)]:
        add_box_bm(bm, (0.0, 0.0, rz), (rw, rw * 0.94, 0.11), taper_top=1.0, mat_idx=1)
    # Pyramidion cap + floating crystal spire
    make_crystal_prism_bm(bm, (0.0, 0.0, 2.60), (0, 0, 1), 0.82, 0.56, sides=4, mat_idx=1)
    return finish_obj("ObstacleMonolith", bm, [mats["dark_stone"], mats["accent_crystal"]])


def build_corridor_pillar(mats):
    """Roadside 3D Lantern Brazier Column."""
    bm = bmesh.new()
    add_box_bm(bm, (0.0, 0.0, 0.22), (0.72, 0.72, 0.44), taper_top=0.86, mat_idx=0)
    add_box_bm(bm, (0.0, 0.0, 1.32), (0.46, 0.46, 1.80), taper_top=0.88, mat_idx=0)
    add_box_bm(bm, (0.0, 0.0, 2.32), (0.68, 0.68, 0.24), taper_top=1.15, mat_idx=0)
    make_crystal_prism_bm(bm, (0.0, 0.0, 2.46), (0, 0, 1), 0.62, 0.24, sides=6, mat_idx=1)
    make_crystal_prism_bm(bm, (0.0, 0.0, 2.46), (0, 0, -1), 0.24, 0.20, sides=6, mat_idx=1)
    return finish_obj("CorridorPillar", bm, [mats["stone"], mats["rune_gold"]])


def build_floating_island(mats):
    """Genuine 3D Craggy Floating Sky Island + Miniature Temple Citadel + Crystal Spire!"""
    bm = bmesh.new()
    # Craggy inverted-cone rock island
    rings = [
        (0.0,  2.80, 9),
        (-0.8, 2.35, 9),
        (-1.8, 1.45, 9),
        (-2.8, 0.55, 9),
    ]
    rvert = []
    for ri, (rz, rad, segs) in enumerate(rings):
        rv = []
        for k in range(segs):
            ang = (k / segs) * 2.0 * math.pi + ri * 0.22
            jit = 0.88 + 0.22 * math.sin(k * 2.7 + ri * 1.9)
            rv.append(bm.verts.new((math.cos(ang) * rad * jit, math.sin(ang) * rad * jit, rz)))
        rvert.append(rv)
    v_top = bm.verts.new((0.0, 0.0, 0.18))
    v_bot = bm.verts.new((0.0, 0.0, -3.55))
    for k in range(9):
        kn = (k + 1) % 9
        f1 = bm.faces.new([v_top, rvert[0][k], rvert[0][kn]])
        f1.material_index = 1
        f2 = bm.faces.new([rvert[-1][kn], rvert[-1][k], v_bot])
        f2.material_index = 0
    for i in range(len(rings) - 1):
        for k in range(9):
            kn = (k + 1) % 9
            f = bm.faces.new([rvert[i][k], rvert[i][kn], rvert[i + 1][kn], rvert[i + 1][k]])
            f.material_index = 0

    # Miniature sky temple & glowing crystal tower on top!
    add_box_bm(bm, (0.0, 0.0, 0.55), (2.2, 2.2, 0.75), taper_top=0.88, mat_idx=1)
    add_box_bm(bm, (0.0, 0.0, 1.35), (1.35, 1.35, 0.95), taper_top=0.84, mat_idx=1)
    make_crystal_prism_bm(bm, (0.0, 0.0, 1.80), (0, 0, 1), 1.65, 0.45, sides=6, mat_idx=2)
    for sx, sy in [(-0.85, -0.85), (0.85, -0.85), (-0.85, 0.85), (0.85, 0.85)]:
        make_crystal_prism_bm(bm, (sx, sy, 0.85), (0, 0, 1), 0.95, 0.22, sides=5, mat_idx=2)

    return finish_obj("FloatingIsland", bm, [mats["dark_stone"], mats["stone"], mats["rune_gold"]])


def build_puffy_cloud(name, mat):
    """Organic 3D Puffy Cloud sculpted via Blender MetaBalls -> smooth low-poly 3D mesh!"""
    mb = bpy.data.metaballs.new(name + "_MB")
    mb.resolution = 0.08
    mb.threshold = 0.60
    mobj = bpy.data.objects.new(name + "_MBObj", mb)
    bpy.context.collection.objects.link(mobj)
    puffs = [
        ( 0.00,  0.00, 0.36, 0.68),
        (-0.56,  0.06, 0.28, 0.52),
        ( 0.56, -0.04, 0.30, 0.54),
        (-0.28, -0.28, 0.26, 0.46),
        ( 0.28,  0.28, 0.28, 0.48),
        (-0.88,  0.00, 0.20, 0.38),
        ( 0.88,  0.02, 0.22, 0.40),
    ]
    for x, y, z, r in puffs:
        el = mb.elements.new(type="BALL")
        el.co = (x, y, z)
        el.radius = r
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = mobj
    mobj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    cobj = bpy.context.active_object
    cobj.name = name
    dec = cobj.modifiers.new("Dec", "DECIMATE")
    dec.ratio = 0.35
    bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in cobj.data.polygons:
        p.use_smooth = True
    cobj.data.materials.append(mat)
    return cobj


def main():
    reset_scene()
    mats = {
        "stone":          make_mat("Prop_Stone",        (0.54, 0.48, 0.66, 1.0), roughness=0.68, metallic=0.05),
        "dark_stone":     make_mat("Prop_DarkStone",    (0.28, 0.24, 0.38, 1.0), roughness=0.74, metallic=0.08),
        "portal_crystal": make_mat("Prop_PortalCryst",  (0.70, 0.84, 1.00, 1.0), roughness=0.16, metallic=0.12, em_rgb=(0.32, 0.56, 1.0), em_str=0.45),
        "portal_glow":    make_mat("Prop_PortalGlow",   (0.92, 0.97, 1.00, 1.0), roughness=0.08, metallic=0.05, em_rgb=(0.68, 0.88, 1.0), em_str=1.25),
        "accent_crystal": make_mat("Prop_AccentCryst",  (0.78, 0.32, 0.98, 1.0), roughness=0.18, metallic=0.10, em_rgb=(0.66, 0.20, 0.95), em_str=0.65),
        "rune_gold":      make_mat("Prop_RuneGold",     (1.00, 0.78, 0.28, 1.0), roughness=0.24, metallic=0.22, em_rgb=(1.00, 0.62, 0.14), em_str=0.95),
        "gold_cloud":     make_mat("Prop_GoldCloud",    (1.00, 0.84, 0.42, 1.0), roughness=0.38, metallic=0.02, em_rgb=(1.00, 0.64, 0.18), em_str=0.55),
        "storm_cloud":    make_mat("Prop_StormCloud",   (0.22, 0.18, 0.34, 1.0), roughness=0.55, metallic=0.05, em_rgb=(0.44, 0.18, 0.78), em_str=0.28),
    }

    objs = [
        build_crystal_portal(mats),
        build_obstacle_spikes(mats),
        build_obstacle_arch(mats),
        build_obstacle_monolith(mats),
        build_corridor_pillar(mats),
        build_floating_island(mats),
        build_puffy_cloud("GoldenCloud", mats["gold_cloud"]),
        build_puffy_cloud("StormCloud", mats["storm_cloud"]),
    ]

    for o in objs:
        o.data.validate()

    os.makedirs("web3d/public/models", exist_ok=True)
    out_glb = "web3d/public/models/props.glb"
    bpy.ops.export_scene.gltf(
        filepath=out_glb,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
    )
    print(f"Exported {out_glb}: {os.path.getsize(out_glb):,} bytes | meshes={[o.name for o in objs]}")


if __name__ == "__main__":
    main()
