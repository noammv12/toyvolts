# Next session: performance first, then keep building (no online yet)

Noam tried the v0.3 release on another machine: "SOOOO LAGGY". Fix that before anything else.
Verify with numbers, not feelings: add a benchmark, measure before/after, ship a new release.

## Where the frame time is going (suspects, most likely first)

All of these are on by default in `src/world/toy_room.tscn` (Environment) and cost a lot on a
laptop / integrated GPU. On the dev laptop (RTX 3050) captures show 45-125 fps at 1600x900.

1. `sdfgi_enabled` (dynamic GI) - biggest single cost. Replace on Low/Medium with a plain
   ambient + the existing lights, or a baked LightmapGI (the room is static; bake once).
2. `ssil_enabled` - expensive screen-space GI. Off on Low/Medium.
3. `volumetric_fog_enabled` - off on Low, low density/resolution on Medium.
4. `ssao_enabled` - keep on Medium+ at low quality, off on Low.
5. Outline post-process (`src/core/post_fx.gd`, `shaders/outline_post.gdshader`) reads the
   normal-roughness buffer, which forces an extra prepass. Depth-only outline on Low.
6. `anti_aliasing/quality/msaa_3d=2` (4x) in `project.godot` - 2x on Medium, off + FXAA on Low.
7. Sun shadows: `directional_shadow_max_distance 80`, 4 splits, blend splits, `shadow_blur 1.2`.
   Medium: 50 m, no blend; Low: 30 m, 2 splits, size 2048.
8. Resolution: add `scaling_3d_scale` 0.75/0.66 with FSR2 (`scaling_3d_mode`) on Medium/Low.
   This is the cheapest big win on weak GPUs.
9. CPU: `Vfx` creates new materials/particles per shot (pool them), `ToonMat.apply` makes a
   unique ShaderMaterial per surface (share by texture), bots raycast every character in
   `_pick_target` (fine), HUD widgets `queue_redraw()` every frame (fine).
10. VSync / frame pacing: expose vsync toggle and an fps cap in settings.

## Plan

1. **Bench**: `--bench` arg → fixed camera path through the Toy Room for 10 s, prints avg/1%-low
   frame time per phase to stdout; `tools/bench.sh` runs it per preset and prints a table.
   Also show frame time (ms) next to the fps counter in the HUD.
2. **Quality presets** in `Game` (`quality`: low/medium/high, saved in user://settings.cfg,
   `--quality=` arg): one function `Game.apply_quality(env: Environment, sun, viewport)` called by
   `ArenaBase._ready`. Auto-detect on first run from `RenderingServer.get_video_adapter_name()`
   + a 2-second probe (if the first frames are slow, drop a level) and tell the user.
3. **Settings screen** in the main menu: quality preset, resolution scale, vsync, fps cap,
   fullscreen, mouse sensitivity, audio volume. Also reachable in-match (Esc → M currently
   goes to menu; add a pause overlay with Resume / Settings / Menu).
4. **Static-light option**: try a LightmapGI bake for the Toy Room (needs the editor bake or
   runtime `LightmapGI.bake()`; the headless editor can bake via a tool script). If it works,
   Medium = lightmap + no SDFGI and looks nearly as good.
5. Pool VFX materials/particles; share toon materials per texture; profile with
   `--print-fps` and Godot's `Performance` monitors (`Performance.get_monitor`).
6. Re-export (`tools/export.sh`), `gh release create v0.4 build/ToyVolts-win64.zip`, tell Noam
   which preset to pick if auto-detect gets it wrong.

Definition of done: Low preset >= 60 fps on integrated graphics class hardware (estimate via
the RTX 3050 running the Low preset at >= 200 fps), High still looks like the v0.3 captures.

## Then continue the program (still no online)

- Feel tuning against the Steam client once Noam plays: `src/weapons/weapon_db.gd`,
  movement in `src/character/character.gd`, camera in `src/player/player.tscn`.
- Capture the Battery mode + item match (health/ammo capsules).
- More maps with the KayKit City kit (Neighborhood) and Restaurant kit (Diner).
- Bot difficulty levels; better bot movement on furniture (jump links).
- Gun visibility from straight behind the big-head figures (camera / hold pose).

## Rituals (unchanged)

`tools/import.sh` after new class_name scripts or assets → `tools/test.sh` (63 checks) →
`tools/shot.sh <name> --mode=ffa --frames=200 ...` and look at the PNG → commit → push →
`tools/export.sh` + `gh release create` for a build. Gotchas are in memory (project_toyvolts.md).

## Results (2026-09-02, v0.4)

Bench: `tools/bench.sh` (idle / 360 sweep / combat, 1600x900, 5 bots, vsync off).

| GPU | none (v0.3) | Low | Medium | High |
|---|---|---|---|---|
| RTX 3050 Laptop (dev) | 91 fps, 7.1 ms GPU | 267 fps, 1.4 ms | 157 fps, 3.5 ms | 85 fps, 7.2 ms |
| Intel UHD iGPU (`--gpu-index 1`) | - | 111 fps, 6.9 ms | 29 fps, 27 ms | 15 fps, 58 ms |

So v0.3 on an iGPU was ~15 fps: that is the "SOOOO LAGGY". Low clears 60 fps there with
room; Medium is for GTX-1650/RTX-2060 class; High for RTX 30+.

What each preset does: `src/core/quality.gd` (SDFGI/SSIL only on High, SSAO very-low on
Medium, fog off on Low, MSAA 4x/off/off, FSR2 0.8 on Medium, FSR1 0.66 + FXAA on Low,
sun shadow 80/50/48 m with 4096/4096/2048 atlas, depth-only outline on Low, mesh LOD bias).
Low's shadow range must cover the room (48 m): with 30 m the far walls lost their shadow and
the frame looked washed out.

LightmapGI: `LightmapGI.bake()` is not exposed to scripts in 4.7 (neither runtime nor editor
`-s`), so the bake needs a manual editor session. Not done; Medium uses ambient 1.0 + SSAO
instead and looks close to High in the captures (captures/preset_*.png).

CPU: Vfx is fully pooled (no per-shot node/material creation; p99 on Low went 12-16 ms ->
6.7 ms on the RTX), world kit models share toon materials, figure flash uniforms only upload
on change. Physics + scripts are ~1 ms; the game is GPU-bound on every preset.

Environmental finding: on this ASUS laptop ANY Godot window rendered on the RTX 3050 freezes
~500 ms every 1.5-3 s (empty project too; Vulkan, D3D12 and OpenGL; not vsync, audio,
tablet driver, power plan or joypads). Intel iGPU and headless are clean. Not a game bug;
the settings GPU pick (`--gpu-index`) is the in-game workaround.
