extends Control
## Title screen: pick a mode. Auto-starts when launched with --mode=ffa|tdm|practice.

const TOON_ORANGE := Color(0.95, 0.42, 0.2)


func _ready() -> void:
    Game.set_mouse_captured(false)
    if Game.has_arg("mode"):
        Game.start_match(Game.mode, Game.bot_count)
        return
    _build()


func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.12, 0.14, 0.2)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 14)
    add_child(box)

    var title := Label.new()
    title.text = "TOYVOLTS"
    title.add_theme_font_size_override("font_size", 72)
    title.add_theme_color_override("font_color", TOON_ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var sub := Label.new()
    sub.text = "seven weapons, one toy box"
    sub.add_theme_font_size_override("font_size", 20)
    sub.modulate = Color(1, 1, 1, 0.7)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(sub)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 20)
    box.add_child(spacer)

    _button(box, "Free For All  -  5 bots", func() -> void: Game.start_match("ffa", 5))
    _button(box, "Team Deathmatch  -  3 vs 3", func() -> void: Game.start_match("tdm", 5))
    _button(box, "Practice  -  target dummies", func() -> void: Game.start_match("practice", 0))
    _button(box, "Quit", func() -> void: get_tree().quit())

    var hint := Label.new()
    hint.text = "WASD move   Space jump (melee: double jump)   LMB fire   RMB aim / heavy swing\nR reload   1-7 / mouse wheel / Q switch weapon   Tab scoreboard   Esc free mouse, then M for menu"
    hint.add_theme_font_size_override("font_size", 15)
    hint.modulate = Color(1, 1, 1, 0.55)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 30)
    hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
    hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    add_child(hint)


func _button(parent: Control, text: String, on_pressed: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(360, 48)
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(on_pressed)
    parent.add_child(b)
