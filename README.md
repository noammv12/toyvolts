# ToyVolts

A Microvolts / ToyBattles-style toy arena shooter in Godot 4.7. Every player carries all
seven weapons (melee, rifle, shotgun, sniper, gatling, bazooka, grenade launcher) on keys 1-7.

## Play

Double-click `PLAY.bat` (or `tools/godot.sh --path .`). Pick Free For All, Team Deathmatch or
Practice from the menu.

| Input | Action |
|---|---|
| WASD | move (no sprint, full air control) |
| Space | jump; double jump while melee is out |
| LMB / RMB | fire / aim (rifle zoom, sniper scope) or heavy melee swing |
| R | reload (switching weapons cancels a reload) |
| 1-7, wheel, Q | switch weapon / last weapon |
| Tab | scoreboard |
| Esc, then M | free the mouse, back to menu |

## Develop

- `tools/import.sh` after adding scripts with `class_name` or new assets
- `tools/test.sh` headless tests (47 checks)
- `tools/shot.sh <name> [--mode=ffa|tdm|practice] [--bots=N] [--frames=N] [--yaw=deg] [--pitch=deg]` renders one frame to `captures/`
- Design, weapon tuning table and milestones: `design/plan.md`

Original assets only. The Microvolts client files in `~/ToyBattlesDemo` are reference material and never enter this repo.
