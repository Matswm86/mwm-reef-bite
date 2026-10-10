"""Render the MWM Reef Bite calm placeholder music loop.

Own composition and own synthesis (GDD 9): a soft marimba melody in D major
pentatonic over a slow D - Bm - G - A pad with a round sub bass and a few
bubbles, 72 BPM, 16 bars (53.3 s), seamless loop (the reverb tail is folded
back onto the start). The melody is new and written for this game; nothing
from any other game's music. Output: assets/music/rb_reef_loop.ogg, mono,
peak -3 dBFS (the game plays it at least 6 dB under the effects).

Usage: python3 tools/render_music.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from render_sfx import (
    SR,
    bubbles,
    env,
    fm_bell,
    lp,
    marimba,
    reverb,
    tt,
    write_ogg,
)

BPM = 72.0
EIGHTH = 60.0 / BPM / 2.0
BAR = EIGHTH * 8
BARS = 16
D4 = 293.66
# D major pentatonic from D4: D E F# A B D5 E5 F#5 A5 B5.
SCALE = [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0, 2.245, 2.5198, 2.9966, 3.3636]

# Eighth-note grid per bar, -1 = rest (own melody).
PHRASE_A = [
    [5, -1, 3, -1, 2, 3, 5, -1],
    [4, -1, 2, -1, 4, -1, -1, -1],
    [5, -1, 4, -1, 3, 4, 5, -1],
    [6, -1, 3, -1, -1, -1, -1, -1],
]
PHRASE_B = [
    [7, -1, 6, -1, 5, -1, 3, -1],
    [4, -1, 5, 6, -1, -1, 4, -1],
    [5, -1, 4, -1, 3, -1, 2, -1],
    [3, -1, -1, -1, 1, -1, -1, -1],
]
PHRASE_A2 = PHRASE_A[:3] + [[6, -1, 5, -1, 3, -1, -1, -1]]
PHRASE_C = [
    [8, -1, 7, -1, 5, -1, -1, -1],
    [7, -1, 5, -1, 4, -1, -1, -1],
    [5, 4, 3, -1, 4, -1, 5, -1],
    [3, -1, -1, -1, -1, -1, -1, -1],
]
MELODY = PHRASE_A + PHRASE_B + PHRASE_A2 + PHRASE_C
# Chord per bar (frequencies of the pad), roots for the bass.
CHORDS = {
    "D": ([146.83, 185.0, 220.0, 293.66], 73.42),
    "Bm": ([123.47, 146.83, 185.0, 246.94], 61.74),
    "G": ([98.0, 123.47, 146.83, 196.0], 49.0),
    "A": ([110.0, 138.59, 164.81, 220.0], 55.0),
}
PROGRESSION = ["D", "Bm", "G", "A"] * 4


def soft_saw(f: float, dur: float, harmonics: int = 10) -> np.ndarray:
    t = tt(dur)
    out = np.zeros(len(t))
    for k in range(1, harmonics + 1):
        if f * k > 5000.0:
            break
        out += np.sin(2.0 * np.pi * f * k * t) / k
    return out


def render() -> np.ndarray:
    loop = BAR * BARS
    tail = 4.0
    total = loop + tail
    n = int(total * SR)
    mel = np.zeros(n)
    pad = np.zeros(n)
    bass = np.zeros(n)
    for b in range(BARS):
        start = b * BAR
        for k, deg in enumerate(MELODY[b]):
            if deg < 0:
                continue
            f = D4 * SCALE[deg]
            s = int((start + k * EIGHTH) * SR)
            x = marimba(f, 1.6) * 0.8 + fm_bell(f, 1.6, 2.0, 0.35, 0.05, 0.5) * 0.18
            mel[s : s + len(x)] += x[: n - s]
        chord, root = CHORDS[PROGRESSION[b]]
        d = BAR + 0.6
        p = np.zeros(int(d * SR))
        for f in chord:
            for cents in (-6.0, 6.0):
                p += soft_saw(f * 2 ** (cents / 1200.0), d)
        p = lp(p, 900.0) * env(d, 0.9, 2.2)
        s = int(start * SR)
        pad[s : s + len(p)] += p[: n - s]
        for beat in (0, 4):
            bd = EIGHTH * 3.5
            t = tt(bd)
            x = (np.sin(2 * np.pi * root * t) + 0.25 * np.sin(4 * np.pi * root * t)) * env(
                bd, 0.02, 0.6
            )
            s2 = int((start + beat * EIGHTH) * SR)
            bass[s2 : s2 + len(x)] += x[: n - s2]
    pad /= np.max(np.abs(pad)) + 1e-9
    mel /= np.max(np.abs(mel)) + 1e-9
    bass /= np.max(np.abs(bass)) + 1e-9
    bub = bubbles(40, total, 500.0, 1300.0, 909, 0.15)
    x = mel * 0.55 + pad * 0.22 + lp(bass, 400.0) * 0.38 + bub * 0.05
    x = reverb(lp(x, 7000.0), 2.4, 0.4, damp=3500.0, seed=919)
    m = int(loop * SR)
    out = x[:m].copy()
    rest = x[m:]
    out[: len(rest)] += rest
    return out / (np.max(np.abs(out)) + 1e-9) * 10 ** (-3.0 / 20.0)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    out = root / "assets" / "music"
    out.mkdir(parents=True, exist_ok=True)
    x = render()
    write_ogg(x, out / "rb_reef_loop.ogg", quality="3")
    print(f"rb_reef_loop.ogg  {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main()
