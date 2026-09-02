extends Node
## Registers every input action in code so the whole map lives in one readable file.
## (The editor's Input Map UI would also work; this keeps it diffable.)

const KEYS := {
    "move_forward": [KEY_W, KEY_UP],
    "move_back": [KEY_S, KEY_DOWN],
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "jump": [KEY_SPACE],
    "reload": [KEY_R],
    "weapon_last": [KEY_Q],
    "weapon_1": [KEY_1],
    "weapon_2": [KEY_2],
    "weapon_3": [KEY_3],
    "weapon_4": [KEY_4],
    "weapon_5": [KEY_5],
    "weapon_6": [KEY_6],
    "weapon_7": [KEY_7],
    "toggle_mouse": [KEY_ESCAPE],
    "scoreboard": [KEY_TAB],
    "menu": [KEY_M],
}

const MOUSE := {
    "fire": MOUSE_BUTTON_LEFT,
    "alt_fire": MOUSE_BUTTON_RIGHT,
    "weapon_next": MOUSE_BUTTON_WHEEL_UP,
    "weapon_prev": MOUSE_BUTTON_WHEEL_DOWN,
}


func _init() -> void:
    for action in KEYS:
        for keycode in KEYS[action]:
            _add_key(action, keycode)
    for action in MOUSE:
        _add_mouse(action, MOUSE[action])


func _ensure(action: String) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)


func _add_key(action: String, keycode: Key) -> void:
    _ensure(action)
    var ev := InputEventKey.new()
    ev.physical_keycode = keycode
    InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
    _ensure(action)
    var ev := InputEventMouseButton.new()
    ev.button_index = button
    InputMap.action_add_event(action, ev)
