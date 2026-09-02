extends Node
## Global state: command-line args, mouse capture, settings, match setup.

const ARENA_SCENE := "res://src/world/toy_room.tscn"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

var mouse_captured := false
var mouse_sensitivity := 0.0022
var headless := false
var mode := "practice"      ## practice | ffa | tdm
var bot_count := 5
var skin := "Knight"        ## Skins.ALL id
var match_active := true
var _args := {}


func _init() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--"):
            var kv := a.trim_prefix("--").split("=", true, 1)
            _args[kv[0]] = kv[1] if kv.size() > 1 else "true"


func _ready() -> void:
    headless = DisplayServer.get_name() == "headless"
    if has_arg("mode"):
        mode = arg("mode")
    bot_count = int(arg("bots", "5"))
    skin = arg("skin", skin)
    if has_arg("timescale"):   # debug: slow motion for effect captures
        Engine.time_scale = float(arg("timescale"))


func has_arg(name: String) -> bool:
    return _args.has(name)


func arg(name: String, default := "") -> String:
    return _args.get(name, default)


func set_mouse_captured(captured: bool) -> void:
    mouse_captured = captured
    if headless:
        return
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


const SETTINGS_PATH := "user://settings.cfg"


func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return
    skin = cfg.get_value("player", "skin", skin)
    mouse_sensitivity = cfg.get_value("player", "sensitivity", mouse_sensitivity)
    if not has_arg("mode"):
        mode = cfg.get_value("match", "mode", mode)
        bot_count = cfg.get_value("match", "bots", bot_count)


func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("player", "skin", skin)
    cfg.set_value("player", "sensitivity", mouse_sensitivity)
    cfg.set_value("match", "mode", mode)
    cfg.set_value("match", "bots", bot_count)
    cfg.save(SETTINGS_PATH)


func start_match(new_mode: String, bots: int) -> void:
    mode = new_mode
    bot_count = bots
    get_tree().change_scene_to_file.call_deferred(ARENA_SCENE)


func to_menu() -> void:
    set_mouse_captured(false)
    get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


func _input(event: InputEvent) -> void:
    if get_tree().get_first_node_in_group("player") == null:
        return
    if event.is_action_pressed("toggle_mouse"):
        set_mouse_captured(not mouse_captured)
    elif event is InputEventMouseButton and event.pressed and not mouse_captured and not has_arg("screenshot"):
        set_mouse_captured(true)
