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





def ember_gradient(co, no, head_c):
    """
    Molten-sun ramp measured off the reference sheet:
        deep rust #6b2d18 -> ember #e65412 -> gold #ff9e2c -> cream #ffedb4
    """
    RUST = (0.40, 0.11, 0.06)
    EMBER = (0.96, 0.43, 0.11)
    GOLD = (1.00, 0.71, 0.24)
    CREAM = (1.00, 0.97, 0.86)

    tvert = max(0.0, min(1.0, (co.z - 0.02) / 1.30))

    d = Vector((co.x - head_c.x, co.y - head_c.y, co.z - head_c.z))
    d.x /= 0.50
    d.y /= 0.48
    d.z /= 0.44
    core = math.exp(-d.length_squared * 1.20)

    upf = max(0.0, float(no.z)) * 0.5 + max(0.0, 1.0 - abs(no.z)) * 0.16

    n = fbm3(float(co.x), float(co.y), float(co.z))

    heat = max(0.0, min(1.0, 0.34 * tvert + 0.64 * core + 0.22 * upf + 0.22 * (n - 0.5) + 0.14))

    def mix(a, b, t):
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)

    if heat < 0.46:
        c = mix(RUST, EMBER, heat / 0.46)
    elif heat < 0.78:
        c = mix(EMBER, GOLD, (heat - 0.46) / 0.32)
    else:
        c = mix(GOLD, CREAM, (heat - 0.78) / 0.22)
    return c


def fbm3(x, y, z):
    """Cheap smooth pseudo-noise in [0,1] for the ember crackle."""
    s = math.sin(x * 5.13 + y * 2.71 + z * 3.37)
    s += math.sin(x * 9.71 - y * 4.13 + z * 7.19) * 0.5
    s += math.sin(x * 17.31 + y * 11.73 - z * 13.11) * 0.25
    return (s / 1.75) * 0.5 + 0.5


def build_seamless_chibi_body(mat_body):
    """
    GOLDEN SUN SOUL — proportions measured off the owner's reference turnaround
    sheet (`tools/reference/golden-sun-character-turnaround.png`, 4 views).

    Measured from that sheet (figure = feet -> top of head = 100%):
        head height ......... 53.6 %     head width ..... 62.8 % of height
        head is WIDER than tall ........ w/h = 1.17  (a big round sun-ball)
        head width vs chest width ...... ~2.3 x
        silhouette pinch at 46-53 % .... head bottom pole sits straight on
                                         the shoulders -> NO visible neck
        eyes ......... 63 % down the head, spaced 0.35 x head width
        eye size ..... 0.20 x head width, 0.16 x head height
        palette ...... cream core #fefbe3 -> gold #fbab34 / #f38c1f
                       -> orange #d86a19 -> deep rust #a54827 / #5c2c36
        colour families ..... orange-gold 43.6 %, red-orange 31.1 %,
                              red 14.9 %, gold-yellow 5.5 %

    Mapped onto a 1.365 m figure (Blender: -Y = front, +Z = up, soles at Z=0):
        legs ...... Z 0.000 .. 0.200
        pelvis .... Z 0.200 .. 0.360
        chest ..... Z 0.360 .. 0.640   (shoulders tuck into the head base)
        head ...... Z 0.634 .. 1.366   (centre Z = 1.000, 0.85 wide x 0.73 tall)
        crown ..... thin tapered flame-ray tips reach Z ~ 1.52
    """
    mb_data = bpy.data.metaballs.new("SoulMeta")
    mb_data.resolution = 0.017
    mb_data.threshold = 0.60
    mb_obj = bpy.data.objects.new("SoulMetaObj", mb_data)
    bpy.context.collection.objects.link(mb_obj)

    # 1. Compact pear-shaped tummy that flares straight into the shoulders.
    el_pel = mb_data.elements.new(type="ELLIPSOID")
    el_pel.co = (0.0, 0.010, 0.270)
    el_pel.size_x, el_pel.size_y, el_pel.size_z = 0.420, 0.385, 0.295
    el_pel.radius = 1.0

    el_tum = mb_data.elements.new(type="ELLIPSOID")
    el_tum.co = (0.0, -0.014, 0.345)
    el_tum.size_x, el_tum.size_y, el_tum.size_z = 0.410, 0.375, 0.285
    el_tum.radius = 1.0

    el_che = mb_data.elements.new(type="ELLIPSOID")
    el_che.co = (0.0, 0.000, 0.495)
    el_che.size_x, el_che.size_y, el_che.size_z = 0.370, 0.340, 0.265
    el_che.radius = 1.0

    # Shoulder yoke rising into the head base: no neck gap, exactly like the sheet.
    add_meta_capsule(mb_data, 0.0, 0.0, 0.500, 0.0, 0.006, 0.700, 0.106, 0.098, steps=5)

    # 2. THE GIANT MOLTEN SUN HEAD (53.6 % of the figure, wider than it is tall!)
    el_head = mb_data.elements.new(type="ELLIPSOID")
    el_head.co = (0.0, 0.012, 1.030)
    el_head.size_x, el_head.size_y, el_head.size_z = 0.740, 0.800, 0.600
    el_head.radius = 1.0

    # Chubby cheek lobes low & forward so the big ball still reads as a face.
    for side in (-1.0, 1.0):
        el_chk = mb_data.elements.new(type="ELLIPSOID")
        el_chk.co = (side * 0.156, -0.140, 0.910)
        el_chk.size_x, el_chk.size_y, el_chk.size_z = 0.313, 0.294, 0.276
        el_chk.radius = 1.0

    # 3. Stubby little legs & upturned boots (X = +-0.082)
    for side in (-1.0, 1.0):
        hx = side * 0.078
        add_meta_capsule(mb_data, hx, 0.0, 0.215, hx * 1.05, -0.006, 0.115, 0.068, 0.058, steps=6)
        add_meta_capsule(mb_data, hx * 1.05, -0.006, 0.115, hx * 1.08, 0.006, 0.040, 0.056, 0.048, steps=6)
        add_meta_capsule(mb_data, hx * 1.08, 0.020, 0.036, hx * 1.08, -0.078, 0.032, 0.050, 0.044, steps=5)

    # 4. Short arms held out in a friendly A-pose, cute mitten paws
    for side in (-1.0, 1.0):
        add_meta_capsule(mb_data, side * 0.112, 0.0, 0.550, side * 0.205, 0.006, 0.495, 0.058, 0.052, steps=6)
        add_meta_capsule(mb_data, side * 0.205, 0.006, 0.495, side * 0.280, -0.016, 0.430, 0.050, 0.054, steps=6)
        el_paw = mb_data.elements.new(type="ELLIPSOID")
        el_paw.co = (side * 0.312, -0.026, 0.416)
        el_paw.size_x, el_paw.size_y, el_paw.size_z = 0.140, 0.130, 0.122
        el_paw.radius = 1.0
        el_th = mb_data.elements.new(type="BALL")
        el_th.co = (side * 0.290, -0.062, 0.432)
        el_th.radius = 0.040

    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = mb_obj
    mb_obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    body_obj = bpy.context.active_object
    body_obj.name = "SoulBody"

    sm = body_obj.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.50
    sm.iterations = 4
    bpy.ops.object.modifier_apply(modifier=sm.name)

    dec = body_obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = 0.50
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
    head_c = Vector((0.0, 0.012, 1.000))
    for poly in body_obj.data.polygons:
        for li in poly.loop_indices:
            v = verts[body_obj.data.loops[li].vertex_index]
            r, g, b = ember_gradient(v.co, v.normal, head_c)
            col_layer.data[li].color = (r, g, b, 1.0)

    body_obj.data.materials.append(mat_body)

    bx = [v.co.x for v in body_obj.data.vertices]
    bz = [v.co.z for v in body_obj.data.vertices]
    by = [v.co.y for v in body_obj.data.vertices]
    print("--- BODY-ONLY geometry (no rays/eyes) ---")
    print(f"  x range : {min(bx):+.3f} .. {max(bx):+.3f}   (symmetry check)")
    print(f"  y range : {min(by):+.3f} .. {max(by):+.3f}")
    print(f"  z range : {min(bz):+.3f} .. {max(bz):+.3f}")
    for lo, hi in [(0.90, 1.10), (0.95, 1.15), (1.00, 1.20), (0.75, 0.95)]:
        band = [x for x, z in zip(bx, bz) if lo < z < hi]
        if band:
            print(f"  head width z[{lo:.2f},{hi:.2f}] : {max(band)-min(band):.3f} m")
    torso = [x for x, z in zip(bx, bz) if 0.30 < z < 0.50]
    print(f"  torso width z[.30,.50] : {max(torso)-min(torso):.3f} m")
    arms = [x for x, z in zip(bx, bz) if z < 0.60]
    print(f"  arm/leg span z<0.60    : {max(arms)-min(arms):.3f} m")
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





def build_crown_and_face_parts(mats, body_obj):
    """
    Crown of thin tapered flame-rays + the molten ember face, all measured
    against the ACTUAL isosurface of `body_obj` so nothing floats or sinks.
    """
    parts = []
    head_c = Vector((0.0, 0.012, 1.000))

    def surface_along(direction, maxd=1.4, fallback_r=0.42):
        d = Vector(direction).normalized()
        try:
            hit, loc, _n, _i = body_obj.ray_cast(head_c, d, distance=maxd)
            if hit:
                return Vector(loc)
        except Exception:
            pass
        # analytic fallback on the head ellipsoid (radii incl. cheek swell)
        rx, ry, rz = 0.430, 0.412, 0.370
        k = math.sqrt((d.x / rx) ** 2 + (d.y / ry) ** 2 + (d.z / rz) ** 2)
        return head_c + d * (1.0 / max(1e-6, k))

    # 1. Seven hero flame-rays + six shorter staggered secondary tips.
    #    Thin & short (the sheet shows slim spikes, NOT a huge sunflower).
    # Angles measured off the sheet: the tips all live on the TOP hemisphere and
    # stay inside the head's own silhouette (head = 0.93 of the figure width).
    hero_specs = [
        ("Ray_0",    0.0,   0.112, 0.070, 0.045, 0.030),
        ("Ray_1",  -36.0,   0.105, 0.064, 0.042, 0.028),
        ("Ray_2",   36.0,   0.105, 0.064, 0.042, 0.028),
        ("Ray_3",  -68.0,   0.082, 0.056, 0.038, 0.024),
        ("Ray_4",   68.0,   0.082, 0.056, 0.038, 0.024),
        ("Ray_5", -100.0,   0.050, 0.048, 0.033, 0.020),
        ("Ray_6",  100.0,   0.050, 0.048, 0.033, 0.020),
    ]
    ray_bone_transforms = {}
    for bname, deg, L, W0, D0, y_off in hero_specs:
        rad = math.radians(deg)
        dir_v = Vector((math.sin(rad), 0.085, math.cos(rad) + (1.0 - math.cos(rad)) * 0.06)).normalized()
        base_pos = surface_along(dir_v) - dir_v * 0.030
        base_pos.y += y_off
        mesh = make_faceted_sun_ray_mesh(bname + "_Mesh", L, W0, D0, 0.020, 0.018)
        mesh.materials.append(mats["crown"])
        obj = bpy.data.objects.new(bname + "_Obj", mesh)
        bpy.context.collection.objects.link(obj)
        rot_q = Vector((0, 0, 1)).rotation_difference(dir_v)
        obj.matrix_world = Matrix.Translation(base_pos) @ rot_q.to_matrix().to_4x4()
        parts.append((obj, bname))
        ray_bone_transforms[bname] = (base_pos, base_pos + dir_v * L)

    sec_specs = [
        (-18.0, 0.080, 0.048, 0.032),
        ( 18.0, 0.080, 0.048, 0.032),
        (-52.0, 0.068, 0.044, 0.030),
        ( 52.0, 0.068, 0.044, 0.030),
        (-86.0, 0.048, 0.038, 0.027),
        ( 86.0, 0.048, 0.038, 0.027),
    ]
    for idx, (deg, L, W0, D0) in enumerate(sec_specs):
        rad = math.radians(deg)
        dir_v = Vector((math.sin(rad) * 0.96, 0.20, math.cos(rad) * 0.96)).normalized()
        base_pos = surface_along(dir_v) - dir_v * 0.024
        mesh = make_faceted_sun_ray_mesh(f"SecRay_{idx}", L, W0, D0, 0.0, 0.016)
        mesh.materials.append(mats["crown"])
        obj = bpy.data.objects.new(f"SecRayObj_{idx}", mesh)
        bpy.context.collection.objects.link(obj)
        rot_q = Vector((0, 0, 1)).rotation_difference(dir_v)
        obj.matrix_world = Matrix.Translation(base_pos) @ rot_q.to_matrix().to_4x4()
        parts.append((obj, "Head"))

    # 1b. White-hot crown core where the rays converge (the "heart" of the sun)
    crown_top = surface_along(Vector((0.0, 0.10, 1.0)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=26, ring_count=18, radius=0.112,
                                         location=(0.0, crown_top.y * 0.35, crown_top.z - 0.048))
    core = bpy.context.active_object
    core.scale = (1.05, 0.98, 0.70)
    bpy.ops.object.transform_apply(scale=True)
    for p in core.data.polygons:
        p.use_smooth = True
    core.data.materials.append(mats["core"])
    parts.append((core, "Head"))

    # 2. BIG molten ember eyes: dark glowing cavity + white-hot inner glint.
    #    Measured off the sheet: 63 % down the head, spaced 0.35 x head width.
    def front_surface(x, z, radius=0.085, fallback=None):
        best = None
        for v in body_obj.data.vertices:
            co = v.co
            if (co.x - x) ** 2 + (co.z - z) ** 2 > radius * radius:
                continue
            if best is None or co.y < best:
                best = co.y
        if best is None:
            best = fallback if fallback is not None else -0.36
        return best

    eyelid_pivots = {}
    eye_z = 0.930
    for side, s_tag in [(-1.0, "R"), (1.0, "L")]:
        ex = side * 0.158
        ez = eye_z
        sy = front_surface(ex, ez)
        ey = sy + 0.019          # lens centre: front face sits just proud of the skin
        eyelid_pivots[f"Eyelid_{s_tag}"] = Vector((ex, ey + 0.006, ez))

        # Dark smouldering eye cavity (0.20 x head width, 0.16 x head height!)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, radius=0.080,
                                             location=(ex, ey, ez))
        sock = bpy.context.active_object
        sock.scale = (1.05, 0.34, 0.72)
        sock.rotation_euler = Euler((0.0, 0.0, side * math.radians(-15.0)), "XYZ")
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for p in sock.data.polygons:
            p.use_smooth = True
        sock.data.materials.append(mats["socket"])
        parts.append((sock, "Head"))

        # White-hot ember glint burning inside the cavity
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=14, radius=0.038,
                                             location=(ex * 0.97, ey - 0.030, ez + 0.006))
        gl = bpy.context.active_object
        gl.scale = (1.00, 0.32, 0.86)
        gl.rotation_euler = Euler((0.0, 0.0, side * math.radians(-15.0)), "XYZ")
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for p in gl.data.polygons:
            p.use_smooth = True
        gl.data.materials.append(mats["glint"])
        parts.append((gl, "Head"))

        # Tiny secondary catchlight so the eye always reads as alive
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.011,
                                             location=(ex - side * 0.030, ey - 0.036, ez + 0.026))
        sp1 = bpy.context.active_object
        for p in sp1.data.polygons:
            p.use_smooth = True
        sp1.data.materials.append(mats["sparkle"])
        parts.append((sp1, "Head"))

        # Animated upper eyelid shell (rests tucked back, +96 deg sweeps it shut)
        bm_lid = bmesh.new()
        bmesh.ops.create_uvsphere(bm_lid, u_segments=24, v_segments=15, radius=0.082)
        for v in list(bm_lid.verts):
            if v.co.z < -0.012:
                bm_lid.verts.remove(v)
            else:
                v.co.x *= 1.10
                v.co.y *= 0.56
                v.co.z *= 1.30
        bmesh.ops.recalc_face_normals(bm_lid, faces=bm_lid.faces)
        lid_mesh = bpy.data.meshes.new(f"EyelidMesh_{s_tag}")
        bm_lid.to_mesh(lid_mesh)
        bm_lid.free()
        for p in lid_mesh.polygons:
            p.use_smooth = True
        lid_mesh.materials.append(mats["lid"])
        lid_obj = bpy.data.objects.new(f"EyelidObj_{s_tag}", lid_mesh)
        bpy.context.collection.objects.link(lid_obj)
        lid_obj.location = (ex, ey + 0.006, ez)
        lid_obj.rotation_euler = Euler((math.radians(-88.0), 0.0, side * math.radians(-15.0)), "XYZ")
        parts.append((lid_obj, f"Eyelid_{s_tag}"))

    # 3. Warm little molten smile tucked between the cheeks
    sm_z = 0.848
    sm_y = front_surface(0.0, sm_z, radius=0.07) + 0.012
    sm_pts = []
    sm_rads = []
    for si in range(9):
        su = (si / 8.0) * 2.0 - 1.0
        sx = su * 0.062
        sz = sm_z + (su * su) * 0.026
        sy = sm_y + (su * su) * 0.020
        sm_pts.append((sx, sy, sz))
        sm_rads.append(0.005 + 0.012 * math.sin((si / 8.0) * math.pi))
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

    add_bone("Root",   (0.0, 0.0, 0.0),     (0.0, 0.0, 0.16))
    add_bone("Pelvis", (0.0, 0.006, 0.28), (0.0, 0.006, 0.42), "Root")
    add_bone("Spine",  (0.0, 0.006, 0.42), (0.0, 0.006, 0.56), "Pelvis", True)
    add_bone("Neck",   (0.0, 0.006, 0.56), (0.0, 0.010, 0.66), "Spine", True)
    add_bone("Head",   (0.0, 0.010, 0.66), (0.0, 0.012, 1.36), "Neck", True)

    for bname, (bh, bt) in ray_bone_transforms.items():
        add_bone(bname, bh, bt, "Head", False)

    for bname, piv in eyelid_pivots.items():
        add_bone(bname, piv, piv + Vector((0.0, -0.05, 0.0)), "Head", False)

    for side, tag in [(-1.0, "R"), (1.0, "L")]:
        add_bone(f"UpperArm_{tag}", (side * 0.112, 0.0, 0.550),   (side * 0.205, 0.006, 0.495), "Spine", False)
        add_bone(f"Forearm_{tag}",  (side * 0.205, 0.006, 0.495), (side * 0.280, -0.016, 0.430), f"UpperArm_{tag}", True)
        add_bone(f"Hand_{tag}",     (side * 0.280, -0.016, 0.430),(side * 0.324, -0.028, 0.398), f"Forearm_{tag}", True)

        hx = side * 0.078
        add_bone(f"Thigh_{tag}", (hx, 0.0, 0.215),          (hx * 1.05, -0.006, 0.115), "Pelvis", False)
        add_bone(f"Shin_{tag}",  (hx * 1.05, -0.006, 0.115), (hx * 1.08, 0.006, 0.040), f"Thigh_{tag}", True)
        add_bone(f"Foot_{tag}",  (hx * 1.08, 0.006, 0.040), (hx * 1.08, -0.075, 0.030), f"Shin_{tag}", True)

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
        "Mat_SoulBody":  np.array([255.0, 178.0, 62.0]),   # vertex colours override
        "Mat_CrownGold": np.array([255.0, 204.0, 74.0]),
        "Mat_SoulCore":  np.array([255.0, 240.0, 189.0]),
        "Mat_EyeSocket": np.array([43.0, 19.0, 14.0]),
        "Mat_EyeGlint":  np.array([255.0, 250.0, 230.0]),
        "Mat_Eyelid":    np.array([245.0, 135.0, 41.0]),
        "Mat_Sparkle":   np.array([255.0, 255.0, 255.0]),
        "Mat_Smile":     np.array([140.0, 36.0, 15.0]),
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


def render_turnaround_sheet(arm_obj, mesh_obj, out_png):
    """
    Orthographic 4-view turnaround of the Soul on the same dark studio backdrop
    as the owner's reference sheet, so both can be measured with one script.
    Views: front (0 deg) | right side (90) | back (180) | left side (270).
    """
    MAT_PALETTE = {
        "Mat_SoulBody":  np.array([255.0, 178.0, 62.0]),   # vertex colours override
        "Mat_CrownGold": np.array([255.0, 204.0, 74.0]),
        "Mat_SoulCore":  np.array([255.0, 240.0, 189.0]),
        "Mat_EyeSocket": np.array([43.0, 19.0, 14.0]),
        "Mat_EyeGlint":  np.array([255.0, 250.0, 230.0]),
        "Mat_Eyelid":    np.array([245.0, 135.0, 41.0]),
        "Mat_Sparkle":   np.array([255.0, 255.0, 255.0]),
        "Mat_Smile":     np.array([140.0, 36.0, 15.0]),
    }

    W, H = 384, 420
    sheet = Image.new("RGBA", (W * 4 + 30, H + 12), (14, 14, 36, 255))
    tracks = {t.name: t for t in arm_obj.animation_data.nla_tracks}
    for tr in tracks.values():
        tr.mute = True          # rest pose: a turnaround sheet documents the design
    # Muting the NLA is not enough -- the last authored action is still bound to
    # animation_data.action and would pose the rig. Unbind it for a true rest pose.
    arm_obj.animation_data.action = None
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()

    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = mesh_obj.evaluated_get(deps)
    emesh = eval_obj.to_mesh()
    emesh.calc_loop_triangles()

    verts = np.array([eval_obj.matrix_world @ v.co for v in emesh.vertices], dtype=np.float32)
    norms = np.array([v.normal for v in emesh.vertices], dtype=np.float32)
    col_attr = emesh.color_attributes.get("Col")
    mat_names = [m.name if m else "Mat_SoulBody" for m in emesh.materials]
    light_dir = np.array([0.42, -0.72, 0.55], dtype=np.float32)
    light_dir /= np.linalg.norm(light_dir)
    SCALE = 250.0

    for vi_idx, yaw_deg in enumerate([0.0, 90.0, 180.0, 270.0]):
        rad = math.radians(yaw_deg)
        ca, sa = math.cos(rad), math.sin(rad)
        rx = verts[:, 0] * ca - verts[:, 1] * sa
        ry = verts[:, 0] * sa + verts[:, 1] * ca
        rz = verts[:, 2]
        nx = norms[:, 0] * ca - norms[:, 1] * sa
        ny = norms[:, 0] * sa + norms[:, 1] * ca
        nz = norms[:, 2]

        cy_cam = ry + 6.0
        sx = W * 0.5 + rx * SCALE
        sz = H * 0.93 - rz * SCALE

        zbuf = np.full((H, W), 1e9, dtype=np.float32)
        cbuf = np.zeros((H, W, 3), dtype=np.uint8)
        cbuf[:, :] = (14, 14, 36)

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
            base_c = MAT_PALETTE.get(mname, MAT_PALETTE["Mat_SoulBody"])
            if col_attr and mname in ("Mat_SoulBody", "Mat_CrownGold"):
                vc = col_attr.data[tri.loops[0]].color
                base_c = np.array([vc[0] * 255.0, vc[1] * 255.0, vc[2] * 255.0])

            tnorm = np.array([(nx[vi[0]] + nx[vi[1]] + nx[vi[2]]) / 3.0,
                              (ny[vi[0]] + ny[vi[1]] + ny[vi[2]]) / 3.0,
                              (nz[vi[0]] + nz[vi[1]] + nz[vi[2]]) / 3.0])
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
                cbuf[ymin:ymax + 1, xmin:xmax + 1][closer] = lit_c

        tile = Image.fromarray(cbuf, "RGB").convert("RGBA")
        px = 6 + vi_idx * (W + 6)
        # NOTE: no on-tile label -- it would land inside the analysed crop and
        # corrupt the silhouette metrics (it did, once).
        sheet.alpha_composite(tile, (px, 6))

    eval_obj.to_mesh_clear()
    for tr in tracks.values():
        tr.mute = False
    bpy.context.scene.frame_set(1)
    sheet.save(out_png)
    print(f"turnaround -> {out_png}")


def _hex(h):
    """'#1d113a' -> linear-ish (r,g,b,1) float tuple."""
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    def srgb_to_linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


def _build_dusk_world(scene):
    """Dusk Hollow sky: #1d113a zenith / #6b3878 mid / #ffb876 horizon."""
    world = bpy.data.worlds.new("World_DuskHollow")
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)

    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    geo = nt.nodes.new("ShaderNodeNewGeometry")

    nt.links.new(geo.outputs["Incoming"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])

    el = ramp.color_ramp.elements
    el[0].position = 0.0
    el[0].color = _hex("#2c1842")          # straight down: ground bounce
    e = el.new(0.50); e.color = _hex("#ffb876")   # horizon: warm dusk
    e = el.new(0.60); e.color = _hex("#6b3878")   # mid sky
    e = el.new(1.00); e.color = _hex("#1d113a")   # zenith
    ramp.color_ramp.interpolation = "EASE"
    scene.world = world


def _crystal_mesh(name, height, radius):
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=radius, depth=height, location=(0, 0, 0)
    )
    ob = bpy.context.object
    ob.name = name
    return ob


def render_hero_shot(arm_obj, mesh_obj, out_png, biome="dusk_hollow", preview=False):
    """
    Cycles render of the Soul posed in his run cycle, standing on the Dusk
    Hollow causeway under the biome's real sky/fog/light palette -- the shot
    the player actually sees from the low behind-character chase camera.
    Runs AFTER the glTF export so none of this scenery pollutes the .glb.
    """
    sc = bpy.context.scene
    _build_dusk_world(sc)

    # ---------------------------------------------------------------- ground
    bpy.ops.mesh.primitive_plane_add(size=260.0, location=(0, 60.0, 0.0))
    ground = bpy.context.object
    ground.name = "Hero_Ground"
    gmat = bpy.data.materials.new("Mat_HeroStone")
    gmat.use_nodes = True
    nt = gmat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    brick = nt.nodes.new("ShaderNodeTexBrick")
    vcoord = nt.nodes.new("ShaderNodeTexCoord")
    emit = nt.nodes.new("ShaderNodeEmission")
    mixsh = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes["Material Output"]
    brick.inputs["Scale"].default_value = 5.0
    brick.inputs["Mortar Size"].default_value = 0.035
    nt.links.new(vcoord.outputs["Generated"], brick.inputs["Vector"])
    nt.links.new(brick.outputs["Fac"], mixsh.inputs["Fac"])
    bsdf.inputs["Base Color"].default_value = _hex("#473966")
    bsdf.inputs["Roughness"].default_value = 0.85
    emit.inputs["Color"].default_value = _hex("#ffd178")
    emit.inputs["Strength"].default_value = 0.9
    nt.links.new(bsdf.outputs[0], mixsh.inputs[1])
    nt.links.new(emit.outputs[0], mixsh.inputs[2])
    nt.links.new(mixsh.outputs[0], out.inputs["Surface"])
    ground.data.materials.append(gmat)

    # ------------------------------------------------------------ causeway
    bpy.ops.mesh.primitive_plane_add(size=260.0, location=(0, 60.0, 0.01))
    path = bpy.context.object
    path.name = "Hero_Causeway"
    path.scale = (0.055, 1.0, 1.0)
    pmat = bpy.data.materials.new("Mat_HeroPath")
    pmat.use_nodes = True
    bsdf = pmat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = _hex("#69588c")
    bsdf.inputs["Roughness"].default_value = 0.72
    path.data.materials.append(pmat)

    # ---------------------------------------------------------------- crystals
    cry_mat = bpy.data.materials.new("Mat_HeroCrystal")
    cry_mat.use_nodes = True
    cbsdf = cry_mat.node_tree.nodes["Principled BSDF"]
    cbsdf.inputs["Base Color"].default_value = _hex("#b95cff")
    cbsdf.inputs["Emission Color"].default_value = _hex("#7b26d9")
    cbsdf.inputs["Emission Strength"].default_value = 1.6
    cbsdf.inputs["Roughness"].default_value = 0.12
    cbsdf.inputs["Transmission Weight"].default_value = 0.55
    cbsdf.inputs["IOR"].default_value = 1.6

    import random as _rnd
    rng = _rnd.Random(20251016)
    for i in range(26):
        side = -1 if i % 2 == 0 else 1
        lane = rng.choice([1.05, 1.35, 1.7, 2.1, 2.6])
        h = rng.uniform(1.1, 3.4)
        cr = _crystal_mesh(f"Hero_Crystal_{i}", h, h * rng.uniform(0.13, 0.24))
        cr.location = (side * lane, rng.uniform(1.5, 48.0), h * 0.5)
        cr.rotation_euler = (
            rng.uniform(-0.14, 0.14), rng.uniform(-0.14, 0.14), rng.uniform(0.0, 3.14)
        )
        cr.data.materials.append(cry_mat)

    # ----------------------------------------------------------- distant peaks
    for i, (dist, hh, col) in enumerate([
        (95.0, 34.0, "#533173"), (140.0, 52.0, "#341f52"), (185.0, 70.0, "#2a1845"),
    ]):
        bpy.ops.mesh.primitive_cone_add(
            vertices=7, radius1=hh * 0.85, depth=hh,
            location=(rng.uniform(-70, 70), dist, hh * 0.32),
        )
        mt = bpy.context.object
        mt.name = f"Hero_Peak_{i}"
        mmat = bpy.data.materials.new(f"Mat_HeroPeak_{i}")
        mmat.use_nodes = True
        mbsdf = mmat.node_tree.nodes["Principled BSDF"]
        mbsdf.inputs["Base Color"].default_value = _hex(col)
        mbsdf.inputs["Roughness"].default_value = 1.0
        mt.data.materials.append(mmat)

    # ------------------------------------------------------------- dusk sun
    bpy.ops.mesh.primitive_uv_sphere_add(radius=6.0, location=(-19.0, 155.0, 11.0))
    sun_disc = bpy.context.object
    sun_disc.name = "Hero_SunDisc"
    smat = bpy.data.materials.new("Mat_HeroSun")
    smat.use_nodes = True
    semit = smat.node_tree.nodes.new("ShaderNodeEmission")
    souts = smat.node_tree.nodes["Material Output"]
    smat.node_tree.links.new(semit.outputs[0], souts.inputs["Surface"])
    semit.inputs["Color"].default_value = _hex("#ffe6a6")
    semit.inputs["Strength"].default_value = 8.0
    sun_disc.data.materials.append(smat)

    # ----------------------------------------------------------------- lights
    bpy.ops.object.light_add(type="SUN", location=(-14.0, 120.0, 26.0))
    sun = bpy.context.object
    sun.name = "Hero_Sun"
    sun.data.energy = 3.4
    sun.data.color = _hex("#ffd39b")[:3]
    sun.rotation_euler = (math.radians(72.0), 0.0, math.radians(-14.0))

    bpy.ops.object.light_add(type="AREA", location=(3.0, -3.0, 4.0))
    rim = bpy.context.object
    rim.name = "Hero_Rim"
    rim.data.energy = 220.0
    rim.data.size = 7.0
    rim.data.color = _hex("#a47ad6")[:3]
    rim.rotation_euler = (math.radians(38.0), 0.0, math.radians(150.0))

    # Soul's own molten glow spilling onto the stones around him
    bpy.ops.object.light_add(type="POINT", location=(0.0, 0.0, 0.95))
    aura = bpy.context.object
    aura.name = "Hero_Aura"
    aura.data.energy = 26.0
    aura.data.color = _hex("#ffb84d")[:3]
    aura.data.shadow_soft_size = 0.35

    # ----------------------------------------------------------------- camera
    cam_data = bpy.data.cameras.new("Hero_Cam")
    cam_data.lens = 32.0
    cam_data.clip_end = 600.0
    cam = bpy.data.objects.new("Hero_Cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    # Low, just behind and left of Soul -- the game's chase framing.
    cam.location = (-0.95, -4.30, 1.72)
    tgt = bpy.data.objects.new("Hero_CamTarget", None)
    sc.collection.objects.link(tgt)
    tgt.location = (0.0, 0.30, 0.95)
    tc = cam.constraints.new("TRACK_TO")
    tc.target = tgt
    tc.track_axis = "TRACK_NEGATIVE_Z"
    tc.up_axis = "UP_Y"

    # ------------------------------------------------------------------- pose
    tracks = {t.name: t for t in arm_obj.animation_data.nla_tracks}
    for tn, tr in tracks.items():
        tr.mute = (tn != "Run")
    sc.frame_set(11)
    bpy.context.view_layer.update()

    # ----------------------------------------------------------------- render
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 6 if preview else 96
    sc.cycles.use_denoising = not preview
    sc.cycles.denoiser = "OPENIMAGEDENOISE"
    sc.cycles.max_bounces = 8
    sc.cycles.diffuse_bounces = 3
    sc.cycles.glossy_bounces = 4
    sc.cycles.transmission_bounces = 6
    sc.render.resolution_x = 480 if preview else 1600
    sc.render.resolution_y = 270 if preview else 900
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Filmic"
    sc.view_settings.look = "Medium High Contrast"
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = out_png

    # NOTE: no compositor bloom here. Blender 5.0 removed CompositorNodeComposite,
    # so the glow pass is applied in `_post_bloom()` after the render instead.

    bpy.ops.render.render(write_still=True)
    if not preview:
        _post_bloom(out_png)
    print(f"hero shot -> {out_png}")


def _post_bloom(path, threshold=0.86, strength=0.45, radius=18.0):
    """
    Screen-space bloom so the ember body, crown rays and crystals glow the way
    they do under the WebGL renderer. Pure numpy -- Blender 5.0's compositor no
    longer exposes a composite output node.
    """
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255.0

    lum = a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    over = np.clip(lum - threshold, 0.0, None) / max(1e-5, 1.0 - threshold)
    bright = a * over[..., None]

    def box_blur(img, r):
        # O(n) separable box blur, three passes ~= Gaussian
        out = img
        for _ in range(3):
            k = max(1, int(r / 3))
            pad = k // 2
            tp = np.pad(out, ((pad, pad), (0, 0), (0, 0)), mode="edge")
            c = np.cumsum(tp, axis=0)
            out = (c[k:] - c[:-k]) / float(k)
            need = img.shape[0] - out.shape[0]
            if need > 0:
                out = np.pad(out, ((0, need), (0, 0), (0, 0)), mode="edge")
            tp = np.pad(out, ((0, 0), (pad, pad), (0, 0)), mode="edge")
            c = np.cumsum(tp, axis=1)
            out = (c[:, k:] - c[:, :-k]) / float(k)
            need = img.shape[1] - out.shape[1]
            if need > 0:
                out = np.pad(out, ((0, 0), (0, need), (0, 0)), mode="edge")
        return out

    glow = box_blur(bright, radius)
    res = a + strength * glow
    # soft filmic-ish shoulder so the highlights roll off instead of clipping
    res = res / (1.0 + np.maximum(res - 1.0, 0.0) * 0.9)
    Image.fromarray((np.clip(res, 0.0, 1.0) * 255.0).astype(np.uint8)).save(path)


def main():
    reset_scene()
    # Molten-sun palette measured off `tools/reference/golden-sun-character-turnaround.png`:
    #   highlight #fefbe3 | gold #fbab34/#f38c1f | orange #d86a19 | rust #a54827/#5c2c36
    mats = {
        "body":    make_pbr_mat("Mat_SoulBody",  (1.0, 1.0, 1.0, 1.0), roughness=0.42, emission_rgb=(1.0, 0.44, 0.10), emission_strength=0.34, use_vertex_color=True),
        "crown":   make_pbr_mat("Mat_CrownGold", (1.0, 1.0, 1.0, 1.0), roughness=0.30, emission_rgb=(1.0, 0.62, 0.16), emission_strength=0.80, use_vertex_color=True),
        "core":    make_pbr_mat("Mat_SoulCore",  (1.0, 0.94, 0.74, 1.0), roughness=0.22, emission_rgb=(1.0, 0.84, 0.42), emission_strength=2.60),
        "socket":  make_pbr_mat("Mat_EyeSocket", (0.17, 0.075, 0.055, 1.0), roughness=0.55, emission_rgb=(0.34, 0.10, 0.02), emission_strength=0.28),
        "glint":   make_pbr_mat("Mat_EyeGlint",  (1.0, 0.98, 0.90, 1.0), roughness=0.06, emission_rgb=(1.0, 0.88, 0.55), emission_strength=3.00),
        "lid":     make_pbr_mat("Mat_Eyelid",    (0.96, 0.53, 0.16, 1.0), roughness=0.38, emission_rgb=(1.0, 0.40, 0.08), emission_strength=0.26),
        "sparkle": make_pbr_mat("Mat_Sparkle",   (1.0, 1.0, 1.0, 1.0), roughness=0.02, emission_rgb=(1.0, 1.0, 1.0), emission_strength=1.4),
        "smile":   make_pbr_mat("Mat_Smile",     (0.55, 0.14, 0.06, 1.0), roughness=0.40, emission_rgb=(0.90, 0.25, 0.05), emission_strength=0.55),
    }

    body_obj = build_seamless_chibi_body(mats["body"])
    parts, ray_transforms, eyelid_pivots = build_crown_and_face_parts(mats, body_obj)
    arm_obj, mesh_obj = build_armature_and_skin(body_obj, parts, ray_transforms, eyelid_pivots)
    author_all_animations(arm_obj)

    os.makedirs("web3d/public/models", exist_ok=True)
    out_glb = "web3d/public/models/soul.glb"

    render_evaluated_verification_sheet(arm_obj, mesh_obj, "/tmp/blender_soul_sheet_v4.png")
    render_turnaround_sheet(arm_obj, mesh_obj, "/tmp/soul_turnaround_v4.png")

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

    xs = [v.co.x for v in mesh_obj.data.vertices]
    ys = [v.co.y for v in mesh_obj.data.vertices]
    zs = [v.co.z for v in mesh_obj.data.vertices]
    fig_h = max(zs)
    hx_band = [x for x, z in zip(xs, zs) if 0.95 < z < 1.15]
    head_w = max(hx_band) - min(hx_band)
    pinch = [x for x, z in zip(xs, zs) if 0.58 < z < 0.68]
    armsp = [x for x, z in zip(xs, zs) if z < 0.58]
    span = max(armsp) - min(armsp)
    print("--- measured proportions vs reference ---")
    print(f"  total height (with crown) : {fig_h:.3f} m")
    print(f"  head width  (z .95-1.15)  : {head_w:.3f} m    ref 0.854")
    print(f"  head width / fig height   : {head_w / fig_h:.3f}     ref 0.628")
    print(f"  shoulder pinch (.58-.68)  : {max(pinch)-min(pinch):.3f} m")
    print(f"  arm span     (z < 0.58)   : {span:.3f} m")
    print(f"  head / arm-span           : {head_w / span:.2f}      ref ~1.18")
    print(f"  depth range               : {max(ys)-min(ys):.3f} m")

    # In-game hero render LAST: it fills the scene with scenery that must never
    # end up inside the exported .glb.
    render_hero_shot(arm_obj, mesh_obj, "/tmp/soul_hero_ingame.png")


if __name__ == "__main__":
    main()
