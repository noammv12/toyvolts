extends Control
## Title screen: mode, bot count and figure choice with a live 3D preview.
## Auto-starts when launched with --mode=ffa|tdm|elim|practice.

const ACCENT := Color(0.95, 0.42, 0.2)
const MODES := [
    ["party", "Birthday Party", "Lalu's room: blow out the candles, pop the balloons, break the pinata, open the gifts. Guests only cheer."],
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
var _map_buttons := {}
var _map_blurb: Label
var _blurb: Label
var _bots_label: Label
var _preview_figure: Figure
var _preview_root: Node3D
var _skin_name: Label
var _skin_blurb: Label
var _settings: SettingsPanel
var _settings_dim: ColorRect
var _lobby: LobbyPanel
var _hint: Label


## The controls hint follows the bindings ("E bazooka" after a rebind).
func _refresh_hint() -> void:
    if _hint == null:
        return
    var k := func(action: String) -> String: return InputSetup.binding_text(action)
    var move := "%s%s%s%s" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")]
    var weapons := PackedStringArray()
    for i in range(1, 8):
        weapons.append(k.call("weapon_%d" % i))
    _hint.text = "%s move   %s jump (melee: double jump)   %s crouch   %s fire   %s aim / heavy swing   %s reload\n%s weapons 1-7   %s / %s next / previous   %s last weapon   %s scoreboard   %s pause / settings" % [
        move, k.call("jump"), k.call("crouch"), k.call("fire"), k.call("alt_fire"), k.call("reload"),
        " ".join(weapons), k.call("weapon_next"), k.call("weapon_prev"), k.call("weapon_last"), k.call("scoreboard"), k.call("toggle_mouse")]


func open_settings() -> void:
    _settings_dim.visible = true
    _settings.visible = true


func open_lobby() -> void:
    _settings_dim.visible = true
    _lobby.visible = true
    _lobby.refresh()


func _ready() -> void:
    Game.set_mouse_captured(false)
    if Game.has_arg("server") or Game.has_arg("host"):
        # the network starts one frame after Game._ready: hand the kick-off to the lobby logic
        _autostart_hosted.call_deferred()
        return
    if Game.has_arg("mode") and not Game.has_arg("join"):
        Game.start_match(Game.mode, Game.bot_count)
        return
    _mode = Game.mode if Game.mode != "practice" else "ffa"
    _bots = Game.bot_count
    _build()
    if Game.has_arg("join"):
        open_lobby()


func _autostart_hosted() -> void:
    if Net.is_server_role():
        Net.start_match()
    else:
        push_error("[net] could not host: " + Net.last_error)
        get_tree().quit(1)


func _build() -> void:
    if Game.headless and Game.has_arg("join"):
        _lobby = LobbyPanel.new()   # no UI needed: the panel only reacts to Net signals
        _settings_dim = ColorRect.new()
        add_child(_settings_dim)
        add_child(_lobby)
        return
    var bg := ColorRect.new()
    bg.color = Color(0.11, 0.13, 0.18)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    if not Game.headless:
        add_child(_confetti())

    var root := HBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 40)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 36)
    add_child(margin)
    margin.add_child(root)

    # ---- left column: title + modes
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation", 7)
    root.add_child(left)

    var title := Label.new()
    title.text = "TOYVOLTS"
    title.add_theme_font_size_override("font_size", 62)
    title.add_theme_color_override("font_color", ACCENT)
    left.add_child(title)
    var sub := Label.new()
    sub.text = "seven weapons, one toy box"
    sub.add_theme_font_size_override("font_size", 17)
    sub.modulate = Color(1, 1, 1, 0.7)
    left.add_child(sub)
    left.add_child(_spacer(8))

    # ---- the birthday button: first thing on the screen, cake coloured
    var party_btn := Button.new()
    party_btn.text = PartyText.MENU_BUTTON
    party_btn.custom_minimum_size = Vector2(330, 62)
    party_btn.add_theme_font_size_override("font_size", 30)
    party_btn.add_theme_color_override("font_color", PartyText.GOLD)
    party_btn.add_theme_color_override("font_hover_color", PartyText.CREAM)
    party_btn.add_theme_color_override("font_pressed_color", PartyText.CREAM)
    party_btn.add_theme_color_override("font_outline_color", Color(0.45, 0.08, 0.25))
    party_btn.add_theme_constant_override("outline_size", 4)
    var cake := StyleBoxFlat.new()
    cake.bg_color = PartyText.HOT_PINK
    cake.border_color = PartyText.TEAL
    cake.set_border_width_all(3)
    cake.set_corner_radius_all(14)
    cake.set_content_margin_all(6)
    party_btn.add_theme_stylebox_override("normal", cake)
    var cake_hover := cake.duplicate() as StyleBoxFlat
    cake_hover.bg_color = PartyText.PINK
    cake_hover.border_color = PartyText.GOLD
    party_btn.add_theme_stylebox_override("hover", cake_hover)
    party_btn.add_theme_stylebox_override("pressed", cake_hover)
    party_btn.add_theme_stylebox_override("focus", cake_hover)
    party_btn.pressed.connect(func() -> void:
        Sfx.play_ui("party_horn", -6.0)
        Game.start_party())
    left.add_child(party_btn)
    var party_sub := Label.new()
    party_sub.text = PartyText.MENU_SUB
    party_sub.add_theme_font_size_override("font_size", 14)
    party_sub.modulate = PartyText.PINK
    left.add_child(party_sub)
    left.add_child(_spacer(6))

    var mode_title := Label.new()
    mode_title.text = "MODE"
    mode_title.add_theme_font_size_override("font_size", 14)
    mode_title.modulate = Color(1, 1, 1, 0.5)
    left.add_child(mode_title)
    for m in MODES:
        var b := Button.new()
        b.text = m[1]
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(330, 33)
        b.add_theme_font_size_override("font_size", 18)
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

    left.add_child(_spacer(6))
    var map_title := Label.new()
    map_title.text = "MAP"
    map_title.add_theme_font_size_override("font_size", 14)
    map_title.modulate = Color(1, 1, 1, 0.5)
    left.add_child(map_title)
    var map_row := HBoxContainer.new()
    map_row.add_theme_constant_override("separation", 8)
    left.add_child(map_row)
    for key in Game.MAPS:
        var b := Button.new()
        b.text = Game.MAPS[key].name
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(104, 40)
        b.add_theme_font_size_override("font_size", 16)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _set_map(key))
        map_row.add_child(b)
        _map_buttons[key] = b
    _map_blurb = Label.new()
    _map_blurb.add_theme_font_size_override("font_size", 14)
    _map_blurb.modulate = Color(1, 1, 1, 0.6)
    _map_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _map_blurb.custom_minimum_size = Vector2(330, 22)
    left.add_child(_map_blurb)

    left.add_child(_spacer(6))
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
    start.custom_minimum_size = Vector2(330, 50)
    start.add_theme_font_size_override("font_size", 25)
    start.add_theme_color_override("font_color", ACCENT)
    start.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        Game.save_settings()
        Game.start_match(_mode, _bots if _mode != "practice" else 0))
    left.add_child(start)
    var online := Button.new()
    online.text = "Online  (host / join)"
    online.custom_minimum_size = Vector2(330, 40)
    online.add_theme_font_size_override("font_size", 19)
    online.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        open_lobby())
    left.add_child(online)
    var settings_btn := Button.new()
    settings_btn.text = "Settings"
    settings_btn.custom_minimum_size = Vector2(330, 34)
    settings_btn.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        open_settings())
    left.add_child(settings_btn)
    var quit := Button.new()
    quit.text = "Quit"
    quit.custom_minimum_size = Vector2(330, 34)
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
    _lobby = LobbyPanel.new()
    _lobby.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
    _lobby.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _lobby.grow_vertical = Control.GROW_DIRECTION_BOTH
    _lobby.visible = false
    _lobby.closed.connect(func() -> void:
        _lobby.visible = false
        _settings_dim.visible = false)
    add_child(_lobby)

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

    _hint = Label.new()
    _hint.add_theme_font_size_override("font_size", 14)
    _hint.modulate = Color(1, 1, 1, 0.5)
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    right.add_child(_spacer(18))
    right.add_child(_hint)
    _refresh_hint()
    Game.settings_changed.connect(_refresh_hint)

    _set_mode(_mode)
    _set_bots(_bots)
    _set_difficulty(Game.bot_difficulty)
    _set_map(Game.map)
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
    if mode == "party" and Game.map != "lalu_party" and not _map_buttons.is_empty():
        _set_map("lalu_party")   # the party only happens in Lalu's room


func _set_bots(n: int) -> void:
    _bots = clampi(n, 1, 7)
    _bots_label.text = str(_bots)


func _set_map(key: String) -> void:
    if not Game.MAPS.has(key):
        key = "toy_room"
    Game.map = key
    for k in _map_buttons:
        _map_buttons[k].button_pressed = k == key
    _map_blurb.text = Game.MAPS[key].blurb
    if key == "lalu_party" and _mode != "party":
        _set_mode("party")       # picking the room picks the party (any mode can still be chosen after)


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
        _preview_figure.add_hat(PartyText.HOT_PINK)


## Paper confetti drifting down over the whole title screen.
func _confetti() -> GPUParticles2D:
    var p := GPUParticles2D.new()
    p.amount = 110
    p.lifetime = 11.0
    p.preprocess = 8.0
    p.position = Vector2(800, -30)
    var img := Image.create(10, 7, false, Image.FORMAT_RGBA8)
    img.fill(Color.WHITE)
    p.texture = ImageTexture.create_from_image(img)
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = Vector3(900, 4, 1)
    pm.direction = Vector3(0, 1, 0)
    pm.spread = 25.0
    pm.initial_velocity_min = 25.0
    pm.initial_velocity_max = 60.0
    pm.gravity = Vector3(0, 28, 0)
    pm.damping_min = 4.0
    pm.damping_max = 9.0
    pm.angle_min = 0.0
    pm.angle_max = 360.0
    pm.angular_velocity_min = -160.0
    pm.angular_velocity_max = 160.0
    pm.scale_min = 0.8
    pm.scale_max = 1.6
    var g := Gradient.new()
    g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
    var colors := PackedColorArray()
    var offsets := PackedFloat32Array()
    for i in PartyText.PALETTE.size():
        colors.append(PartyText.PALETTE[i])
        offsets.append(float(i) / PartyText.PALETTE.size())
    g.colors = colors
    g.offsets = offsets
    var ramp := GradientTexture1D.new()
    ramp.gradient = g
    pm.color_initial_ramp = ramp
    p.process_material = pm
    p.emitting = true
    return p


func _spacer(h: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c
