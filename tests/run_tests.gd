extends Node
## Headless smoke + logic tests. Runs as a scene so autoloads exist before anything compiles.
## Run: tools/test.sh   (= godot --headless --path . --quit-after 3000 res://tests/test_runner.tscn)
## Exit code 0 = green.

var _fails := 0
var _count := 0


func _ready() -> void:
    _run()


func _run() -> void:
    _check("toon shader loads", load("res://shaders/toon.gdshader") != null)
    _check("player scene loads", load("res://src/player/player.tscn") != null)
    var arena_scene := load("res://src/world/arena_greybox.tscn") as PackedScene
    _check("arena scene loads", arena_scene != null)
    if arena_scene:
        var arena: Node3D = arena_scene.instantiate()
        add_child(arena)
        await get_tree().process_frame
        _check("arena built > 20 static bodies", arena.box_count > 20)
        var player := arena.get_node_or_null("Player") as Player
        _check("arena has Player with script", player != null)
        if player:
            _check("spawns on rifle (slot 2)", player.weapon_slot == 2)
            player._select_weapon(1)
            _check("melee grants double jump", player.max_jumps() == 2)
            _check("melee runs faster", player.speed_multiplier() > 1.0)
            player._select_weapon(5)
            _check("gatling slows run", player.speed_multiplier() < 1.0)
            _check("gatling single jump", player.max_jumps() == 1)
            _check("previous slot tracked for Q", player.previous_slot == 1)
            player._select_weapon(9)
            _check("invalid slot ignored", player.weapon_slot == 5)
            for i in 90:
                await get_tree().physics_frame
            _check("player settles on the floor", player.is_on_floor())
            _check("player did not fall through", player.global_position.y > -0.5)
        arena.queue_free()
        await get_tree().process_frame
    print("\n%d checks, %d failed" % [_count, _fails])
    get_tree().quit(1 if _fails > 0 else 0)


func _check(name: String, ok: bool) -> void:
    _count += 1
    if not ok:
        _fails += 1
    print("%s  %s" % ["PASS" if ok else "FAIL", name])
