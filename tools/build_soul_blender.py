"""
Builds the fully sculpted, PBR-shaded, 25-bone rigged & weight-painted 3D
Pixar-Chibi Soul character (`web3d/public/models/soul.glb`) using real
Blender 5.0 (`bpy`), complete with 7 fluid skeletal animation clips and a
shaded multi-view / multi-pose verification sheet.
"""

import math
import os
import bpy
import bmesh
from mathutils import Vector, Euler, Matrix
import numpy as np
from PIL import Image, ImageDraw


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_pbr_mat(name, base_rgba, roughness=0.42, metallic=0.0, emission_rgb=None, emission_strength=0.0, use_vertex_color=False):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic

    if use_vertex_color:
        vcol = nodes.new("ShaderNodeVertexColor")
        vcol.layer_name = "Col"
        links.new(vcol.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = base_rgba

    if emission_rgb and emission_strength > 0.0 and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*emission_rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength

    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def add_meta_capsule(mball, ax, ay, az, bx, by, bz, r_surface_a, r_surface_b, steps=10):
    """
    Note: With MetaBall threshold=0.60, effective visible iso-surface radius of an
    isolated BALL is ~0.55 * ball.radius, and along a dense chain sums to ~0.82 * r.
    Calibrating multiplier = 1.24 produces exact plump Pixar-chibi thickness!
    """
    for i in range(steps):
        t = i / max(1, steps - 1)
        el = mball.elements.new(type="BALL")
        el.co = (ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t)
        el.radius = (r_surface_a + (r_surface_b - r_surface_a) * t) * 1.24


def build_seamless_chibi_body(mat_body):
    """
    True Pixar-Chibi Toddler Proportions matching `hover_open.png`!
      Total height with crown: ~1.34m
      Feet soles: Z = 0.00m
      Plump stubby legs: Z = 0.00 .. 0.34m
      Pear-shaped chibi tummy/bottom: Z = 0.33 .. 0.60m
      Short cuddly neck nestled right under big sun-hood: Z = 0.60 .. 0.67m
      Big velvety Sun-Hood head center: Z = 0.89m (radius ~0.27m!)
    """
    mb_data = bpy.data.metaballs.new("SoulMeta")
    mb_data.resolution = 0.014
    mb_data.threshold = 0.60
    mb_obj = bpy.data.objects.new("SoulMetaObj", mb_data)
    bpy.context.collection.objects.link(mb_obj)

    # 1. Plump Pear-Shaped Chibi Bottom, Tummy & Shoulders (compact & cuddly!)
    el_pel = mb_data.elements.new(type="ELLIPSOID")
    el_pel.co = (0.0, 0.012, 0.37)
    el_pel.size_x, el_pel.size_y, el_pel.size_z = 0.195, 0.172, 0.165
    el_pel.radius = 1.0

    el_tum = mb_data.elements.new(type="ELLIPSOID")
    el_tum.co = (0.0, -0.015, 0.45)
    el_tum.size_x, el_tum.size_y, el_tum.size_z = 0.182, 0.165, 0.160
    el_tum.radius = 1.0

    el_che = mb_data.elements.new(type="ELLIPSOID")
    el_che.co = (0.0, 0.0, 0.56)
    el_che.size_x, el_che.size_y, el_che.size_z = 0.160, 0.140, 0.135
    el_che.radius = 1.0

    # Short soft chibi neck bridge nestled directly into sun-hood (zero giraffe neck!)
    add_meta_capsule(mb_data, 0.0, 0.0, 0.56, 0.0, 0.005, 0.66, 0.108, 0.122, steps=4)

    # 2. Big Velvety Sun-Hood Cranium + Plump Toddler Cheeks (~56% head+crown ratio!)
    el_head = mb_data.elements.new(type="ELLIPSOID")
    el_head.co = (0.0, 0.010, 0.835)
    el_head.size_x, el_head.size_y, el_head.size_z = 0.345, 0.340, 0.315
    el_head.radius = 1.0

    for side in (-1.0, 1.0):
        el_chk = mb_data.elements.new(type="ELLIPSOID")
        el_chk.co = (side * 0.168, -0.052, 0.768)
        el_chk.size_x, el_chk.size_y, el_chk.size_z = 0.160, 0.155, 0.138
        el_chk.radius = 1.0

    # 3. Plump, Stubby Chibi Legs & Upturned Little Boots (X = ±0.096)
    for side in (-1.0, 1.0):
        hx = side * 0.096
        # Thigh: Z=0.35 -> 0.19
        add_meta_capsule(mb_data, hx, 0.0, 0.35, hx * 1.04, -0.006, 0.19, 0.072, 0.060, steps=6)
        # Calf: Z=0.19 -> 0.065
        add_meta_capsule(mb_data, hx * 1.04, -0.006, 0.19, hx * 1.05, 0.006, 0.065, 0.058, 0.050, steps=6)
        # Cute rounded Pixar foot pointing -Y
        add_meta_capsule(mb_data, hx * 1.05, 0.018, 0.055, hx * 1.05, -0.082, 0.052, 0.054, 0.050, steps=5)

    # 4. Plump, Stubby Chibi Arms & Cute Mitten-Paws in 42° A-pose
    for side in (-1.0, 1.0):
        # Shoulder (0.125, 0, 0.565) -> Elbow (0.235, 0.005, 0.475) -> Hand (0.325, -0.018, 0.395)
        add_meta_capsule(mb_data, side * 0.122, 0.0, 0.565, side * 0.232, 0.005, 0.478, 0.054, 0.048, steps=6)
        add_meta_capsule(mb_data, side * 0.232, 0.005, 0.478, side * 0.320, -0.018, 0.400, 0.048, 0.054, steps=6)
        el_paw = mb_data.elements.new(type="ELLIPSOID")
        el_paw.co = (side * 0.340, -0.025, 0.384)
        el_paw.size_x, el_paw.size_y, el_paw.size_z = 0.074, 0.068, 0.065
        el_paw.radius = 1.0
        el_th = mb_data.elements.new(type="BALL")
        el_th.co = (side * 0.318, -0.065, 0.402)
        el_th.radius = 0.038

    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = mb_obj
    mb_obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    body_obj = bpy.context.active_object
    body_obj.name = "SoulBody"

    sm = body_obj.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.62
    sm.iterations = 6
    bpy.ops.object.modifier_apply(modifier=sm.name)

    dec = body_obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = 0.40
    bpy.ops.object.modifier_apply(modifier=dec.name)

    min_z = min(v.co.z for v in body_obj.data.vertices)
    for v in body_obj.data.vertices:
        v.co.z -= min_z

    for poly in body_obj.data.polygons:
        poly.use_smooth = True

    if not body_obj.data.color_attributes:
        body_obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    col_layer = body_obj.data.color_attributes["Col"]
    verts = body_obj.data.vertices
    for poly in body_obj.data.polygons:
        for li in poly.loop_indices:
            v = verts[body_obj.data.loops[li].vertex_index]
            co = v.co
            no = v.normal
            # Creamy Pixar golden-apricot skin!
            r, g, b = 1.0, 0.66, 0.21
            # Soft creamy-peach face zone on front (-Y) of head!
            if co.y < -0.05 and co.z > 0.62:
                face_w = max(0.0, min(1.0, (-co.y - 0.05) / 0.14)) * max(0.0, 1.0 - abs(co.x) / 0.24)
                r = r * (1.0 - 0.65 * face_w) + 1.0 * (0.65 * face_w)
                g = g * (1.0 - 0.65 * face_w) + 0.80 * (0.65 * face_w)
                b = g * 0.0 + b * (1.0 - 0.65 * face_w) + 0.50 * (0.65 * face_w)
            # Top sunlit butter-gold lift
            top_lift = max(0.0, min(1.0, (co.z - 0.52) / 0.58)) * max(0.0, no.z * 0.5 + 0.5)
            r = r * (1.0 - 0.34 * top_lift) + 1.0 * (0.34 * top_lift)
            g = g * (1.0 - 0.34 * top_lift) + 0.85 * (0.34 * top_lift)
            b = b * (1.0 - 0.34 * top_lift) + 0.40 * (0.34 * top_lift)
            # Rosy coral cheek blush & warm knees
            cheek_d = math.exp(-(((co.z - 0.77) / 0.090) ** 2)) * math.exp(-(((abs(co.x) - 0.140) / 0.075) ** 2)) * (1.0 if co.y < 0.02 else 0.35)
            warm_blush = min(0.50, cheek_d * 0.50)
            r = r * (1.0 - warm_blush) + 1.0 * warm_blush
            g = g * (1.0 - warm_blush) + 0.38 * warm_blush
            b = b * (1.0 - warm_blush) + 0.24 * warm_blush
            col_layer.data[li].color = (r, g, b, 1.0)

    body_obj.data.materials.append(mat_body)
    return body_obj


def make_faceted_sun_ray_mesh(name, length, w0, d0, curve_up=0.03, curve_back=0.025):
    bm = bmesh.new()
    rings = 8
    ring_verts = []
    v_base = bm.verts.new((0.0, 0.0, -0.04))
    for i in range(rings):
        t = i / rings
        z = t * length
        taper = (1.0 - t) ** 0.82
        belly = math.sin(t * math.pi) * 0.18 * (1.0 - 0.4 * t)
        hw = w0 * (taper + belly) + 0.006
        hd = d0 * (taper + belly * 0.75) + 0.005
        cx = curve_up * (t * t)
        cy = curve_back * (t * t)
        pts = [
            (cx,             cy - hd,        z),
            (cx + hw * 0.56, cy - hd * 0.50, z),
            (cx + hw,        cy,             z),
            (cx + hw * 0.56, cy + hd * 0.50, z),
            (cx,             cy + hd,        z),
            (cx - hw * 0.56, cy + hd * 0.50, z),
            (cx - hw,        cy,             z),
            (cx - hw * 0.56, cy - hd * 0.50, z),
        ]
        ring_verts.append([bm.verts.new(p) for p in pts])

    v_tip = bm.verts.new((curve_up, curve_back, length + 0.012))

    for k in range(8):
        bm.faces.new([v_base, ring_verts[0][(k + 1) % 8], ring_verts[0][k]])
    for i in range(rings - 1):
        r0, r1 = ring_verts[i], ring_verts[i + 1]
        for k in range(8):
            kn = (k + 1) % 8
            bm.faces.new([r0[k], r0[kn], r1[kn], r1[k]])
    rl = ring_verts[-1]
    for k in range(8):
        bm.faces.new([rl[k], rl[(k + 1) % 8], v_tip])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    col = mesh.color_attributes["Col"]
    for poly in mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            vz = mesh.vertices[mesh.loops[li].vertex_index].co.z
            u = max(0.0, min(1.0, vz / max(0.01, length)))
            col.data[li].color = (1.0, 0.62 + 0.33 * u, 0.16 + 0.44 * (u * u), 1.0)
    return mesh


def make_curved_capsule_mesh(name, pts, radii, segs=10):
    """Clean watertight curved tube mesh (for expressive arched brows & smile!)."""
    bm = bmesh.new()
    rings = []
    for idx, (pt, rad) in enumerate(zip(pts, radii)):
        p = Vector(pt)
        if idx < len(pts) - 1:
            tang = (Vector(pts[idx + 1]) - p).normalized()
        else:
            tang = (p - Vector(pts[idx - 1])).normalized()
        up = Vector((0, 0, 1)) if abs(tang.z) < 0.9 else Vector((1, 0, 0))
        u_ax = tang.cross(up).normalized()
        v_ax = tang.cross(u_ax).normalized()
        rv = []
        for k in range(segs):
            ang = (k / segs) * 2.0 * math.pi
            rv.append(bm.verts.new(p + (u_ax * math.cos(ang) + v_ax * math.sin(ang)) * rad))
        rings.append(rv)
    v_start = bm.verts.new(Vector(pts[0]))
    v_end = bm.verts.new(Vector(pts[-1]))
    for k in range(segs):
        bm.faces.new([v_start, rings[0][(k + 1) % segs], rings[0][k]])
    for i in range(len(rings) - 1):
        for k in range(segs):
            kn = (k + 1) % segs
            bm.faces.new([rings[i][k], rings[i][kn], rings[i + 1][kn], rings[i + 1][k]])
    for k in range(segs):
        bm.faces.new([rings[-1][k], rings[-1][(k + 1) % segs], v_end])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    return mesh


def build_crown_and_face_parts(mats):
    parts = []
    head_c = Vector((0.0, 0.012, 0.845))

    # 1. 7 Bold Sunflower Hero Rays + 4 Secondary Staggered Rays (matching hover_open.png!)
    hero_specs = [
        ("Ray_0",   0.0,   0.34, 0.148, 0.088,  0.00,  0.032, 0.025),
        ("Ray_1", -46.0,   0.32, 0.138, 0.082, -0.035, 0.030, 0.025),
        ("Ray_2",  46.0,   0.32, 0.138, 0.082,  0.035, 0.030, 0.025),
        ("Ray_3", -93.0,   0.30, 0.130, 0.076, -0.022, 0.026, 0.025),
        ("Ray_4",  93.0,   0.30, 0.130, 0.076,  0.022, 0.026, 0.025),
        ("Ray_5", -134.0,  0.24, 0.108, 0.068, -0.018, 0.022, 0.035),
        ("Ray_6",  134.0,  0.24, 0.108, 0.068,  0.018, 0.022, 0.035),
    ]
    ray_bone_transforms = {}
    for bname, deg, L, W0, D0, c_up, c_back, y_off in hero_specs:
        rad = math.radians(deg)
        dir_v = Vector((math.sin(rad), 0.10, math.cos(rad))).normalized()
        base_pos = head_c + Vector((math.sin(rad) * 0.195, y_off, math.cos(rad) * 0.185))
        mesh = make_faceted_sun_ray_mesh(bname + "_Mesh", L, W0, D0, c_up, c_back)
        mesh.materials.append(mats["crown"])
        obj = bpy.data.objects.new(bname + "_Obj", mesh)
        bpy.context.collection.objects.link(obj)
        rot_q = Vector((0, 0, 1)).rotation_difference(dir_v)
        obj.matrix_world = Matrix.Translation(base_pos) @ rot_q.to_matrix().to_4x4()
        parts.append((obj, bname))
        ray_bone_transforms[bname] = (base_pos, base_pos + dir_v * L)

    sec_specs = [
        (-23.0, 0.25, 0.102, 0.064, 0.085),
        ( 23.0, 0.25, 0.102, 0.064, 0.085),
        (-69.0, 0.24, 0.096, 0.060, 0.085),
        ( 69.0, 0.24, 0.096, 0.060, 0.085),
    ]
    for idx, (deg, L, W0, D0, y_off) in enumerate(sec_specs):
        rad = math.radians(deg)
        dir_v = Vector((math.sin(rad) * 0.94, 0.24, math.cos(rad) * 0.94)).normalized()
        base_pos = head_c + Vector((math.sin(rad) * 0.200, y_off, math.cos(rad) * 0.190))
        mesh = make_faceted_sun_ray_mesh(f"SecRay_{idx}", L, W0, D0, 0.0, 0.025)
        mesh.materials.append(mats["crown"])
        obj = bpy.data.objects.new(f"SecRayObj_{idx}", mesh)
        bpy.context.collection.objects.link(obj)
        rot_q = Vector((0, 0, 1)).rotation_difference(dir_v)
        obj.matrix_world = Matrix.Translation(base_pos) @ rot_q.to_matrix().to_4x4()
        parts.append((obj, "Head"))

    # 2. Big Soulful Pixar Eyes nestled FLUSH into front forehead/cheeks (ey = -0.172, ez = 0.835)!
    eyelid_pivots = {}
    for side, s_tag in [(-1.0, "R"), (1.0, "L")]:
        ex, ey, ez = side * 0.088, -0.172, 0.835
        eyelid_pivots[f"Eyelid_{s_tag}"] = Vector((ex, ey, ez))

        # Sclera nestled flush into face contour (rotated 16 deg outward along cheek!)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.066, location=(ex, ey, ez))
        scl = bpy.context.active_object
        scl.scale = (0.96, 0.44, 1.05)
        scl.rotation_euler = Euler((0.0, 0.0, side * math.radians(-16.0)), "XYZ")
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for p in scl.data.polygons:
            p.use_smooth = True
        scl.data.materials.append(mats["sclera"])
        parts.append((scl, "Head"))

        # HUGE Pixar Chestnut-Amber Iris
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=0.053, location=(ex * 0.97, ey - 0.011, ez - 0.002))
        iris = bpy.context.active_object
        iris.scale = (0.94, 0.40, 1.02)
        iris.rotation_euler = Euler((0.0, 0.0, side * math.radians(-16.0)), "XYZ")
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for p in iris.data.polygons:
            p.use_smooth = True
        iris.data.materials.append(mats["iris"])
        parts.append((iris, "Head"))

        # Deep Glossy Pupil
        bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=0.035, location=(ex * 0.96, ey - 0.018, ez - 0.002))
        pup = bpy.context.active_object
        pup.scale = (0.92, 0.36, 1.00)
        pup.rotation_euler = Euler((0.0, 0.0, side * math.radians(-16.0)), "XYZ")
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for p in pup.data.polygons:
            p.use_smooth = True
        pup.data.materials.append(mats["pupil"])
        parts.append((pup, "Head"))

        # Primary + Secondary Pixar Specular Catchlights!
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.014, location=(ex - side * 0.016, ey - 0.028, ez + 0.021))
        sp1 = bpy.context.active_object
        for p in sp1.data.polygons:
            p.use_smooth = True
        sp1.data.materials.append(mats["sparkle"])
        parts.append((sp1, "Head"))

        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.007, location=(ex + side * 0.016, ey - 0.026, ez - 0.018))
        sp2 = bpy.context.active_object
        for p in sp2.data.polygons:
            p.use_smooth = True
        sp2.data.materials.append(mats["sparkle"])
        parts.append((sp2, "Head"))

        # Animated Upper Eyelid Shell (full hemisphere sweep so +95 deg closes 100% cleanly!)
        bm_lid = bmesh.new()
        bmesh.ops.create_uvsphere(bm_lid, u_segments=22, v_segments=14, radius=0.072)
        for v in list(bm_lid.verts):
            if v.co.z < -0.012:
                bm_lid.verts.remove(v)
            else:
                v.co.x *= 1.02
                v.co.y *= 0.56
                v.co.z *= 1.10
        bmesh.ops.recalc_face_normals(bm_lid, faces=bm_lid.faces)
        lid_mesh = bpy.data.meshes.new(f"EyelidMesh_{s_tag}")
        bm_lid.to_mesh(lid_mesh)
        bm_lid.free()
        for p in lid_mesh.polygons:
            p.use_smooth = True
        lid_mesh.materials.append(mats["nose"])
        lid_obj = bpy.data.objects.new(f"EyelidObj_{s_tag}", lid_mesh)
        bpy.context.collection.objects.link(lid_obj)
        lid_obj.location = (ex, ey + 0.002, ez)
        lid_obj.rotation_euler = Euler((math.radians(-88.0), 0.0, side * math.radians(-16.0)), "XYZ")
        parts.append((lid_obj, f"Eyelid_{s_tag}"))

        # Clean Watertight Arched Pixar Eyebrow
        brow_pts = []
        brow_rads = []
        for bi in range(7):
            bu = (bi / 6.0) * 2.0 - 1.0
            bx = ex + side * bu * 0.046
            bz = ez + 0.078 + (1.0 - bu * bu) * 0.018
            by = ey - 0.008 + (bu * bu) * 0.018
            brow_pts.append((bx, by, bz))
            brow_rads.append(0.004 + 0.006 * math.sin((bi / 6.0) * math.pi))
        brow_mesh = make_curved_capsule_mesh(f"Brow_{s_tag}", brow_pts, brow_rads, segs=10)
        brow_mesh.materials.append(mats["brow"])
        brow_obj = bpy.data.objects.new(f"BrowObj_{s_tag}", brow_mesh)
        bpy.context.collection.objects.link(brow_obj)
        parts.append((brow_obj, "Head"))

    # Cute Little Button Nose nestled flush at y = -0.205
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.019, location=(0.0, -0.205, 0.792))
    nose = bpy.context.active_object
    nose.scale = (1.18, 0.65, 0.82)
    bpy.ops.object.transform_apply(scale=True)
    for p in nose.data.polygons:
        p.use_smooth = True
    nose.data.materials.append(mats["nose"])
    parts.append((nose, "Head"))

    # Joyful Curved Pixar Smile Arc nestled flush at y = -0.194
    sm_pts = []
    sm_rads = []
    for si in range(9):
        su = (si / 8.0) * 2.0 - 1.0
        sx = su * 0.050
        sz = 0.748 + (su * su) * 0.022
        sy = -0.194 + (su * su) * 0.018
        sm_pts.append((sx, sy, sz))
        sm_rads.append(0.004 + 0.011 * math.sin((si / 8.0) * math.pi))
    sm_mesh = make_curved_capsule_mesh("SmileArc", sm_pts, sm_rads, segs=10)
    sm_mesh.materials.append(mats["smile"])
    sm_obj = bpy.data.objects.new("SmileObj", sm_mesh)
    bpy.context.collection.objects.link(sm_obj)
    parts.append((sm_obj, "Head"))

    return parts, ray_bone_transforms, eyelid_pivots


def build_armature_and_skin(body_obj, parts, ray_bone_transforms, eyelid_pivots):
    arm_data = bpy.data.armatures.new("SoulArmature")
    arm_obj = bpy.data.objects.new("SoulRig", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def add_bone(name, head, tail, parent=None, connect=False):
        b = eb.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        return b

    add_bone("Root",   (0.0, 0.0, 0.0),    (0.0, 0.0, 0.16))
    add_bone("Pelvis", (0.0, 0.005, 0.36), (0.0, 0.005, 0.48), "Root")
    add_bone("Spine",  (0.0, 0.005, 0.48), (0.0, 0.005, 0.59), "Pelvis", True)
    add_bone("Neck",   (0.0, 0.005, 0.59), (0.0, 0.008, 0.66), "Spine", True)
    add_bone("Head",   (0.0, 0.008, 0.66), (0.0, 0.012, 1.00), "Neck", True)

    for bname, (bh, bt) in ray_bone_transforms.items():
        add_bone(bname, bh, bt, "Head", False)

    for bname, piv in eyelid_pivots.items():
        add_bone(bname, piv, piv + Vector((0.0, -0.05, 0.0)), "Head", False)

    for side, tag in [(-1.0, "R"), (1.0, "L")]:
        add_bone(f"UpperArm_{tag}", (side * 0.120, 0.0, 0.565),   (side * 0.232, 0.005, 0.478), "Spine", False)
        add_bone(f"Forearm_{tag}",  (side * 0.232, 0.005, 0.478), (side * 0.320, -0.018, 0.400), f"UpperArm_{tag}", True)
        add_bone(f"Hand_{tag}",     (side * 0.320, -0.018, 0.400),(side * 0.365, -0.028, 0.368), f"Forearm_{tag}", True)

        hx = side * 0.096
        add_bone(f"Thigh_{tag}", (hx, 0.0, 0.35),           (hx * 1.04, -0.006, 0.19), "Pelvis", False)
        add_bone(f"Shin_{tag}",  (hx * 1.04, -0.006, 0.19), (hx * 1.05, 0.006, 0.065), f"Thigh_{tag}", True)
        add_bone(f"Foot_{tag}",  (hx * 1.05, 0.006, 0.065), (hx * 1.05, -0.088, 0.048), f"Shin_{tag}", True)

    bpy.ops.object.mode_set(mode="OBJECT")

    non_body_bones = ["Root"] + list(ray_bone_transforms.keys()) + list(eyelid_pivots.keys())
    for nb in non_body_bones:
        arm_data.bones[nb].use_deform = False

    bpy.ops.object.select_all(action="DESELECT")
    body_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    for nb in non_body_bones:
        arm_data.bones[nb].use_deform = True

    part_objs = []
    for obj, target_bone in parts:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if not obj.data.color_attributes:
            obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
            ca = obj.data.color_attributes["Col"]
            for i in range(len(ca.data)):
                ca.data[i].color = (1.0, 1.0, 1.0, 1.0)
        vg = obj.vertex_groups.new(name=target_bone)
        vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
        part_objs.append(obj)

    bpy.ops.object.select_all(action="DESELECT")
    body_obj.select_set(True)
    for po in part_objs:
        po.select_set(True)
    bpy.context.view_layer.objects.active = body_obj
    bpy.ops.object.join()
    body_obj.name = "SoulMesh"
    body_obj.data.validate()

    return arm_obj, body_obj


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def start_action(arm_obj, name):
    reset_pose(arm_obj)
    act = bpy.data.actions.new(name=name)
    arm_obj.animation_data.action = act
    if hasattr(arm_obj.animation_data, "action_suitable_slots") and arm_obj.animation_data.action_suitable_slots:
        arm_obj.animation_data.action_slot = arm_obj.animation_data.action_suitable_slots[0]
    return act


def push_nla(arm_obj, act, name, end_frame):
    if hasattr(arm_obj.animation_data, "action_suitable_slots") and arm_obj.animation_data.action_suitable_slots:
        arm_obj.animation_data.action_slot = arm_obj.animation_data.action_suitable_slots[0]
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.frame_end = end_frame
    if hasattr(strip, "action_slot") and act.slots:
        strip.action_slot = act.slots[0]
    track.mute = False


def author_all_animations(arm_obj):
    """
    Exact Right-Hand-Rule verification in Blender world (Character faces -Y, +Z Up, +X Left):
      - Rotation around +X (`pitch_x > 0`):
          +Z vector tips toward -Y (Head/Spine leans FORWARD!)
          -Z vector tips toward +Y (Leg swings BACKWARD / Knee bends BACKWARD!)
      - Rotation around +Y (`roll_y > 0`):
          +Z vector tips toward +X (Torso tilts LEFT!)
          +X arm (+X, 0, -dZ) rotates UPWARD when `roll_y < 0`!
          -X arm (-X, 0, -dZ) rotates UPWARD when `roll_y > 0`!
          Therefore: to RAISE arm (`side = +1` for L, `-1` for R): `roll_y = -side * lift_deg`!
      - Eyelid rotation around +X:
          Rest eyelid is tucked back at `-78°`. Adding `pitch_x = +78°` sweeps it DOWN over front (-Y) to close!
    """
    bpy.context.scene.render.fps = 60
    arm_obj.animation_data_create()
    rest_mats = {b.name: b.matrix_local.copy() for b in arm_obj.data.bones}

    def key_world(bname, frame, pitch_x=0.0, roll_y=0.0, yaw_z=0.0, wx=0.0, wy=0.0, wz=0.0):
        pb = arm_obj.pose.bones[bname]
        pb.rotation_mode = "XYZ"
        rm = rest_mats[bname].to_3x3()
        w_rot = Euler((math.radians(pitch_x), math.radians(roll_y), math.radians(yaw_z)), "XYZ").to_matrix()
        loc_rot = rm.inverted() @ w_rot @ rm
        pb.rotation_euler = loc_rot.to_euler("XYZ")
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        if wx != 0.0 or wy != 0.0 or wz != 0.0 or bname == "Pelvis":
            pb.location = rm.inverted() @ Vector((wx, wy, wz))
            pb.keyframe_insert(data_path="location", frame=frame)

    ray_names = [f"Ray_{i}" for i in range(7)]

    # 1. RUN (Frames 1..43, 60fps = 0.70s bouncy athletic chibi sprint!)
    act_run = start_action(arm_obj, "Run")
    N_RUN = 43
    for f in range(1, N_RUN + 1):
        u = (f - 1) / (N_RUN - 1)
        ph = u * 2.0 * math.pi
        bob_z = -math.cos(2.0 * ph) * 0.045 + 0.015
        sway_x = math.sin(ph) * 0.025
        hip_yaw = math.sin(ph) * 14.0
        hip_roll = math.cos(ph) * 5.0

        key_world("Pelvis", f, pitch_x=10.0 + math.cos(2.0 * ph) * 2.5, roll_y=hip_roll, yaw_z=hip_yaw, wx=sway_x, wy=0.0, wz=bob_z)
        key_world("Spine",  f, pitch_x=5.0 - math.cos(2.0 * ph) * 2.5, roll_y=-hip_roll * 0.65, yaw_z=-hip_yaw * 0.85)
        key_world("Head",   f, pitch_x=-9.0 + math.cos(2.0 * ph - 0.4) * 3.0, roll_y=math.sin(ph) * 5.2, yaw_z=-hip_yaw * 0.35)
        key_world("Eyelid_L", f, pitch_x=0.0)
        key_world("Eyelid_R", f, pitch_x=0.0)

        ray_bob = math.sin(2.0 * ph - 0.85) * 8.0
        for ri, rn in enumerate(ray_names):
            side_sign = -1.0 if ri in (1, 3, 5) else (1.0 if ri in (2, 4, 6) else 0.0)
            key_world(rn, f, pitch_x=-ray_bob, roll_y=side_sign * ray_bob * 0.55)

        for tag, lph, side in [("L", ph, 1.0), ("R", ph + math.pi, -1.0)]:
            s = math.sin(lph)
            c = math.cos(lph)
            thigh_pitch = -42.0 * s + 6.0
            knee_bend = 14.0 + 58.0 * max(0.0, -s) ** 0.85 + 22.0 * max(0.0, c)
            foot_pitch = -18.0 * s + (24.0 if s < -0.2 else -8.0)
            key_world(f"Thigh_{tag}", f, pitch_x=thigh_pitch, roll_y=-side * 2.0)
            key_world(f"Shin_{tag}",  f, pitch_x=knee_bend)
            key_world(f"Foot_{tag}",  f, pitch_x=foot_pitch)

        for tag, aph, side in [("L", ph + math.pi, 1.0), ("R", ph, -1.0)]:
            sa = math.sin(aph)
            arm_pitch = -38.0 * sa + 4.0
            # Slightly lower/lift arm dynamically: -side * lift raises arm!
            arm_roll = -side * (-8.0 + 8.0 * abs(sa))
            elb_pitch = -52.0 - 20.0 * max(0.0, sa)
            key_world(f"UpperArm_{tag}", f, pitch_x=arm_pitch, roll_y=arm_roll, yaw_z=-side * 12.0 * sa)
            key_world(f"Forearm_{tag}",  f, pitch_x=elb_pitch, yaw_z=side * (-16.0))
            key_world(f"Hand_{tag}",     f, pitch_x=-10.0 * sa)

    push_nla(arm_obj, act_run, "Run", N_RUN)

    # 2. HOVER IDLE (Frames 1..121, 2.0s Main Screen float + real 3D blink!)
    act_idle = start_action(arm_obj, "HoverIdle")
    N_IDLE = 121
    for f in range(1, N_IDLE + 1):
        u = (f - 1) / (N_IDLE - 1)
        ph = u * 2.0 * math.pi
        bob_z = math.sin(ph) * 0.052
        sway_x = math.sin(ph) * 0.022

        key_world("Pelvis", f, pitch_x=-5.0 + math.sin(ph) * 3.0, roll_y=math.sin(ph) * 4.5, yaw_z=math.cos(ph) * 6.5, wx=sway_x, wy=0.0, wz=bob_z)
        key_world("Spine",  f, pitch_x=-2.0 + math.cos(ph) * 2.5, roll_y=-math.sin(ph) * 2.5)
        key_world("Head",   f, pitch_x=3.0 + math.sin(ph - 0.5) * 4.0, roll_y=math.cos(ph) * 6.5, yaw_z=math.sin(ph) * 8.5)

        blink = math.sin(((f - 80) / 16.0) * math.pi) if 80 <= f <= 96 else 0.0
        key_world("Eyelid_L", f, pitch_x=96.0 * blink)
        key_world("Eyelid_R", f, pitch_x=96.0 * blink)

        for ri, rn in enumerate(ray_names):
            key_world(rn, f, pitch_x=math.sin(ph - ri * 0.4) * 4.5)

        for tag, lph, side in [("L", ph, 1.0), ("R", ph + math.pi, -1.0)]:
            k = math.sin(lph)
            key_world(f"Thigh_{tag}", f, pitch_x=-16.0 + 14.0 * k, roll_y=-side * 4.0)
            key_world(f"Shin_{tag}",  f, pitch_x=38.0 + 16.0 * max(0.0, -k))
            key_world(f"Foot_{tag}",  f, pitch_x=16.0)

        for tag, aph, side in [("L", ph, 1.0), ("R", ph + math.pi, -1.0)]:
            w = math.sin(aph)
            key_world(f"UpperArm_{tag}", f, pitch_x=-14.0 + 10.0 * w, roll_y=-side * (12.0 + 8.0 * w))
            key_world(f"Forearm_{tag}",  f, pitch_x=-30.0 + 10.0 * w, yaw_z=side * (-12.0))

    push_nla(arm_obj, act_idle, "HoverIdle", N_IDLE)

    # 3. JUMP START (Frames 1..15)
    act_js = start_action(arm_obj, "JumpStart")
    N_JS = 15
    for f in range(1, N_JS + 1):
        u = (f - 1) / (N_JS - 1)
        coil = math.sin(min(1.0, u / 0.35) * math.pi) if u < 0.35 else 0.0
        ext = max(0.0, (u - 0.25) / 0.75)
        key_world("Pelvis", f, pitch_x=14.0 * coil - 8.0 * ext, wz=-0.05 * coil + 0.04 * ext)
        key_world("Spine",  f, pitch_x=10.0 * coil - 10.0 * ext)
        key_world("Head",   f, pitch_x=-12.0 * ext)
        key_world("Eyelid_L", f, pitch_x=0.0)
        key_world("Eyelid_R", f, pitch_x=0.0)
        for tag, side in [("L", 1.0), ("R", -1.0)]:
            # -side * lift raises arms joyfully UP!
            lift = -12.0 * coil + 58.0 * ext
            key_world(f"UpperArm_{tag}", f, pitch_x=-22.0 * ext, roll_y=-side * lift)
            key_world(f"Forearm_{tag}",  f, pitch_x=-38.0 * (1.0 - 0.5 * ext))
        key_world("Thigh_L", f, pitch_x=-25.0 * coil - 42.0 * ext, roll_y=-4.0)
        key_world("Shin_L",  f, pitch_x=45.0 * coil + 28.0 * ext)
        key_world("Thigh_R", f, pitch_x=-25.0 * coil + 22.0 * ext, roll_y=4.0)
        key_world("Shin_R",  f, pitch_x=45.0 * coil + 54.0 * ext)
    push_nla(arm_obj, act_js, "JumpStart", N_JS)

    # 4. JUMP APEX (Frames 1..45 — Wide joyful star-leap with kicking feet!)
    act_ja = start_action(arm_obj, "JumpApex")
    N_JA = 45
    for f in range(1, N_JA + 1):
        u = (f - 1) / (N_JA - 1)
        ph = u * 2.0 * math.pi
        kick = math.sin(ph)
        key_world("Pelvis", f, pitch_x=-6.0 + 4.0 * math.cos(ph), roll_y=4.0 * kick, wz=0.02 * math.sin(ph))
        key_world("Spine",  f, pitch_x=-8.0 + 3.0 * math.sin(ph))
        key_world("Head",   f, pitch_x=-8.0, roll_y=5.0 * kick)
        key_world("Eyelid_L", f, pitch_x=0.0)
        key_world("Eyelid_R", f, pitch_x=0.0)
        for ri, rn in enumerate(ray_names):
            key_world(rn, f, pitch_x=8.0 + 5.0 * math.sin(ph + ri))
        for tag, side in [("L", 1.0), ("R", -1.0)]:
            # -side * 62 deg raises both arms wide & high into a joyful Star-Leap V!
            key_world(f"UpperArm_{tag}", f, pitch_x=-20.0 + 8.0 * math.sin(ph), roll_y=-side * (62.0 + 7.0 * math.cos(ph)))
            key_world(f"Forearm_{tag}",  f, pitch_x=-18.0)
        key_world("Thigh_L", f, pitch_x=-38.0 + 18.0 * kick, roll_y=-6.0)
        key_world("Shin_L",  f, pitch_x=34.0 + 14.0 * max(0.0, -kick))
        key_world("Foot_L",  f, pitch_x=12.0)
        key_world("Thigh_R", f, pitch_x=20.0 - 18.0 * kick, roll_y=6.0)
        key_world("Shin_R",  f, pitch_x=58.0 - 14.0 * max(0.0, kick))
        key_world("Foot_R",  f, pitch_x=22.0)
    push_nla(arm_obj, act_ja, "JumpApex", N_JA)

    # 5. JUMP LAND (Frames 1..16 — Cushioned knee squash!)
    act_jl = start_action(arm_obj, "JumpLand")
    N_JL = 16
    for f in range(1, N_JL + 1):
        u = (f - 1) / (N_JL - 1)
        dip = math.sin(u * math.pi)
        key_world("Pelvis", f, pitch_x=18.0 * dip + 8.0 * (1.0 - dip), wz=-0.085 * dip)
        key_world("Spine",  f, pitch_x=14.0 * dip + 4.0)
        key_world("Head",   f, pitch_x=-10.0 + 14.0 * dip)
        key_world("Eyelid_L", f, pitch_x=0.0)
        key_world("Eyelid_R", f, pitch_x=0.0)
        for ri, rn in enumerate(ray_names):
            key_world(rn, f, pitch_x=-14.0 * dip)
        for tag, side in [("L", 1.0), ("R", -1.0)]:
            key_world(f"UpperArm_{tag}", f, pitch_x=16.0 * dip, roll_y=-side * (24.0 * dip))
            key_world(f"Forearm_{tag}",  f, pitch_x=-42.0)
            key_world(f"Thigh_{tag}",    f, pitch_x=-34.0 * dip, roll_y=-side * 4.0)
            key_world(f"Shin_{tag}",     f, pitch_x=60.0 * dip)
            key_world(f"Foot_{tag}",     f, pitch_x=-22.0 * dip)
    push_nla(arm_obj, act_jl, "JumpLand", N_JL)

    # 6. SLIDE ROLL (Frames 1..37, 0.60s tight tucked parkour roll right above Z=0!)
    #    Notice: When upside-down (u ~ 0.5, spin = 180°), Head is ~0.52m below Pelvis!
    #    So lifting Pelvis slightly (`wz = +0.18 * sin(u*pi)`) keeps the rolling ball
    #    skimming RIGHT ON TOP OF THE STONE FLOOR (Z ~ 0.05..0.65m), never underground!
    act_sl = start_action(arm_obj, "SlideRoll")
    N_SL = 37
    for f in range(1, N_SL + 1):
        u = (f - 1) / (N_SL - 1)
        s_u = u * u * (3.0 - 2.0 * u)
        spin_deg = s_u * 360.0
        tuck = math.sin(u * math.pi)
        # Keep rolling ball center at Z ~ 0.46m so lowest crown tip kisses Z ~ 0.03m!
        wz_roll = 0.34 * (math.sin(s_u * math.pi) ** 1.1) - 0.02 * tuck
        key_world("Pelvis", f, pitch_x=spin_deg, wz=wz_roll)
        key_world("Spine",  f, pitch_x=38.0 * tuck)
        key_world("Head",   f, pitch_x=32.0 * tuck)
        key_world("Eyelid_L", f, pitch_x=96.0 * tuck)
        key_world("Eyelid_R", f, pitch_x=96.0 * tuck)
        for tag, side in [("L", 1.0), ("R", -1.0)]:
            key_world(f"UpperArm_{tag}", f, pitch_x=-58.0 * tuck, roll_y=-side * (15.0 * tuck))
            key_world(f"Forearm_{tag}",  f, pitch_x=-76.0 * tuck)
            key_world(f"Thigh_{tag}",    f, pitch_x=-75.0 * tuck, roll_y=-side * 4.0)
            key_world(f"Shin_{tag}",     f, pitch_x=96.0 * tuck)
            key_world(f"Foot_{tag}",     f, pitch_x=28.0 * tuck)
    push_nla(arm_obj, act_sl, "SlideRoll", N_SL)

    # 7. STUMBLE (Frames 1..25)
    act_st = start_action(arm_obj, "Stumble")
    N_ST = 25
    for f in range(1, N_ST + 1):
        u = (f - 1) / (N_ST - 1)
        wob = math.sin(u * math.pi * 2.0) * (1.0 - u)
        imp = math.sin(u * math.pi)
        key_world("Pelvis", f, pitch_x=-14.0 * imp, roll_y=12.0 * wob, wz=-0.04 * imp)
        key_world("Spine",  f, pitch_x=-14.0 * imp, roll_y=-14.0 * wob, yaw_z=18.0 * wob)
        key_world("Head",   f, pitch_x=10.0 * imp, yaw_z=-22.0 * wob)
        key_world("Eyelid_L", f, pitch_x=65.0 * imp)
        key_world("Eyelid_R", f, pitch_x=65.0 * imp)
        for tag, side in [("L", 1.0), ("R", -1.0)]:
            key_world(f"UpperArm_{tag}", f, pitch_x=-25.0 * imp, roll_y=-side * (52.0 * imp))
            key_world(f"Forearm_{tag}",  f, pitch_x=-25.0)
    push_nla(arm_obj, act_st, "Stumble", N_ST)

    arm_obj.animation_data.action = None


def render_evaluated_verification_sheet(arm_obj, mesh_obj, out_png):
    poses = [
        ("1. Front Open Eyes (HoverIdle)", "HoverIdle", 20,  0.0),
        ("2. Front Cute Blink (HoverIdle)", "HoverIdle", 88, 18.0),
        ("3. 3/4 Sprint (Run f=11)",       "Run",       11, 42.0),
        ("4. Chase Back (Run f=11)",       "Run",       11, 180.0),
        ("5. Joyful Star Leap (JumpApex)", "JumpApex",  12, 172.0),
        ("6. Parkour Roll (SlideRoll)",    "SlideRoll", 14, 135.0),
    ]

    W, H = 380, 420
    sheet = Image.new("RGBA", (W * 3 + 24, H * 2 + 24), (20, 14, 34, 255))
    draw = ImageDraw.Draw(sheet)
    tracks = {t.name: t for t in arm_obj.animation_data.nla_tracks}

    mat_palette = {
        "Mat_SoulBody":  np.array([255.0, 178.0, 62.0]),
        "Mat_CrownGold": np.array([255.0, 204.0, 74.0]),
        "Mat_EyeWhite":  np.array([252.0, 250.0, 246.0]),
        "Mat_EyeIris":   np.array([122.0, 52.0, 18.0]),
        "Mat_EyePupil":  np.array([22.0, 9.0, 5.0]),
        "Mat_Sparkle":   np.array([255.0, 255.0, 255.0]),
        "Mat_Brow":      np.array([132.0, 48.0, 18.0]),
        "Mat_Nose":      np.array([255.0, 146.0, 82.0]),
        "Mat_Smile":     np.array([218.0, 68.0, 54.0]),
    }

    for idx, (label, clip_name, frame_no, yaw_deg) in enumerate(poses):
        for tn, tr in tracks.items():
            tr.mute = (tn != clip_name)
        bpy.context.scene.frame_set(frame_no)
        deps = bpy.context.evaluated_depsgraph_get()
        eval_obj = mesh_obj.evaluated_get(deps)
        emesh = eval_obj.to_mesh()
        emesh.calc_loop_triangles()

        verts = np.array([eval_obj.matrix_world @ v.co for v in emesh.vertices], dtype=np.float32)
        norms = np.array([v.normal for v in emesh.vertices], dtype=np.float32)

        rad = math.radians(yaw_deg)
        ca, sa = math.cos(rad), math.sin(rad)
        rx = verts[:, 0] * ca - verts[:, 1] * sa
        ry = verts[:, 0] * sa + verts[:, 1] * ca
        rz = verts[:, 2]
        nx = norms[:, 0] * ca - norms[:, 1] * sa
        ny = norms[:, 0] * sa + norms[:, 1] * ca
        nz = norms[:, 2]

        cy_cam = ry + 2.35
        scale = 365.0 / np.maximum(0.4, cy_cam)
        sx = W * 0.5 + rx * scale
        sz = H * 0.58 - (rz - 0.66) * scale

        zbuf = np.full((H, W), 1e9, dtype=np.float32)
        cbuf = np.zeros((H, W, 3), dtype=np.uint8)
        cbuf[:, :] = (28, 20, 46)
        # Draw subtle floor reference line at Z = 0.0!
        floor_y = int(H * 0.58 - (0.0 - 0.66) * (365.0 / 2.35))
        if 0 <= floor_y < H:
            cbuf[floor_y:min(H, floor_y + 2), 40:W - 40] = (72, 54, 110)

        col_attr = emesh.color_attributes.get("Col")
        mat_names = [m.name if m else "Mat_SoulBody" for m in emesh.materials]
        light_dir = np.array([0.42, -0.72, 0.55], dtype=np.float32)
        light_dir /= np.linalg.norm(light_dir)

        for tri in emesh.loop_triangles:
            vi = tri.vertices
            p0 = (sx[vi[0]], sz[vi[0]], cy_cam[vi[0]])
            p1 = (sx[vi[1]], sz[vi[1]], cy_cam[vi[1]])
            p2 = (sx[vi[2]], sz[vi[2]], cy_cam[vi[2]])

            xmin = max(0, int(min(p0[0], p1[0], p2[0])))
            xmax = min(W - 1, int(max(p0[0], p1[0], p2[0])) + 1)
            ymin = max(0, int(min(p0[1], p1[1], p2[1])))
            ymax = min(H - 1, int(max(p0[1], p1[1], p2[1])) + 1)
            if xmin > xmax or ymin > ymax:
                continue

            denom = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
            if abs(denom) < 1e-4:
                continue

            mname = mat_names[tri.material_index] if tri.material_index < len(mat_names) else "Mat_SoulBody"
            base_c = mat_palette.get(mname, mat_palette["Mat_SoulBody"])
            if col_attr and mname in ("Mat_SoulBody", "Mat_CrownGold"):
                li = tri.loops[0]
                vc = col_attr.data[li].color
                base_c = np.array([vc[0] * 255.0, vc[1] * 255.0, vc[2] * 255.0])

            tnorm = np.array([
                (nx[vi[0]] + nx[vi[1]] + nx[vi[2]]) / 3.0,
                (ny[vi[0]] + ny[vi[1]] + ny[vi[2]]) / 3.0,
                (nz[vi[0]] + nz[vi[1]] + nz[vi[2]]) / 3.0,
            ])
            tnorm /= (np.linalg.norm(tnorm) + 1e-6)
            ndotl = float(np.dot(tnorm, light_dir))
            wrap = max(0.32, min(1.12, (ndotl + 0.45) / 1.35))
            rim = max(0.0, 1.0 - abs(tnorm[1])) ** 2.2 * 36.0
            lit_c = np.clip(base_c * wrap + rim, 0, 255).astype(np.uint8)

            ys_g, xs_g = np.mgrid[ymin:ymax + 1, xmin:xmax + 1]
            w0 = ((p1[1] - p2[1]) * (xs_g - p2[0]) + (p2[0] - p1[0]) * (ys_g - p2[1])) / denom
            w1 = ((p2[1] - p0[1]) * (xs_g - p2[0]) + (p0[0] - p2[0]) * (ys_g - p2[1])) / denom
            w2 = 1.0 - w0 - w1
            inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
            if not np.any(inside):
                continue
            z_pix = w0 * p0[2] + w1 * p1[2] + w2 * p2[2]
            sub_z = zbuf[ymin:ymax + 1, xmin:xmax + 1]
            closer = inside & (z_pix < sub_z)
            if np.any(closer):
                sub_z[closer] = z_pix[closer]
                sub_c = cbuf[ymin:ymax + 1, xmin:xmax + 1]
                sub_c[closer] = lit_c

        eval_obj.to_mesh_clear()
        tile = Image.fromarray(cbuf, "RGB").convert("RGBA")
        col_i = idx % 3
        row_i = idx // 3
        px, py = 6 + col_i * (W + 6), 6 + row_i * (H + 6)
        sheet.alpha_composite(tile, (px, py))
        draw.text((px + 10, py + 8), label, fill=(255, 232, 160, 255))

    for tr in tracks.values():
        tr.mute = False
    bpy.context.scene.frame_set(1)
    sheet.save(out_png)


def main():
    reset_scene()
    mats = {
        "body":    make_pbr_mat("Mat_SoulBody",  (1.0, 0.65, 0.20, 1.0), roughness=0.45, emission_rgb=(1.0, 0.42, 0.08), emission_strength=0.18, use_vertex_color=True),
        "crown":   make_pbr_mat("Mat_CrownGold", (1.0, 0.76, 0.24, 1.0), roughness=0.34, emission_rgb=(1.0, 0.56, 0.12), emission_strength=0.28, use_vertex_color=True),
        "sclera":  make_pbr_mat("Mat_EyeWhite",  (0.99, 0.98, 0.97, 1.0), roughness=0.12),
        "iris":    make_pbr_mat("Mat_EyeIris",   (0.42, 0.16, 0.04, 1.0), roughness=0.08, emission_rgb=(0.50, 0.22, 0.05), emission_strength=0.12),
        "pupil":   make_pbr_mat("Mat_EyePupil",  (0.04, 0.02, 0.01, 1.0), roughness=0.04),
        "sparkle": make_pbr_mat("Mat_Sparkle",   (1.0, 1.0, 1.0, 1.0), roughness=0.02, emission_rgb=(1.0, 1.0, 1.0), emission_strength=1.4),
        "brow":    make_pbr_mat("Mat_Brow",      (0.42, 0.14, 0.04, 1.0), roughness=0.42),
        "nose":    make_pbr_mat("Mat_Nose",      (1.0, 0.50, 0.24, 1.0), roughness=0.40),
        "smile":   make_pbr_mat("Mat_Smile",     (0.80, 0.20, 0.16, 1.0), roughness=0.35),
    }

    body_obj = build_seamless_chibi_body(mats["body"])
    parts, ray_transforms, eyelid_pivots = build_crown_and_face_parts(mats)
    arm_obj, mesh_obj = build_armature_and_skin(body_obj, parts, ray_transforms, eyelid_pivots)
    author_all_animations(arm_obj)

    os.makedirs("web3d/public/models", exist_ok=True)
    out_glb = "web3d/public/models/soul.glb"

    render_evaluated_verification_sheet(arm_obj, mesh_obj, "/tmp/blender_soul_sheet_v3.png")

    bpy.ops.export_scene.gltf(
        filepath=out_glb,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_attributes=True,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_frame_step=1,
    )
    print(f"Exported {out_glb}: {os.path.getsize(out_glb):,} bytes | tris={len(mesh_obj.data.polygons) * 2}")


if __name__ == "__main__":
    main()
