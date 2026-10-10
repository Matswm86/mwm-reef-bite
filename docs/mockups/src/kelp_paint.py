"""Paint the World-1 kelp and seagrass atlas (2048 x 2048): albedo + alpha (scissor at 0.5), normal (OpenGL),
ORM (R occlusion, G roughness, B metallic). Own work, no third-party images.

Run:  python3 kelp_paint.py <out_dir>

Layout (pixels, x right, y down), mirrored in kelp_build.py RECTS:
  giant kelp blades  8 variants, 256 x 1024 each: x 0-1023, rows y 0-1023 and 1024-2047
  stipe              128 x 2048 at x 1024
  sugar kelp blades  2 variants, 384 x 1024 at x 1152 (y 0 and 1024)
  sugar kelp stipe   64 x 1024 at x 1536, y 0 (holdfast end at the bottom)
  seagrass blades    6 variants, 64 x 1024 at x 1600 + 64 i, y 0
  seagrass, short    6 variants, 64 x 1024 at x 1600 + 64 i, y 1024
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
A = 2048
ALB = np.zeros((A, A, 4), np.float32)
NRM = np.zeros((A, A, 3), np.float32)
NRM[..., 2] = 1
ORM = np.zeros((A, A, 3), np.float32)
ORM[..., 0], ORM[..., 1] = 1, 0.5

RECTS = {}
for i in range(8):
    RECTS[f"giant{i}"] = ((i % 4) * 256, (i // 4) * 1024, 256, 1024)
RECTS["stipe"] = (1024, 0, 128, 2048)
RECTS["sugar0"] = (1152, 0, 384, 1024)
RECTS["sugar1"] = (1152, 1024, 384, 1024)
RECTS["sugar_stipe"] = (1536, 0, 64, 1024)
for i in range(6):
    RECTS[f"grass{i}"] = (1600 + 64 * i, 0, 64, 1024)
    RECTS[f"grass_s{i}"] = (1600 + 64 * i, 1024, 64, 1024)


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim >= 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def fbm(shape, sigmas, seed):
    r = np.random.default_rng(seed)
    out = np.zeros(shape, np.float32)
    amp = tot = 0
    amp = 1.0
    for sg in sigmas:
        n = ndimage.gaussian_filter(r.standard_normal(shape).astype(np.float32), sg, mode="wrap")
        out += amp * n / (n.std() + 1e-6)
        tot += amp
        amp *= 0.55
    return out / tot


def to_normal(H, k=1.0):
    gy, gx = np.gradient(H)
    n = np.stack([-gx * k, gy * k, np.ones_like(H)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def put(key, col, alpha, H, rough, k=1.0):
    x, y, w, h = RECTS[key]
    mask = alpha > 0.02
    if (~mask).any() and mask.any():
        idx = ndimage.distance_transform_edt(~mask, return_distances=False, return_indices=True)
        col = col[idx[0], idx[1]]
    ALB[y : y + h, x : x + w, :3] = np.clip(col, 0, 1)
    ALB[y : y + h, x : x + w, 3] = np.clip(alpha, 0, 1)
    NRM[y : y + h, x : x + w] = to_normal(H, k)
    ORM[y : y + h, x : x + w, 1] = rough
    ORM[y : y + h, x : x + w, 2] = 0.0


def grid(key):
    x, y, w, h = RECTS[key]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = (xx + 0.5) / w * 2 - 1  # -1..1 across
    v = 1 - (yy + 0.5) / h  # 0 base .. 1 tip
    return u, v, w, h


def giant_blade(i):
    """Macrocystis blade: gas bladder at the base, short stalk, lance blade with toothed edge,
    lengthwise corrugations, crosswise wrinkles, eroded tip, a few bryozoan crusts."""
    key = f"giant{i}"
    u, v, w, h = grid(key)
    r = np.random.default_rng(100 + i)
    nz = fbm(u.shape, (30, 8), 200 + i)
    # bladder (pneumatocyst) at v 0.015-0.085, radius in u
    bv0, bv1 = 0.012, 0.082
    bc = 0.5 * (bv0 + bv1)
    by = (v - bc) / ((bv1 - bv0) / 2)
    bladder = (u / 0.30) ** 2 + by**2 < 1
    stalk = (v > bv1 - 0.01) & (v < 0.13) & (np.abs(u) < 0.07 + 0.25 * sstep(0.11, 0.13, v))
    wmax = r.uniform(0.82, 0.96)
    t = np.clip((v - 0.12) / 0.88, 0, 1)
    half = wmax * np.sin(np.pi * np.clip(t, 0, 1) ** 0.55) ** 0.9 * (1 - 0.25 * t)
    half *= 1 + 0.06 * fbm(u.shape, (40,), 300 + i)[..., :] * 0
    teeth = np.abs(np.sin(v * h / 9.0 + 0.4 * i)) ** 3
    half_t = half * (1 - 0.05 * teeth)
    blade = (np.abs(u) < half_t) & (v > 0.12)
    # erosion: ragged tip and one or two holes
    tip_cut = v > 0.93 + 0.05 * fbm(u.shape, (6,), 400 + i)
    blade &= ~tip_cut
    for _ in range(r.integers(0, 3)):
        cu, cv, rr = r.uniform(-0.4, 0.4), r.uniform(0.4, 0.85), r.uniform(0.03, 0.07)
        blade &= ((u - cu) / 1.0) ** 2 + ((v - cv) * h / w * 0.5) ** 2 > rr**2
    alpha = (blade | bladder | stalk).astype(np.float32)
    alpha = ndimage.gaussian_filter(alpha, 0.7)
    alpha = sstep(0.25, 0.75, alpha)

    base, mid, tip = rgb("#6a4818"), rgb("#ae8834"), rgb("#c8a04a")
    col = mix(base, mid, sstep(0.10, 0.45, v))
    col = mix(col, tip, sstep(0.55, 1.0, v))
    col = col * (1 + 0.10 * nz[..., None])
    corr = np.sin(u * math.pi * 4.5 + 2.0 * fbm(u.shape, (20,), 500 + i))  # lengthwise ridges
    wr = np.sin(v * h / 14.0 + 3.0 * u + 1.5 * fbm(u.shape, (14,), 600 + i))  # crosswise wrinkles
    Hb = 0.9 * corr + 0.6 * wr * sstep(0.2, 0.5, v)
    edge = sstep(0.75, 1.0, np.abs(u) / np.maximum(half_t, 1e-3)) * blade
    col = mix(col, col * 0.75, edge * 0.6)  # thicker darker margin
    col = col * (1 + 0.05 * corr[..., None])
    crust = (fbm(u.shape, (5, 2), 700 + i) > 1.6) & blade & (v > 0.3)
    col = mix(col, rgb("#cfc6a8"), ndimage.gaussian_filter(crust.astype(np.float32), 1.0) * 0.6)
    # bladder: glossy rounder darker olive
    bd = np.clip(1 - (u / 0.30) ** 2 - by**2, 0, 1)
    col = np.where(bladder[..., None], mix(rgb("#5e4614"), rgb("#8a6a26"), np.sqrt(bd)), col)
    col = np.where(stalk[..., None] & ~bladder[..., None], rgb("#4a3210"), col)
    H = np.where(bladder, np.sqrt(bd) * 22.0, Hb)
    rough = np.where(bladder, 0.25, 0.42 + 0.05 * nz).astype(np.float32)
    put(key, col, alpha, H, rough, k=0.35)


def stipe():
    key = "stipe"
    u, v, w, h = grid(key)
    nz = fbm(u.shape, ((6, 40),), 800) if False else fbm(u.shape, (4,), 800)
    fib = ndimage.gaussian_filter(
        np.random.default_rng(801).standard_normal(u.shape).astype(np.float32), (40, 1.2)
    )
    fib /= fib.std() + 1e-6
    col = mix(rgb("#3e2a0e"), rgb("#6e5220"), 0.5 + 0.25 * fib)
    col = col * (1 - 0.35 * (np.abs(u) ** 2)[..., None])
    col = col * (1 + 0.06 * nz[..., None])
    H = fib * 0.8 + np.sqrt(np.clip(1 - u**2, 0, 1)) * 6
    put(key, col, np.ones_like(u), H, np.full(u.shape, 0.45, np.float32), k=0.5)


def sugar_blade(i):
    """Saccharina latissima: smooth central band, dimpled (bullate) flanks, ruffled margin, eroded tip."""
    key = f"sugar{i}"
    u, v, w, h = grid(key)
    r = np.random.default_rng(900 + i)
    nz = fbm(u.shape, (30, 8), 910 + i)
    t = v
    half = 0.10 + 0.86 * sstep(0.0, 0.22, t) * (1 - 0.15 * sstep(0.75, 1.0, t))
    ruffle = np.sin(v * h / 18.0 + 1.3 * i) * 0.5 + 0.5
    half_r = half * (1 - 0.05 * ruffle)
    tip_cut = v > 0.935 + 0.035 * fbm(u.shape, (22, 6), 920 + i) + 0.03 * (1 - np.abs(u))
    blade = (np.abs(u) < half_r) & ~tip_cut & (v > 0.004)
    alpha = sstep(0.25, 0.75, ndimage.gaussian_filter(blade.astype(np.float32), 0.7))
    col = mix(rgb("#634616"), rgb("#a88636"), sstep(0.0, 0.35, v))
    col = mix(col, rgb("#a88a3a"), sstep(0.6, 1.0, v) * 0.6)
    band = 1 - sstep(0.18, 0.32, np.abs(u))
    col = mix(col, col * 1.12, band * 0.5)
    rr = np.random.default_rng(930 + i)
    dim = np.zeros(u.shape, np.float32)
    for _ in range(900):
        cu = rr.uniform(-0.9, 0.9)
        cv = rr.uniform(0.1, 0.9)
        if abs(cu) < 0.28:
            continue
        rad_u, rad_v = rr.uniform(0.06, 0.12), rr.uniform(0.012, 0.02)
        x0 = int((cu + 1) / 2 * w)
        y0 = int((1 - cv) * h)
        ru, rv = int(rad_u * w / 2) + 2, int(rad_v * h) + 2
        ys, xs = slice(max(y0 - rv, 0), y0 + rv), slice(max(x0 - ru, 0), x0 + ru)
        d = ((u[ys, xs] - cu) / rad_u) ** 2 + ((v[ys, xs] - cv) / rad_v) ** 2
        dim[ys, xs] = np.maximum(dim[ys, xs], np.clip(1 - d, 0, 1))
    margin = sstep(0.80, 1.0, np.abs(u) / np.maximum(half_r, 1e-3))
    col = (
        col
        * (1 - 0.15 * dim[..., None])
        * (1 - 0.18 * margin[..., None])
        * (1 + 0.08 * nz[..., None])
    )
    H = -dim * 6.0 + margin * np.sin(v * h / 18.0 + 1.3 * i) * 4.0 + band * 1.5
    put(key, col, alpha, H, (0.40 + 0.05 * nz).astype(np.float32), k=0.5)


def sugar_stipe():
    key = "sugar_stipe"
    u, v, w, h = grid(key)
    fib = ndimage.gaussian_filter(
        np.random.default_rng(950).standard_normal(u.shape).astype(np.float32), (30, 1)
    )
    fib /= fib.std() + 1e-6
    col = mix(rgb("#3a280c"), rgb("#5e4418"), 0.5 + 0.25 * fib) * (1 - 0.3 * (u**2))[..., None]
    put(
        key,
        col,
        np.ones_like(u),
        fib * 0.6 + np.sqrt(np.clip(1 - u**2, 0, 1)) * 4,
        np.full(u.shape, 0.45, np.float32),
    )


def grass(i, short=False):
    """Zostera marina blade: parallel veins, rounded tip, brown aged tip, epiphyte specks."""
    key = f"grass_s{i}" if short else f"grass{i}"
    u, v, w, h = grid(key)
    r = np.random.default_rng(1000 + i + (50 if short else 0))
    half = 0.80 * np.ones_like(v)
    tipv = r.uniform(0.90, 0.99)
    half = np.where(
        v > tipv - 0.03, 0.80 * np.sqrt(np.clip(1 - ((v - (tipv - 0.03)) / 0.03) ** 2, 0, 1)), half
    )
    sheath = v < 0.10
    half = np.where(sheath, 0.92, half)
    blade = np.abs(u) < half
    alpha = sstep(0.25, 0.75, ndimage.gaussian_filter(blade.astype(np.float32), 0.6))
    green = rgb(["#4d7a2c", "#56802e", "#5f8634", "#4a7030", "#68873a", "#526f2a"][i])
    col = mix(rgb("#8a8a52"), green, sstep(0.0, 0.12, v))
    age = sstep(0.55 + 0.25 * r.random(), 1.0, v)
    col = mix(col, rgb("#857238"), age * r.uniform(0.3, 0.8))
    veins = np.cos(u * math.pi * 3.5) ** 8
    col = col * (1 - 0.10 * veins[..., None])
    spk = (fbm(u.shape, (1.5,), 1100 + i) > 1.9) & (v > 0.4)
    col = mix(col, rgb("#c9c7a8"), ndimage.gaussian_filter(spk.astype(np.float32), 0.6) * 0.7)
    H = veins * 2.0
    put(key, col, alpha, H, np.full(u.shape, 0.38, np.float32), k=0.4)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(8):
        giant_blade(i)
    stipe()
    for i in range(2):
        sugar_blade(i)
    sugar_stipe()
    for i in range(6):
        grass(i)
        grass(i, short=True)

    def u8(a):
        return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)

    Image.fromarray(u8(ALB), "RGBA").save(OUT / "kelp_w1_albedo.png", optimize=True)
    Image.fromarray(u8(NRM * 0.5 + 0.5), "RGB").save(OUT / "kelp_w1_normal.png", optimize=True)
    Image.fromarray(u8(ORM), "RGB").save(OUT / "kelp_w1_orm.png", optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
