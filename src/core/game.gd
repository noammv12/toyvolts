extends Node
## Global state: command-line args, mouse capture, settings.

var mouse_captured := false
var mouse_sensitivity := 0.0022
var headless := false
var _args := {}


func _init() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--"):
            var kv := a.trim_prefix("--").split("=", true, 1)
            _args[kv[0]] = kv[1] if kv.size() > 1 else "true"


func _ready() -> void:
    headless = DisplayServer.get_name() == "headless"
    set_mouse_captured(not headless and not has_arg("screenshot"))


func has_arg(name: String) -> bool:
    return _args.has(name)


func arg(name: String, default := "") -> String:
    return _args.get(name, default)


func set_mouse_captured(captured: bool) -> void:
    mouse_captured = captured
    if headless:
        return
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_mouse"):
        set_mouse_captured(not mouse_captured)
    elif event is InputEventMouseButton and event.pressed and not mouse_captured and not has_arg("screenshot"):
        set_mouse_captured(true)
