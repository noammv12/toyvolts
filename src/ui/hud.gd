extends CanvasLayer
## In-match HUD in the Microvolts layout: HP bar bottom-left, weapon strip with icons and
## ammo bottom-centre, big ammo + reload/heat bottom-right, radar top-left, match status
## top-centre, kill feed top-right, per-weapon crosshairs, hit markers, damage flash and
## direction, kill popups, sniper scope, respawn timer, match-end banner, Tab scoreboard.

const SLOT_W := 72.0
const SLOT_H := 52.0

var _player: Player
var _match: MatchController
var _overlay: Overlay
var _radar: Radar
var _damage_flash: ColorRect
var _hp_bar: HpBar
var _ammo_label: Label
var _weapon_label: Label
var _fps_label: Label
var _feed_label: Label
var _status_label: Label
var _center_label: Label
var _popup_label: Label
var _scoreboard: PanelContainer
var _score_rows: VBoxContainer
var _slots: Array[SlotWidget] = []
var _feed: Array = []   # [text, expires_at]
var _banner_until := 0.0
var _popup_until := 0.0
var _hurt_dir := Vector2.ZERO
var _hurt_until := 0.0


# ---- widgets -------------------------------------------------------------------

class Overlay extends Control:
    var player: Player
    var hud: CanvasLayer
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
        var now := Time.get_ticks_msec() / 1000.0
        if player.arsenal.aiming and d.scope_overlay:
            _draw_scope(c)
        else:
            _draw_crosshair(c, d, s)
        if hit_marker > 0.0:
            var a := clampf(hit_marker / 0.15, 0.0, 1.0)
            var col := Color(1, 0.25, 0.2, a) if hit_kill else Color(1, 1, 1, a)
            for sx in [-1.0, 1.0]:
                for sy in [-1.0, 1.0]:
                    var p0 := c + Vector2(sx * 13.0, sy * 13.0)
                    var p1 := c + Vector2(sx * 22.0, sy * 22.0)
                    draw_line(p0, p1, Color(0, 0, 0, a * 0.8), 5.0)
                    draw_line(p0, p1, col, 2.5)
        # damage direction arc
        if hud._hurt_until > now:
            var a: float = clampf((hud._hurt_until - now) / 0.8, 0.0, 1.0)
            var ang: float = hud._hurt_dir.angle()
            draw_arc(c, 70.0, ang - 0.45, ang + 0.45, 16, Color(1, 0.2, 0.15, a * 0.9), 6.0)
        if s.is_reloading():
            _bar(c + Vector2(-40, 30), Vector2(80, 6), s.reload_progress(), Color(1, 0.85, 0.3))
        elif player.arsenal.swap_left > 0.0 and d.swap_time > 0.0:
            _bar(c + Vector2(-40, 30), Vector2(80, 6),
                1.0 - player.arsenal.swap_left / d.swap_time, Color(0.7, 0.85, 1.0))
        if d.heat_per_shot > 0.0:
            _bar(c + Vector2(-40, 40), Vector2(80, 6), s.heat,
                Color(1, 0.3, 0.2) if s.overheated else Color(1, 0.55, 0.2))

    func _draw_crosshair(c: Vector2, d: WeaponData, s: WeaponState) -> void:
        var air := 4.0 if not player.is_on_floor() else 0.0
        var white := Color.WHITE
        var shadow := Color(0, 0, 0, 0.7)
        match d.slot:
            1:
                draw_circle(c, 5.0, shadow)
                draw_circle(c, 3.0, white)
            3:
                var r := 16.0 + air
                draw_arc(c, r, 0.0, TAU, 40, shadow, 5.0)
                draw_arc(c, r, 0.0, TAU, 40, white, 2.0)
                draw_circle(c, 1.6, white)
            6:
                draw_arc(c, 12.0 + air, 0.0, TAU, 32, shadow, 5.0)
                draw_arc(c, 12.0 + air, 0.0, TAU, 32, white, 2.0)
                draw_circle(c, 2.2, white)
            7:
                var pts := PackedVector2Array([c + Vector2(-12, 8), c + Vector2(0, -6), c + Vector2(12, 8)])
                draw_polyline(pts, shadow, 5.0)
                draw_polyline(pts, white, 2.0)
                draw_circle(c + Vector2(0, 12), 1.8, white)
            4:
                draw_circle(c, 4.0, shadow)
                draw_circle(c, 2.2, white)
            _:
                var gap := 7.0 + d.spread_deg * 1.4 + air + (s.heat * 8.0 if d.heat_per_shot > 0.0 else 0.0)
                var length := 9.0
                for pass_i in 2:
                    var w := 4.0 if pass_i == 0 else 2.0
                    var col := shadow if pass_i == 0 else white
                    draw_line(c + Vector2(gap, 0), c + Vector2(gap + length, 0), col, w)
                    draw_line(c - Vector2(gap, 0), c - Vector2(gap + length, 0), col, w)
                    draw_line(c + Vector2(0, gap), c + Vector2(0, gap + length), col, w)
                    draw_line(c - Vector2(0, gap), c - Vector2(0, gap + length), col, w)
                draw_circle(c, 1.6, white)

    func _draw_scope(c: Vector2) -> void:
        var r := minf(size.x, size.y) * 0.44
        var w := size.length()
        draw_arc(c, r + w * 0.5, 0.0, TAU, 96, Color.BLACK, w)
        draw_arc(c, r, 0.0, TAU, 96, Color(0.08, 0.08, 0.08), 6.0)
        draw_arc(c, r * 0.5, 0.0, TAU, 96, Color(0, 0, 0, 0.35), 1.0)
        draw_line(Vector2(c.x - r, c.y), Vector2(c.x - 14, c.y), Color(0, 0, 0, 0.9), 2.0)
        draw_line(Vector2(c.x + 14, c.y), Vector2(c.x + r, c.y), Color(0, 0, 0, 0.9), 2.0)
        draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y - 14), Color(0, 0, 0, 0.9), 2.0)
        draw_line(Vector2(c.x, c.y + 14), Vector2(c.x, c.y + r), Color(0, 0, 0, 0.9), 2.0)
        for i in range(1, 4):
            var t := i * 40.0
            draw_line(Vector2(c.x - 6, c.y + t), Vector2(c.x + 6, c.y + t), Color(0, 0, 0, 0.9), 1.5)
        draw_circle(c, 2.4, Color(1, 0.2, 0.2))
        var level := player.arsenal.scope_level
        draw_string(ThemeDB.fallback_font, c + Vector2(r * 0.55, -r * 0.55), "%dx" % (4 if level == 1 else 8),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))

    func _bar(pos: Vector2, sz: Vector2, t: float, col: Color) -> void:
        draw_rect(Rect2(pos, sz), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(pos + Vector2.ONE, Vector2((sz.x - 2.0) * clampf(t, 0.0, 1.0), sz.y - 2.0)), col)


class HpBar extends Control:
    var player: Player

    func _process(_d: float) -> void:
        queue_redraw()

    func _draw() -> void:
        if player == null:
            return
        var w := 250.0
        var h := 20.0
        var t := clampf(player.hp / player.max_hp, 0.0, 1.0)
        var col := Color(0.35, 0.9, 0.4).lerp(Color(0.95, 0.3, 0.25), 1.0 - t)
        draw_rect(Rect2(Vector2(0, 0), Vector2(w, h)), Color(0, 0, 0, 0.55))
        draw_rect(Rect2(Vector2(2, 2), Vector2((w - 4) * t, h - 4)), col)
        for i in range(1, 10):
            var x := 2 + (w - 4) * i / 10.0
            draw_line(Vector2(x, 2), Vector2(x, h - 2), Color(0, 0, 0, 0.25), 1.0)
        draw_string(ThemeDB.fallback_font, Vector2(w + 10, h - 2), "%d" % int(ceil(player.hp)),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
        if player.protection_left > 0.0:
            draw_string(ThemeDB.fallback_font, Vector2(0, -8), "SPAWN SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.9, 1.0, 0.9))


class SlotWidget extends Control:
    var slot := 1
    var data: WeaponData
    var player: Player

    func _process(_d: float) -> void:
        queue_redraw()

    func _draw() -> void:
        if player == null:
            return
        var active := player.arsenal.slot == slot
        var s := player.arsenal.states[slot - 1]
        var bg := Color(0.05, 0.06, 0.09, 0.55 if not active else 0.8)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        if active:
            draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.8, 0.3, 0.95), false, 2.0)
        var ink := Color(1, 1, 1, 1.0 if active else 0.55)
        if s.uses_ammo() and s.clip == 0 and s.reserve == 0:
            ink = Color(1, 0.4, 0.35, 0.8)
        _icon(Vector2(8, 6), Vector2(size.x - 16, 24), ink)
        draw_string(ThemeDB.fallback_font, Vector2(5, 14), str(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
        var ammo := "--" if not s.uses_ammo() else ("%d" % s.clip if data.reserve == 0 else "%d|%d" % [s.clip, s.reserve])
        draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 6), ammo, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, ink)

    ## Tiny silhouette per weapon inside `r`.
    func _icon(pos: Vector2, sz: Vector2, col: Color) -> void:
        var o := pos + Vector2(0, sz.y * 0.5)
        var w := sz.x
        match slot:
            1:  # shovel
                draw_line(o + Vector2(4, 8), o + Vector2(w - 12, -6), col, 2.5)
                draw_rect(Rect2(o + Vector2(w - 14, -12), Vector2(10, 9)), col)
            2:  # rifle
                draw_rect(Rect2(o + Vector2(6, -4), Vector2(w - 18, 7)), col)
                draw_line(o + Vector2(w - 12, -1), o + Vector2(w - 2, -1), col, 2.0)
                draw_rect(Rect2(o + Vector2(14, 3), Vector2(6, 8)), col)
                draw_rect(Rect2(o + Vector2(2, -2), Vector2(6, 6)), col)
            3:  # shotgun
                draw_rect(Rect2(o + Vector2(4, -3), Vector2(w - 8, 5)), col)
                draw_rect(Rect2(o + Vector2(w * 0.45, 2), Vector2(w * 0.3, 4)), col)
                draw_rect(Rect2(o + Vector2(2, 0), Vector2(8, 7)), col)
            4:  # sniper
                draw_rect(Rect2(o + Vector2(2, -2), Vector2(w - 4, 4)), col)
                draw_arc(o + Vector2(w * 0.45, -6), 4.0, 0.0, TAU, 12, col, 2.0)
                draw_rect(Rect2(o + Vector2(w * 0.3, 2), Vector2(5, 7)), col)
            5:  # gatling
                for i in 3:
                    draw_line(o + Vector2(w * 0.3, -6 + i * 5), o + Vector2(w - 2, -6 + i * 5), col, 2.0)
                draw_rect(Rect2(o + Vector2(4, -7), Vector2(w * 0.3, 16)), col)
            6:  # bazooka
                draw_rect(Rect2(o + Vector2(2, -4), Vector2(w - 4, 8)), col)
                draw_rect(Rect2(o + Vector2(w - 10, -6), Vector2(8, 12)), col)
                draw_rect(Rect2(o + Vector2(w * 0.4, 4), Vector2(5, 6)), col)
            7:  # grenade launcher
                draw_rect(Rect2(o + Vector2(w * 0.35, -3), Vector2(w * 0.6, 6)), col)
                draw_arc(o + Vector2(w * 0.3, 0), 7.0, 0.0, TAU, 14, col, 2.5)
                draw_rect(Rect2(o + Vector2(2, -2), Vector2(8, 5)), col)


class Radar extends Control:
    var player: Player
    const R := 68.0
    const RANGE_M := 30.0

    func _process(_d: float) -> void:
        queue_redraw()

    func _draw() -> void:
        if player == null:
            return
        var c := Vector2(R + 4, R + 4)
        draw_circle(c, R + 3, Color(0, 0, 0, 0.35))
        draw_circle(c, R, Color(0.08, 0.1, 0.14, 0.55))
        draw_arc(c, R, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 1.5)
        draw_arc(c, R * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 1.0)
        draw_line(c - Vector2(R, 0), c + Vector2(R, 0), Color(1, 1, 1, 0.1), 1.0)
        draw_line(c - Vector2(0, R), c + Vector2(0, R), Color(1, 1, 1, 0.1), 1.0)
        # north tick relative to facing
        var north := Vector2(0, -1).rotated(player.yaw)
        draw_string(ThemeDB.fallback_font, c + north * (R - 12) + Vector2(-4, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
        for node in player.get_tree().get_nodes_in_group("characters"):
            var ch := node as Character
            if ch == null or ch == player or not ch.alive or ch is TargetDummy and false:
                continue
            var rel := ch.global_position - player.global_position
            var flat := Vector2(rel.x, rel.z)
            if flat.length() > RANGE_M:
                continue
            var local := flat.rotated(player.yaw)   # screen-up = facing
            var p := c + local / RANGE_M * R
            var ally := player.team != 0 and ch.team == player.team
            var col := Color(0.4, 0.7, 1.0) if ally else Color(1.0, 0.3, 0.25)
            draw_circle(p, 4.0, Color(0, 0, 0, 0.6))
            draw_circle(p, 3.0, col)
        # player arrow
        var pts := PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(-5, 5)])
        draw_colored_polygon(pts, Color(1, 0.85, 0.3))


# ---- lifecycle -----------------------------------------------------------------

func _ready() -> void:
    _build()
    _player = get_tree().get_first_node_in_group("player") as Player
    _match = get_tree().get_first_node_in_group("match") as MatchController
    _overlay.player = _player
    _overlay.hud = self
    _hp_bar.player = _player
    _radar.player = _player
    for sw in _slots:
        sw.player = _player
    if _player:
        _player.arsenal.hit_confirmed.connect(_on_hit)
        _player.damaged.connect(_on_damaged)
    if _match:
        _match.kill_feed.connect(_on_kill_feed)
        _match.match_ended.connect(_on_match_ended)
        _match.round_ended.connect(_on_round_ended)


func _process(_delta: float) -> void:
    _fps_label.text = "%d fps" % Engine.get_frames_per_second()
    if _player == null:
        return
    var now := Time.get_ticks_msec() / 1000.0
    var s := _player.arsenal.current()
    var d := s.data
    _weapon_label.text = d.display_name.to_upper()
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

    _popup_label.visible = _popup_until > now
    if _popup_label.visible:
        _popup_label.modulate.a = clampf((_popup_until - now) / 0.3, 0.0, 1.0)

    if _banner_until > now and _match:
        _center_label.text = _match.winner_text
        _center_label.modulate = Color(1, 0.85, 0.3)
    elif not _player.alive:
        if _match and _match.mode == "elim":
            _center_label.text = "Eliminated - watch the round"
        else:
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

    _radar = Radar.new()
    _radar.position = Vector2(20, 20)
    _radar.size = Vector2(150, 150)
    _radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_radar)

    _hp_bar = HpBar.new()
    _hp_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
    _hp_bar.size = Vector2(320, 24)
    _hp_bar.position = Vector2(24, -50)
    _hp_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_hp_bar)

    _ammo_label = _label("30 / 120", Control.PRESET_BOTTOM_RIGHT, 38)
    _ammo_label.offset_top -= 26
    _ammo_label.offset_bottom -= 26
    _weapon_label = _label("RIFLE", Control.PRESET_BOTTOM_RIGHT, 16)
    _weapon_label.modulate = Color(1, 1, 1, 0.8)
    _fps_label = _label("", Control.PRESET_TOP_RIGHT, 14)
    _fps_label.modulate = Color(1, 1, 1, 0.55)
    _feed_label = _label("", Control.PRESET_TOP_RIGHT, 17)
    _feed_label.offset_top += 26
    _feed_label.offset_bottom += 26
    _feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _status_label = _label("", Control.PRESET_CENTER_TOP, 18)
    _center_label = _label("", Control.PRESET_CENTER, 40)
    _center_label.offset_top += 110
    _center_label.offset_bottom += 110
    _center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _popup_label = _label("", Control.PRESET_CENTER, 26)
    _popup_label.offset_top -= 90
    _popup_label.offset_bottom -= 90
    _popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _popup_label.visible = false

    var strip := HBoxContainer.new()
    strip.add_theme_constant_override("separation", 6)
    strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
    _grow_inward(strip, Control.PRESET_CENTER_BOTTOM)
    add_child(strip)
    for d in WeaponDB.all():
        var sw := SlotWidget.new()
        sw.slot = d.slot
        sw.data = d
        sw.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
        sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
        strip.add_child(sw)
        _slots.append(sw)

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
    var elim := _match.mode == "elim"
    _score_row(["TOY", "RND" if elim else "K", "D"], Color(1, 1, 1, 0.6), true)
    for c in _match.ranking():
        var col := Color.WHITE
        if _match.mode == "tdm" or _match.mode == "elim":
            if c.team == 1:
                col = Color(1, 0.55, 0.4)
            elif c.team == 2:
                col = Color(0.55, 0.7, 1.0)
        if c == _player:
            col = Color(1, 0.9, 0.4)
        _score_row([c.display_name, str(c.rounds_won if elim else c.kills), str(c.deaths)], col, false)


func _score_row(cells: Array, color: Color, header: bool) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var widths := [200, 60, 50]
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


func _popup(text: String, color: Color) -> void:
    _popup_label.text = text
    _popup_label.modulate = color
    _popup_until = Time.get_ticks_msec() / 1000.0 + 1.0


func _on_hit(killed: bool, headshot: bool) -> void:
    _overlay.hit_marker = 0.15
    _overlay.hit_kill = killed
    if killed:
        Sfx.play_ui("kill")
        _popup("KILL" + ("  +  HEADSHOT" if headshot else ""), Color(1, 0.35, 0.3))
    else:
        Sfx.play_ui("headshot" if headshot else "hit_marker")
        if headshot:
            _popup("HEADSHOT", Color(1, 0.85, 0.3))


func _on_damaged(amount: float, source: Character, _headshot: bool) -> void:
    _damage_flash.color.a = clampf(amount / 60.0, 0.15, 0.5)
    var tw := _damage_flash.create_tween()
    tw.tween_property(_damage_flash, "color:a", 0.0, 0.35)
    if source != null and source != _player:
        var rel := source.global_position - _player.global_position
        var flat := Vector2(rel.x, rel.z).rotated(_player.yaw)
        if flat.length() > 0.01:
            _hurt_dir = flat.normalized()
            _hurt_until = Time.get_ticks_msec() / 1000.0 + 0.8


func _on_kill_feed(text: String) -> void:
    _feed.append([text, Time.get_ticks_msec() / 1000.0 + 5.0])
    if _feed.size() > 5:
        _feed.pop_front()


func _on_match_ended(_text: String) -> void:
    _banner_until = Time.get_ticks_msec() / 1000.0 + 7.0


func _on_round_ended(text: String) -> void:
    _popup(text, Color(1, 0.85, 0.3))
    _popup_until = Time.get_ticks_msec() / 1000.0 + 2.5
