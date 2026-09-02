# ToyVolts v0.6 - online, and the wave-step is real

## Online multiplayer (ENet)

- Title screen > **Online**: host a game (port 7777) or join `ip:port`, pick a name and a toy.
  The host sets map / mode / bots / difficulty and presses START; friends can join a running
  match and spawn straight in. Team modes have a Switch team button.
- The host runs the whole simulation (every toy, every shot, bots, batteries, capsules,
  vials, match rules). Your own toy is predicted locally, so movement and weapon swaps never
  wait for the network; the host's snapshots correct it quietly. Other toys interpolate about
  80 ms behind. Muzzle flash, tracer and swing play at once; hit markers, damage, kills,
  pickups and match events come from the host.
- Dedicated headless server: `ToyVolts.exe --headless -- --server --port=7777 --map=diner --mode=ctb --bots=3`.
- Friends over the internet: `NET.md` (in the zip) explains Tailscale (recommended, zero
  configuration) and port forwarding, with the exact steps for each side.
- HUD shows `ping` on clients and `hosting N` on the host.

## Swapping feels like Microvolts

- Draw times per weapon: melee 0.15 s, rifle 0.2, shotgun 0.25, sniper / bazooka / launcher
  0.3, gatling 0.4. The outgoing weapon drops, the new one rises into the aim; a small camera dip.
- Anything pressed during a draw is remembered and executes the tick the weapon is up: fire,
  aim / heavy swing, and a jump that waits for melee to grant it. Another weapon key mid-draw
  retargets the draw at once (Q and the wheel too). Swap-cancel unchanged.

## Wave-step

- In one airtime: shotgun shot, jump, melee flick, air shot, melee, double jump, back to the
  shotgun, third shot, land. Jump 9.5 / gravity 30 / second jump 0.92x untouched; it works
  because the swaps are quick and buffered. A frame-accurate 60 Hz test scripts exactly this
  (shots at F0, F20, F40, landing at F68).

## Under the hood

- Player split into a `PlayerController` (input, camera, HUD hooks) and the shared `Character`
  body: bots, the local human and remote players are the same class.
- 125 headless checks (`tools/test.sh`), a two-process loopback smoke test
  (`tools/net_test.sh`), `design/research/microvolts-reference.md` with sourced Microvolts
  numbers and a ranked list of what ToyVolts still does differently.

Windows 64-bit, Vulkan (d3d12 fallback: `ToyVolts.exe --rendering-driver d3d12`).
