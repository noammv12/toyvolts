class_name MatchController
extends Node
## Match rules. M1: respawns + kill feed. M2 adds scoring, bots and modes.

signal kill_feed(text: String)

@export var respawn_delay := 3.0
var spawn_points: Array[Vector3] = []


func _ready() -> void:
    add_to_group("match")
    get_tree().node_added.connect(_on_node_added)
    for node in get_tree().get_nodes_in_group("characters"):
        _register(node as Character)


func _on_node_added(node: Node) -> void:
    if node is Character:
        _register(node)


func _register(c: Character) -> void:
    if c != null and not c.died.is_connected(_on_died):
        c.died.connect(_on_died)


func _on_died(victim: Character, killer: Character) -> void:
    if killer != null and killer != victim:
        kill_feed.emit("%s  >  %s" % [killer.display_name, victim.display_name])
    else:
        kill_feed.emit("%s fell apart" % victim.display_name)
    _respawn_later(victim)


func _respawn_later(victim: Character) -> void:
    await get_tree().create_timer(respawn_delay).timeout
    if not is_instance_valid(victim) or victim.alive:
        return
    if victim.respawn_at_home or spawn_points.is_empty():
        victim.respawn(victim.spawn_home, victim.yaw)
    else:
        var p := pick_spawn(victim)
        victim.respawn(p, atan2(p.x, p.z))  # face the arena centre


## The spawn point farthest from any living enemy.
func pick_spawn(for_whom: Character) -> Vector3:
    var best := spawn_points[0]
    var best_score := -1.0
    for p in spawn_points:
        var score := INF
        for node in get_tree().get_nodes_in_group("characters"):
            var c := node as Character
            if c == null or c == for_whom or not c.alive:
                continue
            if c.team != 0 and c.team == for_whom.team:
                continue
            score = minf(score, p.distance_to(c.global_position))
        if score > best_score:
            best_score = score
            best = p
    return best
