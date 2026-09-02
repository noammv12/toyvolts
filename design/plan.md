# ToyVolts â€” design + plan

Working title for a Microvolts / ToyBattles-style toy arena shooter. Godot 4.7.2, GDScript.
Reference game: MICROVOLTS: Recharged (Masangsoft, free on Steam). We copy the *feel and rules*;
models, textures, sounds and maps are original. Ripped client files in `~/ToyBattlesDemo`
are scale/style reference only and never enter this repo.

## The feel we are cloning

- Lobby-room third-person shooter, toy figures fighting in oversized human spaces.
- Every player carries **all seven weapons**, keys 1-7. Skill = swapping at the right moment,
  swap-cancelling reloads and recoil, melee double-jump movement ("wave-step").
- No sprint, no crouch. Constant run speed, full air control, short snappy jumps.
- Low time-to-kill. ~100 HP, health vials drop on kills, short spawn protection.
- Over-the-shoulder camera, character offset left, crosshair centred.
- Modes (order we build): AI Battle â†’ FFA â†’ TDM â†’ Elimination â†’ Capture the Battery â†’ Zombie.

## Weapon table (initial tuning, will be tuned by feel against the Steam client)

Units: damage to a 100 HP target, seconds, metres. Character is ~1.8 m tall in-world.

| Slot | Weapon           | Fire type            | Damage                         | Rate            | Clip / reserve | Reload | Secondary                | Special |
|-----:|------------------|----------------------|--------------------------------|-----------------|----------------|--------|--------------------------|---------|
| 1    | Melee (shovel)   | Sweep hitbox, 1.6 m  | light 20 (3-hit combo), heavy 45 | light 0.35 s, heavy 0.8 s | none    | none   | Heavy swing              | +12% run speed, **double jump** |
| 2    | Rifle            | Hitscan              | 9 body / 14 head               | 10 rps          | 30 / 120       | 1.6 s  | Slight zoom (1.3x), low sens | Spawn weapon |
| 3    | Shotgun          | 8 hitscan pellets    | 9 per pellet, spread 7Â°        | 0.9 s/shot      | 3 / 12         | 1.4 s  | none                     | Falloff after 8 m |
| 4    | Sniper           | Hitscan              | scoped 85 body / 170 head; unscoped 40 | 1.5 s/shot | 5 / 20     | 2.2 s  | Scope 4x, sens Ã·4        | Quickscope allowed |
| 5    | Gatling          | Hitscan              | 6 body / 9 head, spread 4Â°     | 18 rps          | 120 / 0        | 3.0 s  | none                     | 0.45 s spin-up, overheat after 6 s, run Ã—0.8 |
| 6    | Bazooka          | Projectile 24 m/s    | 55 direct + splash 55â†’0 over 3 m | 1.2 s/shot    | 3 / 9          | 2.0 s  | none                     | Self-damage Ã—0.5, knockback |
| 7    | Grenade launcher | Arc projectile 18 m/s | splash 50â†’0 over 2.5 m        | 0.7 s/shot      | 4 / 12         | 1.8 s  | none                     | Bounces, detonates on player contact or 2.0 s fuse |

Movement: run 7.0 m/s, gravity 30, jump v=9.5 (â‰ˆ1.5 m), air accel low, ground accel high.
Hit reactions: brief flinch + knockback on explosives and shotgun. Headshot multiplier 1.5-2x per weapon.

## Architecture (Godot)

```
project.godot                autoloads: InputSetup, Game, DebugCapture
src/core/input_setup.gd      registers input actions in code (move, jump, fire, alt_fire, reload, weapon_1..7, weapon_next/prev/last)
src/core/game.gd             match state, mouse capture, settings
src/core/debug_capture.gd    --screenshot=<png> [--frames=N]  â†’ saves a frame and quits (my visual verify loop)
src/player/player.tscn/.gd   CharacterBody3D, over-shoulder SpringArm camera, weapon slots
src/weapons/weapon_data.gd   Resource: the table above as .tres files in src/weapons/data/
src/weapons/*.gd             base Weapon + Hitscan / Projectile / Melee behaviours
src/world/arena_greybox.*    greybox arena built from a box table (toy scale)
src/ui/hud.*                 crosshair, HP, weapon + ammo
src/bots/*                   M2: nav-mesh bots with weapon preference by range
shaders/toon.gdshader        banded toon lighting + rim (outline pass at art time)
tests/run_tests.gd           headless smoke + unit tests: tools/godot.sh --headless --path . -s tests/run_tests.gd
```

Server-authoritative from the start: player input â†’ simulation on the "server" node (local in solo play),
so M4 multiplayer is a transport change, not a rewrite.

## Milestones

- **M0 skeleton** â€” project, controller, camera, greybox arena, toon shader, HUD, screenshot harness.
- **M1 seven weapons** â€” data-driven, all behaviours in the table, swap + swap-cancel, damage, headshots, splash, HUD ammo.
- **M2 match loop** â€” bots (AI Battle), FFA + TDM rules, respawn + protection, health vials, scoreboard, round timer.
- **M3 art pass** â€” 4 toy figures (rigged, Mixamo anims), 7 toy weapon models, one map at Hobby-Shop scale, sounds.
- **M4 online** â€” ENet, host/join room, lobby screen, 2-8 players.
- **Later** â€” parts customization, capsule shop, Elimination, Capture the Battery, Zombie, more maps.

## Verify ritual

1. `tools/godot.sh --headless --path . --import` (first run / after adding assets)
2. `tools/godot.sh --headless --path . -s tests/run_tests.gd` â†’ exit 0
3. `tools/godot.sh --path . -- --screenshot=captures/<name>.png` â†’ I look at the PNG
4. Noam plays it on the laptop: `tools/godot.sh --path .`
