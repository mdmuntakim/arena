# Ringfall

A 2D platform-fighter for Android, in the spirit of Brawlhalla's ring-out
combat — built entirely in **Godot 4.5.2**, with **zero third-party assets**.
Every sprite, sound and song is generated procedurally by `tools/gen_assets.py`
(numpy) and by code-driven rendering, so there is nothing here that could be
mistaken for anyone else's game. All characters, weapons and stages are
original to Ringfall.

- Package name: `net.mdmuntakim.ringfall`
- Target: Android **arm64-v8a** only, signed APK
- Renderer: **Compatibility (OpenGL ES 3 / gl_compatibility)** — the only
  renderer that works across the Android device spectrum
- Engine: Godot **4.5.2-stable**, pinned in CI and in `build/export.sh`

---

## Game modes

| Mode | What it is |
| --- | --- |
| **1v1 vs AI** | Three difficulties (EASY / NORMAL / HARD AI). First to 3 KOs. |
| **Local 2P** | Two players on one screen; P2 on the physical gamepad or the right half of the touchpad. |
| **Training** | Reversible dummy (never dies, infinite stocks), live damage readout, and a **hitbox display** you toggle with the BACK button (or `T` on a keyboard). |

## The fighters (all original)

| Fighter | Weapons | Profile |
| --- | --- | --- |
| **Sera Volt** | Twindaggers / Longbow | Stormblade acrobat. Blistering speed. |
| **Bram, the Bulwark** | Skyhammer / Emberfists | Siege veteran. Slow, heavy, brutal signatures. |
| **Kaz Longarm** | Pike / Longsword | Pikewall duelist. Range wins fights. |
| **Nyx Emberborn** | Rune Staff / Longsword | Runecaster knight. Medium, tricky signatures. |

Each fighter also fights **unarmed** (Fists) when no weapon is held — unarmed
movesets are complete, not a placeholder.

## Stages (3, all original)

- **Sunspire** — day, warm stone towers, walk-off-able sides with walls.
- **Emberhollow** — dusk, deep brick cavern, wall-jump friendly.
- **Nightfall Reach** — night, blue platforms over a star void.

Platforms are drop-through (fast down + jump input), ledges hang off the main
platform, walls allow wall-jumps and wall-slides.

## Combat rules (Brawlhalla-style)

- Damage is a **percentage** (0 → higher). Knockback scales with damage:
  `kb = (base + damage × scale) × 100 × charge ÷ weight`, in px/s.
- You die by **ring-out** — leaving the blast zone. The screen edge is
  dangerous, not your health bar.
- **3 stocks** each, 5-minute timer, higher damage loses a timeout.
- Light attacks: neutral / side / up / down, on ground **and** in air — every
  fighter has a full 8-direction light kit per weapon plus unarmed.
- **Heavy / signature** attacks (Y), chargable; grounded heavies can **gravity
  cancel** (fast-fall out of recovery frames) into another move.
- **Dodge / air dodge** with real invulnerability windows and an air-dodge
  cooldown; dash on B or RB.
- **Weapon pickups** spawn on stage; LB swaps between your two weapons,
  throwing the held weapon as a projectile if both slots are full. Weapons
  bounce once, then vanish.
- Wall-jumps off solid stage walls.

## Controls

### Touch (Xbox-style layout)

Left side: a **left stick** for movement. Right side, an ABXY diamond plus
shoulder buttons:

| Control | Action |
| --- | --- |
| **A** | Jump |
| **B** | Dodge / Dash / Air dodge |
| **X** | Light attack (stick direction chooses the move) |
| **Y** | Heavy / Signature (hold to charge) |
| **LB** | Weapon swap / throw |
| **RB** | Dash |
| **LT / RT** | Emote / Taunt |
| **START** | Pause |
| **BACK** | Training-mode hitbox display |

The stick **snaps to 8 directions**, so up-x / down-x / up-y etc. pick the
right attack. The whole touchpad is multi-touch (you can move and attack at
once), and in **Settings** you can change the control **size**, **opacity**
and **spacing**, or flip the whole layout for **left-handed** play.

### Bluetooth Xbox gamepad

Plug a controller in: the mapping is identical (A=jump, B=dodge, X=light,
Y=heavy, LB=weapon, RB=dash, LT/RT=taunt, Start=pause, Back=hitbox toggle).
For local 2P, a second pad drives P2. Keyboard on desktop: arrows/WASD move,
`Z`/`X` light/heavy, `C` dodge, `W` jump, `T` hitbox toggle — handy for the
training overlay.

---

## What is actually tested (honest matrix)

| Tested | How | Result |
| --- | --- | --- |
| 406 engine checks (physics, hit resolution, knockback, stocks, KO, AI legality, weapon logic, input mapping) | Headless suite `tests/run_tests.gd` under Godot 4.5.2 | **ALL PASSED (406 checks)** |
| Visual smoke (menu, select, 3 stages, hit confirm, KO blast, training HUD, touchpad) | 8 screenshots on `xvfb` (llvmpipe), reviewed by hand | OK |
| Frame time | llvmpipe software rasterizer, 1920×1080, `avg_frame_ms ≈ 23` | see note |
| APK boots | Built with Godot 4.5.2 arm64 templates, signed with a debug keystore | built + verified structurally |

**Frame-time note:** 23 ms/frame was measured under **llvmpipe — a CPU
software rasterizer** — not on a phone. On any real GPU the scene is trivial
(quads and lines, no filters); expect 60 fps. We have **not** measured on real
Android hardware.

**Not tested (and we won't pretend otherwise):** no real-device or emulator
boot test, no touch input on hardware, no Bluetooth gamepad pairing test.
The CI machine has no Android SDK or device farm — the APK is exported with
Godot's own template pipeline and verified by structure, not by booting.

## Building it yourself

One command, no Android SDK required (the non-Gradle Godot export path):

```bash
bash build/export.sh
```

That pins Godot 4.5.2, runs the 406-check test suite first, generates all
procedural assets, exports the arm64 APK, and signs it with the keystore in
`signing/`. Output: `build/ringfall-arm64.apk`.

CI does exactly this on every push to `main` and publishes the APK plus a
source archive as a GitHub release. APK checksums are printed in the release
notes.

## About the signing key

`signing/debug.keystore` is a **debug-grade** keystore (PKCS#12, password
`android`, alias `androiddebugkey`) committed on purpose so the build is
reproducible from a clean checkout. Before shipping to any store, replace it
with your own release key and change the password in `export_presets.cfg`.

## Layout

```
src/core/    fighter, match, data, ai, camera, input
src/render/  procedural character rigs, fx, parallax
src/ui/      menu, HUD, touchpad
tests/       406-check headless suite
tools/       gen_assets.py, screenshot.gd
build/       export.sh (one-command pinned build)
```

## License

MIT. All assets generated in-repo; nothing was taken from any existing game.
