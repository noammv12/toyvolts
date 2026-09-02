extends Node
## Headless smoke + logic tests. Runs as a scene so autoloads exist before anything compiles.
## Run: tools/test.sh   (exit code 0 = green)

const ARENA := "res://src/world/arena_greybox.tscn"
const TARGET_DUMMY: PackedScene = preload("res://src/world/target_dummy.tscn")

var _fails := 0
var _count := 0


func _ready() -> void:
    Arsenal.spread_scale = 0.0
    _test_weapon_state()
    await _test_practice_scene()
    await _test_match()
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
    var player := arena.get_node_or_null("Player") as Player
    _check("arena has Player", player != null)
    if player == null:
        return
    player.input_enabled = false

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
    await _pull_trigger(player)
    _check("rifle body shot does 9 (%.1f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 9.0))
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


# ---- ffa match: bots, vials, scoring --------------------------------------------

func _test_match() -> void:
    Game.mode = "ffa"
    Game.bot_count = 2
    var arena: Node3D = (load(ARENA) as PackedScene).instantiate()
    add_child(arena)
    await get_tree().process_frame
    var player := arena.get_node("Player") as Player
    player.input_enabled = false
    var m := arena.get_node("Match") as MatchController
    var bots := get_tree().get_nodes_in_group("bots")
    _check("2 bots spawned", bots.size() == 2)
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

    # scoring + end + restart
    Game.match_active = true
    m.score_limit = 1
    var ended := [false]
    m.match_ended.connect(func(_t: String) -> void: ended[0] = true)
    bot.take_damage(1000.0, player, bot.center(), Vector3.ZERO, false)
    _check("reaching the limit ends the match (%s)" % m.winner_text,
        ended[0] and not Game.match_active and m.winner_text == "YOU WIN")
    m.restart()
    _check("restart resets scores and revives", Game.match_active and player.kills == 0 and bot.alive)

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


func _aim_at(player: Player, target: Vector3) -> void:
    for i in 3:
        player._recoil = 0.0
        var cam: Vector3 = player.camera.global_position
        var dir := (target - cam).normalized()
        player.yaw = atan2(-dir.x, -dir.z)
        player.pitch = asin(clampf(dir.y, -1.0, 1.0))
        await get_tree().physics_frame
        await get_tree().process_frame


func _wait_swap(player: Player) -> void:
    while player.arsenal.swap_left > 0.0:
        await get_tree().physics_frame


## Hold a button across a full physics step. `physics_frame` fires *before* nodes process,
## so a value set after an idle-frame await must survive two signals to be seen.
func _hold(player: Player, alt: bool) -> void:
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


func _pull_trigger(player: Player) -> void:
    await _hold(player, false)
