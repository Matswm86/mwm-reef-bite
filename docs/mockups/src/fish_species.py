"""World-1 fish roster: shape, fin and colour spec shared by the texture painter and the Blender builder.

Units: L = total length nose to tail tip = 1.0. s = distance from the snout along the body (0..1),
z = height above the body axis. The body runs from s = 0 to s = sb (caudal base); the tail fin fills sb..1.
Blender/glTF placement: snout at x = +ORIGIN_S, so the model origin sits 0.42 L behind the snout and the
bounding-box centre 0.08 L behind the origin (DESIGN.md section 5 ring offset).

Pure Python + numpy so both system python3 (painter) and Blender's python (builder) can import it.
"""

import math

import numpy as np

ORIGIN_S = 0.42
BLOCK_W, BLOCK_H = 1024, 512  # one species block in the 2048 atlas (2 columns x 4 rows)
BODY_H = 320  # body strip height inside the block; fins and eye pack below
ATLAS = 2048


def pchip(xs, ys, x):
    """Monotone cubic (Fritsch-Carlson) so profiles never overshoot into bumps."""
    xs = np.asarray(xs, float)
    ys = np.asarray(ys, float)
    x = np.clip(np.asarray(x, float), xs[0], xs[-1])
    h = np.diff(xs)
    d = np.diff(ys) / h
    m = np.zeros_like(ys)
    m[0], m[-1] = d[0], d[-1]
    for k in range(1, len(xs) - 1):
        if d[k - 1] * d[k] <= 0:
            m[k] = 0.0
        else:
            w1, w2 = 2 * h[k] + h[k - 1], h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k])
    i = np.clip(np.searchsorted(xs, x) - 1, 0, len(xs) - 2)
    t = (x - xs[i]) / h[i]
    h00 = 2 * t**3 - 3 * t**2 + 1
    h10 = t**3 - 2 * t**2 + t
    h01 = -2 * t**3 + 3 * t**2
    h11 = t**3 - t**2
    return h00 * ys[i] + h10 * h[i] * m[i] + h01 * ys[i + 1] + h11 * h[i] * m[i + 1]


# ------------------------------------------------------------------ roster
# prof: (s, top z, bottom z, half width). Real proportions from photo reference (FishBase side views).
SPECIES = {
    "golden_trevally": dict(
        tier="player (2-10)",
        common="Golden trevally (juvenile)",
        latin="Gnathanodon speciosus",
        hero=True,
        sb=0.775,
        prof=[
            (0.000, -0.012, -0.040, 0.010),
            (0.020, 0.034, -0.066, 0.026),
            (0.050, 0.076, -0.090, 0.038),
            (0.090, 0.116, -0.114, 0.048),
            (0.150, 0.158, -0.150, 0.058),
            (0.250, 0.190, -0.178, 0.064),
            (0.350, 0.188, -0.176, 0.061),
            (0.450, 0.160, -0.155, 0.054),
            (0.550, 0.112, -0.112, 0.043),
            (0.650, 0.064, -0.064, 0.028),
            (0.720, 0.033, -0.033, 0.017),
            (0.755, 0.021, -0.021, 0.013),
            (0.775, 0.027, -0.027, 0.010),
        ],
        mouth=dict(z=-0.028, end_s=0.058, drop=0.010, lips=0.014),
        eye=dict(s=0.092, zn=0.63, r=0.024),
        op=dict(s=0.215, pre=0.165),
        ll=dict(arch=0.07, end_rise=0.0, scutes=(0.56, 0.77)),
        scale=0.0065,
        scale_amp=0.07,
        section=2.3,
        fins=[
            dict(
                kind="dorsal",
                s0=0.300,
                s1=0.372,
                h=[0.0, 0.050, 0.046, 0.032, 0.010],
                rake=0.35,
                rays=7,
                spiny=True,
            ),
            dict(
                kind="dorsal",
                s0=0.405,
                s1=0.735,
                h=[0.0, 0.092, 0.060, 0.036, 0.028, 0.024, 0.018, 0.010],
                rake=0.30,
                rays=20,
            ),
            dict(
                kind="anal",
                s0=0.500,
                s1=0.735,
                h=[0.0, 0.078, 0.046, 0.030, 0.022, 0.016, 0.008],
                rake=0.30,
                rays=16,
            ),
            dict(kind="caudal", len=0.225, fork=0.78, spread=0.95, lobe="sickle", rays=19),
            dict(
                kind="pectoral",
                s=0.225,
                zn=0.40,
                len=0.190,
                wid=0.030,
                shape="falcate",
                down=14,
                out=9,
                rays=14,
            ),
            dict(
                kind="pelvic", s=0.250, len=0.060, wid=0.016, shape="round", down=22, out=30, rays=6
            ),
        ],
        colors=dict(
            belly="#ecebe0",
            flank="#ecb426",
            back="#7a5c0e",
            head="#c99a1e",
            iris="#e2c24a",
            fin="#e2ad18",
            fin_edge="#c48d10",
            ray="#a07612",
            lips="#cfc0a0",
            ll="#f2d870",
        ),
        metal=(0.40, 0.25),
        rough=(0.22, 0.32),
    ),
    "brisling": dict(
        tier=1,
        common="Brisling (European sprat)",
        latin="Sprattus sprattus",
        sb=0.815,
        prof=[
            (0.000, -0.004, -0.016, 0.004),
            (0.030, 0.026, -0.032, 0.016),
            (0.100, 0.060, -0.066, 0.032),
            (0.220, 0.082, -0.092, 0.040),
            (0.400, 0.088, -0.096, 0.038),
            (0.550, 0.074, -0.080, 0.032),
            (0.700, 0.044, -0.046, 0.020),
            (0.790, 0.022, -0.022, 0.011),
            (0.815, 0.026, -0.026, 0.008),
        ],
        mouth=dict(z=-0.010, end_s=0.075, drop=0.020, lips=0.005, underbite=0.004),
        eye=dict(s=0.085, zn=0.60, r=0.025),
        op=dict(s=0.200, pre=0.150),
        ll=None,
        keel=True,
        scale=0.012,
        scale_amp=0.45,
        section=2.0,
        fins=[
            dict(
                kind="dorsal",
                s0=0.400,
                s1=0.520,
                h=[0.0, 0.070, 0.050, 0.030, 0.012],
                rake=0.25,
                rays=14,
            ),
            dict(
                kind="anal",
                s0=0.640,
                s1=0.770,
                h=[0.0, 0.030, 0.024, 0.016, 0.008],
                rake=0.20,
                rays=14,
            ),
            dict(kind="caudal", len=0.185, fork=0.70, spread=0.75, lobe="pointed", rays=19),
            dict(
                kind="pectoral",
                s=0.205,
                zn=0.22,
                len=0.075,
                wid=0.018,
                shape="pointed",
                down=28,
                out=20,
                rays=12,
            ),
            dict(
                kind="pelvic", s=0.420, len=0.045, wid=0.012, shape="round", down=22, out=30, rays=7
            ),
        ],
        colors=dict(
            belly="#f4f6f4",
            flank="#c7d3d6",
            back="#2c5b6c",
            head="#b8c8cc",
            iris="#b9c2c0",
            fin="#c8d2d4",
            fin_edge="#7b8e94",
            ray="#9aaab0",
            lips="#d7dcd9",
            ll="#e0e8ea",
        ),
        metal=(0.75, 0.45),
        rough=(0.20, 0.30),
    ),
    "gronngylt": dict(
        tier=2,
        common="Grønngylt (corkwing wrasse)",
        latin="Symphodus melops",
        sb=0.810,
        prof=[
            (0.000, -0.010, -0.030, 0.006),
            (0.040, 0.040, -0.058, 0.028),
            (0.120, 0.098, -0.098, 0.050),
            (0.250, 0.142, -0.138, 0.060),
            (0.400, 0.148, -0.138, 0.058),
            (0.550, 0.120, -0.114, 0.048),
            (0.700, 0.072, -0.070, 0.030),
            (0.780, 0.056, -0.056, 0.022),
            (0.810, 0.060, -0.060, 0.018),
        ],
        mouth=dict(z=-0.020, end_s=0.045, drop=0.006, lips=0.010),
        eye=dict(s=0.100, zn=0.66, r=0.022),
        op=dict(s=0.240, pre=0.185),
        ll=dict(arch=0.08, end_rise=0.0, break_s=0.62),
        scale=0.017,
        scale_amp=0.40,
        section=2.4,
        fins=[
            dict(
                kind="dorsal",
                s0=0.250,
                s1=0.790,
                h=[0.0, 0.062, 0.064, 0.066, 0.070, 0.082, 0.084, 0.050],
                rake=0.15,
                rays=24,
                spiny=True,
            ),
            dict(
                kind="anal",
                s0=0.540,
                s1=0.790,
                h=[0.0, 0.050, 0.068, 0.072, 0.062, 0.030],
                rake=0.15,
                rays=12,
            ),
            dict(kind="caudal", len=0.190, fork=-0.12, spread=0.62, lobe="round", rays=14),
            dict(
                kind="pectoral",
                s=0.250,
                zn=0.45,
                len=0.090,
                wid=0.040,
                shape="round",
                down=18,
                out=22,
                rays=13,
            ),
            dict(
                kind="pelvic", s=0.270, len=0.060, wid=0.016, shape="round", down=22, out=30, rays=6
            ),
        ],
        colors=dict(
            belly="#d8c79a",
            flank="#7c7a34",
            back="#3d4a22",
            head="#6f6a2c",
            iris="#d9752c",
            fin="#6e6a2c",
            fin_edge="#3c6a6a",
            ray="#4b4a1e",
            lips="#9a7a40",
            ll="#b8b070",
            line="#3fa3a6",
            line2="#d0743a",
            spot="#151510",
        ),
        metal=(0.12, 0.05),
        rough=(0.30, 0.40),
    ),
    "sei": dict(
        tier=3,
        common="Sei (saithe, young)",
        latin="Pollachius virens",
        sb=0.825,
        prof=[
            (0.000, -0.006, -0.020, 0.005),
            (0.030, 0.028, -0.044, 0.024),
            (0.100, 0.068, -0.080, 0.044),
            (0.220, 0.094, -0.100, 0.054),
            (0.380, 0.098, -0.100, 0.052),
            (0.550, 0.078, -0.080, 0.040),
            (0.700, 0.044, -0.045, 0.024),
            (0.800, 0.023, -0.023, 0.012),
            (0.825, 0.029, -0.029, 0.009),
        ],
        mouth=dict(z=-0.012, end_s=0.070, drop=0.014, lips=0.006, underbite=0.003),
        eye=dict(s=0.090, zn=0.62, r=0.020),
        op=dict(s=0.215, pre=0.165),
        ll=dict(arch=0.01, end_rise=0.0, pale=True),
        scale=0.0055,
        scale_amp=0.22,
        section=2.2,
        fins=[
            dict(
                kind="dorsal",
                s0=0.270,
                s1=0.380,
                h=[0.0, 0.074, 0.064, 0.040, 0.012],
                rake=0.35,
                rays=13,
            ),
            dict(
                kind="dorsal",
                s0=0.420,
                s1=0.590,
                h=[0.0, 0.056, 0.046, 0.034, 0.018, 0.006],
                rake=0.30,
                rays=20,
            ),
            dict(
                kind="dorsal",
                s0=0.630,
                s1=0.770,
                h=[0.0, 0.046, 0.036, 0.022, 0.006],
                rake=0.30,
                rays=19,
            ),
            dict(
                kind="anal",
                s0=0.420,
                s1=0.600,
                h=[0.0, 0.048, 0.040, 0.026, 0.012, 0.004],
                rake=0.30,
                rays=24,
            ),
            dict(
                kind="anal",
                s0=0.640,
                s1=0.765,
                h=[0.0, 0.038, 0.030, 0.018, 0.005],
                rake=0.30,
                rays=19,
            ),
            dict(kind="caudal", len=0.175, fork=0.22, spread=0.70, lobe="pointed", rays=22),
            dict(
                kind="pectoral",
                s=0.225,
                zn=0.48,
                len=0.085,
                wid=0.022,
                shape="pointed",
                down=22,
                out=20,
                rays=18,
            ),
            dict(
                kind="pelvic",
                s=0.205,
                len=0.050,
                wid=0.012,
                shape="pointed",
                down=22,
                out=30,
                rays=6,
            ),
        ],
        colors=dict(
            belly="#e2e4e0",
            flank="#7e8a86",
            back="#26332f",
            head="#6b7774",
            iris="#cfd2c0",
            fin="#3a4644",
            fin_edge="#222c2a",
            ray="#2c3634",
            lips="#9aa29e",
            ll="#e8ecdc",
        ),
        metal=(0.45, 0.20),
        rough=(0.24, 0.34),
    ),
    "berggylt": dict(
        tier=4,
        common="Berggylt (ballan wrasse)",
        latin="Labrus bergylta",
        sb=0.805,
        prof=[
            (0.000, -0.008, -0.036, 0.008),
            (0.040, 0.046, -0.068, 0.034),
            (0.120, 0.102, -0.112, 0.060),
            (0.250, 0.146, -0.146, 0.074),
            (0.420, 0.150, -0.140, 0.070),
            (0.580, 0.120, -0.110, 0.055),
            (0.720, 0.076, -0.072, 0.034),
            (0.790, 0.062, -0.062, 0.025),
            (0.805, 0.064, -0.064, 0.022),
        ],
        mouth=dict(z=-0.024, end_s=0.055, drop=0.008, lips=0.016),
        eye=dict(s=0.105, zn=0.66, r=0.019),
        op=dict(s=0.250, pre=0.190),
        ll=dict(arch=0.07, end_rise=0.0),
        scale=0.021,
        scale_amp=0.42,
        section=2.4,
        fins=[
            dict(
                kind="dorsal",
                s0=0.240,
                s1=0.790,
                h=[0.0, 0.066, 0.068, 0.068, 0.070, 0.080, 0.086, 0.050],
                rake=0.12,
                rays=29,
                spiny=True,
            ),
            dict(
                kind="anal",
                s0=0.560,
                s1=0.790,
                h=[0.0, 0.056, 0.074, 0.076, 0.060, 0.030],
                rake=0.15,
                rays=12,
            ),
            dict(kind="caudal", len=0.195, fork=-0.18, spread=0.66, lobe="round", rays=14),
            dict(
                kind="pectoral",
                s=0.255,
                zn=0.45,
                len=0.095,
                wid=0.045,
                shape="round",
                down=16,
                out=22,
                rays=14,
            ),
            dict(
                kind="pelvic", s=0.270, len=0.065, wid=0.018, shape="round", down=22, out=30, rays=6
            ),
        ],
        colors=dict(
            belly="#d8c08e",
            flank="#5f6a34",
            back="#2f3a1e",
            head="#5a5a2a",
            iris="#d48a3a",
            fin="#4f5a2a",
            fin_edge="#2e3a1c",
            ray="#3a4220",
            lips="#8a7038",
            ll="#a8a268",
            spot="#e3c27a",
        ),
        metal=(0.08, 0.04),
        rough=(0.32, 0.42),
    ),
    "lyr": dict(
        tier=5,
        common="Lyr (pollack)",
        latin="Pollachius pollachius",
        sb=0.825,
        prof=[
            (0.000, -0.002, -0.014, 0.005),
            (0.030, 0.024, -0.040, 0.024),
            (0.100, 0.070, -0.082, 0.046),
            (0.220, 0.100, -0.106, 0.056),
            (0.380, 0.104, -0.104, 0.054),
            (0.550, 0.080, -0.082, 0.041),
            (0.700, 0.044, -0.046, 0.024),
            (0.800, 0.023, -0.023, 0.012),
            (0.825, 0.030, -0.030, 0.009),
        ],
        mouth=dict(z=-0.006, end_s=0.080, drop=0.020, lips=0.007, underbite=0.010),
        eye=dict(s=0.095, zn=0.62, r=0.021),
        op=dict(s=0.220, pre=0.170),
        ll=dict(arch=0.32, end_rise=0.0, dark=True),
        scale=0.006,
        scale_amp=0.22,
        section=2.2,
        fins=[
            dict(
                kind="dorsal",
                s0=0.270,
                s1=0.390,
                h=[0.0, 0.078, 0.066, 0.040, 0.012],
                rake=0.35,
                rays=13,
            ),
            dict(
                kind="dorsal",
                s0=0.430,
                s1=0.600,
                h=[0.0, 0.058, 0.048, 0.034, 0.018, 0.006],
                rake=0.30,
                rays=19,
            ),
            dict(
                kind="dorsal",
                s0=0.640,
                s1=0.775,
                h=[0.0, 0.048, 0.036, 0.022, 0.006],
                rake=0.30,
                rays=18,
            ),
            dict(
                kind="anal",
                s0=0.420,
                s1=0.610,
                h=[0.0, 0.050, 0.042, 0.028, 0.012, 0.004],
                rake=0.30,
                rays=27,
            ),
            dict(
                kind="anal",
                s0=0.650,
                s1=0.770,
                h=[0.0, 0.040, 0.030, 0.018, 0.005],
                rake=0.30,
                rays=18,
            ),
            dict(kind="caudal", len=0.175, fork=0.14, spread=0.70, lobe="pointed", rays=22),
            dict(
                kind="pectoral",
                s=0.230,
                zn=0.48,
                len=0.090,
                wid=0.022,
                shape="pointed",
                down=22,
                out=20,
                rays=18,
            ),
            dict(
                kind="pelvic",
                s=0.210,
                len=0.050,
                wid=0.012,
                shape="pointed",
                down=22,
                out=30,
                rays=6,
            ),
        ],
        colors=dict(
            belly="#e4dcc4",
            flank="#8f8350",
            back="#3e3c22",
            head="#7e7448",
            iris="#d2c48a",
            fin="#5a5430",
            fin_edge="#3a3620",
            ray="#46422a",
            lips="#a69a78",
            ll="#2e2a18",
        ),
        metal=(0.40, 0.18),
        rough=(0.26, 0.36),
    ),
    "torsk": dict(
        tier=6,
        common="Torsk (Atlantic cod)",
        latin="Gadus morhua",
        sb=0.830,
        hero=True,
        prof=[
            (0.000, -0.004, -0.030, 0.008),
            (0.040, 0.050, -0.064, 0.036),
            (0.120, 0.092, -0.104, 0.062),
            (0.250, 0.110, -0.118, 0.070),
            (0.400, 0.106, -0.112, 0.062),
            (0.550, 0.084, -0.086, 0.048),
            (0.700, 0.050, -0.050, 0.028),
            (0.800, 0.030, -0.030, 0.016),
            (0.830, 0.037, -0.037, 0.012),
        ],
        mouth=dict(z=-0.020, end_s=0.090, drop=0.012, lips=0.010, overbite=0.006),
        eye=dict(s=0.105, zn=0.64, r=0.020),
        op=dict(s=0.245, pre=0.190),
        ll=dict(arch=0.30, end_rise=0.0, pale=True),
        barbel=dict(s=0.050, len=0.032),
        scale=0.0045,
        scale_amp=0.18,
        section=2.1,
        fins=[
            dict(
                kind="dorsal",
                s0=0.270,
                s1=0.400,
                h=[0.0, 0.070, 0.074, 0.060, 0.030, 0.008],
                rake=0.10,
                rays=14,
            ),
            dict(
                kind="dorsal",
                s0=0.430,
                s1=0.610,
                h=[0.0, 0.060, 0.062, 0.052, 0.030, 0.008],
                rake=0.10,
                rays=20,
            ),
            dict(
                kind="dorsal",
                s0=0.640,
                s1=0.790,
                h=[0.0, 0.052, 0.052, 0.040, 0.020, 0.006],
                rake=0.10,
                rays=19,
            ),
            dict(
                kind="anal",
                s0=0.430,
                s1=0.620,
                h=[0.0, 0.052, 0.054, 0.044, 0.024, 0.006],
                rake=0.10,
                rays=21,
            ),
            dict(
                kind="anal",
                s0=0.650,
                s1=0.785,
                h=[0.0, 0.044, 0.044, 0.032, 0.014, 0.004],
                rake=0.10,
                rays=17,
            ),
            dict(kind="caudal", len=0.170, fork=-0.02, spread=0.66, lobe="square", rays=24),
            dict(
                kind="pectoral",
                s=0.250,
                zn=0.45,
                len=0.090,
                wid=0.032,
                shape="round",
                down=20,
                out=22,
                rays=18,
            ),
            dict(
                kind="pelvic",
                s=0.215,
                len=0.060,
                wid=0.014,
                shape="pointed",
                down=22,
                out=30,
                rays=6,
            ),
        ],
        colors=dict(
            belly="#ece7d4",
            flank="#a08e5e",
            back="#4e4428",
            head="#8e7e52",
            iris="#b8a46a",
            fin="#7a6c46",
            fin_edge="#4e4430",
            ray="#5e5236",
            lips="#bfb090",
            ll="#f0e8cc",
            spot="#5a4a26",
        ),
        metal=(0.10, 0.04),
        rough=(0.30, 0.40),
    ),
    "havabbor": dict(
        tier=7,
        common="Havabbor (European sea bass)",
        latin="Dicentrarchus labrax",
        sb=0.815,
        hero=True,
        prof=[
            (0.000, -0.004, -0.022, 0.006),
            (0.040, 0.040, -0.050, 0.030),
            (0.120, 0.088, -0.088, 0.050),
            (0.250, 0.118, -0.114, 0.060),
            (0.400, 0.118, -0.110, 0.057),
            (0.550, 0.094, -0.090, 0.046),
            (0.700, 0.050, -0.050, 0.026),
            (0.795, 0.029, -0.029, 0.014),
            (0.815, 0.034, -0.034, 0.011),
        ],
        mouth=dict(z=-0.010, end_s=0.085, drop=0.022, lips=0.006, underbite=0.004),
        eye=dict(s=0.095, zn=0.63, r=0.019),
        op=dict(s=0.250, pre=0.180, spot=True),
        ll=dict(arch=0.03, end_rise=0.0, dark=True),
        scale=0.012,
        scale_amp=0.45,
        section=2.2,
        fins=[
            dict(
                kind="dorsal",
                s0=0.300,
                s1=0.440,
                h=[0.0, 0.088, 0.084, 0.066, 0.040, 0.012],
                rake=0.25,
                rays=9,
                spiny=True,
            ),
            dict(
                kind="dorsal",
                s0=0.490,
                s1=0.680,
                h=[0.0, 0.074, 0.058, 0.046, 0.036, 0.020],
                rake=0.25,
                rays=13,
            ),
            dict(
                kind="anal",
                s0=0.545,
                s1=0.690,
                h=[0.0, 0.070, 0.056, 0.042, 0.030, 0.012],
                rake=0.25,
                rays=13,
            ),
            dict(kind="caudal", len=0.185, fork=0.30, spread=0.78, lobe="pointed", rays=18),
            dict(
                kind="pectoral",
                s=0.255,
                zn=0.45,
                len=0.085,
                wid=0.026,
                shape="pointed",
                down=22,
                out=20,
                rays=16,
            ),
            dict(
                kind="pelvic",
                s=0.275,
                len=0.060,
                wid=0.016,
                shape="pointed",
                down=22,
                out=30,
                rays=6,
            ),
        ],
        colors=dict(
            belly="#f0f1ee",
            flank="#b4bcbc",
            back="#42555c",
            head="#a4aeb0",
            iris="#d9d6c4",
            fin="#8e989a",
            fin_edge="#5a666a",
            ray="#6f7a7e",
            lips="#c4cac8",
            ll="#4a565c",
            spot="#1c2428",
        ),
        metal=(0.65, 0.35),
        rough=(0.20, 0.30),
    ),
}
ORDER = ["golden_trevally", "brisling", "gronngylt", "sei", "berggylt", "lyr", "torsk", "havabbor"]


def block_origin(name):
    i = ORDER.index(name)
    return (i % 2) * BLOCK_W, (i // 2) * BLOCK_H  # pixel x, y (y down) of the block's top-left


class Body:
    def __init__(self, name):
        self.name = name
        sp = SPECIES[name]
        self.sp = sp
        p = np.array(sp["prof"], float)
        self.ps, self.pt, self.pb, self.pw = p[:, 0], p[:, 1], p[:, 2], p[:, 3]
        self.sb = sp["sb"]
        ss = np.linspace(0, self.sb, 400)
        self.zmax = float(self.top(ss).max()) + 0.006
        self.zmin = float(self.bot(ss).min()) - 0.006

    def top(self, s):
        return pchip(self.ps, self.pt, s)

    def bot(self, s):
        return pchip(self.ps, self.pb, s)

    def hw(self, s):
        return pchip(self.ps, self.pw, s)

    def mid(self, s):
        return 0.5 * (self.top(s) + self.bot(s))

    # body strip uv (0..1 inside the whole atlas, v up like Blender) for a side-view point
    def body_uv(self, s, z):
        bx, by = block_origin(self.name)
        px = bx + np.asarray(s) / self.sb * (BLOCK_W - 1)
        py = by + 3 + (self.zmax - np.asarray(z)) / (self.zmax - self.zmin) * (BODY_H - 7)
        return px / ATLAS, 1.0 - py / ATLAS

    def body_pixel_grid(self):
        """s, z for every pixel centre of the body strip (BODY_H x BLOCK_W)."""
        xs = np.arange(BLOCK_W)
        ys = np.arange(BODY_H)
        X, Y = np.meshgrid(xs, ys)
        S = X / (BLOCK_W - 1) * self.sb
        Z = self.zmax - (Y - 3) / (BODY_H - 7) * (self.zmax - self.zmin)
        return S, Z

    def eye_pos(self):
        e = self.sp["eye"]
        t, b = float(self.top(e["s"])), float(self.bot(e["s"]))
        return e["s"], b + (t - b) * e["zn"], e["r"]

    def mouth_z(self, s):
        """Mouth line: from the lips at the snout back and down to the gape end."""
        m = self.sp["mouth"]
        t = np.clip(np.asarray(s) / m["end_s"], 0, 1)
        return m["z"] - m["drop"] * t**1.4


# ------------------------------------------------------------------ fins
def fin_outline(body, f, n=48):
    """Return base (n,2) and outer (n,2) polylines of a fin in its own 2D frame.
    Median fins (dorsal, anal, caudal): side-view (s, z). Paired fins: local (x back, y up) from the fin root."""
    u = np.linspace(0, 1, n)
    k = f["kind"]
    if k in ("dorsal", "anal"):
        s = f["s0"] + u * (f["s1"] - f["s0"])
        hs = np.interp(u, np.linspace(0, 1, len(f["h"])), f["h"])
        hs = pchip(np.linspace(0, 1, len(f["h"])), f["h"], u)
        sign = 1 if k == "dorsal" else -1
        edge = body.top(s) if k == "dorsal" else body.bot(s)
        inset = 0.004
        base = np.stack([s, edge - sign * inset], 1)
        outer = np.stack([s + f["rake"] * hs, edge + sign * hs], 1)
        return base, outer
    if k == "caudal":
        sb = body.sb
        zc = float(body.mid(sb))
        hb = float(body.top(sb) - zc)
        v = 1 - 2 * u  # +1 top lobe -> -1 bottom lobe
        Lc, fork, spread = f["len"], f["fork"], f["spread"]
        lobe = f["lobe"]
        if lobe == "sickle":
            s_out = sb + Lc * (1 - fork * (1 - np.abs(v) ** 0.55))
            zz = zc + spread * Lc * np.sign(v) * np.abs(v) ** 0.85
        elif lobe == "pointed":
            s_out = sb + Lc * (1 - fork * (1 - np.abs(v) ** 0.8))
            zz = zc + spread * Lc * v
        elif lobe == "round":  # convex, fork < 0
            s_out = sb + Lc * (1 + fork * 0 - 0.30 * v**2)
            zz = zc + spread * Lc * np.sin(v * math.pi / 2)
        else:  # square / truncate
            s_out = sb + Lc * (1 - 0.06 * v**2 + 0.03 * np.abs(v))
            zz = zc + spread * Lc * v
        base = np.stack([np.full(n, sb - 0.012), zc + hb * 1.05 * v], 1)
        outer = np.stack([np.minimum(s_out, 1.0), zz], 1)
        return base, outer
    # paired fins: base vertical segment at x = 0, fin points back (+x)
    Lp, W = f["len"], f["wid"]
    y_base = W / 2 - u * W
    sh = f["shape"]
    if sh == "falcate":
        x_out = Lp * (1.0 - 0.80 * u**0.7)
        y_out = W / 2 + 0.10 * Lp - u * (W + 0.30 * Lp) - 0.10 * Lp * np.sin(u * math.pi)
    elif sh == "pointed":
        x_out = Lp * (1.0 - 0.65 * np.abs(u - 0.25) ** 0.9 / 0.75**0.9)
        y_out = W / 2 + 0.05 * Lp - u * (W + 0.25 * Lp)
    else:  # round
        x_out = Lp * (0.55 + 0.45 * np.sin(u * math.pi) ** 0.6)
        y_out = W / 2 + 0.08 * Lp - u * (W + 0.30 * Lp)
    base = np.stack([np.zeros(n), y_base], 1)
    outer = np.stack([x_out, y_out], 1)
    return base, outer


def fin_bbox(body, f):
    base, outer = fin_outline(body, f)
    allp = np.concatenate([base, outer])
    lo, hi = allp.min(0), allp.max(0)
    pad = 0.006
    return lo - pad, hi + pad


def pack_fins(body):
    """Shelf-pack every fin plus the eye into the strip under the body. Returns {key: (px, py, w, h, lo, hi)}."""
    sp = body.sp
    items = []
    for i, f in enumerate(sp["fins"]):
        lo, hi = fin_bbox(body, f)
        items.append((f"fin{i}", lo, hi))
    eye_r = sp["eye"]["r"]
    items.append(("eye", np.array([-eye_r * 1.15] * 2), np.array([eye_r * 1.15] * 2)))
    if sp.get("barbel"):
        items.append(("barbel", np.array([0.0, 0.0]), np.array([0.012, 0.012])))
    region_w, region_h = BLOCK_W - 4, BLOCK_H - BODY_H - 4
    scale = 1800.0
    while scale > 100:
        placed = {}
        x = y = 2
        shelf = 0
        ok = True

        def dims(t):
            ex, ey = t[2] - t[1]
            return (ey, ex) if ey > ex * 1.2 else (ex, ey)

        for key, lo, hi in sorted(items, key=lambda t: -dims(t)[1]):
            ex, ey = hi - lo
            rot = bool(ey > ex * 1.2)
            if rot:
                ex, ey = ey, ex
            w = int(math.ceil(ex * scale)) + 2
            h = int(math.ceil(ey * scale)) + 2
            if key == "eye":
                w = h = max(w, 64)
            if x + w > region_w:
                x, y = 2, y + shelf + 2
                shelf = 0
            if y + h > region_h:
                ok = False
                break
            placed[key] = (x, y, w, h, lo, hi, rot)
            x += w + 2
            shelf = max(shelf, h)
        if ok:
            return placed, scale
        scale *= 0.96
    raise RuntimeError("fins do not fit")


def fin_uv(body, rect, pts):
    """Map fin-frame points to atlas uv (v up) inside the fin's packed rect."""
    bx, by = block_origin(body.name)
    px, py = fin_pixel(body, rect, pts)
    return px / ATLAS, 1.0 - py / ATLAS


def fin_pixel(body, rect, pts):
    """Fin-frame points -> atlas pixel coords (x right, y down). Tall fins are stored rotated 90 degrees."""
    bx, by = block_origin(body.name)
    x, y, w, h, lo, hi, rot = rect
    pts = np.asarray(pts, float)
    fx = (pts[..., 0] - lo[0]) / (hi[0] - lo[0])
    fy = (hi[1] - pts[..., 1]) / (hi[1] - lo[1])
    if rot:  # fin x runs down the rect, fin y runs right
        fx, fy = 1.0 - fy, fx
    px = bx + x + 1 + fx * (w - 2)
    py = by + BODY_H + 2 + y + 1 + fy * (h - 2)
    return px, py
