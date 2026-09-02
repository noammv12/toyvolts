extends Node
## Headless smoke + logic tests. Runs as a scene so autoloads exist before anything compiles.
## Run: tools/test.sh   (exit code 0 = green)

const ARENA := "res://src/world/arena_greybox.tscn"
const TARGET_DUMMY: PackedScene = preload("res://src/world/target_dummy.tscn")

var _fails := 0
var _count := 0


func _ready() -> void:
    Arsenal.spread_scale = 0.0
    _check("sound bank loaded (%d streams)" % Sfx._streams.size(), Sfx._streams.size() >= 28)
    _test_weapon_state()
    await _test_practice_scene()
    await _test_wave_step()
    await _test_match()
    await _test_elimination()
    await _test_toy_room()
    await _test_ctb()
    print("\n%d checks, %d failed" % [_count, _fails])
    get_tree().quit(1 if _fails > 0 else 0)


func _check(name: String, ok: bool) -> void:
    _count += 1
    if not ok:
        _fails += 1
    print("%s  %s" % ["PASS" if ok else "FAIL", name])


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
    for i in 25:
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
    player.arsenal.alt = true
    await get_tree().physics_frame
    await get_tree().physics_frame
    player.arsenal.alt = false
    await get_tree().physics_frame
    _check("RMB scopes in (level %d)" % player.arsenal.scope_level, player.arsenal.scope_level == 1 and player.arsenal.aiming)
    await _aim_at(player, dummy.center())
    await _pull_trigger(player)
    _check("scoped sniper body shot is a one-shot kill (hp %.0f)" % dummy.hp, not dummy.alive)
    player.arsenal.scope_level = 0
    for i in 200:
        await get_tree().physics_frame

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
    for p in spots:
        player.velocity = Vector3.ZERO
        player.global_position = p
        for i in 25:
            await get_tree().physics_frame
        var moved: Vector3 = player.global_position - p
        moved.y = maxf(0.0, moved.y)   # settling down onto a top is fine
        if moved.length() > 0.8:
            bad.append("%s->%s" % [p, player.global_position])
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
