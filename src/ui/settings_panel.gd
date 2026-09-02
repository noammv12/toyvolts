class_name SettingsPanel
extends PanelContainer
## Settings sheet shared by the main menu and the pause overlay: quality preset, resolution
## scale, vsync, fps cap, fullscreen, mouse sensitivity, volume, GPU (hybrid laptops).
## Every control applies immediately through Game.set_* (which also saves).

signal closed()

const ACCENT := Color(0.95, 0.42, 0.2)
const SENS_MIN := 0.0006
const SENS_MAX := 0.006

var _quality_buttons := {}
var _scale_slider: HSlider
var _scale_label: Label
var _vsync: CheckButton
var _cap_buttons := {}
var _fullscreen: CheckButton
var _sens_slider: HSlider
var _sens_label: Label
var _volume_slider: HSlider
var _volume_label: Label
var _gpu_label: Label
var _syncing := false
var _double_zoom: CheckButton
var _main: VBoxContainer
var _controls: VBoxContainer
var _bind_buttons := {}       ## action -> Button
var _listening := ""          ## action waiting for a key press
var _listen_hint: Label


func _ready() -> void:
    custom_minimum_size = Vector2(560, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.1, 0.14, 0.97)
    style.border_color = Color(1, 1, 1, 0.08)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.set_content_margin_all(26)
    add_theme_stylebox_override("panel", style)
    _build()
    Game.settings_changed.connect(_sync)
    _sync()


func _build() -> void:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    add_child(box)
    _main = box
    _build_controls()

    var head := HBoxContainer.new()
    box.add_child(head)
    var title := Label.new()
    title.text = "SETTINGS"
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    var back := Button.new()
    back.text = "Back"
    back.custom_minimum_size = Vector2(110, 38)
    back.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        closed.emit())
    head.add_child(back)

    # ---- graphics
    box.add_child(_section("GRAPHICS"))
    var qrow := HBoxContainer.new()
    qrow.add_theme_constant_override("separation", 6)
    box.add_child(qrow)
    qrow.add_child(_row_label("Quality"))
    for level in ["auto", "low", "medium", "high"]:
        var b := Button.new()
        b.text = level.capitalize()
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(92, 36)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            Game.set_quality(level))
        qrow.add_child(b)
        _quality_buttons[level] = b
    _gpu_label = Label.new()
    _gpu_label.add_theme_font_size_override("font_size", 13)
    _gpu_label.modulate = Color(1, 1, 1, 0.55)
    _gpu_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_gpu_label)

    var srow := HBoxContainer.new()
    srow.add_theme_constant_override("separation", 10)
    box.add_child(srow)
    srow.add_child(_row_label("Render scale"))
    _scale_slider = HSlider.new()
    _scale_slider.min_value = 50
    _scale_slider.max_value = 100
    _scale_slider.step = 5
    _scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scale_slider.custom_minimum_size = Vector2(200, 30)
    _scale_slider.value_changed.connect(func(v: float) -> void:
        if not _syncing:
            Game.set_render_scale(v / 100.0))
    srow.add_child(_scale_slider)
    _scale_label = Label.new()
    _scale_label.custom_minimum_size = Vector2(120, 0)
    _scale_label.add_theme_font_size_override("font_size", 14)
    srow.add_child(_scale_label)

    # ---- display
    box.add_child(_section("DISPLAY"))
    var drow := HBoxContainer.new()
    drow.add_theme_constant_override("separation", 24)
    box.add_child(drow)
    _vsync = CheckButton.new()
    _vsync.text = "VSync"
    _vsync.toggled.connect(func(_on: bool) -> void: _push_display())
    drow.add_child(_vsync)
    _fullscreen = CheckButton.new()
    _fullscreen.text = "Fullscreen"
    _fullscreen.toggled.connect(func(_on: bool) -> void: _push_display())
    drow.add_child(_fullscreen)
    var crow := HBoxContainer.new()
    crow.add_theme_constant_override("separation", 6)
    box.add_child(crow)
    crow.add_child(_row_label("FPS cap"))
    for cap in Game.FPS_CAPS:
        var b := Button.new()
        b.text = "Off" if cap == 0 else str(cap)
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(64, 34)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            Game.set_display(Game.vsync, cap, Game.fullscreen))
        crow.add_child(b)
        _cap_buttons[cap] = b

    # ---- controls + audio
    box.add_child(_section("CONTROLS + AUDIO"))
    var krow := HBoxContainer.new()
    krow.add_theme_constant_override("separation", 10)
    box.add_child(krow)
    krow.add_child(_row_label("Keys"))
    var keys_btn := Button.new()
    keys_btn.text = "Key bindings..."
    keys_btn.custom_minimum_size = Vector2(170, 36)
    keys_btn.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        open_controls())
    krow.add_child(keys_btn)
    var keys_note := Label.new()
    keys_note.text = "every action: move, jump, crouch, fire, weapons 1-7, pause..."
    keys_note.add_theme_font_size_override("font_size", 13)
    keys_note.modulate = Color(1, 1, 1, 0.55)
    krow.add_child(keys_note)
    _double_zoom = CheckButton.new()
    _double_zoom.text = "Sniper double zoom (8x): RMB cycles 4x, 8x, off"
    _double_zoom.toggled.connect(func(on: bool) -> void:
        if not _syncing:
            Game.set_sniper_double_zoom(on))
    box.add_child(_double_zoom)
    var mrow := HBoxContainer.new()
    mrow.add_theme_constant_override("separation", 10)
    box.add_child(mrow)
    mrow.add_child(_row_label("Sensitivity"))
    _sens_slider = HSlider.new()
    _sens_slider.min_value = 0.0
    _sens_slider.max_value = 100.0
    _sens_slider.step = 1.0
    _sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _sens_slider.custom_minimum_size = Vector2(200, 30)
    _sens_slider.value_changed.connect(func(v: float) -> void:
        if not _syncing:
            Game.set_sensitivity(lerpf(SENS_MIN, SENS_MAX, v / 100.0)))
    mrow.add_child(_sens_slider)
    _sens_label = Label.new()
    _sens_label.custom_minimum_size = Vector2(120, 0)
    _sens_label.add_theme_font_size_override("font_size", 14)
    mrow.add_child(_sens_label)

    var vrow := HBoxContainer.new()
    vrow.add_theme_constant_override("separation", 10)
    box.add_child(vrow)
    vrow.add_child(_row_label("Volume"))
    _volume_slider = HSlider.new()
    _volume_slider.min_value = 0.0
    _volume_slider.max_value = 100.0
    _volume_slider.step = 5.0
    _volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _volume_slider.custom_minimum_size = Vector2(200, 30)
    _volume_slider.value_changed.connect(func(v: float) -> void:
        if not _syncing:
            Game.set_volume(v / 100.0))
    vrow.add_child(_volume_slider)
    _volume_label = Label.new()
    _volume_label.custom_minimum_size = Vector2(120, 0)
    _volume_label.add_theme_font_size_override("font_size", 14)
    vrow.add_child(_volume_label)

    # ---- GPU pick (hybrid laptops): the engine can only switch adapters at launch
    if not Game.headless:
        var grow := HBoxContainer.new()
        grow.add_theme_constant_override("separation", 6)
        box.add_child(grow)
        grow.add_child(_row_label("GPU"))
        for i in 3:
            var b := Button.new()
            b.text = "#%d" % i
            b.toggle_mode = true
            b.button_pressed = Game.gpu_index == i
            b.custom_minimum_size = Vector2(56, 34)
            b.pressed.connect(func() -> void:
                Sfx.play_ui("ui_click")
                Game.set_gpu_index(i))
            grow.add_child(b)
        var note := Label.new()
        note.text = "restarts the game; try #1 if the game stutters on a laptop"
        note.add_theme_font_size_override("font_size", 13)
        note.modulate = Color(1, 1, 1, 0.55)
        grow.add_child(note)


# ---- controls sheet: every action with its key; click a cell, press a key ------------------

func _build_controls() -> void:
    _controls = VBoxContainer.new()
    _controls.add_theme_constant_override("separation", 10)
    _controls.visible = false
    add_child(_controls)
    var head := HBoxContainer.new()
    _controls.add_child(head)
    var title := Label.new()
    title.text = "CONTROLS"
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    var reset := Button.new()
    reset.text = "Reset to defaults"
    reset.custom_minimum_size = Vector2(150, 38)
    reset.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        _stop_listening()
        Game.reset_bindings())
    head.add_child(reset)
    var back := Button.new()
    back.text = "Back"
    back.custom_minimum_size = Vector2(110, 38)
    back.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        close_controls())
    head.add_child(back)
    _listen_hint = Label.new()
    _listen_hint.text = "Click a key, then press the key or mouse button you want. Esc cancels. Keys already in use swap."
    _listen_hint.add_theme_font_size_override("font_size", 13)
    _listen_hint.modulate = Color(1, 1, 1, 0.55)
    _listen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _controls.add_child(_listen_hint)
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 6)
    _controls.add_child(grid)
    for row in InputSetup.ORDER:
        var action: String = row[0]
        var l := Label.new()
        l.text = row[1]
        l.custom_minimum_size = Vector2(130, 0)
        l.add_theme_font_size_override("font_size", 15)
        grid.add_child(l)
        var b := Button.new()
        b.custom_minimum_size = Vector2(108, 32)
        b.add_theme_font_size_override("font_size", 15)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _start_listening(action))
        grid.add_child(b)
        _bind_buttons[action] = b
    if InputSetup.ORDER.size() % 2 == 1:   # keep the grid rectangular
        grid.add_child(Control.new())
        grid.add_child(Control.new())
    _refresh_bindings()
    Game.settings_changed.connect(_refresh_bindings)


func open_controls() -> void:
    _main.visible = false
    _controls.visible = true
    _refresh_bindings()


func close_controls() -> void:
    _stop_listening()
    _controls.visible = false
    _main.visible = true


func _refresh_bindings() -> void:
    for action in _bind_buttons:
        var b: Button = _bind_buttons[action]
        if action == _listening:
            b.text = "press a key..."
            b.add_theme_color_override("font_color", ACCENT)
        else:
            b.text = InputSetup.binding_text(action)
            b.remove_theme_color_override("font_color")


func _start_listening(action: String) -> void:
    _listening = action
    _refresh_bindings()
    set_process_input(true)


func _stop_listening() -> void:
    _listening = ""
    set_process_input(false)
    _refresh_bindings()


func _input(event: InputEvent) -> void:
    if _listening.is_empty() or not visible or not _controls.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        get_viewport().set_input_as_handled()
        if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
            _stop_listening()   # cancelled
            return
        var action := _listening
        _listening = ""
        Game.set_binding(action, event)
        _stop_listening()
    elif event is InputEventMouseButton and event.pressed:
        get_viewport().set_input_as_handled()
        var action := _listening
        _listening = ""
        Game.set_binding(action, event)
        _stop_listening()


func _section(text: String) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 13)
    l.modulate = Color(1, 1, 1, 0.45)
    return l


func _row_label(text: String) -> Label:
    var l := Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(130, 0)
    l.add_theme_font_size_override("font_size", 17)
    return l


func _push_display() -> void:
    if _syncing:
        return
    Game.set_display(_vsync.button_pressed, Game.fps_cap, _fullscreen.button_pressed)


## Reflect Game's current values (also after auto-detect / probe changes them).
func _sync() -> void:
    _syncing = true
    for level in _quality_buttons:
        var b: Button = _quality_buttons[level]
        b.button_pressed = (level == "auto" and Game.quality_auto) or (level == Game.quality and not Game.quality_auto)
    var adapter := RenderingServer.get_video_adapter_name()
    var mode := "Auto picked %s" % Quality.label(Game.quality) if Game.quality_auto else Quality.label(Game.quality)
    _gpu_label.text = "%s  |  GPU: %s" % [mode, adapter if not adapter.is_empty() else "n/a"]
    _scale_slider.value = roundf(Game.render_scale * 100.0)
    var upscaler := Quality.scale_mode_name(Quality.preset(Game.quality).scale_mode).to_upper()
    _scale_label.text = "%d%%%s" % [int(_scale_slider.value), "" if Game.render_scale >= 0.999 else "  " + upscaler]
    _vsync.button_pressed = Game.vsync
    _fullscreen.button_pressed = Game.fullscreen
    _double_zoom.button_pressed = Game.sniper_double_zoom
    for cap in _cap_buttons:
        _cap_buttons[cap].button_pressed = cap == Game.fps_cap
    var t := inverse_lerp(SENS_MIN, SENS_MAX, Game.mouse_sensitivity)
    _sens_slider.value = roundf(clampf(t, 0.0, 1.0) * 100.0)
    _sens_label.text = "%.2f" % (Game.mouse_sensitivity / 0.0022)
    _volume_slider.value = roundf(Game.volume * 100.0)
    _volume_label.text = "%d%%" % int(_volume_slider.value)
    _syncing = false
