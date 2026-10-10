"""Gameplay cues, HUD, zones, greyscale proof and win card over the Blender render.

Run:  python3 overlay.py <render_dir> <mockups_dir>
Needs <render_dir>/w1_raw.png, mask_{edible,danger,player}_0001.png, fish.json, w1_portrait.png.
Writes world1_mock.png, world1_zones.png, world1_grey.png, wincard_mock.png
and prints the contrast table (WCAG 2.x, my calc).
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

RD = Path(sys.argv[1])
MD = Path(sys.argv[2])
W, H = 1080, 1920
SS = 4  # supersampling for vector drawing

# tokens (DESIGN.md section 8)
WHITE = (255, 255, 255)
INK = (20, 24, 28)  # ink #14181C
GOLD = (245, 192, 0)  # player gold #F5C000
HUD_GLASS = (8, 38, 46)  # #08262E at alpha 0.78
HUD_EDGE = (226, 240, 238)  # #E2F0EE
CARD = (244, 248, 246)  # #F4F8F6
CARD_EDGE = (94, 127, 134)  # #5E7F86
GREEN_SOFT = (227, 240, 234)


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (ch(x) for x in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def blend(c, bg, a):
    return tuple(round(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def load_mask(name):
    m = Image.open(RD / f"{name}_0001.png").convert("L")
    return np.array(m) > 127


raw = Image.open(RD / "w1_raw.png").convert("RGB")
base = np.array(raw)
edible = load_mask("mask_edible")
danger = load_mask("mask_danger")
player = load_mask("mask_player")

# ------------------------------------------------------------------ cues (GDD 4.3, Lett: on every fish)
import json  # noqa: E402

info = json.loads((RD / "fish.json").read_text())["fish"]
pl = next(f for f in info if f["kind"] == 3)
pcx, pcy = pl["px"], pl["py"]
pl_y, pl_x = np.nonzero(player)
print(f"player centre ({pcx}, {pcy}), tier {pl['tier']}, mask length {pl_x.max() - pl_x.min()} px")

cue = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
cd = ImageDraw.Draw(cue)
ring_boxes = []


def bubble_ring(cx, cy, length, phase=0.0):
    """Edible: smooth round ring of 12 small rim-lit bubbles."""
    r = 0.62 * length + 16
    for k in range(12):
        a = phase + 2 * math.pi * k / 12
        bx, by = cx + r * math.cos(a), cy + r * 0.82 * math.sin(a)
        br = 7 + 2 * (k % 3 == 0)
        cd.ellipse(
            ((bx - br - 2) * SS, (by - br - 2) * SS, (bx + br + 2) * SS, (by + br + 2) * SS),
            outline=(*INK, 130),
            width=3 * SS,
        )
        cd.ellipse(
            ((bx - br) * SS, (by - br) * SS, (bx + br) * SS, (by + br) * SS),
            fill=(*WHITE, 70),
            outline=(*WHITE, 245),
            width=3 * SS,
        )
        cd.ellipse(
            (
                (bx - br * 0.45 - 2) * SS,
                (by - br * 0.55 - 2) * SS,
                (bx - br * 0.45 + 2) * SS,
                (by - br * 0.55 + 2) * SS,
            ),
            fill=(*WHITE, 255),
        )
    return (cx - r - 12, cy - r - 12, cx + r + 12, cy + r + 12)


def zigzag_ring(cx, cy, length):
    """Danger: 8-point zigzag star, ink 10 px under white 4 px, pulses 1.00-1.06 in scale at 1 Hz (peak shown)."""
    ro, ri = 0.70 * length + 30, 0.56 * length + 14
    pts = []
    for k in range(16):
        a = -math.pi / 2 + 2 * math.pi * k / 16
        r = ro if k % 2 == 0 else ri
        pts.append(((cx + r * math.cos(a)) * SS, (cy + r * 0.80 * math.sin(a)) * SS))
    cd.line(pts + [pts[0], pts[1]], fill=(*INK, 160), width=11 * SS, joint="curve")
    cd.line(pts + [pts[0], pts[1]], fill=(*WHITE, 245), width=4 * SS, joint="curve")
    return (cx - ro - 8, cy - ro - 8, cx + ro + 8, cy + ro + 8)


for f in info:
    # ring centre = body centre; the model origin sits about 0.1 x length ahead of the length midpoint
    off = 0.08 * f["len_px"] * (1 if f["facing_left"] else -1)
    if f["kind"] == 1:
        ring_boxes.append(
            ("edible", bubble_ring(f["px"] + off, f["py"], f["len_px"], phase=f["px"] * 0.01))
        )
    elif f["kind"] == 2:
        ring_boxes.append(("danger", zigzag_ring(f["px"] + off, f["py"], f["len_px"])))

# aim ring (GDD 3.3): 64 px soft ring at the aim point, finger is below it (lift 120 px)
ax, ay = 700, 820
cd.ellipse(
    ((ax - 34) * SS, (ay - 34) * SS, (ax + 34) * SS, (ay + 34) * SS),
    outline=(*INK, 110),
    width=8 * SS,
)
cd.ellipse(
    ((ax - 32) * SS, (ay - 32) * SS, (ax + 32) * SS, (ay + 32) * SS),
    outline=(*WHITE, 200),
    width=4 * SS,
)
cue = cue.resize((W, H), Image.LANCZOS)
scene = raw.convert("RGBA")
scene.alpha_composite(cue)
near = edible  # for the contrast rows below
danger_box = next(b for k, b in ring_boxes if k == "danger")


# ------------------------------------------------------------------ HUD
def fish_icon(draw, cx, cy, length, fill, outline, ow, s=SS):
    """Side silhouette of the player species: deep body, forked tail."""
    L = length * s
    hgt = L * 0.42
    bx0 = cx * s - L * 0.5
    body = [(bx0 + L * 0.28, cy * s)]
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        x = bx0 + L * 0.28 + t * L * 0.72
        hh = hgt / 2 * math.sin(math.pi * (t**0.75)) ** 0.8
        body.append((x, cy * s - hh))
    for i in range(steps, -1, -1):
        t = i / steps
        x = bx0 + L * 0.28 + t * L * 0.72
        hh = hgt / 2 * 0.9 * math.sin(math.pi * (t**0.75)) ** 0.8
        body.append((x, cy * s + hh))
    tail = [
        (bx0 + L * 0.32, cy * s),
        (bx0, cy * s - hgt * 0.55),
        (bx0 + L * 0.1, cy * s),
        (bx0, cy * s + hgt * 0.55),
    ]
    for poly in (tail, body):
        if fill is not None:
            draw.polygon(poly, fill=fill)
        if outline:
            draw.line(poly + [poly[0]], fill=outline, width=int(ow * s), joint="curve")
    # eye
    ex, ey, er = bx0 + L * 0.86, cy * s - hgt * 0.08, max(L * 0.035, 2 * s)
    draw.ellipse((ex - er, ey - er, ex + er, ey + er), fill=outline or INK)


def star_pts(cx, cy, R, s=SS):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = R if k % 2 == 0 else R * 0.45
        pts.append(((cx + rr * math.cos(a)) * s, (cy + rr * math.sin(a)) * s))
    return pts


def draw_hud(img, tiers=(2, 3, 4), current=3, fill=0.55, done=False):
    """GDD 8.2 Vokse: one silhouette per tier from 2 to the goal, drawn at relative size (x1.28 per tier)."""
    hud = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(hud)
    c, r = 104 * SS, 68 * SS
    d.ellipse((c - r, c - r, c + r, c + r), fill=WHITE, outline=INK, width=5 * SS)
    hs = 34 * SS
    d.polygon([(c - hs, c - 2 * SS), (c, c - hs), (c + hs, c - 2 * SS)], fill=INK)
    d.rectangle((c - hs * 0.68, c - 4 * SS, c + hs * 0.68, c + hs * 0.8), fill=INK)
    d.rectangle((c - 9 * SS, c + 8 * SS, c + 9 * SS, c + hs * 0.8), fill=WHITE)
    px0, py0, px1, py1 = 256, 52, 1044, 204
    d.rounded_rectangle(
        (px0 * SS, py0 * SS, px1 * SS, py1 * SS),
        radius=76 * SS,
        fill=(*HUD_GLASS, 200),
        outline=(*HUD_EDGE, 255),
        width=4 * SS,
    )
    n = len(tiers)
    base_len = 150 / 1.28 ** (n - 1)  # goal silhouette 150 px long
    lens = [base_len * 1.28**k for k in range(n)]
    gap = 34
    total = sum(lens) + gap * (n - 1)
    x = (px0 + px1) / 2 - total / 2 - 20
    ty = 128
    centres = []
    for k, (t, L) in enumerate(zip(tiers, lens)):
        cx = x + L / 2
        centres.append(cx)
        if done or t < current:
            fish_icon(d, cx, ty, L, WHITE, INK, 4)
        elif t == current:
            # empty outline, then gold fill clipped from the tail (left) to fill fraction
            fish_icon(d, cx, ty, L, (*HUD_GLASS, 255), HUD_EDGE, 4)
            layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            fish_icon(ld, cx, ty, L, GOLD, None, 0)
            clip = Image.new("L", (W * SS, H * SS), 0)
            ImageDraw.Draw(clip).rectangle(
                ((cx - L / 2) * SS, 0, (cx - L / 2 + L * fill) * SS, H * SS), fill=255
            )
            hud.paste(
                layer,
                (0, 0),
                Image.composite(layer, Image.new("RGBA", layer.size), clip).split()[3],
            )
            d = ImageDraw.Draw(hud)
            fish_icon(d, cx, ty, L, None, INK, 4)
        else:
            fish_icon(d, cx, ty, L, (*HUD_GLASS, 255), HUD_EDGE, 4)
        x += L + gap
    # goal star on the last silhouette (top right of it)
    gx = centres[-1] + lens[-1] * 0.42
    sp = star_pts(gx + 18, ty - 40, 28)
    d.polygon(sp, fill=GOLD)
    d.line(sp + [sp[0]], fill=INK, width=5 * SS, joint="curve")
    img.alpha_composite(hud.resize((W, H), Image.LANCZOS))
    return (px0, py0, px1, py1), centres, None


hud_box, stage_xs, fill_to = draw_hud(scene)
scene.convert("RGB").save(MD / "world1_mock.png", optimize=True)

# ------------------------------------------------------------------ zones
z = scene.copy()
zd = ImageDraw.Draw(z)
zd.rectangle((0, 0, 231, 231), outline=WHITE, width=5)
zd.rectangle((hud_box[0], hud_box[1], hud_box[2], hud_box[3]), outline=(60, 160, 255), width=5)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(ov)
od.rectangle((0, 1664, W, H), fill=(230, 40, 40, 70))
od.rectangle((0, 256, W - 1, 1640), outline=(255, 220, 0, 255), width=5)
for kind, (bx0, by0, bx1, by1) in ring_boxes:
    od.rectangle((bx0, by0, bx1, by1), outline=(80, 255, 140, 200), width=2)
z.alpha_composite(ov)
z.convert("RGB").save(MD / "world1_zones.png", optimize=True)

# ------------------------------------------------------------------ greyscale proof (colour-blind / no-colour check)
g = scene.convert("L").convert("RGB")
g.save(MD / "world1_grey.png", optimize=True)

# ------------------------------------------------------------------ win card
card_bg = raw.filter(ImageFilter.GaussianBlur(14)).convert("RGBA")
card_bg.alpha_composite(Image.new("RGBA", (W, H), (4, 20, 26, 120)))
wc = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(wc)
d.rounded_rectangle(
    (100 * SS, 330 * SS, 980 * SS, 1470 * SS),
    radius=56 * SS,
    fill=(*CARD, 255),
    outline=(*CARD_EDGE, 255),
    width=4 * SS,
)
card_bg.alpha_composite(wc.resize((W, H), Image.LANCZOS))
portrait = Image.open(RD / "w1_portrait.png").convert("RGB").resize((780, 560), Image.LANCZOS)
pm = Image.new("L", (780 * SS, 560 * SS), 0)
ImageDraw.Draw(pm).rounded_rectangle((0, 0, 780 * SS, 560 * SS), radius=36 * SS, fill=255)
card_bg.paste(portrait, (150, 380), pm.resize((780, 560), Image.LANCZOS))
wc = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(wc)
d.rounded_rectangle(
    (150 * SS, 380 * SS, 930 * SS, 940 * SS), radius=36 * SS, outline=(*INK, 255), width=5 * SS
)
# growth row, all five reached, last one gold = "you grew all the way"
row = [110, 141, 180]
x = 540 - (sum(row) + 2 * 50) / 2
for i, L in enumerate(row):
    fish_icon(d, x + L / 2, 1040, L, GOLD if i == 2 else WHITE, INK, 4)
    x += L + 50
# star (finish reward, rule 30)
scx, scy, R = 540, 1160, 62
spts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    rr = R if k % 2 == 0 else R * 0.45
    spts.append(((scx + rr * math.cos(a)) * SS, (scy + rr * math.sin(a)) * SS))
d.polygon(spts, fill=GOLD)
d.line(spts + [spts[0]], fill=INK, width=8 * SS, joint="curve")


def disc(cx, cy, dia, fill, icon):
    r = dia / 2
    d.ellipse(
        ((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS),
        fill=fill,
        outline=INK,
        width=6 * SS,
    )
    s = SS
    if icon == "replay":
        d.arc(
            ((cx - 40) * s, (cy - 40) * s, (cx + 40) * s, (cy + 40) * s),
            40,
            330,
            fill=INK,
            width=14 * s,
        )
        d.polygon(
            [
                ((cx + 30) * s, (cy - 52) * s),
                ((cx + 56) * s, (cy - 18) * s),
                ((cx + 14) * s, (cy - 14) * s),
            ],
            fill=INK,
        )
    elif icon == "map":  # three dots on a path = level map
        for k, (ox, oy) in enumerate(((-38, 22), (0, -16), (38, 18))):
            rr = 15
            d.ellipse(
                ((cx + ox - rr) * s, (cy + oy - rr) * s, (cx + ox + rr) * s, (cy + oy + rr) * s),
                fill=INK,
            )
        d.line(
            [
                ((cx - 38) * s, (cy + 22) * s),
                (cx * s, (cy - 16) * s),
                ((cx + 38) * s, (cy + 18) * s),
            ],
            fill=INK,
            width=8 * s,
        )
    elif icon == "next":
        d.polygon(
            [
                ((cx - 30) * s, (cy - 46) * s),
                ((cx + 50) * s, cy * s),
                ((cx - 30) * s, (cy + 46) * s),
            ],
            fill=INK,
        )


disc(270, 1340, 200, WHITE, "replay")
disc(540, 1340, 200, WHITE, "map")
disc(810, 1340, 240, GOLD, "next")
card_bg.alpha_composite(wc.resize((W, H), Image.LANCZOS))
draw_hud(card_bg, done=True)
card_bg.convert("RGB").save(MD / "wincard_mock.png", optimize=True)

# ------------------------------------------------------------------ contrast report (my calc)
arr = base.astype(float)


def ring_mean(mask, it_out=10, it_in=6):
    ring = ndimage.binary_dilation(mask, iterations=it_out) & ~ndimage.binary_dilation(
        mask, iterations=it_in
    )
    return tuple(arr[ring].mean(axis=0))


def region_mean(box):
    x0_, y0_, x1_, y1_ = box
    return tuple(arr[y0_:y1_, x0_:x1_].reshape(-1, 3).mean(axis=0))


def region_max_lum(box):
    x0_, y0_, x1_, y1_ = box
    px = arr[y0_:y1_, x0_:x1_].reshape(-1, 3)
    lums = [lum(tuple(p)) for p in px[:: max(1, len(px) // 4000)]]
    i = int(np.argmax(lums))
    return tuple(px[:: max(1, len(px) // 4000)][i])


rows = []
bg_player = ring_mean(player)
pl_mean = tuple(arr[player].mean(axis=0))
rows.append(("Player body mean vs water around it", pl_mean, bg_player))


def box_ring_mean(box, inset):
    x0_, y0_, x1_, y1_ = (int(round(v)) for v in box)
    x0_, y0_ = max(0, x0_), max(0, y0_)
    x1_, y1_ = min(W, x1_), min(H, y1_)
    m = np.zeros((H, W), bool)
    m[y0_:y1_, x0_:x1_] = True
    m[y0_ + inset : y1_ - inset, x0_ + inset : x1_ - inset] = False
    return tuple(arr[m].mean(axis=0))


worst_e = min((box_ring_mean(b, 30) for k, b in ring_boxes if k == "edible"), key=lambda c: -lum(c))
rows.append(("Edible bubble rim white vs brightest water behind any edible ring", WHITE, worst_e))
bg_d = box_ring_mean(danger_box, 40)
rows.append(("Danger ring white vs water behind it", WHITE, bg_d))
rows.append(("Danger ring ink stroke vs water", blend(INK, bg_d, 160 / 255), bg_d))
hud_behind = region_mean((256, 52, 1044, 204))
hud_fill = blend(HUD_GLASS, hud_behind, 200 / 255)
rows.append(
    ("HUD panel (glass over surface) vs water behind", hud_fill, region_mean((256, 210, 1044, 240)))
)
rows.append(("HUD edge vs water behind the panel", HUD_EDGE, region_max_lum((256, 40, 1044, 52))))
rows.append(("Gold current-tier fill vs HUD panel", GOLD, hud_fill))
rows.append(("White reached-stage fish vs HUD panel", WHITE, hud_fill))
rows.append(("Hollow future-stage outline vs HUD panel", HUD_EDGE, hud_fill))
rows.append(("Ink silhouette outline vs gold fill", INK, GOLD))
rows.append(("Home disc white vs water top-left", WHITE, region_mean((0, 0, 232, 232))))
rows.append(
    (
        "Home disc ink ring vs water top-left (the boundary that counts)",
        INK,
        region_mean((0, 0, 232, 232)),
    )
)
pl_px = arr[player]
pl_l = np.array([lum(tuple(c)) for c in pl_px[::7]])
bright = tuple(pl_px[::7][pl_l >= np.percentile(pl_l, 60)].mean(axis=0))
dark = tuple(pl_px[::7][pl_l <= np.percentile(pl_l, 15)].mean(axis=0))
rows.append(("Player gold flank (top 40% luminance) vs water around it", bright, bg_player))
rows.append(("Player dark bars (bottom 15%) vs gold flank (shape cue)", dark, bright))
d_px = arr[danger]
rows.append(
    ("Danger fish body mean vs water around it", tuple(d_px.mean(axis=0)), ring_mean(danger))
)
rows.append(("Ink icons/rings vs white", INK, WHITE))
rows.append(("Ink on gold (next disc, star)", INK, GOLD))
rows.append(("Card edge vs card", CARD_EDGE, CARD))
rows.append(
    (
        "Card vs dimmed scene",
        CARD,
        blend(
            (4, 20, 26),
            tuple(np.array(raw.filter(ImageFilter.GaussianBlur(14))).reshape(-1, 3).mean(axis=0)),
            120 / 255,
        ),
    )
)
print("| Pair | Colours | Ratio |\n|---|---|---|")
for name, a, b in rows:
    ha = "#%02X%02X%02X" % tuple(int(round(v)) for v in a)
    hb = "#%02X%02X%02X" % tuple(int(round(v)) for v in b)
    print(f"| {name} | {ha} on {hb} | {ratio(a, b):.2f}:1 |")
print("rings", ring_boxes)
