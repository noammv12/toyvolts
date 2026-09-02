# ToyVolts v0.8 kickoff: animations + effects ("juice")

Paste the section below as the first prompt of the next session.

---

Continue ToyVolts, my Microvolts-style toy shooter in Godot 4.7 at C:\Users\noamm\toyvolts
(memory: project_toyvolts.md; repo github.com/noammv12/toyvolts, branch main, gh logged in).
v0.7 is released: Lalu's Birthday party room, rebindable keys, Microvolts fidelity pass
(crouch, melee combo, sniper settle, radar rules), lag compensation, online host/join. Verification
is 207 headless checks (tools/test.sh, ~4.5 min, 240 s guard) + 25 loopback checks
(tools/net_test.sh), all green. Read this whole prompt, then the memory file, then the code
paths named below BEFORE writing anything. Work autonomously; ask only if a decision is mine.

THIS SESSION = ANIMATIONS + EFFECTS. Goal: the game should feel like plastic toys fighting:
snappy, readable, juicy. Microvolts signature: toys are plastic, they "fall apart" on death,
every hit is readable. Everything must stay cheap (Low preset on an Intel iGPU: 119 fps today,
no regression allowed) and cosmetic-safe online (clients play effects from existing events; no
new packets unless a rule truly needs one).

WHERE THINGS ARE (read these first, in this order):
- src/character/figure.gd: the KayKit rig wrapper. AnimationTree = loco BlendSpace2D
  (Idle / Running_A / Walking_Backwards / Running_Strafe_Left / Right) -> "air" Blend2
  (Jump_Idle) -> "aim" Blend2 (2H_Ranged_Aiming, upper-body filter) -> "shot" OneShot of a
  Transition of ACTIONS (fire, fire_1h, melee_light/up/over, melee_heavy, reload, hit, throw,
  cheer). play_action(key, seconds) time-scales a clip to fit. play_death() plays Death_A/B on
  the AnimationPlayer with the tree off; revive() turns it back on. add_hat() (party).
- src/character/aim_modifier.gd: SkeletonModifier3D: chest/head pitch tilt, arm lift for guns,
  chest twist, head_scale 0.8, crouch hips drop + lean (no crouch clip exists).
- Clips that exist in every rig (Knight, Barbarian, Mage, Rogue; KayKit Adventurers, CC0) and
  are NOT used yet: Jump_Start, Jump_Land, Jump_Full_Long, Jump_Full_Short, Walking_A/B/C,
  Running_B, Hit_B, Dodge_Forward/Backward/Left/Right, 2H_Melee_Idle, Unarmed_Idle,
  1H_Ranged_Aiming/Shoot/Reload, 2H_Melee_Attack_Slice/Spin/Stab, 1H_Melee_Attack_Stab,
  Interact, PickUp, Use_Item, Sit_*, Lie_*, Block*. There is NO crouch clip and NO run-with-gun
  clip; do not invent clip names, check `anim_player.has_animation()`.
- src/character/character.gd: the simulated body (player, bots, remote toys). Signals: died,
  damaged(amount, source, headshot), respawned, health_changed. States: crouching, grounded(),
  velocity, _jumps_used, protection_left, puppet/predicted flags. take_damage / damage_remote /
  die_remote / respawn are the hooks for reactions.
- src/weapons/arsenal.gd (fired, melee_swung, hit_confirmed signals; muzzle_position;
  _fire_hitscan / _fire_projectile / _melee; the draw arc; gatling `spin` on WeaponState),
  src/weapons/projectile.gd (rocket/grenade flight, bounce, fuse, explode),
  src/weapons/weapon_models.gd (weapons are PRIMITIVE placeholders; gatling has a "Barrels"
  node that spins), src/weapons/weapon_db.gd (numbers).
- src/core/vfx.gd: the POOLED effects autoload. Read it fully: `_acquire/_release_after`,
  shared materials, `tracer`, `muzzle_flash`, `casing`, `impact` (sparks + puff + decal),
  `explosion`, `trail/release_trail`, `jump_puff`, `puff`, `shake` signal. Rule: a shot allocates
  nothing (tests/run_tests.gd checks "a shot uses pooled effects"). src/world/party/party_fx.gd
  is the same pattern for confetti / sparkles / fireworks.
- src/player/player_controller.gd: camera rig (SpringArm), recoil, trauma shake, run bob, swap
  dip, zoom, crouch camera drop, cinematic orbit. src/core/post_fx.gd + shaders/outline_*.gdshader:
  the toon outline full-screen quad (child of the current camera).
- src/ui/hud.gd: hit marker, damage flash + direction arc, kill popups, kill flash, scope.
  Game.hitstop() exists (sniper kills).
- src/core/sfx.gd: pooled positional + UI sounds; assets/sfx via tools/synth_sfx.py (numpy/scipy,
  procedural; regenerate with `python tools/synth_sfx.py`); party sounds in tools/synth_party.py.
- src/net/net.gd: events `_ev_fired/_ev_melee/_ev_reload/_ev_hit/_ev_damaged/_ev_died/_ev_respawn`
  already reach clients; snapshots carry pos/vel/yaw/pitch/slot/hp/alive/on_floor/crouch/
  scope/aiming. Derive every new animation state from these; do not add packet fields unless
  the state cannot be derived (then update NetCodec, its byte-count tests and net_test).

BUILD, IN THIS ORDER (each step: implement -> headless test -> capture -> commit + push):

1. Locomotion. Speed-based walk/run blend (Walking_A below ~45% run speed, Running_A above;
   backwards keeps Walking_Backwards; blend by actual velocity, not input). Jump_Start on
   takeoff (short one-shot), Jump_Idle in the air (exists), Jump_Land on landing with a
   procedural squash-and-stretch (scale the figure root briefly, 0.12 s) and a landing dust puff
   (pooled) scaled by fall speed; a camera dip on landing proportional to fall speed (small).
   Strafe lean: roll the model ~6 degrees into the strafe direction. Crouched locomotion: the
   hips drop stays, add a slight forward lean while moving and use Walking_A at crouch speed.
   Double jump: a spin or a stronger puff already exists; add a short Jump_Full_Short on the
   second jump if it reads well in a capture, else keep Jump_Idle. Bots and remote toys get
   all of this for free (they use Figure); verify with a bots capture.

2. Combat poses. Melee equipped: use 2H_Melee_Idle as the lower-priority idle pose instead of
   the unarmed idle (upper body only, like the aim pose) so the shovel is held two-handed.
   Guns keep 2H_Ranged_Aiming. Gatling: heavier stance (arm lift lower, chest twist stronger)
   via AimModifier targets, not a clip. Reload clip is already timed to reload_time; add a
   magazine-drop prop (pooled small box falling with a bounce sound) for rifle/shotgun/sniper.

3. Hit reactions + the "fell apart" death (the Microvolts signature). Hit: choose Hit_A vs Hit_B
   by the direction of the source (front/back) and add a procedural flinch of the chest away
   from the source (AimModifier gets a `flinch` vector that decays); headshot: extra head jerk
   and a star-pop sprite at the head. Death: the toy breaks into parts. Implement in Vfx as a
   pooled effect `fall_apart(character)`: 8-12 toy parts (boxes/capsules coloured like the
   figure's tint, one spring coil from a torus stack) burst outward with a plastic "pop" and
   clatter, bounce as pooled RigidBody3D on the target layer 4 (they must not push toys), freeze
   after 3 s, recycle. The figure hides immediately (0.1 s, keep Death_A/B as a fallback flag if
   the parts effect is off). Respawn: an "assemble" effect at the spawn point: a light beam, a
   ring puff, the figure scales in from 0 with squash, the existing spawn-shield shimmer stays.
   Death camera: on the local player's death the camera orbits the pile of parts slowly for
   the respawn countdown (reuse the cinematic camera idea from the party finale; it must adopt
   the PostFx quad, see gotchas) and fades back in on respawn.

4. Per-weapon effects. Rifle: keep. Shotgun: 8 pellet tracers already exist; add a bigger
   muzzle cloud and a pump/rack flourish on the model between shots. Sniper: long bright
   tracer (exists), add a scope-glint sprite on the scoped toy visible to others (only while
   scoped; derive from snapshot `aiming` + slot 4), and a bullet-time-free kill effect is
   already hitstop. Gatling: barrel emission ramps with WeaponState.heat (glow red), smoke wisps
   from the barrels above 70% heat, steam burst + hiss when overheated, spin-down sound.
   Bazooka: backblast puff behind the shooter on launch, rocket flame flicker (trail exists),
   close-range explosion adds a brief white screen flash on the local player. Grenade: fuse
   blink (small pooled light blinking faster before detonation) + tick sound, bounce sparks.
   Melee: a swing arc trail (pooled curved ribbon mesh, fades in 0.15 s) per swing kind
   (horizontal / upward / overhead), heavy hit = shockwave ring on the ground, the combo
   finisher = star burst + stronger camera kick on hit.

5. Surface-aware impacts. Tag map materials by surface kind (wood, fabric, plastic, metal,
   paper/cardboard) with a `surface` meta on the StaticBody (ArenaBase._box_mat / _pbr / _place
   can set it; kit models are plastic by default). Vfx.impact picks puff colour, chip particle
   (splinters vs fluff vs plastic shards) and Sfx variant by surface. Decals exist; tint them
   per surface. Keep ONE shared material per kind (pooling rules).

6. Player feedback. Floating damage numbers (pooled Label3D or a sprite atlas; Microvolts shows
   them), low-HP vignette (red edge pulse below 30 HP) with a heartbeat sound, headshot ding
   already exists (make the popup a star pop). Optional if time: a subtle FOV nudge on the jump.

7. Verify + ship. Every new effect goes through the pools (extend the "a shot allocates
   nothing" test to a death, a melee swing, a landing, a gatling overheat). Headless tests for
   the animation states (tree parameters after a jump/landing, walk vs run blend by speed,
   Hit_A vs Hit_B by direction, parts spawned on death and recycled, respawn assemble, gatling
   heat glow parameter, scope glint only while scoped). tools/net_test.sh must stay green
   (deaths and respawns already flow over the wire; check the client plays fall_apart). Bench
   before/after on the iGPU: `GODOT_ARGS="--gpu-index 1" tools/bench.sh low high -- --map=toy_room`
   (today: low 119 / high 17 fps; the RTX path on this laptop has 500 ms present stalls that are
   environmental, do not chase them). Captures: tools/shot.sh with --freeze_on=fire|explode|hit
   [--freeze_delay=N], --fxtest, --timescale=0.2, --frames=a,b,c, --orbit=deg, --pos/--yaw/
   --pitch, --slot=N --autofire=frame, --crouch, --bots=N; read the PNGs (captures/) and judge
   them. Update README, design/plan.md (milestone M7), release notes design/release-notes-v0.8.md,
   memory. Release: `tools/export.sh` then `gh release create v0.8 build/ToyVolts-win64.zip
   --notes-file design/release-notes-v0.8.md`.

CONSTRAINTS AND RITUALS (unchanged, do not skip):
- Original / CC0 assets only (KayKit kits, Kenney sounds, ambientCG textures, procedural
  sounds). The ripped Microvolts client in ~/ToyBattlesDemo is reference only, never in the repo.
- `tools/import.sh` after any new class_name script or asset (the class cache), then
  `tools/test.sh`, then `tools/net_test.sh`, then captures, then commit + push as you go with
  the attribution trailers.
- Godot 4.7 gotchas: GPUParticles3D `restart()` leaves one-shots off, toggle `emitting`;
  `await get_tree().physics_frame` resumes BEFORE nodes process that step (frame-accurate tests
  observe step f-1 after the await, then set inputs for step f); reparenting an Area3D inside
  body_entered must be call_deferred; `var x := untyped_call()` fails to parse (annotate the
  type); parent @onready fields are null in a child's _ready; a moved kinematic body is not
  visible to same-step physics queries; a full-screen PostFx quad is a child of the current
  camera, any other camera you make current must adopt it (see PlayerController.cinematic);
  the KayKit head bone is animated with scale, pose attachments from the bone's orthonormalised
  world basis (see Figure._pose_hat); the baked navmesh floats ~0.5 m above the floor.
- Shell gotchas on this Windows laptop: long python heredocs in Bash fail, write the patch to
  a .py file with the Write tool and run it; Hebrew and other non-ASCII text only through the
  Write/Edit tools (Git Bash mangles it); `-s` SceneTree scripts don't see autoloads, use a
  scene (tests/probe_*.tscn pattern); tools/test.sh has a 240 s guard, if the suite dies without
  a "N checks" line the guard killed it.
- Definition of done: locomotion, poses, hit reactions, fall-apart death + assemble respawn,
  death camera, per-weapon effects, surface impacts, damage numbers and low-HP feedback all
  live and captured; every rule has a headless test; pools proven allocation-free; bench no
  regression on Low; net_test green; docs + memory updated; v0.8 released with notes.
