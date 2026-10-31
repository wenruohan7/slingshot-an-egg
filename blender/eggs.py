"""The 8 eggs from Config.Eggs, one model each, about 4 studs wide and 5 tall
(the size of the built-in egg)."""

import math

from common import R, Paint, gradient_paint, lathe, slab, torus

UP = R(0, 1, 0)
HALF = 2.5  # half the egg's height
WIDTH = 2.0  # the egg's widest radius


def egg_profile(rings=26, bottom_bulge=0.16):
    pts = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        h = -HALF * math.cos(th)
        r = math.sin(th) * (1 + bottom_bulge * math.cos(th))
        pts.append((r, h))
    biggest = max(r for r, _ in pts)
    return [(WIDTH * r / biggest, h) for r, h in pts]


def egg_body(mat, segments=36, rings=26, smooth=True):
    return lathe("Egg", egg_profile(rings), mat, segments=segments, smooth=smooth)


def angle_of(p):
    x, y, _ = p.xyz()
    return p.math("ARCTAN2", y, x)


def height(p):
    return p.xyz()[2]


def dots(p, scale, size, randomness=0.9):
    """1 inside small round dots scattered over the surface."""
    return p.math("SUBTRACT", 1.0, p.step(size, p.voronoi(scale, randomness=randomness), soft=0.04))


def top_light(p, color, amount=0.18):
    """Lighten the top a little, like light from above."""
    t = p.math("DIVIDE", p.math("ADD", height(p), HALF), 2 * HALF, clamp=True)
    return p.mix(color, p.rgb((255, 255, 255)), p.math("MULTIPLY", p.math("POWER", t, 2.0), amount))


def plain():
    p = Paint("Plain")
    base = p.ramp(p.noise(3.0), [(0.3, (250, 232, 195)), (0.7, (255, 246, 222))])
    speck = dots(p, 4.0, 0.09)
    p.set(top_light(p, p.mix(base, p.rgb((205, 150, 95)), p.math("MULTIPLY", speck, 0.9))))
    return [egg_body(p.mat)]


def mint():
    p = Paint("Mint")
    a = angle_of(p)
    zig = p.math("ABSOLUTE", p.math("SUBTRACT", p.math("FRACT", p.math("MULTIPLY", a, 7 / (2 * math.pi))), 0.5))
    centre = p.math("MULTIPLY", p.math("SUBTRACT", zig, 0.25), 1.6)
    band = p.math("SUBTRACT", 1.0, p.step(0.32, p.math("ABSOLUTE", p.math("SUBTRACT", height(p), centre)), soft=0.05))
    spots = dots(p, 1.9, 0.2, randomness=0.6)
    base = p.mix(p.rgb((170, 240, 200)), p.rgb((110, 205, 160)), spots)
    p.set(top_light(p, p.mix(base, p.rgb((255, 255, 255)), band)))
    return [egg_body(p.mat)]


def sky():
    p = Paint("Sky")
    t = p.math("DIVIDE", p.math("ADD", height(p), HALF), 2 * HALF, clamp=True)
    base = p.ramp(t, [(0, (90, 160, 250)), (1, (175, 220, 255))])
    cloud = p.step(0.58, p.noise(0.9, detail=3, vec=p.scaled(1, 1, 1.8)), soft=0.05)
    p.set(p.mix(base, p.rgb((255, 255, 255)), cloud))
    return [egg_body(p.mat)]


def golden():
    p = Paint("Gold")
    a = p.math("MULTIPLY", angle_of(p), 10 / (2 * math.pi))  # 10 diamonds around
    z = p.math("MULTIPLY", height(p), 1.4)
    l1 = p.stripes(p.math("ADD", a, z), 1.0, 0.1, soft=0.05)
    l2 = p.stripes(p.math("SUBTRACT", a, z), 1.0, 0.1, soft=0.05)
    lines = p.math("MAXIMUM", l1, l2)
    shine = p.ramp(p.noise(1.4, detail=2), [(0.3, (225, 150, 25)), (0.6, (255, 200, 60)), (0.8, (255, 230, 130))])
    p.set(top_light(p, p.mix(shine, p.rgb((255, 245, 190)), p.math("MULTIPLY", lines, 0.85)), 0.25))
    return [egg_body(p.mat)]


def crystal():
    p = Paint("Crystal")
    t = p.math("DIVIDE", p.math("ADD", height(p), HALF), 2 * HALF, clamp=True)
    base = p.ramp(t, [(0, (150, 95, 240)), (0.6, (200, 160, 255)), (1, (240, 225, 255))])
    p.set(p.mix(base, p.rgb((255, 255, 255)), p.math("MULTIPLY", dots(p, 3.0, 0.06), 0.9)))
    return [egg_body(p.mat, segments=9, rings=8, smooth=False)]


def rainbow():
    p = Paint("Rainbow")
    t = p.math("DIVIDE", p.math("ADD", height(p), HALF), 2 * HALF, clamp=True)
    bands = [(255, 90, 100), (255, 165, 70), (255, 230, 90), (110, 220, 130), (100, 175, 255), (190, 130, 255)]
    stops = []
    for i, c in enumerate(bands):
        stops.append((i / len(bands), c))
    base = p.ramp(t, stops, interpolation="CONSTANT")
    p.set(p.mix(base, p.rgb((255, 255, 255)), dots(p, 4.0, 0.06)))
    return [egg_body(p.mat)]


def galaxy():
    p = Paint("Galaxy")
    neb = p.noise(0.9, detail=4, distortion=0.8)
    base = p.ramp(neb, [(0.3, (25, 12, 60)), (0.5, (70, 40, 160)), (0.7, (210, 90, 210))])
    stars = dots(p, 4.5, 0.06)
    big = dots(p, 1.3, 0.05, randomness=0.7)
    p.set(p.mix(base, p.rgb((255, 255, 255)), p.math("MAXIMUM", stars, big)))
    ring = gradient_paint("Ring", (120, 220, 255), (255, 150, 240), R(-2.6, 0, 0), R(2.6, 0, 0))
    return [egg_body(p.mat), torus("Ring", R(0, -0.2, 0), R(0.35, 1, 0.2), 2.75, 0.22, ring, segments=40,
                                    sides=8, squash=0.35)]


def wing_outline():
    pts = [(0, 0), (0.5, 0.75), (1.3, 1.1), (2.1, 1.0)]
    # scalloped bottom edge: three feathers
    for x, y in ((1.9, 0.55), (1.65, 0.45), (1.55, 0.1), (1.25, 0.05), (1.1, -0.3), (0.75, -0.3), (0.55, -0.55)):
        pts.append((x, y))
    pts.append((0.15, -0.4))
    return [(x * 1.35, y * 1.35) for x, y in pts]


def divine():
    p = Paint("Divine")
    t = p.math("DIVIDE", p.math("ADD", height(p), HALF), 2 * HALF, clamp=True)
    base = p.ramp(t, [(0, (255, 214, 110)), (0.45, (255, 245, 215)), (1, (255, 255, 250))])
    band = p.math("SUBTRACT", 1.0, p.step(0.22, p.math("ABSOLUTE", p.math("ADD", height(p), 0.15)), soft=0.04))
    gems = dots(p, 2.4, 0.12, randomness=0.0)
    trim = p.mix(p.rgb((245, 185, 60)), p.rgb((120, 220, 255)), gems)
    p.set(p.mix(base, trim, band))
    gold = gradient_paint("Halo", (240, 180, 50), (255, 240, 150), R(0, 2.6, 0), R(0, 3.4, 0))
    feather = Paint("Wing")
    feather.set(feather.ramp(feather.stripes(feather.along(R(0, 1, 0)), 0.35, 0.5, soft=0.25),
                             [(0, (235, 240, 255)), (1, (255, 255, 255))]))
    parts = [egg_body(p.mat), torus("Halo", R(0, 3.15, 0), UP, 1.25, 0.2, gold, segments=36, sides=10)]
    for s in (-1, 1):
        # outline x runs toward Roblox -Z, so flip it to point away from the egg
        outline = [(-x * s, y) for x, y in wing_outline()]
        if s > 0:
            outline.reverse()
        parts.append(slab("Wing", outline, 0.25, feather.mat, R(-0.3, 0.7, 1.55 * s), axis=R(1, 0, 0.8 * s), up=UP,
                          bevel=0.06, smooth=True))
    return parts


# Names copied from Config.Eggs.
TIERS = [
    ("Plain Egg", plain),
    ("Mint Egg", mint),
    ("Sky Egg", sky),
    ("Golden Egg", golden),
    ("Crystal Egg", crystal),
    ("Rainbow Egg", rainbow),
    ("Galaxy Egg", galaxy),
    ("Divine Egg", divine),
]
