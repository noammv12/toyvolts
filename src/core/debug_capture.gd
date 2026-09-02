extends Node
## Visual verification loop: run the game with
##   tools/godot.sh --path . -- --screenshot=<abs path>.png [--frames=45|"40,60,80"]
##       [--freeze_on=fire|explode|hit|land|death|respawn] [--freeze_delay=3]
## It waits N frames, saves the rendered frame(s) and quits. With --freeze_on the scene is
## paused a few frames after the event so short-lived effects can be captured deliberately.

var _frozen := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if Game.has_arg("freeze_on"):
        _arm_freeze(Game.arg("freeze_on"), int(Game.arg("freeze_delay", "3")))
    if Game.has_arg("bind"):   # --bind=weapon_6:E  (capture only, not saved)
        var parts := Game.arg("bind").split(":")
        if parts.size() == 2:
            var ev := InputEventKey.new()
            ev.physical_keycode = OS.find_keycode_from_string(parts[1]) as Key
            InputSetup.bind(parts[0], ev)
            Game.settings_changed.emit()
    if Game.has_arg("kill_me"):   # capture: the local toy falls apart on frame N
        _kill_me(int(Game.arg("kill_me", "60")))
    if Game.has_arg("fxtest"):
        _fx_test(int(Game.arg("fxtest", "30")))
    if Game.has_arg("ui"):
        _show_ui(Game.arg("ui"), int(Game.arg("ui_frame", "30")))
    if Game.has_arg("screenshot"):
        _capture(Game.arg("screenshot"), Game.arg("frames", "45"))
    if Game.has_arg("bench"):
        _bench()
    if Game.has_arg("quit_after"):   # seconds; smoke tests end themselves
        get_tree().create_timer(float(Game.arg("quit_after", "10")), true).timeout.connect(func() -> void:
            print("[capture] quit_after elapsed")
            get_tree().quit())


## `--ui=pause|settings|lobby [--ui_frame=30]`: open the pause overlay (or its settings sheet)
## for a capture. Works in the arena (pause menu) and in the main menu (settings, lobby).
func _show_ui(which: String, at_frame: int) -> void:
    for i in at_frame:
        await get_tree().process_frame
    var pause := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
    if pause != null:
        pause.open()
        if which == "settings" or which == "controls":
            pause._open_settings()
        if which == "controls":
            pause._settings.open_controls()
            if Game.has_arg("ui_listen"):
                pause._settings._start_listening(Game.arg("ui_listen"))
        return
    var menu := get_tree().current_scene
    if menu != null and which.begins_with("lobby") and menu.has_method("open_lobby"):
        menu.open_lobby()
        if which == "lobby_host":   # the room view: host a game on a spare port
            Net.host(int(Game.arg("port", "7799")))
    elif menu != null and menu.has_method("open_settings"):
        menu.open_settings()


## `--kill_me=N`: a deterministic death for the fall-apart / death-camera captures.
func _kill_me(at_frame: int) -> void:
    var player: Character = null
    while player == null:
        await get_tree().process_frame
        player = Game.local_player()
    for i in at_frame:
        await get_tree().process_frame
    player.protection_left = 0.0
    player.take_damage(999.0, null, player.center(), Vector3.ZERO, false)


## Stages every effect a few metres in front of the player and freezes the scene.
func _fx_test(at_frame: int) -> void:
    var player: Character = null
    while player == null:
        await get_tree().process_frame
        player = Game.local_player()
    for i in at_frame:
        await get_tree().process_frame
    var eye := player.eye()
    var f := player.facing()
    var r := f.cross(Vector3.UP)
    var base := eye + f * 5.0
    Vfx.muzzle_flash(base + r * -2.5, f, 0.9)
    Vfx.tracer(base + r * -1.2 + Vector3(0, -0.5, 0), base + r * -1.2 + Vector3(0, -0.5, 0) + f * 6.0)
    Vfx.impact(base + r * 0.0 + Vector3(0, -0.3, 0), -f, false)
    Vfx.impact(base + r * 1.2 + Vector3(0, -0.3, 0), -f, true)
    Vfx.casing(base + r * -2.0 + Vector3(0, -0.6, 0), r)
    Vfx.explosion(base + f * 4.0 + r * 3.0 + Vector3(0, -1.0, 0), 2.5)
    # persistent probes: plain sprite, noise sprite, additive sprite, glow streak
    var s1 := Sprite3D.new()
    s1.texture = Vfx._radial
    s1.pixel_size = 1.5 / 64.0
    s1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s1.modulate = Color(1, 0.5, 0.2)
    Vfx.add_child(s1)
    s1.global_position = base + r * -3.5 + Vector3(0, 1.0, 0)
    var s2 := Vfx._billboard(Vfx._smoke, Color(0.3, 0.3, 0.3, 0.9), 1.5, false)
    Vfx.add_child(s2)
    s2.global_position = base + r * -2.0 + Vector3(0, 1.0, 0)
    var s3 := Vfx._billboard(Vfx._radial, Color(1.0, 0.8, 0.45, 1.0), 1.5, true)
    Vfx.add_child(s3)
    s3.global_position = base + r * -0.5 + Vector3(0, 1.0, 0)
    var streak := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.07, 0.07, 1.6)
    streak.mesh = box
    streak.material_override = Vfx._glow_mat(Color(1.0, 0.85, 0.45), 4.0)
    Vfx.add_child(streak)
    streak.global_position = base + r * 1.0 + Vector3(0, 1.0, 0)
    streak.rotation.y = 0.6
    print("[capture] smoke tex size ", Vfx._smoke.get_size(), " radial ", Vfx._radial.get_size())
    for i in 2:
        await get_tree().process_frame
    get_tree().paused = true
    print("[capture] fx test staged")


func _arm_freeze(kind: String, delay_frames: int) -> void:
    var player: Character = null
    while player == null:
        await get_tree().process_frame
        player = Game.local_player()
    match kind:
        "fire":
            player.arsenal.fired.connect(func(_d: WeaponData) -> void: _freeze_soon(kind, delay_frames))
        "explode":
            Vfx.shake.connect(func(_p: Vector3, _s: float) -> void: _freeze_soon(kind, delay_frames))
        "hit":
            player.arsenal.hit_confirmed.connect(func(_k: bool, _h: bool) -> void: _freeze_soon(kind, delay_frames))
        "land":
            player.landed.connect(func(speed: float) -> void:
                if speed > 3.0:
                    _freeze_soon(kind, delay_frames))
        "death":
            player.died.connect(func(_v: Character, _k: Character) -> void: _freeze_soon(kind, delay_frames))
        "respawn":
            player.respawned.connect(func() -> void: _freeze_soon(kind, delay_frames))


func _freeze_soon(kind: String, delay_frames: int) -> void:
    if _frozen:
        return
    _frozen = true
    for i in delay_frames:
        await get_tree().process_frame
    get_tree().paused = true
    print("[capture] frozen on ", kind)
    if Game.has_arg("dump_vfx"):
        for n in Vfx.get_children():
            if n is Node3D and n.visible and n.position.y > -50.0:
                var extra := ""
                if n is GeometryInstance3D:
                    extra = " transparency=%.2f" % n.transparency
                if n is GPUParticles3D:
                    extra = " emitting=%s amount=%d" % [n.emitting, n.amount]
                if n is Sprite3D:
                    extra = " modulate=%s axis=%d billboard=%d" % [n.modulate, n.axis, n.billboard]
                print("[capture] vfx %s kind=%s pos=%s scale=%s%s" % [n.get_class(), n.get_meta("kind", "?"),
                    n.global_position, n.scale, extra])


## `frames` may be a single number or a comma list (e.g. "80,90,100"): one PNG per entry,
## suffixed with the frame number when more than one.
func _capture(path: String, frames_spec: String) -> void:
    var targets: Array[int] = []
    for part in frames_spec.split(","):
        if part.strip_edges() != "":
            targets.append(int(part))
    targets.sort()
    var frame := 0
    for target in targets:
        while frame < target:
            await get_tree().process_frame
            frame += 1
        await RenderingServer.frame_post_draw
        var who := Game.local_player()
        if who != null and who.controller != null:
            print("[capture] player at %s  camera at %s" % [who.global_position, who.controller.camera.global_position])
        if who != null and who.figure.hat != null:
            var sk := who.figure.skeleton
            var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head"))
            print("[capture] hat rel %s (head bone rel %s, figure rel %s)" % [(who.figure.hat.global_position - who.global_position).snapped(Vector3(0.01, 0.01, 0.01)),
                (head.origin - who.global_position).snapped(Vector3(0.01, 0.01, 0.01)), (who.figure.global_position - who.global_position).snapped(Vector3(0.01, 0.01, 0.01))])
        var cam := get_viewport().get_camera_3d()
        if cam != null:
            print("[capture] active camera %s at %s looking %s" % [cam.name, cam.global_position, -cam.global_transform.basis.z])
        var img := get_viewport().get_texture().get_image()
        var abs_path := ProjectSettings.globalize_path(path)
        if targets.size() > 1:
            abs_path = abs_path.get_basename() + "_f%03d.png" % target
        DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
        var err := img.save_png(abs_path)
        if err == OK:
            print("[capture] saved ", abs_path, " ", img.get_size())
        else:
            print("[capture] FAILED err=", err, " path=", abs_path)
    get_tree().quit()


# ---- benchmark -------------------------------------------------------------------
## `--bench [--quality=low|medium|high] [--scale=0.66]`: drives the player through three fixed
## phases (idle look, 360 sweep, combat with every effect) and prints per-phase frame times.
## tools/bench.sh runs it once per preset and tabulates the "[bench] total" lines.

const BENCH_SKIP_FRAMES := 120   ## warm-up: shader compiles, navmesh, first SDFGI cascades

var _bench_frames: PackedFloat64Array = []
var _bench_gpu: PackedFloat64Array = []
var _bench_cpu: PackedFloat64Array = []
var _bench_recording := false
var _bench_last_usec := 0


func _process(_delta: float) -> void:
    if _bench_recording:
        # wall-clock gap between frames: the engine clamps `delta` at 8 physics steps (133 ms)
        var now := Time.get_ticks_usec()
        var delta := (now - _bench_last_usec) / 1e6 if _bench_last_usec > 0 else _delta
        _bench_last_usec = now
        _bench_frames.append(delta * 1000.0)
        var rid := get_viewport().get_viewport_rid()
        var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
        var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
        _bench_gpu.append(gpu)
        _bench_cpu.append(cpu)
        if delta > 0.033:
            print("[bench] hitch %6.1fms  gpu=%5.1f render_cpu=%5.1f process=%5.1f physics=%5.1f objects=%d nodes=%d  events: %s" % [
                delta * 1000.0, gpu, cpu,
                Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
                Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
                Performance.get_monitor(Performance.OBJECT_COUNT),
                Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
                Game.trace_since(Time.get_ticks_msec() - int(delta * 1000.0) - 40)])


func _bench() -> void:
    var player: Character = null
    while player == null:
        await get_tree().process_frame
        player = Game.local_player()
    player.controller.input_enabled = false
    Game.match_active = true
    Game.trace_enabled = true
    if not Game.has_arg("nomeasure"):
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
    for i in BENCH_SKIP_FRAMES:
        await get_tree().process_frame
    var results := []
    # phase 1: idle at the spawn, looking across the room
    player.global_position = Vector3(0, 0.3, 19)
    player.yaw = 0.0
    player.pitch = deg_to_rad(-6.0)
    results.append(await _bench_phase("idle", 3.0, func(_t: float) -> void: pass, player))
    # phase 2: full turn from the middle of the rug
    player.global_position = Vector3(0, 0.3, 8)
    player.pitch = deg_to_rad(-8.0)
    results.append(await _bench_phase("sweep", 4.0, func(t: float) -> void:
        player.yaw = t / 4.0 * TAU, player))
    # phase 3: combat: rifle burst, three rockets, gatling, while turning slowly
    player.global_position = Vector3(0, 0.3, 12)
    player.yaw = 0.0
    player.pitch = deg_to_rad(-14.0)
    var script := [[2, 0.0, 1.2, true], [6, 1.3, 2.6, false], [5, 2.7, 4.5, true]]
    results.append(await _bench_phase("combat", 4.5, func(t: float) -> void:
        player.yaw = sin(t * 1.4) * 0.6
        var want := false
        for step in script:
            if t >= step[1] and t < step[2]:
                if player.arsenal.slot != step[0]:
                    player.arsenal.select(step[0])
                want = step[3] or (int(t * 12.0) % 4 == 0)   # semi-auto: pulse the trigger
        player.arsenal.trigger = want, player))
    player.arsenal.trigger = false
    # summary
    var all_frames: PackedFloat64Array = []
    var all_gpu: PackedFloat64Array = []
    var all_cpu: PackedFloat64Array = []
    for r in results:
        all_frames.append_array(r.frames)
        all_gpu.append_array(r.gpu)
        all_cpu.append_array(r.cpu)
    var total := _bench_stats("total", all_frames, all_gpu, all_cpu)
    var vp := get_viewport()
    var msaa := {Viewport.MSAA_DISABLED: "off", Viewport.MSAA_2X: "2x", Viewport.MSAA_4X: "4x", Viewport.MSAA_8X: "8x"}
    print("[bench] setup preset=%s scale=%.2f mode=%s msaa=%s res=%s gpu=\"%s\" nodes=%d" % [
        Game.quality, vp.scaling_3d_scale, Quality.scale_mode_name(vp.scaling_3d_mode), msaa.get(vp.msaa_3d, "?"),
        "%dx%d" % [vp.size.x, vp.size.y], RenderingServer.get_video_adapter_name(),
        Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
    print("[bench] draw_calls=%d primitives=%d objects=%d" % [
        Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
        Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
    print(total)
    await get_tree().process_frame
    get_tree().quit()


func _bench_phase(name: String, seconds: float, step: Callable, player: Character) -> Dictionary:
    _bench_frames = []
    _bench_gpu = []
    _bench_cpu = []
    _bench_last_usec = 0
    var t := 0.0
    _bench_recording = true
    while t < seconds:
        step.call(t)
        var before := Time.get_ticks_usec()
        await get_tree().process_frame
        t += (Time.get_ticks_usec() - before) / 1e6
    _bench_recording = false
    player.arsenal.trigger = false
    var frames := _bench_frames.duplicate()
    var gpu := _bench_gpu.duplicate()
    var cpu := _bench_cpu.duplicate()
    print(_bench_stats(name, frames, gpu, cpu))
    return {"frames": frames, "gpu": gpu, "cpu": cpu}


func _bench_stats(name: String, frames: PackedFloat64Array, gpu: PackedFloat64Array, cpu: PackedFloat64Array) -> String:
    if frames.is_empty():
        return "[bench] %s: no frames" % name
    var sorted := frames.duplicate()
    sorted.sort()
    var sum := 0.0
    for f in frames:
        sum += f
    var avg := sum / frames.size()
    var p99 := sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))]
    var worst := sorted[sorted.size() - 1]
    var gsum := 0.0
    for g in gpu:
        gsum += g
    var csum := 0.0
    for c in cpu:
        csum += c
    var hitches := 0
    for f in frames:
        if f > 33.0:
            hitches += 1
    return "[bench] %-7s avg=%6.2fms  p99=%6.2fms  max=%6.2fms  fps=%4.0f  gpu=%5.2fms  cpu=%5.2fms  hitches=%d  frames=%d" % [
        name, avg, p99, worst, 1000.0 / avg, gsum / gpu.size(), csum / cpu.size(), hitches, frames.size()]
