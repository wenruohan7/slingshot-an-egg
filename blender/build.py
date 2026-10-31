"""Builds the models and writes them to models/ in the repo.

Run with Blender's Python (made with Blender 5.2; `pip install bpy` works too):

    blender --background --python blender/build.py -- slingshots eggs stands
    python blender/build.py slingshots            # with the bpy module

Each model gets an .fbx (texture embedded), the texture as a .png, and a
preview picture. The sizes of every model go into src/shared/MeshSizes.luau,
which the game uses to fit an imported mesh exactly where the built-in one was.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402

ROOT = os.path.dirname(HERE)
MODELS = os.path.join(ROOT, "models")
SIZES_JSON = os.path.join(MODELS, "sizes.json")
SIZES_LUAU = os.path.join(ROOT, "src", "shared", "MeshSizes.luau")


def preview_slingshot_extras(look):
    """Bands and pouch for the preview picture only. The game builds its own."""
    from slingshots import R, TIPS
    band = common.flat("PreviewBand", look["band"])
    leather = common.flat("PreviewLeather", (120, 72, 40))
    pouch = R(-1, 11.5, 0)
    objs = [common.rod("Band", R(*t), pouch, 0.2, 0.2, band, segments=8) for t in TIPS]
    objs.append(common.box("Pouch", pouch, (0.8, 1.4, 2.4), leather, bevel=0.2))
    return objs


def build_slingshots(only=None):
    import slingshots
    out = os.path.join(MODELS, "slingshots")
    results = []
    for name, fn, look in slingshots.TIERS:
        if only and name not in only:
            continue
        common.reset()
        info = common.finish(name, fn(look), out, ao_strength=0.45, ao_distance=0.8)
        extras = preview_slingshot_extras(look)
        render_with(info["object"], extras, os.path.join(out, "previews", name + ".png"),
                    view=common.R(1.0, 0.55, -1.6))
        print(f"{name}: {info['triangles']} triangles")
        results.append(info)
    return results


def build_eggs(only=None):
    import eggs
    out = os.path.join(MODELS, "eggs")
    results = []
    for name, fn in eggs.TIERS:
        if only and name not in only:
            continue
        common.reset()
        info = common.finish(name, fn(), out, ao_strength=0.25, ao_distance=0.6, angle=70)
        render_with(info["object"], [], os.path.join(out, "previews", name + ".png"),
                    view=common.R(0.6, 0.35, -1.6))
        print(f"{name}: {info['triangles']} triangles")
        results.append(info)
    return results


def build_stands(only=None):
    import stands
    out = os.path.join(MODELS, "stands")
    results = []
    for name, fn in stands.STANDS:
        if only and name not in only:
            continue
        common.reset()
        info = common.finish(name, fn(), out, ao_strength=0.55, ao_distance=2.5)
        render_with(info["object"], [], os.path.join(out, "previews", name + ".png"),
                    view=common.R(1.0, 0.75, -1.6))
        print(f"{name}: {info['triangles']} triangles")
        results.append(info)
    return results


def render_with(ob, extras, path, view):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    common.render_preview(ob, path, view=view, also=extras)


def write_sizes(kind, results):
    data = {}
    if os.path.exists(SIZES_JSON):
        with open(SIZES_JSON) as f:
            data = json.load(f)
    table = data.setdefault(kind, {})
    for info in results:
        table[info["name"]] = {"size": [round(v, 4) for v in info["size"]],
                               "center": [round(v, 4) for v in info["center"]],
                               "triangles": info["triangles"]}
    with open(SIZES_JSON, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)
    write_luau(data)


def vec(v):
    return "Vector3.new(" + ", ".join(f"{x:g}" for x in v) + ")"


def write_luau(data):
    lines = [
        "--!strict",
        "-- Made by blender/build.py: do not edit by hand.",
        "-- The size and centre of each model in models/, in the model's own space",
        "-- (Slingshots: before SlingshotModel's 0.4 scale; Eggs and Stands: studs).",
        "-- An imported mesh is resized and placed from these, so it lines up no",
        "-- matter what scale Studio's importer picked.",
        "",
        "export type Box = { Size: Vector3, Center: Vector3 }",
        "",
        "local MeshSizes: { [string]: { [string]: Box } } = {",
    ]
    for kind in ("Slingshots", "Eggs", "Stands"):
        lines.append(f"\t{kind} = {{")
        for name, box in sorted(data.get(kind, {}).items()):
            lines.append(f'\t\t["{name}"] = {{ Size = {vec(box["size"])}, Center = {vec(box["center"])} }},')
        lines.append("\t},")
    lines += ["}", "", "return MeshSizes", ""]
    with open(SIZES_LUAU, "w") as f:
        f.write("\n".join(lines))


def main():
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
    else:  # skip Blender's own options and this script's path
        args = [a for a in sys.argv[1:] if not a.startswith("-") and not a.endswith(".py")]
    kinds = [a for a in args if a in ("slingshots", "eggs", "stands")] or ["slingshots", "eggs", "stands"]
    only = [a for a in args if a not in ("slingshots", "eggs", "stands")] or None
    if "slingshots" in kinds:
        write_sizes("Slingshots", build_slingshots(only))
    if "eggs" in kinds:
        write_sizes("Eggs", build_eggs(only))
    if "stands" in kinds:
        write_sizes("Stands", build_stands(only))


if __name__ == "__main__":
    main()
