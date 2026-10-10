"""Bake the own-work textures of MWM Reef Bite.

Writes:
  assets/textures/rb_caustics.png  512x512 tileable caustic pattern (Voronoi
                                   F2 - F1 ridges on a torus, softened)
  icon.png                         512x512 app icon (DESIGN 16: gold barred
                                   fish on teal water with one light shaft)

Usage: python3 tools/make_textures.py
Deterministic (fixed seeds). numpy + Pillow only.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent


def caustics(size: int = 512, cells: int = 22, seed: int = 11) -> Image.Image:
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0.0, 1.0, (cells, 2))
    # Tile the points 3x3 so distances wrap around (seamless texture).
    tiles = np.concatenate([pts + np.array([dx, dy]) for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    ys, xs = np.mgrid[0:size, 0:size] / size
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    for px, py in tiles:
        d = np.sqrt((xs - px) ** 2 + (ys - py) ** 2)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    ridge = f2 - f1
    v = np.exp(-ridge * 95.0)
    v = (v - v.min()) / (v.max() - v.min())
    v = v**1.6
    img = Image.fromarray((v * 255).astype(np.uint8), "L")
    # Soft blur: wrap the edges first so the blur stays seamless.
    big = Image.new("L", (size * 3, size * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * size, j * size))
    big = big.filter(ImageFilter.GaussianBlur(1.6))
    return big.crop((size, size, size * 2, size * 2))


def fish_outline(
    cx: float, cy: float, length: float, flip: bool = False
) -> list[tuple[float, float]]:
    """Deep trevally side outline, nose to the right, as a polygon."""
    pts = []
    n = 40
    half = length * 0.5
    for i in range(n + 1):
        t = i / n
        x = half - t * length * 0.78
        h = length * 0.25 * np.sin(np.pi * min(1.0, t * 1.05)) ** 0.75
        pts.append((x, -h))
    tail_x = half - length * 0.78
    pts += [
        (tail_x - length * 0.05, -length * 0.02),
        (tail_x - length * 0.24, -length * 0.20),
        (tail_x - length * 0.15, 0.0),
        (tail_x - length * 0.24, length * 0.20),
        (tail_x - length * 0.05, length * 0.02),
    ]
    for i in range(n, -1, -1):
        t = i / n
        x = half - t * length * 0.78
        h = length * 0.21 * np.sin(np.pi * min(1.0, t * 1.05)) ** 0.8
        pts.append((x, h))
    s = -1.0 if flip else 1.0
    return [(cx + s * x, cy + y) for x, y in pts]


def icon(size: int = 512) -> Image.Image:
    ys = np.linspace(0.0, 1.0, size)[:, None]
    top = np.array([0x33, 0x8F, 0xA1], float)
    mid = np.array([0x1F, 0x63, 0x73], float)
    deep = np.array([0x06, 0x33, 0x47], float)
    k1 = np.clip(ys / 0.55, 0, 1)
    k2 = np.clip((ys - 0.55) / 0.45, 0, 1)
    col = top * (1 - k1) + mid * k1
    col = col * (1 - k2) + deep * k2
    arr = np.repeat(col[:, None, :], size, axis=1)
    img = Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")
    rays = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(rays)
    d.polygon([(150, -10), (250, -10), (420, size), (250, size)], fill=(255, 250, 225, 70))
    d.polygon([(300, -10), (330, -10), (470, size), (420, size)], fill=(255, 250, 225, 40))
    rays = rays.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, rays)
    fish = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(fish)
    outline = fish_outline(256, 268, 380)
    d.polygon(outline, fill=(240, 184, 0, 255))
    # Belly highlight.
    belly = Image.new("L", (size, size), 0)
    db = ImageDraw.Draw(belly)
    db.ellipse((150, 280, 420, 345), fill=170)
    belly = belly.filter(ImageFilter.GaussianBlur(18))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(outline, fill=255)
    pale = Image.new("RGBA", (size, size), (246, 238, 205, 255))
    fish = Image.composite(pale, fish, Image.fromarray(np.minimum(np.array(belly), np.array(mask))))
    d = ImageDraw.Draw(fish)
    # Five narrow black bars (the player's mark, DESIGN 4).
    bars = Image.new("L", (size, size), 0)
    dbar = ImageDraw.Draw(bars)
    for i in range(5):
        x = 360 - i * 52
        dbar.rectangle((x - 7, 150, x + 7, 400), fill=235)
    bars = Image.fromarray(np.minimum(np.array(bars), np.array(mask)))
    ink = Image.new("RGBA", (size, size), (34, 29, 16, 255))
    fish = Image.composite(ink, fish, bars)
    d = ImageDraw.Draw(fish)
    d.ellipse((390, 238, 420, 268), fill=(250, 214, 60, 255), outline=(20, 24, 28, 255), width=3)
    d.ellipse((400, 247, 413, 260), fill=(20, 24, 28, 255))
    img = Image.alpha_composite(img, fish)
    bub = ImageDraw.Draw(img)
    for x, y, r in [(452, 196, 12), (470, 150, 8), (458, 112, 6)]:
        bub.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 255, 230), width=3)
    return img.convert("RGB")


def main() -> None:
    out = ROOT / "assets" / "textures"
    out.mkdir(parents=True, exist_ok=True)
    caustics().save(out / "rb_caustics.png")
    icon().save(ROOT / "icon.png")
    print("wrote", out / "rb_caustics.png", ROOT / "icon.png")


if __name__ == "__main__":
    main()
