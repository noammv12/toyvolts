class_name LobbyPanel
extends PanelContainer
## Online sheet on the title screen: name + toy, Host (port) / Join (ip:port), then the room:
## player list with teams, the host's map / mode / bots / difficulty, Start (host) or
## "waiting for the host" (clients), Leave. Late joiners land straight in the running match.

signal closed()

const ACCENT := Color(0.95, 0.42, 0.2)
const MODES := [["party", "Birthday Party"], ["ffa", "Free For All"], ["tdm", "Team Deathmatch"], ["elim", "Elimination"], ["ctb", "Capture the Battery"]]

var _name_edit: LineEdit
var _port_edit: LineEdit
var _address_edit: LineEdit
var _status: Label
var _connect_box: VBoxContainer
var _room_box: VBoxContainer
var _players_box: VBoxContainer
var _skin_buttons := {}
var _map_buttons := {}
var _mode_buttons := {}
var _difficulty_buttons := {}
var _bots_label: Label
var _start: Button
var _team_button: Button
var _wait_label: Label
var _host_only: Array[Control] = []


func _ready() -> void:
    custom_minimum_size = Vector2(620, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.1, 0.14, 0.97)
    style.border_color = Color(1, 1, 1, 0.08)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.set_content_margin_all(26)
    add_theme_stylebox_override("panel", style)
    if not Game.headless:
        _build()
    Net.lobby_changed.connect(refresh)
    Net.connected.connect(refresh)
    Net.connection_failed.connect(func(_r: String) -> void: refresh())
    Net.disconnected.connect(func(_r: String) -> void: refresh())


func _build() -> void:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    add_child(box)

    var head := HBoxContainer.new()
    box.add_child(head)
    var title := Label.new()
    title.text = "ONLINE"
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    var back := Button.new()
    back.text = "Back"
    back.custom_minimum_size = Vector2(110, 38)
    back.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        Net.leave()
        closed.emit())
    head.add_child(back)

    # ---- who you are
    var who := HBoxContainer.new()
    who.add_theme_constant_override("separation", 8)
    box.add_child(who)
    who.add_child(_row_label("Name"))
    _name_edit = LineEdit.new()
    _name_edit.text = Game.player_name if Game.player_name != "You" else ""
    _name_edit.placeholder_text = "your name"
    _name_edit.max_length = 16
    _name_edit.custom_minimum_size = Vector2(170, 36)
    _name_edit.text_changed.connect(func(_t: String) -> void: _push_identity())
    who.add_child(_name_edit)
    who.add_child(_spacer_w(10))
    for s in Skins.ALL:
        var b := Button.new()
        b.text = s.name
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(88, 36)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            Game.skin = s.id
            _push_identity())
        who.add_child(b)
        _skin_buttons[s.id] = b

    _status = Label.new()
    _status.add_theme_font_size_override("font_size", 15)
    _status.modulate = Color(1, 1, 1, 0.7)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_status)

    # ---- host / join
    _connect_box = VBoxContainer.new()
    _connect_box.add_theme_constant_override("separation", 8)
    box.add_child(_connect_box)
    var host_row := HBoxContainer.new()
    host_row.add_theme_constant_override("separation", 8)
    _connect_box.add_child(host_row)
    host_row.add_child(_row_label("Host"))
    host_row.add_child(_small_label("port"))
    _port_edit = LineEdit.new()
    _port_edit.text = str(Net.DEFAULT_PORT)
    _port_edit.custom_minimum_size = Vector2(90, 36)
    host_row.add_child(_port_edit)
    var host_btn := Button.new()
    host_btn.text = "Host a game"
    host_btn.custom_minimum_size = Vector2(170, 36)
    host_btn.add_theme_color_override("font_color", ACCENT)
    host_btn.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        _push_identity()
        Net.host(int(_port_edit.text) if _port_edit.text.is_valid_int() else Net.DEFAULT_PORT)
        refresh())
    host_row.add_child(host_btn)
    var join_row := HBoxContainer.new()
    join_row.add_theme_constant_override("separation", 8)
    _connect_box.add_child(join_row)
    join_row.add_child(_row_label("Join"))
    join_row.add_child(_small_label("ip:port"))
    _address_edit = LineEdit.new()
    _address_edit.text = "127.0.0.1:%d" % Net.DEFAULT_PORT
    _address_edit.placeholder_text = "100.x.y.z:7777"
    _address_edit.custom_minimum_size = Vector2(230, 36)
    join_row.add_child(_address_edit)
    var join_btn := Button.new()
    join_btn.text = "Join"
    join_btn.custom_minimum_size = Vector2(110, 36)
    join_btn.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        _push_identity()
        Net.join(_address_edit.text)
        refresh())
    join_row.add_child(join_btn)
    var hint := Label.new()
    hint.text = "Friends over the internet: install Tailscale on both machines, share your 100.x.y.z address (see tools/NET.md)."
    hint.add_theme_font_size_override("font_size", 13)
    hint.modulate = Color(1, 1, 1, 0.5)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _connect_box.add_child(hint)

    # ---- the room
    _room_box = VBoxContainer.new()
    _room_box.add_theme_constant_override("separation", 8)
    _room_box.visible = false
    box.add_child(_room_box)
    _room_box.add_child(_section("PLAYERS"))
    _players_box = VBoxContainer.new()
    _players_box.add_theme_constant_override("separation", 3)
    _room_box.add_child(_players_box)
    _team_button = Button.new()
    _team_button.text = "Switch team"
    _team_button.custom_minimum_size = Vector2(150, 32)
    _team_button.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        var me: Dictionary = Net.players.get(Net.local_id(), {})
        var team: int = 2 if int(me.get("team", 1)) == 1 else 1
        Net.set_local_player(_name_text(), Game.skin, team))
    _room_box.add_child(_team_button)

    _room_box.add_child(_section("MATCH"))
    var map_row := HBoxContainer.new()
    map_row.add_theme_constant_override("separation", 6)
    _room_box.add_child(map_row)
    map_row.add_child(_row_label("Map"))
    for key in Game.MAPS:
        var b := Button.new()
        b.text = Game.MAPS[key].name
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(120, 34)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _push_settings(key, "", -1, ""))
        map_row.add_child(b)
        _map_buttons[key] = b
        _host_only.append(b)
    var mode_row := HBoxContainer.new()
    mode_row.add_theme_constant_override("separation", 6)
    _room_box.add_child(mode_row)
    mode_row.add_child(_row_label("Mode"))
    for m in MODES:
        var b := Button.new()
        b.text = m[1]
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(0, 34)
        b.add_theme_font_size_override("font_size", 14)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _push_settings("", m[0], -1, ""))
        mode_row.add_child(b)
        _mode_buttons[m[0]] = b
        _host_only.append(b)
    var bots_row := HBoxContainer.new()
    bots_row.add_theme_constant_override("separation", 6)
    _room_box.add_child(bots_row)
    bots_row.add_child(_row_label("Bots"))
    var minus := Button.new()
    minus.text = "-"
    minus.custom_minimum_size = Vector2(36, 34)
    minus.pressed.connect(func() -> void: _push_settings("", "", int(Net.settings.bots) - 1, ""))
    bots_row.add_child(minus)
    _host_only.append(minus)
    _bots_label = Label.new()
    _bots_label.add_theme_font_size_override("font_size", 20)
    _bots_label.custom_minimum_size = Vector2(36, 0)
    _bots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bots_row.add_child(_bots_label)
    var plus := Button.new()
    plus.text = "+"
    plus.custom_minimum_size = Vector2(36, 34)
    plus.pressed.connect(func() -> void: _push_settings("", "", int(Net.settings.bots) + 1, ""))
    bots_row.add_child(plus)
    _host_only.append(plus)
    bots_row.add_child(_spacer_w(12))
    for level in ["easy", "normal", "hard"]:
        var b := Button.new()
        b.text = level.capitalize()
        b.toggle_mode = true
        b.custom_minimum_size = Vector2(74, 34)
        b.pressed.connect(func() -> void:
            Sfx.play_ui("ui_click")
            _push_settings("", "", -1, level))
        bots_row.add_child(b)
        _difficulty_buttons[level] = b
        _host_only.append(b)

    var bottom := HBoxContainer.new()
    bottom.add_theme_constant_override("separation", 10)
    _room_box.add_child(bottom)
    _start = Button.new()
    _start.text = "START"
    _start.custom_minimum_size = Vector2(220, 46)
    _start.add_theme_font_size_override("font_size", 24)
    _start.add_theme_color_override("font_color", ACCENT)
    _start.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        Game.save_settings()
        Net.start_match())
    bottom.add_child(_start)
    _wait_label = Label.new()
    _wait_label.text = "Waiting for the host to start..."
    _wait_label.add_theme_font_size_override("font_size", 16)
    _wait_label.modulate = Color(1, 1, 1, 0.7)
    bottom.add_child(_wait_label)
    var leave := Button.new()
    leave.text = "Leave"
    leave.custom_minimum_size = Vector2(110, 40)
    leave.pressed.connect(func() -> void:
        Sfx.play_ui("ui_click")
        Net.leave()
        refresh())
    bottom.add_child(leave)


func _name_text() -> String:
    var t := _name_edit.text.strip_edges() if _name_edit != null else Game.player_name
    return t if not t.is_empty() else "You"


func _push_identity() -> void:
    var me: Dictionary = Net.players.get(Net.local_id(), {})
    Net.set_local_player(_name_text(), Game.skin, int(me.get("team", 1)))
    Game.save_settings()


func _push_settings(map: String, mode: String, bots: int, difficulty: String) -> void:
    if not Net.is_server_role():
        return
    var new_map := map if map != "" else String(Net.settings.map)
    var new_mode := mode if mode != "" else String(Net.settings.mode)
    if mode == "party":
        new_map = "lalu_party"      # the party only happens in Lalu's room
    elif map == "lalu_party" and Net.settings.mode != "party":
        new_mode = "party"          # picking the room picks the party (any mode can be chosen after)
    Net.set_settings(new_map, new_mode,
        clampi(bots if bots >= 0 else int(Net.settings.bots), 0, 7),
        difficulty if difficulty != "" else Net.settings.difficulty)


## Redraw from Net state (called on every lobby change).
func refresh() -> void:
    if Game.headless or _status == null:
        return
    var online := Net.is_online()
    _connect_box.visible = not online
    _room_box.visible = online
    _status.text = Net.status if online or not Net.last_error.is_empty() else "Host a game on your machine, or join a friend's."
    if online and Net.is_client() and Net.players.is_empty():
        _status.text = Net.status
    for key in _skin_buttons:
        _skin_buttons[key].button_pressed = key == Game.skin
    if not online:
        return
    for child in _players_box.get_children():
        child.queue_free()
    var teams: bool = Net.settings.mode in ["tdm", "ctb"]
    for pid in Net.players:
        var p: Dictionary = Net.players[pid]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        var name_label := Label.new()
        name_label.text = p.name + ("  (host)" if pid == 1 else "") + ("  (you)" if pid == Net.local_id() else "")
        name_label.custom_minimum_size = Vector2(260, 0)
        name_label.add_theme_font_size_override("font_size", 17)
        row.add_child(name_label)
        var skin_label := Label.new()
        skin_label.text = Skins.display_name(p.skin)
        skin_label.custom_minimum_size = Vector2(120, 0)
        skin_label.modulate = Color(1, 1, 1, 0.7)
        row.add_child(skin_label)
        var team_label := Label.new()
        if teams:
            team_label.text = "RED" if int(p.team) == 1 else "BLUE"
            team_label.modulate = ArenaBase.TEAM_COLORS[int(p.team)]
        row.add_child(team_label)
        _players_box.add_child(row)
    _team_button.visible = teams
    for key in _map_buttons:
        _map_buttons[key].button_pressed = key == Net.settings.map
    for key in _mode_buttons:
        _mode_buttons[key].button_pressed = key == Net.settings.mode
    for key in _difficulty_buttons:
        _difficulty_buttons[key].button_pressed = key == Net.settings.difficulty
    _bots_label.text = str(Net.settings.bots)
    var host := Net.is_server_role()
    for c in _host_only:
        c.disabled = not host
    _start.visible = host
    _wait_label.visible = not host


func _section(text: String) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 13)
    l.modulate = Color(1, 1, 1, 0.5)
    return l


func _row_label(text: String) -> Label:
    var l := Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(60, 0)
    l.add_theme_font_size_override("font_size", 16)
    return l


func _small_label(text: String) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 13)
    l.modulate = Color(1, 1, 1, 0.55)
    return l


func _spacer_w(w: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(w, 0)
    return c
