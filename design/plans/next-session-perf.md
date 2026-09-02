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
