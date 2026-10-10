# MWM fish game (working slug `mwm-reef-bite`): game design doc

Version 1, 2026-10-10, game-designer. Store-safe eat-and-grow fish game for the MWM Play family app (ages 4-7 and 8+, one-time unlock, no ads, offline). It replaces the sideload remake `projects/fishy/` in the store catalogue. **Name: MWM Reef Bite** (owner pick 2026-10-10). Slug `mwm-reef-bite`, save `user://reef_bite_save.json`, class prefix `Rb`. Owner 2026-10-10: same-size fish bump.

Target: Android, portrait 1080x1920, Godot 4.6 `mobile` renderer. Stand-alone app first, then a game inside MWM Play. Look: **underwater realistic** (owner 2026-10-05). Visuals, colours, species art and renderer tier belong to graphic-designer (`docs/DESIGN.md`, written in parallel); this doc only lists game-feel hooks and shape cues.

Legend: **(owner)** = decided by the owner, do not reopen. **(rule N)** = numbered rule in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. **(designer calc)** = my own simulation or arithmetic (`tools/pacing_sim.py`), not a source. **(my call)** = a design choice I made; change it freely. **(guess)** = a target the builder and QA verify on a phone. **(sourced)** = read from our `projects/fishy/` port of the 2003 original.

### What we take from the original, and what we do not

Game rules are free to use; art, sound, music, the name and code are not.

- **Taken (rules only, sourced from `projects/fishy/README.md` and the logic in `scripts/main.gd`):** you are a fish in a pond; fish swim in from the sides; you eat fish smaller than you and grow; fish bigger than you eat you; you grow by a fraction of what you eat; the game is won by reaching a size goal.
- **Not taken:** the name "Fishy" or anything containing it; every sprite, plant, bone, button, title letter, sound, the `_koi.wav` music and the XGen intro; the 550 x 400 stage layout; the score formula and high-score table; the one-life game over.
- **No code from `projects/fishy/scripts/main.gd`.** That file is a line-by-line port of XGen Studios' ActionScript, so its structure (frame counters, the 10-slot fish arrays, the arrow-key emulation, the |dx| / |dy|-over-3 hit box) is XGen's expression, not just rules. **The new game is written from scratch from this GDD.** The builder must not open, copy or adapt `main.gd`, `stage_data.gd` or `atlas_data.gd`, and must not copy any file from `projects/fishy/assets/`. game-qa checks this (section 14).

| Original rule (sourced) | This game (my call unless marked) | Why |
|---|---|---|
| Size is a continuous number (start 15, fish 2-73) | **Size tiers 1-10**, each 28% longer than the last | A 4-year-old cannot judge "15.3 vs 16.1". Tiers make "smaller / same / bigger" visible (section 4.2) |
| Equal size: you are eaten (player must be strictly larger) | **Same tier: neither eats, they bump** | No "it looked the same and it ate me" moment |
| Grow by eaten size / 50 | Food points = eaten fish's tier; a full meter grows you one tier | Same idea (bigger meal = more growth), readable as a meter |
| Win at size 300 | Each level has a goal (grow to tier X, collect pearls, eat glitter fish) | 30 short levels instead of one long run |
| Eaten = game over | Lett: burped out in a bubble, no cost. Vanlig: meter empties, 3 bubbles, then a gentle restart | Rule 31 |
| Player wraps around the left/right edge | Pond edges are soft walls | Wrapping confuses small children (my call) |
| Arrow keys / drag-as-arrow-keys | Follow-the-finger (section 3) | One thumb, pointing |
| Score, 6 points per size unit, top 10 | No score; one star per cleared level | Rule 30, sister games |

---

## 0. Name

The owner asked for a new name with the "MWM " prefix, not containing "Fishy" (owner 2026-10-10 brief). Checked 2026-10-10 in EUIPO TMview (API, criteria "C" plus the fuzzy "F" top 100; classes 9 software, 28 games/toys, 41 entertainment flagged) and a Google Play search (quoted and unquoted, `hl=en`, `gl=NO`). TMview is a screening tool, not legal clearance.

| Rank | Name | TMview: exact or near hits | Google Play | Verdict |
|---|---|---|---|---|
| 1 | **MWM Reef Bite** | Exact: REEF BITE, US, **Ended**, class 25 (clothing), US500000098376394. Near, classes 9/28/41: single-word "BITE!" (Karsten Manufacturing, golf, class 28, Registered: EM500000018526605, US500000090523115), "REEF." (South Cone Inc, the sandal brand, Colombia class 9: CO500000013194831), "Beef Reef" (CA, classes 25/28/41, CA500000237405400) | No app named "Reef Bite" (quoted search empty; unquoted 29 results, none contain it) | Clear (low risk). Says what you do. "Reef" is a known word for Norwegian parents (rev) |
| 2 | **MWM Tide Bite** | No exact hit. Near: "BIDE BITES" US Ended class 9 (US500000090027405), "BITE!" (as above), ".TIDE" FR Expired (FR500000003552403) | No app with the name | Clear (low risk). Weaker meaning for kids ("tide" = tidevann) |
| 3 | **MWM Glupsk** (Norwegian: greedy-hungry) | Exact: Glupsk, SE, **Registered**, classes 29/32 (seafood, Västsvenska Skaldjur AB), SE500000202100564. Near: "GLUP OG GLUPSK" NO, Ended, classes 25/28, NO502013000005794 | No app with the name | Usable (low-moderate: same word, other classes, but seafood). Every Norwegian child gets it; foreigners do not |
| 4 | **MWM Reef Grow** | Exact: REEF GROW, US, Ended, class 11 (US500000090117198). Nothing in 9/28/41 | No exact, but two same-genre apps "Hungry Reef: Fish Eat & Grow" and "Reef Ladder: Fish Eat & Grow" | Weak: descriptive, easy to confuse with those genre titles |
| 5 | **MWM Deep Gulp** | No exact hit. Near: "GULP!" by Pure Fishing Inc (fishing bait), class 28, **Registered** in US, WO, CA, NZ, AR (US500000076529890, WO500000000849491, CA500000126850900) | No app with the name | Caution: a fishing-bait mark in class 28 with the same word, fish context |

**Rejected after the check:** "Reef Rush" (NetEase marks in classes 9/28/41: CA500000175521500 **Registered**; EM500000014801831 and NO502015000014367 Expired; Play already has "Reef Rush: Eat & Grow", a same-genre game). "Fin Feast" (TMview clean, but Play has "Fin Feast" `com.brmxplqztk.jhskdwyn`, an eat-smaller-fish game). "Little Fin" (LITTLE FIN, US, **Registered**, class 28, US500000088526172). "Deep Bite" (deep bite, DE, **Registered**, classes 25/28/35, DE503020170154445). "Big Fin" (BIG FIN BAY slot game, Thunderkick, classes 9/28/41 Registered, EM500000018796023).

Not checked: the "MWM" prefix itself, domain names, Apple App Store.

When the owner picks: slug `mwm-<name>`, save `user://<name>_save.json`, class prefix two letters (e.g. `Rb` for Reef Bite). **Picked 2026-10-10: MWM Reef Bite, slug `mwm-reef-bite`, save `user://reef_bite_save.json`, prefix `Rb`.**

## 1. Pitch

Steer a little fish with one finger through realistic underwater worlds, eat the fish that are smaller than you, keep away from the bigger ones, and grow until you are the biggest fish in the sea; a big fish that catches you just burps you out in a bubble, so a small child never loses.

## 2. Core loop

**Steer** (hold a finger, the fish swims to it) -> **eat** (touch a smaller fish with your mouth) -> **grow** (the meter fills, the fish pops one size bigger, new food becomes edible) -> **dodge** (bigger fish, world hazards) -> **reach the goal** (win card) -> next level or stop.

Each level starts the player small (tier 2), so every level replays the "small to big" arc in 15 s to 2 min. No score, no timer, no currency, no lives counter in Lett. One star per cleared level, always earned by clearing (rule 30). The win card is the natural stopping point for the play limit (rule 29).

## 3. Controls

One thumb, portrait, touch and drag only (rules 9-11). No swipe, long press, double tap, tilt or on-screen joystick in gameplay.

### 3.1 The input decision: follow-the-finger, not a relative joystick

**Chosen (my call): follow-the-finger.** The fish swims toward the point under the finger, lifted a little above the fingertip so the fish stays visible.

Why, for a 4-year-old (reasoning from rules 9, 12, 14, 16; no study compares the two schemes for this age, so this is my call, to be checked in the kids walk-through):
- **It is pointing.** "Put your finger where you want to go" needs no mental model. A relative joystick needs the child to understand that the press point is a neutral centre and the offset is a direction and speed; children press where they want the fish to go and then see it go somewhere else.
- **A joystick punishes the commonest child touch.** A child who lifts and re-presses (very common) restarts the joystick centre; small finger wobbles become direction changes. Follow-the-finger ignores wobble near the target (the fish slows and settles).
- **Tap works too, for free.** A short tap is a touch that ends at once: the fish swims to that spot and stops. Children who tap instead of hold still play (like rule 13's tap alternative).
- **The cost: the finger covers part of the pond.** Mitigations: the aim point is lifted 120 px above the fingertip, so the fish sits just above the thumb; the camera never moves (the whole pond is always visible); and danger cues are drawn on the fish, not under the finger.

The original's drag-as-arrow-keys and the sister game Neon Bricks' relative paddle drag were both considered. Relative drag suits a paddle on one axis; for free 2D movement it is a joystick in disguise.

### 3.2 Zones (logic px at 1080x1920)

| Zone | Rect | What happens |
|---|---|---|
| Shell home square | x 0-232, y 0-232 | Nothing of the game is drawn or tappable here. The stand-alone build draws its own home disc in the same place and size as the shell's (rule 20); hidden when `Engine.get_meta(&"mwm_play_shell")` is set. |
| HUD strip | x 256-1044, y 40-224 | Goal meter (section 8.2). Not tappable. |
| Pond (fish swim here) | x 0-1080, y 256-1640 | Fish, player, hazards, pickups. |
| Steer area | whole screen except the home square and y >= 1664 | Touch-down here starts steering. |
| Wrist strip | y >= 1664 | Touches that START here are ignored (rule 6). A touch that started higher keeps steering when it slides in. Decorative sea floor only. |

Taller screens (20:9, canvas about 1080x2400): HUD anchored to the top, sea floor and wrist strip to the bottom; the pond grows taller (more room, same fish count). Tablets about 1200 wide: the pond widens to the canvas, fish spawn at the real edges. Camera cutout: push the home disc below `DisplayServer.get_display_safe_area()` but keep its hit area running to the screen edge (copy the ball-connect fix).

### 3.3 Inputs

| Input | Where | Effect |
|---|---|---|
| Touch down | Steer area | Becomes the active pointer (latest touch wins, older touches ignored, rule 14). Same frame: a soft ring (aim marker, 64 px) appears at the aim point and a quiet bubble "blip" plays (rule 19). The fish turns toward it. |
| Hold / drag | Active pointer | Aim point = finger position minus `FINGER_LIFT` (120 px) in y. The lift fades linearly to 0 when the finger is between y 1400 and 1640, so the child can still steer to the sea floor. Aim point is clamped inside the pond. The fish's velocity eases toward the aim (section 4.1). |
| Release | Active pointer | The fish keeps swimming to the last aim point, slows down and idles there (gentle fin wobble). The aim marker fades over 300 ms. Nothing else happens on release: there is no action to trigger. |
| Tap | Steer area | Same as touch + release: swim to that point and stop. |
| Tap home disc / Android back | Top-left | Stand-alone: copies the shell guard (first tap: ring fills over 2.0 s, game keeps running; second tap between 0.3 s and 2.0 s leaves to the world map). In the shell the shell owns this. |
| App sent to background | | Pause. On return, a 240 px "play" disc in the centre resumes on release. |
| Win card buttons | Card | Section 8.4. |

Holdover filter: ignore all touches for 300 ms after any screen change (rule 8).

## 4. Rules (all distances in logic px)

### 4.1 Player motion

- Max speed `PLAYER_SPEED`: Lett 380 px/s, Vanlig 440 px/s.
- Wanted velocity = direction to the aim point x min(max speed, distance x 4.0 /s), so the fish slows smoothly over the last 95-110 px and never overshoots.
- Actual velocity eases toward the wanted velocity with time constant `STEER_TAU` (Lett 0.18 s, Vanlig 0.14 s): responsive, but a jerky finger gives a smooth fish.
- The fish faces left or right by the sign of its x velocity (flip takes 120 ms, a turn animation) and tilts up to 25 degrees with its y velocity.
- The player stays inside the pond with its body radius as margin. Pond edges are soft: no wrapping (my call).

### 4.2 Size tiers and the eat rule

Every fish, the player included, has a **tier** 1-10. Length from nose to tail (my call):

| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Length px (72 x 1.28^(t-1)) | 72 | 92 | 118 | 151 | 193 | 247 | 317 | 405 | 519 | 664 |

- Each tier is 28% longer (64% more area) than the one below, so neighbouring tiers look clearly different side by side.
- Collision body: a circle at the fish's centre with radius `BODY_R` = 0.30 x length. All checks below are centre to centre (simple, and exactly what the sim uses).
- **Eat:** the player eats a fish when that fish's tier is lower than the player's and the centre distance is under (player radius + fish radius x 0.5 + `EAT_REACH`). `EAT_REACH` (a mouth magnet) is Lett 36 px, Vanlig 18 px. The eaten fish is gone at once (no chewing delay); the player's body snaps to face the meal in 80 ms so it always looks like the mouth took it.
- **Caught:** a bigger fish catches the player when its tier is higher and the centre distance is under (big fish radius x 0.8 + player radius x 0.5) x `CATCH_SCALE` (Lett 0.70, Vanlig 0.75). The catch radius is smaller than the eat radius on purpose: near misses go the player's way. The big fish snaps to face the player in 80 ms for the gulp animation.
- **Same tier:** neither eats. Both are pushed 60 px apart over 0.15 s with a soft "boink" (section 9).
- The player never shrinks below its current tier (my call). The top tier the player can reach in a level is the level's goal; bigger fish can still be one or two tiers above that.

### 4.3 The "can I eat it?" cue (never colour only, rule 36)

Four cues, all shape or motion, all present at once (my call):

1. **Size itself.** Tiers differ by 28% in length (4.2).
2. **The player's mouth.** When an edible fish is within 260 px in front of the player (within 70 degrees of its facing), the player's mouth opens (0.12 s) and stays open; it closes when none is near. This is the strongest "yes" signal and needs no reading.
3. **Rings around fish** (shape, not colour):
   - Edible (lower tier): a **smooth round ring** of small bubbles circling slowly around the fish.
   - Danger (higher tier): a **spiky zigzag ring** (8 points) that pulses gently (1 Hz, under the flash limit).
   - Same tier: **no ring**.
   - Lett: rings on every fish all the time. Vanlig: a fish's ring fades in when it is within 420 px of the player and out beyond 480 px (hysteresis), so the screen stays calmer for older kids.
   - Rings update the moment the player grows (a fish that was danger can become edible: its spiky ring morphs into a smooth one over 0.25 s, with one soft "tink").
4. **Faces and fins.** A danger fish within 300 px opens its mouth toward the player and flares its fins; the player's eyes go wide. Edible fish in Vanlig dart away (4.6).

graphic-designer may add colour to the rings (DESIGN.md), but the shapes carry the meaning.

### 4.4 Growing

- Eating a fish of tier k adds k **food points** (bigger meals count more, like the original's size / 50).
- Food needed to grow from tier t to t + 1, `NEED(t)` (designer calc, `pacing_sim.py need`, chosen to give about 4-7 meals per tier):

| From tier | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|
| Lett: 3 + 2t | 7 | 9 | 11 | 13 | 15 | 17 | 19 |
| Vanlig: 3 + t | 5 | 6 | 7 | 8 | 9 | 10 | 11 |

- Lett needs more points but its fish mix is 70% edible and nothing chases, so a level is longer to play but never tense. Vanlig needs fewer points because every extra meal is a risk; levels end in under about 1 minute (designer calc, 6.3).
- Overflow carries over; a meal can grow the player more than once.
- **Growth moment:** the body pops to the new length over 0.35 s (ease-out with a 6% overshoot), a ring of bubbles bursts out, a rising chime plays, and the player gets 0.6 s of catch immunity. The meter's next silhouette fills in (8.2).

### 4.5 Fish population and spawning

- Fish enter from the left or right edge (just off screen) at a random y inside the pond (60 px margin), and swim straight across with a slow vertical wave (amplitude 20 px/s, period about 4 s). They leave at the other edge and are removed.
- Pond holds at most `FISH_MAX` fish (per level, 6.3). When below the max, a new fish spawns every 0.35 s.
- At level start, half of `FISH_MAX` (rounded down) fish are placed already in the pond at random x, never within 300 px of the player, and all of them edible tier 1 (Lett) or tier 1-2 (Vanlig), so food is there from second 0.
- **Tier roll for each new fish** (relative to the player's current tier P):

| | Edible (tier P-3 to P-1, weighted 1:2:3 toward P-1, never below 1) | Same tier | Bigger |
|---|---|---|---|
| Lett | 70% | 10% | 20%: P+1 two times in three, else P+2 |
| Vanlig | 60% | 10% | 30%: P+1 two times in three, else P+2 |
| Breathers (both) | +10 points to edible, taken from bigger | | |

- Level 1 spawns no bigger fish at all. **Anti-starve:** while fewer than 3 edible fish are on screen, the next spawn is always edible. Max tier on screen: 10.
- Fish speed (px/s) = (70 + 12 x tier) x random 0.75-1.25 x `FISH_SPEED_MULT` (Lett 0.75, Vanlig 1.0) x the world speed (6.3). Example: a tier-3 fish in world 1 swims 60-99 px/s in Lett and 80-133 px/s in Vanlig.
- Species per tier and world (realistic fish, e.g. reke / sild / makrell / torsk / laks / kveite) are graphic-designer's call; one rule from me: **one species per tier inside a world**, so a child learns "the striped ones are my size" (shape and pattern cue, rule 36).

### 4.6 Fish behaviour

- **Lett:** no fish chases and no fish flees. Bigger fish just cruise. A catch only happens when the player swims into a big fish's mouth.
- **Vanlig:** a bigger fish within `CHASE_RADIUS` 220 px turns toward the player and chases at 0.5 x the player's max speed (220 px/s) for at most 2.0 s, then gives up and resumes its course (each fish chases once). The player can always outswim a chaser. An edible fish within 200 px darts away at 1.3x its speed for up to 1.0 s.
- Fish do not eat each other (my call; keeps the pond count predictable and avoids sad moments).

### 4.7 Being caught: the gentle mechanic

- **Lett ("Boble-rapen"): costs nothing.** The big fish gulps (0.2 s, its cheeks puff), then **burps the player out inside a bubble**. The bubble floats for 1.4 s to a safe spot (the point nearest the pond centre that is at least 300 px from every bigger fish), pops, and the player swims on with 2.0 s of catch immunity (a soft shimmer around the body, not a flash). Food meter and tier are kept. The child learns that big fish are a nuisance, not a death.
- **Vanlig: costs progress and a bubble.** The same burp-out happens, and (a) the food meter of the current tier empties (the tier stays), and (b) one of 3 **bobler** (bubble icons in the HUD) pops. World 1 levels and every breather have unlimited bobler (only the meter empties). When all 3 are gone, the next catch starts a **gentle restart**: the pond dims to 60% over 0.6 s, all fish swim off to the sides over 0.8 s, the player shrinks back to tier 2 at the centre, bobler refill, dim lifts over 0.4 s. No text, no "game over", no failure sound (a soft reverse-bubble whoosh). Under 2 s total.
- Rule 31 (no game over for 4-7) holds in both settings: there is no game over screen.

### 4.8 Level goals

| Goal (NO / EN) | HUD | Rule | First level |
|---|---|---|---|
| **Vokse / Grow** | Row of fish silhouettes from tier 2 to the goal tier, goal one carries a star | Clear when the player reaches the goal tier | 1 |
| **Perler / Pearls** | N empty pearl slots | One pearl at a time: a shell on the sea floor or a rock opens (0.4 s) at a random spot at least 250 px from the player, 1.5 s after the last pearl was taken (1.0 s on level start). Swim over it (distance < player radius + 40 px) to take it. Pearls never vanish. Clear at N pearls | 4 |
| **Glitterfisk / Glitter fish** | N empty glitter slots | One glitter fish on screen at a time, 3 s after the last one was eaten (4 s on level start). It is always tier P-1 (edible), has a sparkle pattern and a star-shaped tail fin (shape cue), and swims at the normal speed. Clear at N eaten | 17 |

The player grows in every goal type; in pearl and glitter levels the size helps but is not the goal.

## 5. Elements

Every element has a shape or motion cue (rule 36). Names are Norwegian first; colour notes, if any, are hints for graphic-designer.

### 5.1 Hazards (one new per world, introduced on that world's L1)

| Name (NO / EN) | Shape cue | Behaviour | Lett | Vanlig | First level |
|---|---|---|---|---|---|
| Større fisk / Bigger fish | Spiky ring, open mouth when near (4.3) | Catch rules 4.2, 4.6 | No chase | Chase 2 s | 2 |
| **Kulefisk / Pufferfish** | Round body; puffs into a spiky ball | Swims at 60 px/s, tier P-1 when relaxed (edible). When the player comes within 220 px (Lett 160), it puffs over 0.3 s to 2x radius with spikes. Puffed: touching it bounces the player back 200 px over 0.3 s with a "boing", **no catch, no cost** in either setting. Stays puffed 2.5 s (Lett 2.0 s), deflates over 0.5 s; edible again once deflated. Teaches "wait, then eat". Puffing is announced by a 0.3 s inflate sound, never instant | 2 on screen | 2-3 on screen | 6 |
| **Manet / Jellyfish** | Bell with trailing threads, slow pulse | Drifts up and down at 40 px/s (bob amplitude 120 px), never eaten, never eats. Touching it: a soft **tingle**, the player is stunned for 0.4 s (Vanlig 0.6 s) and pushed 80 px away. No cost. Other fish pass through jellies | 2 | 3 | 11 |
| **Ål / Eel** | Long body in a hole; glowing eyes before it strikes | Lives in 2-3 fixed holes on the pond sides (wreck portholes, rocks). Every 5-8 s one eel **peeks**: eyes glow for 1.5 s (Vanlig 1.0 s), then it darts straight out 240 px (Vanlig 320 px) and back, 1.2 s total. The eel counts as a bigger fish (catch rules, gentle mechanic). Never chases | 2 holes | 3 holes | 16 |
| **Strøm / Current** | Horizontal band 200 px tall with slow streak lines and chevrons pointing the way (static low-contrast pattern scrolling at the current speed, rule 38) | Pushes everything inside it (player, fish, pearls stay put) at 100 px/s (Vanlig 140 px/s) in the chevron direction. Player can always swim against it (380 > 100) | 1 band | 2 bands | 21 |
| **Breiflabb / Anglerfish** | Big flat fish on the floor or a ledge, a lure light dangling in front | Never moves except to strike. If the player's centre comes within 180 px of the lure, the lure blinks twice over 1.2 s (Vanlig 0.8 s; 2 blinks in 0.8 s = 2.5 per s, under the 3 flash limit) and the angler lunges 200 px toward the lure and back (0.6 s). Counts as a bigger fish. The lure looks a bit like a pearl: in pearl levels, pearls never spawn within 250 px of a lure | 1 | 2 | 26 |

### 5.2 Friends (one new per world, introduced on that world's L4 or with its goal level)

| Name (NO / EN) | Shape cue | Behaviour | First level |
|---|---|---|---|
| **Tare / Kelp** | Tall swaying kelp patches (2-3, each about 160 x 520 px) | **Hiding place.** While the player's centre is inside a patch, no fish can catch it and chasers give up. The player swims at 70% speed inside. Edible fish pass through, so a child can wait in the kelp and snap. A small "safe" leaf shimmer runs over the patch when the player enters | 4 |
| **Skilpadde / Sea turtle** | Big turtle (about 420 px), slow | Crosses the pond every 25 s at 80 px/s. While the player overlaps its shadow (an ellipse under and behind it), big fish bump off the shell instead of catching (soft "donk"). Players learn to ride along | 9 |
| **Sjøhest / Seahorse** | Small upright seahorse holding on to a stalk | One per pearl level in world 3 and later. Touching it makes it shake out a pearl next to it (the next pearl spawns there instead of at random), at most once every 8 s. Pure helper | 12 |
| **Boblesøyle / Bubble column** | Vertical column of rising bubbles from the wreck floor | Inside it the player is carried upward at +260 px/s on top of its own steering. Fish avoid it. A fast lift away from the floor eels | 18 |
| **Hval / Whale** | Huge whale gliding behind the pond layer, singing | Every 30 s a whale passes (8 s). While its song plays, every bigger fish turns away from the player and swims to the nearest side edge: an 8 s safe window. Announced 1.5 s before by a low whale call | 23 |
| **Lysfisk / Lantern fish** | A small swarm (7 dots of light) drifting slowly | Touching the swarm gives "lys" for 8 s: the swarm circles the player and bigger fish keep at least one body length away (they turn off before reaching it). One swarm at a time, a new one 20 s after use | 27 |

### 5.3 Power-ups (own names, own twists)

A power-up floats as a 110 px glass bubble with an icon inside, bobbing 20 px. Swim over it to take it. At most 1 on screen; first one 8 s into a level that lists it, then every 20 s while none is on screen. Same power-up again = timer refresh, not stack.

| Name (NO / EN) | Icon shape | Effect | Twist | First level |
|---|---|---|---|---|
| **Bobla / Bubble shield** | Bubble with a shine mark | The next catch is blocked: the big fish bonks off the bubble, which pops. Lasts until used or 15 s | The player swims inside a visible bubble that wobbles when fish come near | 3 |
| **Turbofinne / Turbo fin** | Fin with speed lines | Player speed x1.5 for 6 s (Lett 8 s) | A trail of tiny bubbles; the trail gets shorter as time runs out (countdown with no digits) | 8 |
| **Slurp / Slurp mouth** | Swirl | `EAT_REACH` +80 px and edible fish within 220 px drift toward the mouth at 120 px/s, for 8 s (Lett 10 s) | A soft vortex of water lines in front of the mouth; fish are pulled in with a cartoon-free "suck" sound | 13 |

## 6. Progression

### 6.1 Rules

- 6 worlds x 5 levels = 30 hand-made levels, plus the endless mode **Uendelig** (6.5).
- Every world: **L1** one new hazard, **L2** practise it with a new goal type or the world's goal, **L3** a power-up (or a friend where the world has no new power-up), **L4** the friend and a combine, **L5** breather (lower goal, more food, Vanlig bobler unlimited, a calm "picture" level). One new idea at a time.
- No sequential lock (same as the sister games): any level can be picked from the map; the lowest uncleared level pulses at 1 Hz as the suggestion; nothing is ever shown locked.
- **Free part (owner shell rule):** the game holds `full_unlock: bool`, default `true`. The MWM Play adapter sets it on `enter()` through `set_full_unlock(on: bool)`.
  - `full_unlock == false`: the map shows only world 1 levels 1-3. Level discs 4-5 and the world arrows are not drawn at all. Clearing level 3 shows the normal win card with replay + home only (no "next") and emits `free_levels_finished`; the shell then shows its "Du har spilt alle banene her" card. Uendelig is not shown.
  - `full_unlock == true`: all 30 levels. The stand-alone build never calls the hook, so it is fully open.

### 6.2 Worlds

Names are my suggestions (Norwegian, the setting is graphic-designer's): realistic underwater places with a Norwegian flavour.

| World | Name (NO / EN) | Setting hint | Hazard (L1) | Friend | Power-up / rule (L3) | World speed |
|---|---|---|---|---|---|---|
| 1 | Tareskogen / Kelp Forest | Shallow, sunlit, god rays through kelp | Bigger fish (L2) | Tare (L4) | Bobla | 1.00 |
| 2 | Korallrevet / Coral Reef | Warm reef, clear water | Kulefisk (L6) | Skilpadde (L9) | Turbofinne (L8) | 1.05-1.08 |
| 3 | Manetbukta / Jellyfish Bay | Open blue bay, light shafts | Manet (L11) | Sjøhest (L12) | Slurp (L13) | 1.08-1.12 |
| 4 | Vrakdypet / Shipwreck Deep | Old wreck on sand, dimmer | Ål (L16) | Boblesøyle (L18) | Glitterfisk goal (L17) | 1.12-1.16 |
| 5 | Strømfjorden / Current Fjord | Cold fjord, steep rock walls | Strøm (L21) | Hval (L23) | Glitter in currents (L22) | 1.16-1.20 |
| 6 | Dyphavet / Deep Sea | Dark deep, bioluminescence (fish are always rim-lit so cues stay readable; no darkness mechanic) | Breiflabb (L26) | Lysfisk (L27) | Finale: grow to the top (L30) | 1.15-1.25 |

### 6.3 Level table

Columns: goal (Vokse = tier to reach from tier 2, Perler = pearl count, Glitter = glitter fish count); fish = `FISH_MAX`; speed = world speed multiplier; extras = hazards, friends and power-ups present. Vanlig bobler: 3 everywhere except world 1 and breathers (unlimited).

Sim columns (designer calc, `python3 tools/pacing_sim.py table -n 40`, 2026-10-10, 40 runs per level and setting): median clear time of the bot, Lett mean catches per level, Vanlig share of attempts with at least one gentle restart. All 60 rows cleared in 40 of 40 runs. **The sim plays an open pond with plain fish only: no hazards, friends, power-ups, currents, pre-placed start fish or same-tier bumps** (power-ups and friends mostly help, hazards cost time), so rows with extras are approximations. The bot never hesitates, misreads or wanders off for long; **treat every time as a floor**, a real 4-year-old will likely take 1.5-3x longer.

| # | W | Name | New / focus | Goal Lett / Vanlig | Fish L / V | Speed | Extras | Sim Lett median / catches | Sim Vanlig median / restart |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Første munnfull | Steer and eat (no bigger fish) | Vokse 3 / 4 | 7 / 8 | 1.00 | | 13 s / 0.0 | 21 s / 0 |
| 2 | 1 | Større fisker | Bigger fish, the cues | Vokse 4 / 5 | 7 / 9 | 1.00 | | 31 s / 0.1 | 46 s / 0 |
| 3 | 1 | Bobla | Bubble shield | Vokse 4 / 5 | 7 / 9 | 1.00 | Bobla | 32 s / 0.3 | 45 s / 0 |
| 4 | 1 | Gjemmeleken | Kelp, first pearl goal | Perler 4 / 6 | 7 / 9 | 1.00 | 3 Tare | 20 s / 0.1 | 22 s / 0 |
| 5 | 1 | Solstriper | Breather | Vokse 4 / 5 | 7 / 8 | 1.00 | 2 Tare | 30 s / 0.2 | 37 s / 0 |
| 6 | 2 | Kulefisken | Pufferfish | Vokse 5 / 6 | 8 / 10 | 1.05 | 2 / 3 Kulefisk | 39 s / 0.3 | 48 s / 22% |
| 7 | 2 | Perlerevet | Pearls among puffers | Perler 5 / 8 | 8 / 10 | 1.05 | 2 / 3 Kulefisk | 23 s / 0.2 | 33 s / 18% |
| 8 | 2 | Turbofinnen | Turbo fin | Vokse 5 / 6 | 8 / 10 | 1.05 | Turbofinne, 1 / 2 Kulefisk | 40 s / 0.3 | 49 s / 22% |
| 9 | 2 | Skilpadden | Turtle + combine | Vokse 5 / 7 | 8 / 10 | 1.08 | Skilpadde, 2 / 3 Kulefisk, Bobla | 44 s / 0.4 | 51 s / 38% |
| 10 | 2 | Korallhagen | Breather | Vokse 5 / 6 | 8 / 9 | 1.00 | Skilpadde | 40 s / 0.2 | 39 s / 0 |
| 11 | 3 | Manetene | Jellyfish | Vokse 5 / 6 | 8 / 11 | 1.08 | 2 / 3 Manet | 41 s / 0.6 | 49 s / 15% |
| 12 | 3 | Sjøhesten | Seahorse, pearls | Perler 6 / 9 | 8 / 11 | 1.08 | Sjøhest, 2 / 3 Manet | 30 s / 0.3 | 37 s / 18% |
| 13 | 3 | Slurp | Slurp mouth | Vokse 6 / 7 | 9 / 11 | 1.10 | Slurp, 2 / 3 Manet | 46 s / 0.3 | 57 s / 30% |
| 14 | 3 | Pigger og manet | Combine | Vokse 6 / 7 | 9 / 11 | 1.12 | 2 Manet, 2 Kulefisk, Turbofinne | 48 s / 0.5 | 53 s / 28% |
| 15 | 3 | Månelys | Breather | Vokse 5 / 6 | 8 / 10 | 1.05 | 1 Manet, Slurp | 38 s / 0.2 | 40 s / 0 |
| 16 | 4 | Ålen | Eel | Vokse 6 / 7 | 9 / 11 | 1.12 | 2 / 3 Ål-hull | 48 s / 0.6 | 56 s / 30% |
| 17 | 4 | Glitterfisken | Glitter goal | Glitter 3 / 4 | 9 / 12 | 1.12 | 2 Ål-hull | 18 s / 0.2 | 31 s / 15% |
| 18 | 4 | Bobletårnet | Bubble column, pearls | Perler 7 / 10 | 9 / 12 | 1.14 | 2 Boblesøyle, 2 / 3 Ål-hull | 33 s / 0.4 | 49 s / 35% |
| 19 | 4 | Vraket | Combine | Vokse 6 / 8 | 9 / 11 | 1.16 | Ål, Boblesøyle, 2 Kulefisk, Bobla | 49 s / 0.5 | 55 s / 30% |
| 20 | 4 | Skattekisten | Breather | Vokse 6 / 7 | 9 / 11 | 1.08 | 1 Boblesøyle, Slurp | 46 s / 0.2 | 47 s / 0 |
| 21 | 5 | Strømmen | Current | Vokse 6 / 8 | 10 / 12 | 1.16 | 1 / 2 Strøm | 47 s / 0.8 | 59 s / 42% |
| 22 | 5 | Glitter i strømmen | Glitter + current | Glitter 4 / 5 | 10 / 12 | 1.16 | 1 / 2 Strøm, Turbofinne | 24 s / 0.3 | 31 s / 20% |
| 23 | 5 | Hvalen | Whale | Vokse 7 / 8 | 10 / 13 | 1.18 | Hval, 1 Strøm | 50 s / 0.4 | 54 s / 28% |
| 24 | 5 | Villstrøm | Combine | Vokse 7 / 8 | 10 / 13 | 1.20 | 2 Strøm, 2 Manet, 2 Ål-hull, Bobla | 50 s / 0.3 | 58 s / 35% |
| 25 | 5 | Nordlys | Breather | Vokse 6 / 7 | 9 / 12 | 1.12 | Hval | 44 s / 0.2 | 46 s / 0 |
| 26 | 6 | Breiflabben | Anglerfish | Vokse 7 / 8 | 10 / 13 | 1.20 | 1 / 2 Breiflabb | 51 s / 0.5 | 58 s / 38% |
| 27 | 6 | Lysfiskene | Lantern fish, pearls | Perler 8 / 10 | 10 / 13 | 1.20 | Lysfisk, 1 / 2 Breiflabb, Sjøhest | 38 s / 0.2 | 48 s / 40% |
| 28 | 6 | Dypglitter | Glitter in the deep | Glitter 5 / 6 | 10 / 14 | 1.22 | Lysfisk, 1 Breiflabb, 2 Manet, Slurp | 27 s / 0.3 | 44 s / 32% |
| 29 | 6 | Alt på en gang | Everything | Vokse 7 / 9 | 10 / 13 | 1.25 | Breiflabb, Ål, Kulefisk, Strøm, Lysfisk, Bobla | 51 s / 0.5 | 65 s / 48% |
| 30 | 6 | Havets største | Finale: become the biggest | Vokse 8 / 9 | 10 / 13 | 1.15 | Lysfisk, Hval, Bobla + Slurp | 53 s / 0.2 | 50 s / 0 |

"x / y" in extras = Lett count / Vanlig count. **Reading:** Lett bot medians climb from 13 s to about 50 s and Lett catches stay under 1 per level (bigger fish are a nuisance, not a wall). Vanlig medians stay at 21-65 s; restarts stay at or under about 1 in 3 except L21, L27 and L29 (40-48%, the hardest levels; open question 4). Breathers and world 1 never restart (unlimited bobler).

Level 30's win card gets a longer finale (section 9): the player swims a lap as the biggest fish while every fish in the pond turns to look.

Level data file (suggested, builder's call): one JSON per level with `goal` (`"grow"|"pearls"|"glitter"`), `lett` and `vanlig` objects `{target, fish_max, bobler}` (0 = unlimited), `world_speed`, `hazards` (list of `{type, count_lett, count_vanlig, positions?}`), `friends`, `powerups`, `breather`. Values from this table.

### 6.4 World 1 layouts (vertical slice, build these exactly)

Pond rect x 0-1080, y 256-1640. Positions are centres in logic px.

- **L1 Første munnfull:** 3 tier-1 fish pre-placed at (300, 700), (780, 900), (420, 1250); player at (540, 950). No bigger fish (spawn table: 100% edible tier 1 until the player is tier 3; Vanlig goal 4 adds tier 1-2 edible only). Hand onboarding (8.3).
- **L2 Større fisker:** normal spawn table. The first bigger fish is scripted: at 4 s a tier P+1 fish enters from the right at y 600 at half speed with its spiky ring, so the child sees the cue before meeting a second one.
- **L3 Bobla:** normal; Bobla bubble at (540, 700) at 8 s.
- **L4 Gjemmeleken:** 3 kelp patches, rect centres (180, 1150), (540, 700), (900, 1150), each 160 x 520. Pearls spawn at random spots (4.8), never inside kelp.
- **L5 Solstriper:** 2 kelp patches (180, 950) and (900, 950); breather spawn table.

### 6.5 Uendelig (endless mode)

**Pitch:** an endless run of rounds; each round you start small and must grow one size bigger than last time; after that the sea gets busier and faster; the run never ends by losing; the best round is saved.

**Unlock and entry:** a 200 px "Uendelig" disc (a fish silhouette with a looping bubble trail, no text) on every world-map page at (540, 1560), between the world arrows. It appears once level 5 is cleared in either setting, and only when `full_unlock` is true. Before that it is not drawn (nothing is ever shown locked). It shows the best round for the current setting as a small digit on a gold star at its top-right (no star at 0).

**Rounds** (k = 1, 2, 3 ...), designer calc `pacing_sim.py endless`:

| | Lett | Vanlig |
|---|---|---|
| Goal tier in round k | min(3 + k, 8) | min(4 + k, 9) |
| Fish max | min(7 + k div 2, 10) | min(9 + k div 2, 13) |
| World speed | 1.00 + 0.03 x min(k - 1, 8), cap 1.24 at round 9 | same |
| Hazards | from round 3: one hazard type the player has met in the levels, picked at random each round (Lett count, as 6.3 L1 rows) | same, Vanlig counts |
| Power-ups | Bobla from round 2, one random unlocked power-up from round 4 | same |
| Bobler | none (catches cost nothing) | 3, refilled at every round start |

At the caps the round values stop growing; rounds keep counting. Sim (bot medians, 30 runs per round, open pond, designer calc):

| Round | Lett goal / fish / speed: median | Vanlig goal / fish / speed: median / restart |
|---|---|---|
| 1 | 4 / 7 / x1.00: 33 s | 5 / 9 / x1.00: 40 s / 20% |
| 3 | 6 / 8 / x1.06: 47 s | 7 / 10 / x1.06: 54 s / 27% |
| 5 | 8 / 9 / x1.12: 57 s | 9 / 11 / x1.12: 58 s / 27% |
| 7 | 8 / 10 / x1.18: 54 s | 9 / 12 / x1.18: 66 s / 40% |
| 9 | 8 / 10 / x1.24: 57 s | 9 / 13 / x1.24: 74 s / 47% |
| 12 | 8 / 10 / x1.24: 53 s | 9 / 13 / x1.24: 65 s / 37% |

A bot run to round 12 takes about 10 minutes (Lett) or 12 minutes (Vanlig) of play (sum of medians, designer calc), so the best round grows over several sittings. A plain "more fish" ramp did nothing in Lett (more fish = more food, round times fell from 50 to 43 s, designer calc), which is why the goal tier climbs first.

**No game over:** Lett catches cost nothing. Vanlig: empty bobler plus a catch restarts **the same round** (4.7); the round number never goes down. The only way out is the home disc / Android back, which ends the run (quitting costs nothing, rule 28).

**Round clear:** the normal clear sequence (9), then a small round card: the round number as a big digit on a gold star, and two discs at y 1300: home (x 340, 200 px) and next round (x 740, 240 px, most visible). No auto-advance (rule 26). Every 5th round the card is the full win card with spoken praise. The game emits `endless_card_shown(round: int)` on every round card.

**New best:** the star gets a gold ring that pops in (300 ms) with the growth chime at its highest step. No text, no "record".

**HUD in Uendelig:** the goal meter as in Vokse levels, plus a round badge (disc, diameter 150, centre (960, 136)) with the round digit; in Vanlig the 3 bobler sit under the meter.

**Save:** `endless_best` per setting (8.6). A run in progress is not saved.

## 7. Numbers (single balance table)

All tunables live in one const block or data file (studio rule).

| Key | Lett (4-7) | Vanlig (8+) | Unit | Note |
|---|---|---|---|---|
| `POND_RECT` | x 0-1080, y 256-1640 | same | px | Grows taller on 20:9 |
| `TIER_LEN` | 72 x 1.28^(t-1): 72, 92, 118, 151, 193, 247, 317, 405, 519, 664 | same | px | Tier 1-10 |
| `BODY_R` | 0.30 x length | same | | Collision circle |
| `PLAYER_START_TIER` | 2 | 2 | | Every level and round |
| `PLAYER_SPEED` | 380 | 440 | px/s | |
| `STEER_TAU` | 0.18 | 0.14 | s | Velocity easing |
| `ARRIVE_GAIN` | 4.0 | 4.0 | 1/s | Wanted speed = min(max, distance x gain) |
| `FINGER_LIFT` | 120, fading to 0 between finger y 1400 and 1640 | same | px | Aim point above the fingertip |
| `EAT_REACH` | 36 | 18 | px | Mouth magnet |
| `CATCH_SCALE` | 0.70 | 0.75 | | On (big r x 0.8 + player r x 0.5) |
| `MOUTH_OPEN_RANGE` | 260 px, 70 deg cone | same | | Cue 4.3 |
| `RING_RANGE` | always on | fade in 420, out 480 | px | Cue 4.3 |
| `NEED(t)` | 3 + 2t | 3 + t | food points | t = current tier |
| `FOOD(k)` | k | k | food points | k = eaten fish's tier |
| `SPAWN_EDIBLE / SAME / BIG` | 70 / 10 / 20 % | 60 / 10 / 30 % | | Breathers +10 edible, -10 big |
| `BIG_TIER_STEP` | +1 (2/3), +2 (1/3) | same | | |
| `EDIBLE_TIER_WEIGHT` | P-3 : P-2 : P-1 = 1 : 2 : 3 | same | | Never below tier 1 |
| `ANTI_STARVE_MIN_EDIBLE` | 3 | 3 | fish | |
| `SPAWN_INTERVAL` | 0.35 | 0.35 | s | While below `FISH_MAX` |
| `FISH_SPEED` | (70 + 12t) x U(0.75, 1.25) x 0.75 x world | (70 + 12t) x U(0.75, 1.25) x world | px/s | |
| `FISH_WAVE` | 20 px/s, period about 4 s | same | | Vertical drift |
| `CHASE_RADIUS / SPEED / TIME` | off | 220 px / 0.5 x player / 2.0 s | | Once per fish |
| `FLEE_RADIUS / MULT / TIME` | off | 200 px / 1.3 / 1.0 s | | |
| `SAME_TIER_PUSH` | 60 px over 0.15 s | same | | |
| `CATCH_BUBBLE_FLOAT` | 1.4 | 1.4 | s | Burp-out bubble |
| `CATCH_IMMUNITY` | 2.0 | 2.0 | s | After the bubble pops |
| `GROW_IMMUNITY` | 0.6 | 0.6 | s | |
| `BOBLER` | none | 3; unlimited in W1, breathers | | Then gentle restart |
| `RESTART_DIM / SWIM_OFF / LIFT` | n/a | 0.6 / 0.8 / 0.4 | s | |
| `PEARL_DELAY / FIRST` | 1.5 / 1.0 | same | s | Min 250 px from player |
| `GLITTER_DELAY / FIRST` | 3.0 / 4.0 | same | s | Always tier P-1 |
| `POWERUP_FIRST / EVERY` | 8 / 20 | same | s | Max 1 on screen |
| `BOBLA_MAX_S` | 15 | 15 | s | |
| `TURBO_MULT / S` | 1.5 / 8 | 1.5 / 6 | | |
| `SLURP_REACH / PULL_R / PULL_V / S` | +80 / 220 / 120 / 10 | +80 / 220 / 120 / 8 | px, px/s, s | |
| `PUFFER_TRIGGER / PUFF_S / KNOCKBACK` | 160 / 2.0 / 200 | 220 / 2.5 / 200 | px, s, px | No cost |
| `JELLY_STUN / PUSH / DRIFT` | 0.4 / 80 / 40 | 0.6 / 80 / 40 | s, px, px/s | No cost |
| `EEL_WARN / DART / PERIOD` | 1.5 / 240 / 5-8 | 1.0 / 320 / 5-8 | s, px, s | Counts as bigger |
| `CURRENT_SPEED / BAND_H` | 100 / 200 | 140 / 200 | px/s, px | |
| `ANGLER_TRIGGER / WARN / LUNGE` | 180 / 1.2 / 200 | 180 / 0.8 / 200 | px, s, px | |
| `KELP_SPEED_MULT` | 0.7 | 0.7 | | Safe inside |
| `TURTLE_PERIOD / SPEED` | 25 / 80 | same | s, px/s | |
| `WHALE_PERIOD / SAFE_S / WARN` | 30 / 8 / 1.5 | same | s | |
| `LANTERN_S / COOLDOWN` | 8 / 20 | same | s | |
| `BUBBLE_COLUMN_LIFT` | 260 | 260 | px/s | |
| `HINT_IDLE_S` | 7 | 12 | s | Rule 18 |
| `MAX_FLASHES_PER_S` | 3 | 3 | | Global limiter, rule 37 |
| `HOLDOVER_MS` | 300 | 300 | ms | Rule 8 |
| `FREE_LEVELS` | 3 | 3 | | Only when `full_unlock` is false |

## 8. Screens, onboarding and session shape

### 8.1 World map

Same pattern as the sister games: one world per page, the world's underwater scene behind, 5 level discs (diameter 200, hit area 240) on a path of bubbles between y 400 and 1500, never in the top-left 232 square or below y 1664. Cleared level: disc holds a star. Suggested next level: 1 Hz pulse. World change: arrow discs (200 px) at y 1560, x 160 and 920. Uendelig disc at (540, 1560) once unlocked (6.5). No swipe, no scroll (rule 20). Stand-alone only: gear disc top-right opens settings (10.2).

### 8.2 HUD (x 256-1044, y 40-224, not tappable, no text)

- **Vokse levels:** a row of fish silhouettes, one per tier from 2 to the goal tier, each drawn at its relative size (so the row itself shows "grow bigger"). Reached tiers are filled; the current tier's silhouette fills from tail to nose as food comes in; the goal silhouette carries a star. Lett no digits.
- **Perler / Glitter levels:** N slots (pearl shapes or star-tail fish shapes) that fill one by one, plus a small current-tier dot row under them.
- **Vanlig bobler:** 3 bubble icons at the right end (x 900-1040, y 160-216); each catch pops one with a single burst (one flash, not a strobe). Unlimited levels draw none.
- **Uendelig:** round badge (6.5).

### 8.3 First 60 seconds (no text anywhere)

- 0 s: first ever launch skips the map and opens level 1. Player fish at the centre, 3 tiny fish swim nearby. Level intro (9).
- 1.0 s: a hand icon appears, presses just below the nearest tiny fish, and the player fish swims to it while the hand follows; loops every 2.4 s until the child's first touch. Voice line (when recorded, native Norwegian voice only): "Hold fingeren der du vil svømme" ("Hold your finger where you want to swim"; rule 17).
- First touch: the fish swims to the finger. Near a tiny fish its mouth opens; first gulp: crunch-free "nam" sound, bubbles, the meter's silhouette fills a little.
- About 13 s (bot, designer calc; likely 20-40 s for a real 4-year-old): 7 meals, the fish pops to tier 3, goal reached, win card.
- Level 2: the scripted first bigger fish (6.4) shows the spiky ring and the open mouth. If the child swims into it, the burp-bubble sequence shows that nothing bad happens.
- **Idle hint** (rule 18): after `HINT_IDLE_S` with no touch, or Lett 3 catches within 15 s, the hand returns and points at the best target: the nearest edible fish (or pearl / glitter fish) whose straight path from the player stays at least 150 px from every bigger fish; if none, the nearest kelp or the pond centre.

### 8.4 Win card (natural stopping point)

- Goal reached: clear sequence (9), then the card 1.4 s later.
- Shows: the player fish at its final size swimming in a small loop, one big star landing, and three icon discs at y 1300: replay (x 270, 200 px), map/home (x 540, 200 px), next (x 810, 240 px, most visible). No text.
- Spoken praise of the action (rule 32, when recorded): "Du spiste deg stor!" ("You ate your way big!"); pearl levels "Du fant alle perlene!"; glitter levels "Du fanget alle glitterfiskene!".
- Never auto-advances (rule 26). The game emits `level_card_shown(level_id)`; the shell's play limit may end the session here.
- After level 30: no "next" disc. After level 3 with `full_unlock` false: no "next" disc, emit `free_levels_finished`.

### 8.5 Session shape

A level takes about 15 s to 2 min. A child plays 4-8 levels per sitting and stops at a card. Pull to come back: the next world's new place and new creature, and the Uendelig best round for older kids. No streaks, daily rewards, timers or "come back" messages (rule 27).

### 8.6 Save (`user://reef_bite_save.json` until named)

```json
{
  "version": 1,
  "cleared": [1, 2, 3],
  "difficulty": "lett",
  "endless_best": {"lett": 0, "vanlig": 0},
  "settings": {"sfx": true, "music": true, "haptics": false, "less_motion": false}
}
```

Save on level clear, on an Uendelig round clear that beats the best, on difficulty or setting change, on leaving and on `NOTIFICATION_APPLICATION_PAUSED`. Mid-level state is not saved: a left level starts fresh (quitting costs nothing, rule 28). `settings` are only read in the stand-alone build; inside MWM Play the shell's settings win. Missing keys read as defaults. When the name is picked, the file is renamed with the slug (no migration needed before the first release).

## 9. Feel

Sound direction (my call, owner to confirm, open question 6): **soft underwater**, warm and round: bubbles, plops, muffled chimes, whale song, no 8-bit, no growls, no scary bites, no "fail" stings. All sounds made by us (own synthesis in a `tools/render_sfx.py` like the sister games) or CC0 (listed in `CREDITS.md`); nothing from the original. Pitched sounds share one pentatonic scale chosen to fit the music. Files peak at -3 dBFS; the game sets each event's level so effects peak near -12 dBFS and music sits at least 6 dB under effects (rule 33). Every play picks a random variant and a +-4% pitch spread. Every sound below must be listened to before it ships (studio rule: never ship unheard audio).

"Mindre bevegelse" (less motion, rule 39) column says what replaces the effect.

| Event | Visual | Sound (key: description, length, level) | Haptic (only if on; default off) | Mindre bevegelse |
|---|---|---|---|---|
| UI tap (map, card, any disc) | Button presses to 94% in 80 ms, springs back 120 ms | `tap`: soft water "plip", 0.12 s, -6 | 10 ms | Tint only |
| Steer touch-down | Aim ring (64 px) fades in over 60 ms at the aim point | `touch`: tiny bubble blip, 0.06 s, -16 | none | same |
| Fish turns around | Body flips over 120 ms with a tail flick | none | none | Instant flip |
| Mouth opens (edible near) | Mouth opens over 120 ms | none (visual cue only; sound would nag) | none | same |
| **Eat** | Fish vanishes into the mouth with 6-10 small bubbles (0.4 s); player body squashes 8% for 80 ms | `eat_1..3`: soft "nam" (mouth pop + water gulp), 0.2 s, -4; pitch steps up one note per meal within 1.5 s of the last (max 5 steps), resets after | 12 ms | No squash; bubbles kept |
| Meter fills | Current silhouette fills smoothly over 200 ms | none | none | Instant |
| **Grow (tier up)** | Body pops to the new size over 0.35 s (6% overshoot); ring of bubbles bursts out; silhouette in the HUD lights | `grow`: rising 3-note bubbly chime + warm whoosh, 0.9 s, -3; higher tiers start one note higher | 25 ms | No overshoot, no bubble ring; size changes over 0.2 s |
| Edible fish nearby (ring morph after a grow) | Spiky ring morphs to smooth over 0.25 s | `tink`: one soft glass tink per growth (not per fish), 0.2 s, -18 | none | Ring swaps instantly |
| Same-tier bump | Both push apart 60 px over 0.15 s | `boink`: rubbery water boink, 0.15 s, -12 | 8 ms | Push kept (it is gameplay) |
| Danger near (Vanlig chase starts) | Chaser's fins flare, its mouth opens | `swish`: low water swish, 0.4 s, -14; max one per 2 s | none | same |
| **Caught (burp-out)** | Big fish gulps (cheeks puff 0.2 s), then the player pops out inside a bubble that floats 1.4 s to the safe spot, wobbling; pops with a ring of tiny bubbles; 2.0 s shimmer (soft, low contrast, not a flash) | `gulp`: muffled big gulp, 0.25 s, -8; then `burp`: comic soft burp-bubble, 0.4 s, -6; then `bubble_pop`: 0.15 s, -8 | 20 ms | Bubble moves without wobble; shimmer replaced by a static outline |
| Bobler lost (Vanlig) | One HUD bubble pops (one burst) | `bobler`: small pop + descending 2 notes, 0.4 s, -10 | 15 ms | Icon disappears |
| Gentle restart (Vanlig) | Dim, fish swim off, player shrinks (4.7) | `rewind`: reverse-bubble whoosh, 1.2 s, -6 | none | Instant dim and reset |
| Pearl appears | Shell opens over 0.4 s, pearl glows (steady, no blinking) | `shell`: soft clam creak + shimmer, 0.5 s, -12 | none | Shell appears open |
| **Pearl taken** | Pearl flies to its HUD slot (0.4 s arc) | `pearl`: clear bell "ding", one note up per pearl, 0.6 s, -4 | 15 ms | Pearl fades, slot fills |
| Glitter fish eaten | Sparkles fly to the HUD slot | `eat` + `pearl` layered, 0.6 s | 15 ms | Slot fills |
| Power-up taken | Bubble bursts, icon flies onto the player | `bobla_on`: wobbly bubble inflate, 0.7 s, -6; `turbo_on`: rising fizz whoosh, 0.6 s, -6; `slurp_on`: watery vortex swirl, 0.8 s, -6 | 15 ms | Icon appears on the player |
| Bubble shield blocks | Big fish bonks off, the bubble pops | `bonk`: rubbery bonk + pop, 0.3 s, -6 | 20 ms | same |
| Power-up running out | Trail / vortex shrinks over the last 2 s | none | none | same |
| Pufferfish puffs | Inflates over 0.3 s, spikes out | `puff`: balloon stretch, 0.35 s, -10 | none | Swaps to puffed |
| Puffer bounce | Player bounced 200 px | `boing`: soft spring boing, 0.25 s, -8 | 12 ms | Bounce kept |
| Jellyfish tingle | Player wobbles 0.4-0.6 s, small sparkle dots (no flash) | `tingle`: soft fizzy shimmer, 0.5 s, -10 | 15 ms | No wobble |
| Eel peek / dart | Eyes glow steady for the warning time; eel shoots out and back | `eel_peek`: low hum rising, 1.0 s, -14; `eel_dart`: water whoosh, 0.4 s, -8 | none | same (gameplay) |
| Current | Streak lines drift (static pattern, low contrast) | `current`: soft rushing loop, -22, only while the player is inside a band | none | Lines static, chevrons kept |
| Angler lure blink / lunge | Lure blinks twice (under the flash limit); lunge 0.6 s | `angler`: two low "bloop" notes then a muffled snap-free gulp, 1.2 s, -10 | none | Lure brightens once instead of blinking |
| Kelp enter | Leaf shimmer over the patch, 300 ms | `kelp`: leafy swish, 0.3 s, -16 | none | No shimmer |
| Turtle / shell bonk | Shell wobbles | `donk`: hollow wooden donk, 0.2 s, -10 | none | same |
| Whale passes | Whale glides behind (8 s); fish turn away | `whale`: whale call 1.5 s before, then a soft song under the music, 8 s, -14 | none | same |
| Lantern swarm | Lights circle the player for 8 s | `lantern`: soft glassy chimes, 0.8 s, -10 | none | Lights fixed around the player |
| Bubble column | Bubbles rise; player carried up | `column`: bubbling loop, -18, while inside | none | same |
| **Goal reached / level clear** | Time scale 0.4 for 0.4 s real time; all other fish turn and swim off; player does a happy loop; star flies to the HUD; camera push-in 4% (no shake) | `win`: warm marimba-and-bubbles fanfare with a whale-like swell, 3.0 s, -2; music ducks for 3 s | 40 ms | Slow-mo kept; no loop, no push-in |
| Win card | Star lands, 300 ms | `star`: bright bubble ping, 0.6 s, -6; then spoken praise | none | Star appears |
| Level 30 finale | Every fish in the pond turns toward the player for 2 s, then the normal clear | `win` + `whale` song layered | 40 ms | No turn |
| Level intro | Camera starts 6% zoomed in and eases out over 0.8 s; light shafts fade in | `intro`: descending bubble cascade into a soft water swell, 1.5 s, -12 | none | Cut, no sound |
| Ambient | Slow god rays, drifting particles (graphic-designer) | `ambience`: gentle underwater bed, -24, loops | none | Particles off |
| Hint | Hand icon, 1.5 s | `hint`: faint shimmer, 1.0 s, -16 | none | Static hand |
| Uendelig round start / new best | As level intro; new best: gold ring pops onto the star | `intro`; new best `grow` at its top step then `star` | 40 ms | Ring appears |

Music: one calm underwater track per world or one loop for all (open question 6), at least 6 dB under effects.

Flash safety: a global limiter allows at most 3 bright flashes per second (rule 37); extra events inside the same 333 ms get sound and particles but no glow spike. No full-screen flashes. Caustic light on the floor stays low contrast and slow (period >= 2 s), and the current streaks never flicker (rule 38).

## 10. Difficulty settings

### 10.1 Lett (ages 4-7, default) vs Vanlig (ages 8+)

| Aspect | Lett | Vanlig |
|---|---|---|
| Caught by a bigger fish | Burped out in a bubble, nothing lost | Burped out, current tier's meter empties, 1 of 3 bobler; empty + catch = gentle restart (W1 and breathers unlimited) |
| Bigger fish | Never chase | Chase 2 s within 220 px at half player speed |
| Edible fish | Never flee | Dart away within 200 px |
| Spawn mix | 70% edible, 20% bigger | 60% edible, 30% bigger |
| Player speed | 380 px/s | 440 px/s |
| Fish speed | x0.75 | x1.0 |
| Mouth magnet | 36 px | 18 px |
| Food per tier | 3 + 2t | 3 + t |
| Rings | always on | within 420 px |
| Goals | Vokse 3-8 | Vokse 4-9, more pearls / glitter |
| Hazards | fewer, longer warnings | more, shorter warnings |
| Hint | after 7 s idle or 3 catches in 15 s | after 12 s idle |
| Same 30 levels and layouts | yes | yes |

Rule 16 (no reflex demands at the easiest level) holds: in Lett nothing chases, the player is at least 2.9x faster than any fish in world 1 (380 px/s vs at most 133 px/s for the biggest fish that can appear there, tier 6, designer calc), and a catch costs nothing.

### 10.2 Where the setting lives

Same as the sister games: inside MWM Play, a "<name>: Lett / Vanlig" row in the parent area and the adapter calls `set_difficulty(easy: bool)` on `enter()`. Stand-alone: the gear on the world map opens Lett/Vanlig, sound, music and "Mindre bevegelse". Difficulty takes effect from the next level start. Vibration is not in this build: it would need the Android vibrate permission, and the stand-alone game asks for no permissions.

## 11. Performance budget (mid-range phone)

Targets for the builder and game-qa (guess; the phone PerfOverlay decides; the owner's test phone model is open question 8). "Mid phone" here means a Mali-G52 / Adreno 610 class GPU, 4 GB RAM.

| Item | Budget |
|---|---|
| Frame rate | 60 fps target, never under 30 fps on the mid phone; frame time <= 16.6 ms in a busy level (14 fish + 3 hazards + 2 friends) |
| Animated actors on screen | max 14 fish + player + 3 hazards + 2 friends + 1 power-up + 1 pearl = 22 |
| Draw calls in play | <= 120 (Godot `mobile` renderer); fish of the same species share one material and mesh (MultiMesh or instancing per species where possible) |
| Triangles | <= 3,000 per fish at tier >= 6, <= 1,200 below; <= 120,000 in view in total |
| Animation | swim motion in the vertex shader (sine bend along the body), no skeletons for small fish (graphic-designer / builder call) |
| Lights and shadows | 1 directional light; no real-time shadow maps; floor blob shadows; caustics as one projected/animated texture on the floor and rocks |
| Transparency | god rays and fog as <= 4 large additive cards; no full-screen post blur |
| Particles | <= 4 GPU particle emitters alive, <= 400 particles in total (bubbles); pool them |
| Textures | species atlases <= 1024 x 1024, ETC2/ASTC; total texture memory <= 150 MB |
| RAM | <= 400 MB in play |
| Game logic | no physics engine bodies: circle-vs-circle checks over <= 22 actors per frame (O(n), trivial); fish pooled, never instanced mid-level |
| APK / AAB | game share <= 60 MB |
| Audio | <= 12 simultaneous voices; eat/bounce sounds rate-limited (max 6 per second) |

## 12. MWM Play integration

- **Shell flag:** read `Engine.get_meta(&"mwm_play_shell", false)`; when set, hide the game's own home disc, own sound button and own settings gear.
- **Hooks called by the adapter:** `set_full_unlock(on: bool)` (default true), `set_difficulty(easy: bool)` (default Lett), `set_shell_inset(Vector2(232, 232))` (no-op: nothing sits there), plus the shell's four settings (sfx, music, haptics, less motion).
- **Signals up:** `level_card_shown(level_id: int)`, `endless_card_shown(round: int)` (the adapter treats it like `level_card_shown`), `free_levels_finished()`.
- **Save:** public `save_game()` for the adapter's `exit()`; file `user://<slug>_save.json` (8.6). The sync script prefixes `user://` paths with the slug, so the builder writes the file name exactly as the sister games do and checks the final path after `tools/sync_game.py`.
- **Names:** unique class names and autoloads with the two-letter prefix (`Rb`; e.g. `RbGame`, `RbSfx`, never bare `Game`, `Main`, `Fish`, `Player`). Runtime folders only: `scenes scripts assets data`.
- **Layout:** portrait 1080x1920, `stretch/aspect = expand`, top-left 232 px square kept empty in play and on the map, nothing tappable at y >= 1664, every child target >= 200 px drawn with a hit area >= 240 px.
- **Back:** `quit_on_go_back = false`; Android back starts the home guard (stand-alone) or is handled by the shell.
- **No network, no SDKs, no permissions** (rules 43-45).

## 13. Vertical slice (what godot-android-dev builds first)

In: world 1 map page; levels 1-5 exactly as in 6.4; follow-the-finger control with lift and aim ring; tiers, eat/catch/bump rules; all four "can I eat it" cues; spawn table, anti-starve; Lett burp-out bubble; Vanlig chase/flee, meter loss, bobler and gentle restart (world 1 is unlimited, so cover bobler and restart with a headless test and a test-only level flag); kelp; Bobla; pearl goal; HUD for Vokse and Perler; win card; hand onboarding and idle hint; Lett/Vanlig switch; `full_unlock` flag and the three signals; "Mindre bevegelse"; save file; flash limiter; home square kept free. Placeholder fish meshes are fine until graphic-designer delivers.

Out: worlds 2-6, other hazards, friends and power-ups, glitter goal, Uendelig, voice lines (blocked on a native Norwegian voice), store art.

## 14. QA hints (game-qa)

- **Licence audit:** no file from `projects/fishy/assets/` and no code from `projects/fishy/scripts/` in the repo (compare hashes of all assets; grep the GDScript for `fishsize`, `fishspeed`, `swimspeed`, `f_size`, `deadfish`, `_koi`, `XGen`, `Fishy`); the strings "Fishy" and "XGen" appear nowhere in the build, store text or credits.
- Lett level 1 clears with no instruction (kids walk-through, sound off, rule: walk the child flow).
- No touch target below y 1664 or inside 232 x 232; level discs and card discs >= 240 px hit area.
- A same-tier fish never eats or is eaten (log check); the player never shrinks below its tier (log check); no fish ever spawns inside the player's catch range at level start.
- Lett: 20 forced catches in a row never change the tier or meter (log check).
- Never more than 3 flashes in any 1 s window when 5 fish are eaten within 1 s.
- No English text on any child screen.

## 15. Play together tip (rule 42, draft)

"Spill på tur: én styrer fisken, den andre sier fra når en stor fisk kommer." ("Take turns: one steers the fish, the other calls out when a big fish is coming.") On Lett a parent can also hold the phone and let the child point: the fish follows any finger, the latest touch wins.

## 16. Open questions for the owner

1. **Name:** pick one from section 0 (my ranking: Reef Bite, Tide Bite, Glupsk, Reef Grow, Deep Gulp), or propose another and I will run the same TMview + Play check.
2. **Control:** follow-the-finger with the fish lifted 120 px above the fingertip (my pick, 3.1). OK, or do you want to try a relative joystick in the slice as an A/B on your phone?
3. **Vanlig cost of a catch:** the meter of the current tier empties and 1 of 3 bobler pops (my pick, 4.7). Alternative: shrink one whole tier per catch (closer to "being eaten", harsher). Which?
4. **Vanlig peaks:** the sim restarts 40-48% of attempts on L21, L27 and L29 (the rest at or under about 1 in 3). Keep these as the hard peaks, or soften them (one fewer fish brings them near 30%, designer calc)?
5. **Equal tier:** same-size fish just bump (my pick). OK, or should the player be able to eat same-size fish (easier) or be eaten by them (the original rule)?
6. **Sound and music:** soft underwater sound set made by us (my pick, section 9). Do you want to supply the music like for Orb Fence (one mix played low), or should we make a calm CC0/own loop?
7. **Player fish:** which fish is "you"? A realistic small species (e.g. a young mackerel or a reef fish) that keeps its species as it grows, or does it change species per tier? graphic-designer needs this for DESIGN.md.
8. **Test phone:** which phone model should the performance budget (section 11) be checked on?
9. **Uendelig unlock:** after level 5 (my pick, same as Orb Fence), from the start, or after level 30?
10. **World 6 darkness:** I left out a darkness mechanic (cues must stay readable, and dark can scare 4-year-olds); the deep sea is only a darker look. OK?
