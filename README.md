# ToyVolts

A Microvolts / ToyBattles-style toy arena shooter in Godot 4.7. Every player carries all
seven weapons (melee, rifle, shotgun, sniper, gatling, bazooka, grenade launcher) on keys 1-7.

## Play

Double-click `PLAY.bat` (or `tools/godot.sh --path .`). Pick a mode (Free For All, Team
Deathmatch, Elimination, Capture the Battery, Practice), a map (Toy Room, Diner) and the bot
difficulty (Easy / Normal / Hard) from the menu. Releases: `build/ToyVolts-win64.zip`.

Capture the Battery: red vs blue, grab one of the three batteries (yellow beam), run it to
your team's CHARGE pad; first to 5. Carriers run 10 % slower and drop the cell when they die.
Item capsules (green = +35 HP, blue = ammo) sit at fixed spots on every map and respawn.

| Input | Action |
|---|---|
| WASD | move (no sprint, full air control) |
| Space | jump; a second jump whenever melee is out, even if you draw it mid-air |
| LMB / RMB | fire / aim (rifle zoom, sniper scope 4x -> 8x) or heavy melee swing |
| R | reload (switching weapons cancels a reload AND the weapon's recovery) |
| 1-7, wheel, Q | switch weapon / last weapon |
| Tab | scoreboard |
| Esc | pause: Resume / Settings / Main Menu |

Skill notes, straight from Microvolts: fire, swap to melee, swap back and fire again beats
the weapon's own fire interval (shotgun 0.48 s instead of 0.9 s). A scoped sniper body shot
is a one-shot kill; unscoped does 55. Melee runs 15% faster.

## Graphics settings

Esc > Settings (or Settings on the title screen): quality preset Low / Medium / High / Auto,
render scale (FSR 1 on Low, FSR 2 on Medium), VSync, fps cap, fullscreen, sensitivity,
volume, and a GPU pick for hybrid laptops (restarts the game). Auto detects the GPU class and
watches the first seconds of a match; if it cannot hold 50 fps it steps down one preset once.

Measured at 1600x900 with 5 bots (`tools/bench.sh`):

| GPU | Low | Medium | High (= v0.3) |
|---|---|---|---|
| RTX 3050 Laptop | 267 fps | 157 fps | 85 fps |
| Intel UHD (iGPU) | 111 fps | 29 fps | 15 fps |

Command line: `ToyVolts.exe --quality=low`, `--scale=0.66`, `--map=diner`, `--mode=ctb`,
`--difficulty=hard`, `--gpu-index 1` (engine flag, before `--`), `--bench` (prints frame
times and quits).

## Develop

- `tools/import.sh` after adding scripts with `class_name` or new assets
- `tools/test.sh` headless tests (93 checks)
- `tools/shot.sh <name> [--mode=ffa|tdm|elim|practice] [--bots=N] [--map=diner] [--quality=low] [--frames=N] [--pos=x,y,z] [--yaw=deg] [--pitch=deg] [--ui=pause|settings]` renders one frame to `captures/`
- `tools/bench.sh [low medium high]` frame-time table per preset; `GODOT_ARGS="--gpu-index 1"` to pick the iGPU
- `tools/export.sh` builds `build/ToyVolts-win64.zip`
- Design, weapon tuning table and milestones: `design/plan.md`; performance notes: `design/plans/next-session-perf.md`

Original assets only. The Microvolts client files in `~/ToyBattlesDemo` are reference material and never enter this repo.
