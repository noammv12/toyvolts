extends Node
## Headless smoke + logic tests. Runs as a scene so autoloads exist before anything compiles.
## Run: tools/test.sh   (exit code 0 = green)

const ARENA := "res://src/world/arena_greybox.tscn"
const HudRadarProbe := preload("res://src/ui/hud.gd").Radar
const TARGET_DUMMY: PackedScene = preload("res://src/world/target_dummy.tscn")

var _fails := 0
var _count := 0


func _ready() -> void:
    Arsenal.spread_scale = 0.0
    _check("sound bank loaded (%d streams)" % Sfx._streams.size(), Sfx._streams.size() >= 28)
    _test_bindings()
    _test_weapon_state()
    _test_net_codec()
    _test_net_interp()
    _test_net_input()
    await _test_lag_comp()
    await _test_practice_scene()
    await _test_wave_step()
    await _test_match()
    await _test_elimination()
    await _test_toy_room()
    await _test_ctb()
    await _test_party()
    print("\n%d checks, %d failed" % [_count, _fails])
    get_tree().quit(1 if _fails > 0 else 0)


func _check(name: String, ok: bool) -> void:
    _count += 1
    if not ok:
        _fails += 1
    print("%s  %s" % ["PASS" if ok else "FAIL", name])


# ---- key bindings: rebind, conflicts swap, saved file, boot apply, defaults -------------

func _test_bindings() -> void:
    var saved := InputSetup.bindings.duplicate()
    InputSetup.reset_defaults()
    _check("bindings: every listed action has a default (%d)" % InputSetup.ORDER.size(),
        InputSetup.ORDER.size() == 21 and InputSetup.bindings.size() == 21 and InputSetup.binding_text("weapon_6") == "6"
        and InputSetup.binding_text("fire") == "LMB" and InputSetup.binding_text("weapon_next") == "Wheel Up")
    var e := InputEventKey.new()
    e.physical_keycode = KEY_E
    _check("bindings: bazooka rebinds to E", Game.set_binding("weapon_6", e) and InputSetup.binding_text("weapon_6") == "E")
    var events := InputMap.action_get_events("weapon_6")
    _check("bindings: the InputMap has exactly one event for weapon_6 and it is E",
        events.size() == 1 and events[0] is InputEventKey and events[0].physical_keycode == KEY_E)
    var six := InputEventKey.new()
    six.physical_keycode = KEY_6
    _check("bindings: 6 is free again (matches nothing)", not InputMap.event_is_action(six, "weapon_6"))
    var cfg := ConfigFile.new()
    var ok := cfg.load(Game.SETTINGS_PATH) == OK
    _check("bindings: saved to user://settings.cfg [controls] (weapon_6 = %s)" % cfg.get_value("controls", "weapon_6", "?"),
        ok and cfg.get_value("controls", "weapon_6", "") == "key:%d" % KEY_E and cfg.get_value("controls", "fire", "") == "mouse:%d" % MOUSE_BUTTON_LEFT)
    # conflict: reload wants E -> the two actions swap keys
    Game.set_binding("reload", e)
    _check("bindings: a conflict swaps (reload %s, bazooka %s)" % [InputSetup.binding_text("reload"), InputSetup.binding_text("weapon_6")],
        InputSetup.binding_text("reload") == "E" and InputSetup.binding_text("weapon_6") == "R")
    # mouse buttons bind too, and boot applies the saved file
    var m := InputEventMouseButton.new()
    m.button_index = MOUSE_BUTTON_XBUTTON1
    Game.set_binding("jump", m)
    _check("bindings: a mouse button binds (jump = %s)" % InputSetup.binding_text("jump"), InputSetup.binding_text("jump") == "Mouse 4"
        and InputMap.event_is_action(m, "jump"))
    InputSetup.reset_defaults()
    var cfg2 := ConfigFile.new()
    cfg2.load(Game.SETTINGS_PATH)
    InputSetup.read_from(cfg2)
    _check("bindings: reading the saved file at boot restores E / R / Mouse 4",
        InputSetup.binding_text("reload") == "E" and InputSetup.binding_text("weapon_6") == "R" and InputSetup.binding_text("jump") == "Mouse 4")
    _check("bindings: short HUD text (%s, %s)" % [InputSetup.short_text("weapon_next"), InputSetup.short_text("jump")],
        InputSetup.short_text("weapon_next") == "Wh+" and InputSetup.short_text("toggle_mouse") == "Esc")
    Game.reset_bindings()
    var cfg3 := ConfigFile.new()
    cfg3.load(Game.SETTINGS_PATH)
    _check("bindings: reset to defaults (file says weapon_6 = %s)" % cfg3.get_value("controls", "weapon_6", "?"),
        InputSetup.binding_text("weapon_6") == "6" and InputSetup.binding_text("jump") == "Space"
        and cfg3.get_value("controls", "weapon_6", "") == "key:%d" % KEY_6)
    # leave the developer's own bindings as they were
    InputSetup.bindings = saved
    InputSetup._apply_all()
    Game.save_settings()


# ---- pure logic ----------------------------------------------------------------

func _test_weapon_state() -> void:
    var rifle := WeaponState.new(WeaponDB.for_slot(2))
    _check("rifle starts full", rifle.clip == 30 and rifle.reserve == 120)
    _check("rifle ready", rifle.ready_to_fire())
    rifle.consume_shot()
    _check("rifle cooldown blocks", not rifle.ready_to_fire() and rifle.clip == 29)
    rifle.tick(0.1, false)
    _check("rifle ready after interval", rifle.ready_to_fire())
    rifle.start_reload()
    _check("reload started", rifle.is_reloading() and not rifle.ready_to_fire())
    rifle.tick(0.8, false)
    _check("reload progress ~0.5", absf(rifle.reload_progress() - 0.5) < 0.05)
    rifle.cancel_reload()
    _check("swap-cancel keeps clip", not rifle.is_reloading() and rifle.clip == 29 and rifle.reserve == 120)
    rifle.start_reload()
    rifle.tick(1.7, false)
    _check("reload completes", rifle.clip == 30 and rifle.reserve == 119)

    var shotgun := WeaponState.new(WeaponDB.for_slot(3))
    for i in 3:
        shotgun.consume_shot()
        shotgun.tick(1.0, false)
    _check("shotgun empty after 3", shotgun.clip == 0 and not shotgun.ready_to_fire())

    var gat := WeaponState.new(WeaponDB.for_slot(5))
    _check("gatling needs spin-up", not gat.ready_to_fire())
    for i in 30:
        gat.tick(1.0 / 60.0, true)
    _check("gatling spun up after 0.5 s", gat.ready_to_fire())
    var shots := 0
    for i in 130:
        if gat.ready_to_fire():
            gat.consume_shot()
            shots += 1
        gat.tick(gat.data.fire_interval, true)
    _check("gatling overheats before the belt runs out (%d shots)" % shots,
        gat.overheated and shots >= 100 and shots < 120)
    for i in 60:
        gat.tick(0.05, false)
    _check("gatling cools down", not gat.overheated)

    var melee := WeaponState.new(WeaponDB.for_slot(1))
    _check("melee never needs ammo", melee.has_ammo() and not melee.can_reload())


# ---- network: packet encoding, snapshot interpolation, server input queue ----------------

func _test_net_codec() -> void:
    var packet := {"seq": 70001, "yaw": 1.2345, "pitch": -0.5, "wish": Vector3(0.7071, 0.0, -0.7071),
        "trigger": true, "alt": false, "jump": true, "jump_seq": 7, "select_seq": 3, "select_a": 1,
        "select_b": 3, "reload_seq": 9, "aim_origin": Vector3(1.5, 2.25, -3.0), "aim_dir": Vector3(0.0, 0.6, -0.8),
        "crouch": true, "view_tick": 123456}
    var bytes := NetCodec.encode_input(packet)
    var back := NetCodec.decode_input(bytes)
    _check("input packet is %d bytes" % bytes.size(), bytes.size() == 48)
    _check("input packet carries the crouch flag and the view tick (%d)" % back.view_tick, back.crouch and back.view_tick == 123456)
    _check("input packet round-trips (seq, look, buttons, counters)", back.seq == 70001
        and is_equal_approx(back.yaw, 1.2345) and is_equal_approx(back.pitch, -0.5)
        and back.trigger and not back.alt and back.jump and back.jump_seq == 7
        and back.select_seq == 3 and back.select_a == 1 and back.select_b == 3 and back.reload_seq == 9)
    _check("input packet keeps the wish direction within 1%%", (back.wish - packet.wish).length() < 0.01)
    _check("input packet keeps the aim ray", back.aim_origin.is_equal_approx(packet.aim_origin)
        and back.aim_dir.is_equal_approx(packet.aim_dir))
    _check("truncated input packet decodes to nothing", NetCodec.decode_input(bytes.slice(0, 20)).is_empty())

    var toys := []
    for i in 3:
        toys.append({"net_id": [1, 82311, -2][i], "pos": Vector3(i, 0.5, -i * 3.0), "vel": Vector3(7, -2, 0),
            "yaw": 0.1 * i, "pitch": -0.2, "slot": 3, "hp": 61.4, "alive": true, "on_floor": i == 0,
            "carrying": i == 2, "scope": 2, "aiming": true, "clip": 3, "reserve": 12, "ack_seq": 4200 + i,
            "jumps_used": 1, "crouch": i == 1})
    var sb := NetCodec.encode_snapshot(9001, 123.5, toys)
    var snap := NetCodec.decode_snapshot(sb)
    _check("snapshot with 3 toys is %d bytes" % sb.size(), sb.size() == 9 + 3 * 47)
    var ok: bool = snap.tick == 9001 and is_equal_approx(snap.time_left, 123.5) and snap.toys.size() == 3
    if ok:
        var t: Dictionary = snap.toys[1]
        ok = t.net_id == 82311 and t.pos.is_equal_approx(Vector3(1, 0.5, -3)) and t.vel.is_equal_approx(Vector3(7, -2, 0)) \
            and is_equal_approx(t.yaw, 0.1) and t.slot == 3 and t.hp == 62.0 and t.alive and not t.on_floor \
            and not t.carrying and t.scope == 2 and t.aiming and t.clip == 3 and t.reserve == 12 and t.ack_seq == 4201 \
            and t.jumps_used == 1 and snap.toys[2].net_id == -2 and snap.toys[2].carrying and snap.toys[0].on_floor             and t.crouch and not snap.toys[0].crouch
    _check("snapshot round-trips (ids incl. negative bots, flags, ammo, ack)", ok)


func _test_net_interp() -> void:
    var it := NetInterp.new()
    var mk := func(x: float, yaw: float) -> Dictionary:
        return {"pos": Vector3(x, 0, 0), "vel": Vector3(60, 0, 0), "yaw": yaw, "pitch": 0.0, "slot": 2,
            "hp": 100.0, "alive": true, "on_floor": true, "carrying": false, "scope": 0, "aiming": false}
    it.push(100, mk.call(0.0, 0.0))
    it.push(110, mk.call(10.0, 1.0))
    it.push(105, mk.call(99.0, 9.0))   # late packet: ignored
    var mid := it.sample_at(105.0)
    _check("interp: midpoint between two snapshots", mid.pos.is_equal_approx(Vector3(5, 0, 0)) and is_equal_approx(mid.yaw, 0.5))
    _check("interp: late packet dropped", it.latest_tick() == 110)
    var beyond := it.sample_at(120.0)
    _check("interp: extrapolates at most %d ticks along the velocity" % int(NetInterp.MAX_EXTRAPOLATE),
        beyond.pos.is_equal_approx(Vector3(10 + 60 * NetInterp.MAX_EXTRAPOLATE / 60.0, 0, 0)))
    it.advance(1.0)
    _check("interp: clock starts DELAY_TICKS behind the newest snapshot (%.1f)" % it.render_tick,
        is_equal_approx(it.render_tick, 110 - NetInterp.DELAY_TICKS))
    for i in 20:
        it.push(111 + i, mk.call(11.0 + i, 0.0))
        it.advance(1.0)
    _check("interp: clock keeps pace with a steady stream (%.1f vs %d)" % [it.render_tick, it.latest_tick()],
        absf((it.latest_tick() - NetInterp.DELAY_TICKS) - it.render_tick) < 1.5)
    var wrap := NetInterp.lerp_state(mk.call(0.0, 3.0), mk.call(0.0, -3.0), 0.5)
    _check("interp: yaw blends the short way round (%.2f)" % wrap.yaw, absf(absf(wrap.yaw) - PI) < 0.01)


func _test_net_input() -> void:
    var ni := NetInput.new()
    var c := TARGET_DUMMY.instantiate() as Character
    add_child(c)
    await get_tree().process_frame
    var base := {"seq": 1, "yaw": 0.3, "pitch": 0.1, "wish": Vector3(1, 0, 0), "trigger": false, "alt": false,
        "jump": false, "jump_seq": 5, "select_seq": 2, "select_a": 0, "select_b": 0, "reload_seq": 1,
        "aim_origin": Vector3.ZERO, "aim_dir": Vector3.FORWARD}
    ni.push(base.duplicate())
    ni.feed(c, 1.0 / 60.0)
    _check("net input: first packet primes the counters without a jump", not c.jump_pressed and is_equal_approx(c.yaw, 0.3)
        and c.wish_dir.is_equal_approx(Vector3(1, 0, 0)) and ni.last_seq == 1)
    var p2 := base.duplicate()
    p2.seq = 2
    p2.jump_seq = 6
    p2.trigger = true
    ni.push(p2)
    ni.feed(c, 1.0 / 60.0)
    _check("net input: jump counter edge presses jump once", c.jump_pressed and c.arsenal.trigger)
    c.jump_pressed = false
    var p3 := base.duplicate()
    p3.seq = 3
    p3.jump_seq = 6
    ni.push(p3)
    ni.feed(c, 1.0 / 60.0)
    _check("net input: same counter again does not re-jump", not c.jump_pressed and not c.arsenal.trigger)
    var p4 := base.duplicate()
    p4.seq = 4
    p4.select_seq = 3
    p4.select_a = 1
    p4.select_b = 3
    ni.push(p4)
    ni.feed(c, 1.0 / 60.0)
    _check("net input: two selects in one packet apply in order (slot %d, previous %d)" % [c.arsenal.slot, c.arsenal.previous_slot],
        c.arsenal.slot == 3 and c.arsenal.previous_slot == 1)
    ni.push({"seq": 2, "yaw": 9.0})   # stale
    _check("net input: stale packets are dropped", ni.packets == 4)
    ni.feed(c, 1.0 / 60.0)
    _check("net input: starved tick repeats the last held state", ni.last_seq == 4 and is_equal_approx(c.yaw, 0.3))
    for i in range(5, 11):
        var p := base.duplicate()
        p.seq = i
        ni.push(p)
    _check("net input: queue caps at %d" % NetInput.MAX_QUEUE, ni.queue.size() == NetInput.MAX_QUEUE)
    ni.feed(c, 1.0 / 60.0)
    _check("net input: catches up two per tick when behind", ni.queue.size() == NetInput.MAX_QUEUE - 2)
    c.queue_free()
    await get_tree().process_frame


# ---- lag compensation: pose history ring, rewind cap, a rewound raycast ------------------

func _test_lag_comp() -> void:
    var h := NetHistory.new()
    for t in range(1, 21):
        h.record(t, Vector3(t, 0, 0), 0.1 * t, t % 2 == 0)
    h.record(20, Vector3(99, 0, 0), 0.0, false)   # duplicate tick: ignored
    _check("lag comp: history keeps the last %d ticks (%d..%d)" % [NetHistory.TICKS, h.oldest_tick(), h.newest_tick()],
        h.size() == NetHistory.TICKS and h.oldest_tick() == 6 and h.newest_tick() == 20 and h.at(20).pos.x == 20.0)
    _check("lag comp: a tick inside the ring returns that pose (tick 12 -> x %.0f, crouch %s)" % [h.at(12).pos.x, h.at(12).crouch],
        h.at(12).pos.x == 12.0 and h.at(12).crouch and is_equal_approx(h.at(12).yaw, 1.2))
    _check("lag comp: older than the ring clamps to the oldest, newer to the newest", h.at(2).tick == 6 and h.at(50).tick == 20)
    _check("lag comp: the rewind is capped at %d ticks (200 ms)" % NetHistory.MAX_REWIND_TICKS,
        NetHistory.rewind_tick(100, 130) == 118 and NetHistory.rewind_tick(125, 130) == 125 and NetHistory.rewind_tick(140, 130) == 130)
    # a rewound raycast: the dummy moved 4 m since the tick the shooter saw; rewinding puts the
    # hitbox back under the shot for the query, then restores it
    var d := TARGET_DUMMY.instantiate() as Character
    d.net_id = 77
    add_child(d)
    var shooter := TARGET_DUMMY.instantiate() as Character
    shooter.net_id = 2
    shooter.peer_id = 2
    add_child(shooter)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var saved_role: int = Net.role
    Net.role = Net.Role.HOST
    Net.tick = 1000
    Net.characters[77] = d
    Net.characters[2] = shooter
    d.global_position = Vector3(20, 0, 0)
    shooter.global_position = Vector3(20, 0, 8)
    await get_tree().physics_frame
    Net.history_for(d).record(990, Vector3(20, 0, 0), 0.0, false)   # where the client saw it
    d.global_position = Vector3(24, 0, 0)                            # where it is now
    Net.history_for(d).record(1000, d.global_position, 0.0, false)
    await get_tree().physics_frame
    var space := get_viewport().world_3d.direct_space_state
    var o := Vector3(20, 0.9, 8)
    var dir := Vector3(0, 0, -1)
    Net.tick = 1000   # the host clock keeps ticking while we await: pin it for the calls
    var now_hit := Net.rewound_raycast(shooter, o, dir, 30.0, 1000, space)   # view = now: no rewind
    Net.tick = 1000
    var past_hit := Net.rewound_raycast(shooter, o, dir, 30.0, 990, space)   # view 10 ticks ago
    _check("lag comp: judged at the current tick the shot at the old spot misses", now_hit.is_empty())
    _check("lag comp: rewound %d ticks the same ray hits the toy where the client saw it (z %.1f)" % [Net.last_rewind_ticks, past_hit.position.z if past_hit else 99.0],
        Net.last_rewind_ticks == 10 and not past_hit.is_empty() and past_hit.collider == d and past_hit.shape == 0 and absf(past_hit.position.z - 0.3) < 0.05)
    var head := Net.rewound_raycast(shooter, Vector3(20, 1.4, 8), dir, 30.0, 990, space)
    _check("lag comp: a ray at head height reports the head shape (shape %d)" % (head.shape if head else -1), head and head.shape == Character.HEAD_SHAPE_INDEX)
    _check("lag comp: the toy itself never moved (x %.0f)" % d.global_position.x, d.global_position.x == 24.0)
    Net.tick = 1000
    Net.rewound_raycast(shooter, o, dir, 30.0, 900, space)
    _check("lag comp: a view further back than 200 ms is clamped (%d ticks)" % Net.last_rewind_ticks, Net.last_rewind_ticks == NetHistory.MAX_REWIND_TICKS)
    # world geometry still blocks a rewound shot: a wall between shooter and the past spot
    var wall := StaticBody3D.new()
    wall.collision_layer = Character.LAYER_WORLD
    var ws := CollisionShape3D.new()
    var wb := BoxShape3D.new()
    wb.size = Vector3(4, 4, 0.5)
    ws.shape = wb
    wall.add_child(ws)
    add_child(wall)
    wall.global_position = Vector3(20, 1, 4)
    await get_tree().physics_frame
    await get_tree().physics_frame
    Net.tick = 1000
    var blocked := Net.rewound_raycast(shooter, o, dir, 30.0, 990, space)
    _check("lag comp: a wall in front still blocks the rewound shot (hit %s)" % (blocked.collider.get_class() if blocked else "nothing"),
        blocked and blocked.collider == wall)
    wall.queue_free()
    Net.characters.clear()
    Net._histories.clear()
    Net.role = saved_role
    Net.tick = 0
    d.queue_free()
    shooter.queue_free()
    await get_tree().process_frame


# ---- practice scene: weapons against a dummy ------------------------------------

func _test_practice_scene() -> void:
    Game.mode = "practice"
    var arena_scene := load(ARENA) as PackedScene
    _check("arena scene loads", arena_scene != null)
    if arena_scene == null:
        return
    var arena: Node3D = arena_scene.instantiate()
    add_child(arena)
    await get_tree().process_frame
    _check("arena built > 20 static bodies", arena.box_count > 20)
    _check("navmesh baked (%d polys)" % arena.navmesh_polys, arena.navmesh_polys > 20)
    _check("arena spawned dummies", get_tree().get_nodes_in_group("characters").size() >= 4)
    var player: Character = arena.local_player()
    _check("arena has a local player with a controller", player != null and player.controller is PlayerController)
    if player == null:
        return
    player.controller.input_enabled = false
    await get_tree().process_frame
    _check("figure rig loaded (skeleton + tree)", player.figure.ready_ok and player.figure.skeleton != null and player.figure.tree.active)
    _check("figure hand grip exists", player.figure.grip != null and player.figure.grip.get_child_count() == 7)
    _check("figure materials toonified", player.figure.mats.size() >= 4)
    _check("running anim loops", player.figure.anim_player.get_animation("Running_A").loop_mode == Animation.LOOP_LINEAR)
    _check("muzzle comes from the held weapon", player.muzzle_position().distance_to(player.global_position) < 2.5)

    _check("spawns on rifle (slot 2)", player.arsenal.slot == 2)
    player.arsenal.select(1)
    _check("melee grants double jump", player.max_jumps() == 2)
    player.arsenal.select(5)
    _check("previous slot tracked for Q", player.arsenal.previous_slot == 1)
    player.arsenal.select(9)
    _check("invalid slot ignored", player.arsenal.slot == 5)
    for i in 60:
        await get_tree().physics_frame
    _check("player settles on the floor", player.is_on_floor())

    # a private dummy 9 m straight ahead
    var dummy := TARGET_DUMMY.instantiate() as Character
    dummy.position = player.global_position + Vector3(0, 0, -9)
    dummy.yaw = PI
    arena.add_child(dummy)
    for i in 30:
        await get_tree().physics_frame
    _check("dummy on floor", dummy.is_on_floor())

    # rifle: body then head
    player.arsenal.select(2)
    await _wait_swap(player)
    await _aim_at(player, dummy.center())
    var hp0 := dummy.hp
    var fx0: int = Vfx.pool_stats().reused + Vfx.pool_stats().created
    var nodes0 := Vfx.get_child_count()
    await _pull_trigger(player)
    _check("rifle body shot does 9 (%.1f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 9.0))
    var fx_used: int = Vfx.pool_stats().reused + Vfx.pool_stats().created - fx0
    _check("a shot uses pooled effects (+%d uses, +%d nodes)" % [fx_used, Vfx.get_child_count() - nodes0],
        fx_used >= 4 and Vfx.get_child_count() - nodes0 <= 2)
    await _aim_at(player, dummy.global_position + Vector3(0, 1.66, 0))
    hp0 = dummy.hp
    await _pull_trigger(player)
    _check("rifle headshot does 13.5 (%.1f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 13.5))
    _check("kill feed knows the weapon", dummy.last_hit_weapon == "Rifle")

    # shotgun: semi-auto, pellets converge with spread 0
    player.arsenal.select(3)
    await _wait_swap(player)
    await _aim_at(player, dummy.center())
    var clip0 := player.arsenal.current().clip
    hp0 = dummy.hp
    player.arsenal.trigger = true
    for i in 6:
        await get_tree().physics_frame
    player.arsenal.trigger = false
    _check("shotgun is semi-auto (clip %d -> %d)" % [clip0, player.arsenal.current().clip],
        player.arsenal.current().clip == clip0 - 1)
    _check("shotgun 8 pellets x 9 with mild falloff at 9 m (%.1f)" % (hp0 - dummy.hp),
        hp0 - dummy.hp >= 60.0 and hp0 - dummy.hp <= 72.0)

    # bazooka: direct hit + splash
    await _reset(dummy)
    player.arsenal.select(6)
    await _wait_swap(player)
    await _aim_at(player, dummy.center())
    await _pull_trigger(player)
    var waited := 0
    while dummy.hp == 100.0 and waited < 120:
        await get_tree().physics_frame
        waited += 1
    _check("rocket lands within 2 s (hp %.0f after %d frames)" % [dummy.hp, waited], dummy.hp < 100.0)
    _check("rocket direct hit nearly lethal (hp %.0f)" % dummy.hp, dummy.hp <= 15.0)

    # grenade fuse: a resting grenade next to the dummy
    await _reset(dummy)
    var g := Projectile.new()
    g.setup(WeaponDB.for_slot(7), player, Vector3.ZERO)
    arena.add_child(g)
    g.global_position = dummy.center() + Vector3(1.0, 0.3, 0)
    for i in 150:
        await get_tree().physics_frame
    _check("grenade fuse detonates (%s)" % ("freed" if not is_instance_valid(g) else "alive"),
        not is_instance_valid(g))
    _check("grenade splash hurts (hp %.0f)" % dummy.hp, dummy.hp < 100.0 and dummy.hp > 40.0)

    # melee light + heavy
    await _reset(dummy)
    player.arsenal.select(1)
    await _wait_swap(player)
    player.global_position = dummy.global_position + Vector3(0, 0, 1.3)
    await _aim_at(player, dummy.center())
    await _pull_trigger(player)
    _check("melee light hits for 20 (%.0f)" % (100.0 - dummy.hp), is_equal_approx(100.0 - dummy.hp, 20.0))
    for i in 60:
        await get_tree().physics_frame
    hp0 = dummy.hp
    await _hold(player, true)
    _check("melee heavy hits for 45 (%.0f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 45.0))

    # swap-cancel: leaving a weapon drops its recovery, so out-and-back beats the fire interval
    await _reset(dummy)
    player.global_position = dummy.global_position + Vector3(0, 0, 9)
    player.arsenal.select(3)
    await _wait_swap(player)
    await _aim_at(player, dummy.center())
    await _pull_trigger(player)
    var cd_before: float = player.arsenal.states[2].cooldown
    player.arsenal.select(1)
    var cd_after: float = player.arsenal.states[2].cooldown
    _check("swap-cancel drops the shotgun recovery (%.2f -> %.2f)" % [cd_before, cd_after], cd_before > 0.5 and cd_after == 0.0)
    player.arsenal.select(3)
    await _wait_swap(player)
    _check("shotgun fires again right after the draw", player.arsenal.current().ready_to_fire())

    # wave-step: a gun jump, then melee drawn mid-air grants the second jump
    player.arsenal.select(2)
    await _wait_swap(player)
    for i in 40:
        await get_tree().physics_frame
    _check("standing before the jump test", player.is_on_floor())
    player.jump_pressed = true
    for i in 3:
        await get_tree().physics_frame
    _check("gun jump leaves the floor, no jumps left", not player.is_on_floor() and player.jumps_left() == 0)
    player.arsenal.select(1)
    player.jump_pressed = true
    for i in 3:
        await get_tree().physics_frame
    _check("melee drawn mid-air grants a second jump (vy %.1f)" % player.velocity.y,
        player.velocity.y > 4.0 and player.jumps_left() == 0)
    for i in 90:
        await get_tree().physics_frame

    # sniper: unscoped body 55, scoped body = one-shot kill
    await _reset(dummy)
    player.arsenal.select(4)
    await _wait_swap(player)
    await _aim_at(player, dummy.center())
    await _pull_trigger(player)
    _check("unscoped sniper body hit does 55 (%.0f)" % (100.0 - dummy.hp), is_equal_approx(100.0 - dummy.hp, 55.0))
    await _reset(dummy)
    while not player.arsenal.current().ready_to_fire():   # the 1.5 s recovery of the last shot
        await get_tree().physics_frame
    player.arsenal.alt = true
    await get_tree().physics_frame
    await get_tree().physics_frame
    player.arsenal.alt = false
    await get_tree().physics_frame
    _check("RMB scopes in (level %d)" % player.arsenal.scope_level, player.arsenal.scope_level == 1 and player.arsenal.aiming)
    # a shot inside the 0.15 s scope settle is a hip shot (55), even though the scope is up
    await _aim_at(player, dummy.center())
    _check("sniper: still settling after scoping in (%.2f s)" % player.arsenal.scope_time, player.arsenal.scope_time < Arsenal.SCOPE_SETTLE)
    await _pull_trigger(player)
    _check("sniper: a shot during the settle does the unscoped 55 (%.0f)" % (100.0 - dummy.hp), is_equal_approx(100.0 - dummy.hp, 55.0))
    await _reset(dummy)
    for i in 12:
        await get_tree().physics_frame
    _check("sniper: settled after 0.15 s (%.2f s)" % player.arsenal.scope_time, player.arsenal.scope_time >= Arsenal.SCOPE_SETTLE)
    while not player.arsenal.current().ready_to_fire():
        await get_tree().physics_frame
    await _aim_at(player, dummy.center())
    await _pull_trigger(player)
    _check("scoped sniper body shot is a one-shot kill (hp %.0f)" % dummy.hp, not dummy.alive)
    # the sniper keeps its 1.5 s recovery through a swap (no recovery-cancel), unlike the shotgun
    var sniper_cd: float = player.arsenal.states[3].cooldown
    player.arsenal.select(1)
    _check("sniper: recovery survives a swap (%.2f -> %.2f)" % [sniper_cd, player.arsenal.states[3].cooldown],
        sniper_cd > 1.0 and player.arsenal.states[3].cooldown == sniper_cd)
    player.arsenal.select(4)
    await _wait_swap(player)
    # single zoom by default: RMB again scopes OUT; with the double-zoom setting it goes to 8x
    player.arsenal.alt = true
    await get_tree().physics_frame
    await get_tree().physics_frame
    player.arsenal.alt = false
    await get_tree().physics_frame
    player.arsenal.alt = true
    await get_tree().physics_frame
    await get_tree().physics_frame
    player.arsenal.alt = false
    await get_tree().physics_frame
    _check("sniper: single zoom by default (4x then off, level %d)" % player.arsenal.scope_level, player.arsenal.scope_level == 0)
    Game.sniper_double_zoom = true
    for i in 2:
        player.arsenal.alt = true
        await get_tree().physics_frame
        await get_tree().physics_frame
        player.arsenal.alt = false
        await get_tree().physics_frame
    _check("sniper: the double-zoom setting adds the 8x stage (level %d, fov %.0f)" % [player.arsenal.scope_level, player.arsenal.zoom_fov()],
        player.arsenal.scope_level == 2 and is_equal_approx(player.arsenal.zoom_fov(), 9.0))
    Game.sniper_double_zoom = false
    player.arsenal.scope_level = 0
    for i in 200:
        await get_tree().physics_frame

    # gatling: the spin drops to zero the tick the toy leaves the floor while firing
    player.arsenal.select(5)
    await _wait_swap(player)
    player.arsenal.trigger = true
    for i in 40:
        await get_tree().physics_frame
    var spin_before: float = player.arsenal.states[4].spin
    player.jump_pressed = true
    for i in 3:
        await get_tree().physics_frame
    var spin_after: float = player.arsenal.states[4].spin
    player.arsenal.trigger = false
    _check("gatling: spin resets when leaving the floor while firing (%.2f -> %.2f)" % [spin_before, spin_after],
        spin_before > 0.9 and spin_after < 0.15 and not player.is_on_floor())
    for i in 90:
        await get_tree().physics_frame

    # melee combo: horizontal 20, upward 20, overhead 30 (1.5x, knockback), then it resets; 0.8 s idle resets too
    await _reset(dummy)
    player.arsenal.select(1)
    await _wait_swap(player)
    player.global_position = dummy.global_position + Vector3(0, 0, 1.3)
    await _aim_at(player, dummy.center())
    var combo_dmg: Array = []
    for swing in 3:
        var before := dummy.hp
        await _pull_trigger(player)
        combo_dmg.append(before - dummy.hp)
        if swing < 2:
            for i in 20:
                await get_tree().physics_frame
            dummy.velocity = Vector3.ZERO
            dummy.global_position = dummy.spawn_home
            player.global_position = dummy.global_position + Vector3(0, 0, 1.3)
    _check("melee combo: 20, 20, then the overhead finisher 30 (%s)" % [combo_dmg],
        combo_dmg.size() == 3 and is_equal_approx(combo_dmg[0], 20.0) and is_equal_approx(combo_dmg[1], 20.0) and is_equal_approx(combo_dmg[2], 30.0))
    _check("melee combo: the finisher resets the chain (combo %d)" % player.arsenal.states[0].combo, player.arsenal.states[0].combo == 0)
    for i in 20:
        await get_tree().physics_frame
    await _reset(dummy)
    player.global_position = dummy.global_position + Vector3(0, 0, 1.3)
    await _pull_trigger(player)
    _check("melee combo: second chain starts at 1 (combo %d)" % player.arsenal.states[0].combo, player.arsenal.states[0].combo == 1)
    for i in 60:   # a second of idling
        await get_tree().physics_frame
    _check("melee combo: drops after 0.8 s idle (combo %d)" % player.arsenal.states[0].combo, player.arsenal.states[0].combo == 0)

    # radar rules: enemies show only within 6 m or for 1.5 s after firing; allies always
    var now := Time.get_ticks_msec()
    dummy.last_fire_msec = -100000
    dummy.global_position = player.global_position + Vector3(0, 0, -20)
    _check("radar: a silent enemy 20 m away is hidden", not HudRadarProbe.shows(player, dummy, now))
    dummy.last_fire_msec = now
    _check("radar: an enemy that just fired shows", HudRadarProbe.shows(player, dummy, now))
    _check("radar: ... and is hidden again 1.5 s later", not HudRadarProbe.shows(player, dummy, now + 1600))
    dummy.global_position = player.global_position + Vector3(0, 0, -4)
    _check("radar: an enemy within 6 m shows", HudRadarProbe.shows(player, dummy, now + 9999))
    player.team = 1
    dummy.team = 1
    dummy.global_position = player.global_position + Vector3(0, 0, -25)
    _check("radar: a teammate always shows", HudRadarProbe.shows(player, dummy, now + 9999))
    player.team = 0
    dummy.team = 0
    dummy.global_position = dummy.spawn_home

    # crouch (L-Ctrl): half speed, low capsule + head, no jump, stand up only with headroom
    await _reset(dummy)
    player.arsenal.select(2)
    await _wait_swap(player)
    player.global_position = Vector3(-2, 0.3, 10)   # an open lane along -x in the greybox
    for i in 30:
        await get_tree().physics_frame
    player.wish_dir = Vector3(-1, 0, 0)
    for i in 40:
        await get_tree().physics_frame
    var run_speed := Vector2(player.velocity.x, player.velocity.z).length()
    player.crouch_held = true
    for i in 40:
        await get_tree().physics_frame
    var crouch_speed := Vector2(player.velocity.x, player.velocity.z).length()
    var cap := player.get_node("Collision").shape as CapsuleShape3D
    _check("crouch: half speed (%.1f -> %.1f m/s)" % [run_speed, crouch_speed], player.crouching
        and absf(run_speed - 7.0) < 0.3 and absf(crouch_speed - 3.5) < 0.3)
    _check("crouch: capsule 1.15 -> %.2f, head hitbox %.2f -> %.2f, eye lowered" % [cap.height, 1.4, player.get_node("Head").position.y],
        is_equal_approx(cap.height, Character.CROUCH_HEIGHT) and player.get_node("Head").position.y < 1.2 and player.eye().y - player.global_position.y < 1.1)
    player.wish_dir = Vector3.ZERO
    player.jump_pressed = true
    for i in 3:
        await get_tree().physics_frame
    _check("crouch: no jump while crouched (vy %.1f)" % player.velocity.y, player.is_on_floor() and player.velocity.y <= 0.1)
    # a low ceiling 1.0 m above the floor: standing up must wait until we walk out from under it
    var lid: StaticBody3D = arena._box(player.global_position + Vector3(0, 1.5, 0), Vector3(3, 0.3, 3), Color.WHITE)
    for i in 3:
        await get_tree().physics_frame
    player.crouch_held = false
    for i in 10:
        await get_tree().physics_frame
    _check("crouch: stays crouched under a low ceiling (headroom %s)" % player.has_headroom(), player.crouching and not player.has_headroom())
    player.wish_dir = Vector3(-1, 0, 0)
    for i in 70:
        await get_tree().physics_frame
    player.wish_dir = Vector3.ZERO
    _check("crouch: stands up once clear of it (capsule %.2f)" % cap.height, not player.crouching and is_equal_approx(cap.height, Character.STAND_HEIGHT))
    lid.queue_free()
    for i in 30:
        await get_tree().physics_frame
    var hips_drop := player.figure.aim_modifier.crouch_drop
    _check("crouch: procedural hips drop is wired (%.2f model units)" % hips_drop, hips_drop > 0.3 and player.figure.aim_modifier.crouch_target == 0.0)

    # death + respawn through the match controller
    await _reset(dummy)
    var kills0 := player.kills
    dummy.take_damage(1000.0, player, dummy.center(), Vector3.ZERO, false)
    _check("dummy dies and credits the killer", not dummy.alive and player.kills == kills0 + 1)
    _check("death drops a health vial", get_tree().get_nodes_in_group("pickups").size() >= 1)
    for i in 215:
        await get_tree().physics_frame
    _check("dummy respawns at home with full hp",
        dummy.alive and dummy.hp == 100.0 and dummy.global_position.distance_to(dummy.spawn_home) < 0.6)

    arena.queue_free()
    await get_tree().process_frame


# ---- wave-step: the skill ceiling, frame-accurate at 60 Hz ------------------------------
## One airtime: shotgun shot, jump, (melee flick = swap-cancel) shotgun shot in the air, swap
## to melee, double jump mid-air, swap back, third shotgun shot, land. Swaps are quick and
## presses during a draw are buffered; the jump itself stays 9.5 / gravity 30 / 0.92x.

func _test_wave_step() -> void:
    Game.mode = "practice"
    var arena: Node3D = (load(ARENA) as PackedScene).instantiate()
    add_child(arena)
    await get_tree().process_frame
    var player: Character = arena.local_player()
    player.controller.input_enabled = false
    var dummy := TARGET_DUMMY.instantiate() as Character
    dummy.position = player.global_position + Vector3(0, 0, -6)
    dummy.yaw = PI
    arena.add_child(dummy)
    player.arsenal.select(3)
    for i in 60:
        await get_tree().physics_frame
    await _aim_at(player, dummy.center())
    _check("wave-step: standing with the shotgun up", player.is_on_floor() and player.arsenal.slot == 3
        and player.arsenal.swap_left == 0.0)
    var shots: Array = []          # [frame, airborne, height]
    var frame := [0]
    var on_fire := func(d: WeaponData) -> void:
        if d.slot == 3:
            shots.append([frame[0], not player.is_on_floor(), player.global_position.y])
    player.arsenal.fired.connect(on_fire)

    # F0 fire, F1 jump, F2 melee (swap-cancel), F6 shotgun (draw 0.25 s = 15 ticks, up at F21),
    # F18 fire (during the draw: buffered), F22 melee, F24 jump (double jump during the melee
    # draw), F26 shotgun (up at F41), F38 fire (buffered)
    var script := {0: "fire", 1: "jump", 2: "sel1", 6: "sel3", 18: "fire", 22: "sel1", 24: "jump", 26: "sel3", 38: "fire"}
    var floor_frames: Array[int] = []
    var vy_after_double := 0.0
    var landed := -1
    # inputs set after the await are processed by the step that runs at the next await, so the
    # state seen right after a resume is the result of step f-1
    for f in 120:
        await get_tree().physics_frame
        if f == 25:
            vy_after_double = player.velocity.y
        if f >= 2 and player.is_on_floor():
            floor_frames.append(f - 1)   # the step that ended on the floor
            if landed < 0:
                landed = f - 1
        frame[0] = f
        player.arsenal.trigger = false
        match script.get(f, ""):
            "fire":
                player.arsenal.trigger = true
            "jump":
                player.jump_pressed = true
            "sel1":
                player.arsenal.select(1)
            "sel3":
                player.arsenal.select(3)
        if landed >= 0 and f > landed + 3:
            break
    player.arsenal.fired.disconnect(on_fire)
    var shot_frames := PackedStringArray()
    for sh in shots:
        shot_frames.append("F%d%s@%.2fm" % [sh[0], " air" if sh[1] else " ground", sh[2]])
    var summary := "shots %s, landed F%d" % [", ".join(shot_frames), landed]
    _check("wave-step: three shotgun shots in one airtime (%s)" % summary, shots.size() == 3 and landed > 0
        and not shots[0][1] and shots[1][1] and shots[2][1] and shots[2][0] < landed)
    var touched_between := false
    for ff in floor_frames:
        if ff >= 2 and shots.size() == 3 and ff <= shots[2][0]:
            touched_between = true
    _check("wave-step: feet never touch the floor between the jump and the third shot", not touched_between)
    _check("wave-step: double jump fires during the melee draw (vy %.1f)" % vy_after_double, vy_after_double > 8.0)
    _check("wave-step: honest airtime (%d ticks, no float)" % landed, landed >= 55 and landed <= 78)
    _check("wave-step: buffered shots leave the draw the tick it completes (F%d, F%d)" % [
        shots[1][0] if shots.size() > 1 else -1, shots[2][0] if shots.size() > 2 else -1],
        shots.size() == 3 and shots[1][0] >= 20 and shots[1][0] <= 22 and shots[2][0] >= 40 and shots[2][0] <= 42)

    # jump pressed with no jumps left, then melee selected: the press still counts (short buffer)
    for i in 60:
        await get_tree().physics_frame
    player.arsenal.select(3)
    await _wait_swap(player)
    for i in 10:
        await get_tree().physics_frame
    player.jump_pressed = true
    for i in 8:
        await get_tree().physics_frame
    _check("jump buffer: airborne with the shotgun, no jumps left", not player.is_on_floor() and player.jumps_left() == 0)
    player.jump_pressed = true          # nothing available yet: remembered
    await get_tree().physics_frame
    await get_tree().physics_frame
    var vy_before := player.velocity.y
    player.arsenal.select(1)            # melee comes out: the buffered press fires the double jump
    await get_tree().physics_frame
    await get_tree().physics_frame
    _check("jump buffer: press just before melee is out still double-jumps (vy %.1f -> %.1f)" % [vy_before, player.velocity.y],
        player.velocity.y > vy_before + 2.5 and player.jumps_left() == 0)
    for i in 90:
        await get_tree().physics_frame

    # alt pressed during the sniper draw: scoped the tick the rifle comes up (quickscope buffer)
    player.arsenal.select(2)
    await _wait_swap(player)
    player.arsenal.select(4)
    await get_tree().physics_frame
    player.arsenal.alt = true
    await get_tree().physics_frame
    player.arsenal.alt = false
    _check("alt buffer: press early in the sniper draw is remembered (level %d, draw %.2f left)" % [
        player.arsenal.scope_level, player.arsenal.swap_left], player.arsenal.scope_level == 0 and player.arsenal.swap_left > 0.12)
    await _wait_swap(player)
    await get_tree().physics_frame
    await get_tree().physics_frame
    _check("alt buffer: scoped the tick the draw completes (level %d)" % player.arsenal.scope_level, player.arsenal.scope_level == 1)
    player.arsenal.scope_level = 0

    # fire pressed during a draw, then a retarget to another weapon: the press belongs to the old draw
    player.arsenal.select(2)
    await _wait_swap(player)
    player.arsenal.select(3)
    await get_tree().physics_frame
    player.arsenal.trigger = true
    await get_tree().physics_frame
    player.arsenal.trigger = false
    player.arsenal.select(2)
    var clip_before: int = player.arsenal.current().clip
    await _wait_swap(player)
    for i in 3:
        await get_tree().physics_frame
    _check("select mid-draw retargets and drops the buffered press (rifle clip %d)" % player.arsenal.current().clip,
        player.arsenal.slot == 2 and player.arsenal.current().clip == clip_before)
    arena.queue_free()
    await get_tree().process_frame


# ---- ffa match: bots, vials, scoring --------------------------------------------

func _test_match() -> void:
    Game.mode = "ffa"
    Game.bot_count = 2
    Game.bot_difficulty = "hard"
    var arena: Node3D = (load(ARENA) as PackedScene).instantiate()
    add_child(arena)
    await get_tree().process_frame
    Game.bot_difficulty = "normal"
    var player: Character = arena.local_player()
    player.controller.input_enabled = false
    var m := arena.get_node("Match") as MatchController
    var bots := get_tree().get_nodes_in_group("bots")
    _check("2 bots spawned", bots.size() == 2)
    var hard: bool = bots.size() == 2 and bots[0].skill >= 0.78 and bots[1].skill >= 0.78
    _check("hard difficulty gives hard skills (%.2f, %.2f)" % [bots[0].skill, bots[1].skill], hard)
    _check("match is FFA to 20", m.mode == "ffa" and m.score_limit == 20)
    if bots.size() < 2:
        arena.queue_free()
        return
    var starts: Array[Vector3] = []
    for b in bots:
        starts.append(b.global_position)
    for i in 300:
        await get_tree().physics_frame
    var moved := 0
    var fired := 0
    for i in bots.size():
        if bots[i].global_position.distance_to(starts[i]) > 1.0:
            moved += 1
        fired += bots[i].shots_fired
    _check("bots move around (%d/2)" % moved, moved >= 1)
    _check("bots fire at enemies (%d shots)" % fired, fired > 0)
    _check("status line reports FFA", m.status_line(player).begins_with("FFA"))

    # health vial heals (bots frozen so nobody interferes)
    Game.match_active = false
    var bot := bots[0] as Character
    await _reset(bot)
    bot.hp = 40.0
    var vial := HealthVial.new()
    arena.add_child(vial)
    vial.global_position = bot.global_position
    for i in 12:
        await get_tree().physics_frame
    _check("vial heals +30 (hp %.0f)" % bot.hp, is_equal_approx(bot.hp, 70.0) and not is_instance_valid(vial))

    # scoring + end + restart (bots may already have kills from the warm-up: clear the board)
    Game.match_active = true
    for c in m.contestants():
        c.kills = 0
    m.score_limit = 1
    var ended := [false]
    m.match_ended.connect(func(_t: String, _w: Character) -> void: ended[0] = true)
    bot.take_damage(1000.0, player, bot.center(), Vector3.ZERO, false)
    _check("reaching the limit ends the match (%s)" % m.winner_text,
        ended[0] and not Game.match_active and m.winner == player and m.winner_text == "YOU WINS")
    m.restart()
    _check("restart resets scores and revives", Game.match_active and player.kills == 0 and bot.alive)

    arena.queue_free()
    await get_tree().process_frame


# ---- toy room map: loads, collides, bakes ---------------------------------------

func _test_toy_room() -> void:
    for key in Game.MAPS:
        await _test_map(key, Game.MAPS[key].scene)


func _test_map(key: String, path: String) -> void:
    Game.mode = "ffa"
    Game.bot_count = 3
    var scene := load(path) as PackedScene
    _check("%s scene loads" % key, scene != null)
    if scene == null:
        return
    var room: Node3D = scene.instantiate()
    add_child(room)
    await get_tree().process_frame
    _check("%s placed > 40 colliders (%d)" % [key, room.box_count], room.box_count > 40)
    _check("%s navmesh baked (%d polys)" % [key, room.navmesh_polys], room.navmesh_polys > 80)
    _check("%s has 8 spawns, ctb layout, capsules" % key, room.spawns.size() >= 8 and room.base_positions.size() == 2
        and room.battery_spawns.size() >= 1 and room.capsule_spawns.size() >= 4)
    var player: Character = room.local_player()
    player.controller.input_enabled = false
    Game.match_active = false        # bots must not shoot the player into a respawn mid-test
    for i in 90:
        await get_tree().physics_frame
    _check("%s: player stands on the floor" % key, player.is_on_floor() and player.global_position.y > -0.5)
    # every spawn, battery, base and capsule spot must be clear floor (no launch out of furniture)
    var bad := PackedStringArray()
    var spots: Array = []
    spots.append_array(room.spawns)
    spots.append_array(room.battery_spawns)
    for t in room.base_positions:
        spots.append(room.base_positions[t])
    for c in room.capsule_spawns:
        spots.append(c[0])
    player.collision_mask = Character.LAYER_WORLD   # a wandering bot on the spot must not launch us
    for p in spots:
        player.velocity = Vector3.ZERO
        player.global_position = p
        for i in 25:
            await get_tree().physics_frame
        var moved: Vector3 = player.global_position - p
        moved.y = maxf(0.0, moved.y)   # settling down onto a top is fine
        if moved.length() > 0.8:
            bad.append("%s->%s" % [p, player.global_position])
    player.collision_mask = Character.LAYER_WORLD | Character.LAYER_CHARACTER
    Game.match_active = true
    _check("%s: %d spots are clear (%s)" % [key, spots.size(), ", ".join(bad) if not bad.is_empty() else "ok"], bad.is_empty())
    var bots := get_tree().get_nodes_in_group("bots")
    var grounded := 0
    for b in bots:
        if b.global_position.y > -0.5 and b.global_position.y < 9.0:
            grounded += 1
    _check("%s: bots stay inside (%d/%d)" % [key, grounded, bots.size()], grounded == bots.size())
    room.queue_free()
    await get_tree().process_frame


# ---- capture the battery + item capsules --------------------------------------------

func _test_ctb() -> void:
    Game.mode = "ctb"
    Game.bot_count = 2
    var room: Node3D = (load("res://src/world/toy_room.tscn") as PackedScene).instantiate()
    add_child(room)
    await get_tree().process_frame
    var player: Character = room.local_player()
    player.controller.input_enabled = false
    var m := room.get_node("Match") as MatchController
    Game.match_active = false   # freeze bots while we drive the player
    await get_tree().physics_frame
    var batteries := get_tree().get_nodes_in_group("batteries")
    var bases := get_tree().get_nodes_in_group("battery_bases")
    var capsules := get_tree().get_nodes_in_group("capsules")
    _check("ctb: 3 batteries, 2 bases, capsules placed (%d/%d/%d)" % [batteries.size(), bases.size(), capsules.size()],
        batteries.size() == 3 and bases.size() == 2 and capsules.size() >= 5)
    _check("ctb: player is red and bots split by team", player.team == 1 and m.mode == "ctb" and m.score_limit == 5)
    var blue_on_north := true
    for b in get_tree().get_nodes_in_group("bots"):
        if b.team == 2 and b.global_position.z > 0.0:
            blue_on_north = false
    _check("ctb: blue bots start on the blue half", blue_on_north)
    Game.match_active = true
    # walk onto the west battery
    var cell := batteries[1] as Battery
    player.global_position = cell.global_position + Vector3(0, 0.05, 0)
    for i in 4:
        await get_tree().physics_frame
    _check("ctb: stepping on a battery picks it up", player.carrying == cell and not cell.is_loose() and cell.get_parent() == player.battery_mount)
    _check("ctb: carrier runs slower", is_equal_approx(player.run_speed * (0.9), 6.3))
    var loose := m.loose_batteries().size()
    _check("ctb: 2 loose batteries remain (%d)" % loose, loose == 2)
    # deliver to the red pad
    player.global_position = m.base_positions[1] + Vector3(0, 0.3, 0)
    for i in 4:
        await get_tree().physics_frame
    _check("ctb: charging at the red pad scores (red %d)" % m.team_score(1), m.team_score(1) == 1 and player.captures == 1)
    _check("ctb: battery returns home after a charge", player.carrying == null and cell.is_loose() and cell.global_position.distance_to(cell.home) < 0.5)
    _check("ctb: status line shows the score", m.status_line(player).begins_with("BATTERY  RED 1"))
    # a dying carrier drops the cell where they fell
    player.global_position = cell.global_position + Vector3(0, 0.05, 0)
    for i in 4:
        await get_tree().physics_frame
    var drop_spot := Vector3(-8, 0.3, 0)
    player.global_position = drop_spot
    await get_tree().physics_frame
    player.take_damage(1000.0, null, player.center(), Vector3.ZERO, false)
    await get_tree().physics_frame
    await get_tree().physics_frame
    _check("ctb: death drops the battery on the spot", player.carrying == null and cell.is_loose() and cell.global_position.distance_to(drop_spot) < 1.0)
    # health capsule heals, ammo capsule tops up reserves, both vanish then respawn
    for v in get_tree().get_nodes_in_group("pickups"):
        if v is HealthVial:
            v.queue_free()   # the death just dropped one under the player
    await get_tree().physics_frame
    player.alive = true
    player.collision_layer = Character.LAYER_CHARACTER
    player.hp = 50.0
    var health_cap: ItemCapsule = null
    var ammo_cap: ItemCapsule = null
    for c in capsules:
        if c.kind == "health" and health_cap == null:
            health_cap = c
        if c.kind == "ammo" and ammo_cap == null:
            ammo_cap = c
    player.global_position = health_cap.global_position + Vector3(0, 0.05, 0)
    for i in 4:
        await get_tree().physics_frame
    _check("capsule: health +35 (hp %.0f) and it vanishes" % player.hp, is_equal_approx(player.hp, 85.0) and not health_cap.is_available())
    player.arsenal.states[1].reserve = 10
    player.global_position = ammo_cap.global_position + Vector3(0, 0.05, 0)
    for i in 4:
        await get_tree().physics_frame
    _check("capsule: ammo tops up the rifle reserve (%d)" % player.arsenal.states[1].reserve, player.arsenal.states[1].reserve == 51 and not ammo_cap.is_available())
    room.queue_free()
    await get_tree().process_frame


# ---- Lalu's birthday room: props, guests, zones, finale + reset, network mirror -----------

func _test_party() -> void:
    Game.mode = "party"
    Game.bot_count = 5
    var room: Node3D = (load("res://src/world/lalu_party.tscn") as PackedScene).instantiate()
    add_child(room)
    await get_tree().process_frame
    var party := room.get_node("Party") as PartyManager
    var player: Character = room.local_player()
    player.controller.input_enabled = false
    _check("party: 12 candles, 30 balloons, 5 gifts, a pinata, 4 cannons", party.candles.size() == 12
        and party.balloons.size() == 30 and party.gifts.size() == 5 and party.pinata != null and party.cannons.size() == 4)
    var bots := get_tree().get_nodes_in_group("bots")
    var guests := 0
    var hats := 0
    for b in bots:
        if b.party_guest and b.display_name in PartyText.GUESTS:
            guests += 1
        if b.figure.hat != null and is_instance_valid(b.figure.hat):
            hats += 1
    _check("party: 5 guests with party names (%d) and hats (%d)" % [guests, hats], guests == 5 and hats == 5)
    for i in 30:
        await get_tree().physics_frame
    var hat_ok := player.figure.hat != null and is_instance_valid(player.figure.hat)
    var hat_dy := player.figure.hat.global_position.y - player.global_position.y if hat_ok else -1.0
    _check("party: the player's hat sits on the head (%.2f m up)" % hat_dy, hat_ok and hat_dy > 1.3 and hat_dy < 2.2)
    _check("party: status line is the checklist", party.status_line().begins_with("PARTY   candles 0/12"))

    # a guest shot: no damage, a hop and a cheer
    var guest := bots[0] as Bot
    var vy0 := guest.velocity.y
    var r := guest.take_damage(50.0, player, guest.center(), Vector3.ZERO, false)
    _check("party: shooting a guest never hurts (hp %.0f), it hops (vy %.1f -> %.1f)" % [guest.hp, vy0, guest.velocity.y],
        r.applied and not r.killed and guest.hp == 100.0 and guest.velocity.y >= Character.PARTY_HOP - 0.01)

    # candle: on_shot blows it out
    var c0 := party.candles[0]
    c0.on_shot(player, c0.flame_position(), Vector3.FORWARD, null)
    _check("party: a shot candle goes out (candles %d/12)" % party.counts().candles, not c0.lit and party.counts().candles == 1)
    # balloon: a real rifle shot through the shootable hook
    var b0 := party.balloons[0]
    player.velocity = Vector3.ZERO
    player.global_position = b0.global_position + Vector3(0, -b0.height, 6.0)
    for i in 20:
        await get_tree().physics_frame
    player.arsenal.select(2)
    await _wait_swap(player)
    await _aim_at(player, b0.global_position)
    await _pull_trigger(player)
    _check("party: a rifle shot pops a balloon (balloons %d/30)" % party.counts().balloons, b0.is_popped and party.counts().balloons == 1)
    # pinata: ten hits burst it into candy + capsules
    var p := party.pinata
    for i in 4:
        p.on_shot(player, p.body_position(), Vector3(1, 0, 0), null)
    _check("party: pinata swings after hits (hits %d, tilt vel %.2f)" % [p.hits, p._vel.length()], p.hits == 4 and not p.is_burst and p._vel.length() > 0.5)
    for i in 6:
        p.on_shot(player, p.body_position(), Vector3(0, 0, 1), null)
    await get_tree().physics_frame
    var candy := 0
    for node in room.get_children():
        if node is RigidBody3D:
            candy += 1
    var caps := 0
    for node in get_tree().get_nodes_in_group("capsules"):
        if node.net_index >= PartyManager.PINATA_CAPSULE_BASE:
            caps += 1
    _check("party: 10 hits burst the pinata into %d candy cubes + %d capsules" % [candy, caps], p.is_burst and candy == PartyPinata.CANDY and caps == 4)
    # gifts: every surprise comes out; the puppy follows
    for g in party.gifts:
        g.open_by(player, true)
    await get_tree().physics_frame
    var kinds_ok := true
    for g in party.gifts:
        if not g.is_open or g.surprise == null:
            kinds_ok = false
    _check("party: all five gifts open with a surprise (gifts %d/5)" % party.counts().gifts, kinds_ok and party.counts().gifts == 5)
    var puppy := get_tree().get_first_node_in_group("puppies") as PartyPuppy
    _check("party: the puppy gift spawns a puppy that belongs to the opener", puppy != null and puppy.owner_character == player)
    player.global_position = Vector3(4, 0.3, 14)
    for i in 240:
        await get_tree().physics_frame
    var pd := puppy.global_position.distance_to(player.global_position) if puppy != null else 99.0
    _check("party: the puppy runs after her (travelled %.1f m, now %.1f m away)" % [puppy.travelled if puppy else 0.0, pd],
        puppy != null and puppy.travelled > 3.0 and pd < 5.0)

    # zones: bouncy castle super jump, moon low gravity
    player.velocity = Vector3.ZERO
    player.global_position = Vector3(17, 0.85, -17)
    for i in 30:
        await get_tree().physics_frame
    _check("party: bouncy castle = super jump (x%.1f, bounce %s, standing %s)" % [player.zone_jump_mult, player.zone_bounce, player.is_on_floor()],
        player.zone_jump_mult == 2.0 and player.zone_bounce and player.is_on_floor())
    player.jump_pressed = true
    await get_tree().physics_frame
    await get_tree().physics_frame
    _check("party: castle jump launches at 2x (vy %.1f)" % player.velocity.y, player.velocity.y > 17.0)
    var bounced := false
    for i in 150:
        await get_tree().physics_frame
        if player.is_on_floor():
            await get_tree().physics_frame
            await get_tree().physics_frame
            bounced = player.velocity.y > 4.0
            break
    _check("party: landing in the castle bounces you back up (vy %.1f)" % player.velocity.y, bounced)
    player.velocity = Vector3.ZERO
    player.global_position = Vector3(-17, 0.8, -17)
    for i in 8:
        await get_tree().physics_frame
    _check("party: moon corner = low gravity (x%.2f)" % player.zone_gravity_mult, is_equal_approx(player.zone_gravity_mult, 0.3) and not player.zone_bounce)
    player.global_position = Vector3(0, 0.3, 20)
    for i in 8:
        await get_tree().physics_frame
    _check("party: leaving the zones restores normal movement", player.zone_gravity_mult == 1.0 and player.zone_jump_mult == 1.0 and player.zone_push == Vector3.ZERO)

    # network mirror: remote events + the late-joiner state list
    party.apply_remote("candle", 3, 0, null, Vector3.ZERO)
    party.apply_remote("balloon", 5, 1, null, Vector3.ZERO)
    var states := party.remote_states()
    var has_c3 := false
    var has_b5 := false
    for s in states:
        if s[0] == "candle" and s[1] == 3:
            has_c3 = true
        if s[0] == "balloon" and s[1] == 5:
            has_b5 = true
    _check("party: remote events apply and the late-joiner list carries them (%d entries)" % states.size(),
        not party.candles[3].lit and party.balloons[5].is_popped and has_c3 and has_b5 and states.size() >= 9)

    # finale: finish the checklist -> fireworks, cheering, then everything resets
    party.finale_seconds = 2.5
    var started := [0]
    var resets := [0]
    party.finale_started.connect(func() -> void: started[0] += 1)
    party.reset_done.connect(func() -> void: resets[0] += 1)
    for c in party.candles:
        if c.lit:
            c.on_shot(player, c.flame_position(), Vector3.FORWARD, null)
    for b in party.balloons:
        if not b.is_popped:
            b.on_shot(player, b.global_position, Vector3.FORWARD, null)
    _check("party: completing the checklist starts the finale (done=%s)" % party.counts().done, party.counts().done and started[0] == 1 and party.finale_active)
    var cheering := 0
    for b in bots:
        if b._dance_left > 1.0:
            cheering += 1
    _check("party: every guest cheers in the finale (%d/5)" % cheering, cheering == 5)
    _check("party: the camera orbits the cake", player.controller.cinematic_active())
    for i in 30:
        await get_tree().physics_frame
    _check("party: fireworks and confetti fly (%d fireworks, %d bursts)" % [party.fx.stats.fireworks, party.fx.stats.confetti],
        party.fx.stats.fireworks >= 1 and party.fx.stats.confetti >= 3)
    for i in 200:
        await get_tree().physics_frame
    var after := party.counts()
    _check("party: the party resets itself for another round (candles %d, balloons %d, pinata %s, gifts %d)" % [after.candles, after.balloons, after.pinata, after.gifts],
        resets[0] == 1 and not party.finale_active and after.candles == 0 and after.balloons == 0 and not after.pinata and after.gifts == 0
        and get_tree().get_nodes_in_group("puppies").is_empty())
    room.queue_free()
    await get_tree().process_frame


# ---- elimination rounds ------------------------------------------------------------

func _test_elimination() -> void:
    Game.mode = "elim"
    Game.bot_count = 2
    var arena: Node3D = (load(ARENA) as PackedScene).instantiate()
    add_child(arena)
    await get_tree().process_frame
    var player: Character = arena.local_player()
    player.controller.input_enabled = false
    var m := arena.get_node("Match") as MatchController
    _check("elimination round 1 active", m.mode == "elim" and m.round_active and m.round_number == 1)
    Game.match_active = false   # freeze bots
    await get_tree().physics_frame
    Game.match_active = true
    var bots := get_tree().get_nodes_in_group("bots")
    var rounds := [0]
    m.round_ended.connect(func(_t: String, _w: Character) -> void: rounds[0] += 1)
    for b in bots:
        b.take_damage(1000.0, player, b.center(), Vector3.ZERO, false)
    _check("last toy standing ends the round", rounds[0] == 1 and player.rounds_won == 1 and not m.round_active)
    _check("no respawn timer in elimination", bots[0].respawn_at_msec == 0)
    for i in 220:
        await get_tree().physics_frame
    _check("round 2 starts with everyone alive", m.round_number == 2 and m.round_active and bots[0].alive and bots[1].alive)
    arena.queue_free()
    await get_tree().process_frame


# ---- helpers -------------------------------------------------------------------

func _reset(c: Character) -> void:
    c.hp = 100.0
    c.alive = true
    c.protection_left = 0.0
    c.collision_layer = Character.LAYER_CHARACTER
    c.visible = true
    c.velocity = Vector3.ZERO
    c.global_position = c.spawn_home
    for i in 30:  # let knockback / respawn motion settle
        await get_tree().physics_frame


func _aim_at(player: Character, target: Vector3) -> void:
    for i in 3:
        player.controller._recoil = 0.0
        var cam: Vector3 = player.controller.camera.global_position
        var dir := (target - cam).normalized()
        player.yaw = atan2(-dir.x, -dir.z)
        player.pitch = asin(clampf(dir.y, -1.0, 1.0))
        await get_tree().physics_frame
        await get_tree().process_frame


func _wait_swap(player: Character) -> void:
    while player.arsenal.swap_left > 0.0:
        await get_tree().physics_frame


## Hold a button across a full physics step. `physics_frame` fires *before* nodes process,
## so a value set after an idle-frame await must survive two signals to be seen.
func _hold(player: Character, alt: bool) -> void:
    var guard := 0
    while not player.arsenal.current().ready_to_fire() and guard < 300:
        await get_tree().physics_frame
        guard += 1
    if alt:
        player.arsenal.alt = true
    else:
        player.arsenal.trigger = true
    await get_tree().physics_frame
    await get_tree().physics_frame
    player.arsenal.alt = false
    player.arsenal.trigger = false
    await get_tree().physics_frame


func _pull_trigger(player: Character) -> void:
    await _hold(player, false)
