# MICROVOLTS: Recharged — Reference Document

Research reference for **ToyVolts**, a Godot 4.7 clone of **MICROVOLTS: Recharged**
(Masangsoft, Steam appid `1426440`, released Sept 8 2023, source:
https://store.steampowered.com/app/1426440/MICROVOLTS_Recharged/). Original game:
**MicroVolts** by SK iMedia, published by Rock Hippo Productions, released June 9 2011,
shut down ~Sept 2017; Masangsoft relaunched the IP as Recharged (source:
https://en.wikipedia.org/wiki/MicroVolts).

**How to read this**: every number is followed inline by `(source: URL)`. Unfound
numbers are marked **UNKNOWN — no source found**, or given as a labeled community
**(estimate, no hard source)** — nothing is invented. Two source generations exist and
sometimes conflict: legacy 2011-2017 (`microvolts.fandom.com`, `mvs.fandom.com`,
Wikipedia) vs. current Recharged (`mv.masanggames.com`, Steam). **Fandom weapon stat
tables use internal relative game units** ("Power 208," "Firing Rate 945") — not
real-world damage/RPM/meters; no source converts them. **Sourcing limitation**: Fandom
and web.archive.org returned HTTP 402/blocked to direct fetch this session; that content
came via a `r.jina.ai` proxy (partial success) or search-engine snippets, flagged inline.

---

## 1. Weapon table

MicroVolts has dozens of stat-differentiated skins per slot; *"higher price tag does not
increase stats; only appearance changes"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
Tables give the fullest stat block found per class (relative units, see caveat above); a
"typical/base" row is the first/default model.

**Melee**: left-click = light attack; right-click = "Secondary Power," a slow, much
stronger hit — *"can almost kill them instantly"* but not a reliable one-shot (source:
https://mvs.fandom.com/wiki/Melees via r.jina.ai). Light-combo hit count, per-hit damage:
**UNKNOWN**. Range: very short, no ammo (source: https://microvolts.fandom.com/wiki/Melee).
Confirmed run-speed bonus while equipped; legacy relative "Run Speed" stat: Folding
Shovel (default) 20, Mad Wrench 40, Steel Hammer 60 (source:
https://microvoltsguides.wordpress.com/2011/05/22/80/). **Double jump confirmed**: only
available with melee equipped — *"you should have your melee weapon equipped in order to
perform a double jump"* (source: https://microvolts.fandom.com/wiki/Melee via search
snippet); switching to melee **mid-air** grants the jump instantly — *"you add a press of
the spacebar as you switch to your melee weapon"* (source: WebSearch summary of same
page) — root of "wave-stepping" (Section 4). Tuning: Power, or Run Speed/Range (source:
https://mv.masanggames.com/MV_GUIDE/1196629).

**Rifle** — Power/Firing Rate/Accuracy (source: https://microvolts.fandom.com/wiki/Rifle
via r.jina.ai):

| Model | Power | Firing Rate | Accuracy |
|---|---|---|---|
| Cricket (base) | 17 | 80 | 70 |
| Hornet | 208 | 945 | 790 |
| Hyperion | 288 | 950 | 855 |
| Laser of Exactitude | 288 | 1000 | 1000 |

Clip/reserve/reload/RPM/headshot rule/range: **UNKNOWN**. Has a mild ADS zoom with
reduced sensitivity (source: WebSearch summary of https://microvolts.fandom.com/wiki/Rifle).
Qualitative: *"versatile... fast and accurate damage"* (source:
https://mv.masanggames.com/MV_WEAPONS). Tuning: Accuracy or Ammo.

**Shotgun** — Power/Firing Rate/Accuracy/Reload/Mag/Reserve (source:
https://microvolts.fandom.com/wiki/Shotgun via r.jina.ai):

| Model | Power | Firing Rate | Accuracy | Reload | Mag | Reserve |
|---|---|---|---|---|---|---|
| Zolo (base) | 810 | 375 | 550 | 300 | 3 | 6 |
| Driver | 1020 | 325 | 620 | 325 | 2 | 8 |
| AC-ME Cannon | 870 | 275 | 450 | 250 | 3 | 6 |

Mag/reserve ratios above are real (3+6 = 2 reloads' worth); pellet count, spread,
falloff, knockback: **UNKNOWN**. *"Strong at close range... low accuracy at distance"*
(source: https://mv.masanggames.com/MV_WEAPONS). Tuning: Firing Rate or Reload Speed.
Signature tech: "Shotgun Quick Shoot" (Section 4).

**Sniper Rifle** — Power/Firing Rate/Zoom Speed/Zoom stages (source:
https://microvolts.fandom.com/wiki/Sniper_Rifle via r.jina.ai):

| Model | Power | Firing Rate | Zoom Speed | Zoom stages |
|---|---|---|---|---|
| Jam (base) | 700 | 5 | 500 | 1 |
| Sea Eagle | 1100 | 5 | 500 | 1 |
| Venom | 1100 | 5 | 500 | **2 (double zoom)** |

**"4x then 8x" is unverified folklore — (estimate, no hard source), not a documented
spec.** Confirmed: most models have **one** zoom stage; a named minority (Venom) have a
double zoom, and community meta **prefers single-zoom**: *"the B's double scope gets in
the way in such fast-paced game"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
No numeric headshot multiplier found — sniper is framed as a binary one-shot-kill weapon;
the max-power single-zoom "D" variant *"achieves one-shot kills on body shots"* too, not
just headshots (same source). Unscoped damage confirmed much lower (*"firing without
scoping greatly reduces the damage"*, source: WebSearch summary of Sniper_Rifle page); one
legacy page gives unscoped damage "about 200" relative units **(estimate, legacy, not
confirmed for Recharged)** (source: https://mvs.fandom.com/wiki/Snipers via r.jina.ai).
Sensitivity drops sharply while scoped; Recharged added an adjustable zoom-sensitivity
setting (source: https://mv.masanggames.com/MV_NEW_CHANGES). Swapping cancels scope
state. Clip/reserve/RPM/reload: **UNKNOWN**. Tuning: Zoom Speed or Reload Speed.

**Gatling Gun** — Power/Warm-Up/Run Speed/Accuracy/Ammo (source:
https://microvolts.fandom.com/wiki/Gatling_Gun via r.jina.ai):

| Model | Power | Warm-Up | Run Speed | Accuracy | Ammo (clip/reserve) |
|---|---|---|---|---|---|
| MicroGun (base) | 400 | 655 | 500 | 500 | 120 / 0 |
| Firefly | 560 | 655 | 540 | 500 | 120 / 0 |
| Crank | 640 | 477 | 500 | 400 | 120 / 0 |

`X/0` ammo implies no spare-magazine reserve (reload = full refill). Spin-up confirmed:
*"period of time when the Gatling Gun starts spinning its barrel, before bullets are
actually fired"* — and **resets if you jump or fall while holding fire** (source: same
wiki page). Overheat confirmed: a circular bar around the crosshair fills and halts
firing until it drains; burst-fire avoids it (same page). Exact shot-count/cooldown-time:
**UNKNOWN**. Tuning: Warm-Up Speed or Speed while Firing. A closed-beta Gatling
swap-cancel exploit ("Heavy-Step") was deliberately patched out for being overpowered
(Section 4).

**Bazooka** — Power/Firing Rate/Blast Radius/Bullet Speed/Reload (source:
https://microvolts.fandom.com/wiki/Bazooka via r.jina.ai):

| Model | Power | Firing Rate | Blast Radius | Reload |
|---|---|---|---|---|
| Sting Ray (base) | 360 | 500 | 350 | 375 |
| Pocket Rocket | 500 | 15 | 45 | 250 |
| Mimic | 400 | 35 | 35 | 500 |

Documented tradeoff: Pocket Rocket = slowest fire, biggest blast; Mimic = fastest fire,
smallest blast/lowest damage (same page). Explodes on any impact, capable of direct
hits. **Splash falloff, self-damage, rocket-jump potential: UNKNOWN — no source found
despite targeted searches; total silence on both weapon pages suggests self-damage
likely does not exist, but this is inference, not confirmation.** Clip/reserve:
**UNKNOWN**. Tuning: Firing Rate or Bullet Speed.

**Grenade Launcher** — Power/Firing Rate/Range (source:
https://microvolts.fandom.com/wiki/Grenade_Launcher via r.jina.ai):

| Model | Power | Firing Rate | Range |
|---|---|---|---|
| Hot Dog (base) | 550 | 350 | 570 |
| Pulse | 600 | 400 | 635 |
| Exile | 750 | 450 | 570 |

Arched, gravity-affected trajectory for shooting around cover. **Does NOT detonate on
player contact** — *"the grenade does not explode on contact. Instead, in case the
grenade hits a wall, ceiling or floor it will trigger the delay [fuse]"* (source: same
wiki page). Fuse length varies by model (Pulse fast, Exile mid) but exact seconds:
**UNKNOWN**. 2013 update reduced arc trajectory. Clip/reload/bounce physics: **UNKNOWN**.
Tuning: Firing Rate or Blast Radius.

**Cross-weapon tuning (Recharged)**: one chosen stat boost at a time per weapon, cost
disputed between sources (10 MP+400 Energy per Steam guide vs. 40 MP+400 Battery per
official guide, source: https://mv.masanggames.com/MV_GUIDE/1196629 vs.
https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).

**Draw/swap time**: no numeric equip-time found for any weapon/generation. Confirmed
qualitatively that equip speed differs per weapon and matters — drawing has a visible
windup, *"pulls it up from their waist until it's aiming straight forward"* before it can
fire (source: WebSearch snippet of https://mvs.fandom.com/wiki/Tips_%26_Tricks). A
removed legacy accessory ("hands") used to add +10% equip speed. **Exact per-weapon draw
times: UNKNOWN everywhere.**

---

## 2. Movement

- **Scale**: no numeric height/scale anywhere. Qualitative only: *"makes you feel like a
  small toy in a big world"* (source: http://mikedot.blogspot.com/2011/05/microvolts-review.html);
  figures fight "from desk tops to outdoor settings" (source:
  https://mv.masanggames.com/MV_MAPS). **UNKNOWN, no number.**
- **Run speed**: **UNKNOWN — no m/s value anywhere.** Only relative gear modifiers exist
  (melee "Run Speed" stat 20-60, source: microvoltsguides.wordpress.com/2011/05/22/80/;
  character passives like "Naomi +2.0% run speed," source: en.wikipedia.org/wiki/MicroVolts).
- **Jump**: no height number; **UNKNOWN**. Single jump on Space Bar (source:
  https://www.magicgameworld.com/controls-for-microvolts-recharged/ via search snippet).
  Maps have "Super Jump" pads/cannons as level features (confirmed via Steam achievements,
  source: https://steamcommunity.com/stats/1426440/achievements).
- **Double jump — confirmed**: only with melee equipped (*"can jump twice"*, source:
  microvolts.fandom.com/wiki/Melee via search snippet); tracked by achievement "Jump
  jump jump!: Double jump 100 times in one match" (source: steamcommunity.com/stats/1426440/achievements).
- **Melee-drawn mid-air grants it instantly** — confirmed, root of wave-stepping (Section 4).
- **Air control**: no explicit statement; indirect evidence jumping reduces accuracy,
  implying airborne aiming/movement is expected (source: steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
  **UNKNOWN beyond that.**
- **Sprint**: absent from every control list checked — inferred absent, not explicitly denied.
- **Crouch — DOES exist, contrary to a "no crouch" assumption.** Bound to **L-CTRL**
  (source: magicgameworld.com control list via search snippet), corroborated by a 2011
  review's loop description: *"you run, you shoot, you jump, you shoot, you crouch"*
  (source: mikedot.blogspot.com/2011/05/microvolts-review.html). Mechanical effect
  (hitbox/accuracy): **UNKNOWN**.
- **Dash/dodge**: no dedicated ability found; closest is repeated melee double-jumping
  used as informal "dodging, bunny hopping" (source: microvoltsguides.wordpress.com/2011/05/22/80/).
- **Ladders**: **none found**. Maps use Super Jump pads and jump-onto-geometry instead;
  some maps add specific climbable objects (e.g. Bitmap 2's PC towers, source:
  mv.masanggames.com/MV_MAPS).

---

## 3. Camera

Third-person confirmed as a marketed core feature (source: https://www.mmobomb.com/review/microvolts;
https://en.wikipedia.org/wiki/MicroVolts). Community notes the camera framing itself is
tactical: *"players can hide near a corner and watch without being seen. Very handy for
sniping"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
**Shoulder side: UNKNOWN** — no source states left vs. right default; the game does have
manual camera-orbit arrow keys alongside mouse-look, implying player-adjustable framing
(source: WebSearch summary of magicgameworld.com control list). **FOV: UNKNOWN — no
value found anywhere.** Rifle has a mild zoom/ADS with reduced sensitivity, no
magnification number given. **Sniper "4x/8x" unverified** — see Section 1; most models
single-zoom, some (Venom) double-zoom, community prefers single-zoom. Sensitivity
**confirmed to scale down** while scoped/zoomed; Recharged added a player-adjustable
zoom-sensitivity setting (source: https://mv.masanggames.com/MV_NEW_CHANGES). Swapping
weapons cancels scope state.

---

## 4. Swap / wave-step / advanced mechanics

**Weapon swapping (swap-cancel)**: core documented mechanic — switching between two+
weapons to fire faster than either's native rate (source: https://mvs.fandom.com/wiki/Tips_%26_Tricks
via r.jina.ai). One source states it **only works with Shotgun, Bazooka, and Grenade
Launcher**. Execution: hold fire down through the swap, use separate keybinds per
weapon, time it to when the draw animation "aims straight forward" (same page). Tactic:
Bazooka splash-knockback into Shotgun (same page). **Recharged confirms it persists** —
"Shotgun Quick Shoot": *"right after shooting any shotgun and holding left click down,
quickly tapping the swap key twice reduces the time between shots"* (source:
steamcommunity.com/sharedfiles/filedetails/?id=3034418362). A Gatling-specific
swap-cancel exploit ("Heavy-Step") existed only in closed beta and was deliberately
disabled for being overpowered (source: mvs.fandom.com/wiki/Tips_%26_Tricks) — precedent
that swap-cancel breadth is an actively-balanced lever, not universal by default.

**Wave step / wavestepping**: named, deep community tech — *"manipulating the melee
double jump to execute two airborne shots"* (source:
http://fantasysportsvideogames.blogspot.com/2013/01/microvolts-wavestepping-guide.html).
Taught progression: (1) master plain swapping, (2) static wavestep, easiest on shotgun,
(3) directional (4-way) wavesteps, (4) full 360°, (5) advanced rocket/grenade
wavesteps — good for firing "a barrage of rockets" from height, causing enemy
*"confusion lasting 2-3 seconds or longer if hits connect"* (same blog). Estimated
learning time "less than an hour... up to a week" (same source). Downsides: sniper
vulnerability while fixated, can look like cheating to opponents. One source claims
ground wavestepping is limited to three weapons (Zolo, Pulse, KW-79) — **internally
ambiguous**, since Pulse is a Grenade Launcher model elsewhere on the same wiki system.
**Confirmed still relevant in Recharged**: *"swap and wavestep mechanics are essential to
improve"*, best practiced in AI Battle (no stat impact) (source:
steamcommunity.com/sharedfiles/filedetails/?id=3034418362).

**Ninja-swap**: confirmed to exist as a named, distinct technique (grouped with
swap/wavestep in tutorial titles), but **its exact definition is UNKNOWN — no text
source explains it**; all explanations sit in unreachable YouTube videos. **(estimate,
no hard source)**: likely a faster/more disguised swap-cancel variant, by naming
convention — not confirmed.

**Quickscoping / Dragshoting**: confirmed named tactics. Quickscope = aim, zoom, adjust,
fire while zoomed, for close/mid range (source: WebSearch summary of
microvolts.fandom.com/wiki/Sniper_Rifle); *"sometimes it's one hit kill"* (source:
steamcommunity.com/sharedfiles/filedetails/?id=167804504). Dragshoting = drag your aim
onto target regardless of scope state (same source). Firing too early on a double-zoom
scope drops damage to no-scope levels (source: mvs.fandom.com/wiki/Snipers via r.jina.ai).

**Rocket jumping**: **UNKNOWN — no evidence found it exists**; total silence on
self-damage across both explosive weapon pages suggests it most likely does not.

**Shotgun-jump combos**: no distinct named self-knockback tech found beyond "Shotgun
Quick Shoot" and shotgun being the recommended training weapon for wavestepping.

**Bunny hopping**: **not documented as a distinct MicroVolts tech** — search hits were
all other games (one candidate guide confirmed to be Left 4 Dead 2, source:
steamcommunity.com/sharedfiles/filedetails/?id=3429794997, excluded). The community's
"bunny hopping" language appears to mean informal melee-double-jump dodging, not a
CS-style strafe-jump mechanic.

**Other named mechanics**: corner-peek sniping (third-person camera lets you watch from
cover unseen, source: steamcommunity.com/sharedfiles/filedetails/?id=3034418362);
scope-cancel via swap (repeated from Section 3).

---

## 5. HUD layout

**Exact HUD positions are essentially undocumented anywhere** — no source gives a HUD
teardown for this game; a gameplay-video pass would be needed for real positions.

| Element | Finding |
|---|---|
| HP bar | **UNKNOWN** |
| Ammo count | **UNKNOWN** — Reload bound to R (source: magicgameworld.com control list, search snippet) |
| Weapon slots | Melee defaults slot 1, Rifle slot 2 (source: microvoltsguides.wordpress.com/2011/05/22/80/); mouse wheel also cycles weapons. Visual layout: **UNKNOWN** |
| Radar/minimap | Likely **not** a persistent HUD element — "Radar" is a time-limited item pickup (e.g. spawns at Elimination's 1-min mark), not a baseline minimap. Baseline compass: **UNKNOWN** |
| Kill feed | **UNKNOWN** presentation; multi-kill events are tracked (achievements "Double Kill Master," "Multi Kill Master," source: steamcommunity.com/stats/1426440/achievements) |
| Crosshair | A reactive/dynamic crosshair concept exists (*"despite dynamic crosshair not reacting, jumping does reduce accuracy"*, source: steamcommunity.com/sharedfiles/filedetails/?id=3034418362); per-weapon shapes: **UNKNOWN** |
| Damage/hit indicators | Directional damage indicator, hit-marker: **UNKNOWN — no source found** |
| Headshot indicator | Headshots are scored/tracked (Sniper/Rifle headshot achievements) but a distinct indicator: **UNKNOWN** |
| Kill popups | **UNKNOWN** presentation. An announcer figure "Colonel Crac" exists from the training stage (source: search snippet, page 402'd); in-match kill callouts unconfirmed |
| Scoreboard | Key and columns: **UNKNOWN — no source found** |

---

## 6. Modes

Source lists disagree on count: Wikipedia (legacy) lists 17 modes (source:
en.wikipedia.org/wiki/MicroVolts); a Fandom summary lists 11; the **current official
Recharged page lists only 6**: Team Deathmatch, Elimination, Zombie Mode, Capture the
Battery, Free for All, A.I. Battle (source: https://mv.masanggames.com/MV_MODES). Treat
the 6-mode list as current truth, rest as legacy/unconfirmed-current.

| Mode | Rules | Limits | Teams | Respawn | Special |
|---|---|---|---|---|---|
| Team Deathmatch | First to target score by kills (mv.masanggames.com/MV_MODES) | Score/time **UNKNOWN**; max match size 16 (mvs.fandom.com/wiki/Maps) | Team | Unlimited | — |
| Free For All | Solo, first to target score | **UNKNOWN** | Solo | Unlimited | — |
| Item Match (legacy) | Same as TDM but kills drop a random item (not map spawns); one item held, +optional Suicide Bomb (microvolts.fandom.com/wiki/Item_Match via search) | **UNKNOWN** | Team | Unlimited | Item pool: Health Boost +400HP, Team Heal +1000HP, Ammo Refill, Suicide Bomb, Power Potion, Shield, Hermes' Boots, Disguise (microvolts.fandom.com/wiki/Items via search) |
| Zombie Mode | 1-3 random "infected" scale w/ lobby size; infected melee-infect, rest survive/fight (microvolts.fandom.com/wiki/Zombie_Mode via search) | Infection clock counts down, no numeric limit found | Infected vs. rest | All spawn separately, 0 ammo except rifle | Ammo capsules spawn more as clock ticks; special weapons spawn mid-match |
| Capture the Battery | Steal enemy battery from their camp, deliver to yours (mv.masanggames.com/MV_MODES) | Target score **UNKNOWN** | 2 teams, 2 bases | Likely unlimited | Battery always visible even carried; capture grants team XP/MP bonus |
| Elimination | No respawn within a round; last team standing (mv.masanggames.com/MV_MODES) | **UNKNOWN** | Team | **None per round** | Radar power-up spawns center-map at halftime/1-min-left |
| Bomb Battle (legacy) | Elimination-style + plant/defuse at site A/B (microvolts.fandom.com/wiki/Bomb_Battle via search) | **UNKNOWN** | Offense/Defense | None mid-round | 2 bomb sites |
| Boss Battle (legacy, PvE) | 1-4 co-op vs. giant "Tracker" boss + adds (microvolts.fandom.com/wiki/Boss_Battle via search) | N/A | 1-4 co-op | **UNKNOWN** | Only on "Academy Invasion" map; loot box on win; **awards no XP/MP** |
| Close Combat (legacy) | Melee-only, "Chess" map only | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | Melee-only restriction |
| Arms Race (legacy) | FFA gun-game, kills force weapon tier-up | ~first-to-20 **(estimate)** | Up to 6, FFA | **UNKNOWN** | Tier ladder ~1=Rifle,5=Shotgun,8=Sniper,12=Gatling,14=Rocket,17=Grenade (estimate); melee tiers down/escapes |
| Scrimmage (legacy) | Shared team HP-pool gauge drains on damage | Gauge starts ~5000 HP (estimate) | Team | Death → "repair box" (unclear) | Reportedly least-played mode |
| Invasion (legacy, PvE) | Wave-clear, Easy=10 rounds, Hard=20, boss every 5th | N/A | **UNKNOWN** | **UNKNOWN** | Hard capped 3 plays/day |
| A.I. Battle | Practice vs. bots via Create Room | N/A | Solo practice | **UNKNOWN** | No XP/MP/kill tracking |

A "Practice/Square Mode" sandbox is also referenced. A "League" ranked system was
reportedly announced but the announcement page 401'd — title only, unverified (source:
https://www.gamespress.com/Masangsoft-Announces-Major-MICROVOLTS-Recharged-Update-with-New-League).

---

## 7. Room / lobby flow

**Least-documented area found** — no primary source gives a UI teardown.

- Channel system reportedly exists (regional EU/US servers) — **low confidence, no single source**.
- Separate test/beta server exists apart from live (source: mvs.fandom.com/wiki/Test_server via search).
- Room list fields: **UNKNOWN**.
- Room creation weapon-restriction options confirmed: All Weapons / Weapon Select
  (melee + 2 player-picked weapons) / Single Weapon (host picks one for all) — **medium confidence**.
- Map/mode gating confirmed: not all modes fit all maps due to size/spawn/objective placement.
- Max players: **16** (source: mvs.fandom.com/wiki/Maps — most solid figure found, single source).
- A.I. Battle selectable directly from Create Room (source: steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
- Ready-up, host-start, map voting/rotation, mid-match join, team balancing: **all UNKNOWN — no source found for any of them.**
- **Kicking — vote-kick confirmed, not simple host-kick.** Any player, even opposing
  team, can start a kick vote; documented complaint that *"enemy teams can kick players
  for no reason or for just being good,"* ~1-in-3-match kick-bans reported by one poster
  (source: https://mv-forum.masanggames.com/index.php?/topic/1714-vote-kick-system-needs-to-change/).
  A community fix proposal (teammates-only kicks, evidence required, abuse penalties) is
  unimplemented per the same thread.

---

## 8. Progression and shop

**Currencies**: **MP** (Micro Points, free, earned via K/D and match outcome; spent on
weapons, tuning, Limited Capsule pulls) and **RT**/"RT Coin" (premium, real-money;
Capsule Machine, membership, cosmetics) (source: en.wikipedia.org/wiki/MicroVolts).
**Battery** (in-game resource, distinct from the CTB object) required with MP to tune
gear; membership grants unlimited Battery (source: mv.masanggames.com/MV_NEW_CHANGES).
**Energy**: tuning costs 400 Energy + 10 MP per the Steam guide (source:
steamcommunity.com/sharedfiles/filedetails/?id=3034418362).

**Capsule machine**: RT-based, **1,000 RT/pull ("~$1")** (legacy figure, source:
en.wikipedia.org/wiki/MicroVolts); legacy rare-drop estimates ~1:75 weapons, ~1:25
clothing (same source). MP-based "Limited Capsule": **2,300 MP/pull**, shared community
pool (fixed stock per rarity, odds improve as others pull), 24-hour window, up to 20
capsules per purchase (source: steamcommunity.com/sharedfiles/filedetails/?id=3034418362,
mv.masanggames.com/MV_GUIDE/1196635). Current capsules split Seasonal/Standard with an
in-game drop-rate viewer (source: mv.masanggames.com/MV_GUIDE/1196736).

**Weapon upgrades**: lettered A/B/C/D variants with different fixed stats; tuning system
(one stat boost at a time, re-tunable). Legacy had a level-9 upgrade system with
failure/downgrade risk (added Nov 2011, source: en.wikipedia.org/wiki/MicroVolts) —
**Recharged removed this "Evolution system"** for the current MP+Battery tuning,
marketed as "no longer pay-to-win" (source: mv.masanggames.com/MV_NEW_CHANGES).

**Parts customization**: legacy 7-slot list — Hair, Face, Top, Bottom, Hands, Shoes,
Accessories, each affecting stats like run speed/HP/ammo (source:
en.wikipedia.org/wiki/MicroVolts). Recharged store page cites "ten unique costume parts"
without naming slots (source: store.steampowered.com/app/1426440/). **Net**: 7-slot list
confirmed for legacy, likely-but-unconfirmed continuity into Recharged.

**Characters**: 9 named, each with in-fiction lore (source: mv.masanggames.com/MV_FIGURES):
Naomi (anime heroine, guitarist), Knox (sports-game receiver, "The Wild"), C.H.I.P.
(limited-edition figure), Kai (young rocket scientist), Pandora ("Sealed Devil"),
Sophitia (priest/swordfighter), $harkill Khan (DJ), Simon (cyborg protagonist), Amelia
(high-elf knight, rapier). Free-starter vs. premium split: **UNKNOWN**.

**Rentals**: MP-tier weapons rentable 7 or 30 days; RT-tier weapons 1/7/30 days; both
also offer an "Unlimited"/permanent option needing post-match repair (source: WebSearch
synthesis of microvolts.fandom.com/wiki/Shop). Accessories rentable 1-30 days
(historically up to 90). Capsule-machine accessories are permanent by default.

**Daily rewards / battle pass**: daily login grants MP, scaling with streak (medium
confidence). No traditional tiered battle pass found — instead recurring **seasonal
"Starter Pack" DLCs** (Silver/Gold/Platinum) bundling membership + RT + cosmetics.
Confirmed 2026 Spring pricing: Silver ₪18.50 = 15-day membership + 1,000 RT + 1
accessory (source: store.steampowered.com/app/4493610/...Silver/); Platinum ₪189.95 =
30-day membership + 3,000 RT + 7-piece set + a skin (source:
store.steampowered.com/app/4493580/...Platinum/). Membership benefits: daily RT reward,
unlimited Battery, extra equipment presets (2 free / 4 member), extra missions.

---

## 9. Maps worth cloning next

**Toy-scale framing**: figures fight *"an all out war for valuable battery resources and
supremacy of the Micro World"* (source: mmobomb.com/news/...microvolts-recharged;
en.wikipedia.org/wiki/MicroVolts), in-fiction framed as **Hyuga High School's figure
club** — dioramas span *"chessboards, schools, war-destroyed towns, gardens, ships, toy
boxes"* (en.wikipedia.org/wiki/MicroVolts). Official copy: *"the little things you
overlook... can become crucial keys"*, battles happen *"across desks, areas beneath
chairs, and other domestic spaces"* (mv.masanggames.com/MV_ABOUT_GAME); marketing:
*"battle it out in the bedroom, kitchen, garden or even entire neighbourhoods!"*
(f2pg.com/microvolts/). A period review: *"climbing on plates and forks to hiding in
coffee cups... the terrain is from the perspective of a toy"* (mmos.com/review/microvolts).
Not all modes fit all maps (size/spawn/objective placement gates it). **Max match size:
16 players** (mvs.fandom.com/wiki/Maps).

Several requested names don't exist under those titles in the official 31-map roster,
Wikipedia's 28, or the Fandom Maps category (~32 pages) — closest analogs noted, not
confirmed content.

| # | Requested | Status | Real name |
|---|---|---|---|
| 1 | Toy Fort | UNKNOWN | — (closest: Castle) |
| 2 | Bitmap | Confirmed | Bitmap / Bitmap 2 |
| 3 | Hobby Shop | Confirmed, thin | Hobby Shop |
| 4 | Ship Cabin | UNKNOWN | — (closest: Model Ship, Toy Fleet) |
| 5 | Toy Garden | Confirmed, thin | Toy Garden / Toy Garden 2 |
| 6 | Neighborhood | Confirmed | Neighborhood |
| 7 | Kitchen | UNKNOWN | — |
| 8 | Garage | UNKNOWN | — |
| 9 | Studio | Confirmed | The Studio |
| 10 | School | Confirmed | Girls' High School / Academy |
| 11 | Skate Park | UNKNOWN | — |
| 12 | Playground | UNKNOWN | — (closest: Rumpus Room) |
| 13 | Museum | UNKNOWN | — |
| 14 | Christmas | UNKNOWN | — (unverified lead: "Fruitys Christmas Renovation" event) |

- **Bitmap**: office/PC desk of a game company's art team (mv.masanggames.com/MV_MAPS);
  "battle your way to employee of the month" (mvs.fandom.com/wiki/Bitmap via r.jina.ai).
  Bitmap 2 adds climbable PC towers. Modes: TDM, FFA, Elimination, Item Match, Scrimmage,
  Close Combat, Arms Race, Sniper Mode, Square Mode — **no CTB**. Associated with
  sniper-heavy play in community video titles. Layout/spawn: **UNKNOWN**.
- **Hobby Shop**: "a cafe loved by figure lovers," after-hours collector battles
  (mv.masanggames.com/MV_MAPS). Likely a night-lit variant (low confidence). Layout: **UNKNOWN**.
- **Toy Garden**: outdoor garden, "a pond flowing under a sturdy and beautiful stone
  bridge" — a natural elevation/chokepoint over water (mv.masanggames.com/MV_MAPS). Night
  variant Toy Garden 2 adds jump pads. Layout beyond the bridge: **UNKNOWN**.
- **Neighborhood**: "a general family house theme," two connected neighboring houses
  (mv.masanggames.com/MV_MAPS). Layout: many parallel traversal routes between houses —
  windowsill jump pads, a pipe route, through cupboards, across "the patio cooler," plus
  spawn-area jump pads (mvs.fandom.com/wiki/Neighborhood via r.jina.ai). **Explicitly
  called out as CTB-friendly**: *"many ways to get across from house to house... effective
  for CTB"* (same source) — the clearest "what makes it fun" data point in this whole
  research pass. Modes: CTB, FFA, TDM, Zombie, Elimination, Item Match, Scrimmage, Arms
  Race, Bomb Battle.
- **The Studio**: "a diorama production studio" with production supplies as terrain
  (mv.masanggames.com/MV_MAPS); signature landmark — *"a creepy clown looking down at you
  as you play"* (mvs.fandom.com/wiki/The_Studio via r.jina.ai). 12 modes supported. Layout
  beyond the clown landmark: **UNKNOWN**.
- **School**: "Girls' High School" (current) / "Academy" (legacy) — "school setting with
  a gym in the middle" (mv.masanggames.com/MV_MAPS); central gym reached via stairs,
  flagged as strong high-ground (mvs.fandom.com/wiki/Academy via r.jina.ai) — consistent
  with (not explicitly confirmed as) a symmetric two-wing layout converging on the gym.
  12 modes supported. "Academy Invasion" variant used for Boss Battle.
- **Closest analogs**: **Castle** (Toy Fort) — "figure-scale castle in the middle of
  production." **Model Ship** (Ship Cabin) — asymmetric two-deck map, upper open/lower
  heavy-cover corridors, rope-bridge overlook, *"the only map where spawning and the
  whole map isn't mostly symmetrical"* (mvs.fandom.com/wiki/Model_Ship via r.jina.ai);
  **Toy Fleet** is a separate ship map noted for high sniper positions. **Rumpus Room**
  (Playground) — "a playroom made of polyurethane," indoor with blocks/toy trucks, not an
  outdoor playground (mv.masanggames.com/MV_MAPS, f2p.com/microvolts-a-new-map-and-good-old-items/).

---

## 10. Ranked gap list — what ToyVolts still does differently

Ranked by estimated impact on the MicroVolts feel, based on the ToyVolts current-state
facts against the sourced findings above.

1. **Wave-step depth**: MicroVolts wavestepping is a taught skill ladder — static →
   directional (4-way) → 360° → per-weapon variants with a 2-3s enemy "confusion" debuff
   on connecting hits (source: fantasysportsvideogames.blogspot.com). ToyVolts has one
   fixed melee-drawn double jump at 0.92x, no directional/360 variants, no debuff. Highest-
   impact gap since this tech defines skilled Microvolts play.
2. **Grenade Launcher detonation mismatch**: source confirms grenades do **not** detonate
   on player contact, only on wall/ceiling/floor hits triggering a fuse (source:
   microvolts.fandom.com/wiki/Grenade_Launcher). ToyVolts detonates on player contact
   *or* a 2.0s fuse — an un-sourced direct-hit-kills-instantly behavior.
3. **Bazooka self-damage is undocumented/likely absent** (inference from total silence
   on both weapon pages) — ToyVolts' `self damage x0.5` and implied rocket-jump potential
   has no confirmed Microvolts precedent.
4. **Swap-cancel breadth**: source says swap-cancel *"only works with Shotgun, Bazooka,
   and Grenade Launcher"*, and a Gatling swap exploit was deliberately disabled as OP
   (source: mvs.fandom.com/wiki/Tips_%26_Tricks). ToyVolts applies universal swap-cancel
   across all 7 weapons including Gatling and Sniper.
5. **Sniper scope-stage mismatch**: most models are single-zoom; community actually
   prefers single-zoom over double ("gets in the way"). ToyVolts hard-codes an always-on
   two-stage zoom (FOV 18→9) — opposite the documented preference; "4x/8x" itself is
   unverified folklore.
6. **Radar as permanent HUD vs. limited pickup**: source Radar is a time-limited item
   pickup, not a baseline minimap. ToyVolts has a permanent top-left radar always on —
   a different information-availability balance.
7. **Crouch is missing**: source confirms a bound crouch key (L-CTRL), contrary to a
   "no crouch" assumption. ToyVolts has no crouch at all.
8. **Gatling warm-up doesn't reset on airborne fire**: source resets spin-up on jump/fall
   while firing, penalizing airborne Gatling use; ToyVolts' 0.45s spin-up has no such interaction.
9. **No weapon-variant/tuning system**: source has dozens of lettered stat-variants per
   slot plus a two-choice tuning system per weapon; ToyVolts has one fixed stat block —
   a large progression gap, lower priority than the combat-feel items above.
10. **Missing modes**: ToyVolts lacks Item Match (kill-drop items) and Zombie Mode
    (infection + ammo-capsule tension), both confirmed current/legacy staples with
    well-documented rules, plus Bomb Battle and legacy Close Combat/Boss Battle/Scrimmage/Arms Race.
11. **No character roster or parts customization**: source has 9 named characters + a
    7-slot customization system + capsule gacha; ToyVolts has 4 generic KayKit skins,
    no shop — large gap, but already deferred to a "Later" milestone in the ToyVolts plan.
12. **No room list/lobby flow**: mostly undocumented for the source game too (low-confidence
    gap), but the one concrete feature found — a **vote-kick system** open to any player
    including opposing team (source: mv-forum.masanggames.com topic 1714) — is worth a
    deliberate design decision either way. ToyVolts currently has no room list/browser at all.

**Status after the 2026-09-02 session (v0.6)**: gap 1 partly closed - draw times are
now per weapon (0.15-0.4 s), presses during a draw are buffered, and a frame-accurate test
proves three shotgun shots in one airtime with the melee double jump; directional /
360-degree wave-steps work by construction (full air control) but no hit "confusion" debuff
exists. Gap 12: an ENet host/join lobby now exists (no room list, no vote-kick). Gaps 2-11
are untouched and remain the checklist for the next sessions.

---

## Sources

- https://store.steampowered.com/app/1426440/MICROVOLTS_Recharged/
- https://store.steampowered.com/news/app/1426440/view/3693569804225063063
- https://store.steampowered.com/app/4493610/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Silver/
- https://store.steampowered.com/app/4493600/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Gold/
- https://store.steampowered.com/app/4493580/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Platinum/
- https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362
- https://steamcommunity.com/sharedfiles/filedetails/?id=167804504
- https://steamcommunity.com/sharedfiles/filedetails/?id=3429794997 (checked, excluded — Left 4 Dead 2 guide, not MicroVolts)
- https://steamcommunity.com/stats/1426440/achievements
- https://steamcommunity.com/app/1426440/discussions/0/3942399239157052366/
- https://steamcommunity.com/app/1426440/discussions/0/3803904095525797642/
- https://steamcommunity.com/app/1426440/reviews/
- https://en.wikipedia.org/wiki/MicroVolts
- https://en.wikipedia.org/wiki/Microman (background analogy only)
- https://mv.masanggames.com/MV_WEAPONS
- https://mv.masanggames.com/MV_MODES
- https://mv.masanggames.com/MV_MAPS
- https://mv.masanggames.com/MV_ABOUT_GAME
- https://mv.masanggames.com/MV_FIGURES
- https://mv.masanggames.com/MV_FAQ
- https://mv.masanggames.com/MV_NEW_CHANGES
- https://mv.masanggames.com/MV_GUIDE/1196629
- https://mv.masanggames.com/MV_GUIDE/1196635
- https://mv.masanggames.com/MV_GUIDE/1196647
- https://mv.masanggames.com/MV_GUIDE/1196736
- https://mv-forum.masanggames.com/index.php?/topic/1714-vote-kick-system-needs-to-change/
- https://mv-forum.masanggames.com/index.php?/topic/2197-double-jump-and-achievement/
- https://microvolts.fandom.com/wiki/Rifle (r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Shotgun (r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Sniper_Rifle (r.jina.ai proxy / search snippet)
- https://microvolts.fandom.com/wiki/Melee (r.jina.ai proxy / search snippet)
- https://microvolts.fandom.com/wiki/Gatling_Gun (r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Bazooka (r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Grenade_Launcher (r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Colonel_Crac (search snippet, page 402'd)
- https://microvolts.fandom.com/wiki/Item_Match, Team_Death_Match, Capture_the_Battery, Zombie_Mode, Bomb_Battle, Boss_Battle, Arms_Race, Scrimmage, Invasion, Items, Shop, Category:Modes, Category:Maps, Selection_Screen (all search-snippet only, Fandom fetch blocked)
- https://mvs.fandom.com/wiki/Weapons (search snippet)
- https://mvs.fandom.com/wiki/Tips_&_Tricks (r.jina.ai proxy / search snippet)
- https://mvs.fandom.com/wiki/Melees (r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Snipers (r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Maps, Modes, Test_server, Frequently_Asked_Questions (search snippet only)
- https://mvs.fandom.com/wiki/Bitmap (r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Neighborhood (r.jina.ai proxy)
- https://mvs.fandom.com/wiki/The_Studio (r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Academy (r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Model_Ship (r.jina.ai proxy)
- http://fantasysportsvideogames.blogspot.com/2013/01/microvolts-wavestepping-guide.html
- https://guidescroll.com/2011/10/microvolts-wavestepping-guide/ (search snippet)
- http://orcz.com/MicroVolts:_Sniper_Rifles (search snippet, page 404'd)
- http://mikedot.blogspot.com/2011/05/microvolts-review.html
- https://www.mmobomb.com/review/microvolts
- https://www.mmobomb.com/news/third-person-toy-themed-lobby-shooter-microvolts-relaunches-microvolts-recharged
- https://mmos.com/review/microvolts
- https://www.f2pg.com/microvolts/
- https://www.f2p.com/microvolts-a-new-map-and-good-old-items/
- http://microvoltsurge.blogspot.com/p/maps.html
- https://microvoltsguides.wordpress.com/2011/05/22/80/
- https://microvoltsguides.wordpress.com/2011/05/19/close-combat-tips-and-tactics/
- https://www.magicgameworld.com/controls-for-microvolts-recharged/ (search snippet, direct fetch 403'd)
- https://gamepretty.com/microvolts-recharged-beginners-guide/
- https://gamerjournalist.com/microvolts-recharged-codes/ (synthesis only, not re-fetched)
- https://www.gamespress.com/Masangsoft-Announces-Major-MICROVOLTS-Recharged-Update-with-New-League (title only, body 401'd)
- https://combatarms.fandom.com/wiki/HUD (generic other-game reference only, not MicroVolts-specific)
- YouTube tutorial titles (title-only, transcripts unreachable): https://www.youtube.com/watch?v=d_rg6INEbZQ, watch?v=clCXTsHE9rs, watch?v=WJFUWeWWqKk, watch?v=CfZ6AK9Rmyk, watch?v=-6xT1nJPb4U, watch?v=e0Mj8ebmJYY, watch?v=N3SWEUKqaSs
