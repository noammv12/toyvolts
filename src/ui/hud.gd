extends CanvasLayer
## In-match HUD: crosshair + hit marker, HP, ammo, reload/heat bars, weapon strip,
## sniper scope, damage flash, kill feed, match status, Tab scoreboard, respawn timer,
## match-end banner. Built in code; polls the player and match every frame.

var _player: Player
var _match: MatchController
var _overlay: Overlay
var _damage_flash: ColorRect
var _hp_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _fps_label: Label
var _feed_label: Label
var _status_label: Label
var _center_label: Label
var _scoreboard: PanelContainer
var _score_rows: VBoxContainer
var _slot_labels: Array[Label] = []
var _feed: Array = []   # [text, expires_at]
var _banner_until := 0.0


class Overlay extends Control:
    var player: Player
    var hit_marker := 0.0
    var hit_kill := false

    func _process(delta: float) -> void:
        hit_marker = maxf(0.0, hit_marker - delta)
        queue_redraw()

    func _draw() -> void:
        if player == null or not player.alive:
            return
        var c := size * 0.5
        var d := player.arsenal.data()
        var s := player.arsenal.current()
        if player.arsenal.aiming and d.scope_overlay:
            var r := minf(size.x, size.y) * 0.42
            var w := size.length()
            draw_arc(c, r + w * 0.5, 0.0, TAU, 96, Color.BLACK, w)
            draw_arc(c, r, 0.0, TAU, 96, Color(0.1, 0.1, 0.1), 4.0)
            draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color(0, 0, 0, 0.8), 1.5)
            draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color(0, 0, 0, 0.8), 1.5)
            draw_circle(c, 2.2, Color(1, 0.2, 0.2))
        else:
            var gap := 7.0 + d.spread_deg * 1.4 + (4.0 if not player.is_on_floor() else 0.0)
            var length := 9.0
            for pass_i in 2:
                var w := 4.0 if pass_i == 0 else 2.0
                var col := Color(0, 0, 0, 0.7) if pass_i == 0 else Color.WHITE
                draw_line(c + Vector2(gap, 0), c + Vector2(gap + length, 0), col, w)
                draw_line(c - Vector2(gap, 0), c - Vector2(gap + length, 0), col, w)
                draw_line(c + Vector2(0, gap), c + Vector2(0, gap + length), col, w)
                draw_line(c - Vector2(0, gap), c - Vector2(0, gap + length), col, w)
            draw_circle(c, 1.6, Color.WHITE)
        if hit_marker > 0.0:
            var a := clampf(hit_marker / 0.15, 0.0, 1.0)
            var col := Color(1, 0.25, 0.2, a) if hit_kill else Color(1, 1, 1, a)
            for sx in [-1.0, 1.0]:
                for sy in [-1.0, 1.0]:
                    var p0 := c + Vector2(sx * 13.0, sy * 13.0)
                    var p1 := c + Vector2(sx * 22.0, sy * 22.0)
                    draw_line(p0, p1, Color(0, 0, 0, a * 0.8), 5.0)
                    draw_line(p0, p1, col, 2.5)
        if s.is_reloading():
            _bar(c + Vector2(-40, 28), Vector2(80, 6), s.reload_progress(), Color(1, 0.85, 0.3))
        elif player.arsenal.swap_left > 0.0 and d.swap_time > 0.0:
            _bar(c + Vector2(-40, 28), Vector2(80, 6),
                1.0 - player.arsenal.swap_left / d.swap_time, Color(0.7, 0.85, 1.0))
        if d.heat_per_shot > 0.0:
            _bar(c + Vector2(-40, 38), Vector2(80, 6), s.heat,
                Color(1, 0.3, 0.2) if s.overheated else Color(1, 0.55, 0.2))

    func _bar(pos: Vector2, sz: Vector2, t: float, col: Color) -> void:
        draw_rect(Rect2(pos, sz), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(pos + Vector2.ONE, Vector2((sz.x - 2.0) * clampf(t, 0.0, 1.0), sz.y - 2.0)), col)


func _ready() -> void:
    _build()
    _player = get_tree().get_first_node_in_group("player") as Player
    _match = get_tree().get_first_node_in_group("match") as MatchController
    _overlay.player = _player
    if _player:
        _player.arsenal.hit_confirmed.connect(_on_hit)
        _player.damaged.connect(_on_damaged)
        _player.arsenal.weapon_changed.connect(func(slot: int, _d: WeaponData) -> void: _refresh_slots(slot))
        _refresh_slots(_player.arsenal.slot)
    if _match:
        _match.kill_feed.connect(_on_kill_feed)
        _match.match_ended.connect(_on_match_ended)


func _process(_delta: float) -> void:
    _fps_label.text = "%d fps" % Engine.get_frames_per_second()
    if _player == null:
        return
    var now := Time.get_ticks_msec() / 1000.0
    _hp_label.text = "HP %d" % int(ceil(_player.hp))
    var s := _player.arsenal.current()
    var d := s.data
    _weapon_label.text = d.display_name
    if not s.uses_ammo():
        _ammo_label.text = "--"
    elif s.overheated:
        _ammo_label.text = "HOT"
    elif d.reserve == 0:
        _ammo_label.text = "%d" % s.clip
    else:
        _ammo_label.text = "%d / %d" % [s.clip, s.reserve]
    _ammo_label.modulate = Color(1, 0.4, 0.3) if (s.uses_ammo() and s.clip == 0) else Color.WHITE

    _feed = _feed.filter(func(e: Array) -> bool: return e[1] > now)
    var lines := PackedStringArray()
    for e in _feed:
        lines.append(e[0])
    _feed_label.text = "\n".join(lines)

    if _match:
        _status_label.text = _match.status_line(_player)

    # centre message: banner > respawn timer > mouse hint
    if _banner_until > now and _match:
        _center_label.text = _match.winner_text
        _center_label.modulate = Color(1, 0.85, 0.3)
    elif not _player.alive:
        var left := maxf(0.0, (_player.respawn_at_msec - Time.get_ticks_msec()) / 1000.0)
        _center_label.text = "Respawn in %d" % int(ceil(left))
        _center_label.modulate = Color.WHITE
    elif not Game.mouse_captured and not Game.headless and not Game.has_arg("screenshot"):
        _center_label.text = "Click to play   |   M = menu"
        _center_label.modulate = Color(1, 1, 1, 0.8)
    else:
        _center_label.text = ""

    var show_scores := Input.is_action_pressed("scoreboard") or _banner_until > now
    _scoreboard.visible = show_scores and _match != null and _match.mode != "practice"
    if _scoreboard.visible:
        _refresh_scoreboard()


func _build() -> void:
    _damage_flash = ColorRect.new()
    _damage_flash.color = Color(1, 0.1, 0.05, 0.0)
    _damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_damage_flash)

    _overlay = Overlay.new()
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_overlay)

    _hp_label = _label("HP 100", Control.PRESET_BOTTOM_LEFT, 34)
    _ammo_label = _label("30 / 120", Control.PRESET_BOTTOM_RIGHT, 34)
    _ammo_label.offset_top -= 30
    _ammo_label.offset_bottom -= 30
    _weapon_label = _label("Rifle", Control.PRESET_BOTTOM_RIGHT, 18)
    _fps_label = _label("", Control.PRESET_TOP_RIGHT, 16)
    _feed_label = _label("", Control.PRESET_TOP_RIGHT, 18)
    _feed_label.offset_top += 30
    _feed_label.offset_bottom += 30
    _feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _status_label = _label("", Control.PRESET_CENTER_TOP, 18)
    _center_label = _label("", Control.PRESET_CENTER, 40)
    _center_label.offset_top += 110
    _center_label.offset_bottom += 110
    _center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label("Tab scoreboard   Esc mouse", Control.PRESET_TOP_LEFT, 15)

    var strip := HBoxContainer.new()
    strip.add_theme_constant_override("separation", 14)
    strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
    _grow_inward(strip, Control.PRESET_CENTER_BOTTOM)
    add_child(strip)
    for d in WeaponDB.all():
        var l := Label.new()
        l.text = "%d %s" % [d.slot, d.display_name.to_upper()]
        _style(l, 15)
        strip.add_child(l)
        _slot_labels.append(l)

    _scoreboard = PanelContainer.new()
    _scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
    _scoreboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _scoreboard.grow_vertical = Control.GROW_DIRECTION_BOTH
    _scoreboard.offset_top -= 160
    _scoreboard.offset_bottom -= 160
    _scoreboard.visible = false
    add_child(_scoreboard)
    var margin := MarginContainer.new()
    for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 16)
    _scoreboard.add_child(margin)
    _score_rows = VBoxContainer.new()
    _score_rows.add_theme_constant_override("separation", 4)
    margin.add_child(_score_rows)


func _refresh_scoreboard() -> void:
    for child in _score_rows.get_children():
        child.queue_free()
    _score_row(["TOY", "K", "D"], Color(1, 1, 1, 0.6), true)
    for c in _match.ranking():
        var col := Color.WHITE
        if _match.mode == "tdm":
            col = Color(1, 0.55, 0.4) if c.team == 1 else Color(0.55, 0.7, 1.0)
        if c == _player:
            col = Color(1, 0.9, 0.4)
        _score_row([c.display_name, str(c.kills), str(c.deaths)], col, false)


func _score_row(cells: Array, color: Color, header: bool) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var widths := [200, 50, 50]
    for i in cells.size():
        var l := Label.new()
        l.text = cells[i]
        l.custom_minimum_size = Vector2(widths[i], 0)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
        l.modulate = color
        _style(l, 16 if header else 20)
        row.add_child(l)
    _score_rows.add_child(row)


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
        Control.PRESET_CENTER:
            c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _style(l: Label, font_size: int) -> void:
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 5)


func _refresh_slots(slot: int) -> void:
    for i in _slot_labels.size():
        _slot_labels[i].modulate = Color.WHITE if i + 1 == slot else Color(1, 1, 1, 0.45)


func _on_hit(killed: bool, _headshot: bool) -> void:
    _overlay.hit_marker = 0.15
    _overlay.hit_kill = killed


func _on_damaged(amount: float, _source: Character, _headshot: bool) -> void:
    _damage_flash.color.a = clampf(amount / 60.0, 0.15, 0.5)
    var tw := _damage_flash.create_tween()
    tw.tween_property(_damage_flash, "color:a", 0.0, 0.35)


func _on_kill_feed(text: String) -> void:
    _feed.append([text, Time.get_ticks_msec() / 1000.0 + 5.0])
    if _feed.size() > 5:
        _feed.pop_front()


func _on_match_ended(_text: String) -> void:
    _banner_until = Time.get_ticks_msec() / 1000.0 + 7.0
