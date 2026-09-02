extends CanvasLayer
## In-match HUD: crosshair, HP, weapon strip, hint, fps. Built in code.

var _hp_label: Label
var _weapon_label: Label
var _fps_label: Label
var _slot_labels: Array[Label] = []
var _player: Player


class Crosshair extends Control:
    func _draw() -> void:
        var c := size * 0.5
        var gap := 7.0
        var length := 9.0
        for pass_i in 2:
            var w := 4.0 if pass_i == 0 else 2.0
            var col := Color(0, 0, 0, 0.7) if pass_i == 0 else Color.WHITE
            draw_line(c + Vector2(gap, 0), c + Vector2(gap + length, 0), col, w)
            draw_line(c - Vector2(gap, 0), c - Vector2(gap + length, 0), col, w)
            draw_line(c + Vector2(0, gap), c + Vector2(0, gap + length), col, w)
            draw_line(c - Vector2(0, gap), c - Vector2(0, gap + length), col, w)
        draw_circle(c, 1.6, Color.WHITE)


func _ready() -> void:
    _build()
    _player = get_tree().get_first_node_in_group("player") as Player
    if _player:
        _player.health_changed.connect(_on_health)
        _player.weapon_changed.connect(_on_weapon)
        _on_health(_player.hp, _player.max_hp)
        _on_weapon(_player.weapon_slot, Player.WEAPON_NAMES[_player.weapon_slot - 1])


func _process(_delta: float) -> void:
    _fps_label.text = "%d fps" % Engine.get_frames_per_second()


func _build() -> void:
    var cross := Crosshair.new()
    cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(cross)

    _hp_label = _label("HP 100", Control.PRESET_BOTTOM_LEFT, 30)
    _weapon_label = _label("Rifle", Control.PRESET_BOTTOM_RIGHT, 30)
    _fps_label = _label("", Control.PRESET_TOP_RIGHT, 16)
    _label("WASD move   Space jump (melee: double)   1-7 / wheel / Q weapons   Esc mouse",
        Control.PRESET_TOP_LEFT, 16)

    var strip := HBoxContainer.new()
    strip.add_theme_constant_override("separation", 14)
    strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
    _grow_inward(strip, Control.PRESET_CENTER_BOTTOM)
    add_child(strip)
    for i in Player.WEAPON_NAMES.size():
        var l := Label.new()
        l.text = "%d %s" % [i + 1, Player.WEAPON_NAMES[i].to_upper()]
        _style(l, 15)
        strip.add_child(l)
        _slot_labels.append(l)


func _label(text: String, preset: Control.LayoutPreset, font_size: int) -> Label:
    var l := Label.new()
    l.text = text
    _style(l, font_size)
    l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 24)
    _grow_inward(l, preset)
    add_child(l)
    return l


## Corner-anchored controls must grow toward the screen centre when their text changes.
func _grow_inward(c: Control, preset: Control.LayoutPreset) -> void:
    match preset:
        Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT:
            c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
        Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER_TOP, Control.PRESET_CENTER:
            c.grow_horizontal = Control.GROW_DIRECTION_BOTH
    match preset:
        Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM:
            c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _style(l: Label, font_size: int) -> void:
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 5)


func _on_health(hp: int, max_hp: int) -> void:
    _hp_label.text = "HP %d / %d" % [hp, max_hp]


func _on_weapon(slot: int, weapon_name: String) -> void:
    _weapon_label.text = weapon_name
    for i in _slot_labels.size():
        _slot_labels[i].modulate = Color.WHITE if i + 1 == slot else Color(1, 1, 1, 0.45)
