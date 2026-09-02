# ToyVolts v0.8 - Plastic

The toys move and break like plastic, and three bugs that bit the first party night are gone.

## Fixes (please re-download, these also went out as a v0.7 hotfix)

- **Sound.** Exported builds shipped mute: inside a build Godot lists sound files as
  `name.wav.import`, the sound bank rejected the extension and loaded nothing. Editor and
  headless tests never saw it. The bank now strips the suffix and logs `Sfx: N sounds loaded`
  at startup.
- **Menu online.** Esc opened the pause menu but no click landed: in an online match the
  world keeps running, and a "click to recapture the mouse" rule only checked whether the
  tree was paused, so the first click grabbed the mouse back before any button saw it.
- **Spawning inside things.** Two Toy Room spawns and one Diner spawn sat inside furniture,
  and the picker could drop a joining friend onto a bot idling on a spawn point. Every
  placement (first stand, bots, joins, respawns) now goes through a standing-capsule check
  against walls, furniture and other toys, with a ring search out to 3.6 m; a spawn with
  anyone within 1.2 m is never picked. The three bad points moved to open floor.

## Animations + effects (M7)

- **Locomotion:** speed-based walk/run blend, jump takeoff and landing beats with a squash
  and a dust ring, strafe lean, per-weapon stances (two-handed melee idle, heavier gatling
  hold), reload flourish with the spent magazine dropping and clattering.
- **Hit reactions:** directional flinches (Hit_A / Hit_B) plus a procedural chest kick that
  scales with the damage.
- **The fall-apart death:** 8-12 pooled plastic parts that bounce and fade, an orbiting death
  camera, and an assemble effect on respawn.
- **Per-weapon effects:** shotgun cloud + pump, sniper glint others can see, gatling heat glow
  / smoke / steam, bazooka backblast, grenade fuse blink, melee swing ribbons and shockwaves.
- **Surface-aware impacts:** wood, fabric, metal, paper, plastic, inferred from the map's
  textures and kit models.
- **Feedback:** floating damage numbers, a low-health vignette with a heartbeat.
- 14 new procedural sounds. Everything pooled and warmed up; Low holds its frame rate on the
  Intel iGPU.

## Under the hood

- 272 headless checks (was 207): animation states, pools allocation-free, spawn clearance on
  every map, occupied-spawn avoidance; loopback net test green.
- Perf polish: strafe-lean transform writes dead-banded, parked plastic parts stop pairing
  with the pile, the vignette quad is hidden while healthy.
