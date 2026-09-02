extends Node
## Online play over ENet. Autoload "Net".
##
## The host (or a dedicated `--server`) runs the whole simulation: every Character, the
## Arsenal raycasts, bots, batteries, capsules, vials and the match rules. Clients send one
## input tick per physics frame (unreliable) and show the server's world: their own toy is
## predicted locally and reconciled against snapshots, everyone else interpolates snapshots,
## fire feedback plays at once, damage waits for the server (reliable events).
##
## Every RPC lives on this autoload (same node path on every peer) and addresses toys by
## `net_id` (humans: their peer id; bots: negative), never by node path.

signal lobby_changed()
signal connected()                       ## hosting, or joined a host
signal connection_failed(reason: String)
signal disconnected(reason: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
const INPUT_CHANNEL := 1
const SNAPSHOT_CHANNEL := 2
const PING_INTERVAL := 1.0
const CORRECTION_MIN := 0.12       ## metres of prediction error we ignore
const CORRECTION_SNAP := 3.0       ## metres of error we teleport over (respawn, big knockback)
const CORRECTION_RATE := 0.3       ## share of the remaining correction applied per tick
const PREDICTION_HISTORY := 90

enum Role { OFFLINE, HOST, CLIENT, SERVER }

var role := Role.OFFLINE
var players := {}                  ## peer_id -> {name, skin, team}
var settings := {"map": "toy_room", "mode": "ffa", "bots": 3, "difficulty": "normal"}
var in_match := false
var characters := {}               ## net_id -> Character (this machine's instances)
var vials := {}                    ## vial id -> HealthVial
var tick := 0                      ## server simulation tick
var ping_ms := 0
var status := ""                   ## lobby status text
var snapshots_received := 0
var last_error := ""

var _peer: ENetMultiplayerPeer
var _inputs := {}                  ## server: peer_id -> NetInput
var _interp := {}                  ## client: net_id -> NetInterp
var _seq := 0                      ## client: input sequence
var _jump_seq := 0
var _select_seq := 0
var _select_args: Array[int] = []
var _reload_seq := 0
var _last_shot_seq := 0
var _history: Array = []           ## client: [seq, predicted pos] ring for reconciliation
var _correction := Vector3.ZERO
var _last_ack := -1
var _vial_serial := 0
var _ping_t := 0.0
var _arena: ArenaBase
var _local: Character              ## the toy this machine controls (host or client)
var _remote_shots := 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---- roles ----------------------------------------------------------------------------

func is_online() -> bool:
    return role != Role.OFFLINE


## This machine simulates (offline play, the host, a dedicated server).
func is_authority() -> bool:
    return role != Role.CLIENT


func is_client() -> bool:
    return role == Role.CLIENT


func is_server_role() -> bool:
    return role == Role.HOST or role == Role.SERVER


func has_local_human() -> bool:
    return role != Role.SERVER


func local_id() -> int:
    return multiplayer.get_unique_id() if is_online() else 1


func peer_count() -> int:
    return multiplayer.get_peers().size() if is_online() else 0


func role_name() -> String:
    return ["offline", "host", "client", "server"][role]


# ---- host / join / leave ---------------------------------------------------------------

func host(port: int = DEFAULT_PORT, dedicated := false) -> Error:
    leave()
    var p := ENetMultiplayerPeer.new()
    var err := p.create_server(port, MAX_PLAYERS)
    if err != OK:
        last_error = "Could not open port %d (%s)" % [port, error_string(err)]
        status = last_error
        print("[net] ", last_error)
        connection_failed.emit(last_error)
        return err
    _peer = p
    multiplayer.multiplayer_peer = p
    role = Role.SERVER if dedicated else Role.HOST
    players.clear()
    settings = {"map": Game.map, "mode": Game.mode if Game.mode != "practice" else "ffa",
        "bots": Game.bot_count, "difficulty": Game.bot_difficulty}
    if not dedicated:
        players[1] = {"name": Game.player_name, "skin": Game.skin, "team": 1}
    status = "Hosting on port %d" % port
    print("[net] hosting on port %d%s" % [port, " (dedicated)" if dedicated else ""])
    connected.emit()
    lobby_changed.emit()
    return OK


func join(address: String) -> Error:
    leave()
    var host_name := address.strip_edges()
    var port := DEFAULT_PORT
    var colon := host_name.rfind(":")
    if colon > 0 and host_name.substr(colon + 1).is_valid_int():
        port = int(host_name.substr(colon + 1))
        host_name = host_name.substr(0, colon)
    if host_name.is_empty():
        host_name = "127.0.0.1"
    var p := ENetMultiplayerPeer.new()
    var err := p.create_client(host_name, port)
    if err != OK:
        last_error = "Could not connect to %s:%d (%s)" % [host_name, port, error_string(err)]
        status = last_error
        print("[net] ", last_error)
        connection_failed.emit(last_error)
        return err
    _peer = p
    multiplayer.multiplayer_peer = p
    role = Role.CLIENT
    players.clear()
    status = "Connecting to %s:%d ..." % [host_name, port]
    print("[net] connecting to %s:%d" % [host_name, port])
    return OK


func leave() -> void:
    if not is_online():
        return
    print("[net] leaving (%s)" % role_name())
    if _peer != null:
        _peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    _peer = null
    role = Role.OFFLINE
    players.clear()
    characters.clear()
    vials.clear()
    _inputs.clear()
    _interp.clear()
    _history.clear()
    in_match = false
    _local = null
    _arena = null
    status = ""
    lobby_changed.emit()


func _on_peer_connected(id: int) -> void:
    print("[net] peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
    if is_server_role():
        var pname: String = players.get(id, {}).get("name", "peer %d" % id)
        print("[net] peer %d left (%s)" % [id, pname])
        players.erase(id)
        _inputs.erase(id)
        if characters.has(id):
            var c: Character = characters[id]
            characters.erase(id)
            if is_instance_valid(c):
                c.queue_free()
            rpc("_despawn", id)
        rpc("_lobby", players, settings)
        lobby_changed.emit()
        _notice_all("%s left" % pname)
    else:
        print("[net] peer %d left" % id)


func _on_connected_to_server() -> void:
    print("[net] connected to server as peer %d" % multiplayer.get_unique_id())
    status = "Connected"
    rpc_id(1, "_register", Game.player_name, Game.skin)
    connected.emit()


func _on_connection_failed() -> void:
    last_error = "Connection failed (no host at that address, or the port is closed)"
    print("[net] ", last_error)
    leave()
    status = last_error
    connection_failed.emit(last_error)


func _on_server_disconnected() -> void:
    print("[net] host left")
    var was_in_match := in_match
    leave()
    status = "The host left"
    disconnected.emit(status)
    if was_in_match:
        Game.notice.emit("The host left the game")
        Game.to_menu()


# ---- lobby ------------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, skin: String) -> void:
    if not is_server_role():
        return
    var id := multiplayer.get_remote_sender_id()
    var clean := pname.strip_edges().substr(0, 16)
    if clean.is_empty():
        clean = "Toy %d" % id
    players[id] = {"name": _unique_name(clean), "skin": skin if Skins.display_name(skin) != skin else "Knight",
        "team": _balanced_team()}
    print("[net] peer %d registered as %s" % [id, players[id].name])
    rpc("_lobby", players, settings)
    lobby_changed.emit()
    _notice_all("%s joined" % players[id].name)
    if in_match:
        rpc_id(id, "_start_match", settings)


func _unique_name(base: String) -> String:
    var used := []
    for pid in players:
        used.append(players[pid].name)
    var candidate := base
    var n := 2
    while used.has(candidate):
        candidate = "%s %d" % [base, n]
        n += 1
    return candidate


func _balanced_team() -> int:
    var red := 0
    var blue := 0
    for pid in players:
        if players[pid].team == 1:
            red += 1
        elif players[pid].team == 2:
            blue += 1
    return 1 if red <= blue else 2


@rpc("authority", "call_remote", "reliable")
func _lobby(new_players: Dictionary, new_settings: Dictionary) -> void:
    players = new_players
    settings = new_settings
    lobby_changed.emit()


## Lobby UI: this machine's name / skin / team changed.
func set_local_player(pname: String, skin: String, team: int) -> void:
    Game.player_name = pname
    Game.skin = skin
    if is_server_role():
        if players.has(1):
            players[1] = {"name": pname, "skin": skin, "team": team}
            rpc("_lobby", players, settings)
            lobby_changed.emit()
    elif is_client():
        rpc_id(1, "_update_player", pname, skin, team)


@rpc("any_peer", "call_remote", "reliable")
func _update_player(pname: String, skin: String, team: int) -> void:
    if not is_server_role():
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    var clean := pname.strip_edges().substr(0, 16)
    players[id] = {"name": clean if not clean.is_empty() else players[id].name,
        "skin": skin, "team": clampi(team, 1, 2)}
    rpc("_lobby", players, settings)
    lobby_changed.emit()


## Lobby UI (host only): match settings changed.
func set_settings(map: String, mode: String, bots: int, difficulty: String) -> void:
    if not is_server_role():
        return
    settings = {"map": map, "mode": mode, "bots": bots, "difficulty": difficulty}
    rpc("_lobby", players, settings)
    lobby_changed.emit()


## Host presses Start (or the dedicated server boots): everyone loads the map.
func start_match() -> void:
    if not is_server_role():
        return
    in_match = true
    Game.map = settings.map
    Game.mode = settings.mode
    Game.bot_count = int(settings.bots)
    Game.bot_difficulty = settings.difficulty
    print("[net] match starting: %s %s bots=%d" % [Game.map, Game.mode, Game.bot_count])
    rpc("_start_match", settings)
    Game.start_match(Game.mode, Game.bot_count)


@rpc("authority", "call_remote", "reliable")
func _start_match(s: Dictionary) -> void:
    if not is_client():
        return
    settings = s
    in_match = true
    Game.map = s.map
    Game.mode = s.mode
    Game.bot_count = int(s.bots)
    Game.bot_difficulty = s.difficulty
    print("[net] match starting: %s %s" % [Game.map, Game.mode])
    Game.start_match(Game.mode, Game.bot_count)


func _notice_all(text: String) -> void:
    Game.notice.emit(text)
    if is_server_role():
        rpc("_ev_notice", text)


@rpc("authority", "call_remote", "reliable")
func _ev_notice(text: String) -> void:
    Game.notice.emit(text)


# ---- arena / spawning ----------------------------------------------------------------------

## ArenaBase calls this at the end of its _ready.
func on_arena_ready(arena: ArenaBase) -> void:
    _arena = arena
    characters.clear()
    vials.clear()
    _interp.clear()
    _history.clear()
    _correction = Vector3.ZERO
    _last_ack = -1
    _local = null
    snapshots_received = 0
    tick = 0
    if not is_online():
        return
    if is_client():
        print("[net] arena ready, announcing to the host")
        rpc_id(1, "_client_ready")
        return
    for node in get_tree().get_nodes_in_group("characters"):
        register_character(node as Character)
    var m := arena.get_node_or_null("Match") as MatchController
    if m != null:
        m.kill_feed.connect(func(text: String) -> void: rpc("_ev_feed", text))
        m.announce.connect(func(text: String, who: Character) -> void: rpc("_ev_announce", text, _id_of(who)))
        m.round_ended.connect(func(text: String, who: Character) -> void:
            rpc("_ev_round", text, _id_of(who))
            _send_match_state(0)
            _send_scores(0))
        m.round_started.connect(func() -> void: _send_match_state(0))
        m.match_ended.connect(func(text: String, who: Character) -> void:
            rpc("_ev_end", text, _id_of(who))
            _send_scores(0))
        m.restarted.connect(func() -> void:
            rpc("_ev_restart")
            _send_scores(0))
    # peers already waiting in the lobby got _start_match; they announce themselves with _client_ready


func register_character(c: Character) -> void:
    if c == null:
        return
    characters[c.net_id] = c
    if c.is_local():
        _local = c
    if is_server_role():
        c.arsenal.fired.connect(_on_char_fired.bind(c))
        c.arsenal.melee_swung.connect(_on_char_melee.bind(c))
        c.arsenal.reload_started.connect(_on_char_reload.bind(c))
        c.arsenal.hit_confirmed.connect(_on_char_hit.bind(c))
        c.damaged.connect(_on_char_damaged.bind(c))
        c.died.connect(_on_char_died)
        c.respawned.connect(_on_char_respawned.bind(c))
    elif is_client():
        c.arsenal.cosmetic = true
        if c.is_local():
            c.predicted = true
            c.arsenal.weapon_changed.connect(func(slot: int, _d: WeaponData) -> void: _select_args.append(slot))
            c.arsenal.reload_started.connect(func() -> void: _reload_seq = (_reload_seq + 1) & 0xFF)
            c.arsenal.fired.connect(func(_d: WeaponData) -> void: _last_shot_seq = _seq)
        else:
            c.puppet = true
            _interp[c.net_id] = NetInterp.new()


func _id_of(c: Character) -> int:
    return c.net_id if c != null and is_instance_valid(c) else 0


func _char(net_id: int) -> Character:
    var c: Character = characters.get(net_id)
    return c if c != null and is_instance_valid(c) else null


func _match() -> MatchController:
    return _arena.get_node_or_null("Match") as MatchController if _arena != null and is_instance_valid(_arena) else null


@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
    if not is_server_role() or _arena == null:
        return
    var id := multiplayer.get_remote_sender_id()
    var info: Dictionary = players.get(id, {})
    if info.is_empty():
        return
    if not characters.has(id):
        var teams := Game.mode in ["tdm", "ctb"]
        var team: int = int(info.team) if teams else 0
        var c := _arena.spawn_human(id, id, info.name, info.skin, team, Vector3.ZERO, 0.0, false)
        var ni := NetInput.new()
        c.controller = ni
        _inputs[id] = ni
        if not teams:
            c.set_color(ArenaBase.FFA_COLORS[(players.keys().find(id) + 3) % ArenaBase.FFA_COLORS.size()])
        var m := _match()
        var p: Vector3 = m.pick_spawn(c) if m != null else _arena.spawns[0]
        c.global_position = p
        c.yaw = atan2(p.x, p.z)
        c.protection_left = Character.SPAWN_PROTECTION
        register_character(c)
        print("[net] spawned C%d (%s) for peer %d" % [id, info.name, id])
        rpc("_spawn", _spawn_args(c))
    # the full world for the newcomer
    for nid in characters:
        var other := _char(nid)
        if other != null and nid != id:
            rpc_id(id, "_spawn", _spawn_args(other))
    _send_scores(id)
    _send_objects(id)
    _send_match_state(id)


func _spawn_args(c: Character) -> Array:
    return [c.net_id, c.peer_id, c.display_name, c.model_id, c.team, c.body_color,
        c.global_position, c.yaw, c is Bot]


@rpc("authority", "call_remote", "reliable")
func _spawn(args: Array) -> void:
    if not is_client() or _arena == null or not is_instance_valid(_arena):
        return
    var net_id: int = args[0]
    if characters.has(net_id):
        return
    var peer_id: int = args[1]
    var local := peer_id == multiplayer.get_unique_id()
    var c := _arena.spawn_human(net_id, peer_id, args[2], args[3], args[4], args[6], args[7], local)
    c.set_color(args[5])
    register_character(c)
    print("[net] spawned C%d (%s)%s" % [net_id, args[2], " (local)" if local else ""])


@rpc("authority", "call_remote", "reliable")
func _despawn(net_id: int) -> void:
    var c := _char(net_id)
    characters.erase(net_id)
    _interp.erase(net_id)
    if c != null:
        c.queue_free()


# ---- client input + prediction ---------------------------------------------------------------

## Character hook (client, local toy): the controller wrote this tick's inputs; ship them.
func client_before_simulate(c: Character) -> void:
    _seq += 1
    if c.jump_pressed:
        _jump_seq = (_jump_seq + 1) & 0xFF
    var a := 0
    var b := 0
    if not _select_args.is_empty():
        _select_seq = (_select_seq + 1) & 0xFF
        a = _select_args[0]
        b = _select_args[-1] if _select_args.size() > 1 else 0
        _select_args.clear()
    var ray := c.get_aim_ray()
    var packet := {"seq": _seq, "yaw": c.yaw, "pitch": c.pitch, "wish": c.wish_dir,
        "trigger": c.arsenal.trigger, "alt": c.arsenal.alt, "jump": c.jump_pressed,
        "jump_seq": _jump_seq, "select_seq": _select_seq, "select_a": a, "select_b": b,
        "reload_seq": _reload_seq, "aim_origin": ray.origin, "aim_dir": ray.dir}
    rpc_id(1, "_rpc_input", NetCodec.encode_input(packet))


## Character hook (client, local toy): after move_and_slide. Record the prediction and ease
## in any pending correction.
func client_after_simulate(c: Character) -> void:
    _history.append([_seq, c.global_position + _correction])
    while _history.size() > PREDICTION_HISTORY:
        _history.pop_front()
    if _correction.length() > 0.0005:
        var step := _correction * CORRECTION_RATE
        c.global_position += step
        _correction -= step
    else:
        _correction = Vector3.ZERO


@rpc("any_peer", "call_remote", "unreliable_ordered", INPUT_CHANNEL)
func _rpc_input(bytes: PackedByteArray) -> void:
    if not is_server_role():
        return
    var ni: NetInput = _inputs.get(multiplayer.get_remote_sender_id())
    if ni != null:
        ni.push(NetCodec.decode_input(bytes))


# ---- snapshots ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    if not is_online():
        return
    if is_server_role():
        tick += 1
        if in_match and _arena != null and is_instance_valid(_arena) and not multiplayer.get_peers().is_empty():
            _send_snapshot()
    elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
        _ping_t += delta
        if _ping_t >= PING_INTERVAL:
            _ping_t = 0.0
            rpc_id(1, "_ping", Time.get_ticks_msec())


func _send_snapshot() -> void:
    var m := _match()
    var toys: Array = []
    for nid in characters:
        var c := _char(nid)
        if c == null:
            continue
        var s := c.arsenal.current()
        toys.append({"net_id": nid, "pos": c.global_position, "vel": c.velocity, "yaw": c.yaw,
            "pitch": c.pitch, "slot": c.arsenal.slot, "hp": c.hp, "alive": c.alive,
            "on_floor": c.is_on_floor(), "carrying": c.carrying != null,
            "scope": c.arsenal.scope_level, "aiming": c.arsenal.aiming, "clip": s.clip,
            "reserve": s.reserve, "ack_seq": c.controller.last_seq if c.controller is NetInput else 0,
            "jumps_used": c._jumps_used})
    rpc("_snapshot", NetCodec.encode_snapshot(tick, m.time_left if m != null else 0.0, toys))


@rpc("authority", "call_remote", "unreliable_ordered", SNAPSHOT_CHANNEL)
func _snapshot(bytes: PackedByteArray) -> void:
    if not is_client():
        return
    var snap := NetCodec.decode_snapshot(bytes)
    if snap.is_empty():
        return
    if snapshots_received == 0:
        print("[net] first snapshot: tick %d, %d toys" % [snap.tick, snap.toys.size()])
    snapshots_received += 1
    var m := _match()
    if m != null:
        m.time_left = snap.time_left
    for t in snap.toys:
        var c := _char(t.net_id)
        if c == null:
            continue
        if c == _local:
            _reconcile(c, t)
        else:
            var it: NetInterp = _interp.get(t.net_id)
            if it == null:
                it = NetInterp.new()
                _interp[t.net_id] = it
            it.push(snap.tick, t)


func _reconcile(c: Character, t: Dictionary) -> void:
    if not c.alive:
        return
    if absf(c.hp - t.hp) >= 1.0:
        c.hp = t.hp
        c.health_changed.emit(c.hp, c.max_hp)
    if int(t.ack_seq) <= _last_ack:
        return
    _last_ack = int(t.ack_seq)
    if int(t.slot) == c.arsenal.slot and c.arsenal.swap_left <= 0.0 and _last_ack >= _last_shot_seq:
        var s := c.arsenal.current()
        if not s.is_reloading():
            s.clip = int(t.clip)
            s.reserve = int(t.reserve)
    var predicted := Vector3.INF
    for h in _history:
        if h[0] == _last_ack:
            predicted = h[1]
            break
    if predicted == Vector3.INF:
        return
    var err: Vector3 = t.pos - predicted
    var dist := err.length()
    if dist < CORRECTION_MIN:
        return
    for h in _history:
        h[1] += err
    if dist > CORRECTION_SNAP:
        c.global_position += err + _correction
        c.velocity = t.vel
        _correction = Vector3.ZERO
    else:
        _correction += err


## Character hook (client, puppets): one physics tick of interpolation.
func puppet_step(c: Character) -> void:
    var it: NetInterp = _interp.get(c.net_id)
    if it == null or not it.has_samples():
        return
    it.advance(1.0)
    var s := it.sample()
    if s.is_empty():
        return
    c.global_position = s.pos
    c.velocity = s.vel
    c.yaw = s.yaw
    c.pitch = s.pitch
    c.puppet_on_floor = s.on_floor
    if absf(c.hp - s.hp) >= 1.0:
        c.hp = s.hp
        c.health_changed.emit(c.hp, c.max_hp)
    if int(s.slot) != c.arsenal.slot and c.alive:
        c.arsenal.select(int(s.slot))
    c.arsenal.scope_level = int(s.scope)
    c.arsenal.aiming = s.aiming


@rpc("any_peer", "call_remote", "unreliable")
func _ping(t: int) -> void:
    if is_server_role():
        rpc_id(multiplayer.get_remote_sender_id(), "_pong", t)


@rpc("authority", "call_remote", "unreliable")
func _pong(t: int) -> void:
    ping_ms = Time.get_ticks_msec() - t


# ---- events: server side -----------------------------------------------------------------------

func _peers_except(peer_id: int) -> Array:
    var out := []
    for pid in multiplayer.get_peers():
        if pid != peer_id:
            out.append(pid)
    return out


func _on_char_fired(d: WeaponData, c: Character) -> void:
    var ray := c.get_aim_ray()
    if c.peer_id > 1:
        _remote_shots += 1
        if _remote_shots == 1 or _remote_shots % 100 == 0:
            print("[net] remote shot #%d: C%d slot %d from %s along %s" % [_remote_shots, c.net_id, d.slot, ray.origin, ray.dir])
    for pid in _peers_except(c.peer_id):
        rpc_id(pid, "_ev_fired", c.net_id, d.slot, ray.origin, ray.dir)


func _on_char_melee(heavy: bool, c: Character) -> void:
    for pid in _peers_except(c.peer_id):
        rpc_id(pid, "_ev_melee", c.net_id, heavy)


func _on_char_reload(c: Character) -> void:
    for pid in _peers_except(c.peer_id):
        rpc_id(pid, "_ev_reload", c.net_id)


func _on_char_hit(killed: bool, headshot: bool, c: Character) -> void:
    if c.peer_id > 1 and multiplayer.get_peers().has(c.peer_id):
        rpc_id(c.peer_id, "_ev_hit", killed, headshot)


func _on_char_damaged(amount: float, source: Character, headshot: bool, c: Character) -> void:
    if multiplayer.get_peers().is_empty():
        return
    rpc("_ev_damaged", c.net_id, amount, _id_of(source), headshot, c.hp)
    if source != null and source.peer_id > 1:
        print("[net] hit: C%d (%s) damaged C%d (%s) for %.0f" % [source.net_id, source.display_name, c.net_id, c.display_name, amount])


func _on_char_died(victim: Character, killer: Character) -> void:
    if multiplayer.get_peers().is_empty():
        return
    rpc("_ev_died", victim.net_id, _id_of(killer), victim.last_hit_weapon)
    _send_scores(0)


func _on_char_respawned(c: Character) -> void:
    if multiplayer.get_peers().is_empty():
        return
    rpc("_ev_respawn", c.net_id, c.global_position, c.yaw)


func _send_scores(to: int) -> void:
    var rows: Array = []
    for nid in characters:
        var c := _char(nid)
        if c != null:
            rows.append([nid, c.kills, c.deaths, c.captures, c.rounds_won])
    if to == 0:
        if not multiplayer.get_peers().is_empty():
            rpc("_ev_scores", rows)
    else:
        rpc_id(to, "_ev_scores", rows)


func _send_match_state(to: int) -> void:
    var m := _match()
    if m == null:
        return
    var args := [m.active, m.round_active, m.round_number, m.winner_text, _id_of(m.winner), Game.match_active]
    if to == 0:
        if not multiplayer.get_peers().is_empty():
            rpc("_ev_match_state", args)
    else:
        rpc_id(to, "_ev_match_state", args)


func _send_objects(to: int) -> void:
    for node in get_tree().get_nodes_in_group("batteries"):
        var b := node as Battery
        if b != null:
            rpc_id(to, "_ev_battery", b.net_index, 1 if b.carrier != null else 0, _id_of(b.carrier), b.global_position)
    for node in get_tree().get_nodes_in_group("capsules"):
        var cap := node as ItemCapsule
        if cap != null:
            rpc_id(to, "_ev_capsule", cap.net_index, cap.is_available())
    for vid in vials:
        var v: HealthVial = vials[vid]
        if is_instance_valid(v):
            rpc_id(to, "_ev_vial", vid, v.global_position)
    var party := _party()
    if party != null:
        for args in party.remote_states():
            rpc_id(to, "_ev_party", args[0], args[1], args[2], args[3], args[4])


func _party() -> PartyManager:
    return _arena.get_node_or_null("Party") as PartyManager if _arena != null and is_instance_valid(_arena) else null


## Party props (candles, balloons, pinata, gifts, finale, reset) call this on the authority.
func party_event(kind: String, index: int, state: int, who_id: int, pos: Vector3) -> void:
    if is_server_role() and not multiplayer.get_peers().is_empty():
        rpc("_ev_party", kind, index, state, who_id, pos)


## Objects call these on the authority; they are no-ops offline.
func battery_changed(b: Battery) -> void:
    if is_server_role() and not multiplayer.get_peers().is_empty():
        rpc("_ev_battery", b.net_index, 1 if b.carrier != null else 0, _id_of(b.carrier), b.global_position)


func capsule_changed(cap: ItemCapsule) -> void:
    if is_server_role() and not multiplayer.get_peers().is_empty():
        rpc("_ev_capsule", cap.net_index, cap.is_available())


func vial_spawned(v: HealthVial) -> void:
    if not is_server_role():
        return
    _vial_serial += 1
    v.net_id = _vial_serial
    vials[v.net_id] = v
    if not multiplayer.get_peers().is_empty():
        rpc("_ev_vial", v.net_id, v.global_position)


func vial_taken(v: HealthVial) -> void:
    if not is_server_role():
        return
    vials.erase(v.net_id)
    if not multiplayer.get_peers().is_empty():
        rpc("_ev_vial_taken", v.net_id)


# ---- events: client side -----------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _ev_fired(net_id: int, slot: int, origin: Vector3, dir: Vector3) -> void:
    var c := _char(net_id)
    if c != null:
        c.arsenal.fire_remote(slot, origin, dir)


@rpc("authority", "call_remote", "reliable")
func _ev_melee(net_id: int, heavy: bool) -> void:
    var c := _char(net_id)
    if c != null:
        c.arsenal.melee_remote(heavy)


@rpc("authority", "call_remote", "reliable")
func _ev_reload(net_id: int) -> void:
    var c := _char(net_id)
    if c != null:
        c.arsenal.reload_remote()


@rpc("authority", "call_remote", "reliable")
func _ev_hit(killed: bool, headshot: bool) -> void:
    if _local != null and is_instance_valid(_local):
        _local.arsenal.hit_confirmed.emit(killed, headshot)
    print("[net] hit_confirmed killed=%s headshot=%s" % [killed, headshot])


@rpc("authority", "call_remote", "reliable")
func _ev_damaged(net_id: int, amount: float, source_id: int, headshot: bool, hp: float) -> void:
    var c := _char(net_id)
    if c != null:
        c.damage_remote(amount, _char(source_id), headshot, hp)


@rpc("authority", "call_remote", "reliable")
func _ev_died(net_id: int, killer_id: int, weapon: String) -> void:
    var c := _char(net_id)
    if c != null:
        c.last_hit_weapon = weapon
        c.die_remote(_char(killer_id))


@rpc("authority", "call_remote", "reliable")
func _ev_respawn(net_id: int, pos: Vector3, yaw: float) -> void:
    var c := _char(net_id)
    if c == null:
        return
    c.respawn(pos, yaw)
    print("[net] respawn C%d at %s" % [net_id, pos])
    if c == _local:
        _history.clear()
        _correction = Vector3.ZERO
    elif _interp.has(net_id):
        _interp[net_id] = NetInterp.new()


@rpc("authority", "call_remote", "reliable")
func _ev_scores(rows: Array) -> void:
    for row in rows:
        var c := _char(row[0])
        if c != null:
            c.kills = row[1]
            c.deaths = row[2]
            c.captures = row[3]
            c.rounds_won = row[4]


@rpc("authority", "call_remote", "reliable")
func _ev_feed(text: String) -> void:
    var m := _match()
    if m != null:
        m.kill_feed.emit(text)


@rpc("authority", "call_remote", "reliable")
func _ev_announce(text: String, who_id: int) -> void:
    var m := _match()
    if m != null:
        m.announce.emit(text, _char(who_id))


@rpc("authority", "call_remote", "reliable")
func _ev_round(text: String, who_id: int) -> void:
    var m := _match()
    if m != null:
        m.round_active = false
        m.round_ended.emit(text, _char(who_id))


@rpc("authority", "call_remote", "reliable")
func _ev_end(text: String, who_id: int) -> void:
    var m := _match()
    if m == null:
        return
    m.active = false
    m.winner_text = text
    m.winner = _char(who_id)
    Game.match_active = false
    print("[net] match ended: %s" % text)
    m.match_ended.emit(text, m.winner)


@rpc("authority", "call_remote", "reliable")
func _ev_match_state(args: Array) -> void:
    var m := _match()
    if m == null:
        return
    m.active = args[0]
    m.round_active = args[1]
    m.round_number = args[2]
    m.winner_text = args[3]
    m.winner = _char(args[4])
    Game.match_active = args[5]


@rpc("authority", "call_remote", "reliable")
func _ev_restart() -> void:
    var m := _match()
    if m == null:
        return
    m.winner_text = ""
    m.winner = null
    m.active = true
    m.round_active = true
    m.round_number = 1
    m.time_left = m.time_limit
    Game.match_active = true
    print("[net] match restarted")
    for vid in vials:
        if is_instance_valid(vials[vid]):
            vials[vid].queue_free()
    vials.clear()


@rpc("authority", "call_remote", "reliable")
func _ev_battery(index: int, state: int, carrier_id: int, pos: Vector3) -> void:
    for node in get_tree().get_nodes_in_group("batteries"):
        var b := node as Battery
        if b != null and b.net_index == index:
            b.apply_remote(state == 1, _char(carrier_id), pos)


@rpc("authority", "call_remote", "reliable")
func _ev_capsule(index: int, available: bool) -> void:
    for node in get_tree().get_nodes_in_group("capsules"):
        var cap := node as ItemCapsule
        if cap != null and cap.net_index == index:
            cap.set_available_remote(available)


@rpc("authority", "call_remote", "reliable")
func _ev_vial(id: int, pos: Vector3) -> void:
    if _arena == null or not is_instance_valid(_arena) or vials.has(id):
        return
    var v := HealthVial.new()
    v.net_id = id
    v.cosmetic = true
    _arena.add_child(v)
    v.global_position = pos
    vials[id] = v


@rpc("authority", "call_remote", "reliable")
func _ev_party(kind: String, index: int, state: int, who_id: int, pos: Vector3) -> void:
    var party := _party()
    if party != null:
        party.apply_remote(kind, index, state, _char(who_id), pos)


@rpc("authority", "call_remote", "reliable")
func _ev_vial_taken(id: int) -> void:
    var v: HealthVial = vials.get(id)
    vials.erase(id)
    if v != null and is_instance_valid(v):
        v.queue_free()
