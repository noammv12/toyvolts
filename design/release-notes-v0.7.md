# ToyVolts v0.7 - Lalu's Birthday

A present for Hila (Lalu) from Noam & Daniel: her own party room, first thing on the title screen.

## LALU'S BIRTHDAY (new map `lalu_party`, new mode `party`)

- The big pink button on the title screen starts the party: Hila's room at toy scale with a
  giant three-tier cake and **12 lit candles** (shoot a candle to blow it out: smoke puff +
  squeak), **30 tethered balloons** that bob and pop into confetti, a **pinata** on a rope
  that swings when hit and bursts after 10 hits into candy cubes and item capsules, and
  **five gifts** whose lids pop when the bow is shot: a spring toy, a jack-in-the-box that
  cheers, a coin rain, a puppy plush that follows whoever opened it, and a fireworks battery.
- Confetti cannons in the corners, a disco dance floor with a mirror ball, a **bouncy castle**
  (double-height jumps, landings bounce you back up), a **moon corner** (low gravity), a
  slide from the dining table to the floor, a HAPPY BIRTHDAY HILA banner, a
  "From Noam & Daniel" sign and "מזל טוב לאלו" on the walls.
- Party mode: no PvP. Five guests in party hats (Sprinkles, Bubbles, Muffin, Confetti, Pixie)
  wander and dance; shooting anyone (guests, Noam, Daniel) makes them hop and cheer, never
  hurts. Everyone wears a party hat, the title screen has confetti, a "Happy Birthday"
  chiptune plays in the room.
- The checklist (candles, balloons, pinata, gifts) replaces the scoreboard. When it is
  complete: the cake erupts in a confetti storm, a fireworks show, every guest cheers, the
  camera orbits the room and a card flies in: "Happy Birthday Lalu! Love, Noam & Daniel".
  Then everything resets so she can do it again.
- Online: the room is hostable from the lobby (mode Birthday Party). Every prop is mirrored
  to the guests (candles, balloons, pinata hits and burst, gifts and who opened them, the
  finale and the reset), late joiners get the current state. Loopback-tested.
- Runs on Low on an integrated GPU (`--quality=low` if the auto-detect picks too high).

## Key bindings

- Esc > Settings > **Key bindings...**: every action (move, jump, crouch, fire, aim, reload,
  weapons 1-7, last / next / previous weapon, scoreboard, pause) with its key. Click a cell,
  press a key or mouse button; Esc cancels; a key another action uses swaps the two; Reset to
  defaults. Saved under `[controls]` in `user://settings.cfg` and applied at boot. The weapon
  strip and the title hint show the bound key (bazooka on E shows "E" over slot 6).

## Fidelity pass (from design/research/microvolts-reference.md)

- Swap-cancel: the recovery-cancel works for the shotgun, bazooka and grenade launcher only;
  reload-cancel stays universal; the sniper keeps its 1.5 s recovery through swaps.
- Sniper: single 4x zoom by default, "double zoom (8x)" as a Settings toggle; a 0.15 s scope
  settle (a shot fired sooner does the unscoped 55; the scope HUD says "settling").
- Gatling: the spin drops to zero when the toy leaves the floor while firing.
- Crouch on L-Ctrl: half speed, capsule 1.15 -> 0.8, head hitbox lowered, camera down 0.45 m,
  a procedural hips drop (the kit has no crouch clip), no jump while crouched, stand up only
  with headroom; bots crouch when hurt behind cover; replicated online.
- Melee combo: the three light swings alternate horizontal, upward, overhead; the third does
  1.5x with knockback and resets; the combo drops after 0.8 s idle.
- Radar: teammates and objectives always; enemies only for 1.5 s after they fire or within
  6 m; hidden while scoped.
- Grenades keep exploding on a direct player hit (the research doc's gap 2 was wrong).

## Lag compensation

- The client's input packet carries the server tick it is rendering (the interpolation
  clock). The host keeps 15 ticks of position / yaw / crouch history per toy and judges that
  client's hitscan shots against the world it saw: world geometry as it is now, every other
  toy where it stood at that tick (capped at 200 ms back). Shots land where you aimed over
  Tailscale. Headless unit tests, the loopback test checks the host rewinds.

## Under the hood

- World props can be shot: anything in the `shootable` group with `on_shot()` reacts to
  hitscan, melee, rockets, grenades and splash. New physics layer 4 for props toys walk
  through (balloons, the pinata, gift bows).
- `PartyZone` areas change movement locally on every peer (bounce / moon / slide), so
  prediction and the host agree without extra packets.
- 198 headless checks (`tools/test.sh`), 24 loopback checks (`tools/net_test.sh`: a third
  phase hosts the party and the client mirrors every prop; the host rewinds the client's shot).
- Debug: `--map=lalu_party --mode=party`, `--party_finish` (completes the checklist for
  finale captures), `--party_smoke` (the host works through the checklist by itself).
