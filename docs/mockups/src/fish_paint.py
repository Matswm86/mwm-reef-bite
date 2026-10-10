"""Paint the World-1 fish atlas (2048 x 2048): albedo + alpha, tangent-space normal (OpenGL, +Y up) and
ORM (R occlusion, G roughness, B metallic; the glTF metallicRoughness layout).

Run:  python3 fish_paint.py <out_dir>
Every texel is computed from fish_species.py (side-view body strip, packed fins, eye disc), so the Blender
builder lands its UVs on the same pixels. Own work, no third-party images.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fish_species as F  # noqa: E402

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
A = F.ATLAS
ALB = np.zeros((A, A, 4), np.float32)
NRM = np.zeros((A, A, 3), np.float32)
NRM[..., 2] = 1.0
ORM = np.zeros((A, A, 3), np.float32)
ORM[..., 0], ORM[..., 1] = 1.0, 0.5
RNG = np.random.default_rng(7)


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    colour = any(np.ndim(x) and np.shape(x)[-1] == 3 for x in (a, b))
    if colour and t.ndim >= 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def fbm(shape, sigmas, seed):
    r = np.random.default_rng(seed)
    out = np.zeros(shape, np.float32)
    amp, tot = 1.0, 0.0
    for sg in sigmas:
        n = ndimage.gaussian_filter(r.standard_normal(shape).astype(np.float32), sg, mode="wrap")
        n /= n.std() + 1e-6
        out += amp * n
        tot += amp
        amp *= 0.55
    return out / tot


def spots(S, Z, density, rmin, rmax, seed, region=None):
    """Field 0..1 of soft round spots scattered in (s, z) metric space."""
    r = np.random.default_rng(seed)
    out = np.zeros(S.shape, np.float32)
    smin, smax, zmin, zmax = S.min(), S.max(), Z.min(), Z.max()
    n = int(density * (smax - smin) * (zmax - zmin))
    ds = (smax - smin) / (S.shape[1] - 1)
    dz = (zmax - zmin) / (S.shape[0] - 1)
    for _ in range(n):
        cs, cz = r.uniform(smin, smax), r.uniform(zmin, zmax)
        rad = r.uniform(rmin, rmax)
        i0 = int((zmax - cz - 2 * rad) / dz)
        i1 = int((zmax - cz + 2 * rad) / dz) + 2
        j0 = int((cs - smin - 2 * rad) / ds)
        j1 = int((cs - smin + 2 * rad) / ds) + 2
        i0, j0 = max(i0, 0), max(j0, 0)
        sub_s, sub_z = S[i0:i1, j0:j1], Z[i0:i1, j0:j1]
        if sub_s.size == 0:
            continue
        el = r.uniform(0.7, 1.3)
        d = np.sqrt(((sub_s - cs) / el) ** 2 + ((sub_z - cz) * el) ** 2) / rad
        out[i0:i1, j0:j1] = np.maximum(out[i0:i1, j0:j1], 1 - sstep(0.6, 1.0, d))
    return out


def height_to_normal(H, ds, dz, k=1.0):
    gz, gs = np.gradient(H, dz, ds)  # rows run down = -z
    nx = -gs * k
    ny = gz * k  # dH/dz = -dH/drow
    nz = np.ones_like(H)
    n = np.stack([nx, ny, nz], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


# ------------------------------------------------------------------ scales
def scale_field(S, Z, p):
    """Overlapping cycloid scales: anterior scales overlap posterior ones (free edge toward the tail).
    Returns height 0..1 and an edge mask for the albedo pocket line."""
    row_h = p * 0.82
    best_i = np.full(S.shape, 1e9, np.float32)
    h = np.zeros(S.shape, np.float32)
    edge = np.zeros(S.shape, np.float32)
    R = p * 0.78
    i0 = np.floor(S / p).astype(int)
    for di in (-1, 0, 1):
        ii = i0 + di
        off = (ii % 2) * 0.5
        j0 = np.floor(Z / row_h - off).astype(int)
        for dj in (-1, 0, 1):
            jj = j0 + dj
            cs = ii * p + p * 0.5
            cz = (jj + off + 0.5) * row_h
            ls, lz = S - cs, Z - cz
            d = np.sqrt(ls**2 + (lz * 1.1) ** 2) / R
            cov = d < 1.0
            take = cov & (ii < best_i)
            t = np.clip(ls / R, -1, 1)
            hh = (0.35 + 0.65 * sstep(-1.0, 0.85, t)) * (1 - sstep(0.80, 1.0, d))
            ee = sstep(0.72, 0.97, d) * (ls > 0)
            h = np.where(take, hh, h)
            edge = np.where(take, ee, edge)
            best_i = np.where(take, ii, best_i)
    return h, edge


# ------------------------------------------------------------------ head geometry helpers (side view)
def op_edge_s(sp, zn):
    """Rear edge of the gill cover as s(zn)."""
    s0 = sp["op"]["s"]
    up = s0 - 0.030 * ((zn - 0.55) / 0.45) ** 2
    lo = s0 - 0.075 * np.clip((0.55 - zn) / 0.55, 0, 1) ** 1.5
    return np.where(zn > 0.55, up, lo)


def pre_edge_s(sp, zn):
    s0 = sp["op"]["pre"]
    up = s0 - 0.012 * np.clip((zn - 0.45) / 0.55, 0, 1)
    lo = s0 - 0.060 * np.clip((0.45 - zn) / 0.45, 0, 1) ** 1.8
    return np.where(zn > 0.45, up, lo)


def lateral_line_z(body, S):
    ll = body.sp["ll"]
    T, B = body.top(S), body.bot(S)
    m = 0.5 * (T + B)
    g = (
        0.12
        + 0.22 * (1 - sstep(0.2, 0.65, S))
        + (ll["arch"] / 0.32) * 0.35 * np.exp(-(((S - 0.30) / 0.13) ** 2))
    )
    return m + (T - m) * g


# ------------------------------------------------------------------ body strip
def paint_body(name):
    body = F.Body(name)
    sp = body.sp
    c = {k: rgb(v) for k, v in sp["colors"].items()}
    S, Z = body.body_pixel_grid()
    T, B = body.top(S), body.bot(S)
    zn = np.clip((Z - B) / np.maximum(T - B, 1e-4), -0.2, 1.2)
    ds = body.sb / (F.BLOCK_W - 1)
    dz = (body.zmax - body.zmin) / (F.BODY_H - 7)
    seed = F.ORDER.index(name) * 101

    # countershaded base
    col = mix(c["belly"], c["flank"], sstep(0.24, 0.52, zn))
    col = mix(col, c["back"], sstep(0.62, 0.95, zn))
    big = fbm(S.shape, (40, 14), seed + 1)
    col = col * (1 + 0.06 * big[..., None])

    se, ze, er = body.eye_pos()
    zn_op = zn
    s_op = op_edge_s(sp, zn_op)
    d_op = S - s_op  # <0 head, >0 body
    head = 1 - sstep(-0.006, 0.004, d_op)
    col = mix(
        col, mix(col, c["head"], 0.55), head * sstep(0.2, 0.5, zn) * (1 - sstep(0.75, 0.95, zn))
    )
    # silvery cheek and gill cover below the eye line, darker brow above it (all species)
    se0, ze0, er0 = body.eye_pos()
    cheek = head * (1 - sstep(ze0 - 2.5 * er0, ze0 - 0.5 * er0, Z)) * sstep(0.12, 0.3, zn)
    col = mix(col, mix(c["belly"], c["flank"], 0.25), cheek * 0.55)
    brow = head * sstep(ze0 + 0.8 * er0, ze0 + 3.0 * er0, Z)
    col = mix(col, c["back"], brow * 0.35)

    metal = mix(np.float32(sp["metal"][0]), np.float32(sp["metal"][1]), sstep(0.6, 0.9, zn))
    rough = np.full(S.shape, sp["rough"][0], np.float32)
    rough = np.where(head > 0.5, sp["rough"][0] + 0.04, rough)
    ao = np.ones(S.shape, np.float32)
    H = np.zeros(S.shape, np.float32)

    # scales (body only, fade on head and on the thin dorsal / ventral edges)
    p = sp["scale"]
    jit = 0.12 * p
    jsig = max(9.0, p / ds * 2.0)
    sh, sedge = scale_field(
        S + jit * fbm(S.shape, (jsig,), seed + 41), Z + jit * fbm(S.shape, (jsig,), seed + 42), p
    )
    smask = (1 - head) * sstep(0.0, 0.08, zn) * (1 - sstep(0.94, 1.02, zn))
    smask *= 1 - sstep(body.sb - 0.03, body.sb, S) * 0.5
    H += sh * smask * p * 0.16 * sp["scale_amp"]
    col = col * (1 - 0.22 * sp["scale_amp"] * sedge[..., None] * smask[..., None])
    col = col * (1 + 0.05 * (sh[..., None] - 0.5) * smask[..., None])

    # species pattern ------------------------------------------------
    if name == "golden_trevally":
        for k, bs in enumerate([0.255, 0.365, 0.475, 0.585, 0.690]):
            wob = 0.0016 * fbm(S.shape, (22, 8), seed + 10 + k)
            curve = bs + 0.012 * (zn - 0.5) ** 2 - 0.006 * (zn - 0.5) + wob
            w = 0.020 if k < 4 else 0.016
            bar = 1 - sstep(w * 0.55, w, np.abs(S - curve))
            bar *= sstep(0.06, 0.24, zn) * (1 - sstep(0.97, 1.05, zn))
            col = mix(col, c["back"] * 0.25, bar * 0.82)
            metal = mix(metal, np.float32(0.15), bar)
        # gold glow strongest mid-flank, silvery belly sheen
        col = mix(col, rgb("#f6d24a"), sstep(0.35, 0.55, zn) * (1 - sstep(0.6, 0.85, zn)) * 0.25)
        # lateral scutes (posterior lateral line)
        zl = body.mid(S) + 0.002
        a0, a1 = sp["ll"]["scutes"]
        sc_ph = (S - a0) / 0.0085
        sw = 0.005 * (1 + 0.6 * sstep(a0, a1, S))
        scute = (
            (1 - sstep(sw * 0.6, sw, np.abs(Z - zl)))
            * sstep(a0, a0 + 0.03, S)
            * (1 - sstep(a1 - 0.01, a1, S))
        )
        hump = (0.5 - 0.5 * np.cos(2 * math.pi * sc_ph)) * np.clip(1 - np.abs(Z - zl) / sw, 0, 1)
        H += scute * hump * 0.0011
        col = mix(col, rgb("#7a6420"), scute * 0.35)
    elif name == "brisling":
        col = mix(col, rgb("#18485a"), sstep(0.88, 1.0, zn) * 0.8)
        sheen = sstep(0.45, 0.70, zn) * (1 - sstep(0.72, 0.86, zn))
        col = mix(col, rgb("#cfe3e6"), sheen * 0.55)
        loss = sstep(0.55, 1.1, fbm(S.shape, (5, 2), seed + 3)) * smask
        col = col * (1 - 0.18 * loss[..., None])
        # ventral keel scutes
        kz = B + 0.004
        kmask = (kz + 0.004 > Z) & (S > 0.12) & (S < 0.62)
        H += np.where(kmask, (0.5 - 0.5 * np.cos(2 * math.pi * S / 0.011)) * 0.0006, 0)
    elif name == "gronngylt":
        net = sstep(0.2, 0.9, sh) * smask
        col = mix(col, c["line2"] * 0.85, net * 0.35 * sstep(0.2, 0.6, zn))
        mott = sstep(0.2, 1.2, fbm(S.shape, (10, 4), seed + 4))
        col = mix(col, c["back"] * 0.8, mott * 0.35)
        # wavy blue-green and orange lines on cheek and gill cover
        for k in range(5):
            zz = ze - er * 1.4 - k * 0.012 + 0.006 * np.sin(S * 160 + k)
            line = (
                (1 - sstep(0.0012, 0.0026, np.abs(Z - zz))) * (se - 0.02 < S) * (s_op - 0.004 > S)
            )
            col = mix(col, c["line"] if k % 2 == 0 else c["line2"], line * 0.85)
        # dark crescent behind the eye and the tail-stock spot
        dcr = np.sqrt(((S - (se + er * 2.2)) / 0.012) ** 2 + ((Z - ze) / 0.016) ** 2)
        col = mix(col, c["spot"], (1 - sstep(0.7, 1.0, dcr)) * 0.85)
        dsp = np.sqrt(
            ((S - (body.sb - 0.035)) / 0.016) ** 2 + ((Z - body.mid(S) - 0.004) / 0.016) ** 2
        )
        col = mix(col, c["spot"], (1 - sstep(0.7, 1.0, dsp)) * 0.95)
    elif name == "sei":
        dark = sstep(0.50, 0.62, zn + 0.02 * fbm(S.shape, (8,), seed))
        col = mix(col, mix(c["back"], c["flank"], 0.35), dark * 0.55)
    elif name == "berggylt":
        cent = (1 - sstep(0.15, 0.55, 1 - sh)) * smask
        pale = sstep(0.4, 0.85, sh) * (1 - sedge) * smask
        col = mix(
            col,
            c["spot"],
            pale * 0.30 * (0.3 + 0.7 * sstep(-0.3, 0.8, fbm(S.shape, (12,), seed + 5))),
        )
        blot = sstep(0.1, 1.0, fbm(S.shape, (16, 6), seed + 6))
        col = mix(col, c["back"] * 0.75, blot * 0.50)
        hsp = spots(S, Z, 9000, 0.0015, 0.0030, seed + 7) * head
        col = mix(col, c["spot"], hsp * 0.6)
        del cent
    elif name == "lyr":
        mott = sstep(0.2, 1.3, fbm(S.shape, (7, 3), seed + 8))
        col = mix(col, rgb("#b09a58"), mott * 0.30 * sstep(0.25, 0.6, zn))
        col = mix(col, rgb("#c49a40"), sstep(0.32, 0.55, zn) * (1 - sstep(0.55, 0.8, zn)) * 0.25)
    elif name == "torsk":
        sp1 = spots(S, Z, 26000, 0.0022, 0.0055, seed + 9)
        sp1 *= sstep(0.30, 0.55, zn)
        col = mix(col, c["spot"], sp1 * 0.65)
        mott = sstep(0.0, 1.4, fbm(S.shape, (10, 4), seed + 10))
        col = mix(col, c["back"] * 0.9, mott * 0.30 * sstep(0.4, 0.8, zn))
    elif name == "havabbor":
        col = mix(col, rgb("#dfe6e6"), sstep(0.30, 0.55, zn) * (1 - sstep(0.55, 0.75, zn)) * 0.45)
        rows = 0.5 + 0.5 * np.sin((Z - body.mid(S)) / (sp["scale"] * 0.82) * math.pi)
        col = col * (1 - 0.06 * rows[..., None] * smask[..., None] * sstep(0.4, 0.8, zn)[..., None])
        if sp["op"].get("spot"):
            dsp = np.sqrt(((S - (sp["op"]["s"] - 0.012)) / 0.010) ** 2 + ((zn - 0.78) / 0.07) ** 2)
            col = mix(col, c["spot"], (1 - sstep(0.6, 1.0, dsp)) * 0.85)

    # lateral line ------------------------------------------------------
    if sp.get("ll"):
        zl = lateral_line_z(body, S)
        start = sp["op"]["s"] - 0.012
        on = (start < S) & (body.sb - 0.01 > S)
        dl = np.abs(Z - zl)
        line = (1 - sstep(0.0009, 0.0020, dl)) * on
        ll_col = c["ll"]
        col = mix(
            col, ll_col, line * (0.6 if sp["ll"].get("dark") or sp["ll"].get("pale") else 0.30)
        )
        H += line * 0.00035
        pores = (0.5 + 0.5 * np.cos(2 * math.pi * S / 0.006)) ** 8 * line
        H -= pores * 0.00012
        ao -= pores * 0.08

    # gill cover, preopercle, mouth, eye socket, nostril ---------------
    ow = 0.0022
    op_line = np.exp(-((d_op / ow) ** 2)) * sstep(0.03, 0.12, zn) * (1 - sstep(0.90, 0.98, zn))
    H += -op_line * 0.0012 + head * 0.0004
    col = col * (1 - 0.24 * op_line[..., None])
    opb = head * sstep(-0.05, -0.004, d_op) * sstep(0.25, 0.5, zn) * (1 - sstep(0.7, 0.9, zn))
    col = mix(col, np.clip(col * 1.12 + 0.02, 0, 1), opb * 0.5)
    ao -= op_line * 0.45
    # membrane fringe just behind the edge, slightly translucent pale
    fringe = (
        np.exp(-(((d_op - ow * 1.4) / ow) ** 2))
        * sstep(0.1, 0.25, zn)
        * (1 - sstep(0.85, 0.95, zn))
    )
    col = mix(col, col * 1.25 + 0.04, fringe * 0.35)
    d_pre = S - pre_edge_s(sp, zn)
    pre_line = (
        np.exp(-((d_pre / 0.0016) ** 2)) * sstep(0.10, 0.2, zn) * (1 - sstep(0.80, 0.9, zn)) * head
    )
    H += -pre_line * 0.0006
    col = col * (1 - 0.10 * pre_line[..., None])

    m = sp["mouth"]
    zm = body.mouth_z(S)
    inmouth = m["end_s"] + 0.004 > S
    dm = Z - zm
    gap = (
        np.exp(-((dm / 0.0016) ** 2))
        * inmouth
        * (1 - sstep(m["end_s"] - 0.004, m["end_s"] + 0.004, S))
    )
    lips = (1 - sstep(m["lips"] * 0.6, m["lips"], np.abs(dm))) * inmouth
    col = mix(col, c["lips"], lips * 0.65)
    col = col * (1 - 0.70 * gap[..., None])
    rough = mix(rough, np.float32(0.42), lips)
    metal = mix(metal, np.float32(0.05), lips)
    H += lips * 0.0005 * (1 - np.abs(dm) / max(m["lips"], 1e-3)) - gap * 0.0010
    ao -= gap * 0.6
    # maxilla: the upper-jaw bone edge curving up behind the gape
    mx_s = m["end_s"]
    dmx = np.sqrt(
        ((S - mx_s) / 0.006) ** 2 + ((Z - (zm + m["lips"] * 0.8)) / (m["lips"] * 1.8 + 0.004)) ** 2
    )
    mxl = (1 - sstep(0.6, 1.1, dmx)) * (mx_s + 0.004 > S)
    col = col * (1 - 0.10 * mxl[..., None])
    H += mxl * 0.0003

    de = np.sqrt((S - se) ** 2 + (Z - ze) ** 2) / er
    socket = sstep(0.85, 1.0, de) * (1 - sstep(1.0, 1.35, de))
    col = mix(col, col * 0.72, socket)
    rim = np.exp(-(((de - 1.25) / 0.12) ** 2))
    H += rim * 0.0005 - socket * 0.0004
    ao -= socket * 0.4
    inner = de < 0.95
    col = np.where(inner[..., None], col * 0.3, col)
    nose = np.sqrt((S - se * 0.48) ** 2 + (Z - (ze + er * 0.15)) ** 2) / (er * 0.22)
    col = col * (1 - 0.55 * (1 - sstep(0.6, 1.0, nose))[..., None])

    # fin-base shadow under where the fins attach
    for f in sp["fins"]:
        if f["kind"] == "pectoral":
            fz = B + (T - B) * f["zn"]
            dp = np.sqrt(((S - f["s"]) / 0.006) ** 2 + ((Z - fz) / (f["wid"] * 0.6)) ** 2)
            ao -= (1 - sstep(0.7, 1.4, dp)) * 0.35
        elif f["kind"] in ("dorsal", "anal"):
            band = sstep(f["s0"] - 0.01, f["s0"] + 0.01, S) * (
                1 - sstep(f["s1"] - 0.01, f["s1"] + 0.01, S)
            )
            edgez = sstep(0.90, 1.0, zn) if f["kind"] == "dorsal" else 1 - sstep(0.0, 0.10, zn)
            ao -= band * edgez * 0.20

    fine = fbm(S.shape, (1.0,), seed + 99)
    H += fine * 0.00002
    col = np.clip(col * np.clip(0.55 + 0.45 * ao, 0.4, 1)[..., None], 0, 1)

    bx, by = F.block_origin(name)
    ALB[by : by + F.BODY_H, bx : bx + F.BLOCK_W, :3] = col
    ALB[by : by + F.BODY_H, bx : bx + F.BLOCK_W, 3] = 1.0
    NRM[by : by + F.BODY_H, bx : bx + F.BLOCK_W] = height_to_normal(H, ds, dz, k=1.0)
    ORM[by : by + F.BODY_H, bx : bx + F.BLOCK_W, 0] = np.clip(ao, 0.3, 1)
    ORM[by : by + F.BODY_H, bx : bx + F.BLOCK_W, 1] = np.clip(rough, 0.03, 1)
    ORM[by : by + F.BODY_H, bx : bx + F.BLOCK_W, 2] = np.clip(metal, 0, 1)
    return body


# ------------------------------------------------------------------ fins
SS = 4  # supersample for fin rasterising


def paint_fins(body):
    sp = body.sp
    c = {k: rgb(v) for k, v in sp["colors"].items()}
    rects, _ = F.pack_fins(body)
    bx, by = F.block_origin(body.name)
    x0, y0 = bx, by + F.BODY_H + 2
    rw, rh = F.BLOCK_W, F.BLOCK_H - F.BODY_H - 2
    big = (rw * SS, rh * SS)
    alpha_im = Image.new("L", big, 0)
    ray_im = Image.new("L", big, 0)
    tipdark_im = Image.new("L", big, 0)
    da, dr, dt = ImageDraw.Draw(alpha_im), ImageDraw.Draw(ray_im), ImageDraw.Draw(tipdark_im)
    col_full = np.zeros((rh, rw, 3), np.float32)
    col_full[:] = c["fin"]

    def to_px(rect, pts):
        px, py = F.fin_pixel(body, rect, pts)
        return np.stack([(px - x0) * SS, (py - y0) * SS], -1)

    for i, f in enumerate(sp["fins"]):
        rect = rects[f"fin{i}"]
        base, outer = F.fin_outline(body, f, n=64)
        nr = f["rays"]
        spiny = f.get("spiny", False)
        n = len(base)
        u = np.linspace(0, 1, n)
        # membrane edge: scallops between rays
        ray_u = (np.arange(nr) + 0.5) / nr if f["kind"] != "caudal" else np.linspace(0.02, 0.98, nr)
        phase = np.interp(u, ray_u, np.arange(nr), left=-0.5, right=nr - 0.5)
        notch = 0.5 - 0.5 * np.cos(2 * math.pi * (phase - np.round(phase)))
        depth = 0.28 if spiny else (0.02 if f["kind"] in ("pectoral", "pelvic") else 0.05)
        if (
            spiny and f["kind"] == "dorsal" and len(f["h"]) > 6
        ):  # wrasse: only the spiny front part notched
            depth = np.where(u < 0.55, 0.22, 0.04)
        memb = base + (outer - base) * (1 - depth * notch)[:, None]
        poly = np.concatenate([to_px(rect, base), to_px(rect, memb[::-1])])
        da.polygon([tuple(p) for p in poly], fill=175)
        # rays: from base to slightly past the membrane, branching near the tip for soft rays
        rect_scale = (
            rect[2] / max(rect[5][0] - rect[4][0], 1e-6)
            if not rect[6]
            else rect[3] / max(rect[5][0] - rect[4][0], 1e-6)
        )
        wbase = max(1.2, 0.0022 * rect_scale * SS * (1.6 if spiny else 1.0))
        for k, ru in enumerate(ray_u):
            b = np.array([np.interp(ru, u, base[:, 0]), np.interp(ru, u, base[:, 1])])
            o = np.array([np.interp(ru, u, outer[:, 0]), np.interp(ru, u, outer[:, 1])])
            ext = 1.06 if spiny else 1.0
            tip = b + (o - b) * ext
            seg = 10
            pts = [b + (tip - b) * t for t in np.linspace(0, 1, seg + 1)]
            pp = to_px(rect, np.array(pts))
            sp_front = spiny and (f["kind"] != "dorsal" or len(f["h"]) <= 6 or ru < 0.55)
            for j in range(seg):
                t = j / seg
                w = wbase * (1 - 0.6 * t)
                if not sp_front and t > 0.6:  # branch: two thin rays
                    off = (t - 0.6) * 0.06
                    d = o - b
                    nrm = np.array([-d[1], d[0]]) / (np.linalg.norm(d) + 1e-9)
                    for sgn in (-1, 1):
                        q0 = to_px(rect, np.array([pts[j] + sgn * nrm * off * np.linalg.norm(d)]))[
                            0
                        ]
                        q1 = to_px(
                            rect,
                            np.array([pts[j + 1] + sgn * nrm * (off + 0.006) * np.linalg.norm(d)]),
                        )[0]
                        dr.line([tuple(q0), tuple(q1)], fill=255, width=max(1, int(w * 0.6)))
                        da.line([tuple(q0), tuple(q1)], fill=255, width=max(1, int(w * 0.6)))
                else:
                    dr.line([tuple(pp[j]), tuple(pp[j + 1])], fill=255, width=max(1, int(w)))
                    da.line([tuple(pp[j]), tuple(pp[j + 1])], fill=255, width=max(1, int(w)))
        # dark tips (golden trevally caudal lobes, corkwing edging)
        if body.name == "golden_trevally" and f["kind"] == "caudal":
            for lobe in (slice(0, 14), slice(n - 14, n)):
                tri = np.concatenate(
                    [
                        to_px(rect, outer[lobe]),
                        to_px(rect, (base + (outer - base) * 0.55)[lobe][::-1]),
                    ]
                )
                dt.polygon([tuple(p) for p in tri], fill=255)
        if body.name in ("gronngylt", "berggylt", "torsk", "brisling", "sei", "lyr", "havabbor"):
            edge = np.concatenate(
                [to_px(rect, outer), to_px(rect, (base + (outer - base) * 0.82)[::-1])]
            )
            dt.polygon([tuple(p) for p in edge], fill=150)

    alpha = np.asarray(alpha_im.resize((rw, rh), Image.LANCZOS), np.float32) / 255
    rays = np.asarray(ray_im.resize((rw, rh), Image.LANCZOS), np.float32) / 255
    tipd = np.asarray(tipdark_im.resize((rw, rh), Image.LANCZOS), np.float32) / 255
    noise = fbm((rh, rw), (3, 1.2), F.ORDER.index(body.name) + 500)
    col = col_full * (1 + 0.08 * noise[..., None])
    col = mix(col, c["ray"], rays * 0.65)
    if body.name == "golden_trevally":
        col = mix(col, rgb("#151208"), tipd * 0.95)
    elif body.name == "gronngylt":
        col = mix(col, c["fin_edge"], tipd * 0.9)
    else:
        col = mix(col, c["fin_edge"], tipd * 0.6)
    if body.name in ("berggylt", "torsk"):
        fs = sstep(0.4, 1.2, fbm((rh, rw), (2.5,), 77 + F.ORDER.index(body.name)))
        col = mix(col, c["spot"] if body.name == "berggylt" else c["back"], fs * 0.35)
    a = np.clip(alpha, 0, 1)
    a = np.where(rays > 0.3, np.maximum(a, 0.9 * rays), a)  # rays near opaque, membrane about 0.65
    Hf = ndimage.gaussian_filter(rays, 0.8) * 0.6 + noise * 0.05
    nf = height_to_normal(Hf, 1.0, 1.0, k=1.6)
    mask = a > 0.02
    # dilate colour into empty texels so mips never pull in black
    idx = ndimage.distance_transform_edt(~mask, return_distances=False, return_indices=True)
    col = col[idx[0], idx[1]]
    ALB[y0 : y0 + rh, x0 : x0 + rw, :3] = np.clip(col, 0, 1)
    ALB[y0 : y0 + rh, x0 : x0 + rw, 3] = a
    NRM[y0 : y0 + rh, x0 : x0 + rw] = np.where(mask[..., None], nf, np.array([0, 0, 1], np.float32))
    ORM[y0 : y0 + rh, x0 : x0 + rw, 0] = 1.0
    ORM[y0 : y0 + rh, x0 : x0 + rw, 1] = 0.36 - 0.08 * rays
    ORM[y0 : y0 + rh, x0 : x0 + rw, 2] = 0.04

    # eye disc: pupil, iris with radial fibres and a gold ring, dark limbus
    ex, ey, ew, eh, lo, hi, _ = rects["eye"]
    px0, py0 = bx + ex, by + F.BODY_H + 2 + ey
    yy, xx = np.mgrid[0:eh, 0:ew]
    cx, cy = (ew - 1) / 2, (eh - 1) / 2
    rr = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (min(ew, eh) / 2 / 1.15)
    ang = np.arctan2(yy - cy, xx - cx)
    iris = c["iris"]
    fib = 0.5 + 0.5 * np.sin(ang * 46 + 3 * np.sin(ang * 7)) * (0.6 + 0.4 * np.sin(rr * 30))
    ecol = mix(iris * 0.55, iris * 1.08, fib * sstep(0.42, 0.80, rr))
    ecol = mix(ecol, np.clip(iris * 1.15, 0, 1), np.exp(-(((rr - 0.52) / 0.04) ** 2)) * 0.35)
    ecol = mix(ecol, ecol * 0.55, sstep(0.62, 0.84, rr))
    ecol = mix(ecol, rgb("#14120c"), sstep(0.82, 0.98, rr))
    pupil = 1 - sstep(0.44, 0.49, rr)
    ecol = mix(ecol, rgb("#020304"), pupil)
    ALB[py0 : py0 + eh, px0 : px0 + ew, :3] = np.clip(ecol, 0, 1)
    ALB[py0 : py0 + eh, px0 : px0 + ew, 3] = 1.0
    NRM[py0 : py0 + eh, px0 : px0 + ew] = (0, 0, 1)
    ORM[py0 : py0 + eh, px0 : px0 + ew, 0] = 1.0
    ORM[py0 : py0 + eh, px0 : px0 + ew, 1] = 0.03
    ORM[py0 : py0 + eh, px0 : px0 + ew, 2] = np.where((rr > 0.45) & (rr < 0.85), 0.5, 0.0)
    if "barbel" in rects:
        bxr, byr, bw, bh = rects["barbel"][:4]
        ALB[by + F.BODY_H + 2 + byr : by + F.BODY_H + 2 + byr + bh, bx + bxr : bx + bxr + bw] = (
            *c["lips"],
            1.0,
        )
        ORM[by + F.BODY_H + 2 + byr : by + F.BODY_H + 2 + byr + bh, bx + bxr : bx + bxr + bw] = (
            1,
            0.45,
            0,
        )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in F.ORDER:
        b = paint_body(name)
        paint_fins(b)
        print("painted", name)

    def srgb8(a):
        return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)

    Image.fromarray(srgb8(ALB), "RGBA").save(OUT / "fish_w1_albedo.png", optimize=True)
    Image.fromarray(srgb8(NRM * 0.5 + 0.5), "RGB").save(OUT / "fish_w1_normal.png", optimize=True)
    Image.fromarray(srgb8(ORM), "RGB").save(OUT / "fish_w1_orm.png", optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
