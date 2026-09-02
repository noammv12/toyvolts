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

## Under the hood

- World props can be shot: anything in the `shootable` group with `on_shot()` reacts to
  hitscan, melee, rockets, grenades and splash. New physics layer 4 for props toys walk
  through (balloons, the pinata, gift bows).
- `PartyZone` areas change movement locally on every peer (bounce / moon / slide), so
  prediction and the host agree without extra packets.
- 155 headless checks (`tools/test.sh`, 23 new for the party), 23 loopback checks
  (`tools/net_test.sh`, a third phase hosts the party and the client mirrors every prop).
- Debug: `--map=lalu_party --mode=party`, `--party_finish` (completes the checklist for
  finale captures), `--party_smoke` (the host works through the checklist by itself).
