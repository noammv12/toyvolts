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
the weapon's own fire interval (shotgun 0.4 s instead of 0.9 s). Draws are short (melee
0.15 s, rifle 0.2, shotgun 0.25, sniper / bazooka / launcher 0.3, gatling 0.4) and anything
you press during a draw is remembered: fire, aim, a jump waiting for melee, or another
weapon key (which retargets the draw at once). The wave-step works in one airtime: shotgun
shot, jump, melee flick, air shot, melee, double jump, back to the shotgun, third shot, land
(`tests/run_tests.gd` scripts exactly that at 60 Hz). A scoped sniper body shot is a one-shot
kill; unscoped does 55. Melee runs 15% faster.

## Online

Title screen > **Online**: host a game (port 7777) or join `ip:port`; pick name and toy;
the host picks map / mode / bots and presses START. Friends can join a running match. The
host runs the whole simulation; your own toy is predicted locally so movement and swaps
never wait for the network. Over the internet use Tailscale (zero configuration) or forward
UDP 7777: the exact steps for both sides are in `tools/NET.md`. Dedicated server:

```
ToyVolts.exe --headless -- --server --port=7777 --map=diner --mode=ctb --bots=3
```

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
times and quits), `--host` / `--join=ip:port` / `--server` with `--port=N` (online, see
`tools/NET.md`).

## Develop

- `tools/import.sh` after adding scripts with `class_name` or new assets
- `tools/test.sh` headless tests (125 checks: weapons, packets, interpolation, the wave-step at 60 Hz, modes, maps)
- `tools/net_test.sh` two-process loopback smoke: headless host + client, handshake, spawns, a confirmed hit, a whole short match
- `tools/shot.sh <name> [--mode=ffa|tdm|elim|practice] [--bots=N] [--map=diner] [--quality=low] [--frames=N] [--pos=x,y,z] [--yaw=deg] [--pitch=deg] [--ui=pause|settings]` renders one frame to `captures/`
- `tools/bench.sh [low medium high]` frame-time table per preset; `GODOT_ARGS="--gpu-index 1"` to pick the iGPU
- `tools/export.sh` builds `build/ToyVolts-win64.zip`
- Design, weapon tuning table and milestones: `design/plan.md`; performance notes: `design/plans/next-session-perf.md`;
  Microvolts reference numbers and the gap list: `design/research/microvolts-reference.md`

Original assets only. The Microvolts client files in `~/ToyBattlesDemo` are reference material and never enter this repo.
