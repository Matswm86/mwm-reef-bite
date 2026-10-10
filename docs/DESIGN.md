# MWM fish game (slug `mwm-reef-bite`): visual design spec

Owner: graphic-designer. Version 1, 2026-10-10. The builder reads this before touching any colour, material, light, camera, fish model or UI node. Rules and numbers come from `docs/GDD.md` (game-designer, written in parallel; I read version 1); child rules (rule N) from `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. Numbers tagged (my calc) are my own arithmetic with the WCAG 2.x formula, either sampled from the rendered mock or computed from the tokens below.

**Owner decisions this spec follows:**
- Underwater **realistic** look: PBR fish, caustics, god rays, depth fog, particles and bubbles (owner, 2026-10-05).
- Modern, realistic, high-end; **no toy, cute or "friendly" style, even for kids**. Kid rules live in the gameplay (rings, no game over, big targets), never in a cartoon art style (owner rule 2026-10-06, `memory/feedback/feedback_new_3d_games_realistic_not_toy.md`). A mock frame goes to the owner before the build: `docs/mockups/world1_mock.png`.
- This game has its own look, separate from the MWM Play shell and from every sister game.
- Engine: **Godot 4.6.2**, `mobile` renderer, portrait 1080x1920, `stretch/aspect = expand`.

**The one rule the builder must not change:** every gameplay fish (player, food, danger, hazards, friends, pickups) lives on **one play plane** under a **fixed camera**, so a fish's length on screen is exactly its tier length from GDD 4.2. Nothing interactive is ever placed at another depth, and nothing at another depth ever looks interactive.

## Mockups

All rebuilt by the scripts in `docs/mockups/src/` (Blender 4.5.1 in background mode, Cycles; the fish, kelp and seagrass are the game GLBs from `assets/models/`, plus two Poly Haven CC0 scans; then Pillow). Fish and kelp realism pass: 2026-10-10. The Blender MCP addon was not connected in this session, so I drove Blender from the command line instead; nothing opened on the desktop.

| File | What it shows |
|---|---|
| `docs/mockups/world1_mock.png` | **World 1 "Tareskogen", level 2 "Større fisker", Lett, mid-play, 1080x1920.** Player tier 3 (118 px) with the current tier half full in the HUD; 2 brisling (tier 1) and 2 grønngylt (tier 2) with bubble rings (edible); 1 sei (tier 3, same tier, no ring); berggylt (tier 4) and lyr (tier 5) with zigzag rings (danger); aim ring above the finger point; kelp forest, god rays, caustics, depth fog |
| `docs/mockups/world1_zones.png` | Same frame with zones: home square (white), HUD strip (blue), pond y 256-1640 (yellow), ring bounding boxes (green), wrist strip y >= 1664 (red) |
| `docs/mockups/world1_grey.png` | Same frame in greyscale: proof that edible / same / danger and the HUD states read without colour (rule 36) |
| `docs/mockups/wincard_mock.png` | Win card over the blurred scene: player portrait, tier row, star, replay / map / next discs |
| `docs/mockups/src/world1_mock.py` | `blender -b --factory-startup -P world1_mock.py -- <out_dir> [samples] [scale%]`: whole scene, imports the fish and kelp GLBs, writes `w1_raw.png`, object masks and `fish.json` (tier, centre px, kind of every fish). About 70 s on the RTX 3060 at full size, 128 samples |
| `docs/mockups/src/fish_species.py` | Shape, fin, colour and atlas-layout spec of the 8 world-1 fish (shared by painter and builder) |
| `docs/mockups/src/fish_paint.py` | `python3 fish_paint.py assets/models/fish/textures`: paints the fish atlas (albedo + alpha, normal, ORM), about 20 s |
| `docs/mockups/src/fish_build.py` | `blender -b --factory-startup -P fish_build.py -- <tex_dir> assets/models/fish <preview_dir> [--no-preview]`: meshes, GLB export, lineup and close-up renders |
| `docs/mockups/src/kelp_paint.py`, `kelp_build.py` | Same pair for `assets/models/kelp/` (giant kelp, sugar kelp, eelgrass) |
| `docs/mockups/src/wincard_render.py` | `blender -b <out_dir>/world1_mock.blend -P wincard_render.py -- <out_dir> [samples]`: player portrait for the card (rim cut to 10% and AgX High Contrast for the close-up) |
| `docs/mockups/src/overlay.py` | `python3 overlay.py <out_dir> docs/mockups`: rings, aim ring, HUD, zones, greyscale, win card, and the contrast table in section 9 |

Raw renders and the `.blend` live outside the repo in `~/MWM/scratch/mwm-reef-bite/render2/` (current) and `render/` (before the realism pass); the pre-pass mockup PNGs are kept in `~/MWM/scratch/mwm-reef-bite/old_mockups/`.

**What the mock does not prove.** The fish are now the real game meshes (section 4b): side-profile anatomy per species, fin rays, gill cover, lateral line, scale normal map, wet specular and domed eyes. At game size they read as real species; on the win-card close-up the player is clearly a trevally now, but it still looks clean-CG rather than photographed: smooth head with no skin micro-detail, flat lighting at 1 m, rays and scales painted rather than sculpted. A sculpt-and-bake pass on the player head (section 12) is the next step before store screenshots. The environment (kelp, light, caustics, fog, sand) is the look to sign off; the mock is a Cycles render, not a Godot capture.

---

## 1. Visual theme

**A sunlit underwater documentary seen from the side: real fish with wet, scaled, silver-and-colour skin glide through a golden kelp forest, sun shafts and moving caustic light fall from a rippling surface, and the water fades to blue-green depth behind them.**

References (take the idea, not the look):
- **BBC "Blue Planet II", "Green Seas" kelp-forest sequences**: take the light. Golden-brown kelp backlit by the sun, shafts slanting down through the canopy, fish lit from above with a darker belly side, water that turns from bright cyan near the surface to deep teal at the floor. Leave behind any real footage (we render everything).
- **Subnautica (Unknown Worlds), the Safe Shallows**: take the game-scale tricks that make realistic water readable at distance: one fog colour ramp by depth, caustics on sand and creature backs, a bright surface ceiling, silhouettes that stay clean against fog. Leave behind its sci-fi flora and first-person camera.

Mood in one sentence: clear, calm and real; the sea looks like a nature film, and the only "game" marks are the white rings and the HUD.

### 1a. What we must not copy from the original Fishy (seen in `projects/fishy/screenshots/`)

| Original (XGen, 2003) | This game |
|---|---|
| Flat vector cartoon fish with outline gill-curves, giant round eyes with a white highlight, open "smile" mouths | Realistic species with real proportions, small realistic eyes (iris + pupil), closed mouths that open only as a gameplay cue |
| Pastel pink, lavender and sky-blue fish; orange-red-yellow player | Natural species colours per world; player is a **gold golden trevally with black bars** (section 4) |
| Landscape 550x400, light-blue vertical gradient water, one flat brown dune strip, flat green and teal seaweed strands | Portrait, 3D kelp forest in depth, PBR sand with caustics, fog, surface ceiling, god rays |
| Big score number top-centre; "Q" and speaker icons bottom-left | No score, no numbers in Lett; home disc top-left; HUD is a row of fish silhouettes |
| "! FISHY !" title and Comic-style capital text; "YOU ATE EVERYTHING..." end text | No text for the child anywhere |
| White fish skeletons on the floor after losing | Nothing dies: a catch is a burp-bubble (GDD 4.7); no bones, no blood, ever |
| Bubbles as plain white circles from the player's mouth | Rim-lit glass bubbles (fresnel), only from eating, growing and the gill trail |

## 2. Camera

**Choice: real 3D models, side view, fixed perspective camera, all gameplay on one plane (a "2.5D game in a 3D world").**

| Setting | Value | Why |
|---|---|---|
| Node | `Camera3D`, perspective, looks along -Z at the play plane z = 0 | |
| Distance | 9.0 m | |
| FOV | `keep_aspect = KEEP_WIDTH`, `fov = 22.9` (horizontal) | 1080 logic px across = 3.645 m at 9 m: **1 logic px = 1/296.3 m** on the play plane at every screen height (20:9 phones only see more water above and below). Blender equivalent in the mock: sensor 36 mm vertical, lens 50 mm at 1920 px |
| Mapping | `x_m = (px - 540) / 296.3`, `y_m = (960 - py) / 296.3`, z = 0 | Logic positions from the GDD drop straight into 3D |
| Height | Camera at the pond centre, horizon at screen y 960 | The sea floor fills the wrist strip and fades into fog toward the horizon |
| Motion | **None during play** (GDD 3.1). Level intro: starts 6% closer and eases out over 0.8 s. Level clear: 4% push-in, no shake (GDD 9). Both off under "Mindre bevegelse" | |

Why this and not the alternatives:
- **Not flat 2D sprites (classic 2.5D cards):** realistic fish need light that moves over them: caustics crawling over the back, a rim of sun on the dorsal edge, the body darkening as it turns away. A sprite cannot react to the caustic or the turn (GDD 4.1: 120 ms flip, 25 degree tilt). A 3D fish with a vertex-shader swim costs about the same draw call as a sprite.
- **Not orthographic:** orthographic kills the depth that sells realism (kelp rows getting smaller and bluer, parallax during the intro zoom). Perspective is free here because every gameplay fish sits at the same distance, so perspective never changes their relative sizes.
- **Not a free 3D camera or follow camera:** the GDD keeps the whole pond visible and the camera still; a moving camera would make tier sizes drift on screen.

Depth layers (Godot units = metres, camera at z = +9):

| Layer | z | Content | Rules |
|---|---|---|---|
| In front of the plane | +0.1 to +8 | Marine snow particles only | No kelp, rocks or fish in front of the play plane, ever (they would hide fish and break "on the plane = interactive") |
| **Play plane** | 0 (fish bodies within +-0.15) | All gameplay actors, on-plane kelp patches (Tare friend), pearl shells, power-up bubbles | Full contrast, no fog (fog starts 10 m from camera = 1 m behind the plane) |
| Near background | -1 to -10 | Floor, rocks, kelp forest; clear lane in the middle behind the pond centre (kelp only at abs(x) >= 1.6 m when z > -10) | Fog 0-30% |
| Far background | -10 to -30 | Kelp rows, rocks, scenery schools (MultiMesh) | Fog 30-100% (fog end 34 m from camera) |
| Ceiling | y = +4.0 m above the pond centre | Water surface seen from below, fades into fog with distance | |

**Scenery fish rule (size reading):** a far fish looks small and could be mistaken for food. Scenery schools therefore sit at least 7 m behind the plane (>= 30% fog), never carry rings, are always a school (a shimmering mass, never a lone fish), and no scenery fish may appear longer than 60 px on screen.

## 3. Worlds

World names and mechanics are game-designer's (GDD 6.2); settings, light and palettes are mine. Every world keeps the same camera, HUD, rings and player. Only the environment, fog ramp, sun and species change.

Shared contrast rules for every world (my bars; sections 5 and 9 have the numbers):
1. The player's lit flank keeps **>= 3:1** against the water behind the play plane ("play water" token below). If a world's water is brighter, darken that world's fog, never wash out the player.
2. Ring strokes: white 4 px over ink 11 px (danger) or ink 3 px (edible bubbles), so one of the two always keeps >= 3:1 on bright and on dark water.
3. No more than 20% of the frame below sRGB luminance 0.01 (crushed black), and the player's lit flank >= 3:1 in dark worlds. This is the Race Riders World 6 lesson (QA 2026-10-07: player at 1.02:1, 62-71% of the frame near black).
4. Caustics move slowly (pattern period >= 2 s) and stay low contrast (floor multiplier <= 1.6, fish <= 1.3), as GDD 9 and rule 38 ask.

| # | World (NO / EN) | Setting and light | Fog top / mid / deep (hex) | Play water | Floor and props | Sun |
|---|---|---|---|---|---|---|
| 1 | **Tareskogen** / Kelp Forest | Norwegian coast, 6-8 m, summer noon. Golden kelp forest with a clear sandy lane, strong slanting shafts, bright rippled ceiling | #338FA1 / #0F546B / #063347 | #2A6875 | Pale coastal sand (Poly Haven `coast_sand_01`), grey granite boulders (`coast_rocks_01`), seagrass tufts, kelp holdfasts on rocks | Warm white #FFF5DB, energy 1.6, 14 degrees off vertical |
| 2 | **Korallrevet** / Coral Reef | Tropical reef, 5 m, clearest water. Coral heads (brain, table, branching) left and right, white coral sand, sea fans | #3AAFC2 / #13809A / #08506C | **#1A6E88** (darkened: the reef's natural turquoise put the gold player at 2.32:1, my calc) | White-cream sand, coral rubble, sea fans in the far layer. Coral colour variety is game content (purple allowed here) | Neutral white #FFFFFF, energy 1.8 |
| 3 | **Manetbukta** / Jellyfish Bay | Open blue bay over a deep sand slope, 10 m. Few props, big blue space, long shafts; jellies glow softly by transmission | #3A8ED0 / #1D5FA0 / #0C2F63 | #2563A6 | Sand slope dropping away to the right, a few rock outcrops, sea grass meadow on the left | Cool white #F2F8FF, energy 1.4 |
| 4 | **Vrakdypet** / Shipwreck Deep | A sunk wooden ship on sand at 18 m, dim green-teal, weaker shafts; warm light only from the open hatch and portholes (the eel holes) | #3E7A6E / #1E4A46 / #0E2A2A | #1F4844 | Wreck hull and mast lying across the far layer (Poly Haven candidates in CREDITS.md), barrels, the treasure chest for L20, rust and wood ambientCG textures | Green-white #E6F2DC, energy 0.9; one warm OmniLight in the hatch (Høy only) |
| 5 | **Strømfjorden** / Current Fjord | Cold fjord wall, 12 m: dark granite cliffs left and right with anemones and dead-man's-fingers, silt in the water, pale overcast shafts | #4C8C96 / #24515C / #10303A | #26525C | Rock wall cards in two depths, boulder scree, white anemone clusters (static meshes), silt particles drifting with the current bands | Overcast white #EAF2F2, energy 1.1 |
| 6 | **Dyphavet** / Deep Sea | 600 m, no sunlight. Near-black navy water, blue-violet bioluminescent specks and siphonophore strands far behind, glowing lures | #0B1E33 / #061220 / #02070F | #071526 | Silt floor, a few basalt rocks and white tube-worm patches catching the rim light | **No sun.** A cool key "camera lamp" from upper front (#CFE6FF, energy 0.9) plus a fish rim light (section 10) so every fish keeps its outline (GDD 6.2) |

60/30/10 per world: about 60% water and fog, 30% floor, kelp, coral, rock or wreck, 10% fish and the white rings. The player's gold is the only saturated warm yellow in every world; no prop, coral or light uses #F5C000-like gold at full saturation.

### Dark and dim worlds: contrast numbers (my calc, token values; verify on the first capture of each world)

| Pair | W4 Vrakdypet | W5 Strømfjorden | W6 Dyphavet | Bar |
|---|---|---|---|---|
| Player lit flank target vs play water | #B9B48A on #1F4844: 4.81:1 | #C2C2A6 on #26525C: 4.73:1 | #A9A88C on #071526: 7.57:1 | 3.0 |
| Minimum fish luminance (any species, lit side) for 3:1 | L >= 0.260 (for example #8A9AA6) | | L >= 0.122 (for example #6C7A84, 4.16:1) | 3.0 |
| White ring stroke vs play water | 10.15:1 | 8.59:1 | 18.35:1 | 3.0 |
| Ink ring stroke vs the brightest spot (shaft or lamp) | 4.71:1 | 7.32:1 | 1.35:1, white carries it (13.21:1) | one stroke >= 3.0 |
| HUD edge #E2F0EE vs water behind the HUD | 4.26:1 | 3.26:1 | 14.37:1 | 3.0 |
| Home disc: white vs water / ink ring vs water | 4.98 / 3.58 | 3.82 / 4.67 | 16.83 / 1.06 | one edge >= 3.0 |

In World 6 the dark species (dragonfish, rattail) are naturally near black; the fish rim light (`rim` 0.6, `rim_tint` 0.3) plus a 0.15 emission on photophore dots lifts every species above L 0.122 on its lit side. Never solve World 6 by brightening the water: the deep sea must stay dark, the fish must glow and catch light.

## 4. The player fish

**Species: golden trevally (*Gnathanodon speciosus*), juvenile colouring.** This answers GDD open question 7: the player keeps one species at every tier.

- **Look:** bright metallic gold body with a silver belly, **five narrow black vertical bars** (bar width about 4% of length), black-tipped forked tail, gold fins, yellow iris. Deep, laterally compressed body, pointed snout, very thin tail stock, long sickle-shaped tail lobes.
- **Why this fish:** it is a real reef-and-coast hunter that schools with bigger fish and grows large, so "small to big" is true to the animal. Gold is the hue that separates best from blue-green water in every world, and the bars are a shape cue: **no other fish in the game has vertical bars** (rule for every species in section 4a). Not orange-red like the original's player, not a famous film fish (no clownfish, no blue tang).
- **Growth:** tiers 2-10 (GDD), same model scaled to the tier length (72-664 px). From tier 6 the body gets 5% deeper and the bars 15% fainter (an adult trevally fades toward silver-gold), never gone.
- **Readability:** material `rim` 0.5 with `rim_tint` 0.6 (warm sun-catch #FFE7A0). In the mock (rim strength 2.5 on a linear facing ramp, the Cycles stand-in) the lit flank reads 3.05:1 against the play water (my calc, section 9). Eyes: real eye with gold iris, not a cartoon eye; when an edible fish is near, the mouth opens (GDD 4.3 cue 2) by a jaw hinge in the vertex shader; when a danger fish is near, the eye whites show a little more (pupil scale 0.8).
- **Gill trail:** a thin column of 6-10 rim-lit bubbles rises from the gill every 1.5 s while swimming (one small emitter shared with eat bubbles), which also helps a child find "me".

## 4a. Fish roster and how size reads at a glance

Tier lengths are the GDD's (4.2): 72 x 1.28^(t-1) px = **72, 92, 118, 151, 193, 247, 317, 405, 519, 664 px**, nose to tail, on the play plane (0.24 m to 2.24 m at 296.3 px per m). One species per tier per world (GDD 4.5).

Species rules: real animals with real proportions and colours; **no vertical bars** (the player's mark); no plain saturated gold; no eel shape in World 4 (the Ål hazard owns it); no angler shape in World 6 (Breiflabb owns it); no small glowing swarm (Lysfisk owns it); no fish with exposed gore or scary teeth in the idle pose. Draft lists below; game-designer may swap species, the rules stay.

| Tier (px) | W1 Tareskogen | W2 Korallrevet | W3 Manetbukta | W4 Vrakdypet | W5 Strømfjorden | W6 Dyphavet |
|---|---|---|---|---|---|---|
| 1 (72) | Brisling (sprat) | Grønn kromis (green chromis) | Ansjos (anchovy) | Kutling (goby) | Krill | Dypvannsreke (red deep shrimp) |
| 2 (92) | Grønngylt (corkwing wrasse) | Gul-lilla gramma (royal gramma) | Sardin | Sølvtorsk (poor cod) | Sild (herring) | Sølvøksfisk (hatchetfish) |
| 3 (118) | Sei (saithe, young) | Trådsommerfuglfisk (threadfin butterflyfish) | Taggmakrell (horse mackerel) | Knurr (red gurnard) | Lodde (capelin) | Laksesild (pearlside) |
| 4 (151) | Berggylt (ballan wrasse) | Papegøyefisk, ung (parrotfish) | Makrell (mackerel) | Hyse (haddock) | Hyse (haddock) | Dragefisk (scaly dragonfish) |
| 5 (193) | Lyr (pollack) | Rød snapper | Havbrasme (Ray's bream) | Lysing (hake) | Sei (saithe) | Skolest (rattail) |
| 6 (247) | Torsk (cod) | Korallabbor (coral grouper) | Havabbor (sea bass) | Torsk (cod) | Torsk (cod) | Vassild (argentine) |
| 7 (317) | Havabbor (sea bass) | Napoleonfisk, ung (humphead wrasse) | Dorado (mahi-mahi) | Uer (redfish) | Laks (salmon) | Svarthå (velvet-belly lantern shark, small) |
| 8 (405) | Laks (salmon) | Barrakuda | Tunfisk (bluefin) | Brosme (tusk) | Blåkveite (Greenland halibut) | Isgalt (roundnose grenadier) |
| 9 (519) | Kveite (halibut) | Kjempeabbor (goliath grouper) | Sverdfisk (swordfish) | Kveite (halibut) | Kveite (halibut) | Sildekonge (oarfish) |
| 10 (664) | (not reached in W1) | (not reached in W2) | Klumpfisk (ocean sunfish) | Stor kveite | Brugde (basking shark) | Håkjerring (Greenland shark) |

Highest tier that can appear: W1 7 (goal 5 + 2), W2 9, W3-W6 10.

**Body families (10 meshes for 60 species):** each species is one of 10 base meshes with its own proportions baked into a mesh variant and its own 1024x512 block in the world's fish atlas (section 4b): (1) shrimp/krill, (2) slim schooling (sprat, anchovy, herring, chromis), (3) deep oval reef (gramma, butterflyfish, wrasse), (4) wrasse/perch heavy (berggylt, grouper, sea bass), (5) gadoid (cod, saithe, pollack, haddock, hake, tusk), (6) fast fusiform (mackerel, tuna, dorado, bream), (7) flatfish (halibut), (8) elongate (barracuda, swordfish, oarfish, rattail), (9) big oddities (sunfish, basking shark, Greenland shark, napoleon), (10) deep-sea slender (dragonfish, hatchetfish, pearlside).

**How size reads at a glance (all at once, never colour alone):**
1. **One plane, fixed camera:** on-screen length = tier, no perspective drift (section 2).
2. **28% steps** (GDD): neighbours differ clearly side by side.
3. **One species per tier:** after a few levels "the striped-tail ones are my size" is learned by shape and pattern.
4. **Rings** (section 5): edible = smooth bubble ring, danger = 8-point zigzag, same tier = none.
5. **HUD row** draws the player at every tier from 2 to the goal at true relative size (section 6).
6. **Mouth and eyes** (GDD 4.3): player's mouth opens toward food; danger fish open mouths and flare fins near the player.
7. **Scenery fish never look like food** (section 2 rule).

## 4b. World 1 fish models (built 2026-10-10)

Files, tiers and triangle counts: `assets/models/fish/README.md`. Generated by `docs/mockups/src/fish_*.py`, own work.

| Item | Spec |
|---|---|
| Size and axes | 1.0 m nose to tail, nose +X at x = +0.42, up +Y, left flank +Z; scale by tier length |
| Triangles | 1,120-1,188 below tier 6; player 2,870, cod 2,947, sea bass 2,846 (budget 1,200 / 3,000) |
| Anatomy | Body lofted from a real side profile (pchip, no bumps) with a fuller-flank superellipse section; fins are ray-aligned quad grids whose outline, notches and ray tips come from the alpha; domed cornea per eye; cod chin barbel; trevally lateral scutes in the normal map |
| Surfaces | `fish_w1_body` opaque, back-face culled; `fish_w1_fins` alpha blend (Godot: depth-prepass alpha), double sided, backlight through the membrane. 2 draw calls per species |
| Atlas | One 2048 set shared by all 8 GLBs by relative URI: `fish_w1_albedo` (RGBA), `fish_w1_normal` (OpenGL), `fish_w1_orm` (R occlusion, G roughness, B metallic). 1024x512 block per species: body side view on top (both flanks share it), fins, eye and barbel packed below |
| Masks | COLOR_0: R jaw, G fin flare, B swim weight. Vertex shader in the README, same instance uniforms as `rb_fish.gdshader` |
| Import sizes | Albedo 2048 (the player is seen at about 650 px on the win card); normal and ORM `process/size_limit` 1024 |

Do: keep the player's 5 bars and black caudal tips; keep fins translucent. Don't: embed the atlas in each GLB (8 copies), add bars to any other species, or brighten the water to help the player stand out (raise `rim_k` instead).

## 5. Edible and danger cues (GDD 4.3, visual spec)

All rings use only white and ink, never a hue, so they work in greyscale (`world1_grey.png`) and for colour-blind children (rule 36). They are drawn on top of the fish (no depth test) but under the HUD, all rings in **one** MultiMesh of camera-facing quads with an SDF shader (1 draw call).

| Cue | Shape | Size (L = fish length px) | Stroke | Motion |
|---|---|---|---|---|
| **Edible** (lower tier) | Smooth ellipse of **12 small glass bubbles** | Radius 0.62 L + 16 px, ellipse 1.0 x 0.82; bubbles 14-18 px diameter | Each bubble: white 3 px rim, white 27% fill, a white highlight dot, ink 3 px outer ring at 50% | Circles slowly (0.25 rev/s); each bubble bobs 2 px |
| **Danger** (higher tier) | **8-point zigzag star** | Outer radius 0.70 L + 30 px, inner 0.56 L + 14 px, ellipse 1.0 x 0.80 | Ink 11 px at 63% under white 4 px | Pulses in **scale** 1.00-1.06 at 1 Hz, never in brightness (no flash, rule 37) |
| **Same tier** | No ring | | | |
| Morph after a grow | Zigzag points retract into bubbles over 0.25 s | | | "Mindre bevegelse": instant swap |
| Lett / Vanlig | Lett: rings on every fish all the time. Vanlig: fade in within 420 px of the player, out beyond 480 px (GDD) | | | |
| **Aim ring** (GDD 3.3) | Plain circle, 64 px | | White 4 px over ink 8 px at 43% | Fades in 60 ms, out 300 ms |

Ring centre = the fish's body centre, which sits about 0.08 L behind the model origin toward the tail (`overlay.py` uses this offset). Rings may overlap the wrist strip; they are not tappable.

Danger body language (on the model, not the ring): within 300 px the danger fish's jaw opens 25 degrees and its dorsal and pectoral fins spread (vertex shader, per-instance flag in `INSTANCE_CUSTOM.w`). Teeth are only those the real species has (pollack and cod show none); no added fangs.

## 6. HUD (GDD 8.2; x 256-1044, y 40-224, not tappable, no text)

| Element | Spec |
|---|---|
| Home disc (stand-alone only; the shell owns it in MWM Play) | Diameter 136, centre (104, 104), white with 5 px ink ring, ink house 68 px; hit area 0,0 to 216,216 (shell spec) |
| Panel | Rounded rect x 256-1044, y 52-204, radius 76, `hud_glass` at alpha 0.78, 4 px `hud_edge` outline |
| **Vokse row** | One player silhouette per tier from 2 to the goal tier, drawn at relative size (x1.28 per tier), goal silhouette 150 px long, gaps 34 px, centred in the panel |
| Reached tier | White fill, ink 4 px outline, ink eye |
| Current tier | `hud_glass` fill with `hud_edge` outline; **gold fills from the tail to the nose** as food comes in (200 ms ease); ink outline drawn over the fill |
| Future tiers | `hud_glass` fill, `hud_edge` 4 px outline (hollow) |
| Goal | Gold star (radius 28) with 5 px ink outline at the goal silhouette's top-right |
| Grow moment | The current silhouette's fill completes, it turns white with a 300 ms shimmer, the next one starts (no flash) |
| Perler / Glitter | N slots in the panel: pearl = white circle with a highlight, empty = `hud_edge` ring; glitter = star-tail fish shape. A small dot row of the current tier under them |
| Vanlig bobler | 3 glass-bubble icons, 44 px, at x 900-1040, y 160-216 (GDD); in Vanlig the silhouette row centres in x 280-880 |
| Uendelig | Round badge, diameter 150, centre (960, 136): white disc, ink ring, ink digit in Fredoka SemiBold 72 px; the panel shortens to x 256-870 |
| Resume disc | 240 px white disc, ink ring, ink play triangle, scene dimmed 50% |

Silhouette = the player species' side outline (deep body, forked tail, eye dot), the same drawing as on the win card, built once as a vector in `overlay.py` (`fish_icon`) and to be exported as an SVG/PNG atlas for the HUD.

## 7. Win card (GDD 8.4)

| Element | Spec |
|---|---|
| Backdrop | Scene blurred (radius 14 px equivalent) and dimmed with #04141A at 47% |
| Card | x 100-980, y 330-1470, radius 56, `card` fill, 4 px `card_edge` |
| Picture window | x 150-930, y 380-940, radius 36, 5 px ink frame; shows the player at its final tier swimming a slow loop in the world's water: a `SubViewport` 780x560 with the player, the world's fog colour and a blurred floor card (2-3 draw calls) |
| Tier row | The level's silhouettes, all white, goal one gold, centred at y 1040 |
| Star | Gold, radius 62, 8 px ink outline, centre (540, 1160); lands 0.6 -> 1.08 -> 1.0 in 300 ms |
| Discs at y 1340 | Replay (270, dia 200, white, ink circular arrow), map (540, dia 200, white, ink three dots on a path), next (810, dia 240, gold, ink play triangle). Hit areas 240. Pressed: 94% + `green_soft` fill for 100 ms, act on release |

Note for game-designer: GDD 8.4 places the discs at y 1300; the mock draws them at y 1340 so the star clears the row. Either works; 1300 is fine if the star moves to y 1130.

## 8. Palette tokens

### 8a. UI chrome (all worlds; no purple)

| Token | Hex | Godot | Use |
|---|---|---|---|
| ink | #14181C | Color(0.078, 0.094, 0.110) | Outlines, icons, ring under-strokes, disc rings |
| white | #FFFFFF | Color(1.000, 1.000, 1.000) | Ring strokes, home disc, reached silhouettes, white discs |
| gold | #F5C000 | Color(0.961, 0.753, 0.000) | Player colour in UI: current-tier fill, goal star, next disc, final silhouette |
| hud_glass | #08262E | Color(0.031, 0.149, 0.180) | HUD panel at alpha 0.78, hollow silhouettes |
| hud_edge | #E2F0EE | Color(0.886, 0.941, 0.933) | HUD outline, future-tier outlines |
| card | #F4F8F6 | Color(0.957, 0.973, 0.965) | Win card, settings panel (light, house rule) |
| card_edge | #5E7F86 | Color(0.369, 0.498, 0.525) | Card outline |
| green_soft | #E3F0EA | Color(0.890, 0.941, 0.918) | Pressed state of white discs (shell token) |

### 8b. Game elements

| Token | Hex | Godot | Use |
|---|---|---|---|
| player_gold (albedo flank) | #F0B800 | Color(0.941, 0.722, 0.000) | Trevally flank albedo (renders lighter under sun and rim) |
| player_back | #8A6400 | Color(0.541, 0.392, 0.000) | Trevally back |
| player_belly | #F3ECC8 | Color(0.953, 0.925, 0.784) | Belly |
| bar_ink | #221D10 | Color(0.133, 0.114, 0.063) | Bars and tail tips |
| player_rim | #FFE7A0 | Color(1.000, 0.906, 0.627) | `rim_tint` source for the sun-catch rim |
| kelp_dark / kelp_light | #5E3F12 / #B88F36 | Color(0.369, 0.247, 0.071) / Color(0.722, 0.561, 0.212) | Kelp albedo ramp (world 1), translucency #D9B44A |
| seagrass | #5F7D2A | Color(0.373, 0.490, 0.165) | Floor blades (world 1) |
| bubble | #FFFFFF rim, fill alpha 0 | | Fresnel rim, additive |

### 8c. World fog and water (Godot `Environment.fog_light_color` = mid at the play plane; height ramp top to deep)

| World | Top | Mid | Deep | Play water (sampled or target) |
|---|---|---|---|---|
| 1 | #338FA1 Color(0.200, 0.561, 0.631) | #0F546B Color(0.059, 0.329, 0.420) | #063347 Color(0.024, 0.200, 0.278) | #2A6875 Color(0.165, 0.408, 0.459) |
| 2 | #3AAFC2 Color(0.227, 0.686, 0.761) | #13809A Color(0.075, 0.502, 0.604) | #08506C Color(0.031, 0.314, 0.424) | #1A6E88 Color(0.102, 0.431, 0.533) |
| 3 | #3A8ED0 Color(0.227, 0.557, 0.816) | #1D5FA0 Color(0.114, 0.373, 0.627) | #0C2F63 Color(0.047, 0.184, 0.388) | #2563A6 Color(0.145, 0.388, 0.651) |
| 4 | #3E7A6E Color(0.243, 0.478, 0.431) | #1E4A46 Color(0.118, 0.290, 0.275) | #0E2A2A Color(0.055, 0.165, 0.165) | #1F4844 Color(0.122, 0.282, 0.267) |
| 5 | #4C8C96 Color(0.298, 0.549, 0.588) | #24515C Color(0.141, 0.318, 0.361) | #10303A Color(0.063, 0.188, 0.227) | #26525C Color(0.149, 0.322, 0.361) |
| 6 | #0B1E33 Color(0.043, 0.118, 0.200) | #061220 Color(0.024, 0.071, 0.125) | #02070F Color(0.008, 0.027, 0.059) | #071526 Color(0.027, 0.082, 0.149) |

## 9. Contrast (my calc, WCAG 2.x)

Sampled from the rendered World 1 mock by `overlay.py` (pixel means; ring rows use the brightest water behind any ring of that kind):

| Pair | Colours | Ratio | Bar |
|---|---|---|---|
| Player lit flank (top 40% luminance) vs water around it | #C0C19E on #277084 | **3.05:1** | 3.0 |
| Player body mean (incl. bars and shade) vs water | #A7A77E on #277084 | 2.28:1 | info: the bars are meant to be dark |
| Player bars vs gold flank (internal pattern) | #6E785A on #C0C19E | 2.51:1 | pattern cue, not a boundary |
| Edible bubble rim white vs the brightest water behind any edible ring | #FFFFFF on #58929B | 3.50:1 | 3.0 |
| Danger ring white vs water behind it | #FFFFFF on #295A66 | 7.66:1 | 3.0 |
| Danger ring ink stroke vs that water | #1C3138 on #295A66 | 1.77:1 | white carries it here; ink carries it in shafts |
| Danger fish body vs water around it | #596A4F on #5C7169 | 1.11:1 | info: realistic olive fish blend in; the ring is the cue |
| HUD panel vs water just below it | #21434B on #73AAB2 | 4.13:1 | 3.0 (the panel fill is the boundary) |
| HUD edge vs water behind the panel | #E2F0EE on #96BEC3 | 1.72:1 | decorative; boundary given by the fill above |
| Gold current-tier fill vs HUD panel | #F5C000 on #21434B | 6.31:1 | 3.0 |
| White reached silhouette vs HUD panel | #FFFFFF on #21434B | 10.66:1 | 3.0 |
| Hollow future silhouette outline vs HUD panel | #E2F0EE on #21434B | 9.11:1 | 3.0 |
| Ink outline vs gold fill | #14181C on #F5C000 | 10.55:1 | 3.0 |
| Home disc ink ring vs water top-left | #14181C on #7BAFB6 | 7.33:1 | 3.0 (white disc alone is 2.43:1, so the ring is required) |
| Ink icons and rings vs white | #14181C on #FFFFFF | 17.84:1 | 4.5 |
| Ink on gold (next disc, star) | #14181C on #F5C000 | 10.55:1 | 4.5 |
| Card edge vs card | #5E7F86 on #F4F8F6 | 4.04:1 | 3.0 |
| Card vs dimmed scene | #F4F8F6 on #354F50 | 8.22:1 | 3.0 |

Worlds 2-6 are in section 3 (token calc, to be re-measured on captures).

Flash: nothing in the HUD or rings changes brightness faster than 3 times per second; the danger pulse is a 6% scale change at 1 Hz. Bursts (eat, grow, pearl) go through the GDD's global limiter.

## 10. Lighting, materials and shaders (Godot 4.6.2, `mobile` renderer)

Available on Mobile and used: DirectionalLight3D, sky/ambient colour, depth and height fog, tonemap, glow, MSAA/FXAA, GPU particles, MultiMesh. **Not available on Mobile, do not fake with extra passes:** SSAO, SSIL, SSR, SDFGI, VoxelGI, volumetric fog.

| Item | Høy (default) | Lav (32-bit tablet) |
|---|---|---|
| Sun / key | One `DirectionalLight3D` per world (section 3), **no shadow maps** (GDD 11); fish shadows are soft blob quads on the floor (one MultiMesh, scaled and faded by the fish's height above the floor) | Same, blob shadows only for the player and danger fish |
| Ambient | `ambient_light_source` Color, colour = world mid fog x 1.6, energy 0.9 | Same |
| Fog | `fog_mode` Depth, `fog_light_color` = play water, `fog_depth_begin` 10 m, `fog_depth_end` 34 m, curve 0.8, `fog_sky_affect` 1.0; height fog on (`fog_height` -2.5 m, density 0.15) so the floor side is darker | Same (cheap per pixel) |
| Background | `background_mode` Color = world deep; a large unshaded gradient quad behind everything (top -> deep) | Same |
| **Caustics** | One shared shader include: two scrolling samples of a 512x512 tileable caustic texture (own bake from the Blender voronoi in `world1_mock.py`), `min()` blended, projected on world XZ; multiplier on floor, rocks and kelp <= 1.6, on fish top-facing normals <= 1.3; period >= 2 s | Floor only; one sample |
| **God rays** | <= 4 additive camera-facing cards (GDD), each a 1024x256 texture holding 3-5 shafts, top-to-bottom fade, slow sway +-2 degrees over 8 s. One mesh for all cards (1 draw call) | 2 cards |
| **Water surface** | One quad seen from below, built on `stylized_water.gdshader` adapted to realistic values: `cull_front`, deep = world top fog, highlight #FFFFFF at 60%, `edge_threshold` 0.05, `horizon_mix` 0.85 toward the fog, sparkles off, ripples off; depth foam **off** (the `WATER_DEPTH_FOAM` define forces a depth copy per frame on Mobile) | Same |
| **Kelp** | MultiMesh of the giant-kelp GLBs in `assets/models/kelp/` (stipe + 22-32 folded blade strips with gas bladders, 422-602 tris near, 168 tris far; outline from alpha scissor, sway shader in the kelp README) or `stylized_grass.gdshader` adapted: wind becomes a slow current sway (strength 0.06, speed 0.4, lean 0.3, direction +X), base-to-tip ramp `kelp_dark` -> `kelp_light`, back-lit translucency on (the gold glow in the mock), flattened lighting normal off. Two MultiMesh chunks: near (z -1 to -10) and far (z -10 to -30, 2-plane cards beyond 15 m) | Near chunk 60% (`kelp_giant_c` only), far as cards only |
| On-plane kelp patch (Tare friend) | Same frond mesh at full contrast, rooted on a rock, denser (8 strands per patch); "safe" leaf shimmer = 300 ms brightness ramp along the blades | Same |
| Seagrass / floor detail | `seagrass_tuft.glb` (9 eelgrass blades, 90 tris) in MultiMesh, plus `kelp_sugar.glb` clumps (312 tris) off the play lane; same `kelp_w1` material | 40% of the blades, or off under 50 fps |
| Floor | Heightmapped strip (gentle dunes) with Poly Haven/ambientCG albedo, normal and roughness (1024, ETC2) + caustics + depth tint (floor albedo x mix toward deep fog by distance) | Same textures |
| **Fish** | One spatial shader per world for all species: albedo, normal and ORM from the world fish atlas (each GLB's UVs already point at its own block, no tile index), roughness and metallic per texel from the ORM (0.20-0.42 roughness, metallic 0.04-0.75), `specular` 0.6, fresnel hue shift for the silver iridescence (cheap stand-in for Blender's thin film), caustics on top-facing normals, `rim` per section 4 | Same shader, normal map off |
| Fish swim | Vertex shader: lateral sine bend along the body (amplitude rising toward the tail, 2-4 Hz by tier), per-instance phase and speed (instance uniforms `phase`, `swim_hz`); jaw open and fin flare from the COLOR_0 masks (R jaw, G flare, B swim weight) scaled by `mouth` and `flare`. No skeletons (GDD 11). Code in `assets/models/fish/README.md` | Same |
| Turn | Rotate 180 degrees around Y over 120 ms (shows the other side; atlas tiles are symmetric), never a negative scale (it flips normals) | Same |
| Bubbles | Additive fresnel rim on a sphere impostor quad, white | Same |
| Particles | Pool of <= 4 GPUParticles3D emitters, <= 400 particles (GDD): marine snow 150, eat bubbles 6-10, grow ring 24, burp bubble trail 12; CPUParticles3D on the Compatibility fallback | Marine snow 60 |
| Glow | On, threshold 1.2, intensity 0.35, levels 3-4: lures, photophores and the surface only | Off |
| Tonemap | AgX if the builder's capture looks harsher than the mock (the mock used Blender AgX Medium High Contrast), else ACES; exposure per world from the capture | Same |
| Anti-aliasing | MSAA 2x | FXAA, `scaling_3d_scale` 0.8 below 60 fps |
| "Mindre bevegelse" | God rays static, caustics frozen, marine snow off, kelp sway amplitude x0.5, intro zoom and clear push-in off | Same |

### 10a. Studio techniques reused (Wayfarer art pass, 2026-10-10)

| Wayfarer technique | Here |
|---|---|
| Water tinted by depth (turquoise shallows to dark deep) | Fog colour ramp by height (top/mid/deep per world) and the floor tinted toward deep fog with distance |
| Shore / surface foam | Underwater there is no shore: the matching effect is the bright rippled ceiling (adapted `stylized_water`) and rim-lit bubble trails. Depth-intersection foam stays off (depth copy cost on Mobile) |
| Dense instanced vegetation | Kelp and seagrass as MultiMesh with the adapted `stylized_grass` shader (current sway, translucency, realistic palette) |
| Real terrain from Kartverket (DTM CC BY 4.0) and seabed soundings | **Not worth it here.** The camera looks sideways at a 3.6 m wide pond; the floor is a strip in the wrist band that fades into fog within 30 m, so a real depth model would show up as a few centimetres of profile. One optional use: World 5's far fjord walls could take their silhouette from a real Norwegian fjord DTM (CC BY 4.0, credit "© Kartverket"). Low value, skip unless the owner wants it |
| Colour grade with `fit_lut.py` | Section 10b |

### 10b. Colour grade (LUT)

Order from the studio rules: first fix light and materials until `tools/refmatch/compare.py <capture> --reference <mood.png>` stops rising, then bake a grade: `python3 ~/MWM/projects/game-studio/tools/refmatch/fit_lut.py <capture.png> --reference <mood.png> --out assets/luts/w1_grade.cube --preview <out.png>`. Mood image per world: the owner-approved mock frame (`w1_raw.png` for World 1) or a licence-clean reference the owner supplies. In Godot: `Environment.adjustment_enabled` + `adjustment_color_correction` (a 3D LUT texture). **Applying the LUT on Android is untested** (studio note): check it on the phone and on the 32-bit tablet before relying on it; if it fails, the world palette without a grade must already pass section 9.

## 11. Phone budget

Ceilings proven in Race Riders (DESIGN 12, QA 2026-10-07) and the GDD 11 limits, whichever is tighter. Numbers are my calc for a busy World 1 frame (14 fish + 3 hazards + 2 friends); the device PerfOverlay decides.

| Item | Høy ceiling | Høy estimate | Lav ceiling | Lav estimate |
|---|---|---|---|---|
| Draw calls | **80** | about 48: background quad 1, floor 2, rocks MultiMesh 2, kelp near/far 2, seagrass 1, on-plane kelp 1, surface 1, ray cards 1, scenery schools 2, gameplay fish 7 species + player 1, 2 surfaces each = 16 (MultiMesh or instancing per species), blob shadows 1, rings 1, hazards and friends 4, pickups 2, particles 4, HUD 3, home 1, spare 4 | **60** | about 32 (ray cards 1, schools 1, fewer particles) |
| Visible triangles | **120k** (GDD), hard ceiling 200k (Race Riders) | about 120k: fish 14 x 1.2k + 4 x 3k = 29k, player 3k, kelp near 40 x 510 = 20k + far 120 x 168 = 20k, seagrass 200 tufts x 90 = 18k, rocks 6k, floor 8k, schools 240 x 40 = 10k, hazards and friends 6k (at the ceiling: cut far kelp first) | **90k** | about 60k: kelp near 24 x 422 = 10k + far 60 x 168 = 10k, seagrass 80 tufts x 90 = 7k, schools 60 x 40 = 2k, fish 29k, rest 5k |
| Fish per mesh | <= 1,200 tris below tier 6, <= 3,000 from tier 6 (GDD); player 3,000 at every tier (hero) | | Same meshes | |
| Gameplay actors | <= 22 (GDD) | | Same | |
| Scenery schools | 2 schools x 120 fish (MultiMesh, 40-tri fish, vertex swim) | | 1 x 60 | |
| Textures | Max 2048 px; ETC2/ASTC with mipmaps; per world: fish atlas set (albedo 2048, normal and ORM 1024 via import size limit) about 7.7 MB, kelp set at 1024 about 3.5 MB (my calc); environment 1024 sets | | Same files, mipmap bias +1 | |
| Texture memory | <= 150 MB (GDD, Race Riders) | about 40 MB in a level | | |
| Lights | 1 directional, no shadow maps (+1 omni in World 4 hatch) | | 1 directional | |
| Transparency | Ray cards, surface, rings, bubbles, particles; kelp and seagrass are alpha scissor (opaque pipeline) | | Same | |

### 11a. APK size plan

- **Race Riders lesson (QA 2026-10-07, measured):** the APK was 294.6 MB: native libs 145 MB stored uncompressed (both ABIs, `compress_native_libraries=false` at that build), textures 60.3 MB, a 92.6-minute music file 43.2 MB, landscapes 39.2 MB. Its export preset now has `compress_native_libraries=true`; the brief cites about 219 MB after that, which I did not measure.
- **This game:** GDD 11 gives the game's own content <= 60 MB. Plan (my calc, ETC2 sizes with mips): fish atlases 6 x 2.7 MB = 16 MB (now measured against the world-1 set: 7.7 MB fish + 3.5 MB kelp per world, my calc, so 6 worlds would be about 67 MB of the 60 MB: worlds 2-6 should drop the fish albedo to 1024 and keep only the player at 2048, see open item 10); environment 6 worlds x about 3 MB (1024 albedo per world, normal and roughness shared where the material allows) = 18 MB; player, rings, HUD, UI 3 MB; meshes 5 MB; audio <= 10 MB (short loops, no long music file) = **about 52 MB**.
- Export: `compress_native_libraries=true`, `.gdignore` on `docs/` and raw source folders, no raw scans or EXRs in `assets/`. For Google Play, an AAB split per ABI.

## 12. Asset source plan

Only own work or CC0 (MIT shaders, OFL fonts). Every file copied in gets a row in `CREDITS.md` the same day.

| Asset | Source | Notes |
|---|---|---|
| **Fish (60 species, 10 families) and the player** | **Own work.** World 1 (player + 7 species) done 2026-10-10 by the generator in `docs/mockups/src/fish_*.py` (section 4b). Worlds 2-6: add species to `fish_species.py` and rerun. Next quality step: sculpt the player head in Blender (gill cover, lips, eye socket, cheek scales) and bake it into the player block | Smithsonian 3D open access refused scripted access (HTTP 403) and the CC BY / BY-NC fish scans are excluded by the CC0 rule (CREDITS.md). Specimen scans would need a full repaint anyway |
| Kelp, seagrass, anemones, coral | Own Blender meshes + own painted atlas: world 1 kelp, sugar kelp and eelgrass done (`assets/models/kelp/`, `kelp_*.py`); anemones and coral later, ambientCG/Poly Haven CC0 where a scan helps | |
| Sand, rock, wood, rust textures | Poly Haven, ambientCG (CC0, licences checked 2026-10-10) | World 1 uses `coast_sand_01` and `coast_rocks_01` in the mock |
| Wreck and props (World 4) | Poly Haven CC0 models (`ship_pinnace`, `dutch_ship_medium`, `treasure_chest`, barrels): sink them with a damage and growth pass in Blender | Candidates only |
| Caustic texture, ray cards, bubble sprites, HUD silhouettes | Own (Blender bakes, `overlay.py` vectors) | |
| Shaders | `projects/game-studio/templates/shaders/` (MIT, Cortiz): keep headers, copy the licence file | |
| Fonts | None for the child. Fredoka (OFL) for stand-alone adult settings, copied with its licence | |
| Not used | Kenney and Poly Pizza (toy low-poly style; Poly Pizza licences differ per model); anything from `projects/fishy/` | |

## 13. Typography

The child reads nothing (GDD): no text in play, map, HUD or win card. Only the Uendelig round digit (Fredoka SemiBold 72 px, ink on white) and the adult stand-alone settings and credits (Fredoka, body 40 px, headings 56 px, ink on `card`). Store art may use a display face later (OFL only), never in the game UI.

## 14. Four questions before any visual feature

| Feature | Noticed at camera distance? | Phone cost | Cheaper trick | Fits spec? | Verdict |
|---|---|---|---|---|---|
| PBR fish with caustics and rim | Yes: fish are the focus and the size cue | 1 draw per species, atlas read | Unlit sprites lose the light response that sells realism | Yes | Keep |
| Kelp forest MultiMesh with translucency | Yes: it is the World 1 identity and gives depth | 2 draws, about 40k tris | Far rows as 2-plane cards (already in) | Yes | Keep |
| Caustics on floor and fish | Yes, the strongest "underwater" signal | 2 texture reads on those pixels | Floor only on Lav | Yes | Keep |
| God rays | Yes | 1 draw, additive overdraw on 4 cards | Fewer cards on Lav | Yes | Keep, <= 4 cards |
| Real-time shadow maps | Barely: a side view sees the floor at a grazing angle | Shadow pass doubles fish draws | Blob shadow quads | No (GDD 11) | Cut |
| Volumetric fog | It would look nice | Not available on Mobile | Depth + height fog and ray cards | No | Cut |
| Depth-intersection foam on the surface | No: the surface is far above the fish | Depth copy every frame | Bright ceiling without foam | No | Cut |
| Scenery schools | Yes, they make the sea feel alive | 2 MultiMesh draws, 10k tris | | Yes, with the size rule in section 2 | Keep |
| Kartverket real seabed | No (section 10a) | Import work | Hand-shaped dune strip | | Skip |
| LUT grade | Yes if lighting is right first | 1 lookup in the tonemap pass | Palette that already passes | Untested on Android | Try after lighting |

## 15. Do and don't

- Do: keep every gameplay fish on the play plane and the camera still.
- Do: keep gold for the player only (fish, HUD fill, star, next disc) and vertical bars for the player only.
- Do: draw rings in white plus ink only, with shapes that work in greyscale.
- Do: darken a world's water before the player drops under 3:1; never brighten the deep sea to fix World 6, light the fish instead.
- Do: show every new world's first Godot capture to the owner before building its levels (hero scene first; World 1 is the hero).
- Don't: cartoon eyes, smiles, pastel fish, outline-drawn fish, skeletons, score numbers, text for the child, the "! FISHY !" lettering, the original's light-blue gradient with a brown dune strip.
- Don't: put kelp, rocks or fish between the camera and the play plane.
- Don't: use purple in the HUD, card or buttons (it is allowed in World 2 coral and World 6 bioluminescence).
- Don't: use real-time shadow maps, volumetric fog, SSR or SSAO on Mobile.
- Don't: share this look with other MWM games or restyle it toward the shell.

## 16. Store assets (later)

- **Icon 512x512:** the gold barred trevally in three-quarter side view, mouth open toward a small silver brisling, on World 1 teal water with one ray of light. Must read at 48 px: one gold fish, one dark eye, the bars.
- **Feature graphic 1024x500:** World 1 kelp lane with god rays, the player at tier 5 centre-left, a danger lyr with its zigzag ring at the right, a school of brisling with bubble rings ahead. Name on the bright upper water once chosen.
- **Screenshots (capture bot only, never this mock):** World 1 L2 (rings visible), World 2 L9 (turtle ride), World 6 L27 (lantern swarm in the dark).

## 17. Visual tier

**Premium realistic 3D** (the studio's premium tier with the owner's 2026-10-06 realism rule: not stylized, not toy). Hero scene: World 1 level 2 as in `world1_mock.png`. The owner signs it off from the builder's real Godot capture before worlds 2-6 are built.

## 18. Open items and things I could not verify

1. **Fish model quality:** world-1 fish are real game meshes now (section 4b), but the win-card close-up still reads clean-CG (smooth head, painted rather than sculpted detail). Owner to judge from `wincard_mock.png`; a player-head sculpt is the next step if it is not enough.
2. **Owner pick needed:** player species (golden trevally, my pick; GDD open question 7).
3. **Species lists** in section 4a are drafts; game-designer may swap any species within the rules.
4. **Worlds 2-6 contrast** numbers are token calculations, not renders; re-measure on the first capture of each world.
5. **LUT on Android** untested (studio note).
6. **Phone performance** unverified: the budget table is arithmetic; the PerfOverlay on the owner's phone and the 32-bit tablet decides (GDD open question 8).
7. **Race Riders "about 219 MB"** APK figure from the brief: not measured by me; the QA report I read says 294.6 MB before native-lib compression.
8. **Smithsonian 3D CC0 fish scans:** tried 2026-10-10; site and API refused scripted access (HTTP 403), so no specimen or licence could be confirmed. Not used.
9. **Blender MCP** was not connected; mocks were rendered with Blender 4.5.1 from the command line instead.
10. **APK size with the new atlases** (my calc): about 11 MB of fish and kelp textures per world. Fine for world 1; over the 60 MB plan if all 6 worlds copy it unchanged.
11. **Fish and kelp shaders in the READMEs are not compile-tested** (no shader compiler in headless Godot here). The GLBs themselves were import-tested in a scratch Godot 4.6.2 project: textures resolve by URI, fins import as depth-prepass alpha, kelp as alpha scissor, COLOR_0 present.
12. **Player readability after the pass:** lit flank 3.05:1 against the play water (my calc), down from 3.59:1, because the model is now exactly tier length (the proxy was 10% longer) and has more dark bar area. Passes the 3:1 bar narrowly with `rim` raised in the mock; check on the first Godot capture.
