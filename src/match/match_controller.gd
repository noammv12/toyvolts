class_name MatchController
extends Node
## Match rules: modes (practice / ffa / tdm), respawns, kill feed, health vial drops,
## scoring, time limit, match end and restart.

signal kill_feed(text: String)
signal match_ended(text: String)

const TEAM_NAMES := {1: "RED", 2: "BLUE"}

@export var respawn_delay := 3.0
var mode := "practice"
var score_limit := 0
var time_limit := 480.0
var time_left := 480.0
var active := true
var winner_text := ""
var spawn_points: Array[Vector3] = []


func _ready() -> void:
    add_to_group("match")
    mode = Game.mode
    match mode:
        "ffa":
            score_limit = 20
        "tdm":
            score_limit = 30
        _:
            score_limit = 0
    time_left = time_limit
    Game.match_active = true
    get_tree().node_added.connect(_on_node_added)
    for node in get_tree().get_nodes_in_group("characters"):
        _register(node as Character)


func _process(delta: float) -> void:
    if not active or mode == "practice":
        return
    time_left -= delta
    if time_left <= 0.0:
        time_left = 0.0
        _end_by_score()


func _on_node_added(node: Node) -> void:
    if node is Character:
        _register(node)


func _register(c: Character) -> void:
    if c != null and not c.died.is_connected(_on_died):
        c.died.connect(_on_died)


func _on_died(victim: Character, killer: Character) -> void:
    if killer != null and killer != victim:
        kill_feed.emit("%s  [%s]  %s" % [killer.display_name, victim.last_hit_weapon, victim.display_name])
    else:
        kill_feed.emit("%s fell apart" % victim.display_name)
    _drop_vial(victim.global_position)
    victim.respawn_at_msec = Time.get_ticks_msec() + int(respawn_delay * 1000.0)
    _respawn_later(victim)
    if active:
        _check_win()


func _drop_vial(at: Vector3) -> void:
    var vial := HealthVial.new()
    get_parent().add_child(vial)
    vial.global_position = at + Vector3(0, 0.1, 0)


func _respawn_later(victim: Character) -> void:
    await get_tree().create_timer(respawn_delay).timeout
    if not is_instance_valid(victim) or victim.alive or not active:
        return
    respawn_now(victim)


func respawn_now(c: Character) -> void:
    if c.respawn_at_home or spawn_points.is_empty():
        c.respawn(c.spawn_home, c.yaw)
    else:
        var p := pick_spawn(c)
        c.respawn(p, atan2(p.x, p.z))  # face the arena centre


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
        score += randf() * 2.0
        if score > best_score:
            best_score = score
            best = p
    return best


# ---- scoring ------------------------------------------------------------------

func contestants() -> Array[Character]:
    var list: Array[Character] = []
    for node in get_tree().get_nodes_in_group("characters"):
        var c := node as Character
        if c != null and not (c is TargetDummy):
            list.append(c)
    return list


func ranking() -> Array[Character]:
    var list := contestants()
    list.sort_custom(func(a: Character, b: Character) -> bool:
        if a.kills != b.kills:
            return a.kills > b.kills
        return a.deaths < b.deaths)
    return list


func team_score(team: int) -> int:
    var total := 0
    for c in contestants():
        if c.team == team:
            total += c.kills
    return total


func status_line(viewer: Character) -> String:
    var clock := "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
    match mode:
        "ffa":
            var lead := ranking()
            var leader_text := ""
            if not lead.is_empty():
                leader_text = "1st %s %d" % [lead[0].display_name, lead[0].kills]
            return "FFA to %d   |   You %d   |   %s   |   %s" % [score_limit, viewer.kills, leader_text, clock]
        "tdm":
            return "RED %d  -  %d BLUE   |   to %d   |   %s" % [team_score(1), team_score(2), score_limit, clock]
        _:
            return "Practice   |   %d kills" % viewer.kills


func _check_win() -> void:
    if mode == "ffa":
        for c in ranking():
            if c.kills >= score_limit:
                _end("YOU WIN" if c is Player else "%s WINS" % c.display_name.to_upper())
                return
    elif mode == "tdm":
        for team in [1, 2]:
            if team_score(team) >= score_limit:
                _end("%s TEAM WINS" % TEAM_NAMES[team])
                return


func _end_by_score() -> void:
    if mode == "ffa":
        var lead := ranking()
        _end("%s WINS" % lead[0].display_name.to_upper() if not lead.is_empty() else "TIME")
    elif mode == "tdm":
        var r := team_score(1)
        var b := team_score(2)
        _end("RED TEAM WINS" if r > b else ("BLUE TEAM WINS" if b > r else "DRAW"))


func _end(text: String) -> void:
    if not active:
        return
    active = false
    winner_text = text
    Game.match_active = false
    match_ended.emit(text)
    await get_tree().create_timer(7.0).timeout
    if is_inside_tree():
        restart()


func restart() -> void:
    for node in get_tree().get_nodes_in_group("pickups"):
        node.queue_free()
    for c in contestants():
        c.kills = 0
        c.deaths = 0
        c.alive = false
        respawn_now(c)
    time_left = time_limit
    winner_text = ""
    active = true
    Game.match_active = true
