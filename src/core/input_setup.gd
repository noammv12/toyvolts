extends Node
## Registers every input action in code and owns the key bindings: one primary binding per
## action (a key or a mouse button). Rebinding to a key another action uses swaps the two.
## Saved under [controls] in user://settings.cfg by Game (read_from / write_to); applied to
## the InputMap at boot and after every change.

## Every rebindable action in the order the Controls sheet lists them: [action, label].
const ORDER := [
    ["move_forward", "Forward"], ["move_back", "Back"], ["move_left", "Left"], ["move_right", "Right"],
    ["jump", "Jump"], ["crouch", "Crouch"], ["fire", "Fire"], ["alt_fire", "Aim / alt fire"],
    ["reload", "Reload"], ["weapon_1", "Melee"], ["weapon_2", "Rifle"], ["weapon_3", "Shotgun"],
    ["weapon_4", "Sniper"], ["weapon_5", "Gatling"], ["weapon_6", "Bazooka"], ["weapon_7", "Grenade launcher"],
    ["weapon_last", "Last weapon"], ["weapon_next", "Next weapon"], ["weapon_prev", "Previous weapon"],
    ["scoreboard", "Scoreboard"], ["toggle_mouse", "Pause"],
]
const DEFAULT_KEYS := {
    "move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
    "jump": KEY_SPACE, "crouch": KEY_CTRL, "reload": KEY_R, "weapon_last": KEY_Q,
    "weapon_1": KEY_1, "weapon_2": KEY_2, "weapon_3": KEY_3, "weapon_4": KEY_4,
    "weapon_5": KEY_5, "weapon_6": KEY_6, "weapon_7": KEY_7,
    "scoreboard": KEY_TAB, "toggle_mouse": KEY_ESCAPE,
}
const DEFAULT_MOUSE := {
    "fire": MOUSE_BUTTON_LEFT, "alt_fire": MOUSE_BUTTON_RIGHT,
    "weapon_next": MOUSE_BUTTON_WHEEL_UP, "weapon_prev": MOUSE_BUTTON_WHEEL_DOWN,
}
const FIXED := {"menu": KEY_M}     ## not rebindable (back to the title with the mouse free)
const MOUSE_NAMES := {
    MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
    MOUSE_BUTTON_WHEEL_UP: "Wheel Up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
    MOUSE_BUTTON_WHEEL_LEFT: "Wheel Left", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel Right",
    MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

signal bindings_changed()

var bindings := {}      ## action -> "key:<physical keycode>" | "mouse:<button index>"


func _init() -> void:
    for action in FIXED:
        _ensure(action)
        InputMap.action_add_event(action, _key_event(FIXED[action]))
    reset_defaults()


static func defaults() -> Dictionary:
    var out := {}
    for action in DEFAULT_KEYS:
        out[action] = "key:%d" % int(DEFAULT_KEYS[action])
    for action in DEFAULT_MOUSE:
        out[action] = "mouse:%d" % int(DEFAULT_MOUSE[action])
    return out


func reset_defaults() -> void:
    bindings = defaults()
    _apply_all()


## Bind `action` to `event` (InputEventKey or InputEventMouseButton). If another action already
## uses that input, it takes over this action's old binding (a swap: nothing is ever lost).
func bind(action: String, event: InputEvent) -> bool:
    var s := serialize(event)
    if s.is_empty() or not bindings.has(action):
        return false
    var old: String = bindings[action]
    for other in bindings:
        if other != action and bindings[other] == s:
            bindings[other] = old
    bindings[action] = s
    _apply_all()
    return true


## The event an action is bound to (null if unbound).
func event_for(action: String) -> InputEvent:
    return deserialize(bindings.get(action, ""))


## Short display name: "E", "Space", "LMB", "Wheel Up".
func binding_text(action: String) -> String:
    var s: String = bindings.get(action, "")
    if s.begins_with("key:"):
        var code := int(s.substr(4))
        var name := OS.get_keycode_string(code)
        return name if not name.is_empty() else "Key %d" % code
    if s.begins_with("mouse:"):
        var b := int(s.substr(6))
        return MOUSE_NAMES.get(b, "Mouse %d" % b)
    return "-"


## Compact form for the HUD weapon strip.
func short_text(action: String) -> String:
    var t := binding_text(action)
    return t.replace("Wheel Up", "Wh+").replace("Wheel Down", "Wh-").replace("Space", "Spc").replace("Escape", "Esc")


func label_of(action: String) -> String:
    for row in ORDER:
        if row[0] == action:
            return row[1]
    return action


static func serialize(event: InputEvent) -> String:
    if event is InputEventKey:
        var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
        return "key:%d" % code
    if event is InputEventMouseButton:
        return "mouse:%d" % int(event.button_index)
    return ""


static func deserialize(s: String) -> InputEvent:
    if s.begins_with("key:"):
        return _key_event(int(s.substr(4)))
    if s.begins_with("mouse:"):
        var ev := InputEventMouseButton.new()
        ev.button_index = int(s.substr(6)) as MouseButton
        return ev
    return null


## Settings file plumbing (Game owns user://settings.cfg).
func read_from(cfg: ConfigFile) -> void:
    var loaded := defaults()
    for action in loaded:
        var s: String = cfg.get_value("controls", action, loaded[action])
        if deserialize(s) != null:
            loaded[action] = s
    bindings = loaded
    _apply_all()


func write_to(cfg: ConfigFile) -> void:
    for action in bindings:
        cfg.set_value("controls", action, bindings[action])


func _apply_all() -> void:
    for action in bindings:
        _ensure(action)
        InputMap.action_erase_events(action)
        var ev := deserialize(bindings[action])
        if ev != null:
            InputMap.action_add_event(action, ev)
    bindings_changed.emit()


func _ensure(action: String) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)


static func _key_event(keycode: int) -> InputEventKey:
    var ev := InputEventKey.new()
    ev.physical_keycode = keycode as Key
    return ev
