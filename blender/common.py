"""Shared helpers for the model scripts: making shapes, painting them with
procedural colours, baking those colours into one texture, and exporting an
FBX that Roblox Studio's 3D Importer can read.

Coordinates: Roblox is Y-up with -Z as the front. Blender is Z-up. The FBX
exporter (forward -Z, up Y) turns Blender (x, y, z) into Roblox (x, z, -y),
so `R(x, y, z)` below takes a Roblox position and gives the Blender one.
Every model is built in Roblox coordinates through `R`.
"""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

TEXTURE_SIZE = 1024  # Roblox shows textures at up to 1024x1024
MAX_TRIANGLES = 12000  # Roblox allows 20,000 per mesh; stay well under


def R(x, y, z):
    """A Roblox position (Y up, -Z front) as a Blender vector."""
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    return scene


# ---------------------------------------------------------------- materials


class Paint:
    """A material whose colour is a small node graph. While baking, the colour
    feeds an Emission shader, so the bake copies it exactly."""

    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        self.mat.use_nodes = True
        self.nt = self.mat.node_tree
        self.nt.nodes.clear()
        self.out = self.nt.nodes.new("ShaderNodeOutputMaterial")
        self.emit = self.nt.nodes.new("ShaderNodeEmission")
        self.link(self.emit.outputs[0], self.out.inputs[0])
        tc = self.nt.nodes.new("ShaderNodeTexCoord")
        self.pos = tc.outputs["Object"]  # the joined object sits at the origin, so this is model space

    def link(self, a, b):
        self.nt.links.new(a, b)

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    # colours and numbers
    def rgb(self, c):
        n = self.node("ShaderNodeRGB")
        n.outputs[0].default_value = (*srgb(c), 1)
        return n.outputs[0]

    def value(self, v):
        n = self.node("ShaderNodeValue")
        n.outputs[0].default_value = v
        return n.outputs[0]

    def _in(self, socket, v):
        if isinstance(v, (int, float)):
            socket.default_value = v
        elif isinstance(v, (tuple, list, Vector)):
            socket.default_value = v
        else:
            self.link(v, socket)

    def math(self, op, a, b=0.0, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        return n.outputs[0]

    def vmath(self, op, a, b=(0, 0, 0)):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        return n.outputs["Value"] if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else n.outputs["Vector"]

    def xyz(self, vec=None):
        n = self.node("ShaderNodeSeparateXYZ")
        self._in(n.inputs[0], vec if vec is not None else self.pos)
        return n.outputs[0], n.outputs[1], n.outputs[2]

    def along(self, direction, origin=(0, 0, 0)):
        """Distance along a Blender direction, measured from origin."""
        rel = self.vmath("SUBTRACT", self.pos, Vector(origin))
        return self.vmath("DOT_PRODUCT", rel, Vector(direction).normalized())

    def mix(self, a, b, fac):
        n = self.node("ShaderNodeMix", data_type="RGBA", clamp_factor=True)
        self._in(n.inputs["Factor"], fac)
        self._in(n.inputs[6], a)
        self._in(n.inputs[7], b)
        return n.outputs[2]

    def ramp(self, fac, stops, interpolation="LINEAR"):
        """stops: [(position, colour)], positions 0..1."""
        n = self.node("ShaderNodeValToRGB")
        n.color_ramp.interpolation = interpolation
        els = n.color_ramp.elements
        while len(els) < len(stops):
            els.new(0.5)
        for el, (pos, c) in zip(els, stops):
            el.position = pos
            el.color = (*srgb(c), 1)
        self._in(n.inputs[0], fac)
        return n.outputs[0]

    def noise(self, scale, detail=3.0, roughness=0.5, vec=None, distortion=0.0):
        n = self.node("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = roughness
        n.inputs["Distortion"].default_value = distortion
        self._in(n.inputs["Vector"], vec if vec is not None else self.pos)
        return n.outputs["Fac"]

    def voronoi(self, scale, feature="F1", vec=None, randomness=1.0):
        n = self.node("ShaderNodeTexVoronoi", feature=feature)
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = randomness
        self._in(n.inputs["Vector"], vec if vec is not None else self.pos)
        return n.outputs["Distance"]

    def scaled(self, sx, sy, sz):
        """Model position stretched per axis, for streaky noise."""
        return self.vmath("MULTIPLY", self.pos, Vector((sx, sy, sz)))

    def step(self, edge, x, soft=0.0):
        """0 below edge, 1 above (with a soft ramp of width soft)."""
        if soft <= 0:
            return self.math("GREATER_THAN", x, edge)
        return self.math("DIVIDE", self.math("SUBTRACT", x, edge - soft / 2), soft, clamp=True)

    def stripes(self, t, period, width=0.5, soft=0.04):
        """1 on the stripes, 0 between: stripes repeat every `period` along t."""
        f = self.math("FRACT", self.math("DIVIDE", t, period))
        return self.math("SUBTRACT", 1.0, self.step(width, f, soft))

    def set(self, color):
        self.link(color, self.emit.inputs["Color"])
        return self.mat


def srgb(c):
    """0-255 sRGB triple to linear 0-1, which is what Blender nodes store."""
    out = []
    for v in c:
        v = v / 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def gradient_paint(name, low, high, a, b, middle=None):
    """A colour fading from low at point a to high at point b (Blender vectors)."""
    p = Paint(name)
    d = Vector(b) - Vector(a)
    t = p.math("DIVIDE", p.along(d, a), d.length, clamp=True)
    stops = [(0, low), (1, high)] if middle is None else [(0, low), (0.5, middle), (1, high)]
    return p.set(p.ramp(t, stops))


def flat(name, c):
    p = Paint(name)
    return p.set(p.rgb(c))


# ------------------------------------------------------------------- shapes


def _obj(name, bm, mat, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    if smooth:
        me.shade_smooth()
    else:
        me.shade_flat()
    return ob


def _place(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)


def _frame(center, axis):
    """Matrix moving local +Z onto axis at center (Blender vectors)."""
    axis = Vector(axis).normalized()
    rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
    return Matrix.Translation(Vector(center)) @ rot


def sphere(name, center, radius, mat, segments=24, rings=14, smooth=True, axis=(0, 0, 1)):
    """radius: number or (rx, ry, rz) along the local axes (local Z = axis)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    r = radius if isinstance(radius, (tuple, list)) else (radius,) * 3
    _place(bm, _frame(center, axis) @ Matrix.Diagonal((*r, 1)))
    return _obj(name, bm, mat, smooth)


def ico(name, center, radius, mat, subdiv=1, smooth=False, scale=(1, 1, 1), axis=(0, 0, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    _place(bm, _frame(center, axis) @ Matrix.Diagonal((*scale, 1)))
    return _obj(name, bm, mat, smooth)


def rod(name, a, b, r1, r2, mat, segments=16, smooth=True, cap=True):
    """A tapered cylinder from a to b (Blender vectors), radius r1 at a, r2 at b."""
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segments,
                          radius1=r1, radius2=r2, depth=(b - a).length)
    _place(bm, _frame((a + b) / 2, b - a))
    ob = _obj(name, bm, mat, smooth)
    if smooth and cap:
        # keep the flat caps flat
        ob.data.set_sharp_from_angle(angle=math.radians(50))
    return ob


def box(name, center, size, mat, bevel=0.0, rot=None, segments=2):
    """A box; size is in Roblox order (width X, height Y, depth Z). rot is a
    Blender rotation matrix applied around the box's centre."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    _place(bm, Matrix.Diagonal((size[0], size[2], size[1], 1)))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.verts[:] + bm.edges[:], offset=bevel, segments=segments,
                        affect="EDGES", profile=0.5)
    m = Matrix.Translation(Vector(center))
    if rot is not None:
        m = m @ rot.to_4x4()
    _place(bm, m)
    ob = _obj(name, bm, mat, smooth=bevel > 0)
    if bevel > 0:
        ob.data.set_sharp_from_angle(angle=math.radians(40))
    return ob


def torus(name, center, axis, major, minor, mat, segments=32, sides=10, smooth=True, squash=1.0, arc=None):
    """A ring around `axis`. arc (radians) makes an open part-ring that starts
    on the local +X side; leave it out for a full ring."""
    bm = bmesh.new()
    full = arc is None
    arc = 2 * math.pi if full else arc
    count = segments if full else segments + 1
    rings = []
    for i in range(count):
        a = arc * i / segments
        ring = []
        for j in range(sides):
            b = 2 * math.pi * j / sides
            rr = major + minor * math.cos(b)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), minor * math.sin(b) * squash)))
        rings.append(ring)
    for i in range(segments):
        r0, r1 = rings[i], rings[(i + 1) % count]
        for j in range(sides):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % sides], r0[(j + 1) % sides]))
    _place(bm, _frame(center, axis))
    return _obj(name, bm, mat, smooth)


def slab(name, outline, thickness, mat, center, axis=(0, 0, 1), up=(0, 1, 0), bevel=0.0, smooth=False):
    """A flat shape: 2D outline [(x, y)] in a plane facing `axis`, extruded to
    `thickness` and centred on `center`. `up` picks the outline's +y direction."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, -thickness / 2)) for x, y in outline]
    face = bm.faces.new(verts)
    # fill the (maybe concave) outline with triangles first, then extrude it
    bmesh.ops.triangulate(bm, faces=[face])
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    top = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, thickness), verts=top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        outline_edges = [e for e in bm.edges if len(e.link_faces) == 2 and
                         e.calc_face_angle(0) > math.radians(30)]
        bmesh.ops.bevel(bm, geom=outline_edges, offset=bevel, segments=2, affect="EDGES", profile=0.5,
                        clamp_overlap=True)
    z = Vector(axis).normalized()
    y = Vector(up).normalized()
    x = y.cross(z).normalized()
    y = z.cross(x)
    rot = Matrix((x, y, z)).transposed().to_4x4()
    _place(bm, Matrix.Translation(Vector(center)) @ rot)
    ob = _obj(name, bm, mat, smooth)
    if smooth:
        ob.data.set_sharp_from_angle(angle=math.radians(45))
    return ob


def star_outline(points, outer, inner, rotate=math.pi / 2):
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = rotate + math.pi * i / points
        out.append((r * math.cos(a), r * math.sin(a)))
    return out


def circle_outline(r, n=24, start=0.0, end=2 * math.pi, closed=True):
    count = n if closed else n + 1
    return [(r * math.cos(start + (end - start) * i / n), r * math.sin(start + (end - start) * i / n)) for i in range(count)]


def crystal(name, base, axis, radius, length, mat, sides=6, tip=0.35, twist=0.0):
    """A gem prism: a short column with a pointed top, flat shaded."""
    bm = bmesh.new()
    bottom, top = [], []
    h = length * (1 - tip)
    for i in range(sides):
        a = 2 * math.pi * i / sides + twist
        bottom.append(bm.verts.new((radius * 0.8 * math.cos(a), radius * 0.8 * math.sin(a), 0)))
        top.append(bm.verts.new((radius * math.cos(a), radius * math.sin(a), h)))
    apex = bm.verts.new((0, 0, length))
    bm.faces.new(list(reversed(bottom)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
        bm.faces.new((top[i], top[j], apex))
    _place(bm, _frame(base, axis))
    return _obj(name, bm, mat, smooth=False)


def skin(name, points, edges, radii, mat, subdiv=2):
    """A smooth branching tube (Skin modifier + Subdivision), like a tree branch."""
    me = bpy.data.meshes.new(name + "Skel")
    me.from_pydata([tuple(p) for p in points], edges, [])
    ob = bpy.data.objects.new(name + "Skel", me)
    bpy.context.scene.collection.objects.link(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    for v, r in zip(me.skin_vertices[0].data, radii):
        v.radius = (r, r)
    me.skin_vertices[0].data[0].use_root = True
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = subdiv
    sub.render_levels = subdiv
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    bm = bmesh.new()
    bm.from_mesh(ev.to_mesh())
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    return _obj(name, bm, mat, smooth=True)


def lathe(name, profile, mat, center=(0, 0, 0), axis=(0, 0, 1), segments=32, smooth=True):
    """Spin a profile [(radius, height)] around the local Z axis."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), h)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            a, b, c, d = rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]
            if profile[k][0] < 1e-6:
                bm.faces.new((a, c, d))
            elif profile[k + 1][0] < 1e-6:
                bm.faces.new((a, b, d))
            else:
                bm.faces.new((a, b, c, d))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _place(bm, _frame(center, axis))
    return _obj(name, bm, mat, smooth)


# ------------------------------------------------------------ bake + export


def join(name, objects):
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    with bpy.context.temp_override(active_object=objects[0], selected_objects=objects,
                                   selected_editable_objects=objects):
        bpy.ops.object.join()
    ob = objects[0]
    ob.name = name
    ob.data.name = name
    return ob


def triangles(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def unwrap(ob, angle=60, margin=0.004):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.6,
                             scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def _bake(ob, image, kind, samples):
    scene = bpy.context.scene
    scene.cycles.samples = samples
    for slot in ob.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = image
        nt.nodes.active = node
    bake = scene.render.bake
    bake.margin = 8
    bake.use_clear = True
    for other in scene.objects:
        other.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type=kind)


def bake_texture(ob, path, ao_strength=0.5, size=TEXTURE_SIZE, ao_distance=1.0):
    """Bake every material's colour (and soft shadows in the corners) into
    one image at path, then give the object a single material using it."""
    color = bpy.data.images.new(ob.name + "Color", size, size, alpha=False)
    _bake(ob, color, "EMIT", 4)
    rgb = np.array(color.pixels[:], dtype=np.float32).reshape(size, size, 4)
    if ao_strength > 0:
        bpy.context.scene.world = bpy.context.scene.world or bpy.data.worlds.new("World")
        bpy.context.scene.world.light_settings.distance = ao_distance
        ao = bpy.data.images.new(ob.name + "AO", size, size, alpha=False)
        ao.colorspace_settings.name = "Non-Color"
        _bake(ob, ao, "AO", 48)
        occ = np.array(ao.pixels[:], dtype=np.float32).reshape(size, size, 4)[..., :1]
        rgb[..., :3] *= (1 - ao_strength) + ao_strength * occ
    color.pixels = rgb.ravel()
    color.filepath_raw = path
    color.file_format = "PNG"
    color.save()

    final = bpy.data.materials.new(ob.name)
    final.use_nodes = True
    nt = final.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.6
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=False)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    ob.data.materials.clear()
    ob.data.materials.append(final)
    return path


def roblox_box(ob):
    """The mesh's bounding box in Roblox axes: (size, center)."""
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    size = hi - lo
    c = (hi + lo) / 2
    return (size.x, size.z, size.y), (c.x, c.z, -c.y)


def export_fbx(ob, path):
    for other in bpy.context.scene.objects:
        other.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="OFF",  # write normals, which carry the smooth/sharp edges
        use_mesh_modifiers=True,
        path_mode="COPY",
        embed_textures=True,
        bake_anim=False,
    )


def finish(name, parts, out_dir, ao_strength=0.5, ao_distance=1.0, angle=60):
    """Join parts, unwrap, bake, export. Returns info for the size table."""
    ob = join(name, parts)
    tris = triangles(ob)
    if tris > MAX_TRIANGLES:
        raise RuntimeError(f"{name}: {tris} triangles (limit {MAX_TRIANGLES})")
    unwrap(ob, angle=angle)
    os.makedirs(out_dir, exist_ok=True)
    bake_texture(ob, os.path.join(out_dir, name + ".png"), ao_strength=ao_strength, ao_distance=ao_distance)
    export_fbx(ob, os.path.join(out_dir, name + ".fbx"))
    size, center = roblox_box(ob)
    return {"name": name, "triangles": tris, "size": size, "center": center, "object": ob}


# ------------------------------------------------------------------ preview


def render_preview(ob, path, res=420, view=(1.0, -1.6, 0.7), also=()):
    """A quick Cycles picture of the finished model on a soft background.
    view is a Blender-space direction from the model to the camera."""
    scene = bpy.context.scene
    shown = [ob, *also]
    for other in scene.objects:
        other.hide_render = other not in shown
    pts = [o.matrix_world @ v.co for o in shown for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (hi + lo) / 2
    radius = (hi - lo).length / 2

    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.78, 0.86, 0.95, 1)
    bg.inputs[1].default_value = 0.9

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    d = Vector(view).normalized()
    dist = radius / math.tan(cam_data.angle / 2) * 1.08
    cam.location = center + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    sun_data = bpy.data.lights.new("PreviewSun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(12)
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)

    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.cycles.samples = 48
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

    for o in (cam, sun):
        bpy.data.objects.remove(o)
    for other in scene.objects:
        other.hide_render = False
