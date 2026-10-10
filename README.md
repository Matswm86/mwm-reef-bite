# MWM Reef Bite

An underwater eat-and-grow game for children (ages 4-7 on Lett, 8+ on Vanlig). You steer a small golden fish with one finger through a sunlit kelp forest, eat the fish that are smaller than you, keep away from the bigger ones and grow until you reach the level's goal. A big fish that catches you just burps you out in a bubble, so a small child never loses.

**Download the Android APK:** https://github.com/Matswm86/mwm-reef-bite/releases/download/latest/mwm-reef-bite.apk

- No ads, no tracking, no accounts, no network, no in-app purchases.
- Works offline. Asks for no Android permissions.
- Debug-signed sideload build (built by GitHub Actions on every push to `main`). If Android warns about the source, allow "Install from this source". Uninstall an older build first if the signature changed.

## What is in this build (world 1 vertical slice)

World 1 "Tareskogen" (kelp forest), levels 1-5, in two settings:

| Level | Name | Goal (Lett / Vanlig) | New idea |
|---|---|---|---|
| 1 | Første munnfull | grow to size 3 / 4 | steer and eat, onboarding hand |
| 2 | Større fisker | grow to 4 / 5 | bigger fish and the danger cues |
| 3 | Bobla | grow to 4 / 5 | bubble shield power-up |
| 4 | Gjemmeleken | 4 / 6 pearls | kelp hiding places, pearl goal |
| 5 | Solstriper | grow to 4 / 5 | calm breather level |

How it plays:
- **Follow the finger:** hold a finger where you want to swim; the fish swims to a point a little above the fingertip. A tap works too.
- **Size tiers:** every fish has a size 1-10. Smaller fish are food, bigger fish are danger, same-size fish just bump.
- **Four "can I eat it?" cues, none of them colour:** the size itself, your fish's mouth opens when food is in front of it, a smooth bubble ring around food and a spiky zigzag ring around danger, and danger fish open their mouths when close.
- **Gentle catch:** Lett costs nothing (burped out in a bubble). Vanlig empties the current size meter; world 1 has unlimited bubbles, so there is never a restart here.
- No text for the child, no score, no timer, no game over. One star per cleared level.
- Settings (gear on the map, stand-alone only): Lett / Vanlig, sound and music with volume sliders, "Mindre bevegelse" (less motion).

Inside the MWM Play family app the game runs in shell mode: the app's home button replaces the game's own, levels 1-3 are free and the full game is unlocked by the app.

## For developers

Godot 4.6.2, GDScript with static types, `mobile` renderer, portrait 1080x1920. All gameplay fish sit on one plane under a fixed perspective camera, so the size on screen is the size tier. Rules: `docs/GDD.md`; look: `docs/DESIGN.md`; every tunable number: `scripts/RbBalance.gd`.

| Path | What |
|---|---|
| `scripts/RbSim.gd` | Pure game logic (no nodes): steering, eat / catch / bump, spawning, gentle catch, pearls, Bobla, kelp |
| `scripts/RbPlay.gd` | Touch input, drives the logic, fish views, rings, HUD, hand, sounds, win card |
| `scripts/RbWorld.gd` | The 3D kelp forest: camera, light, fog, floor, kelp MultiMesh, rays, surface, schools |
| `scripts/RbFishCatalog.gd` | Fish model name table: sculpted GLBs drop in by file name, else a procedural proxy |
| `scripts/RbState.gd` | Autoload `RbGame`: save file `user://reef_bite_save.json`, settings, MWM Play hooks and signals |
| `tools/render_sfx.py`, `tools/render_music.py` | Own-synthesis sound effects and the calm music loop |
| `tools/make_textures.py` | Caustic texture and app icon |

**Fish models.** Put a GLB at `assets/models/fish/<name>.glb` with a name from `RbFishCatalog.SPECIES` (player `golden_trevally`, tiers 1-10 `brisling`, `gronngylt`, `sei`, `berggylt`, `lyr`, `torsk`, `havabbor`, `laks`, `kveite`, `stor_kveite`). The loader scales it to the tier length, centres it and expects the nose toward +X. A node named `Jaw` opens with the mouth cue; an AnimationPlayer's first animation loops. Run with `RB_PROXY_FISH=1` to force the proxies.

Checks (run in the game folder, always with `--audio-driver Dummy`):

```bash
../game-studio/tools/gd-android-lint.sh .
godot --headless --audio-driver Dummy --quit
XDG_DATA_HOME=<tmp> godot --headless --audio-driver Dummy res://tests/logic_test.tscn
XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy --display-driver x11 \
  --resolution 1080x1920 res://tests/capture.tscn        # under Xvfb; CAPTURE_PHASE=shell for MWM Play mode
```

The logic test has a bot clear levels 1-5 in both settings and checks the rules (catches, bobler and the gentle restart, bump, spawn mix, chase, kelp, Bobla, pearls, save, sounds). Never build the APK locally; CI does it (`.github/workflows/build-android.yml`).

Credits and licences: `CREDITS.md`.
