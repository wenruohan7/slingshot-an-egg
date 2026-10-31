"""Puts the preview pictures of one folder side by side: models/<kind>/previews.png"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont


def sheet(folder, names, cols=4, out=None):
    tiles = [Image.open(os.path.join(folder, "previews", n + ".png")).convert("RGB") for n in names]
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    img = Image.new("RGB", (cols * w, rows * (h + 34)), (235, 242, 250))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, (n, t) in enumerate(zip(names, tiles)):
        x, y = (i % cols) * w, (i // cols) * (h + 34)
        img.paste(t, (x, y))
        tw = draw.textlength(n, font=font)
        draw.text((x + (w - tw) / 2, y + h + 4), n, fill=(40, 40, 60), font=font)
    img.save(out or os.path.join(folder, "previews.png"))


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import bpy  # noqa: F401  (the model lists import Blender modules)
    root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models")
    for kind in sys.argv[1:] or ["slingshots", "eggs", "stands"]:
        folder = os.path.join(root, kind)
        names = sorted(f[:-4] for f in os.listdir(os.path.join(folder, "previews")) if f.endswith(".png"))
        if kind == "slingshots":
            from slingshots import TIERS
            names = [t[0] for t in TIERS]
        elif kind == "eggs":
            from eggs import TIERS
            names = [t[0] for t in TIERS]
        sheet(folder, names, cols=4 if len(names) > 3 else len(names))
