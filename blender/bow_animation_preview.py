"""Renders a picture of the bow animations on a block R15 dummy:
models/bow-animation-preview.png. Run with the bpy module or Blender:

    python3 blender/bow_animation_preview.py
"""

import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import bow_animation as anim  # noqa: E402

# Roblox (Y up, faces -Z) to Blender (Z up): x -> x, y -> z, z -> -y
P = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=float)

COLORS = {
    "Head": (1.0, 0.8, 0.2),
    "UpperTorso": (0.1, 0.55, 0.95),
    "LowerTorso": (0.1, 0.45, 0.85),
    "LeftUpperArm": (0.95, 0.75, 0.2),
    "LeftLowerArm": (1.0, 0.82, 0.3),
    "LeftHand": (1.0, 0.9, 0.5),
    "RightUpperArm": (0.95, 0.75, 0.2),
    "RightLowerArm": (1.0, 0.82, 0.3),
    "RightHand": (1.0, 0.9, 0.5),
}
LEG = (0.35, 0.75, 0.25)


def mat(name, rgb):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def to_blender(cf):
    R = P @ cf.R @ P.T
    p = P @ cf.p
    m = Matrix.Identity(4)
    for r in range(3):
        for c in range(3):
            m[r][c] = R[r, c]
        m[r][3] = p[r]
    return m


def box(name, cf, size, rgb):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.name = name
    o.matrix_world = to_blender(cf)
    sx, sy, sz = size
    o.scale = (sx, sz, sy)  # Roblox Y/Z sizes swap
    o.data.materials.append(mat(name + "Mat", rgb))
    return o


def rod(name, a, b, radius, rgb):
    a, b = P @ np.asarray(a), P @ np.asarray(b)
    d = b - a
    length = float(np.linalg.norm(d))
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=max(length, 1e-3), vertices=10)
    o = bpy.context.object
    o.name = name
    o.location = tuple((a + b) / 2)
    o.rotation_mode = "QUATERNION"
    from mathutils import Vector
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(tuple(d / max(length, 1e-6))))
    o.data.materials.append(mat(name + "Mat", rgb))


def bow(info, nock_x):
    """The built-in bow (same shape as SlingshotModel.luau), string to the nock."""
    frame = info["bow"]
    s = anim.BOW_SCALE

    def at(x, y):
        return frame.point((x * s, y * s, 0))

    wood = (0.55, 0.33, 0.15)
    pts_top = [at(-2.4 * t * t, 1.2 + 5.3 * t) for t in np.linspace(0, 1, 7)]
    pts_bot = [at(-2.4 * t * t, -(1.2 + 5.3 * t)) for t in np.linspace(0, 1, 7)]
    rod("Grip", at(0, -1.2), at(0, 1.2), 0.3, wood)
    for i in range(6):
        rod(f"LimbT{i}", pts_top[i], pts_top[i + 1], 0.25 - i * 0.02, wood)
        rod(f"LimbB{i}", pts_bot[i], pts_bot[i + 1], 0.25 - i * 0.02, wood)
    nock = frame.point((nock_x, 0, 0))
    rod("StringT", pts_top[-1], nock, 0.04, (1, 1, 1))
    rod("StringB", pts_bot[-1], nock, 0.04, (1, 1, 1))


def scene(transforms, info, nock_x):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    world = anim.forward_kinematics(transforms)
    for name, size in anim.PARTS.items():
        if name == "HumanoidRootPart":
            continue
        rgb = COLORS.get(name, LEG)
        box(name, world[name], size, rgb)
    # a face, so you can see where the head looks
    head = world["Head"]
    for x in (-0.25, 0.25):
        box("Eye", head * anim.CF(p=(x, 0.12, -0.6)), (0.14, 0.24, 0.04), (0.1, 0.1, 0.15))
    box("Mouth", head * anim.CF(p=(0, -0.22, -0.6)), (0.4, 0.07, 0.04), (0.1, 0.1, 0.15))
    bow(info, nock_x)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    bpy.context.object.data.materials.append(mat("Ground", (0.55, 0.8, 0.45)))
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.78, 1.0, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sc.world = w
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.5
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(40), math.radians(15), math.radians(60))
    sc.collection.objects.link(sun_obj)
    sc.render.resolution_x = 420
    sc.render.resolution_y = 480
    return sc


def camera(sc, location, target, fov=50):
    from mathutils import Vector
    cam = bpy.data.cameras.new("Cam")
    cam.angle = math.radians(fov)
    obj = bpy.data.objects.new("Cam", cam)
    sc.collection.objects.link(obj)
    obj.location = location
    direction = Vector(target) - Vector(location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.camera = obj


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def frames():
    """(label, transforms, info, nock bow-space x)"""
    out = []
    for time, label in ((0.0, "Draw starts"), (0.5, "Drawing"), (1.0, "Full draw")):
        p = anim.draw_at(time)
        t, info = anim.solve(p)
        out.append((label, t, info, info["nock"]))
    rel = anim.release_animation()
    for (time, t, *_), label in zip(rel["keys"][1:4], ("Release (Impact)", "Follow-through", "Settle")):
        _, info = anim.solve(1.0)
        out.append((label, t, info, None))
    return out


def main():
    tmp = tempfile.mkdtemp()
    tiles = []
    for i, (label, t, info, nock) in enumerate(frames()):
        world = anim.forward_kinematics(t)
        info = dict(info)
        info["bow"] = anim.bow_frame(world["RightHand"])
        nock_x = info["bow"].inv().point(nock)[0] if nock is not None else anim.NOCK_REST
        sc = scene(t, info, nock_x)
        camera(sc, (-7.5, 4.0, 4.8), (0, 0.6, 3.3), fov=46)
        path = os.path.join(tmp, f"{i}.png")
        render(path)
        tiles.append((label, path))
    # The aiming camera the game uses while drawing (over the left shoulder).
    t, info = anim.solve(1.0)
    sc = scene(t, info, info["bow"].inv().point(info["nock"])[0])
    # Same place as AIM_OFFSET / AIM_LOOK in src/client/ShotCamera.luau (root at 3 studs up).
    sc.render.resolution_x, sc.render.resolution_y = 840, 480
    camera(sc, (-1.8, -8.5, 5.3), (0.6, 40, 4.2), fov=58)
    path = os.path.join(tmp, "aim.png")
    render(path)
    tiles.append(("Aiming camera", path))

    imgs = [Image.open(p).convert("RGB") for _, p in tiles]
    w, h = imgs[0].size
    cols = 4
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * (h + 34)), (235, 242, 250))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, ((label, _), img) in enumerate(zip(tiles, imgs)):
        x, y = (i % cols) * w, (i // cols) * (h + 34)
        sheet.paste(img, (x, y))
        tw = draw.textlength(label, font=font)
        draw.text((x + (img.width - tw) / 2, y + h + 4), label, fill=(40, 40, 60), font=font)
    out = os.path.join(anim.ROOT, "models", "bow-animation-preview.png")
    sheet.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
