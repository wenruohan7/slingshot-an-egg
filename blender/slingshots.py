"""The 12 slingshots from Config.Slingshots, one model each.

Only the frame is modelled here (handle, fork, arms, tips and decorations).
The game still builds the elastic bands and the pouch itself, so they keep
stretching when you charge. The frame is drawn in the same space as the
built-in slingshot in SlingshotModel.luau, before its 0.4 scale: the handle
starts at the origin, the fork is at Y = 6, the two tips (where the bands
tie on) are at Y = 12, Z = -4 and +4, and +X is forward, where the egg flies.
"""

import math

from common import (R, Paint, box, circle_outline, crystal, flat, ico, lathe, rod, skin, slab, sphere,
                    star_outline, torus)

FORWARD = R(1, 0, 0)
UP = R(0, 1, 0)
TIP_L = (0, 12, -4)
TIP_R = (0, 12, 4)
TIPS = (TIP_L, TIP_R)


def helix(p, period, turns_per_unit=1.0, width=0.5, center=(0, 0)):
    """Stripes that wind around a vertical handle, like tape on a grip."""
    x, y, z = p.xyz(p.vmath("SUBTRACT", p.pos, (center[0], center[1], 0)))
    angle = p.math("ARCTAN2", y, x)
    t = p.math("ADD", p.math("MULTIPLY", z, turns_per_unit), p.math("MULTIPLY", angle, period / (2 * math.pi)))
    return p.stripes(t, period, width)


def grip_wrap(name, a, b, base_color, stripe_color, rim=None, radius=0.98, period=0.7):
    p = Paint(name)
    p.set(p.mix(p.rgb(base_color), p.rgb(stripe_color), helix(p, period)))
    parts = [rod(name, R(0, a, 0), R(0, b, 0), radius, radius, p.mat, segments=20)]
    if rim:
        rim_mat = flat(name + "Rim", rim)
        for y in (a, b):
            parts.append(torus(name + "Rim", R(0, y, 0), UP, radius, 0.16, rim_mat, segments=24, sides=8))
    return parts


def fork_points(width=1.0):
    """Skeleton of the Y: handle up to the fork, then two arms curving out and up."""
    pts = [(0, -0.2, 0), (0, 3, 0), (0, 6, 0)]
    arm = [(0, 7.3, 1.8), (0, 9.4, 3.5), (0, 11.2, 4.0), (0, 12.0, 4.0)]
    for side in (-1, 1):
        for x, y, z in arm:
            pts.append((x, y, side * z))
    edges = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (2, 7), (7, 8), (8, 9), (9, 10)]
    return [R(*p) for p in pts], edges


def fork(name, mat, thick=1.0, subdiv=2):
    pts, edges = fork_points()
    radii = [0.78, 0.8, 0.86, 0.72, 0.66, 0.62, 0.6, 0.72, 0.66, 0.62, 0.6]
    return skin(name, pts, edges, [r * thick for r in radii], mat, subdiv=subdiv)


def wood(name, light, dark):
    p = Paint(name)
    grain = p.noise(3.0, detail=4, vec=p.scaled(3.5, 3.5, 0.35))
    rings = p.stripes(p.math("ADD", p.noise(1.5, vec=p.scaled(6, 6, 0.4)), 0), 0.25, 0.35, soft=0.15)
    c = p.ramp(grain, [(0.3, dark), (0.7, light)])
    return p.set(p.mix(c, p.rgb(dark), p.math("MULTIPLY", rings, 0.35)))


def gradient(name, low, high, y0, y1, extra=None):
    """A colour that fades from low at Roblox height y0 to high at y1."""
    p = Paint(name)
    t = p.math("DIVIDE", p.math("SUBTRACT", p.along(UP), y0), y1 - y0, clamp=True)
    stops = [(0, low), (1, high)] if extra is None else [(0, low), (0.5, extra), (1, high)]
    return p.set(p.ramp(t, stops))


def tips(name, mat, radius=0.85):
    return [sphere(name, R(*t), radius, mat, segments=20, rings=12) for t in TIPS]


# ---------------------------------------------------------------- the tiers


def wooden(look):
    frame = fork("Frame", wood("Wood", (196, 140, 92), (138, 92, 56)))
    parts = [frame, *tips("Tip", flat("Pink", look["accent"]))]
    parts += grip_wrap("Grip", 1.0, 4.6, look["accent"], (255, 245, 250))
    return parts


def sturdy(look):
    frame = fork("Frame", wood("DarkWood", (140, 96, 62), (92, 60, 38)), thick=1.22)
    metal = gradient("Steel", (150, 155, 165), (225, 228, 235), 0, 12)
    parts = [frame]
    parts += grip_wrap("Grip", 0.8, 4.8, (45, 45, 50), (240, 240, 240), rim=(200, 204, 212), radius=1.15)
    parts.append(torus("Collar", R(0, 6.0, 0), UP, 1.02, 0.28, metal, segments=24, sides=10))
    for z in (-4, 4):
        parts.append(rod("Cap", R(0, 11.2, z), R(0, 12.6, z), 0.95, 0.85, metal, segments=16))
        parts.append(sphere("CapTop", R(0, 12.6, z), 0.85, metal, segments=16, rings=8))
        parts.append(torus("ArmRing", R(0, 10.4, z * 0.93), R(0, 1, z * 0.12), 0.86, 0.2, metal, segments=20, sides=8))
    return parts


def leaf(name, mat, base, direction, length, width, normal=None):
    """A pointed leaf lying flat, from base out along direction."""
    outline = []
    n = 10
    for i in range(n + 1):
        t = i / n
        outline.append((t * length, math.sin(math.pi * t) ** 0.8 * width / 2))
    for i in range(n - 1, 0, -1):
        t = i / n
        outline.append((t * length, -math.sin(math.pi * t) ** 0.8 * width / 2))
    d = direction.normalized()
    normal = normal or d.cross(FORWARD).cross(d).normalized()
    up = normal.cross(d).normalized()
    # slab's outline x runs along `up.cross(axis)`; pick axis=normal, up so x lands on d
    return slab(name, [(-y, x) for x, y in outline], 0.12, mat, base, axis=normal, up=d, smooth=True)


def leafy(look):
    p = Paint("Vine")
    streak = p.noise(2.5, vec=p.scaled(4, 4, 0.5))
    p.set(p.ramp(streak, [(0.35, (70, 130, 50)), (0.65, (130, 190, 85))]))
    parts = [fork("Frame", p.mat, thick=0.95)]
    lp = Paint("Leaf")
    lp.set(lp.ramp(lp.noise(4.0), [(0.3, (60, 160, 60)), (0.7, (120, 215, 90))]))
    for z, s in ((-1, -1), (1, 1)):
        parts.append(leaf("Leaf", lp.mat, R(0.3, 7.2, 1.7 * s), R(0.6, 0.5, 1.0 * s), 3.0, 1.3))
        parts.append(leaf("Leaf", lp.mat, R(-0.3, 9.6, 3.55 * s), R(-0.5, 0.9, 0.7 * s), 2.6, 1.1))
    parts.append(leaf("Leaf", lp.mat, R(0.4, 5.6, 0), R(1.0, 0.25, 0.0), 2.4, 1.1, normal=R(0, 1, 0)))
    petal = flat("Petal", (255, 250, 240))
    center = flat("FlowerMiddle", look["accent"])
    for t in TIPS:
        c = R(*t)
        parts.append(sphere("FlowerMiddle", c, 0.62, center, segments=16, rings=10))
        for i in range(5):
            a = 2 * math.pi * i / 5
            off = R(0, math.cos(a), math.sin(a)) * 0.85
            parts.append(sphere("Petal", c + off - FORWARD * 0.1, (0.52, 0.42, 0.22), petal, segments=14, rings=8,
                                axis=FORWARD))
    parts += grip_wrap("Grip", 1.0, 4.6, (150, 105, 60), (240, 225, 160), radius=0.95, period=0.5)
    return parts


def iron(look):
    p = Paint("Iron")
    brushed = p.noise(6.0, vec=p.scaled(1, 1, 10))
    p.set(p.ramp(brushed, [(0.3, (128, 134, 146)), (0.7, (188, 193, 203))]))
    dark = flat("DarkIron", look["accent"])
    seg = 8
    pts = [(0, -0.3, 0), (0, 6, 0)]
    parts = [rod("Handle", R(*pts[0]), R(*pts[1]), 0.8, 0.8, p.mat, segments=seg, smooth=False)]
    for s in (-1, 1):
        a, b, c = R(0, 6, 0), R(0, 9, 3.6 * s), R(0, 12, 4 * s)
        parts.append(rod("Arm", a, b, 0.72, 0.66, p.mat, segments=seg, smooth=False))
        parts.append(rod("Arm", b, c, 0.66, 0.62, p.mat, segments=seg, smooth=False))
        parts.append(ico("Joint", b, 0.72, p.mat, subdiv=1))
        # a hex nut on each tip
        parts.append(rod("Nut", c - UP * 0.5, c + UP * 0.5, 0.95, 0.95, dark, segments=6, smooth=False))
        parts.append(rod("Bolt", c + UP * 0.5, c + UP * 0.8, 0.45, 0.45, p.mat, segments=6, smooth=False))
    parts.append(box("ForkPlate", R(0, 6.1, 0), (1.9, 2.4, 2.0), dark, bevel=0.15))
    for z in (-0.6, 0.6):
        for y in (5.6, 6.6):
            parts.append(rod("Rivet", R(0.95, y, z), R(1.15, y, z), 0.22, 0.18, p.mat, segments=8))
    parts += grip_wrap("Grip", 0.8, 4.8, (60, 60, 66), (110, 112, 120), rim=look["accent"], radius=1.02, period=0.45)
    return parts


def swirl(name, center, colors, arms=3, axis="x"):
    """A lollipop spiral on a disc that faces forward, centred on center (Blender)."""
    p = Paint(name)
    rel = p.vmath("SUBTRACT", p.pos, center)
    x, y, z = p.xyz(rel)
    angle = p.math("ARCTAN2", z, y)
    r = p.math("SQRT", p.math("ADD", p.math("MULTIPLY", y, y), p.math("MULTIPLY", z, z)))
    t = p.math("ADD", p.math("MULTIPLY", angle, arms / (2 * math.pi)), p.math("MULTIPLY", r, 2.2))
    f = p.math("FRACT", t)
    stops = []
    n = len(colors)
    for i, c in enumerate(colors):
        stops.append((i / n, c))
        stops.append(((i + 1) / n - 0.001, c))
    return p.set(p.ramp(f, stops, interpolation="CONSTANT"))


def candy(look):
    p = Paint("CandyStripe")
    stripe = p.stripes(p.along(R(0, 1, 0.7)), 1.1, 0.5, soft=0.06)
    p.set(p.mix(p.rgb(look["frame"]), p.rgb((255, 255, 255)), stripe))
    parts = [fork("Frame", p.mat)]
    for t in TIPS:
        c = R(*t) + FORWARD * 0.25
        mat = swirl("Lolly", c, [(255, 120, 180), (255, 255, 255), (120, 210, 255), (255, 255, 255)], arms=2)
        parts.append(rod("Lolly", c - FORWARD * 0.35, c + FORWARD * 0.35, 1.45, 1.45, mat, segments=28))
        parts.append(torus("LollyRim", c, FORWARD, 1.45, 0.35, mat, segments=28, sides=8))
    drop = Paint("Gumdrop")
    drop.set(drop.ramp(drop.noise(14.0), [(0.4, (100, 195, 245)), (0.6, (165, 230, 255))]))
    gum = lathe("Gumdrop", [(0, 0), (1.25, 0), (1.3, 0.25), (1.1, 0.9), (0.6, 1.35), (0, 1.5)], drop.mat,
                center=R(0.55, 5.4, 0), axis=R(0.35, 1, 0), segments=24)
    parts.append(gum)
    parts += grip_wrap("Grip", 1.0, 4.6, (255, 255, 255), look["band"], radius=0.96, period=0.8)
    return parts


def golden(look):
    p = Paint("Gold")
    shine = p.noise(1.8, detail=2, vec=p.scaled(1, 1, 0.5))
    band = p.stripes(p.along(R(0.3, 1, 0)), 3.0, 0.12, soft=0.5)
    c = p.ramp(shine, [(0.3, (222, 150, 30)), (0.6, (255, 205, 70)), (0.8, (255, 236, 150))])
    p.set(p.mix(c, p.rgb((255, 246, 200)), p.math("MULTIPLY", band, 0.5)))
    parts = [fork("Frame", p.mat, thick=1.05)]
    ruby = gradient("Ruby", (150, 10, 30), (255, 70, 90), 5, 7.3)
    parts.append(ico("Ruby", R(0.75, 6.1, 0), 0.95, ruby, subdiv=1, scale=(1, 0.55, 1), axis=R(1, 0, 0)))
    parts.append(torus("RubySetting", R(0.62, 6.1, 0), FORWARD, 0.95, 0.18, p.mat, segments=24, sides=8))
    pale = flat("PaleGold", look["accent"])
    diamond = gradient("Diamond", (150, 220, 255), (255, 255, 255), 12, 14)
    for t in TIPS:
        parts.append(sphere("Tip", R(*t), 0.8, pale, segments=18, rings=10))
        parts.append(crystal("TipGem", R(*t) + UP * 0.5, UP, 0.5, 1.4, diamond, sides=6))
    parts += grip_wrap("Grip", 1.0, 4.6, (190, 30, 40), (255, 210, 80), rim=(255, 220, 110), radius=1.0, period=0.6)
    return parts


def ice(look):
    p = Paint("Ice")
    frost = p.noise(5.0, detail=5)
    p.set(p.ramp(frost, [(0.35, (150, 215, 250)), (0.55, (200, 238, 255)), (0.75, (255, 255, 255))]))
    parts = [fork("Frame", p.mat)]
    shard = gradient("Shard", (120, 190, 255), (245, 252, 255), 10.5, 15.5)
    for s in (-1, 1):
        base = R(0, 12, 4 * s)
        parts.append(crystal("Shard", base - UP * 0.3, R(0, 1, 0), 0.62, 3.0, shard))
        parts.append(crystal("Shard", base, R(0, 1, 0.55 * s), 0.42, 2.0, shard, twist=0.4))
        parts.append(crystal("Shard", base, R(0.55, 0.9, -0.1 * s), 0.38, 1.7, shard, twist=0.2))
        parts.append(crystal("Shard", base, R(-0.55, 0.9, -0.1 * s), 0.38, 1.6, shard, twist=0.7))
        # icicles hanging under the arms
        for y, z, length in ((7.6, 2.0, 1.4), (9.0, 3.2, 1.1), (10.2, 3.85, 0.8)):
            top = R(0, y - 0.35, z * s)
            parts.append(rod("Icicle", top, top - UP * length, 0.26, 0.0, shard, segments=6, smooth=False))
    snow = flat("Snow", (250, 252, 255))
    parts.append(sphere("Snow", R(0, 6.55, 0), (1.25, 1.1, 0.6), snow, segments=20, rings=10))
    parts += grip_wrap("Grip", 1.0, 4.6, (80, 160, 255), (255, 255, 255), radius=0.96, period=0.55)
    return parts


def flame(name, base, mat, scale=1.0):
    prof = [(0, 0), (0.55, 0.15), (0.75, 0.55), (0.62, 1.0), (0.38, 1.45), (0.15, 1.85), (0, 2.1)]
    return lathe(name, [(r * scale, h * scale) for r, h in prof], mat, center=base, axis=UP, segments=18)


def lava(look):
    p = Paint("Basalt")
    cracks = p.voronoi(1.6, feature="DISTANCE_TO_EDGE")
    glow = p.math("SUBTRACT", 1.0, p.step(0.07, cracks, soft=0.06))
    rock = p.ramp(p.noise(4.0, detail=4), [(0.35, (40, 26, 26)), (0.7, (82, 56, 52))])
    hot = p.ramp(p.noise(3.0), [(0.3, (255, 90, 20)), (0.7, (255, 190, 50))])
    p.set(p.mix(rock, hot, glow))
    parts = [fork("Frame", p.mat, thick=1.12)]
    fire = gradient("Fire", (255, 80, 20), (255, 236, 120), 11.6, 14.4, extra=(255, 160, 30))
    for t in TIPS:
        parts.append(flame("Flame", R(*t) - UP * 0.4, fire, scale=1.25))
    rocks = flat("Rock", (70, 46, 42))
    for pos, r in (((0.5, 5.8, 0.5), 0.6), ((-0.4, 6.4, -0.6), 0.5), ((0.4, 2.2, -0.6), 0.45)):
        parts.append(ico("Rock", R(*pos), r, rocks, subdiv=1))
    parts += grip_wrap("Grip", 1.0, 4.6, (45, 30, 28), (255, 120, 30), radius=1.0, period=0.5)
    return parts


def crystal_tier(look):
    gem = gradient("Amethyst", (120, 70, 200), (215, 180, 255), 0, 12)
    parts = [fork("Frame", gem, subdiv=1)]
    for o in parts:
        o.data.shade_flat()
    shard = gradient("CrystalShard", (170, 110, 255), (255, 250, 255), 11, 15.5)
    for s in (-1, 1):
        base = R(0, 11.8, 4 * s)
        parts.append(crystal("Crystal", base, R(0, 1, 0.15 * s), 0.75, 3.2, shard, twist=0.3))
        parts.append(crystal("Crystal", base, R(0.5, 0.85, 0.35 * s), 0.45, 2.0, shard))
        parts.append(crystal("Crystal", base, R(-0.45, 0.85, 0.4 * s), 0.42, 1.8, shard, twist=0.5))
    parts.append(crystal("Heart", R(0.3, 5.3, 0), R(0.5, 1, 0), 0.8, 2.6, shard, sides=6))
    parts += grip_wrap("Grip", 1.0, 4.6, (110, 60, 200), (255, 255, 255), radius=0.96, period=0.6)
    return parts


def rainbow(look):
    p = Paint("Rainbow")
    t = p.math("DIVIDE", p.along(R(0, 1, 0)), 12.5, clamp=True)
    p.set(p.ramp(t, [(0.0, (255, 80, 90)), (0.2, (255, 160, 60)), (0.4, (255, 230, 80)),
                     (0.6, (100, 220, 120)), (0.8, (90, 170, 255)), (1.0, (190, 120, 255))]))
    parts = [fork("Frame", p.mat)]
    star = gradient("Star", (255, 200, 40), (255, 245, 150), 11, 13.5)
    for tpos in TIPS:
        parts.append(slab("Star", star_outline(5, 1.55, 0.7), 0.7, star, R(*tpos) + UP * 0.2, axis=FORWARD,
                          up=UP, bevel=0.12, smooth=True))
    cloud = flat("Cloud", (255, 255, 255))
    for pos, r in (((0, 0.2, 0), 1.25), ((0.3, 0.6, 1.0), 0.95), ((-0.2, 0.5, -1.05), 0.95),
                   ((0.9, 0.4, -0.2), 0.8), ((-0.9, 0.4, 0.2), 0.8)):
        parts.append(sphere("Cloud", R(*pos), r, cloud, segments=16, rings=10))
    parts += grip_wrap("Grip", 1.6, 4.8, (255, 255, 255), (255, 130, 200), radius=0.96, period=0.7)
    return parts


def galaxy(look):
    p = Paint("Space")
    neb = p.noise(1.4, detail=4, distortion=0.6)
    base = p.ramp(neb, [(0.35, (34, 16, 82)), (0.55, (80, 40, 160)), (0.75, (200, 80, 200))])
    stars = p.math("SUBTRACT", 1.0, p.step(0.07, p.voronoi(4.0, randomness=1.0), soft=0.03))
    p.set(p.mix(base, p.rgb((255, 255, 255)), stars))
    parts = [fork("Frame", p.mat)]
    planet = Paint("Planet")
    planet.set(planet.ramp(planet.stripes(planet.along(UP), 0.4, 0.5, soft=0.3),
                           [(0, (110, 190, 255)), (1, (180, 240, 255))]))
    ring = flat("PlanetRing", (255, 150, 240))
    for t in TIPS:
        c = R(*t) + UP * 0.2
        parts.append(sphere("Planet", c, 0.95, planet.mat, segments=22, rings=12))
        parts.append(torus("Ring", c, R(0.35, 1, 0.25), 1.45, 0.14, ring, segments=32, sides=6, squash=0.4))
    glow = gradient("StarGlow", (255, 120, 255), (255, 230, 255), 4.5, 7.5)
    parts.append(slab("Star", star_outline(4, 1.4, 0.45), 0.5, glow, R(0.6, 6.1, 0), axis=FORWARD, up=UP,
                      bevel=0.1, smooth=True))
    parts += grip_wrap("Grip", 1.0, 4.6, (30, 18, 70), (120, 220, 255), rim=(255, 120, 255), radius=0.98, period=0.6)
    return parts


def crescent(name, center, r, thickness, mat, mirror=1):
    """A crescent moon facing forward. Built as a strip between its outer and
    inner arcs (both run tip to tip), so its hollow side stays empty."""
    import bmesh
    from common import _obj
    d, ri = 0.5 * r, 0.85 * r
    x = (r * r - ri * ri + d * d) / (2 * d)
    y = math.sqrt(r * r - x * x)
    t0 = math.atan2(y, x)
    p0 = math.atan2(y, x - d)
    n = 20
    outer = [(r * math.cos(t0 + (2 * math.pi - 2 * t0) * i / n), r * math.sin(t0 + (2 * math.pi - 2 * t0) * i / n))
             for i in range(n + 1)]
    inner = [(d + ri * math.cos(p0 + (2 * math.pi - 2 * p0) * i / n), ri * math.sin(p0 + (2 * math.pi - 2 * p0) * i / n))
             for i in range(n + 1)]
    bm = bmesh.new()

    def ring(points, z):
        return [bm.verts.new((px * mirror, py, z)) for px, py in points]

    of, ob_, inf, inb = ring(outer, thickness / 2), ring(outer, -thickness / 2), ring(inner, thickness / 2), ring(inner, -thickness / 2)
    for i in range(n):
        for quad in ((of[i], of[i + 1], inf[i + 1], inf[i]), (ob_[i], inb[i], inb[i + 1], ob_[i + 1]),
                     (of[i], ob_[i], ob_[i + 1], of[i + 1]), (inf[i], inf[i + 1], inb[i + 1], inb[i])):
            bm.faces.new(quad)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    from common import _frame
    from mathutils import Matrix, Vector
    # local Z faces forward, local Y is up
    zf = FORWARD.normalized()
    yu = UP.normalized()
    xr = yu.cross(zf)
    m = Matrix.Translation(center) @ Matrix((xr, yu, zf)).transposed().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    obj = _obj(name, bm, mat, smooth=True)
    obj.data.set_sharp_from_angle(angle=math.radians(45))
    return obj


def moon(look):
    p = Paint("Marble")
    veins = p.noise(1.2, detail=6, distortion=2.5)
    line = p.math("SUBTRACT", 1.0, p.step(0.05, p.math("ABSOLUTE", p.math("SUBTRACT", veins, 0.5)), soft=0.05))
    base = p.ramp(p.noise(2.0), [(0.3, (222, 224, 238)), (0.7, (246, 246, 252))])
    p.set(p.mix(base, p.rgb((150, 160, 200)), p.math("MULTIPLY", line, 0.7)))
    parts = [fork("Frame", p.mat)]
    gold = gradient("MoonGold", (240, 190, 70), (255, 240, 160), 10, 14)
    for s, t in ((-1, TIP_L), (1, TIP_R)):
        # the crescents open away from each other
        parts.append(crescent("Crescent", R(*t) + UP * 0.3, 1.6, 0.6, gold, mirror=s))
        parts.append(torus("Trim", R(0, 11.1, 4 * s), UP, 0.66, 0.16, gold, segments=20, sides=8))
    star = gradient("MoonStar", (140, 160, 255), (220, 230, 255), 5, 7.4)
    parts.append(slab("Star", star_outline(5, 1.2, 0.52), 0.5, star, R(0.6, 6.1, 0), axis=FORWARD, up=UP,
                      bevel=0.1, smooth=True))
    parts += grip_wrap("Grip", 1.0, 4.6, (140, 160, 255), (255, 255, 255), rim=(245, 210, 110), radius=0.98, period=0.6)
    return parts


# Names and colours copied from Config.Slingshots.
TIERS = [
    ("Wooden Slingshot", wooden, {"frame": (176, 122, 78), "accent": (255, 120, 160), "band": (235, 60, 110)}),
    ("Sturdy Slingshot", sturdy, {"frame": (120, 80, 50), "accent": (240, 240, 240), "band": (60, 60, 60)}),
    ("Leafy Slingshot", leafy, {"frame": (100, 160, 70), "accent": (255, 220, 90), "band": (80, 200, 90)}),
    ("Iron Slingshot", iron, {"frame": (150, 155, 165), "accent": (70, 75, 85), "band": (40, 40, 45)}),
    ("Candy Slingshot", candy, {"frame": (255, 150, 200), "accent": (255, 255, 255), "band": (120, 210, 255)}),
    ("Golden Slingshot", golden, {"frame": (255, 200, 60), "accent": (255, 240, 160), "band": (200, 40, 40)}),
    ("Ice Slingshot", ice, {"frame": (170, 230, 255), "accent": (255, 255, 255), "band": (80, 160, 255)}),
    ("Lava Slingshot", lava, {"frame": (60, 40, 40), "accent": (255, 110, 30), "band": (255, 170, 40)}),
    ("Crystal Slingshot", crystal_tier, {"frame": (190, 140, 255), "accent": (255, 255, 255), "band": (150, 90, 255)}),
    ("Rainbow Slingshot", rainbow, {"frame": (255, 120, 200), "accent": (120, 230, 255), "band": (255, 230, 80)}),
    ("Galaxy Slingshot", galaxy, {"frame": (60, 30, 120), "accent": (150, 220, 255), "band": (255, 120, 255)}),
    ("Moon Slingshot", moon, {"frame": (230, 230, 245), "accent": (255, 230, 120), "band": (140, 160, 255)}),
]
