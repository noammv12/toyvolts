extends Node
## Global state: command-line args, mouse capture, settings (quality preset, display, input,
## audio), match setup, pause plumbing.

signal notice(text: String)          ## short HUD message (quality auto-adjusted, ...)
signal settings_changed()

const MENU_SCENE := "res://src/ui/main_menu.tscn"
const MAPS := {
    "lalu_party": {"name": "Lalu's Birthday", "scene": "res://src/world/lalu_party.tscn",
        "blurb": "Hila's party room: a giant cake with 12 candles, 30 balloons, a pinata, five gifts, a bouncy castle, a moon corner and a slide."},
    "toy_room": {"name": "Toy Room", "scene": "res://src/world/toy_room.tscn",
        "blurb": "A kid's bedroom at toy scale: rug arena, bed ramp, dining table high ground."},
    "diner": {"name": "Diner", "scene": "res://src/world/diner.tscn",
        "blurb": "A restaurant kitchen: counter island, appliance walls, crate stacks, tiled floor."},
}
const SETTINGS_PATH := "user://settings.cfg"
const FPS_CAPS := [0, 60, 120, 144, 240]
const PROBE_FPS_FLOOR := 50.0        ## auto mode drops one preset when the first match runs below this

var mouse_captured := false
var mouse_sensitivity := 0.0022
var headless := false
var mode := "practice"      ## practice | ffa | tdm | elim | ctb | party
var bot_count := 5
var bot_difficulty := "normal"   ## easy | normal | hard (Bot.SKILL_RANGES)
var map := "toy_room"            ## MAPS key
var skin := "Knight"        ## Skins.ALL id
var player_name := "You"    ## shown in feeds and (online) to other players
var match_active := true

# graphics + display settings (user://settings.cfg)
var quality := "high"       ## resolved preset: low | medium | high ("none" = untouched, bench only)
var quality_auto := true    ## chosen by Quality.detect() + the first-match probe, not by hand
var quality_probed := false
var render_scale := 1.0
var vsync := true
var fps_cap := 0
var fullscreen := false
var volume := 1.0
var gpu_index := 0          ## hybrid laptops: which adapter to render on (needs a relaunch)
var gpu_name := ""          ## adapter name seen when gpu_index was chosen

var base_time_scale := 1.0
var _hitstop_serial := 0
var _args := {}
var _probe_frames: PackedFloat64Array = []


## Freeze-frame for big hits (sniper kills): real-time `seconds` at `scale` speed, then back.
func hitstop(seconds: float, scale := 0.05) -> void:
    if headless:
        return
    _hitstop_serial += 1
    var serial := _hitstop_serial
    Engine.time_scale = base_time_scale * scale
    await get_tree().create_timer(seconds, true, false, true).timeout
    if serial == _hitstop_serial:
        Engine.time_scale = base_time_scale
var trace_enabled := false
var _trace: Array = []       ## [msec, tag] ring, bench hitch attribution


func _init() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--"):
            var kv := a.trim_prefix("--").split("=", true, 1)
            _args[kv[0]] = kv[1] if kv.size() > 1 else "true"


func _ready() -> void:
    headless = DisplayServer.get_name() == "headless"
    load_settings()
    if has_arg("mode"):
        mode = arg("mode")
    bot_count = int(arg("bots", str(bot_count)))
    if has_arg("difficulty"):
        bot_difficulty = arg("difficulty")
    if has_arg("map") and MAPS.has(arg("map")):
        map = arg("map")
    skin = arg("skin", skin)
    if has_arg("timescale"):   # debug: slow motion for effect captures
        base_time_scale = float(arg("timescale"))
        Engine.time_scale = base_time_scale
    if has_arg("quality"):
        quality = arg("quality")
        quality_auto = false
        quality_probed = true
        if Quality.is_level(quality):
            render_scale = Quality.preset(quality).scale
    if has_arg("scale"):
        render_scale = float(arg("scale"))
    if has_arg("bench"):       # measure real frame times: no vsync, no cap, windowed
        vsync = has_arg("vsync")
        fps_cap = int(arg("cap", "0"))
        fullscreen = has_arg("fullscreen")
    apply_display()
    _honor_gpu_choice()
    _start_network_from_args.call_deferred()


## `--server` (dedicated, no local toy) / `--host` / `--join=ip:port`, with `--port=`.
func _start_network_from_args() -> void:
    var port := int(arg("port", str(Net.DEFAULT_PORT)))
    if has_arg("server"):
        Net.host(port, true)
    elif has_arg("host"):
        Net.host(port, false)
    elif has_arg("join"):
        Net.join(arg("join"))


## The adapter can only be picked at launch (--gpu-index). If the saved choice is not the one
## we started on, relaunch once with the flag. Never loops: a relaunch carries the flag.
func _honor_gpu_choice() -> void:
    if headless or is_capture() or gpu_index <= 0:
        return
    var engine_args := OS.get_cmdline_args()
    if engine_args.has("--gpu-index"):
        return
    if RenderingServer.get_video_adapter_name() == gpu_name and not gpu_name.is_empty():
        return
    var args := PackedStringArray(["--gpu-index", str(gpu_index)])
    args.append_array(engine_args)
    var user_args := OS.get_cmdline_user_args()
    if not user_args.is_empty():
        args.append("--")
        args.append_array(user_args)
    if OS.create_process(OS.get_executable_path(), args) > 0:
        get_tree().quit()


func set_gpu_index(index: int) -> void:
    gpu_index = maxi(0, index)
    gpu_name = ""   # unknown until the relaunch reports it
    save_settings()
    if headless:
        return
    var args := PackedStringArray(["--gpu-index", str(gpu_index)])
    if OS.create_process(OS.get_executable_path(), args) > 0:
        get_tree().quit()


func _record_gpu_name() -> void:
    if gpu_index > 0 and OS.get_cmdline_args().has("--gpu-index") and gpu_name.is_empty():
        gpu_name = RenderingServer.get_video_adapter_name()
        save_settings()


func has_arg(name: String) -> bool:
    return _args.has(name)


## Cheap event log for the benchmark: what happened in the frames before a hitch.
func trace(tag: String) -> void:
    if not trace_enabled:
        return
    _trace.append([Time.get_ticks_msec(), tag])
    if _trace.size() > 256:
        _trace.pop_front()


func trace_since(msec: int) -> String:
    var out := PackedStringArray()
    for e in _trace:
        if e[0] >= msec:
            out.append("%s@%d" % [e[1], e[0]])
    return " ".join(out)


func arg(name: String, default := "") -> String:
    return _args.get(name, default)


func is_capture() -> bool:
    return has_arg("screenshot") or has_arg("bench") or has_arg("fxtest")


func set_mouse_captured(captured: bool) -> void:
    mouse_captured = captured
    if headless:
        return
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


# ---- settings --------------------------------------------------------------------

func load_settings() -> void:
    var cfg := ConfigFile.new()
    var loaded := cfg.load(SETTINGS_PATH) == OK
    skin = cfg.get_value("player", "skin", skin)
    player_name = cfg.get_value("player", "name", player_name)
    mouse_sensitivity = cfg.get_value("player", "sensitivity", mouse_sensitivity)
    if not has_arg("mode"):
        mode = cfg.get_value("match", "mode", mode)
        bot_count = cfg.get_value("match", "bots", bot_count)
        bot_difficulty = cfg.get_value("match", "difficulty", bot_difficulty)
    if not has_arg("map"):
        var saved_map: String = cfg.get_value("match", "map", map)
        if MAPS.has(saved_map):
            map = saved_map
    vsync = cfg.get_value("display", "vsync", vsync)
    fps_cap = cfg.get_value("display", "fps_cap", fps_cap)
    fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
    volume = cfg.get_value("audio", "volume", volume)
    gpu_index = cfg.get_value("graphics", "gpu_index", gpu_index)
    gpu_name = cfg.get_value("graphics", "gpu_name", gpu_name)
    InputSetup.read_from(cfg)   # [controls]: key bindings, applied to the InputMap now
    quality_auto = cfg.get_value("graphics", "auto", true)
    quality_probed = cfg.get_value("graphics", "probed", false)
    var saved_quality: String = cfg.get_value("graphics", "quality", "")
    if not loaded or saved_quality.is_empty() or not Quality.is_level(saved_quality):
        quality = Quality.detect() if not headless else "high"
        quality_auto = true
        quality_probed = false
        render_scale = Quality.preset(quality).scale
        if not headless:
            print("[quality] first launch: auto picked %s for \"%s\"" % [quality, RenderingServer.get_video_adapter_name()])
    else:
        quality = saved_quality
        render_scale = cfg.get_value("graphics", "render_scale", Quality.preset(quality).scale)


func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("player", "skin", skin)
    cfg.set_value("player", "name", player_name)
    cfg.set_value("player", "sensitivity", mouse_sensitivity)
    cfg.set_value("match", "mode", mode)
    cfg.set_value("match", "bots", bot_count)
    cfg.set_value("match", "difficulty", bot_difficulty)
    cfg.set_value("match", "map", map)
    cfg.set_value("graphics", "quality", quality if Quality.is_level(quality) else "high")
    cfg.set_value("graphics", "auto", quality_auto)
    cfg.set_value("graphics", "probed", quality_probed)
    cfg.set_value("graphics", "render_scale", render_scale)
    cfg.set_value("graphics", "gpu_index", gpu_index)
    cfg.set_value("graphics", "gpu_name", gpu_name)
    cfg.set_value("display", "vsync", vsync)
    cfg.set_value("display", "fps_cap", fps_cap)
    cfg.set_value("display", "fullscreen", fullscreen)
    cfg.set_value("audio", "volume", volume)
    InputSetup.write_to(cfg)
    cfg.save(SETTINGS_PATH)


## Controls sheet: rebind one action (swaps on conflict), save, tell the HUD / title hint.
func set_binding(action: String, event: InputEvent) -> bool:
    if not InputSetup.bind(action, event):
        return false
    save_settings()
    settings_changed.emit()
    return true


func reset_bindings() -> void:
    InputSetup.reset_defaults()
    save_settings()
    settings_changed.emit()


## Pick a preset by hand ("low"/"medium"/"high") or hand control back to auto-detection ("auto").
func set_quality(level: String) -> void:
    if level == "auto":
        quality_auto = true
        quality_probed = false
        quality = Quality.detect() if not headless else "high"
    elif Quality.is_level(level):
        quality = level
        quality_auto = false
        quality_probed = true
    else:
        return
    render_scale = Quality.preset(quality).scale
    apply_quality()
    save_settings()
    settings_changed.emit()


func set_render_scale(scale: float) -> void:
    render_scale = clampf(scale, 0.5, 1.0)
    apply_quality()
    save_settings()
    settings_changed.emit()


func set_display(new_vsync: bool, new_cap: int, new_fullscreen: bool) -> void:
    vsync = new_vsync
    fps_cap = new_cap
    fullscreen = new_fullscreen
    apply_display()
    save_settings()
    settings_changed.emit()


func set_volume(v: float) -> void:
    volume = clampf(v, 0.0, 1.0)
    apply_display()
    save_settings()
    settings_changed.emit()


func set_sensitivity(s: float) -> void:
    mouse_sensitivity = clampf(s, 0.0004, 0.01)
    save_settings()
    settings_changed.emit()


func apply_display() -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
    AudioServer.set_bus_mute(0, volume <= 0.0)
    if headless:
        return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = fps_cap
    var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
    if DisplayServer.window_get_mode() != want and not is_capture():
        DisplayServer.window_set_mode(want)


## Push the current preset into whatever arena is loaded (and the root viewport).
func apply_quality() -> void:
    _record_gpu_name()
    Quality.apply_global(quality)
    Quality.apply_viewport(quality, get_viewport(), render_scale)
    for node in get_tree().get_nodes_in_group("arena"):
        var arena := node as ArenaBase
        if arena:
            Quality.apply_environment(quality, arena.environment(), arena.sun())
    for node in get_tree().get_nodes_in_group("post_fx"):
        node.refresh()


## Auto mode only: watch the first seconds of a real match and step down one preset if it
## cannot hold PROBE_FPS_FLOOR. Runs once, then the result is saved.
func probe_quality() -> void:
    if not quality_auto or quality_probed or headless or is_capture() or quality == "low":
        return
    await get_tree().create_timer(3.0).timeout   # shader compiles, navmesh bake, GI warm-up
    _probe_frames = []
    var t := 0.0
    while t < 2.0:
        var before := Time.get_ticks_usec()
        await get_tree().process_frame
        var dt := (Time.get_ticks_usec() - before) / 1e6
        t += dt
        _probe_frames.append(dt)
    if _probe_frames.size() < 10 or get_tree().paused:
        return
    var avg := t / _probe_frames.size()
    quality_probed = true
    print("[quality] auto=%s probe: %.0f fps on %s (floor %.0f)" % [quality, 1.0 / avg, RenderingServer.get_video_adapter_name(), PROBE_FPS_FLOOR])
    if 1.0 / avg < PROBE_FPS_FLOOR:
        var lowered := Quality.lower(quality)
        quality = lowered
        render_scale = Quality.preset(quality).scale
        apply_quality()
        notice.emit("Graphics set to %s for a smoother game (Esc > Settings to change)" % Quality.label(quality))
    save_settings()


# ---- scene flow ------------------------------------------------------------------

func start_match(new_mode: String, bots: int) -> void:
    mode = new_mode
    bot_count = bots
    if mode == "party" and map != "lalu_party":
        map = "lalu_party"   # the party only happens in Lalu's room
    get_tree().paused = false
    get_tree().change_scene_to_file.call_deferred(map_scene())


## Lalu's birthday room: the title-screen button and the lobby preset.
func start_party() -> void:
    map = "lalu_party"
    bot_difficulty = "easy"
    save_settings()
    start_match("party", 5)


func map_scene() -> String:
    return MAPS.get(map, MAPS["toy_room"]).scene


func to_menu() -> void:
    get_tree().paused = false
    set_mouse_captured(false)
    Net.leave()
    get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


## The toy this machine controls (null in the menu, on a dedicated server, or before spawn).
func local_player() -> Character:
    return get_tree().get_first_node_in_group("local_player") as Character


func _input(event: InputEvent) -> void:
    if local_player() == null:
        return
    var pause := get_tree().get_first_node_in_group("pause_menu")
    if event.is_action_pressed("toggle_mouse"):
        if pause != null and not is_capture():
            pause.toggle()
        else:
            set_mouse_captured(not mouse_captured)
    elif event is InputEventMouseButton and event.pressed and not mouse_captured and not is_capture() \
            and not get_tree().paused:
        set_mouse_captured(true)
