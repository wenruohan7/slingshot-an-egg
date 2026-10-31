"""The three shop stands in the hub: Slingshot Shop, Egg Shop and Rebirth.

Each sits on the floor at the origin with its counter facing -Z (Roblox's
front), about 17 studs wide. The game puts the shop's name sign above it.
"""

import math

from mathutils import Matrix

from common import (R, Paint, box, crystal, flat, gradient_paint, lathe, rod, skin, slab, sphere,
                    star_outline, torus)

UP = R(0, 1, 0)
FRONT = R(0, 0, -1)

WIDTH = 15.0  # between the posts
DECK_Y = 0.8  # top of the wooden deck
COUNTER_Z = -2.6
BACK_Z = 3.6
ROOF_BACK_Y = 11.2
ROOF_FRONT_Y = 9.6


def planks(name, light, dark, along=(1, 0, 0), period=1.3):
    p = Paint(name)
    grain = p.noise(2.0, detail=4, vec=p.scaled(*(0.3 if a else 4.0 for a in along)))
    wood = p.ramp(grain, [(0.3, dark), (0.75, light)])
    across = [1 - abs(a) for a in along]
    across_dir = R(*across) if sum(across) else R(0, 1, 0)
    seams = p.stripes(p.along(across_dir), period, 0.06, soft=0.03)
    return p.set(p.mix(wood, p.rgb(tuple(int(c * 0.6) for c in dark)), seams))


def candy_stripes(name, a, b, direction, period, soft=0.06, width=0.5):
    p = Paint(name)
    s = p.stripes(p.along(direction), period, width, soft=soft)
    return p.set(p.mix(p.rgb(a), p.rgb(b), s))


def kiosk(color, light, panel=None):
    """Deck, counter, back wall, candy-cane posts and a striped awning with a
    scalloped edge. Returns the parts; each stand adds its own decorations."""
    wood = planks("Deck", (205, 150, 100), (150, 100, 62))
    wall = planks("Wall", (225, 180, 130), (175, 125, 85), along=(0, 1, 0), period=1.5)
    trim = flat("Trim", (255, 255, 255))
    parts = [
        box("Deck", R(0, DECK_Y / 2, 0.4), (WIDTH + 2.4, DECK_Y, 10.4), wood, bevel=0.2),
        box("BackWall", R(0, DECK_Y + 4.4, BACK_Z), (WIDTH, 8.8, 0.8), wall, bevel=0.1),
    ]
    # counter: a striped front panel in the shop's colour under a wooden top
    front = panel or candy_stripes("CounterFront", color, light, R(1, 0, 0), 1.5, width=0.5)
    parts.append(box("Counter", R(0, DECK_Y + 1.8, COUNTER_Z), (WIDTH - 1.2, 3.6, 2.2), front, bevel=0.15))
    parts.append(box("CounterTop", R(0, DECK_Y + 3.8, COUNTER_Z - 0.1), (WIDTH - 0.4, 0.45, 3.0), wood, bevel=0.15))
    parts.append(box("CounterBase", R(0, DECK_Y + 0.2, COUNTER_Z - 0.2), (WIDTH - 0.6, 0.4, 2.6), trim, bevel=0.1))

    post = candy_stripes("Post", color, (255, 255, 255), R(0, 1, 0.9), 1.1, width=0.5)
    cap = flat("PostCap", color)
    for x in (-WIDTH / 2, WIDTH / 2):
        for z, top in ((COUNTER_Z - 1.6, ROOF_FRONT_Y + 0.1), (BACK_Z - 0.2, ROOF_BACK_Y - 0.1)):
            parts.append(rod("Post", R(x, DECK_Y, z), R(x, top, z), 0.42, 0.42, post, segments=14))
            parts.append(sphere("PostCap", R(x, DECK_Y + 0.15, z), (0.6, 0.6, 0.3), cap, segments=14, rings=6))

    # awning sloping down to the front, striped across
    depth = (BACK_Z + 0.8) - (COUNTER_Z - 2.8)
    rise = ROOF_BACK_Y - ROOF_FRONT_Y
    angle = math.atan2(rise, depth)
    length = math.hypot(depth, rise)
    awning = candy_stripes("Awning", color, (255, 255, 255), R(1, 0, 0), 1.7, soft=0.03)
    mid_z = (BACK_Z + 0.8 + COUNTER_Z - 2.8) / 2
    tilt = Matrix.Rotation(-angle, 3, "X")
    parts.append(box("Awning", R(0, (ROOF_BACK_Y + ROOF_FRONT_Y) / 2 + 0.3, mid_z), (WIDTH + 2.0, 0.5, length),
                     awning, bevel=0.15, rot=tilt))
    # scallops hanging off the front edge; they line up with the stripes
    count = 10
    span = WIDTH + 2.0
    for i in range(count):
        x = -span / 2 + span * (i + 0.5) / count
        parts.append(sphere("Scallop", R(x, ROOF_FRONT_Y - 0.15, COUNTER_Z - 2.85), (span / count / 2, 0.25, 0.75),
                            awning, segments=14, rings=8))
    return parts


def mini_slingshot(name, center, scale, frame_mat, tip_mat, facing=FRONT, subdiv=2):
    """A slingshot shape for signs: fork in the plane facing `facing`."""
    side = UP.cross(facing).normalized()
    pts = [center + UP * (y * scale) + side * (z * scale) for y, z in
           ((-6, 0), (-3, 0), (0, 0), (1.3, 1.8), (3.4, 3.5), (5.2, 4.0), (6, 4.0),
            (1.3, -1.8), (3.4, -3.5), (5.2, -4.0), (6, -4.0))]
    edges = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (2, 7), (7, 8), (8, 9), (9, 10)]
    radii = [r * scale for r in (0.8, 0.8, 0.9, 0.75, 0.68, 0.64, 0.62, 0.75, 0.68, 0.64, 0.62)]
    parts = [skin(name, pts, edges, radii, frame_mat, subdiv=subdiv)]
    for i in (6, 10):
        parts.append(sphere(name + "Tip", pts[i], 0.95 * scale, tip_mat, segments=16, rings=10))
    band = flat(name + "Band", (235, 60, 110))
    parts.append(rod(name + "Band", pts[6], pts[10], 0.22 * scale, 0.22 * scale, band, segments=8))
    return parts


def egg(name, center, mat, scale=1.0, segments=20):
    prof = []
    rings = 12
    for i in range(rings + 1):
        th = math.pi * i / rings
        prof.append((math.sin(th) * (1 + 0.16 * math.cos(th)) * 0.86 * scale, -1.25 * scale * math.cos(th)))
    return lathe(name, prof, mat, center=center, segments=segments)


def spotted(name, base, spot, scale=1.6):
    p = Paint(name)
    d = p.math("SUBTRACT", 1.0, p.step(0.22, p.voronoi(scale, randomness=0.6), soft=0.04))
    return p.set(p.mix(p.rgb(base), p.rgb(spot), d))


def slingshot_shop():
    pink, light = (255, 120, 160), (255, 205, 220)
    parts = kiosk(pink, light)
    wood = planks("SignWood", (200, 140, 90), (140, 92, 56))
    # a bullseye target on the back wall
    rings = Paint("Target")
    x, y, z = rings.xyz(rings.vmath("SUBTRACT", rings.pos, R(0, DECK_Y + 6.4, BACK_Z)))
    r = rings.math("DIVIDE", rings.math("SQRT", rings.math("ADD", rings.math("MULTIPLY", x, x),
                                                          rings.math("MULTIPLY", z, z))), 2.6)
    rings.set(rings.ramp(r, [(0, (255, 70, 90)), (0.2, (255, 255, 255)), (0.4, (255, 70, 90)),
                             (0.6, (255, 255, 255)), (0.8, (255, 70, 90))], interpolation="CONSTANT"))
    parts.append(rod("Target", R(0, DECK_Y + 6.4, BACK_Z - 0.4), R(0, DECK_Y + 6.4, BACK_Z - 0.75), 2.6, 2.6,
                     rings.mat, segments=32))
    parts.append(torus("TargetRim", R(0, DECK_Y + 6.4, BACK_Z - 0.6), FRONT, 2.6, 0.2, wood, segments=32, sides=8))
    # slingshots hanging on the wall either side of the target
    tip = flat("ShopTip", pink)
    for sx in (-4.8, 4.8):
        parts += mini_slingshot("Hanging", R(sx, DECK_Y + 6.2, BACK_Z - 0.75), 0.28,
                                planks("HangWood", (196, 140, 92), (138, 92, 56), along=(0, 1, 0)), tip, subdiv=1)
    # a big slingshot standing on the roof
    big_wood = Paint("BigWood")
    big_wood.set(big_wood.ramp(big_wood.noise(2.0, detail=4, vec=big_wood.scaled(3, 3, 0.35)),
                               [(0.3, (150, 100, 62)), (0.7, (205, 150, 100))]))
    parts += mini_slingshot("Big", R(0, ROOF_BACK_Y + 3.3, 1.2), 0.42, big_wood.mat, tip)
    # some eggs-for-ammo in a crate on the counter
    parts.append(box("Crate", R(4.6, DECK_Y + 4.5, COUNTER_Z), (2.6, 1.0, 1.8), wood, bevel=0.1))
    for i, c in enumerate(((255, 250, 235), (170, 240, 200), (140, 200, 255))):
        parts.append(egg("CrateEgg", R(3.8 + 0.8 * i, DECK_Y + 5.3, COUNTER_Z), flat("CrateEgg", c), 0.45, 14))
    return parts


def egg_shop():
    yellow, light = (255, 205, 80), (255, 240, 190)
    parts = kiosk(yellow, light, panel=candy_stripes("CounterFront", yellow, (255, 255, 255), R(1, 0, 0), 1.5))
    wood = planks("ShelfWood", (215, 160, 105), (155, 105, 65))
    # two shelves of eggs on the back wall
    colors = [((255, 250, 235), (215, 175, 130)), ((170, 240, 200), (110, 205, 160)), ((140, 200, 255), (255, 255, 255)),
              ((255, 205, 60), (255, 240, 160)), ((200, 160, 255), (255, 255, 255)), ((255, 130, 210), (255, 230, 120))]
    k = 0
    for shelf_y in (DECK_Y + 4.6, DECK_Y + 7.4):
        parts.append(box("Shelf", R(0, shelf_y, BACK_Z - 0.8), (WIDTH - 1.6, 0.35, 1.2), wood, bevel=0.08))
        for sx in (-4.2, 0, 4.2):
            base, spot = colors[k]
            k += 1
            parts.append(egg("ShelfEgg", R(sx, shelf_y + 1.15, BACK_Z - 0.8), spotted("ShelfEgg", base, spot), 0.85))
    # a nest of eggs on the counter
    straw = Paint("Straw")
    straw.set(straw.ramp(straw.noise(6.0, detail=5, distortion=1.5), [(0.3, (175, 120, 55)), (0.7, (230, 185, 100))]))
    parts.append(torus("Nest", R(-4.2, DECK_Y + 4.35, COUNTER_Z), UP, 1.25, 0.5, straw.mat, segments=24, sides=10))
    parts.append(sphere("NestBottom", R(-4.2, DECK_Y + 4.1, COUNTER_Z), (1.3, 1.3, 0.3), straw.mat, segments=16, rings=6))
    for (dx, dz), c in zip(((-0.45, -0.3), (0.5, -0.2), (0.0, 0.45)), ((255, 140, 180), (120, 210, 255), (255, 230, 90))):
        parts.append(egg("NestEgg", R(-4.2 + dx, DECK_Y + 4.9, COUNTER_Z + dz), spotted("NestEgg", c, (255, 255, 255), 3.0),
                         0.5, 14))
    # a giant spotted egg on the roof, sitting in a nest
    parts.append(egg("BigEgg", R(0, ROOF_BACK_Y + 3.0, 1.2), spotted("BigEgg", (255, 225, 120), (255, 160, 70), 0.9), 2.2, 28))
    parts.append(torus("BigNest", R(0, ROOF_BACK_Y + 0.9, 1.2), UP, 2.0, 0.6, straw.mat, segments=28, sides=10))
    return parts


def rebirth():
    purple, light = (150, 110, 255), (220, 200, 255)
    stone = Paint("Stone")
    stone.set(stone.ramp(stone.noise(1.4, detail=5), [(0.3, (96, 80, 150)), (0.7, (140, 122, 196))]))
    tiles = Paint("Tiles")
    t = tiles.math("MAXIMUM", tiles.stripes(tiles.along(R(1, 0, 0)), 2.0, 0.06, soft=0.03),
                   tiles.stripes(tiles.along(R(0, 0, 1)), 2.0, 0.06, soft=0.03))
    tiles.set(tiles.mix(tiles.ramp(tiles.noise(2.0), [(0.3, (170, 150, 220)), (0.7, (205, 190, 245))]),
                        tiles.rgb((110, 90, 170)), t))
    parts = [lathe("Platform", [(0, 0), (8.6, 0), (8.6, 0.6), (8.2, 1.0), (0, 1.0)], tiles.mat, segments=40)]
    parts.append(lathe("Step", [(0, 0), (9.4, 0), (9.4, 0.4), (0, 0.4)], stone.mat, segments=40))

    # an arch of stone with a swirling portal in it
    arch_y = 1.0
    for x in (-5.2, 5.2):
        parts.append(box("Pillar", R(x, arch_y + 3.6, 2.0), (1.8, 7.2, 1.8), stone.mat, bevel=0.2))
        parts.append(box("PillarCap", R(x, arch_y + 0.35, 2.0), (2.4, 0.7, 2.4), stone.mat, bevel=0.12))
    parts.append(torus("Arch", R(0, arch_y + 7.2, 2.0), R(0, 0, 1), 5.2, 0.95, stone.mat, segments=24, sides=10,
                       arc=math.pi))
    swirl = Paint("Portal")
    x, y, z = swirl.xyz(swirl.vmath("SUBTRACT", swirl.pos, R(0, arch_y + 7.2, 2.0)))
    ang = swirl.math("ARCTAN2", z, x)
    rr = swirl.math("SQRT", swirl.math("ADD", swirl.math("MULTIPLY", x, x), swirl.math("MULTIPLY", z, z)))
    tt = swirl.math("FRACT", swirl.math("ADD", swirl.math("MULTIPLY", ang, 3 / (2 * math.pi)),
                                         swirl.math("MULTIPLY", rr, 0.35)))
    swirl.set(swirl.ramp(tt, [(0, (90, 40, 200)), (0.5, (190, 140, 255)), (0.75, (255, 220, 255)), (1, (90, 40, 200))]))
    portal = lathe("Portal", [(0, 0), (4.4, 0), (4.4, 0.25), (0, 0.25)], swirl.mat, center=R(0, arch_y + 7.2, 2.1),
                   axis=R(0, 0, -1), segments=40)
    parts.append(portal)
    # the portal disc only fills the arch's round top; a rectangle fills below
    parts.append(box("PortalLow", R(0, arch_y + 3.6, 2.0), (8.6, 7.2, 0.25), swirl.mat))

    gem = gradient_paint("Gem", (150, 90, 255), (255, 240, 255), R(0, 1, 0), R(0, 6, 0))
    for sx in (-1, 1):
        base = R(sx * 7.0, 1.0, -1.0)
        parts.append(crystal("Crystal", base, R(0.1 * sx, 1, 0), 0.9, 4.0, gem))
        parts.append(crystal("Crystal", base + R(0.6 * sx, 0, 0.5), R(0.5 * sx, 1, 0.2), 0.55, 2.6, gem, twist=0.4))
        parts.append(crystal("Crystal", base + R(-0.3 * sx, 0, -0.7), R(-0.1, 1, -0.5), 0.5, 2.2, gem, twist=0.8))
    star = gradient_paint("Star", (255, 200, 60), (255, 245, 170), R(0, 12, 0), R(0, 15, 0))
    parts.append(slab("Star", star_outline(5, 1.6, 0.7), 0.7, star, R(0, arch_y + 14.6, 2.0), axis=FRONT, up=UP,
                      bevel=0.12, smooth=True))
    # the altar counter in front
    front = candy_stripes("Altar", purple, light, R(1, 0, 0), 1.4)
    parts.append(box("Altar", R(0, 2.6, -3.2), (8.0, 3.2, 2.2), front, bevel=0.2))
    parts.append(box("AltarTop", R(0, 4.35, -3.2), (8.8, 0.4, 2.8), stone.mat, bevel=0.15))
    orb = gradient_paint("Orb", (180, 120, 255), (255, 245, 255), R(0, 4.6, 0), R(0, 6.4, 0))
    parts.append(sphere("Orb", R(0, 5.6, -3.2), 0.9, orb, segments=24, rings=14))
    parts.append(torus("OrbStand", R(0, 4.75, -3.2), UP, 0.6, 0.22, stone.mat, segments=20, sides=8))
    return parts


# Names match the shop titles in src/shared/Shops.luau.
STANDS = [
    ("Slingshot Shop", slingshot_shop),
    ("Egg Shop", egg_shop),
    ("Rebirth", rebirth),
]
