# MICROVOLTS: Recharged — Reference Document

Research reference for **ToyVolts**, a Godot 4.7 clone of the free Steam game
**MICROVOLTS: Recharged** (developer/publisher Masangsoft, Steam appid `1426440`,
released Sept 8, 2023 (source: https://store.steampowered.com/app/1426440/MICROVOLTS_Recharged/)).
The original game was **MicroVolts** by Korean studio SK iMedia, published in NA/EU by
Rock Hippo Productions, CBT Aug 2010, official release June 9 2011, engine Gamebryo+PhysX,
service shut down ~Sept 9 2017; Masangsoft later acquired the IP and relaunched it as
Recharged (source: https://en.wikipedia.org/wiki/MicroVolts). It is also known in
Japan/Korea under related "ToyBattles"/토이워 branding.

## How to read this document

- Every concrete number is followed inline by `(source: URL)`. Where no number could be
  found, that is stated explicitly as **UNKNOWN — no source found**, or given as a
  clearly labeled community **(estimate, no hard source)**.
- **Two generations of source material exist and sometimes conflict**: the legacy
  2011–2017 game (documented mostly on `microvolts.fandom.com` and `mvs.fandom.com`,
  the "MicroVoltsSurge" wiki, plus Wikipedia) vs. the 2023+ Masangsoft relaunch
  "MICROVOLTS: Recharged" (documented on `mv.masanggames.com` and the Steam store/community
  pages). Facts are labeled by generation wherever it matters; where Recharged-specific
  confirmation exists it is called out.
- **Weapon numeric stat tables on the Fandom wikis are internal relative game units**
  (e.g. "Power 208," "Firing Rate 945") — **not** real-world damage points, RPM, or
  meters. No source converts these to real-world units for any weapon. Treat all such
  tables as ranking/comparison data between weapon models, not literal damage-to-100-HP
  numbers.
- **Sourcing limitation**: `microvolts.fandom.com`, `mvs.fandom.com`, and
  `web.archive.org` returned HTTP 402/blocked to direct fetch tools in this research
  session (an environment-side block, not a missing-page 404). Fandom content below was
  recovered either through a `r.jina.ai` text-extraction proxy (worked partially) or
  through search-engine snippets/summaries of those pages — flagged inline as
  "via search snippet" where the raw page text could not be independently verified.

---

## 1. Weapon table

MicroVolts' item system has **dozens of purchasable weapon skins/models per slot**, each
with its own stat block; per Steam's own Recharged beginner's guide, *"higher price tag
does not increase stats; only appearance changes"* — stats are tied to the specific
model/variant, not the price tier (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
Tables below give the fullest available stat block per class (relative units, see caveat
above) plus every qualitative mechanic that could be confirmed. A "typical/base" row is
the first-listed/default model per class.

### Melee

| Aspect | Finding |
|---|---|
| Attack types | Left-click = moderate "light" attack; right-click = "Secondary Power," a slower, much stronger hit described as "can almost kill them instantly" but does **not** consistently one-shot (source: https://mvs.fandom.com/wiki/Melees via r.jina.ai proxy) |
| Light-attack combo count | **UNKNOWN — no source found.** No page documents a numbered combo chain (e.g. "3-hit combo"); searched explicitly with no results |
| Per-hit damage numbers | **UNKNOWN — no source found** (wiki stat blocks are image-based, not machine-readable text) |
| Range | Very short — "get nice and close to your target" (source: https://mvs.fandom.com/wiki/Melees via r.jina.ai) |
| Ammo | None required (source: https://microvolts.fandom.com/wiki/Melee via r.jina.ai) |
| Movement bonus | Confirmed — equipping melee increases run speed ("light weight increases your speed in battle"); default weapon (Folding Shovel) flavor text: "increases movement speed so you can whack more enemies" (source: https://mvs.fandom.com/wiki/Melees via r.jina.ai) |
| Relative "Run Speed" stat by model (legacy game) | Folding Shovel (default) 20, Mad Wrench 40, Steel Hammer 60, Chain Saw 20, ADV Mad Wrench 50, ADV Chain Saw 30 — internal relative units (source: https://microvoltsguides.wordpress.com/2011/05/22/80/) |
| Double jump | **Confirmed**: equipping/drawing melee grants a double jump. "Melee weapons attack lightly and quickly, and can jump twice"; "you should have your melee weapon equipped in order to perform a double jump" (source: https://microvolts.fandom.com/wiki/Melee via search snippet) |
| Melee-drawn-mid-air trick | Confirmed: switching to melee *while airborne* instantly grants the extra jump — "to pull off this move, you add a press of the spacebar as you switch to your melee weapon"; this is the mechanical root of community "wave-stepping" (source: WebSearch summary of https://microvolts.fandom.com/wiki/Melee) — see Section 4 |
| Tuning (Recharged) | Melee can be tuned for Power, or Run Speed / Range (3-way option set per one source) (source: https://mv.masanggames.com/MV_GUIDE/1196629) |

### Rifle (Assault Rifle)

Stat block on the wiki = **Power / Firing Rate / Accuracy** (relative units, source:
https://microvolts.fandom.com/wiki/Rifle via r.jina.ai proxy):

| Model | Power | Firing Rate | Accuracy |
|---|---|---|---|
| Cricket (early/base) | 17 | 80 | 70 |
| Pepper | 17 | 90 | 85 |
| Sherlock | 25 | 80 | 65 |
| Hornet | 208 | 945 | 790 |
| Gold Rifle | 213 | 955 | 830 |
| Hyperion | 288 | 950 | 855 |
| Laser of Exactitude | 288 | 1000 | 1000 |

Clip size, reserve ammo, reload time, true RPM, headshot multiplier, and range/falloff:
**UNKNOWN — no numeric source found** for any Rifle model. Qualitative Steam description:
*"versatile weapon that deals fast and accurate damage... agility without restriction of
movement"* (source: https://mv.masanggames.com/MV_WEAPONS). Rifle also has a **mild
zoom/ADS mode**: *"Rifles have a secondary 'mode' where it zooms in a small amount, and
the cursor sensitivity is greatly reduced while zooming in"* (source: WebSearch summary
of https://microvolts.fandom.com/wiki/Rifle). Recharged tuning: Accuracy or Ammo
(source: https://mv.masanggames.com/MV_GUIDE/1196629).

### Shotgun

Stat block = **Power / Firing Rate / Accuracy / Reload / Magazine / Reserve** (source:
https://microvolts.fandom.com/wiki/Shotgun via r.jina.ai proxy):

| Model | Power | Firing Rate | Accuracy | Reload | Mag | Reserve |
|---|---|---|---|---|---|---|
| Zolo (default) | 810 | 375 | 550 | 300 | 3 | 6 |
| Bombard | 876 | 395 | 550 | 475 | 3 | 6 |
| Driver | 1020 | 325 | 620 | 325 | 2 | 8 |
| KW-79 | 759 | 475 | 480 | 325 | 3 | 6 |
| AC-ME Cannon | 870 | 275 | 450 | 250 | 3 | 6 |

Note the mag/reserve *ratio* (3 clip / 6 reserve = 2 reloads worth) is confirmed real
data even though the units for Power/Firing Rate/Reload are relative, not seconds.
Pellet count per shot, spread angle, range falloff, and knockback distance: **UNKNOWN —
no source found**. Qualitative: *"strong damage at close range... difficult to shoot
enemies from a distance due to its low accuracy"* (source: https://mv.masanggames.com/MV_WEAPONS).
Recharged tuning: Firing Rate or Reload Speed (source: https://mv.masanggames.com/MV_GUIDE/1196629).
Signature advanced tech: "Shotgun Quick Shoot" — see Section 4.

### Sniper Rifle

Stat block = **Power / Firing Rate / Zoom Speed / (Zoom Range stages) / Reload Speed**
(source: https://microvolts.fandom.com/wiki/Sniper_Rifle via r.jina.ai proxy):

| Model | Power | Firing Rate | Zoom Speed | Zoom stages | Reload Speed |
|---|---|---|---|---|---|
| Jam (default) | 700 | 5 | 500 | 1 | — |
| Sea Eagle | 1100 | 5 | 500 | 1 | — |
| Venom | 1100 | 5 | 500 | **2 ("double zoom")** | — |
| Sea Wasp | 1170 | 5 | 550 | — | 550 |

- **Scope zoom levels — the common "4x then 8x" figure is NOT independently confirmed
  anywhere.** Mark it explicitly as **(estimate/community folklore, no hard source)**.
  What IS confirmed: most sniper models have a **single** zoom stage; a named minority
  (Venom called out specifically) have a **double zoom** (2-stage) scope, and this is
  a build choice per weapon model, not a universal mechanic (source:
  https://microvolts.fandom.com/wiki/Sniper_Rifle via r.jina.ai, corroborated by
  https://mvs.fandom.com/wiki/Snipers via r.jina.ai). Recharged's own beginner guide
  confirms this persists: *"For snipers specifically, variants B and D are nearly
  identical except B has dual zoom"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
  **Community meta explicitly prefers the single-zoom variant**: *"most players use max
  damage sniper, mostly D variant because the B's double scope gets in the way in such
  fast-paced game"* (same source).
- **Headshot rule**: the game does not appear to use a stated numeric headshot
  multiplier; sniper is instead framed as a binary one-shot-kill weapon. *"This weapon
  is capable of killing enemies with a single headshot"* (source: WebSearch snippet of
  https://microvolts.fandom.com/wiki/Sniper_Rifle). Recharged nuance: the max-power
  single-zoom "D" variant is popular specifically because it *"achieves one-shot kills
  on body shots"* too, not only headshots (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
- **Unscoped vs. scoped damage**: *"Firing without scoping greatly reduces the damage
  compared to firing while scoping"* (source: https://microvolts.fandom.com/wiki/Sniper_Rifle
  via search snippet); Recharged guide: *"Hipfire deals low damage"* (source:
  https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362). One legacy
  MicroVoltsSurge page gives an actual number: unscoped/hipfire damage "about 200"
  (relative units, source: https://mvs.fandom.com/wiki/Snipers via r.jina.ai) —
  **(estimate, legacy value, not confirmed for Recharged)**.
- **Quickscoping** is a confirmed, named community technique — see Section 4.
- **Sensitivity/movement while scoped**: turn speed "decreased greatly" while scoped
  (source: WebSearch snippet of https://microvolts.fandom.com/wiki/Sniper_Rifle); jump
  reduces accuracy even though the crosshair doesn't visually react to it (source:
  https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
- **Swap cancels scope**: switching to another weapon while scoped immediately cancels
  the scope state (source: same guide).
- Clip size, reserve ammo, real RPM, real reload time: **UNKNOWN — no source found**;
  qualitative only: "fires a single bullet with extremely high reload times" (source:
  WebSearch snippet, http://orcz.com/MicroVolts:_Sniper_Rifles — page itself 404'd,
  snippet text only, cite with caution). Recharged tuning: Zoom Speed or Reload Speed
  (source: https://mv.masanggames.com/MV_GUIDE/1196629).

### Gatling Gun (Machine Gun)

Stat block = **Power / Warm-Up Time / Run Speed while firing / Accuracy / Ammo
(clip/reserve)** (source: https://microvolts.fandom.com/wiki/Gatling_Gun via r.jina.ai proxy):

| Model | Power | Warm-Up | Run Speed | Accuracy | Ammo (clip/reserve) |
|---|---|---|---|---|---|
| MicroGun (default) | 400 | 655 | 500 | 500 | 120 / 0 |
| DareDev | 480 | 795 | 570 | 600 | 120 / 0 |
| Firefly | 560 | 655 | 540 | 500 | 120 / 0 |
| Crank | 640 | 477 | 500 | 400 | 120 / 0 |

`Ammo: X/0` on every model implies **no spare-magazine reserve pool** in the source
game — a reload is a full refill, matching ToyVolts' "belt 120, no reserve" design.
- **Spin-up/warm-up mechanic**, confirmed: *"the period of time when the Gatling Gun
  starts spinning its barrel, before bullets are actually fired."* Critically, **warm-up
  resets if you jump or fall while holding fire** (source: https://microvolts.fandom.com/wiki/Gatling_Gun
  via r.jina.ai) — a specific rule ToyVolts does not currently model.
- **Overheat mechanic**, confirmed: *"a circular bar around the crosshair starts to
  fill... [when maxed] the Gatling Gun will stop firing"* until the bar drops back to
  zero; burst-firing is the community-recommended way to avoid it (source: same page).
  **Exact shot-count-before-overheat and exact cooldown time: UNKNOWN — no source found.**
- Qualitative: *"takes time to fire, but its spinning barrel can take down multiple
  enemies at once. However, due to its heavy weight, it is vulnerable to fast enemies"*
  (source: https://mv.masanggames.com/MV_WEAPONS). Recharged tuning: Warm-Up Speed or
  Speed while Firing (source: https://mv.masanggames.com/MV_GUIDE/1196629).
- A closed-beta-only Gatling swap-cancel exploit ("Heavy-Step") existed and was
  deliberately patched out for being overpowered — see Section 4.

### Bazooka (Rocket Launcher)

Stat block = **Power / Firing Rate / Blast Radius / Bullet Speed / Reload Speed**
(source: https://microvolts.fandom.com/wiki/Bazooka via r.jina.ai proxy):

| Model | Power | Firing Rate | Blast Radius | Bullet Speed | Reload Speed |
|---|---|---|---|---|---|
| Sting Ray (default) | 360 | 500 | 350 | 300 | 375 |
| Pound | 440 | 500 | 400 | — | 375 |
| Pocket Rocket | 500 | 15 | 45 | — | 250 |
| Mimic | 400 | 35 | 35 | — | 500 |

The wiki explicitly documents a tradeoff design: *"Pocket Rocket [has] the slowest
firing rate, but is more powerful and has a bigger blast radius,"* while *"Mimic has the
fastest firing rate"* but the smallest blast radius and lowest damage (source: same
page, direct quote). Direct hits: *"the Bazooka is a weapon that is capable for Direct
Shots"* and *"explodes on any impact"* (source: WebSearch snippet of same page).
Qualitative: *"fires devastating explosive projectiles over long distances... can be
launched into the air as it clears enemies"* (source: https://mv.masanggames.com/MV_WEAPONS).

**Splash falloff curve, self-damage, and rocket-jump potential: UNKNOWN — no source
found despite multiple targeted searches** ("microvolts self damage bazooka," "microvolts
rocket jump," "does not take own explosive damage"). No wiki page, guide, or forum post
asserts *or* denies self-damage exists. Given the total absence of any mention on the
dedicated Bazooka/Grenade Launcher pages (which document blast radius without ever
mentioning shooter self-harm), the most defensible read is that **MicroVolts likely does
not model self-damage or rocket-jumping** — but this is an inference from silence, not a
positive confirmation. Clip/reserve ammo: **UNKNOWN**. Recharged tuning: Firing Rate or
Bullet Speed (source: https://mv.masanggames.com/MV_GUIDE/1196629).

### Grenade Launcher

Stat block = **Power / Firing Rate / Range** (source: https://microvolts.fandom.com/wiki/Grenade_Launcher
via r.jina.ai proxy):

| Model | Power | Firing Rate | Range |
|---|---|---|---|
| Hot Dog (default) | 550 | 350 | 570 |
| Pulse | 600 | 400 | 635 |
| Exile | 750 | 450 | 570 |

- **Trajectory**: arched/gravity-affected — *"this is the style of aiming preferred when
  using the Grenade Launcher as it is susceptible to gravity,"* enabling shots around
  corners/over cover other weapons can't reach (source: same page).
- **Detonation behavior — does NOT detonate on player contact.** *"The grenade does not
  explode on contact. Instead, in case the grenade hits a wall, ceiling or floor it will
  trigger the delay [fuse]"* (source: https://microvolts.fandom.com/wiki/Grenade_Launcher
  via r.jina.ai). Different models have different fuse lengths ("Pulse detonates quickly
  while Exile falls in the middle range") but exact fuse times in seconds: **UNKNOWN — no
  numeric source found.** A 2013 Halloween update reduced the arc trajectory, affecting
  long-range use (source: same page) — confirms the arc has been tuned/nerfed historically.
- Qualitative: *"loaded with grenades that can finish off many enemies at once... brings
  unexpected variables on the battlefield"* (source: https://mv.masanggames.com/MV_WEAPONS).
  Recharged tuning: Firing Rate or Blast Radius (source: https://mv.masanggames.com/MV_GUIDE/1196629).
  Clip size, reload time, exact splash radius, bounce-count physics: **UNKNOWN — no
  source found.**

### Cross-weapon: Recharged tuning system

Every slot supports a **tuning** system where the player picks exactly one stat-boosting
effect at a time (re-tunable later): Melee → Power / Run Speed / Range; Rifle → Accuracy
/ Ammo; Shotgun → Firing Rate / Reload Speed; Sniper → Zoom Speed / Reload Speed;
Gatling → Warm-Up Speed / Speed while Firing; Bazooka → Firing Rate / Bullet Speed;
Grenade Launcher → Firing Rate / Blast Radius (source: https://mv.masanggames.com/MV_GUIDE/1196629,
cost "40 MP and 400 battery energy per tuning adjustment" per that page, though the
Steam guide separately cites "10 MP + 400 Energy" per tune — https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362
— the two guides disagree on the MP figure, both are cited as-is).

### Weapon draw/swap time — no hard numbers exist for MicroVolts

No source gives numeric "equip time in ms/seconds" for any weapon in either game
generation. What is confirmed qualitatively: swap speed **differs per weapon** and this
matters mechanically — *"weapon equip speeds vary so you have to be careful not to
switch too fast,"* and drawing a weapon has a visible windup: *"when you pull your
weapon out, your player pulls it up from their waist until it's aiming straight forward"*
before it can fire (source: WebSearch snippet of https://mvs.fandom.com/wiki/Tips_%26_Tricks).
A historical patch-note fragment: an accessory called "hands" used to increase weapon
equip speed by 10%, later removed (source: WebSearch snippet, page unspecified,
surfaced under query "microvolts weapon swap speed equip time draw speed"). **Exact
draw-time numbers per weapon class: UNKNOWN — no source found anywhere.**

---

## 2. Movement

| Aspect | Finding |
|---|---|
| Character scale | No dev-stated numeric height/scale found anywhere (Steam page, Wikipedia, wikis, reviews). Qualitative confirmation only: *"the scope and scale of the environments do a pretty nice job of making you feel like a small toy in a big world"* (source: http://mikedot.blogspot.com/2011/05/microvolts-review.html); official maps page: figures fight in "various locations close to reality. From desk tops to outdoor settings" (source: https://mv.masanggames.com/MV_MAPS). **No numeric scale — UNKNOWN.** |
| Run speed | **UNKNOWN — no m/s or units/s value found anywhere.** Only *relative gear modifiers* exist: melee weapons carry a "Run Speed" stat (Folding Shovel 20 up to Steel Hammer 60, relative units, source: https://microvoltsguides.wordpress.com/2011/05/22/80/); character-level passive run-speed % boosts exist too, e.g. "Naomi +2.0% run speed," "Amelia +3.0% run speed" (source: https://en.wikipedia.org/wiki/MicroVolts). No baseline "normal" run speed number was ever stated in absolute terms. |
| Jump | No numeric jump height found — **UNKNOWN**. Single jump is bound to Space Bar (source: https://www.magicgameworld.com/controls-for-microvolts-recharged/ via search snippet). Maps also contain **"Super Jump" pads/cannons** as level hazards/features that launch players into the air — confirmed via Steam achievements: "Super Jumper: Jump from a Super Jump 100 times in one match," "Fly Like an Eagle: Earn 5 Rifle kills while on a Super Jump" (source: https://steamcommunity.com/stats/1426440/achievements). |
| Double jump rule — **confirmed** | A second jump is only available while a **Melee weapon is equipped/drawn**. *"Melee weapons attack lightly and quickly, and can jump twice"*; *"you should have your melee weapon equipped in order to perform a double jump"* (source: https://microvolts.fandom.com/wiki/Melee via search snippet). Community guide lists "double jumping via space bar" and "dodging, bunny hopping, and reaching high places" among the "best uses for melee" (source: https://microvoltsguides.wordpress.com/2011/05/22/80/). Steam achievement "Jump jump jump!: Double jump 100 times in one match" confirms it's a tracked core mechanic (source: https://steamcommunity.com/stats/1426440/achievements). |
| Melee-drawn mid-air | **Confirmed**: switching to melee mid-air instantly grants the extra jump — *"to pull off this move, you add a press of the spacebar as you switch to your melee weapon"* (source: WebSearch summary of https://microvolts.fandom.com/wiki/Melee). This is the root mechanic of "wave-stepping" (Section 4). A related Steam achievement ("double jump! And..") reportedly requires landing a *hit* using the swap technique, not a kill (source: https://mv-forum.masanggames.com/index.php?/topic/2197-double-jump-and-achievement/). |
| Air control | No explicit statement of full/partial air control — **UNKNOWN**. Indirect evidence only: jumping reduces shooting accuracy even without a visible crosshair reaction, implying players are expected to move/aim/fight while airborne (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362). |
| Sprint | No sprint key appears in any control listing checked, including the full control list at https://www.magicgameworld.com/controls-for-microvolts-recharged/ — treated as **absent (inferred, not explicitly confirmed absent by any source)**. |
| **Crouch — DOES exist, contrary to a "no crouch" assumption** | Bound to **L-CTRL** by default (source: https://www.magicgameworld.com/controls-for-microvolts-recharged/ via search snippet), independently corroborated by a 2011 review's summary of the core loop: *"you run, you shoot, you jump, you shoot, you crouch and you shoot some more"* with "that typical FPS key layout" (source: http://mikedot.blogspot.com/2011/05/microvolts-review.html). Its mechanical effect (hitbox reduction? accuracy bonus?) is **UNKNOWN — no source found.** |
| Dash/dodge | No dedicated dash/dodge ability or key found. The closest analog is repeated melee double-jumping used as "dodging, bunny hopping" per the community guide (source: https://microvoltsguides.wordpress.com/2011/05/22/80/), and generic evasion advice ("confusing movements, turning, jumping on random objects") (source: https://microvoltsguides.wordpress.com/2011/05/19/close-combat-tips-and-tactics/) — **no discrete bound dash ability found.** |
| Ladders/climbing | **No ladder mechanic found in any source.** Maps instead use Super Jump pads/cannons for vertical traversal, and players "climb" onto map geometry via jumping (not a ladder system) — close-combat guide: *"climb — either back-stab people who try to jump on something high or be on an object"* (source: https://microvoltsguides.wordpress.com/2011/05/19/close-combat-tips-and-tactics/). Some maps have explicit extra climbable objects, e.g. Bitmap 2 lets players climb PC-tower geometry (source: https://mv.masanggames.com/MV_MAPS). Treat true ladders as absent. |

---

## 3. Camera

| Aspect | Finding |
|---|---|
| Perspective | Third-person confirmed as a core, marketed feature across every source checked (source: https://www.mmobomb.com/review/microvolts; https://en.wikipedia.org/wiki/MicroVolts contrasts it against typical first-person shooter MMOs). Community guide notes the tactical value of the camera framing: *"due to the camera position, players can hide near a corner and watch without being seen. Very handy for sniping"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362). |
| Shoulder offset side | **UNKNOWN — no source states left vs. right shoulder default.** One relevant data point: the game exposes **manual camera-orbit keys** (Left Arrow = Camera Left, Right Arrow = Camera Right) in addition to mouse-look — a holdover from its 2011 MMO-era control scheme (source: WebSearch summary of https://www.magicgameworld.com/controls-for-microvolts-recharged/), implying the camera is player-rotatable rather than fixed to one side. |
| FOV | **UNKNOWN — no developer-stated or datamined FOV value found anywhere** (Steam store page, FAQ, guides). |
| Rifle zoom/ADS | Confirmed to exist as a **mild zoom, not a dedicated scope**: *"Rifles have a secondary 'mode' where it zooms in a small amount, and the cursor sensitivity is greatly reduced while zooming in"* (source: WebSearch summary of https://microvolts.fandom.com/wiki/Rifle). No magnification number given. |
| Sniper zoom levels | **The "4x then 8x" figure could not be verified anywhere — treat as unverified community folklore / estimate, not a documented spec.** What is confirmed: most sniper models have **one** zoom stage; specific named models (e.g. Venom) have a **double zoom** (2-stage) scope as a per-model trait, not a universal mechanic (source: https://microvolts.fandom.com/wiki/Sniper_Rifle via r.jina.ai, https://mvs.fandom.com/wiki/Snipers via r.jina.ai). Community meta actually **prefers single-zoom** variants because *"the B's double scope gets in the way in such fast-paced game"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362). |
| Sensitivity while scoped/zoomed | **Confirmed to scale down.** Sniper scope: *"players may have some trouble aiming as mouse velocity is decreased greatly"* (source: WebSearch summary of https://microvolts.fandom.com/wiki/Sniper_Rifle). Rifle's mild zoom applies the same reduced-sensitivity behavior (source: WebSearch summary of https://microvolts.fandom.com/wiki/Rifle). Recharged specifically **added a player-adjustable zoom-sensitivity setting**, described as one of the most-requested changes from returning players: *"the function of altering the zoom sensitivity of sniper weapons is used"* (source: https://mv.masanggames.com/MV_NEW_CHANGES). No exact scaling curve/formula found beyond "reduced, and now adjustable." |
| Swap-cancels-scope | Confirmed: switching weapons while scoped immediately cancels the scope state (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362). |

---

## 4. Swap / wave-step / advanced mechanics

### Weapon swapping (swap-cancel)

Core, extensively documented community-coined mechanic: *"Weapon Swapping in a nutshell
is switching back and forth between two (sometimes more) weapons"* to fire faster than
either weapon's native rate allows (source: https://mvs.fandom.com/wiki/Tips_%26_Tricks
via r.jina.ai proxy). One source states this **only works with Shotgun, Bazooka, and
Grenade Launcher** (source: same page) — narrower than a universal cancel on every slot.
Execution tip, quoted: *"keep your fire button held down the entire time while weapon
swapping"*; use separate key bindings per weapon rather than one auto-swap key, and time
the fire input for the moment the weapon animation "aims straight forward" mid-draw
(source: same page). Tactical example given: *"when using a combination of Rockets and
Shotgun weapon swapping, try to use the Bazooka first to knock your enemy into the air"*
— implying splash knockback is used tactically alongside swap-canceling (source: same page).

**Recharged-specific confirmation — "Shotgun Quick Shoot"**: *"right after shooting any
shotgun and holding left click down, quickly tapping the swap key twice reduces the time
between shots"* (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362)
— direct evidence the reload/recovery-cancel-via-swap mechanic persists in the current
Steam build, not just the 2011 original.

A related, **explicitly nerfed** exploit called **"Heavy-Step"** (a Gatling-gun swap
technique) existed only in closed beta and was disabled because devs *"predicted it was
too over-powered"* (source: https://mvs.fandom.com/wiki/Tips_%26_Tricks via r.jina.ai) —
useful precedent that swap-cancel breadth is a balance lever the devs actively watch and
have nerfed per-weapon.

### "Wave step" / "wavestepping"

Confirmed as a real, named, well-documented tech — considerably deeper than a single
melee-drawn double jump. Core definition: *"manipulating the melee double jump to
execute two airborne shots"* (source: http://fantasysportsvideogames.blogspot.com/2013/01/microvolts-wavestepping-guide.html,
corroborated by https://guidescroll.com/2011/10/microvolts-wavestepping-guide/ via
search snippet). Mechanically: equip melee to get the double jump, jump, switch back to
a gun mid-air, fire, then use the leftover air time/second jump to fire again before
landing — net effect is bonus airborne shots per jump cycle plus erratic aerial movement
that *"massively [throws] off [enemy] aim"* (source: guidescroll.com, via search snippet).

Documented **skill progression** (community-taught, not developer-defined): (1) master
plain weapon-swapping first, (2) practice a "static" (standing-still) wavestep, best
learned on a **shotgun** since rocket/grenade variants are harder, (3) progress to
directional wavesteps (left/right/forward/backward), (4) a full 360° wavestep, (5)
advanced players extend it to rocket and grenade-launcher wavesteps — described as good
for firing "a barrage of rockets" from elevated positions and causing enemy *"confusion
lasting 2-3 seconds or longer if hits connect"* (source: fantasysportsvideogames.blogspot.com).
Community-estimated learning time: *"for some, this takes less than an hour to master,
and others up to a week"* (source: same page). Named downsides: increased vulnerability
to snipers when fixated on a single target, and it can draw "hacking" accusations from
unfamiliar opponents (source: same page). One source claims ground-level wavestepping is
"limited to three weapons: Zolo, Pulse, and KW-79" — flagged as **internally ambiguous**
since Zolo/KW-79 are Shotgun models but "Pulse" is a Grenade Launcher model per the same
wiki's own naming, suggesting either a naming collision or a source error.

Confirmed **still relevant in Recharged**: a Steam-guide commenter states *"swap and
wavestep mechanics are essential to improve"* and recommends practicing them risk-free
in A.I. Battle mode, since bot matches don't count toward stats/rewards (source:
https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).

### "Ninja-swap" / "Ninjaswapping"

Confirmed to exist as a named, related-but-distinct technique — always mentioned
alongside "swap" and "wavestep" in community tutorial titles (e.g. "Sneezle - Microvolts
tutorial on Swapping/Wavestepping/Ninjaswapping," source: WebSearch title listing,
https://www.youtube.com/watch?v=WJFUWeWWqKk). **Its exact mechanical definition is
UNKNOWN — no text source explains what distinguishes it from plain weapon-swapping**;
all explanations are locked inside YouTube videos whose transcripts/descriptions could
not be fetched in this session (pages returned 401/blocked). Best guess **(estimate, no
hard source)**: likely a faster or more disguised variant of the swap-cancel timing
window, by naming convention with similar mechanics in other swap-based shooters — not
independently confirmed.

### Quickscoping and "Dragshoting"

Confirmed named/established tactic. Definition: *"aim at your target, then zoom in,
adjust your aim, then fire while zoomed in"* for close-to-mid-range engagements where
scoped damage outweighs the exposure risk (source: WebSearch snippet of
https://microvolts.fandom.com/wiki/Sniper_Rifle). Steam guide phrasing: *"you pick your
sniper at any range and shoot someone (scoped-in)... sometimes it's one hit kill"*
(source: https://steamcommunity.com/sharedfiles/filedetails/?id=167804504). A related
named variant, **"Dragshoting"**, is *"another version of quickscoping but you 'drag'
your aim to your target, even if they are in your scope or not"* (source: same guide).
Timing-failure case documented for double-zoom scopes specifically: firing too early
while the zoom animation is still resolving reduces damage down to "no-scope" levels
(source: https://mvs.fandom.com/wiki/Snipers via r.jina.ai).

### Rocket jumping

**UNKNOWN — no evidence found that this exists**, despite multiple targeted searches.
No wiki page or guide mentions self-damage from your own explosives at all — the
dedicated Bazooka and Grenade Launcher pages document blast radius/power without ever
mentioning the shooter being affected. Read as an inference from absence, not a positive
confirmation: **MicroVolts most likely does not model rocket jumping as a core mechanic.**

### Shotgun-jump combos

No dedicated, separately-named "shotgun jump" (self-knockback via shotgun, TF2-style)
was found. The only shotgun-specific advanced tech documented is "Shotgun Quick Shoot"
(above) and the fact that shotgun is the community-recommended *training weapon* for
learning wavestepping since "rockets and grenades may be more complex" (source:
http://fantasysportsvideogames.blogspot.com/2013/01/microvolts-wavestepping-guide.html).
A discrete "shotgun self-knockback jump" tech: **UNKNOWN — no source found.**

### Bunny hopping

**UNKNOWN / evidence points to non-existence as a distinct named MicroVolts tech.**
Targeted searches ("microvolts recharged bunny hop/bhop guide") returned only unrelated
bhop guides for other games (Left 4 Dead 2, CS, Garry's Mod) that ranked on keyword
overlap; one candidate guide was directly fetched and confirmed to be for Left 4 Dead 2,
not MicroVolts (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3429794997,
checked and excluded). No MicroVolts-specific source uses the term or describes a
CS-style strafe-jump speed gain — the community guide's use of "bunny hopping" (Section 2)
appears to be informal language for repeated melee double-jump dodging, not a distinct
CS-style movement-tech mechanic.

### Other confirmed named mechanics

- **Corner-peek sniping**: the third-person camera lets a player watch/aim from behind
  cover without their model being visible to the enemy (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
- **Scope-cancel via swap** (repeated from Section 3): switching weapons instantly
  cancels scope state — relevant as counter-play against campers/quickscopers.

---

## 5. HUD layout

**Overall finding: exact HUD screen positions (HP bar, ammo, weapon slots, minimap, kill
feed, scoreboard columns) are essentially undocumented in any text source found** — no
Steam page, wiki, review, or forum post gives a HUD teardown for this niche, decade-old
game. Below is everything that could be confirmed, with explicit UNKNOWNs for the rest;
a follow-up pass would need direct gameplay-video observation rather than further text
search.

| HUD element | Finding |
|---|---|
| HP bar location | **UNKNOWN — no source found.** |
| Ammo count location | **UNKNOWN — no source found.** Reload is bound to **R** (source: https://www.magicgameworld.com/controls-for-microvolts-recharged/ via search snippet), but its on-screen placement is undocumented. |
| Weapon slot icons / active-weapon indication | Default slot bindings partially confirmed: Melee defaults to slot **1** (sometimes rebound to Left-Shift), Rifle defaults to slot **2** (source: https://microvoltsguides.wordpress.com/2011/05/22/80/ and WebSearch community discussion). Weapon cycling also works via mouse wheel: Up-wheel = previous weapon, Down-wheel = next weapon (source: https://www.magicgameworld.com/controls-for-microvolts-recharged/ via search snippet). Visual layout/highlight style of the 7 slot icons: **UNKNOWN — no source found.** |
| Radar/minimap | **Ambiguous — likely NOT a persistent HUD element.** The only "radar" reference found is an in-game **consumable/temporary item** called "Radar" that shows enemy player locations for a limited time in certain modes (e.g. spawning at the 1-minute mark in Elimination) — this is a power-up, not a baseline always-on minimap (source: WebSearch synthesis referencing MicroVolts item mechanics and https://mv.masanggames.com/MV_MODES / Elimination notes). Whether a baseline compass/minimap exists at all times: **UNKNOWN — no source found.** |
| Kill feed | **UNKNOWN — no source directly describes it.** Indirect evidence multi-kill events are tracked (and likely announced somehow): Steam achievements "Double Kill Master: Earn 7 Double Kills in one match," "Multi Kill Master: Earn 6 Multi Kills in one match" (source: https://steamcommunity.com/stats/1426440/achievements). Exact on-screen presentation: **(estimate, no hard source).** |
| Crosshair | A **dynamic/reactive crosshair concept exists**: *"despite dynamic crosshair not reacting, jumping does reduce accuracy"* — implying the crosshair does have spread-reactive states even though this specific interaction (jump penalty) isn't visually shown (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362). Distinct crosshair *shapes* per weapon type: **UNKNOWN — no source found.** |
| Directional damage indicator | **UNKNOWN — no source found.** |
| Hit-marker sound/icon | **UNKNOWN — no source found.** |
| Headshot indicator | Headshots are a confirmed, scored mechanic (achievements: "Bullseye!: Score your first kill of a game with a Sniper Rifle Head Shot," "Watch Your Head!," "Accurate Shooter" for Rifle headshots — source: https://steamcommunity.com/stats/1426440/achievements) but a distinct visual/audio headshot indicator: **UNKNOWN — no source found.** |
| Kill popups/announcements | **UNKNOWN in terms of visual presentation.** A character "Colonel Crac" is documented as an in-game announcer/mentor figure from the training stage (source: WebSearch result referencing https://microvolts.fandom.com/wiki/Colonel_Crac, page itself returned 402 on direct fetch); whether he voices in-match kill callouts is **UNKNOWN.** |
| Scoreboard key/columns | **UNKNOWN — no source found** confirming Tab or any other key opens a scoreboard, or what columns it shows. |

---

## 6. Modes

**Mode-roster discrepancy across sources**: Wikipedia (legacy game) lists **17 modes**
(source: https://en.wikipedia.org/wiki/MicroVolts); a Fandom-derived summary lists 11
(Team Death Match, Free For All, Capture the Battery, Item Match, Close Combat,
Elimination, Zombie Mode, Arms Race, Boss Battle, Scrimmage, Bomb Battle) (source:
https://microvolts.fandom.com/wiki/Item_Match via search snippet); the **current
official Recharged modes page lists only 6**: Team Deathmatch, Elimination, Zombie Mode,
Capture the Battery, Free for All, A.I. Battle (source: https://mv.masanggames.com/MV_MODES).
Recharged has evidently trimmed the legacy mode roster — treat the 6-mode list as
current-Recharged truth and the rest as legacy/historical (and possibly reintroduced
later; not verified either way).

| Mode | Core rules | Score/time limit | Team size | Respawn | Special mechanics |
|---|---|---|---|---|---|
| **Team Deathmatch** | First team to reach a target score by killing opposing players wins (source: https://mv.masanggames.com/MV_MODES) | Target score exists, exact number **UNKNOWN — no source found**; time limit **UNKNOWN** | Team-based (max match size 16 players per the wiki's Maps page, source: https://mvs.fandom.com/wiki/Maps) | Unlimited respawns (source: https://mv.masanggames.com/MV_MODES) | Standard combat |
| **Free For All** | Solo mode, first player to reach target score wins (source: https://mv.masanggames.com/MV_MODES) | **UNKNOWN** | Solo, no teams | Unlimited respawns | None noted |
| **Item Match** (legacy) | *"Exactly the same as Team Death Match"* except every kill drops a **random item from the killed/killing player** (a kill-drop system, not static map pickups); one item held at a time, plus an optional Suicide Bomb that can be carried alongside (source: https://microvolts.fandom.com/wiki/Item_Match via search snippet). Item pool: Health Boost (+400 HP), Team Heal (+1000 HP to team+self), Ammo Refill, Suicide Bomb (ignites on death, kills nearby enemies, persists until holder dies), Power Potion (damage buff, longest duration), Shield (temp full immunity), Hermes' Boots (temp speed buff), Disguise (visually appear as enemy team) (source: https://microvolts.fandom.com/wiki/Items via search snippet) | **UNKNOWN** | Same as TDM | Inherits TDM | Kill-drop items, not spawned pickups |
| **Zombie Mode** | 1-3 players randomly "infected" at match start (count scales with lobby size); infected must melee-infect all normal players; normal players fight/survive zombies (source: https://microvolts.fandom.com/wiki/Zombie_Mode via search snippet, https://mv.masanggames.com/MV_MODES) | Score from zombie kills/infections/survivals, no numeric limit found; an "infection clock" counts down | Infected vs. rest (not traditional 2-team) | All players spawn separately with 0 ammo except rifle (source: search of https://microvolts.fandom.com/wiki/Zombie_Mode) | Ammo capsules scattered on map, more spawn as the clock ticks; special "Zombie Weapons" spawn mid-match with an announcement |
| **Capture the Battery** | Steal the enemy team's battery from their base camp and deliver it to your own camp; wins at target score (source: https://mv.masanggames.com/MV_MODES) | Target score **UNKNOWN** | Team-based, 2 bases | Likely unlimited (unconfirmed) | Battery location always visible even while carried; capture grants bonus XP/MP, more to the capturer |
| **Elimination** | No respawn once killed within a round; last-team-standing per round (source: https://mv.masanggames.com/MV_MODES) | **UNKNOWN** | Team-based | **No respawn per round** (defining mechanic) | A Radar power-up spawns center-map at "halftime"/1-minute-remaining, revealing enemy positions |
| **Bomb Battle** (legacy) | Elimination-style (no mid-round respawn) + plant/defuse objective: Offense plants and arms a bomb at site A or B, Defense prevents it (source: https://microvolts.fandom.com/wiki/Bomb_Battle via search snippet) | **UNKNOWN** | Offense vs. Defense roles | No mid-round respawn | Two bomb sites (A/B) |
| **Boss Battle** (legacy, PvE) | 1-4 co-op players fight a giant robot boss ("Tracker," 4 named units TRK-01 to TRK-04) plus mini-robot adds; dodge attacks, destroy adds to survive (source: https://microvolts.fandom.com/wiki/Boss_Battle via search snippet) | N/A — PvE, no score race | 1-4 co-op, no opposing team | **UNKNOWN** | Only on "Academy Invasion" map; win grants a Bronze/Silver/Gold/Diamond loot box; **completing it awards NO XP and NO MP**, unlike every other mode |
| **Close Combat** (legacy) | Melee-weapons-only specialty mode, restricted to the "Chess" map (source: https://microvolts.fandom.com/wiki/Category:Modes via search snippet) | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | Melee-only restriction; single dedicated map |
| **Arms Race** (legacy) | FFA "gun-game" style: kills force weapon-tier progression; first to a kill target wins (source: https://microvolts.fandom.com/wiki/Arms_Race via search snippet) | Reported as **first-to-20 kills** (approximate, via search summary — treat as estimate) | Up to 6 players, FFA | **UNKNOWN** | Weapon-tier ladder by kill count (approx.: 1=Rifle, 5=Shotgun, 8=Sniper, 12=Gatling, 14=Rocket, 17=Grenade — treat as approximate); melee always available to "knock a tier down" or escape; a "Crunch Time" near round end gives lowest-scoring players bonus items |
| **Scrimmage** (legacy) | Team shared-HP-pool mode: each team has a shared health gauge; damaging enemies drains their gauge; team at 0 loses (source: https://microvolts.fandom.com/wiki/Scrimmage via search snippet) | Team gauge starts at **5000 HP** (estimate/search-summary value) | Team-based | On death, player becomes a "repair box" (mechanic unclear from source) | Reportedly "the least played mode" per the wiki summary |
| **Invasion** (legacy, PvE) | Wave-clear: Easy = 10 rounds, Hard = 20 rounds; a boss every 5th stage (source: https://microvolts.fandom.com/wiki/Invasion via search snippet) | N/A — PvE | **UNKNOWN** | **UNKNOWN** | Hard difficulty capped at 3 plays/day |
| **A.I. Battle** | Practice vs. bots, launched via Create Room (source: https://mv.masanggames.com/MV_MODES; confirmed by https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362) | N/A | Configurable, solo practice | **UNKNOWN** | Explicitly does **not** track XP, MP, or kills — pure practice |

A **"Practice/Square Mode"** free-practice sandbox is also referenced alongside
Scrimmage (source: search of https://microvolts.fandom.com/wiki/Scrimmage). A **"League"
ranked system"** was reportedly announced in a major update, but the announcement page
itself returned HTTP 401 on fetch — only the title is confirmed, body content
**unverified** (source: https://www.gamespress.com/Masangsoft-Announces-Major-MICROVOLTS-Recharged-Update-with-New-League).

---

## 7. Room / lobby flow

This is the **least-documented part of the game online** — no primary source gives a UI
teardown of the room list, ready-up flow, or host controls.

- **Channel system**: reported to exist (players "enter a channel" before joining
  matches, tied to regional servers EU/US) via general web-search synthesis, but **no
  single quotable primary source was found — low confidence.**
- **Server list**: a separate test/beta server exists apart from live service (source:
  https://mvs.fandom.com/wiki/Test_server via search snippet, content not independently
  verified).
- **Room list fields** (room name, map, mode, player count, password icon): **UNKNOWN —
  no source found describing the exact UI.**
- **Room creation — weapon restriction option confirmed**: host can choose (1) All
  Weapons, (2) Weapon Select (melee + each player individually picks 2 weapons), or (3)
  Single Weapon (host picks one weapon for everyone) (source: WebSearch synthesis of
  Fandom mode-category content — **medium confidence**, exact page not independently
  re-verified).
- **Room creation — map/mode gating**: not every mode is playable on every map, *"due to
  maps' different sizes and different locations for spawning, batteries, or
  bomb-planting sites"* (same source).
- **Max players per room**: reported as **16 players** in one synthesis (source:
  https://mvs.fandom.com/wiki/Maps: "max match size is 16 players") — treat as the most
  solid figure found, though not independently cross-confirmed on a second page.
- **A.I. Battle is selectable directly from the Create Room screen** as a distinct
  practice option (source: https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
- **Ready-up system**: **UNKNOWN — no source found** either confirming or denying a
  ready-check step.
- **Host manual-start vs. automatic**: **UNKNOWN — no source found.**
- **Map voting/rotation between rounds**: **UNKNOWN — no source found.**
- **Mid-match joining**: **UNKNOWN — no source found.**
- **Team balancing (auto vs. manual)**: **UNKNOWN — no source found.**
- **Kicking players — vote-kick, not simple host-kick, confirmed.** MicroVolts uses a
  **vote-kick** system where any player (including opposing-team members) can initiate a
  kick vote against another player. This is a documented community complaint: *"enemy
  teams can kick players for no reason or for just being good,"* with reports of being
  kick-banned from rejoining roughly 1-in-3 matches per one poster (source:
  https://mv-forum.masanggames.com/index.php?/topic/1714-vote-kick-system-needs-to-change/).
  A community proposal (unimplemented, per the same thread) suggested restricting kicks
  to teammates only and requiring evidence for toxicity/cheating kicks, with a 3-false-kicks
  = 1-month vote-ban penalty — this is a **player suggestion, not a confirmed shipped
  feature.**

**Assessment**: primary-source documentation of the room/lobby UI is essentially absent
online for this game. If precise lobby-flow behavior is load-bearing for ToyVolts, it
should be observed directly from a gameplay video rather than further text research.

---

## 8. Progression and shop

### Currencies

| Currency | Type | Use | Source |
|---|---|---|---|
| **MP** (Micro Points) | Free, earned in-game | Weapon purchases, weapon "tuning," Limited Capsule pulls (2,300 MP/pull), earned via K/D ratio, match outcome, achievements | https://en.wikipedia.org/wiki/MicroVolts; https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362 |
| **RT** (Rock Token / "RT Coin" in Recharged) | Premium, real-money | Capsule Machine pulls, membership, premium cosmetics | https://en.wikipedia.org/wiki/MicroVolts; Steam Starter Pack listings |
| **Battery** | In-game resource (distinct from the CTB mode object of the same name) | Required alongside MP to add/upgrade abilities on weapons/parts via the "setting"/tuning system; Membership grants **unlimited Battery** | https://mv.masanggames.com/MV_NEW_CHANGES |
| **Energy** | In-game resource | Costs **400 Energy (+10 MP)** to tune a weapon per the Steam beginner's guide | https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362 |

### Capsule machine (gacha)

- **RT-based Capsule Machine**: **1,000 RT per pull, "roughly $1" per spin** (legacy
  figure, source: https://en.wikipedia.org/wiki/MicroVolts). Legacy drop-rate estimates
  (unconfirmed for current Recharged build): rare weapons ~1:75 odds, rare clothing
  ~1:25 odds (same source).
- **MP-based "Limited Capsule"**: **2,300 MP per pull** (source:
  https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362); functions as a
  **shared community pool** — a fixed quantity of items per rarity tier seeds each
  capsule box, and odds improve for remaining items as more players pull (source: same
  guide, and https://mv.masanggames.com/MV_GUIDE/1196635). Limited Capsule lists are
  time-gated to a **24-hour** window (source: https://mv.masanggames.com/MV_GUIDE/1196635);
  players can buy **up to 20 capsules at a time** (same source).
- Current capsules split into **"Seasonal"** (rotating) and **"Standard"** (permanent)
  categories, with an in-game "View Probability" button showing exact drop rates per box
  (source: https://mv.masanggames.com/MV_GUIDE/1196736) — the page itself does not list
  the rates or a cost-per-pull.

### Weapon upgrade/leveling

- Weapons have **lettered variants (A/B/C/D)** with permanently different stats (source:
  https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362).
- Weapons/parts can be **"tuned"**: one chosen stat effect active at a time, re-tunable
  for further cost (10 MP + 400 Energy per the beginner's guide, though the official
  guide page cites 40 MP + 400 Battery Energy — the two disagree on the MP figure).
- The **legacy game had an upgrade-to-level-9 system with failure/downgrade risk**
  (added Nov 10 2011) (source: https://en.wikipedia.org/wiki/MicroVolts). Recharged's
  official changelog states this **"Evolution system" and its pay-to-win risk mechanics
  were removed** in the relaunch, replaced by the current MP+Battery tuning system,
  explicitly marketed as "no longer pay-to-win" (source: https://mv.masanggames.com/MV_NEW_CHANGES).

### Parts customization

- Legacy game slot list (per Wikipedia): **Hair, Face, Top (upper body), Bottom (lower
  body), Hands, Shoes (feet), Accessories** — each slot can affect stats like run speed,
  HP, and ammo capacity (source: https://en.wikipedia.org/wiki/MicroVolts).
- Current Recharged Steam store page describes **"ten unique/distinct costume parts"**
  total, without breaking out slot names (source: https://store.steampowered.com/app/1426440/MICROVOLTS_Recharged/).
  A separate legacy summary mentions up to 3 accessory sub-slots (head/back/waist),
  flagged by the search result itself as possibly outdated (source:
  https://microvolts.fandom.com/wiki/Shop via search snippet).
- **Net assessment**: the granular 7-slot breakdown is confirmed for the legacy game;
  Recharged's exact current slot taxonomy is not independently re-confirmed beyond "ten
  parts total" — treat the 7-slot list as legacy fact with likely-but-unconfirmed
  continuity.

### Character roster

Nine named characters confirmed via the official figures page, each with an in-fiction
"toy/media franchise" backstory (source: https://mv.masanggames.com/MV_FIGURES):
**Naomi** (anime "Rainbow" heroine, guitarist), **Knox** (sports-game wide receiver,
"The Wild"), **C.H.I.P.** ("Complex Humanoid Interchangeable Parts," limited-edition
figure, "never commercially available" in-fiction), **Kai** (young rocket scientist,
"Space Battleship Callisto"), **Pandora** ("Sealed Devil" heroine, anime "Hide"),
**Sophitia** (priest/swordfighter, "Forest, Sky and Me"), **$harkill Khan** (DJ from
music game "I'm a Star"), **Simon** (cyborg protagonist, film "Cyborg. 2079"), **Amelia**
(high-elf knight with a rapier, "Forest, Sky and Me"). No source states which (if any)
are free starters vs. paid/premium — **UNKNOWN.**

### Rental vs. permanent items

- Shop weapons: **MP-tier** weapons rentable in **7-day and 30-day** durations;
  **RT-tier** weapons in **1-day, 7-day, and 30-day** durations; both tiers also offer an
  **"Unlimited"/permanent** option requiring ongoing repair after each match (source:
  WebSearch synthesis of https://microvolts.fandom.com/wiki/Shop and related pages).
- Accessories: rentable **1 to 30 days**; historically some at **90 days** (no longer
  current, per source) (same source). Capsule-machine accessories are **permanent by
  default** (same source).

### Daily rewards and battle pass

- Daily login grants **MP**, scaling with consecutive-login streak (source: WebSearch
  synthesis, medium confidence — specific page not independently pinned down).
- A "Login Challenge" event type grants event-specific rewards for streak milestones,
  one cited example at **6/12/18/24-day** milestones (source: WebSearch synthesis citing
  gamerjournalist.com, not independently re-fetched).
- **No traditional tiered battle pass/season pass found.** Instead, Recharged runs
  recurring **seasonal "Starter Pack" DLCs** on Steam (Silver/Gold/Platinum tiers,
  refreshed each season), bundling a fixed membership duration + RT Coin + exclusive
  cosmetic set, not a progression-tier reward track. Confirmed 2026 Spring Season
  pricing: **Silver** ₪18.50 = 15-day membership + 1,000 RT + 1 accessory (source:
  https://store.steampowered.com/app/4493610/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Silver/);
  **Platinum** ₪189.95 = 30-day membership + 3,000 RT + 7-piece cosmetic set + a skin
  (source: https://store.steampowered.com/app/4493580/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Platinum/).
  **Membership benefits** across all tiers: daily login RT reward, unlimited Battery,
  extra equipment preset slots (non-members get **2 presets per character**, members get
  **4**), extra daily/weekly mission counts (source: same Steam pages).

---

## 9. Maps worth cloning next

### Toy-scale framing (applies to all maps)

Toy action figures fight *"an all out war for valuable battery resources and supremacy
of the Micro World"* (source: https://www.mmobomb.com/news/third-person-toy-themed-lobby-shooter-microvolts-relaunches-microvolts-recharged,
https://en.wikipedia.org/wiki/MicroVolts). The in-fiction frame is **Hyuga High School's
figure club** — figures/dolls belonging to a school figure-collecting club (source:
https://en.wikipedia.org/wiki/MicroVolts). Dioramas span *"chessboards, schools,
war-destroyed towns, gardens, ships, toy boxes, and more"* (same source). Official copy
frames it explicitly: *"sometimes, the little things you overlook in your daily life can
become crucial keys that lead the battlefield in Microvolts"* — battles happen *"across
desks, areas beneath chairs, and other domestic spaces"* (source: https://mv.masanggames.com/MV_ABOUT_GAME).
Marketing copy: *"battle it out in the bedroom, kitchen, garden or even entire
neighbourhoods!"* — confirming toy-scale figures fighting inside oversized human
household environments (source: https://www.f2pg.com/microvolts/). A period review
corroborates the toy-on-furniture scale: *"climbing on plates and forks to hiding in
coffee cups... the terrain is from the perspective of a toy"* (source: https://mmos.com/review/microvolts).
Not every mode is playable on every map — size and spawn/objective placement gates which
modes a given map supports (source: https://mvs.fandom.com/wiki/Maps). **Max match size
is 16 players** (same source).

**Confirmation status of the requested map list**: several requested names do not exist
under those exact titles in the official 31-map current roster (`mv.masanggames.com/MV_MAPS`),
Wikipedia's 28-map list, or the MicroVoltsSurge Wiki's Category:Maps (~32 pages). Where a
name doesn't exist, the closest real analog is noted; do not treat unmatched names as
confirmed MicroVolts content.

| # | Requested map | Status | Real name |
|---|---|---|---|
| 1 | Toy Fort | UNKNOWN | — (closest: Castle) |
| 2 | Bitmap | Confirmed, good detail | Bitmap / Bitmap 2 |
| 3 | Hobby Shop | Confirmed, thin detail | Hobby Shop |
| 4 | Ship Cabin | UNKNOWN | — (closest: Model Ship, Toy Fleet) |
| 5 | Toy Garden | Confirmed, thin detail | Toy Garden / Toy Garden 2 |
| 6 | Neighborhood | Confirmed, good detail | Neighborhood |
| 7 | Kitchen | UNKNOWN | — |
| 8 | Garage | UNKNOWN | — |
| 9 | Studio | Confirmed, good detail | The Studio |
| 10 | School | Confirmed, good detail | Girls' High School / Academy |
| 11 | Skate Park | UNKNOWN | — |
| 12 | Playground | UNKNOWN | — (closest: Rumpus Room) |
| 13 | Museum | UNKNOWN | — |
| 14 | Christmas | UNKNOWN | — (possible unverified lead: "Fruitys Christmas Renovation" event) |

**Bitmap** — theme: *"the desk of the art team of a game company"*, an office/PC
diorama (source: https://mv.masanggames.com/MV_MAPS); Fandom frames the objective flavor
as competing "to battle your way to employee of the month" (source:
https://mvs.fandom.com/wiki/Bitmap via r.jina.ai). Variant **Bitmap 2** adds climbable PC
towers for extra verticality (source: https://mv.masanggames.com/MV_MAPS,
https://mvs.fandom.com/wiki/Bitmap). Modes supported: TDM, FFA, Elimination, Item Match,
Scrimmage, Close Combat, Arms Race, Sniper Mode, Square Mode — **no CTB** on base Bitmap
(source: https://mvs.fandom.com/wiki/Bitmap). Community association with sniper-heavy
play (a video titled "Bitmap - Sniper Team Death Match," title only, not transcribed).
Exact spawn/symmetry layout: **UNKNOWN.**

**Hobby Shop** — theme: *"a cafe loved by figure lovers,"* framed as after-hours battles
among figure collectors (source: https://mv.masanggames.com/MV_MAPS). Likely runs a
night/evening lighting variant per one low-confidence synthesis. Layout/spawn detail:
**UNKNOWN** — Fandom article body did not render through available fetch tools.

**Toy Garden** — theme: outdoor garden with *"a pond flowing under a sturdy and
beautiful stone bridge"* (source: https://mv.masanggames.com/MV_MAPS) — the bridge is a
natural elevation/chokepoint crossing a water hazard. Night variant **Toy Garden 2** adds
jump pads (source: same page). Layout/spawn detail beyond the bridge landmark: **UNKNOWN.**

**Neighborhood** — theme: *"a general family house theme"*, two neighboring houses
connected to each other (source: https://mv.masanggames.com/MV_MAPS,
https://mvs.fandom.com/wiki/Neighborhood via r.jina.ai). **Layout**: a two-house
structure with many parallel traversal routes between them — jump pads across
windowsills, a pipe route, through cupboards, and across "the patio cooler," plus jump
pads near tables by the respawns leading to the patio-cooler crossing (source:
https://mvs.fandom.com/wiki/Neighborhood via r.jina.ai). This route variety is
**explicitly called out as effective for CTB**: *"many ways to get across from house to
house... effective for CTB"* (same source) — the clearest "what makes a map notable"
data point found in this whole research pass. Modes: Capture the Battery, FFA, TDM,
Zombie Mode, Elimination, Item Match, Scrimmage, Arms Race, Bomb Battle (same source).

**The Studio** — theme: *"a diorama production studio"* with production supplies as
terrain (source: https://mv.masanggames.com/MV_MAPS). Notable landmark: described as a
*"creepy studio"* — *"play with a creepy clown looking down at you as you play"* (source:
https://mvs.fandom.com/wiki/The_Studio via r.jina.ai) — an overhead clown figure appears
to be the map's signature visual. Modes supported (12): TDM, Elimination, Zombie Mode,
CTB, FFA, Boss Battle, Item Match, Bomb Battle, Close Combat, Arms Race, Scrimmage,
Sniper Mode, Square Mode (same source). Layout beyond that: **UNKNOWN** (wiki trivia
section explicitly marked "Trivia Coming Soon!" at last edit).

**School** — confirmed under two names for what is likely the same underlying map:
current official **"Girls' High School"** and legacy-wiki **"Academy."** Official theme:
*"school setting with a gym in the middle"* (source: https://mv.masanggames.com/MV_MAPS);
Fandom: *"school style map"* where "school is a battlefield" (source:
https://mvs.fandom.com/wiki/Academy via r.jina.ai). **Layout**: a central gymnasium
reached via stairs, explicitly flagged as a strong tactical/high-ground position (source:
same page) — consistent with (but not explicitly confirmed as) a symmetric two-wing
layout converging on a central gym. Modes (12): TDM, Elimination, FFA, Zombie Mode, CTB,
Item Match, Bomb Battle, Close Combat, Arms Race, Scrimmage, Sniper Mode, Square Mode
(same source). An "Academy Invasion" variant of the map's outskirts is used specifically
for Boss Battle story content (same source).

**Closest analogs for unconfirmed requested names**: **Castle** (for "Toy Fort") —
official blurb *"figure-scale castle in the middle of production"* (source:
https://mv.masanggames.com/MV_MAPS). **Model Ship** (for "Ship Cabin") — asymmetric
medium map, two decks (upper open, lower heavy-cover with corridors), a rope-connected
bridge overlooking the upper level, explicitly called out as *"the only map where
spawning and the whole map isn't mostly symmetrical"* (source:
https://mvs.fandom.com/wiki/Model_Ship via r.jina.ai); **Toy Fleet** is a second,
distinct ship map noted for high sniper positions (source: https://mv.masanggames.com/MV_MAPS).
**Rumpus Room** (for "Playground") — *"a playroom made of polyurethane,"* an indoor
playroom with blocks and toy trucks rather than an outdoor playground (source:
https://mv.masanggames.com/MV_MAPS, https://www.f2p.com/microvolts-a-new-map-and-good-old-items/).

---

## 10. Ranked gap list — what ToyVolts still does differently

Ranked by estimated impact on matching the MicroVolts feel, based on the ToyVolts
current-state facts (movement/camera/weapon numbers, modes, maps, HUD, online state)
against the sourced findings above.

1. **Wave-step depth**: MicroVolts wave-stepping is a taught skill ladder — static →
   directional (4-way) → full 360° → per-weapon variants (shotgun easiest, rocket/grenade
   advanced, with a 2-3s enemy "confusion" debuff on connecting hits mid-wavestep)
   (source: fantasysportsvideogames.blogspot.com). ToyVolts currently has a single fixed
   melee-drawn double jump at a flat 0.92x speed with no directional/360 variants and no
   hit-confusion effect. This is the single highest-impact gap since swap/wavestep skill
   expression *is* the core Microvolts identity.
2. **Grenade Launcher detonation rule mismatch**: MicroVolts grenades explicitly do
   **not** detonate on player contact — only on hitting a wall/ceiling/floor, which then
   triggers the fuse (source: microvolts.fandom.com/wiki/Grenade_Launcher). ToyVolts'
   current spec has the grenade "detonate on player contact **or** 2.0s fuse," which adds
   a direct-hit-kills-instantly behavior the source game does not document.
3. **Bazooka self-damage/rocket-jump potential is undocumented in the source and
   possibly absent entirely** — no MicroVolts source confirms self-damage exists at all
   (inference from total silence on both weapon wiki pages). ToyVolts' `self damage x0.5`
   is a designed-in mechanic with no confirmed MicroVolts precedent, changing the
   weapon's risk profile and opening rocket-jump-style movement the reference game likely
   doesn't have.
4. **Swap-cancel breadth**: one legacy source states swap-cancel/weapon-swapping
   *"only works with Shotgun, Bazooka, and Grenade Launcher"* (source:
   mvs.fandom.com/wiki/Tips_&_Tricks), and a Gatling-specific swap exploit ("Heavy-Step")
   was deliberately disabled for being overpowered. ToyVolts currently applies a
   universal swap-cancel (drops reload/recovery) across all seven weapons including
   Gatling and Sniper — broader than the documented/intended scope in the source game.
5. **Sniper scope stage mismatch**: most MicroVolts sniper models have a **single** zoom
   stage; only specific models (Venom) offer a double-zoom, and the community actually
   **prefers single-zoom** because *"the double scope gets in the way in such fast-paced
   game"* (source: steamcommunity.com/sharedfiles/filedetails/?id=3034418362). ToyVolts
   hard-codes a two-stage zoom (FOV 18 then 9) on every sniper always — the opposite of
   the documented player preference, and the "4x/8x" magnification figure itself is
   unverified community folklore, not a documented spec.
6. **Radar as permanent HUD vs. limited pickup**: MicroVolts' "Radar" is a time-limited
   item pickup (e.g. spawning at Elimination's 1-minute mark), not a baseline always-on
   minimap. ToyVolts has a permanent radar HUD element top-left at all times — a
   meaningfully different information-availability balance than the source game.
7. **Crouch is missing**: MicroVolts binds Crouch to **L-CTRL** by default (source:
   magicgameworld.com control list, corroborated by a 2011 review's "you run, you shoot,
   you jump, you shoot, you crouch" description of the core loop). ToyVolts currently has
   no crouch at all — contrary to the assumption that MicroVolts has none.
8. **Gatling warm-up doesn't reset on airborne fire**: MicroVolts explicitly resets
   Gatling spin-up *"if you jump or fall while holding fire"* (source:
   microvolts.fandom.com/wiki/Gatling_Gun), penalizing airborne Gatling use. ToyVolts'
   0.45s spin-up currently has no documented interaction with jump state.
9. **No weapon-variant/tuning system**: MicroVolts has dozens of stat-differentiated
   models per slot (lettered A/B/C/D variants) plus a tuning system letting players boost
   one of two stats per weapon (e.g. Rifle: Accuracy or Ammo; source:
   mv.masanggames.com/MV_GUIDE/1196629). ToyVolts has exactly one fixed stat block per
   weapon with no variants or tuning — a large progression-depth gap, though lower
   priority than the moment-to-moment feel items above since it's cosmetic/build-variety
   rather than core combat feel.
10. **Missing modes**: ToyVolts has FFA, TDM, Elimination, Capture the Battery, Practice
    — missing Item Match (kill-drop items), Zombie Mode (infection + ammo-capsule
    tension), and Bomb Battle from the source game's confirmed roster, plus legacy modes
    Close Combat, Boss Battle, Scrimmage, and Arms Race. Item Match and Zombie Mode are
    both confirmed current/legacy staples with well-documented rules (Section 6) and
    would be the highest-value additions.
11. **No character roster or parts customization**: MicroVolts has 9 named characters
    with lore (Naomi, Knox, C.H.I.P., Kai, Pandora, Sophitia, $harkill Khan, Simon,
    Amelia) plus a 7-slot customization system (hair/face/top/bottom/hands/shoes/accessories)
    and capsule-machine gacha. ToyVolts has 4 generic KayKit toy figures as skins with no
    customization or shop — a large content gap, but already explicitly deferred to a
    "Later" milestone in the ToyVolts plan, so lower urgency for core feel.
12. **No room list/server browser/lobby flow**: MicroVolts' own lobby flow (channels,
    room list fields, ready-up, host-start, map voting, mid-match join, team balancing)
    is itself almost entirely undocumented online, so this is a lower-confidence gap —
    but the one concrete documented feature, a **vote-kick system** (any player, even
    opposing team, can initiate a kick vote) (source: mv-forum.masanggames.com topic
    1714), is notably different from a simple host-kick model and is worth deliberately
    deciding against or replicating. ToyVolts currently has no room list/browser at all
    (host/join only, being built this session).

---

## Sources

- https://store.steampowered.com/app/1426440/MICROVOLTS_Recharged/
- https://store.steampowered.com/news/app/1426440/view/3693569804225063063
- https://store.steampowered.com/app/4493610/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Silver/
- https://store.steampowered.com/app/4493600/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Gold/
- https://store.steampowered.com/app/4493580/MICROVOLTS_Recharged__2026_SPRING_SEASON_Starter_Pack__Platinum/
- https://steamcommunity.com/sharedfiles/filedetails/?id=3034418362
- https://steamcommunity.com/sharedfiles/filedetails/?id=167804504
- https://steamcommunity.com/sharedfiles/filedetails/?id=3429794997 (checked and excluded — confirmed to be a Left 4 Dead 2 guide, not MicroVolts)
- https://steamcommunity.com/stats/1426440/achievements
- https://steamcommunity.com/app/1426440/discussions/0/3942399239157052366/
- https://steamcommunity.com/app/1426440/discussions/0/3803904095525797642/
- https://steamcommunity.com/app/1426440/reviews/
- https://en.wikipedia.org/wiki/MicroVolts
- https://en.wikipedia.org/wiki/Microman (background analogy only, not MicroVolts-specific)
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
- https://mv.masanggames.com/index.php?mid=MV_FAQ&page=2
- https://mv.masanggames.com/index.php?mid=MV_FAQ&category=1032306
- https://mv-forum.masanggames.com/index.php?/topic/1714-vote-kick-system-needs-to-change/
- https://mv-forum.masanggames.com/index.php?/topic/2197-double-jump-and-achievement/
- https://microvolts.fandom.com/wiki/Rifle (via r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Shotgun (via r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Sniper_Rifle (via r.jina.ai proxy / search snippet)
- https://microvolts.fandom.com/wiki/Melee (via r.jina.ai proxy / search snippet)
- https://microvolts.fandom.com/wiki/Gatling_Gun (via r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Bazooka (via r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Grenade_Launcher (via r.jina.ai proxy)
- https://microvolts.fandom.com/wiki/Colonel_Crac (search snippet only, page 402'd)
- https://microvolts.fandom.com/wiki/Item_Match (search snippet only)
- https://microvolts.fandom.com/wiki/Team_Death_Match (search snippet only)
- https://microvolts.fandom.com/wiki/Capture_the_Battery (search snippet only)
- https://microvolts.fandom.com/wiki/Zombie_Mode (search snippet only)
- https://microvolts.fandom.com/wiki/Bomb_Battle (search snippet only)
- https://microvolts.fandom.com/wiki/Boss_Battle (search snippet only)
- https://microvolts.fandom.com/wiki/Arms_Race (search snippet only)
- https://microvolts.fandom.com/wiki/Scrimmage (search snippet only)
- https://microvolts.fandom.com/wiki/Invasion (search snippet only)
- https://microvolts.fandom.com/wiki/Items (search snippet only)
- https://microvolts.fandom.com/wiki/Shop (search snippet only)
- https://microvolts.fandom.com/wiki/Category:Modes (search snippet only)
- https://microvolts.fandom.com/wiki/Category:Maps (search snippet only)
- https://microvolts.fandom.com/wiki/Selection_Screen (search snippet only)
- https://mvs.fandom.com/wiki/Weapons (search snippet only)
- https://mvs.fandom.com/wiki/Tips_&_Tricks (via r.jina.ai proxy / search snippet)
- https://mvs.fandom.com/wiki/Melees (via r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Snipers (via r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Maps (search snippet only)
- https://mvs.fandom.com/wiki/Modes (search snippet only)
- https://mvs.fandom.com/wiki/Test_server (search snippet only)
- https://mvs.fandom.com/wiki/Frequently_Asked_Questions (search snippet only)
- https://mvs.fandom.com/wiki/Bitmap (via r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Neighborhood (via r.jina.ai proxy)
- https://mvs.fandom.com/wiki/The_Studio (via r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Academy (via r.jina.ai proxy)
- https://mvs.fandom.com/wiki/Model_Ship (via r.jina.ai proxy)
- http://fantasysportsvideogames.blogspot.com/2013/01/microvolts-wavestepping-guide.html
- https://guidescroll.com/2011/10/microvolts-wavestepping-guide/ (search snippet only)
- http://orcz.com/MicroVolts:_Sniper_Rifles (search snippet only, page itself 404'd)
- http://mikedot.blogspot.com/2011/05/microvolts-review.html
- https://www.mmobomb.com/review/microvolts
- https://www.mmobomb.com/news/third-person-toy-themed-lobby-shooter-microvolts-relaunches-microvolts-recharged
- https://mmos.com/review/microvolts
- https://www.f2pg.com/microvolts/
- https://www.f2p.com/microvolts-a-new-map-and-good-old-items/
- http://microvoltsurge.blogspot.com/p/maps.html
- https://microvoltsguides.wordpress.com/2011/05/22/80/
- https://microvoltsguides.wordpress.com/2011/05/19/close-combat-tips-and-tactics/
- https://microvoltsguides.wordpress.com/
- https://www.magicgameworld.com/controls-for-microvolts-recharged/ (search snippet only, direct fetch 403'd)
- https://gamepretty.com/microvolts-recharged-beginners-guide/
- https://gamerjournalist.com/microvolts-recharged-codes/ (cited via synthesis, not independently re-fetched)
- https://www.gamespress.com/Masangsoft-Announces-Major-MICROVOLTS-Recharged-Update-with-New-League (title only, body returned 401)
- https://combatarms.fandom.com/wiki/HUD (generic other-game HUD reference only, not MicroVolts-specific)
- YouTube tutorial titles (title-only, transcripts/descriptions unreachable — 401/blocked): https://www.youtube.com/watch?v=d_rg6INEbZQ, https://www.youtube.com/watch?v=clCXTsHE9rs, https://www.youtube.com/watch?v=WJFUWeWWqKk, https://www.youtube.com/watch?v=CfZ6AK9Rmyk, https://www.youtube.com/watch?v=-6xT1nJPb4U, https://www.youtube.com/watch?v=e0Mj8ebmJYY, https://www.youtube.com/watch?v=N3SWEUKqaSs
