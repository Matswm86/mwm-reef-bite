#!/usr/bin/env python3
"""Pacing sim for the MWM fish game (temporary slug mwm-reef-bite). Designer calc only.

Models one level on the open pond: a bot "child" steers the player fish with the
follow-the-finger control from GDD section 3, fish swim in from the sides, the
player eats lower tiers, bigger tiers catch it. No hazards, friends or power-ups
are simulated (they are approximations in the GDD level table).

Usage:
  python3 tools/pacing_sim.py table [-n 40]      # all 30 levels, both settings
  python3 tools/pacing_sim.py one lett 4 [-n 40]  # one level
  python3 tools/pacing_sim.py endless [-n 30]     # Uendelig rounds
  python3 tools/pacing_sim.py need                # need-per-tier sweep (section 4.4)

All numbers printed are (designer calc). Real children are slower: treat bot
times as a floor (likely 1.5-3x for a 4-year-old).
"""

from __future__ import annotations

import argparse
import math
import random
import statistics
from dataclasses import dataclass, field

# ---------------------------------------------------------------- constants (GDD section 7)
POND_X0, POND_X1 = 0.0, 1080.0
POND_Y0, POND_Y1 = 256.0, 1640.0
DT = 1.0 / 60.0
TIER_LEN = {t: 72.0 * 1.28 ** (t - 1) for t in range(1, 11)}  # px nose to tail
BODY_R = 0.30  # collision radius = 0.30 x length
FINGER_OFFSET_Y = 0.0  # sim: the bot's aim point is the fish target directly
TIME_CAP = 600.0


@dataclass
class Setting:
    name: str
    player_speed: float  # px/s max
    steer_tau: float  # s, velocity smoothing
    edible_share: float
    same_share: float
    big_spread: tuple[int, ...]  # tiers above player for bigger fish
    fish_speed_mult: float
    eat_reach: float  # extra px on the eat test (mouth magnet)
    catch_scale: float  # multiplies the bigger fish's catch radius
    chase: bool
    chase_radius: float
    chase_speed_frac: float  # fraction of player max speed
    flee: bool
    react_min: float
    react_max: float
    attend: float  # chance the bot checks danger at a decision
    wander: float  # chance a decision is a planless point
    aim_noise: float
    need_base: int
    need_per_tier: int
    respawn_float: float  # Lett: s spent floating as a bubble
    shield_s: float
    bubbles: int  # Vanlig catches allowed before gentle restart (0 = unlimited)
    accel: float = 1e9  # px/s^2 cap on the velocity change (owner phone test 2026-10-10)
    arrive_gain: float = 4.0  # 1/s, wanted speed = min(max, (distance - dead zone) x gain)
    arrive_dz: float = 0.0  # px, dead zone under the finger
    flee_mult: float = 1.3  # Vanlig flee speed = cruise speed x this


# Owner phone test 2026-10-10: softer controls (was 380 / 440 px/s, tau 0.18 / 0.14 s, gain 4,
# fish x0.75 / x1.0, chase 0.50, flee 1.3).
LETT = Setting("lett", 220, 0.45, 0.70, 0.10, (1, 1, 2), 0.55, 36, 0.70, False, 0, 0, False,
               0.6, 1.2, 0.5, 0.25, 70, 3, 2, 1.4, 2.0, 0,
               accel=450, arrive_gain=2.0, arrive_dz=28, flee_mult=1.1)
VANLIG = Setting("vanlig", 280, 0.40, 0.60, 0.10, (1, 1, 2), 0.8, 18, 0.75, True, 220, 0.40, True,
                 0.4, 0.8, 0.7, 0.10, 50, 3, 1, 1.4, 2.0, 3,
                 accel=560, arrive_gain=2.0, arrive_dz=28, flee_mult=1.1)


def need(s: Setting, tier: int) -> int:
    """Food points to grow from `tier` to tier + 1."""
    return s.need_base + s.need_per_tier * tier


@dataclass
class Fish:
    x: float
    y: float
    vx: float
    vy: float
    tier: int
    glitter: bool = False
    chase_t: float = 0.0
    flee_t: float = 0.0
    phase: float = field(default_factory=lambda: random.uniform(0, 6.28))


@dataclass
class Level:
    goal: str  # "grow" | "pearls" | "glitter"
    target: int  # tier, pearl count or glitter count
    fish_max: int
    world_speed: float  # multiplier on fish speed
    big_ok: bool = True
    unlimited: bool = False  # Vanlig bubbles unlimited (W1 + breathers)
    extra_edible: float = 0.0


def roll_tier(s: Setting, p_tier: int, lvl: Level, edible_on_screen: int) -> int:
    if edible_on_screen < 3 or not lvl.big_ok:
        r = 0.0
    else:
        r = random.random()
    edible_share = min(0.95, s.edible_share + lvl.extra_edible)
    if r < edible_share or p_tier == 1:
        lo = max(1, p_tier - 3)
        hi = max(1, p_tier - 1)
        # weight toward p_tier - 1 (more food value)
        tiers = list(range(lo, hi + 1))
        weights = [1 + i for i in range(len(tiers))]
        return random.choices(tiers, weights)[0]
    if r < edible_share + s.same_share:
        return p_tier
    return min(10, p_tier + random.choice(s.big_spread))


def spawn(s: Setting, p_tier: int, lvl: Level, fishes: list[Fish]) -> Fish:
    edible = sum(1 for f in fishes if f.tier < p_tier)
    t = roll_tier(s, p_tier, lvl, edible)
    side = random.choice((-1, 1))
    L = TIER_LEN[t]
    sp = (70 + 12 * t) * random.uniform(0.75, 1.25) * s.fish_speed_mult * lvl.world_speed
    x = POND_X0 - L if side < 0 else POND_X1 + L
    y = random.uniform(POND_Y0 + 60, POND_Y1 - 60)
    return Fish(x, y, -side * sp, 0.0, t)


def run_level(s: Setting, lvl: Level, seed: int | None = None) -> dict:
    rng_state = random.getstate()
    if seed is not None:
        random.seed(seed)
    px, py = 540.0, (POND_Y0 + POND_Y1) / 2
    vx = vy = 0.0
    tier, food = 2, 0
    fishes: list[Fish] = []
    pearls_got = glitter_got = 0
    pearl: tuple[float, float] | None = None
    pearl_timer = 1.0
    glitter_timer = 4.0
    t = 0.0
    decide_t = 0.0
    aim = (px, py)
    float_t = 0.0
    shield_t = 0.0
    catches = 0
    restarts = 0
    bubbles_left = s.bubbles
    spawn_t = 0.0
    while t < TIME_CAP:
        t += DT
        # goal check
        if lvl.goal == "grow" and tier >= lvl.target:
            break
        if lvl.goal == "pearls" and pearls_got >= lvl.target:
            break
        if lvl.goal == "glitter" and glitter_got >= lvl.target:
            break
        # spawn
        spawn_t -= DT
        if len(fishes) < lvl.fish_max and spawn_t <= 0:
            fishes.append(spawn(s, tier, lvl, fishes))
            spawn_t = 0.35
        if lvl.goal == "glitter":
            glitter_timer -= DT
            if glitter_timer <= 0 and not any(f.glitter for f in fishes):
                f = spawn(s, tier, lvl, fishes)
                f.tier = max(1, tier - 1)
                f.glitter = True
                fishes.append(f)
                glitter_timer = 3.0
        if lvl.goal == "pearls" and pearl is None:
            pearl_timer -= DT
            if pearl_timer <= 0:
                pearl = (random.uniform(140, 940), random.uniform(POND_Y0 + 120, POND_Y1 - 120))
        # bot decision
        decide_t -= DT
        if float_t <= 0 and decide_t <= 0:
            decide_t = random.uniform(s.react_min, s.react_max)
            aim = choose_aim(s, px, py, tier, fishes, pearl, lvl)
        # player motion
        if float_t > 0:
            float_t -= DT
            vx = vy = 0.0
        else:
            dx, dy = aim[0] - px, aim[1] - py
            d = math.hypot(dx, dy)
            # slows as it reaches the finger, stops inside the dead zone
            want = min(s.player_speed, max(0.0, d - s.arrive_dz) * s.arrive_gain)
            tvx, tvy = (dx / d * want, dy / d * want) if d > 1 else (0.0, 0.0)
            k = 1 - math.exp(-DT / s.steer_tau)
            dvx, dvy = (tvx - vx) * k, (tvy - vy) * k
            dv = math.hypot(dvx, dvy)
            if dv > s.accel * DT:
                dvx, dvy = dvx / dv * s.accel * DT, dvy / dv * s.accel * DT
            vx += dvx
            vy += dvy
            px = min(POND_X1 - 30, max(POND_X0 + 30, px + vx * DT))
            py = min(POND_Y1 - 30, max(POND_Y0 + 30, py + vy * DT))
        shield_t = max(0.0, shield_t - DT)
        pr = TIER_LEN[tier] * BODY_R
        # fish motion
        for f in fishes:
            f.phase += DT * 1.5
            fr = TIER_LEN[f.tier] * BODY_R
            dx, dy = px - f.x, py - f.y
            d = math.hypot(dx, dy) or 1
            base = abs(f.vx) if abs(f.vx) > 1 else 90
            if s.chase and f.tier > tier and d < s.chase_radius and float_t <= 0 and shield_t <= 0 \
                    and f.chase_t < 2.0:
                f.chase_t += DT
                cs = s.player_speed * s.chase_speed_frac
                f.x += dx / d * cs * DT
                f.y += dy / d * cs * DT
            elif s.flee and f.tier < tier and d < 200 and f.flee_t < 1.0:
                f.flee_t += DT
                f.x -= dx / d * base * s.flee_mult * DT
                f.y -= dy / d * base * s.flee_mult * DT
            else:
                f.x += f.vx * DT
                f.y += math.sin(f.phase) * 20 * DT
            f.y = min(POND_Y1 - fr, max(POND_Y0 + fr, f.y))
        # interactions
        if float_t <= 0:
            for f in list(fishes):
                fr = TIER_LEN[f.tier] * BODY_R
                d = math.hypot(px - f.x, py - f.y)
                if f.tier < tier and d < pr + fr * 0.5 + s.eat_reach:
                    fishes.remove(f)
                    food += f.tier
                    if f.glitter:
                        glitter_got += 1
                    while food >= need(s, tier):
                        food -= need(s, tier)
                        tier += 1
                        pr = TIER_LEN[tier] * BODY_R
                elif f.tier > tier and shield_t <= 0 and d < (fr * 0.8 + pr * 0.5) * s.catch_scale:
                    catches += 1
                    shield_t = s.shield_s
                    if s.bubbles == 0 or lvl.unlimited:
                        if s.respawn_float:
                            float_t = s.respawn_float
                        if s.bubbles:  # Vanlig unlimited level: lose tier progress
                            food = 0
                    else:
                        if bubbles_left > 0:
                            bubbles_left -= 1
                            food = 0
                            float_t = s.respawn_float
                        else:
                            restarts += 1
                            tier, food = 2, 0
                            pearls_got = glitter_got = 0
                            bubbles_left = s.bubbles
                            fishes.clear()
                            px, py = 540.0, (POND_Y0 + POND_Y1) / 2
                            float_t = 2.0
                    break
            if pearl is not None and math.hypot(px - pearl[0], py - pearl[1]) < pr + 40:
                pearls_got += 1
                pearl = None
                pearl_timer = 1.5
        fishes = [f for f in fishes if -200 < f.x < POND_X1 + 200]
    random.setstate(rng_state)
    return {"time": t, "catches": catches, "restarts": restarts, "cleared": t < TIME_CAP}


def choose_aim(s, px, py, tier, fishes, pearl, lvl):
    if random.random() < s.wander:
        return (random.uniform(100, 980), random.uniform(POND_Y0 + 80, POND_Y1 - 80))
    if random.random() < s.attend:
        danger = [f for f in fishes if f.tier > tier and math.hypot(f.x - px, f.y - py) < 300]
        if danger:
            f = min(danger, key=lambda f: math.hypot(f.x - px, f.y - py))
            dx, dy = px - f.x, py - f.y
            d = math.hypot(dx, dy) or 1
            return (px + dx / d * 250 + random.gauss(0, s.aim_noise),
                    py + dy / d * 250 + random.gauss(0, s.aim_noise))
    if pearl is not None:
        return (pearl[0] + random.gauss(0, s.aim_noise), pearl[1] + random.gauss(0, s.aim_noise))
    food = [f for f in fishes if f.tier < tier and POND_X0 < f.x < POND_X1]
    if lvl.goal == "glitter":
        g = [f for f in food if f.glitter]
        food = g or food
    if not food:
        return (540 + random.gauss(0, 150), (POND_Y0 + POND_Y1) / 2 + random.gauss(0, 200))
    f = min(food, key=lambda f: math.hypot(f.x - px, f.y - py))
    lead = math.hypot(f.x - px, f.y - py) / s.player_speed
    return (f.x + f.vx * lead + random.gauss(0, s.aim_noise), f.y + random.gauss(0, s.aim_noise))


# ---------------------------------------------------------------- level table (GDD 6.3)
# (goal, lett_target, vanlig_target, lett_fish, vanlig_fish, world_speed, breather)
LEVELS = [
    # W1 Tareskogen
    ("grow", 3, 4, 7, 8, 1.00, False),   # 1 no bigger fish
    ("grow", 4, 5, 7, 9, 1.00, False),   # 2 bigger fish appear
    ("grow", 4, 5, 7, 9, 1.00, False),   # 3 Boble
    ("pearls", 4, 6, 7, 9, 1.00, False),  # 4 Tare + pearls
    ("grow", 4, 5, 7, 8, 1.00, True),    # 5 breather
    # W2 Korallrevet
    ("grow", 5, 6, 8, 10, 1.05, False),
    ("pearls", 5, 8, 8, 10, 1.05, False),
    ("grow", 5, 6, 8, 10, 1.05, False),
    ("grow", 5, 7, 8, 10, 1.08, False),
    ("grow", 5, 6, 8, 9, 1.00, True),
    # W3 Manetbukta
    ("grow", 5, 6, 8, 11, 1.08, False),
    ("pearls", 6, 9, 8, 11, 1.08, False),
    ("grow", 6, 7, 9, 11, 1.10, False),
    ("grow", 6, 7, 9, 11, 1.12, False),
    ("grow", 5, 6, 8, 10, 1.05, True),
    # W4 Vrakdypet
    ("grow", 6, 7, 9, 11, 1.12, False),
    ("glitter", 3, 4, 9, 12, 1.12, False),
    ("pearls", 7, 10, 9, 12, 1.14, False),
    ("grow", 6, 8, 9, 11, 1.16, False),
    ("grow", 6, 7, 9, 11, 1.08, True),
    # W5 Strømfjorden
    ("grow", 6, 8, 10, 12, 1.16, False),
    ("glitter", 4, 5, 10, 12, 1.16, False),
    ("grow", 7, 8, 10, 13, 1.18, False),
    ("grow", 7, 8, 10, 13, 1.20, False),
    ("grow", 6, 7, 9, 12, 1.12, True),
    # W6 Dyphavet
    ("grow", 7, 8, 10, 13, 1.20, False),
    ("pearls", 8, 10, 10, 13, 1.20, False),
    ("glitter", 5, 6, 10, 14, 1.22, False),
    ("grow", 7, 9, 10, 13, 1.25, False),
    ("grow", 8, 9, 10, 13, 1.15, True),  # finale: grow to the top
]


def level_obj(i: int, s: Setting) -> Level:
    goal, lt, vt, lf, vf, ws, breather = LEVELS[i]
    lett = s.name == "lett"
    return Level(goal, lt if lett else vt, lf if lett else vf, ws,
                 big_ok=(i != 0), unlimited=(i < 5 or breather),
                 extra_edible=0.10 if breather else 0.0)


def summarize(results):
    times = [r["time"] for r in results]
    return (statistics.median(times), sum(r["cleared"] for r in results), len(results),
            statistics.mean(r["catches"] for r in results),
            sum(1 for r in results if r["restarts"] > 0) / len(results))


def cmd_table(n):
    print("| # | goal | Lett target / fish / median s / catches | Vanlig target / fish / median s / restart% |")
    print("|---|---|---|---|")
    for i in range(30):
        row = []
        for s in (LETT, VANLIG):
            lvl = level_obj(i, s)
            med, ok, tot, catches, rs = summarize([run_level(s, lvl, seed=1000 * i + k) for k in range(n)])
            if s is LETT:
                row.append(f"{lvl.target} / {lvl.fish_max} / {med:.0f} / {catches:.1f}")
            else:
                row.append(f"{lvl.target} / {lvl.fish_max} / {med:.0f} / {rs * 100:.0f}% ({ok}/{tot})")
        print(f"| {i + 1} | {LEVELS[i][0]} | {row[0]} | {row[1]} |")


def cmd_one(setting, idx, n):
    s = LETT if setting == "lett" else VANLIG
    lvl = level_obj(idx - 1, s)
    med, ok, tot, catches, rs = summarize([run_level(s, lvl, seed=k) for k in range(n)])
    print(f"{setting} L{idx}: median {med:.1f} s, cleared {ok}/{tot}, catches {catches:.1f}, restart {rs:.0%}")


def endless_round(k: int, lett: bool) -> Level:
    """Uendelig round k (GDD 6.5): goal tier climbs one per round, then fish and speed ramp."""
    goal = min(3 + k, 8) if lett else min(4 + k, 9)
    fish = min((7 if lett else 9) + k // 2, 10 if lett else 13)
    ws = 1.0 + 0.03 * min(k - 1, 8)
    return Level("grow", goal, fish, ws, unlimited=False)


def cmd_endless(n):
    print("| Round | Lett goal tier / fish / speed: median s | Vanlig goal tier / fish / speed: median s / restart% |")
    print("|---|---|---|")
    total = {True: 0.0, False: 0.0}
    for k in range(1, 13):
        row = []
        for s in (LETT, VANLIG):
            lett = s is LETT
            lvl = endless_round(k, lett)
            med, ok, tot, catches, rs = summarize([run_level(s, lvl, seed=500 * k + j) for j in range(n)])
            total[lett] += med
            row.append(f"{lvl.target} / {lvl.fish_max} / x{lvl.world_speed:.2f}: {med:.0f}"
                       + ("" if lett else f" / {rs * 100:.0f}%") + ("" if ok == tot else f" ({ok}/{tot})"))
        print(f"| {k} | {row[0]} | {row[1]} |")
    print(f"sum of medians to round 12: Lett {total[True] / 60:.1f} min, Vanlig {total[False] / 60:.1f} min")


def cmd_need(n):
    """Compare growth-cost formulas on a grow-to-6 level."""
    import copy
    for base, per in ((1, 1), (2, 1), (1, 2), (3, 2)):
        for s0 in (LETT, VANLIG):
            s = copy.copy(s0)
            s.need_base, s.need_per_tier = base, per
            lvl = Level("grow", 6, 9, 1.1, unlimited=True)
            med, ok, tot, catches, rs = summarize([run_level(s, lvl, seed=j) for j in range(n)])
            print(f"need = {base} + {per} x tier  {s.name:6s}: median {med:5.1f} s  catches {catches:.1f}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["table", "one", "endless", "need"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("-n", type=int, default=40)
    a = ap.parse_args()
    if a.cmd == "table":
        cmd_table(a.n)
    elif a.cmd == "one":
        cmd_one(a.args[0], int(a.args[1]), a.n)
    elif a.cmd == "endless":
        cmd_endless(a.n)
    else:
        cmd_need(a.n)
