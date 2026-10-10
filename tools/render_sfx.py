"""Render the MWM Reef Bite sound effects to assets/sfx/*.ogg.

Soft underwater set (GDD 9): bubbles, plops, muffled chimes, no 8-bit, no
growls, no scary bites, no fail stings. 100% own synthesis (sines, FM and
modal bells, filtered noise, a synthetic convolution room); no samples.
Pitched sounds use D major pentatonic, the key of the music loop.
Output: 44.1 kHz mono Ogg Vorbis, peaks at -3 dBFS (the game sets levels).
Deterministic: every random layer has a fixed seed. Helpers adapted from
the sister game MWM Neon Bricks (tools/render_sfx.py).

Usage: python3 tools/render_sfx.py [--out assets/sfx]
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
# D major pentatonic (D E F# A B) from D4.
D4 = 293.66
PENTA = [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0, 2.245, 2.5198, 2.9966, 3.3636, 4.0]


def note(i: int, base: float = D4) -> float:
    return base * PENTA[i]


# ------------------------------------------------------------------ helpers


def tt(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def env(dur: float, attack: float, tau: float) -> np.ndarray:
    t = tt(dur)
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    a = 0.5 - 0.5 * np.cos(np.pi * a)
    tail = np.clip((dur - t) / (0.25 * dur), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / tau) * (0.5 - 0.5 * np.cos(np.pi * tail))


def at(x: np.ndarray, start: float, total: float) -> np.ndarray:
    out = np.zeros(int(total * SR))
    i = int(start * SR)
    seg = x[: max(0, len(out) - i)]
    out[i : i + len(seg)] += seg
    return out


def mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, g in parts:
        out[: len(p)] += p * g
    return out


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="lowpass", fs=SR, output="sos"), x)


def hp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="highpass", fs=SR, output="sos"), x)


def noise(dur: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(dur * SR))


def glide(dur: float, f0: float, f1: float, curve: float = 1.0) -> np.ndarray:
    """Sine whose frequency moves from f0 to f1 (exponential, shaped)."""
    t = tt(dur)
    k = (t / max(dur, 1e-6)) ** curve
    f = f0 * (f1 / f0) ** k
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def swept_bp(x: np.ndarray, f0: float, f1: float, q: float = 2.0) -> np.ndarray:
    n = len(x)
    fc = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    out = np.zeros(n)
    low = band = 0.0
    damp = 1.0 / q
    for i in range(n):
        f = 2.0 * np.sin(np.pi * fc[i] / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        out[i] = band
    return out


def modal(f: float, dur: float, ratios, amps, taus, attack: float = 0.001) -> np.ndarray:
    t = tt(dur)
    out = np.zeros(len(t))
    for r, a, tau in zip(ratios, amps, taus, strict=True):
        if f * r < SR * 0.45:
            out += a * np.sin(2.0 * np.pi * f * r * t) * env(dur, attack, tau)
    return out


def marimba(f: float, dur: float = 1.2) -> np.ndarray:
    return modal(f, dur, [1.0, 3.93, 9.24], [1.0, 0.35, 0.08], [0.45, 0.12, 0.04], 0.002)


def fm_bell(
    f: float, dur: float, ratio: float, index: float, idx_tau: float, tau: float
) -> np.ndarray:
    t = tt(dur)
    mod = index * np.exp(-t / idx_tau) * np.sin(2.0 * np.pi * f * ratio * t)
    return np.sin(2.0 * np.pi * f * t + mod) * env(dur, 0.002, tau)


def bubble(f0: float, dur: float = 0.07, rise: float = 1.8) -> np.ndarray:
    """One underwater bubble: a sine that chirps upward as it resonates."""
    return glide(dur, f0, f0 * rise, 0.6) * env(dur, 0.002, dur * 0.35)


def bubbles(
    n: int, total: float, lo: float, hi: float, seed: int, gain_lo: float = 0.3
) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros(int(total * SR))
    for _ in range(n):
        f = rng.uniform(lo, hi)
        b = bubble(f, rng.uniform(0.04, 0.09)) * rng.uniform(gain_lo, 1.0)
        out += at(b, rng.uniform(0.0, max(total - 0.1, 0.01)), total)
    return out


def reverb(x: np.ndarray, rt: float, wet: float, damp: float = 4000.0, seed: int = 7) -> np.ndarray:
    """Synthetic room: dense decaying noise, darker over time (soft water room)."""
    n = int(rt * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    ir = lp(rng.uniform(-1, 1, n), damp) * np.exp(-6.9 * t / rt)
    ir = np.concatenate([np.zeros(int(0.015 * SR)), ir])
    ir /= np.sqrt(np.sum(ir**2)) + 1e-9
    w = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
    dry = np.pad(x, (0, len(w) - len(x)))
    return dry * (1.0 - wet * 0.5) + w * wet


def finish(x: np.ndarray, peak_db: float = -3.0, fade_ms: float = 25.0) -> np.ndarray:
    x = hp(x, 40.0)
    a = np.abs(x)
    idx = np.nonzero(a > np.max(a) * 10 ** (-60.0 / 20.0))[0]
    if len(idx):
        x = x[: idx[-1] + 1]
    nf = min(len(x), int(fade_ms / 1000.0 * SR))
    if nf > 0:
        x[-nf:] *= np.linspace(1.0, 0.0, nf) ** 2
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20.0)


# ------------------------------------------------------------------ sounds


def tap(v: int) -> np.ndarray:
    f = [820.0, 900.0, 760.0][v]
    d = 0.12
    body = glide(d, f, f * 0.62, 0.5) * env(d, 0.002, 0.03)
    drip = bubble(f * 1.6, 0.05, 1.5) * 0.35
    return finish(reverb(mix((body, 1.0), (drip, 1.0)), 0.25, 0.25))


def touch() -> np.ndarray:
    return finish(reverb(bubble(700.0, 0.06, 2.0), 0.2, 0.2))


def eat(v: int) -> np.ndarray:
    d = 0.22
    pop = glide(0.09, [190.0, 210.0, 175.0][v], 85.0, 0.5) * env(0.09, 0.002, 0.03)
    gulp = swept_bp(noise(0.16, 30 + v), 420.0, 1300.0, 3.0) * env(0.16, 0.01, 0.05)
    tone = fm_bell(note(4, 2 * D4 * 0.5), d, 2.0, 0.6, 0.04, 0.07) * 0.35
    bub = bubbles(3, d, 600.0, 1100.0, 40 + v)
    x = mix((pop, 1.0), (at(gulp, 0.02, d), 0.5), (tone, 1.0), (bub, 0.35))
    return finish(reverb(lp(x, 6000.0), 0.35, 0.25))


def grow() -> np.ndarray:
    d = 1.1
    x = np.zeros(int(d * SR))
    for k, (i, s) in enumerate([(5, 0.0), (7, 0.11), (9, 0.22)]):
        b = fm_bell(note(i), 0.9, 2.0, 1.2, 0.05, 0.35) * 0.7 + marimba(note(i), 0.9) * 0.5
        x += at(b * (0.8 + 0.1 * k), s, d)
    whoosh = swept_bp(noise(0.8, 51), 250.0, 2200.0, 1.6) * env(0.8, 0.35, 0.25)
    x = mix((x, 1.0), (at(whoosh, 0.0, d), 0.25), (bubbles(14, d, 700.0, 1800.0, 52), 0.25))
    return finish(reverb(x, 1.0, 0.35))


def tink() -> np.ndarray:
    x = modal(note(9) * 2.0, 0.25, [1.0, 2.76, 5.4], [1.0, 0.3, 0.1], [0.08, 0.04, 0.02])
    return finish(reverb(x, 0.5, 0.3))


def boink() -> np.ndarray:
    d = 0.18
    t = tt(d)
    f = 230.0 * (1.0 + 0.45 * np.exp(-t / 0.03) * np.sin(2 * np.pi * 22 * t)) * np.exp(-t * 2.0)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(d, 0.003, 0.05)
    return finish(reverb(lp(x, 2500.0), 0.3, 0.25))


def swish() -> np.ndarray:
    d = 0.45
    x = swept_bp(noise(d, 61), 260.0, 900.0, 1.4) * env(d, 0.12, 0.12)
    return finish(reverb(lp(x, 1800.0), 0.5, 0.3))


def gulp() -> np.ndarray:
    d = 0.28
    low = glide(d, 130.0, 55.0, 0.7) * env(d, 0.01, 0.07)
    mush = lp(noise(d, 71), 500.0) * env(d, 0.01, 0.05)
    return finish(reverb(mix((low, 1.0), (mush, 0.5)), 0.4, 0.3))


def burp() -> np.ndarray:
    d = 0.45
    t = tt(d)
    f = 150.0 * (1.0 - 0.25 * t / d)
    am = 0.6 + 0.4 * np.sin(2 * np.pi * 24.0 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * am * env(d, 0.02, 0.14)
    x = lp(x + 0.4 * np.sin(2 * np.pi * 2 * np.cumsum(f) / SR) * am * env(d, 0.02, 0.1), 900.0)
    x = mix((x, 1.0), (bubbles(6, d, 500.0, 1000.0, 81), 0.3))
    return finish(reverb(x, 0.4, 0.25))


def bubble_pop() -> np.ndarray:
    d = 0.16
    x = glide(0.05, 900.0, 2200.0, 0.4) * env(0.05, 0.001, 0.012)
    x = mix((x, 1.0), (bubbles(5, d, 900.0, 2000.0, 91), 0.5))
    return finish(reverb(x, 0.3, 0.25))


def bobler() -> np.ndarray:
    d = 0.45
    pop = glide(0.05, 1000.0, 2000.0, 0.4) * env(0.05, 0.001, 0.012)
    n1 = marimba(note(8), 0.3) * 0.6
    n2 = marimba(note(6), 0.35) * 0.6
    x = mix((pop, 0.6), (at(n1, 0.05, d), 1.0), (at(n2, 0.2, d), 1.0))
    return finish(reverb(x, 0.5, 0.3))


def rewind() -> np.ndarray:
    d = 1.25
    sweep = swept_bp(noise(d, 101), 2400.0, 220.0, 1.5) * env(d, 0.4, 0.5)
    b = bubbles(20, d, 600.0, 1600.0, 102)[::-1]
    x = mix((sweep, 0.8), (b, 0.3))
    return finish(reverb(lp(x, 5000.0), 0.8, 0.35))


def shell() -> np.ndarray:
    d = 0.55
    t = tt(d)
    jitter = 1.0 + 0.08 * np.random.default_rng(111).standard_normal(len(t)).cumsum() / np.sqrt(
        len(t)
    )
    creak = bp(np.sign(np.sin(2 * np.pi * np.cumsum(70.0 * jitter) / SR)), 200.0, 900.0) * env(
        d, 0.05, 0.12
    )
    shim = np.zeros(len(t))
    for k, i in enumerate([7, 9, 8, 10]):
        shim += at(fm_bell(note(i), 0.4, 3.5, 0.5, 0.05, 0.12), 0.12 + 0.06 * k, d) * 0.25
    return finish(reverb(mix((creak, 0.25), (shim, 1.0)), 0.6, 0.35))


def pearl() -> np.ndarray:
    d = 0.8
    x = fm_bell(note(7), d, 3.0, 1.0, 0.03, 0.3) + modal(
        note(7), d, [1.0, 2.0, 3.0], [0.6, 0.2, 0.08], [0.4, 0.2, 0.1]
    )
    return finish(reverb(x, 0.8, 0.3))


def bobla_on() -> np.ndarray:
    d = 0.7
    t = tt(d)
    f = 280.0 * (2.4 ** (t / d)) * (1.0 + 0.05 * np.sin(2 * np.pi * 9.0 * t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(d, 0.05, 0.3)
    x = mix((lp(x, 3000.0), 0.8), (bubbles(10, d, 600.0, 1400.0, 121), 0.35))
    return finish(reverb(x, 0.6, 0.3))


def bonk() -> np.ndarray:
    d = 0.32
    b = glide(0.2, 260.0, 180.0, 0.5) * env(0.2, 0.002, 0.05)
    p = glide(0.05, 1000.0, 2200.0, 0.4) * env(0.05, 0.001, 0.012)
    x = mix((b, 1.0), (at(p, 0.1, d), 0.6), (bubbles(6, d, 800.0, 1800.0, 131), 0.3))
    return finish(reverb(lp(x, 4000.0), 0.4, 0.3))


def kelp() -> np.ndarray:
    d = 0.32
    t = tt(d)
    x = hp(noise(d, 141), 1800.0) * env(d, 0.06, 0.08) * (0.7 + 0.3 * np.sin(2 * np.pi * 18 * t))
    return finish(reverb(lp(x, 7000.0), 0.4, 0.3))


def win() -> np.ndarray:
    d = 3.2
    x = np.zeros(int(d * SR))
    seq = [(0, 0.0), (2, 0.16), (3, 0.32), (5, 0.48), (7, 0.70), (8, 0.86), (10, 1.1)]
    for i, s in seq:
        x += at(
            marimba(note(i), 1.4) * 0.7 + fm_bell(note(i), 1.4, 2.0, 0.6, 0.05, 0.4) * 0.25, s, d
        )
    t = tt(d)
    swell_f = 110.0 * (1.5 ** np.clip((t - 0.5) / 1.6, 0, 1))
    swell = lp(
        np.sin(2 * np.pi * np.cumsum(swell_f) / SR)
        + 0.3 * np.sin(4 * np.pi * np.cumsum(swell_f) / SR),
        600.0,
    )
    swell *= np.clip((t - 0.3) / 0.8, 0, 1) * np.clip((d - t) / 1.2, 0, 1)
    x = mix((x, 1.0), (swell, 0.25), (bubbles(30, d, 600.0, 2000.0, 151, 0.2), 0.25))
    return finish(reverb(x, 1.6, 0.35), fade_ms=300.0)


def star() -> np.ndarray:
    d = 0.7
    x = mix((fm_bell(note(10), d, 2.0, 1.4, 0.03, 0.22), 1.0), (bubble(1400.0, 0.08, 1.7), 0.4))
    return finish(reverb(x, 0.8, 0.35))


def intro() -> np.ndarray:
    d = 1.6
    x = np.zeros(int(d * SR))
    for k in range(12):
        f = 2200.0 * (0.85**k)
        x += at(bubble(f, 0.07, 1.6) * (0.5 + 0.04 * k), 0.06 * k, d)
    t = tt(d)
    swell = lp(noise(d, 161), 400.0) * np.clip((t - 0.5) / 0.6, 0, 1) * np.clip((d - t) / 0.6, 0, 1)
    pad = (
        (np.sin(2 * np.pi * D4 * 0.5 * t) + 0.5 * np.sin(2 * np.pi * D4 * 0.75 * t))
        * np.clip((t - 0.6) / 0.5, 0, 1)
        * np.clip((d - t) / 0.6, 0, 1)
    )
    x = mix((x, 0.7), (swell, 0.5), (lp(pad, 900.0), 0.25))
    return finish(reverb(x, 1.0, 0.35), fade_ms=200.0)


def hint() -> np.ndarray:
    d = 1.0
    x = np.zeros(int(d * SR))
    for k, i in enumerate([7, 9, 10, 9]):
        x += at(fm_bell(note(i), 0.5, 3.5, 0.4, 0.05, 0.18), 0.12 * k, d) * 0.4
    return finish(reverb(x, 0.8, 0.4), fade_ms=150.0)


def ambience() -> np.ndarray:
    """Gentle underwater bed, 12 s, seamless loop (crossfaded ends)."""
    d = 12.0
    xf = 1.0
    n = int((d + xf) * SR)
    brown = np.cumsum(np.random.default_rng(171).standard_normal(n))
    brown = hp(brown, 25.0)
    bed = lp(brown, 320.0)
    bed /= np.max(np.abs(bed)) + 1e-9
    t = np.arange(n) / SR
    bed *= 0.75 + 0.25 * np.sin(2 * np.pi * t / (d + xf) * 2.0)
    b = bubbles(26, d + xf, 500.0, 1500.0, 172, 0.15) * 0.18
    x = bed + b
    m = int(xf * SR)
    head = x[:m]
    tail = x[-m:]
    w = np.linspace(0.0, 1.0, m)
    looped = x[: n - m].copy()
    looped[:m] = head * w + tail * (1.0 - w)
    return looped / (np.max(np.abs(looped)) + 1e-9) * 10 ** (-3.0 / 20.0)


def build() -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for v in range(3):
        out[f"tap_{v + 1}"] = tap(v)
        out[f"eat_{v + 1}"] = eat(v)
    out["touch"] = touch()
    out["grow"] = grow()
    out["tink"] = tink()
    out["boink"] = boink()
    out["swish"] = swish()
    out["gulp"] = gulp()
    out["burp"] = burp()
    out["bubble_pop"] = bubble_pop()
    out["bobler"] = bobler()
    out["rewind"] = rewind()
    out["shell"] = shell()
    out["pearl"] = pearl()
    out["bobla_on"] = bobla_on()
    out["bonk"] = bonk()
    out["kelp"] = kelp()
    out["win"] = win()
    out["star"] = star()
    out["intro"] = intro()
    out["hint"] = hint()
    out["ambience"] = ambience()
    return out


def write_ogg(x: np.ndarray, path: Path, quality: str = "4") -> None:
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "x.wav"
        sf.write(str(wav), x.astype(np.float32), SR, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", "1", "-ar", str(SR)]
            + ["-c:a", "libvorbis", "-q:a", quality, str(path)],
            check=True,
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--out", type=Path, default=Path(__file__).resolve().parent.parent / "assets" / "sfx"
    )
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, x in build().items():
        write_ogg(x, args.out / f"rb_{name}.ogg")
        peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        print(f"rb_{name}.ogg  {len(x) / SR:.2f} s  peak {peak:.1f} dBFS")


if __name__ == "__main__":
    main()
