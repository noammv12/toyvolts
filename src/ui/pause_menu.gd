class_name PauseMenu
extends CanvasLayer
## Esc in a match: dims the screen, frees the mouse, pauses the tree. Resume / Settings / Menu.

const ACCENT := Color(0.95, 0.42, 0.2)

var is_open := false
var _root: Control
var _buttons: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
    add_to_group("pause_menu")
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.visible = false
    add_child(_root)
    var dim := ColorRect.new()
    dim.color = Color(0.03, 0.04, 0.06, 0.72)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(dim)

    _buttons = VBoxContainer.new()
    _buttons.add_theme_constant_override("separation", 10)
    _buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
    _buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _buttons.grow_vertical = Control.GROW_DIRECTION_BOTH
    _root.add_child(_buttons)
    var title := Label.new()
    title.text = "PAUSED"
    title.add_theme_font_size_override("font_size", 46)
    title.add_theme_color_override("font_color", ACCENT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _buttons.add_child(title)
    _button("Resume", close)
    _button("Settings", _open_settings)
    _button("Main Menu", func() -> void: Game.to_menu())
    var hint := Label.new()
    hint.text = "Esc resumes"
    hint.add_theme_font_size_override("font_size", 14)
    hint.modulate = Color(1, 1, 1, 0.5)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _buttons.add_child(hint)

    _settings = SettingsPanel.new()
    _settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
    _settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _settings.grow_vertical = Control.GROW_DIRECTION_BOTH
    _settings.visible = false
    _settings.closed.connect(func() -> void:
        _settings.visible = false
        _buttons.visible = true)
    _root.add_child(_settings)


func _button(text: String, on_pressed: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(280, 46)
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        on_pressed.call())
    _buttons.add_child(b)


func toggle() -> void:
    if is_open:
        close()
    else:
        open()


func open() -> void:
    is_open = true
    _root.visible = true
    _buttons.visible = true
    _settings.visible = false
    get_tree().paused = true
    Game.set_mouse_captured(false)


func close() -> void:
    is_open = false
    _root.visible = false
    get_tree().paused = false
    Game.set_mouse_captured(true)


func _open_settings() -> void:
    _buttons.visible = false
    _settings.visible = true
