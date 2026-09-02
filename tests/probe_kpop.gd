extends Node
## Probe: do the guests walk to their formation spots when the K-pop show starts?
func _ready() -> void:
    Game.mode = "party"
    Game.bot_count = 5
    var room: Node3D = (load("res://src/world/lalu_party.tscn") as PackedScene).instantiate()
    add_child(room)
    await get_tree().process_frame
    var party := room.get_node("Party") as PartyManager
    room.local_player().controller.input_enabled = false
    for i in 60:
        await get_tree().physics_frame
    party.kpop_seconds = 12.0
    party.kpop.on_shot(null, party.kpop.button_position(), Vector3.FORWARD, null)
    var bots := get_tree().get_nodes_in_group("bots")
    for step in 8:
        for i in 45:
            await get_tree().physics_frame
        var line := PackedStringArray()
        for b in bots:
            var spot: Vector3 = party.kpop.formation_spot(-b.net_id - 1)
            var q := PhysicsRayQueryParameters3D.create(b.global_position + Vector3(0, 0.5, 0), b.global_position + Vector3(0, -3, 0), Character.LAYER_WORLD, [b.get_rid()])
            var under: Dictionary = b.get_world_3d().direct_space_state.intersect_ray(q)
            var on := "air"
            if under:
                var col: Node = under.collider
                on = "%s<%s@%s" % [col.name, col.get_parent().name if col.get_parent() else "-", col.global_position.snapped(Vector3(0.1, 0.1, 0.1))]
            line.append("%s d=%.1f v=%.1f floor=%s place=%s navdone=%s pos=%s next=%s on=%s" % [b.display_name, Vector2(b.global_position.x - spot.x, b.global_position.z - spot.z).length(),
                b.velocity.length(), b.is_on_floor(), b._kpop_in_place, b.nav.is_navigation_finished(), b.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
                b.nav.get_next_path_position().snapped(Vector3(0.1, 0.1, 0.1)), on])
        print("t=%.2f active=%s | %s" % [party.kpop_t, party.kpop_active, " | ".join(line)])
    get_tree().quit(0)
