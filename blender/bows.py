"""The 12 bows from Config.Slingshots, one model each.

Only the bow itself is modelled here (stave, grip and decorations). The game
still builds the bowstring and the nock, so the string keeps drawing back when
you charge. The bow is drawn in the same space as the built-in bow in
SlingshotModel.luau, before its 0.4 scale: the hand holds the grip at the
origin, the grip runs from Y = -1.2 to 1.2, the limbs curve back toward the
player, and the two tips (where the string ties on) are at X = -2.4,
Y = +6.5 and -6.5. +X is forward, where the egg flies; the bow lies in the
X-Y plane.
"""

import math

from common import R, Paint, box, crystal, flat, ico, lathe, rod, skin, slab, sphere, star_outline, torus
from slingshots import crescent, flame, gradient, grip_wrap, leaf, swirl, wood

FORWARD = R(1, 0, 0)
UP = R(0, 1, 0)
SIDE = R(0, 0, 1)

GRIP_HALF = 1.2
LIMB_LENGTH = 5.3
LIMB_CURVE = 2.4
TIP_TOP = (-LIMB_CURVE, GRIP_HALF + LIMB_LENGTH, 0)
TIP_BOTTOM = (-LIMB_CURVE, -(GRIP_HALF + LIMB_LENGTH), 0)
TIPS = (TIP_TOP, TIP_BOTTOM)
NOCK = (-LIMB_CURVE, 0, 0)  # middle of the string at rest


def limb_point(t, side):
    """A point on the upper (side 1) or lower (side -1) limb; t from 0 (grip) to 1 (tip).
    Matches limbPoint in SlingshotModel.luau so the string ties on at the tips."""
    return (-LIMB_CURVE * t * t, side * (GRIP_HALF + LIMB_LENGTH * t), 0)


def stave_points(steps=6):
    """Skeleton of the bow from the bottom tip, through the grip, to the top tip."""
    pts = []
    for i in range(steps, 0, -1):
        pts.append(limb_point(i / steps, -1))
    pts.append((0, -GRIP_HALF, 0))
    pts.append((0, 0, 0))
    pts.append((0, GRIP_HALF, 0))
    for i in range(1, steps + 1):
        pts.append(limb_point(i / steps, 1))
    return pts


def stave(name, mat, thick=1.0, subdiv=2):
    pts = stave_points()
    n = len(pts)
    mid = n // 2
    radii = []
    for i in range(n):
        d = abs(i - mid) / mid  # 0 at the grip, 1 at the tips
        if d <= 1 / mid + 1e-6:
            r = 0.82
        else:
            r = 0.68 - 0.32 * d
        radii.append(r * thick)
    edges = [(i, i + 1) for i in range(n - 1)]
    return skin(name, [R(*p) for p in pts], edges, radii, mat, subdiv=subdiv)


def nocks(name, mat, radius=0.5):
    """Little caps on the tips, where the string ties on."""
    return [sphere(name, R(*t), radius, mat, segments=16, rings=10) for t in TIPS]


def limb_spot(t, side, out=0.0):
    """A point on a limb, pushed `out` studs forward off its front face."""
    x, y, z = limb_point(t, side)
    return R(x + out, y, z)


def grip(name, base, stripe, rim=None, radius=0.95, period=0.6):
    return grip_wrap(name, -GRIP_HALF + 0.1, GRIP_HALF - 0.1, base, stripe, rim=rim, radius=radius, period=period)


# ---------------------------------------------------------------- the tiers


def wooden(look):
    parts = [stave("Stave", wood("Wood", (196, 140, 92), (138, 92, 56)))]
    parts += nocks("Nock", flat("Pink", look["accent"]))
    parts += grip("Grip", look["accent"], (255, 245, 250))
    return parts


def sturdy(look):
    parts = [stave("Stave", wood("DarkWood", (140, 96, 62), (92, 60, 38)), thick=1.2)]
    metal = gradient("Steel", (150, 155, 165), (225, 228, 235), -6.5, 6.5)
    parts += grip("Grip", (45, 45, 50), (240, 240, 240), rim=(200, 204, 212), radius=1.1, period=0.45)
    for side in (-1, 1):
        tip = R(*TIPS[0 if side > 0 else 1])
        parts.append(sphere("Cap", tip, 0.62, metal, segments=16, rings=10))
        parts.append(torus("LimbRing", limb_spot(0.45, side), UP, 0.66, 0.16, metal, segments=20, sides=8))
    parts.append(box("ArrowRest", R(0.55, GRIP_HALF + 0.35, 0), (0.6, 0.3, 0.9), metal, bevel=0.08))
    return parts


def leafy(look):
    p = Paint("Vine")
    p.set(p.ramp(p.noise(2.5, vec=p.scaled(4, 4, 0.5)), [(0.35, (70, 130, 50)), (0.65, (130, 190, 85))]))
    parts = [stave("Stave", p.mat, thick=0.95)]
    lp = Paint("Leaf")
    lp.set(lp.ramp(lp.noise(4.0), [(0.3, (60, 160, 60)), (0.7, (120, 215, 90))]))
    for side in (-1, 1):
        for t, s in ((0.3, 1), (0.6, -1)):
            parts.append(leaf("Leaf", lp.mat, limb_spot(t, side, 0.3), R(0.7, 0.4 * side, 0.9 * s), 2.2, 1.0))
    petal = flat("Petal", (255, 250, 240))
    center = flat("FlowerMiddle", look["accent"])
    for t in TIPS:
        c = R(*t)
        parts.append(sphere("FlowerMiddle", c, 0.5, center, segments=16, rings=10))
        for i in range(5):
            a = 2 * math.pi * i / 5
            off = R(math.cos(a), 0, math.sin(a)) * 0.7
            parts.append(sphere("Petal", c + off, (0.42, 0.34, 0.18), petal, segments=14, rings=8, axis=UP))
    parts += grip("Grip", (150, 105, 60), (240, 225, 160), radius=0.92, period=0.45)
    return parts


def iron(look):
    p = Paint("Iron")
    p.set(p.ramp(p.noise(6.0, vec=p.scaled(1, 1, 10)), [(0.3, (128, 134, 146)), (0.7, (188, 193, 203))]))
    dark = flat("DarkIron", look["accent"])
    parts = []
    pts = stave_points(steps=4)
    for a, b in zip(pts, pts[1:]):
        parts.append(rod("Bar", R(*a), R(*b), 0.66, 0.66, p.mat, segments=8, smooth=False))
    for q in pts[1:-1]:
        parts.append(ico("Joint", R(*q), 0.68, p.mat, subdiv=1))
    for t in TIPS:
        c = R(*t)
        parts.append(rod("Nut", c - FORWARD * 0.45, c + FORWARD * 0.45, 0.8, 0.8, dark, segments=6, smooth=False))
    parts.append(box("Plate", R(0.2, 0, 0), (1.6, 3.2, 1.7), dark, bevel=0.15))
    for y in (-1.0, 1.0):
        for z in (-0.5, 0.5):
            parts.append(rod("Rivet", R(1.0, y, z), R(1.2, y, z), 0.2, 0.16, p.mat, segments=8))
    return parts


def candy(look):
    p = Paint("CandyStripe")
    stripe = p.stripes(p.along(R(0.5, 1, 0)), 1.1, 0.5, soft=0.06)
    p.set(p.mix(p.rgb(look["frame"]), p.rgb((255, 255, 255)), stripe))
    parts = [stave("Stave", p.mat)]
    for t in TIPS:
        c = R(*t) + FORWARD * -0.1
        mat = swirl("Lolly", c, [(255, 120, 180), (255, 255, 255), (120, 210, 255), (255, 255, 255)], arms=2)
        parts.append(rod("Lolly", c - SIDE * 0.3, c + SIDE * 0.3, 1.2, 1.2, mat, segments=28))
        parts.append(torus("LollyRim", c, SIDE, 1.2, 0.3, mat, segments=28, sides=8))
    drop = Paint("Gumdrop")
    drop.set(drop.ramp(drop.noise(14.0), [(0.4, (100, 195, 245)), (0.6, (165, 230, 255))]))
    parts.append(lathe("Gumdrop", [(0, 0), (0.9, 0), (0.95, 0.2), (0.8, 0.65), (0.45, 1.0), (0, 1.1)], drop.mat,
                       center=R(0.7, 0, 0), axis=FORWARD, segments=24))
    parts += grip("Grip", (255, 255, 255), look["band"], radius=0.94, period=0.7)
    return parts


def golden(look):
    p = Paint("Gold")
    shine = p.noise(1.8, detail=2, vec=p.scaled(1, 1, 0.5))
    band = p.stripes(p.along(R(0.3, 1, 0)), 3.0, 0.12, soft=0.5)
    c = p.ramp(shine, [(0.3, (222, 150, 30)), (0.6, (255, 205, 70)), (0.8, (255, 236, 150))])
    p.set(p.mix(c, p.rgb((255, 246, 200)), p.math("MULTIPLY", band, 0.5)))
    parts = [stave("Stave", p.mat, thick=1.05)]
    ruby = gradient("Ruby", (150, 10, 30), (255, 70, 90), -0.8, 0.8)
    parts.append(ico("Ruby", R(0.95, 0, 0), 0.8, ruby, subdiv=1, scale=(1, 0.55, 1), axis=FORWARD))
    parts.append(torus("RubySetting", R(0.85, 0, 0), FORWARD, 0.8, 0.16, p.mat, segments=24, sides=8))
    diamond = gradient("Diamond", (150, 220, 255), (255, 255, 255), 6, 8)
    pale = flat("PaleGold", look["accent"])
    for side, t in ((1, TIP_TOP), (-1, TIP_BOTTOM)):
        parts.append(sphere("Tip", R(*t), 0.6, pale, segments=18, rings=10))
        parts.append(crystal("TipGem", R(*t), UP * side, 0.4, 1.3, diamond, sides=6))
    parts += grip("Grip", (190, 30, 40), (255, 210, 80), rim=(255, 220, 110), radius=1.0)
    return parts


def ice(look):
    p = Paint("Ice")
    p.set(p.ramp(p.noise(5.0, detail=5), [(0.35, (150, 215, 250)), (0.55, (200, 238, 255)), (0.75, (255, 255, 255))]))
    parts = [stave("Stave", p.mat)]
    shard = gradient("Shard", (120, 190, 255), (245, 252, 255), -9, 9)
    for side, t in ((1, TIP_TOP), (-1, TIP_BOTTOM)):
        base = R(*t)
        parts.append(crystal("Shard", base, R(0, side, 0), 0.5, 2.2, shard))
        parts.append(crystal("Shard", base, R(0.6, side * 0.8, 0.3), 0.32, 1.4, shard, twist=0.4))
        parts.append(crystal("Shard", base, R(-0.2, side * 0.8, -0.5), 0.3, 1.2, shard, twist=0.7))
    # icicles hanging off the front of the lower limb
    for t, length in ((0.25, 1.2), (0.5, 0.9), (0.75, 0.6)):
        top = limb_spot(t, -1, 0.35)
        parts.append(rod("Icicle", top, top - UP * length, 0.22, 0.0, shard, segments=6, smooth=False))
    snow = flat("Snow", (250, 252, 255))
    parts.append(sphere("Snow", R(0.1, GRIP_HALF + 0.3, 0), (1.0, 0.9, 0.5), snow, segments=20, rings=10))
    parts += grip("Grip", (80, 160, 255), (255, 255, 255), radius=0.94, period=0.5)
    return parts


def lava(look):
    p = Paint("Basalt")
    cracks = p.voronoi(1.6, feature="DISTANCE_TO_EDGE")
    glow = p.math("SUBTRACT", 1.0, p.step(0.07, cracks, soft=0.06))
    rock = p.ramp(p.noise(4.0, detail=4), [(0.35, (40, 26, 26)), (0.7, (82, 56, 52))])
    hot = p.ramp(p.noise(3.0), [(0.3, (255, 90, 20)), (0.7, (255, 190, 50))])
    p.set(p.mix(rock, hot, glow))
    parts = [stave("Stave", p.mat, thick=1.1)]
    fire = gradient("Fire", (255, 80, 20), (255, 236, 120), 6.2, 8.8, extra=(255, 160, 30))
    parts.append(flame("Flame", R(*TIP_TOP) - UP * 0.3, fire, scale=1.0))
    fire_low = gradient("FireLow", (255, 80, 20), (255, 200, 80), -7, -5.5)
    parts.append(ico("Ember", R(*TIP_BOTTOM), 0.65, fire_low, subdiv=1))
    rocks = flat("Rock", (70, 46, 42))
    for pos, r in (((0.7, 0.6, 0.4), 0.45), ((0.6, -0.7, -0.4), 0.4)):
        parts.append(ico("Rock", R(*pos), r, rocks, subdiv=1))
    parts += grip("Grip", (45, 30, 28), (255, 120, 30), radius=0.98, period=0.45)
    return parts


def crystal_tier(look):
    gem = gradient("Amethyst", (120, 70, 200), (215, 180, 255), -6.5, 6.5)
    parts = [stave("Stave", gem, subdiv=1)]
    parts[0].data.shade_flat()
    shard = gradient("CrystalShard", (170, 110, 255), (255, 250, 255), -9, 9)
    for side, t in ((1, TIP_TOP), (-1, TIP_BOTTOM)):
        base = R(*t)
        parts.append(crystal("Crystal", base, R(-0.15, side, 0), 0.55, 2.4, shard, twist=0.3))
        parts.append(crystal("Crystal", base, R(0.5, side * 0.8, 0.35), 0.35, 1.5, shard))
    parts.append(crystal("Heart", R(0.6, 0, 0), FORWARD, 0.7, 1.6, shard, sides=6))
    parts += grip("Grip", (110, 60, 200), (255, 255, 255), radius=0.94)
    return parts


def rainbow(look):
    p = Paint("Rainbow")
    t = p.math("DIVIDE", p.math("ADD", p.along(UP), 6.5), 13.0, clamp=True)
    p.set(p.ramp(t, [(0.0, (255, 80, 90)), (0.2, (255, 160, 60)), (0.4, (255, 230, 80)),
                     (0.6, (100, 220, 120)), (0.8, (90, 170, 255)), (1.0, (190, 120, 255))]))
    parts = [stave("Stave", p.mat)]
    star = gradient("Star", (255, 200, 40), (255, 245, 150), -8, 8)
    for tpos in TIPS:
        parts.append(slab("Star", star_outline(5, 1.2, 0.55), 0.55, star, R(*tpos), axis=SIDE, up=UP,
                          bevel=0.1, smooth=True))
    cloud = flat("Cloud", (255, 255, 255))
    for pos, r in (((0.8, 0, 0), 0.75), ((0.7, 0.55, 0.5), 0.55), ((0.7, -0.55, -0.5), 0.55)):
        parts.append(sphere("Cloud", R(*pos), r, cloud, segments=16, rings=10))
    parts += grip("Grip", (255, 255, 255), (255, 130, 200), radius=0.94, period=0.7)
    return parts


def galaxy(look):
    p = Paint("Space")
    neb = p.noise(1.4, detail=4, distortion=0.6)
    base = p.ramp(neb, [(0.35, (34, 16, 82)), (0.55, (80, 40, 160)), (0.75, (200, 80, 200))])
    stars = p.math("SUBTRACT", 1.0, p.step(0.07, p.voronoi(4.0, randomness=1.0), soft=0.03))
    p.set(p.mix(base, p.rgb((255, 255, 255)), stars))
    parts = [stave("Stave", p.mat)]
    planet = Paint("Planet")
    planet.set(planet.ramp(planet.stripes(planet.along(UP), 0.4, 0.5, soft=0.3),
                           [(0, (110, 190, 255)), (1, (180, 240, 255))]))
    ring = flat("PlanetRing", (255, 150, 240))
    for t in TIPS:
        c = R(*t)
        parts.append(sphere("Planet", c, 0.8, planet.mat, segments=22, rings=12))
        parts.append(torus("Ring", c, R(0.35, 1, 0.25), 1.2, 0.12, ring, segments=32, sides=6, squash=0.4))
    glow = gradient("StarGlow", (255, 120, 255), (255, 230, 255), -1.2, 1.2)
    parts.append(slab("Star", star_outline(4, 1.2, 0.4), 0.45, glow, R(0.8, 0, 0), axis=FORWARD, up=UP,
                      bevel=0.1, smooth=True))
    parts += grip("Grip", (30, 18, 70), (120, 220, 255), rim=(255, 120, 255), radius=0.96)
    return parts


def moon(look):
    p = Paint("Marble")
    veins = p.noise(1.2, detail=6, distortion=2.5)
    line = p.math("SUBTRACT", 1.0, p.step(0.05, p.math("ABSOLUTE", p.math("SUBTRACT", veins, 0.5)), soft=0.05))
    base = p.ramp(p.noise(2.0), [(0.3, (222, 224, 238)), (0.7, (246, 246, 252))])
    p.set(p.mix(base, p.rgb((150, 160, 200)), p.math("MULTIPLY", line, 0.7)))
    parts = [stave("Stave", p.mat)]
    gold = gradient("MoonGold", (240, 190, 70), (255, 240, 160), -8, 8)
    for s, t in ((1, TIP_TOP), (-1, TIP_BOTTOM)):
        # crescents at the tips, opening away from each other
        parts.append(crescent("Crescent", R(*t) + UP * (0.5 * s), 1.3, 0.5, gold, mirror=s))
        parts.append(torus("Trim", limb_spot(0.85, s), UP, 0.5, 0.13, gold, segments=20, sides=8))
    star = gradient("MoonStar", (140, 160, 255), (220, 230, 255), -1.2, 1.2)
    parts.append(slab("Star", star_outline(5, 1.0, 0.45), 0.45, star, R(0.8, 0, 0), axis=FORWARD, up=UP,
                      bevel=0.1, smooth=True))
    parts += grip("Grip", (140, 160, 255), (255, 255, 255), rim=(245, 210, 110), radius=0.96)
    return parts


# Names and colours copied from Config.Slingshots.
TIERS = [
    ("Wooden Bow", wooden, {"frame": (176, 122, 78), "accent": (255, 120, 160), "band": (235, 60, 110)}),
    ("Sturdy Bow", sturdy, {"frame": (120, 80, 50), "accent": (240, 240, 240), "band": (60, 60, 60)}),
    ("Leafy Bow", leafy, {"frame": (100, 160, 70), "accent": (255, 220, 90), "band": (80, 200, 90)}),
    ("Iron Bow", iron, {"frame": (150, 155, 165), "accent": (70, 75, 85), "band": (40, 40, 45)}),
    ("Candy Bow", candy, {"frame": (255, 150, 200), "accent": (255, 255, 255), "band": (120, 210, 255)}),
    ("Golden Bow", golden, {"frame": (255, 200, 60), "accent": (255, 240, 160), "band": (200, 40, 40)}),
    ("Ice Bow", ice, {"frame": (170, 230, 255), "accent": (255, 255, 255), "band": (80, 160, 255)}),
    ("Lava Bow", lava, {"frame": (60, 40, 40), "accent": (255, 110, 30), "band": (255, 170, 40)}),
    ("Crystal Bow", crystal_tier, {"frame": (190, 140, 255), "accent": (255, 255, 255), "band": (150, 90, 255)}),
    ("Rainbow Bow", rainbow, {"frame": (255, 120, 200), "accent": (120, 230, 255), "band": (255, 230, 80)}),
    ("Galaxy Bow", galaxy, {"frame": (60, 30, 120), "accent": (150, 220, 255), "band": (255, 120, 255)}),
    ("Moon Bow", moon, {"frame": (230, 230, 245), "accent": (255, 230, 120), "band": (140, 160, 255)}),
]
