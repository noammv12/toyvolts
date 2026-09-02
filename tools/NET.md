# Playing ToyVolts online

ToyVolts uses a host-authoritative model over ENet (UDP). One machine hosts: it runs the
whole match (every toy, every shot, the bots, the batteries). Friends join it. Nothing is
uploaded anywhere; there is no account and no server browser, you just tell your friends an
address.

Default port: **7777/UDP**. Up to 8 players, bots fill the rest.

## Same room / same Wi-Fi (LAN)

1. Host: title screen > **Online** > type a name, pick a toy > **Host a game**. Pick the
   map, mode, bots and difficulty, then **START** once everyone is in (people can also join a
   running match; they spawn straight in).
2. Everyone else: **Online** > name + toy > type the host's LAN address in the Join box
   (for example `192.168.1.23:7777`) > **Join**. Windows shows the address under
   `ipconfig` > "IPv4 Address".
3. Windows Firewall will ask the host once to allow `ToyVolts.exe`; say yes (private
   networks is enough).

## Friends over the internet: Tailscale (recommended, zero configuration)

[Tailscale](https://tailscale.com/download) makes every machine in your private mesh reachable
by a fixed `100.x.y.z` address, straight through home routers and carrier NAT, with no port
forwarding and nothing exposed to the public internet. Free for personal use.

Both sides, once:

1. Install Tailscale, sign in (Google/Microsoft/GitHub account), leave it running.
2. The host invites the friends to the same tailnet (Tailscale admin console > Users > Invite),
   or the friends simply sign in with the same account.
3. The host reads its own address: Tailscale tray icon > "This device" (or `tailscale ip -4`
   in a terminal). It looks like `100.101.102.103`.

Every session:

- **Host machine**: run ToyVolts > **Online** > **Host a game** (port 7777) > pick settings >
  **START**.
- **Friend**: run ToyVolts > **Online** > Join box: `100.101.102.103:7777` > **Join**.

That is all. Tailscale traffic is encrypted end to end; latency is usually within 5-10 ms of
the direct route. If Tailscale reports "relayed" (DERP) the connection still works, just with a
bit more delay.

## Friends over the internet: port forwarding (the manual way)

Only the host needs this.

1. Give the host machine a fixed LAN address (router DHCP reservation), say `192.168.1.23`.
2. Router admin page > Port Forwarding / Virtual Server: external port **7777 UDP** ->
   internal `192.168.1.23`, port 7777, protocol UDP.
3. Allow `ToyVolts.exe` (UDP 7777) through Windows Firewall.
4. Find your public address (search "what is my ip") and give friends `PUBLIC_IP:7777`.
5. If your ISP uses CGNAT (public address starts with `100.64`-`100.127` or the router's WAN
   address is private), port forwarding cannot work; use Tailscale.

## Dedicated headless server (optional)

A host that nobody plays on, for example on a spare PC or a VPS:

```
ToyVolts.exe --headless -- --server --port=7777 --map=diner --mode=ctb --bots=3 --difficulty=normal
```

(Godot engine flags go before `--`, game flags after it.) The server starts the match at once;
players join with **Online** > Join `address:7777` and spawn straight in. Modes: `ffa`, `tdm`,
`elim`, `ctb`; maps: `toy_room`, `diner`. Stop it with Ctrl+C.

Host with a window and skip the lobby (useful for testing):

```
ToyVolts.exe -- --host --port=7777 --map=diner --mode=ctb --bots=3
ToyVolts.exe -- --join=127.0.0.1:7777
```

## What the network does (for the curious)

- The host simulates everything at 60 Hz. Clients send one 44-byte input packet per tick
  (look, move, buttons, weapon select, aim ray) and receive a snapshot per tick (position,
  velocity, look, weapon, hp, ammo for every toy). Hits are raycast on the host from the
  client's aim ray.
- Your own toy is predicted locally: movement and weapon swaps never wait for the network.
  The host's snapshot is compared with where you predicted you were at that input; small
  differences are eased out over a few ticks, big ones (a rocket knocked you) snap.
- Other toys interpolate between snapshots ~80 ms behind the newest one.
- Muzzle flash, tracer and swing play at once when you fire; the hit marker, damage numbers,
  kills, pickups, battery and match events arrive from the host as reliable events.
- `tools/net_test.sh` runs a headless host and client on this machine and checks the whole
  handshake plus a confirmed hit. The HUD shows `ping` (client) or `hosting N` (host) next to
  the fps counter.

## Troubleshooting

| Symptom | Check |
|---|---|
| "Connection failed" at once | Wrong address/port, host not in the lobby yet, or firewall on the host. |
| Connects, then "The host left" | The host closed the game or went back to the menu. |
| Rubber-banding | Ping above ~150 ms or packet loss; the HUD ping tells. Prefer Tailscale direct (not relayed) or a wired connection. |
| Everyone lags on the host machine | The host needs headroom: Esc > Settings > Low on weak GPUs; the simulation is cheap, rendering is not. |
