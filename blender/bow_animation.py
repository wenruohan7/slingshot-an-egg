"""The bow draw and release animations, as Roblox KeyframeSequences.

Run with plain Python (numpy):

    python3 blender/bow_animation.py

It writes animations/BowDraw.rbxmx and animations/BowRelease.rbxmx, which Rojo
syncs into ReplicatedStorage.BowAnimations. Upload them from Studio to get the
animation ids (README: "Bow animations"). blender/bow_animation_preview.py
renders a picture of the poses.

The poses are solved, not hand-typed: a copy of the R15 block rig lives here
(joint offsets as in Studio's Rig Builder), and for every key the arms are
aimed so the bow points down the lane and the drawing hand sits exactly on the
bow's nock (same numbers as src/shared/SlingshotModel.luau). The draw
animation is one second long and the game scrubs it with the charge meter:
time 0 is the string at rest, time 1 is full draw.

Roblox space: +X right, +Y up, the character faces -Z. A Pose's CFrame is the
joint's Transform: Part1 = Part0 * C0 * Transform * C1:Inverse().
"""

import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "animations")

# ---------------------------------------------------------------------------
# Small rotation helpers (3x3 matrices, Roblox axes)
# ---------------------------------------------------------------------------


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def frame(x, y, z):
    """Rotation whose columns are the given axes."""
    return np.column_stack([x, y, z])


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    return t * t * (3 - 2 * t)


class CF:
    """A CFrame: rotation R and position p."""

    def __init__(self, R=None, p=(0, 0, 0)):
        self.R = np.eye(3) if R is None else np.asarray(R, dtype=float)
        self.p = np.asarray(p, dtype=float)

    def __mul__(self, o):
        return CF(self.R @ o.R, self.R @ o.p + self.p)

    def inv(self):
        return CF(self.R.T, -self.R.T @ self.p)

    def point(self, v):
        return self.R @ np.asarray(v, dtype=float) + self.p


# ---------------------------------------------------------------------------
# The R15 block rig
# ---------------------------------------------------------------------------

# part: size
PARTS = {
    "HumanoidRootPart": (2, 2, 1),
    "LowerTorso": (2, 0.4, 1),
    "UpperTorso": (2, 1.6, 1),
    "Head": (1.2, 1.2, 1.2),
    "LeftUpperArm": (1, 1.17, 1),
    "LeftLowerArm": (1, 1.05, 1),
    "LeftHand": (1, 0.3, 1),
    "RightUpperArm": (1, 1.17, 1),
    "RightLowerArm": (1, 1.05, 1),
    "RightHand": (1, 0.3, 1),
    "LeftUpperLeg": (1, 1.22, 1),
    "LeftLowerLeg": (1, 1.1, 1),
    "LeftFoot": (1, 0.3, 1),
    "RightUpperLeg": (1, 1.22, 1),
    "RightLowerLeg": (1, 1.1, 1),
    "RightFoot": (1, 0.3, 1),
}

# part1: (part0, C0 position, C1 position). All R15 rig attachments are
# unrotated, so C0 and C1 are plain offsets.
JOINTS = {
    "LowerTorso": ("HumanoidRootPart", (0, -1, 0), (0, -0.2, 0)),
    "UpperTorso": ("LowerTorso", (0, 0.2, 0), (0, -0.8, 0)),
    "Head": ("UpperTorso", (0, 0.8, 0), (0, -0.5, 0)),
    "LeftUpperArm": ("UpperTorso", (-1, 0.563, 0), (0.5, 0.418, 0)),
    "LeftLowerArm": ("LeftUpperArm", (0, -0.334, 0), (0, 0.192, 0)),
    "LeftHand": ("LeftLowerArm", (0, -0.501, 0), (0, 0.125, 0)),
    "RightUpperArm": ("UpperTorso", (1, 0.563, 0), (-0.5, 0.418, 0)),
    "RightLowerArm": ("RightUpperArm", (0, -0.334, 0), (0, 0.192, 0)),
    "RightHand": ("RightLowerArm", (0, -0.501, 0), (0, 0.125, 0)),
    "LeftUpperLeg": ("LowerTorso", (-0.5, -0.2, 0), (0, 0.42, 0)),
    "LeftLowerLeg": ("LeftUpperLeg", (0, -0.41, 0), (0, 0.33, 0)),
    "LeftFoot": ("LeftLowerLeg", (0, -0.55, 0), (0, 0.1, 0)),
    "RightUpperLeg": ("LowerTorso", (0.5, -0.2, 0), (0, 0.42, 0)),
    "RightLowerLeg": ("RightUpperLeg", (0, -0.41, 0), (0, 0.33, 0)),
    "RightFoot": ("RightLowerLeg", (0, -0.55, 0), (0, 0.1, 0)),
}

ORDER = list(JOINTS)  # parents always come before their children
CHILDREN = {name: [c for c, j in JOINTS.items() if j[0] == name] for name in PARTS}

# The R15 RightGripAttachment: 0.15 below the hand's middle, turned -90 degrees
# about X, so its -Z runs down the hand (where the arm points).
GRIP_ATTACHMENT = CF(rx(math.radians(-90)), (0, -0.15, 0))
GRIP_LENGTH = 0.125 + 0.15  # wrist to grip point, along the hand
UPPER = 0.418 + 0.334  # shoulder to elbow
LOWER = 0.192 + 0.501  # elbow to wrist
HAND_REACH = 0.125 + 0.15 + 0.08  # wrist to the hooked fingers

# The bow (SlingshotModel.luau): bow space +X forward, +Y up, grip at the origin.
# The tool's Grip lines the grip attachment's -Z up with the bow's +X and its +Y
# with the bow's +Y.
BOW_SCALE = 0.4
NOCK_REST = -2.4 * BOW_SCALE  # the nock sits this far behind the grip at rest
GRIP_FRAME = CF(frame((0, 0, 1), (0, 1, 0), (-1, 0, 0)))


def bow_frame(hand: CF) -> CF:
    """World frame of the bow's own space, given the right hand's world frame."""
    return hand * GRIP_ATTACHMENT * GRIP_FRAME.inv()


def forward_kinematics(transforms, root=None):
    """World CFrame of every part. transforms: part1 name -> CF."""
    world = {"HumanoidRootPart": root or CF(p=(0, 3, 0))}
    for name in ORDER:
        part0, c0, c1 = JOINTS[name]
        t = transforms.get(name, CF())
        world[name] = world[part0] * CF(p=c0) * t * CF(p=c1).inv()
    return world


def joint_world(world, name):
    """World CFrame of a joint (the C0 point, in Part0's rotation)."""
    part0, c0, _ = JOINTS[name]
    return world[part0] * CF(p=c0)


def rotation_transform(world, name, R_world):
    """The Transform that gives part `name` the world rotation R_world."""
    part0 = JOINTS[name][0]
    return CF(world[part0].R.T @ R_world)


# ---------------------------------------------------------------------------
# Arm solving
# ---------------------------------------------------------------------------


def arm_frame(down, front_hint):
    """Rotation for a limb whose -Y points along `down`, with -Z as close to
    `front_hint` as possible."""
    y = -unit(down)
    z = -np.asarray(front_hint, dtype=float)
    z = unit(z - y * np.dot(z, y))
    x = np.cross(y, z)
    return frame(x, y, z)


def limb_vector(name, child):
    """From a limb's joint to its child's joint, in the limb's own space. R15
    shoulders sit at the arm's inner edge, so this isn't straight down."""
    return np.asarray(JOINTS[child][1], dtype=float) - np.asarray(JOINTS[name][2], dtype=float)


def limb_rotation(direction, front_hint, local):
    """Rotation that points the limb's `local` vector along `direction`, with
    the limb's -Z as close to `front_hint` as possible."""
    a = math.atan2(local[0], -local[1])
    return arm_frame(direction, front_hint) @ rz(-a)


def two_bone(shoulder, target, a, b, pole):
    """Elbow position for a two-bone chain from shoulder to target."""
    d = target - shoulder
    dist = min(np.linalg.norm(d), a + b - 1e-4)
    d = unit(d)
    # law of cosines: distance from shoulder to the elbow's foot on the line
    x = (a * a - b * b + dist * dist) / (2 * dist)
    h = math.sqrt(max(a * a - x * x, 0))
    pole = np.asarray(pole, dtype=float)
    pole = unit(pole - d * np.dot(pole, d))
    return shoulder + d * x + pole * h


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------

AIM = unit((0, math.sin(math.radians(4)), -1))  # down the lane, a touch upward
WORLD_UP = np.array([0.0, 1.0, 0.0])


def base_body(p):
    """Body joints before the arms: a side-on archer's stance that settles a
    little lower and leans back as the string comes back. p: draw 0..1."""
    t = {}
    turn = math.radians(lerp(34, 40, p))  # hips and legs turn left
    t["LowerTorso"] = CF(ry(turn) @ rx(math.radians(-2)), (0, lerp(-0.04, -0.12, p), 0))
    chest = math.radians(lerp(22, 30, p))
    lean = math.radians(lerp(2, 7, p))  # back
    t["UpperTorso"] = CF(ry(chest) @ rx(lean) @ rz(math.radians(lerp(-2, -5, p))))
    # Braced legs: the front (right) leg forward, the back one back and out.
    t["RightUpperLeg"] = CF(rx(math.radians(10)) @ rz(math.radians(6)))
    t["RightLowerLeg"] = CF(rx(math.radians(-10)))
    t["LeftUpperLeg"] = CF(rx(math.radians(-14)) @ rz(math.radians(-8)))
    t["LeftLowerLeg"] = CF(rx(math.radians(-6)))
    t["LeftFoot"] = CF(rx(math.radians(18)))
    return t


def look_head(t, world, tilt):
    """Turns the head to look down the lane, tilted onto the string."""
    neck = joint_world(world, "Head")
    R = frame(*(lambda f: (np.cross(WORLD_UP, -f), WORLD_UP, -f))(unit(AIM * np.array([1, 0, 1]))))
    R = R @ rz(math.radians(tilt)) @ rx(math.radians(-6))
    t["Head"] = rotation_transform(world, "Head", R)
    _ = neck


def solve(p, overrides=None):
    """Joint transforms for draw amount p (0 = string at rest, 1 = full draw).

    overrides can push things around for the release: 'hand_offset' (moves the
    drawing hand, world studs), 'bow_pitch' (degrees, bow tips forward),
    'bow_drop' (degrees, bow arm sags), 'lean' (extra degrees back),
    'hand_open' (degrees, the drawing hand flicks open).
    """
    o = overrides or {}
    t = base_body(p)
    if "lean" in o:
        t["UpperTorso"] = t["UpperTorso"] * CF(rx(math.radians(o["lean"])))
    world = forward_kinematics(t)

    look_head(t, world, tilt=lerp(4, 12, p))
    world = forward_kinematics(t)

    # --- Bow arm (right): reach so the bow points down the lane, string
    # running back just under the chin.
    shoulder = joint_world(world, "RightUpperArm").p
    head = world["Head"]
    anchor = head.point((0, -0.72, -0.5))
    anchor[0] = lerp(anchor[0], shoulder[0], 0.4)  # toward the bow side, clear of the face
    aim = unit(rx(-math.radians(o.get("bow_drop", 0))) @ AIM)
    # The arm stays straight, so the wrist sits at a fixed distance from the
    # shoulder; find the grip point on the arrow line that puts it there:
    # grip = anchor + aim * s, |grip - aim*GRIP_LENGTH - shoulder| = reach
    v_arm = limb_vector("RightUpperArm", "RightLowerArm") + limb_vector("RightLowerArm", "RightHand")
    reach = np.linalg.norm(v_arm)
    base = anchor - aim * GRIP_LENGTH - shoulder
    bb = np.dot(base, aim)
    cc = np.dot(base, base) - reach * reach
    s = -bb + math.sqrt(max(bb * bb - cc, 0))
    grip = anchor + aim * s
    wrist = grip - aim * GRIP_LENGTH
    # Front of the arm faces up, so the elbow points out to the side.
    R_arm = limb_rotation(wrist - shoulder, WORLD_UP, v_arm)
    t["RightUpperArm"] = rotation_transform(world, "RightUpperArm", R_arm)
    world = forward_kinematics(t)
    t["RightLowerArm"] = rotation_transform(world, "RightLowerArm", R_arm)
    world = forward_kinematics(t)
    # The hand turns the bow to point exactly down the lane: hand -Y = aim and
    # hand -Z (the bow's up) = world up, canted a little, tipped on the release.
    cant = math.radians(8)
    pitch = math.radians(o.get("bow_pitch", 0))
    up = rx(-pitch) @ (rz(-cant) @ WORLD_UP)
    t["RightHand"] = rotation_transform(world, "RightHand", arm_frame(aim, up))
    world = forward_kinematics(t)

    # Where the nock is at this draw: from rest straight back along the arrow
    # line to the anchor at full draw.
    bow = bow_frame(world["RightHand"])
    nock = bow.point((lerp(NOCK_REST, -s, p), 0, 0))

    # --- Drawing arm (left): fingers hooked on the nock from behind, elbow
    # lifting up and back as the string comes back.
    target = nock + np.asarray(o.get("hand_offset", (0, 0, 0)), dtype=float)
    l_shoulder = joint_world(world, "LeftUpperArm").p
    hand_dir = unit(rx(math.radians(o.get("hand_open", 0))) @ aim)  # fingers point forward; opening flicks them up
    wrist_l = target - hand_dir * HAND_REACH
    v_upper = limb_vector("LeftUpperArm", "LeftLowerArm")
    v_lower = limb_vector("LeftLowerArm", "LeftHand")
    pole = unit(np.array([-1.0, lerp(0.2, 1.0, p), 1.0]))  # out to the left, up, back
    elbow = two_bone(l_shoulder, wrist_l, np.linalg.norm(v_upper), np.linalg.norm(v_lower), pole)
    R_upper = limb_rotation(elbow - l_shoulder, wrist_l - elbow, v_upper)
    t["LeftUpperArm"] = rotation_transform(world, "LeftUpperArm", R_upper)
    world = forward_kinematics(t)
    R_lower = limb_rotation(wrist_l - elbow, -np.cross(R_upper[:, 0], -unit(wrist_l - elbow)), v_lower)
    t["LeftLowerArm"] = rotation_transform(world, "LeftLowerArm", R_lower)
    world = forward_kinematics(t)
    # Palm toward the face (+X side of the lane line), fingers forward.
    t["LeftHand"] = rotation_transform(world, "LeftHand", arm_frame(hand_dir, np.array([1.0, 0, 0])))
    world = forward_kinematics(t)
    info = {"nock": nock, "target": target, "anchor": anchor, "grip": grip, "draw_length": s, "bow": bow, "world": world}
    return t, info


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

# A key: (time, transforms, easing style, easing direction, markers)
# PoseEasingStyle: Linear 0, Constant 1, Elastic 2, Cubic 3, Bounce 4, CubicV2 5
# PoseEasingDirection: In 0, Out 1, InOut 2
LINEAR, CUBIC2 = 0, 5
EASE_IN, EASE_OUT, EASE_INOUT = 0, 1, 2


# The drawing hand can't reach the string all the way forward at rest (R15
# arms are short), so the draw starts with the string already part way back:
# the animation's time 0 is this much of the full draw. SlingshotModel.luau
# uses the same number.
DRAW_START = 0.6


def draw_at(time):
    """Draw amount for a time in BowDraw (0..1)."""
    return lerp(DRAW_START, 1.0, time)


def draw_animation():
    keys = []
    for i in range(9):
        time = i / 8
        t, _ = solve(draw_at(time))
        keys.append((time, t, LINEAR, EASE_IN, []))
    return {"name": "BowDraw", "loop": False, "priority": 2, "keys": keys}


def release_animation():
    """The string snaps away: the hand flies back and opens, the bow kicks
    forward, the body rocks. 'Impact' marks the frame the game freezes on for a
    Perfect; 'Done' is where it starts fading back to normal."""
    full, _ = solve(1.0)
    snap, _ = solve(1.0, {"hand_offset": (-0.25, 0.25, 0.75), "bow_pitch": 16, "lean": 3, "hand_open": 50})
    hold, _ = solve(1.0, {"hand_offset": (-0.35, 0.3, 0.85), "bow_pitch": 10, "lean": 2, "hand_open": 60})
    settle, _ = solve(0.9, {"hand_offset": (-0.4, -0.25, 0.7), "bow_pitch": -4, "bow_drop": 10, "lean": -2, "hand_open": 40})
    rest, _ = solve(0.6, {"hand_offset": (-0.6, -0.9, 0.4), "bow_drop": 28, "lean": -1, "hand_open": 20})
    keys = [
        (0.0, full, CUBIC2, EASE_OUT, []),
        (0.05, snap, CUBIC2, EASE_OUT, ["Impact"]),
        (0.16, hold, CUBIC2, EASE_INOUT, []),
        (0.34, settle, CUBIC2, EASE_INOUT, ["Done"]),
        (0.62, rest, LINEAR, EASE_IN, []),
    ]
    return {"name": "BowRelease", "loop": False, "priority": 3, "keys": keys}


# ---------------------------------------------------------------------------
# .rbxmx writing
# ---------------------------------------------------------------------------


def fmt(x):
    s = f"{x:.6f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


class Writer:
    def __init__(self):
        self.lines = []
        self.ref = 0

    def item(self, cls, props, children=lambda depth: None, depth=1):
        pad = "\t" * depth
        self.ref += 1
        self.lines.append(f'{pad}<Item class="{cls}" referent="RBX{self.ref:04d}">')
        self.lines.append(f"{pad}\t<Properties>")
        for line in props:
            self.lines.append(f"{pad}\t\t{line}")
        self.lines.append(f"{pad}\t</Properties>")
        children(depth + 1)
        self.lines.append(f"{pad}</Item>")


def cframe_xml(name, cf):
    R, p = cf.R, cf.p
    parts = [f"<X>{fmt(p[0])}</X>", f"<Y>{fmt(p[1])}</Y>", f"<Z>{fmt(p[2])}</Z>"]
    for r in range(3):
        for c in range(3):
            parts.append(f"<R{r}{c}>{fmt(R[r, c])}</R{r}{c}>")
    return f'<CoordinateFrame name="{name}">' + "".join(parts) + "</CoordinateFrame>"


def write_rbxmx(anim, path):
    w = Writer()
    w.lines.append('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
                   'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                   'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')

    def pose(name, transforms, style, direction):
        def kids(depth):
            for child in CHILDREN[name]:
                w.item("Pose", *pose(child, transforms, style, direction), depth=depth)

        cf = transforms.get(name, CF())
        props = [
            f'<string name="Name">{name}</string>',
            cframe_xml("CFrame", cf),
            '<float name="Weight">1</float>',
            f'<token name="EasingStyle">{style}</token>',
            f'<token name="EasingDirection">{direction}</token>',
        ]
        return props, kids

    def keyframes(depth):
        for time, transforms, style, direction, markers in anim["keys"]:
            def kids(d, transforms=transforms, style=style, direction=direction, markers=markers):
                w.item("Pose", *pose("HumanoidRootPart", transforms, style, direction), depth=d)
                for m in markers:
                    w.item("KeyframeMarker", [f'<string name="Name">{m}</string>', '<string name="Value"></string>'], depth=d)

            w.item("Keyframe", ['<string name="Name">Keyframe</string>', f'<float name="Time">{fmt(time)}</float>'], kids, depth)

    w.item("KeyframeSequence", [
        f'<string name="Name">{anim["name"]}</string>',
        f'<bool name="Loop">{"true" if anim["loop"] else "false"}</bool>',
        f'<token name="Priority">{anim["priority"]}</token>',
        '<float name="AuthoredHipHeight">2</float>',
    ], keyframes)
    w.lines.append("</roblox>")
    with open(path, "w") as f:
        f.write("\n".join(w.lines) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    _, info = solve(1.0)
    pull_back = (info["draw_length"] + NOCK_REST) / BOW_SCALE
    print(f"full draw: {info['draw_length']:.3f} studs behind the grip")
    print(f"SlingshotModel.luau: PULL_BACK = Vector3.new({-pull_back:.2f}, 0, 0), DRAW_START = {DRAW_START}")
    for anim in (draw_animation(), release_animation()):
        path = os.path.join(OUT, anim["name"] + ".rbxmx")
        write_rbxmx(anim, path)
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
