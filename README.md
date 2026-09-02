# ToyVolts

A Microvolts / ToyBattles-style toy arena shooter in Godot 4.7. Every player carries all
seven weapons (melee, rifle, shotgun, sniper, gatling, bazooka, grenade launcher) on keys 1-7.

## Play

Double-click `PLAY.bat` (or `tools/godot.sh --path .`). Pick a mode (Birthday Party, Free For
All, Team Deathmatch, Elimination, Capture the Battery, Practice), a map (Lalu's Birthday, Toy
Room, Diner) and the bot difficulty (Easy / Normal / Hard) from the menu. Releases:
`build/ToyVolts-win64.zip`.

**LALU'S BIRTHDAY** (the big pink button, v0.7): Hila's party room. Blow out the 12 candles on
the cake (shoot them), pop the 30 balloons, hit the pinata 10 times (candy + capsules), shoot
the bows on the five gifts (spring toy, jack-in-the-box, coin rain, a puppy that follows you,
fireworks). Bouncy castle = double jumps and bouncy landings, moon corner = low gravity, a
slide from the table, a disco floor, confetti cannons. No PvP: shooting a guest (or Noam and
Daniel online) makes them hop and cheer. Complete the checklist for the finale (confetti
storm, fireworks, orbiting camera, the card), then it resets. Easter eggs: the K-pop stage
(shoot PLAY: the track, strobing lights, every guest in a synchronised routine), Rich the
hippo-like bully asleep on his cushion (shoot: barks and wags), Chuchu the bulbul on her
perch (shoot: she flies a loop around the room). Hostable from the lobby (mode Birthday
Party); every prop is mirrored to the guests.

**Plastic** (v0.8): the toys move and break like plastic. Walk/run blend by speed, jump and
landing beats with a squash and dust ring, strafe lean, per-weapon stances and a reload
flourish; directional hit flinches; the Microvolts fall-apart death (plastic parts bounce and
fade, an orbiting death camera, an assemble effect on respawn); per-weapon effects (shotgun
cloud, sniper glint others can see, gatling heat glow / smoke / steam, bazooka backblast,
grenade fuse blink, melee swing ribbons); impacts that know wood from fabric, metal, paper
and plastic; floating damage numbers and a low-health heartbeat. Weapons you are not holding
reload themselves from reserve (1.5x their reload time); the one in hand still needs R. Spawns are checked for
standing room against furniture and other toys before anyone is placed.

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
| L-Ctrl | crouch |

Every key is rebindable: Esc > Settings > **Key bindings...** (or from the title screen). Click
an action, press a key or mouse button; Esc cancels; a key another action uses swaps the two;
Reset to defaults. Saved under `[controls]` in `user://settings.cfg`. The weapon strip and the
title hint show the bound key (bazooka on E shows "E" over slot 6).

Skill notes, straight from Microvolts: fire, swap to melee, swap back and fire again beats
the weapon's own fire interval (shotgun 0.4 s instead of 0.9 s). That recovery-cancel works
for the shotgun, bazooka and grenade launcher only (the sniper keeps its 1.5 s recovery
through a swap); reload-cancel works with everything. Draws are short (melee
0.15 s, rifle 0.2, shotgun 0.25, sniper / bazooka / launcher 0.3, gatling 0.4) and anything
you press during a draw is remembered: fire, aim, a jump waiting for melee, or another
weapon key (which retargets the draw at once). The wave-step works in one airtime: shotgun
shot, jump, melee flick, air shot, melee, double jump, back to the shotgun, third shot, land
(`tests/run_tests.gd` scripts exactly that at 60 Hz). A scoped sniper body shot is a one-shot
kill; unscoped does 55, and so does a shot fired within 0.15 s of scoping in (the scope
"settles"). The scope is a single 4x zoom; Settings can add the 8x stage. The gatling's
spin drops to zero when you leave the floor while firing. Melee runs 15% faster and its
light swings chain horizontal, upward, overhead: the third does 1.5x with knockback, and
the chain drops after 0.8 s. Crouch (L-Ctrl) halves your speed, lowers the hitboxes and the
camera, blocks jumping and only lets you stand where there is headroom. The radar always
shows teammates and objectives; enemies appear for 1.5 s after they fire or within 6 m,
and the radar hides while you are scoped.

## Online

Title screen > **Online**: host a game (port 7777) or join `ip:port`; pick name and toy;
the host picks map / mode / bots and presses START. Friends can join a running match. The
host runs the whole simulation; your own toy is predicted locally so movement and swaps
never wait for the network, and your hitscan shots are judged against the world you were
seeing (the host rewinds everyone's hitboxes up to 200 ms). Over the internet use Tailscale (zero configuration) or forward
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
| Intel UHD (iGPU), v0.7 | 119 fps (Lalu's Birthday: 102) | - | 17 fps |
| Intel UHD (iGPU), v0.8 | 70 fps (v0.7 same session: 71) | - | - |

Command line: `ToyVolts.exe --quality=low`, `--scale=0.66`, `--map=diner`, `--mode=ctb`,
`--difficulty=hard`, `--gpu-index 1` (engine flag, before `--`), `--bench` (prints frame
times and quits), `--host` / `--join=ip:port` / `--server` with `--port=N` (online, see
`tools/NET.md`).

## Develop

- `tools/import.sh` after adding scripts with `class_name` or new assets
- `tools/test.sh` headless tests (263 checks: bindings, weapons, packets, interpolation, lag compensation, the wave-step at 60 Hz, crouch, combos, radar rules, modes, maps, the party room, the animation states and every effect pool)
- `tools/net_test.sh` two-process loopback smoke: headless host + client, handshake, spawns, a confirmed (lag-compensated) hit, a whole short match, the party room mirrored
- `tools/shot.sh <name> [--mode=ffa|tdm|elim|ctb|party|practice] [--bots=N] [--map=diner|lalu_party] [--quality=low] [--frames=N] [--pos=x,y,z] [--yaw=deg] [--pitch=deg] [--orbit=deg] [--ui=pause|settings|lobby] [--party_finish]` renders one frame (or a comma list of frames) to `captures/`
  - driving the toy for an effect shot: `--aim=x,y,z` (holds the crosshair on a world point), `--move=x,z`, `--jump=N`, `--autofire=N`, `--slot=N`, `--crouch`, `--hp=N`, `--kill_me=N`
  - catching a short effect: `--freeze_on=fire|explode|hit|land|death|respawn [--freeze_delay=frames]`, `--timescale=0.25`, `--dump_vfx`, `--fxtest` (stages the whole effect library in front of the player)
  - note: after a freeze, `--frames=` must land soon after it -- the respawn timer keeps running while the tree is paused
- `tools/synth_sfx.py` / `tools/synth_party.py` regenerate the procedural sounds (party: pops, squeaks, cheers, fireworks, the Happy Birthday chiptune loop)
- `tools/bench.sh [low medium high]` frame-time table per preset; `GODOT_ARGS="--gpu-index 1"` to pick the iGPU
- `tools/export.sh` builds `build/ToyVolts-win64.zip`
- Design, weapon tuning table and milestones: `design/plan.md`; performance notes: `design/plans/next-session-perf.md`;
  Microvolts reference numbers and the gap list: `design/research/microvolts-reference.md`

Original assets only. The Microvolts client files in `~/ToyBattlesDemo` are reference material and never enter this repo.
