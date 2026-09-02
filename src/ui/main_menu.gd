extends Control
## Title screen: mode, bot count and figure choice with a live 3D preview.
## Auto-starts when launched with --mode=ffa|tdm|elim|practice.

const ACCENT := Color(0.95, 0.42, 0.2)
const MODES := [
    ["ffa", "Free For All", "Every toy for itself. First to 20."],
    ["tdm", "Team Deathmatch", "Red vs Blue. First team to 30."],
    ["elim", "Elimination", "No respawns. Last toy standing wins the round; 5 rounds."],
    ["ctb", "Capture the Battery", "Red vs Blue. Grab a battery, run it to your charging pad. First to 5."],
    ["practice", "Practice", "Target dummies, no pressure."],
]

var _mode := "ffa"
var _bots := 5
var _mode_buttons := {}
var _skin_buttons := {}
var _difficulty_buttons := {}
var _blurb: Label
var _bots_label: Label
var _preview_figure: Figure
var _preview_root: Node3D
var _skin_name: Label
var _skin_blurb: Label
var _settings: SettingsPanel
var _settings_dim: ColorRect


func open_settings() -> void:
    _settings_dim.visible = true
    _settings.visible = true


func _ready() -> void:
    Game.set_mouse_captured(false)
    if Game.has_arg("mode"):
        Game.start_match(Game.mode, Game.bot_count)
        return
    _mode = Game.mode if Game.mode != "practice" else "ffa"
    _bots = Game.bot_count
    _build()


func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.11, 0.13, 0.18)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root := HBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 40)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 48)
    add_child(margin)
    margin.add_child(root)

    # ---- left column: title + modes
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation", 10)
    root.add_child(left)

    var title := Label.new()
    title.text = "TOYVOLTS"
    title.add_theme_font_size_override("font_size", 74)
    title.add_theme_color_override("font_color", ACCENT)
    left.add_child(title)
    var sub := Label.new()
    sub.text = "seven weapons, one toy box"
    sub.add_theme_font_size_override("font_size", 20)
    sub.modulate = Color(1, 1, 1, 0.7)
    left.add_child(sub)
    left.add_child(_spacer(18))

    var mode_title := Label.new()
    mode_title.text = "MODE"
    mode_title.add_theme_font_size_override("font_size", 14)
    mode_title.modulate = Color(1, 1, 1, 0.5)
    left.add_child(mode_title)
    for m in MODES:
        var b := Button.new()
        b.text = m[1]
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(330, 44)
        b.add_theme_font_size_override("font_size", 21)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _set_mode(m[0]))
        left.add_child(b)
        _mode_buttons[m[0]] = b
    _blurb = Label.new()
    _blurb.add_theme_font_size_override("font_size", 15)
    _blurb.modulate = Color(1, 1, 1, 0.65)
    _blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _blurb.custom_minimum_size = Vector2(330, 40)
    left.add_child(_blurb)

    left.add_child(_spacer(10))
    var bots_row := HBoxContainer.new()
    bots_row.add_theme_constant_override("separation", 10)
    left.add_child(bots_row)
    var bots_title := Label.new()
    bots_title.text = "BOTS"
    bots_title.add_theme_font_size_override("font_size", 14)
    bots_title.modulate = Color(1, 1, 1, 0.5)
    bots_row.add_child(bots_title)
    var minus := Button.new()
    minus.text = "-"
    minus.custom_minimum_size = Vector2(40, 36)
    minus.pressed.connect(func() -> void: _set_bots(_bots - 1))
    bots_row.add_child(minus)
    _bots_label = Label.new()
    _bots_label.add_theme_font_size_override("font_size", 22)
    _bots_label.custom_minimum_size = Vector2(40, 0)
    _bots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bots_row.add_child(_bots_label)
    var plus := Button.new()
    plus.text = "+"
    plus.custom_minimum_size = Vector2(40, 36)
    plus.pressed.connect(func() -> void: _set_bots(_bots + 1))
    bots_row.add_child(plus)
    bots_row.add_child(_spacer_w(14))
    for level in ["easy", "normal", "hard"]:
        var b := Button.new()
        b.text = level.capitalize()
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(74, 36)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _set_difficulty(level))
        bots_row.add_child(b)
        _difficulty_buttons[level] = b

    left.add_child(_spacer(16))
    var start := Button.new()
    start.text = "PLAY"
    start.custom_minimum_size = Vector2(330, 56)
    start.add_theme_font_size_override("font_size", 26)
    start.add_theme_color_override("font_color", ACCENT)
    start.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        Game.save_settings()
        Game.start_match(_mode, _bots if _mode != "practice" else 0))
    left.add_child(start)
    var settings_btn := Button.new()
    settings_btn.text = "Settings"
    settings_btn.custom_minimum_size = Vector2(330, 40)
    settings_btn.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        open_settings())
    left.add_child(settings_btn)
    var quit := Button.new()
    quit.text = "Quit"
    quit.custom_minimum_size = Vector2(330, 40)
    quit.pressed.connect(func() -> void: get_tree().quit())
    left.add_child(quit)

    _settings_dim = ColorRect.new()
    _settings_dim.color = Color(0.03, 0.04, 0.06, 0.6)
    _settings_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _settings_dim.visible = false
    add_child(_settings_dim)
    _settings = SettingsPanel.new()
    _settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
    _settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _settings.grow_vertical = Control.GROW_DIRECTION_BOTH
    _settings.visible = false
    _settings.closed.connect(func() -> void:
        _settings.visible = false
        _settings_dim.visible = false)
    add_child(_settings)

    # ---- right column: figure select + preview
    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 10)
    root.add_child(right)
    var fig_title := Label.new()
    fig_title.text = "YOUR TOY"
    fig_title.add_theme_font_size_override("font_size", 14)
    fig_title.modulate = Color(1, 1, 1, 0.5)
    right.add_child(fig_title)

    var preview := _build_preview()
    right.add_child(preview)

    _skin_name = Label.new()
    _skin_name.add_theme_font_size_override("font_size", 28)
    right.add_child(_skin_name)
    _skin_blurb = Label.new()
    _skin_blurb.add_theme_font_size_override("font_size", 15)
    _skin_blurb.modulate = Color(1, 1, 1, 0.65)
    right.add_child(_skin_blurb)

    var skins_row := HBoxContainer.new()
    skins_row.add_theme_constant_override("separation", 8)
    right.add_child(skins_row)
    for s in Skins.ALL:
        var b := Button.new()
        b.text = s.name
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(110, 40)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _set_skin(s.id))
        skins_row.add_child(b)
        _skin_buttons[s.id] = b

    var hint := Label.new()
    hint.text = "WASD move   Space jump (melee: double jump)   LMB fire   RMB aim / heavy swing   R reload\n1-7 / wheel / Q weapons   Tab scoreboard   Esc pause / settings"
    hint.add_theme_font_size_override("font_size", 14)
    hint.modulate = Color(1, 1, 1, 0.5)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
    hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
    hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    add_child(hint)

    _set_mode(_mode)
    _set_bots(_bots)
    _set_difficulty(Game.bot_difficulty)
    _set_skin(Game.skin)


func _build_preview() -> Control:
    var container := SubViewportContainer.new()
    container.stretch = true
    container.custom_minimum_size = Vector2(420, 420)
    container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    var vp := SubViewport.new()
    vp.size = Vector2i(420, 420)
    vp.transparent_bg = true
    vp.msaa_3d = Quality.preset(Game.quality).msaa if Quality.is_level(Game.quality) else Viewport.MSAA_4X
    container.add_child(vp)
    _preview_root = Node3D.new()
    vp.add_child(_preview_root)
    var cam := Camera3D.new()
    cam.position = Vector3(0.0, 1.05, 3.1)
    cam.fov = 40.0
    _preview_root.add_child(cam)
    cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-40, 35, 0)
    sun.light_energy = 2.2
    _preview_root.add_child(sun)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-2, 2, 2)
    fill.light_energy = 1.2
    fill.omni_range = 8
    _preview_root.add_child(fill)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.11, 0.13, 0.18, 0)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.6, 0.65, 0.8)
    e.ambient_light_energy = 0.8
    env.environment = e
    _preview_root.add_child(env)
    var disc := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.9
    cyl.bottom_radius = 1.0
    cyl.height = 0.12
    disc.mesh = cyl
    disc.position = Vector3(0, -0.06, 0)
    var dm := StandardMaterial3D.new()
    dm.albedo_color = Color(0.2, 0.23, 0.3)
    disc.material_override = dm
    _preview_root.add_child(disc)
    _preview_figure = Figure.new()
    _preview_figure.rotation.y = PI   # face the preview camera
    _preview_root.add_child(_preview_figure)
    return container


func _process(delta: float) -> void:
    if _preview_figure != null and _preview_figure.ready_ok:
        _preview_figure.rotation.y += delta * 0.6
        _preview_figure.set_locomotion(Vector2.ZERO, true, delta)


func _set_mode(mode: String) -> void:
    _mode = mode
    for key in _mode_buttons:
        _mode_buttons[key].button_pressed = key == mode
    for m in MODES:
        if m[0] == mode:
            _blurb.text = m[2]


func _set_bots(n: int) -> void:
    _bots = clampi(n, 1, 7)
    _bots_label.text = str(_bots)


func _set_difficulty(level: String) -> void:
    if not Bot.SKILL_RANGES.has(level):
        level = "normal"
    Game.bot_difficulty = level
    for key in _difficulty_buttons:
        _difficulty_buttons[key].button_pressed = key == level


func _spacer_w(w: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(w, 0)
    return c


func _set_skin(id: String) -> void:
    Game.skin = id
    for key in _skin_buttons:
        _skin_buttons[key].button_pressed = key == id
    _skin_name.text = Skins.display_name(id)
    for s in Skins.ALL:
        if s.id == id:
            _skin_blurb.text = s.blurb
    if _preview_figure:
        _preview_figure.setup(Skins.path(id))
        _preview_figure.set_aiming(false)


func _spacer(h: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c
