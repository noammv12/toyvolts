class_name MatchController
extends Node
## Match rules: modes (practice / ffa / tdm / elim), respawns, kill feed, health vial drops,
## scoring, time limit, rounds (Elimination), match end and restart.

signal kill_feed(text: String)
signal match_ended(text: String, winner: Character)   ## winner null for team / draw results
signal round_ended(text: String, winner: Character)
signal announce(text: String, who: Character)         ## objective events (battery taken / charged)
signal round_started()
signal restarted()

const TEAM_NAMES := {1: "RED", 2: "BLUE"}
const ELIM_ROUND_TIME := 90.0
const ELIM_ROUNDS_TO_WIN := 5
const CTB_TO_WIN := 5

@export var respawn_delay := 3.0
var mode := "practice"
var score_limit := 0
var time_limit := 480.0
var time_left := 480.0
var active := true
var winner_text := ""
var winner: Character = null
var spawn_points: Array[Vector3] = []
const OCCUPIED_RADIUS := 1.2      ## a toy this close to a spawn point makes it unusable
var round_number := 1
var round_active := true
var base_positions := {}     ## team -> Vector3 (ctb)


func _ready() -> void:
    add_to_group("match")
    mode = Game.mode
    match mode:
        "ffa":
            score_limit = 20
        "tdm":
            score_limit = 30
        "elim":
            score_limit = ELIM_ROUNDS_TO_WIN
            time_limit = ELIM_ROUND_TIME
        "ctb":
            score_limit = CTB_TO_WIN
        _:
            score_limit = 0    # practice and the birthday party never end
    if Game.has_arg("score_limit"):   # debug / smoke tests: end the match quickly
        score_limit = int(Game.arg("score_limit"))
    time_left = time_limit
    Game.match_active = true
    get_tree().node_added.connect(_on_node_added)
    for node in get_tree().get_nodes_in_group("characters"):
        _register(node as Character)
    for node in get_tree().get_nodes_in_group("battery_bases"):
        _register_base(node as BatteryBase)
    for node in get_tree().get_nodes_in_group("batteries"):
        _register_battery(node as Battery)


func _process(delta: float) -> void:
    if not active or mode == "practice" or mode == "party" or not round_active or Net.is_client():
        return
    time_left -= delta
    if time_left <= 0.0:
        time_left = 0.0
        if mode == "elim":
            _end_round_by_time()
        else:
            _end_by_score()


func _on_node_added(node: Node) -> void:
    if node is Character:
        _register(node)
    elif node is BatteryBase:
        _register_base(node)
    elif node is Battery:
        _register_battery(node)


func _register_base(b: BatteryBase) -> void:
    if b != null and not b.charged.is_connected(_on_charged):
        b.charged.connect(_on_charged)


func _register_battery(b: Battery) -> void:
    if b != null and not b.picked_up.is_connected(_on_battery_taken):
        b.picked_up.connect(_on_battery_taken)
        b.dropped.connect(_on_battery_dropped)


func _on_battery_taken(_b: Battery, by: Character) -> void:
    announce.emit("%s took a battery" % by.display_name, by)
    kill_feed.emit("%s  [battery]" % by.display_name)


func _on_battery_dropped(_b: Battery, _at: Vector3) -> void:
    pass


## A carrier stepped on their own pad: score, send the cell home.
func _on_charged(base: BatteryBase, by: Character) -> void:
    if not active or by.carrying == null:
        return
    var cell := by.carrying
    by.captures += 1
    cell.return_home()
    Sfx.play("respawn", base.global_position, 4.0)
    Vfx.explosion(base.global_position + Vector3(0, 0.6, 0), 1.2)
    announce.emit("%s charged a battery!  %s %d - %d %s" % [by.display_name, TEAM_NAMES[1], team_score(1), team_score(2), TEAM_NAMES[2]], by)
    kill_feed.emit("%s charged a battery" % by.display_name)
    _check_win()


func _register(c: Character) -> void:
    if c != null and not c.died.is_connected(_on_died):
        c.died.connect(_on_died)


func _on_died(victim: Character, killer: Character) -> void:
    if Net.is_client():
        return
    if killer != null and killer != victim:
        kill_feed.emit("%s  [%s]  %s" % [killer.display_name, victim.last_hit_weapon, victim.display_name])
    else:
        kill_feed.emit("%s fell apart" % victim.display_name)
    _drop_vial(victim.global_position)
    if mode == "elim":
        if active and round_active:
            _check_round()
        return
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


## The arena hosting this match (parent), if it can resolve spawn overlaps.
func _arena() -> ArenaBase:
    return get_parent() as ArenaBase


## The spawn point farthest from any living enemy (on the team's own half in Capture the Battery).
func pick_spawn(for_whom: Character) -> Vector3:
    var candidates: Array[Vector3] = spawn_points
    if mode == "ctb" and base_positions.has(for_whom.team) and base_positions.size() == 2:
        var own: Vector3 = base_positions[for_whom.team]
        var other: Vector3 = base_positions[2 if for_whom.team == 1 else 1]
        var side: Array[Vector3] = []
        for p in spawn_points:
            if p.distance_to(own) < p.distance_to(other):
                side.append(p)
        if not side.is_empty():
            candidates = side
    var best := candidates[0]
    var best_score := -1.0
    for p in candidates:
        var score := INF
        for node in get_tree().get_nodes_in_group("characters"):
            var c := node as Character
            if c == null or c == for_whom or not c.alive:
                continue
            var d := p.distance_to(c.global_position)
            if d < OCCUPIED_RADIUS:
                score = -INF      # somebody (friend or foe) is standing on it
                break
            if c.team != 0 and c.team == for_whom.team:
                continue
            score = minf(score, d)
        score += randf() * 2.0
        if score > best_score:
            best_score = score
            best = p
    var arena := _arena()
    if arena != null:
        best = arena.safe_spawn(best, for_whom)
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
    var elim := mode == "elim"
    list.sort_custom(func(a: Character, b: Character) -> bool:
        var sa := a.rounds_won if elim else a.kills
        var sb := b.rounds_won if elim else b.kills
        if sa != sb:
            return sa > sb
        if a.kills != b.kills:
            return a.kills > b.kills
        return a.deaths < b.deaths)
    return list


func team_score(team: int) -> int:
    var total := 0
    for c in contestants():
        if c.team != team:
            continue
        match mode:
            "elim":
                total += c.rounds_won
            "ctb":
                total += c.captures
            _:
                total += c.kills
    return total


## Loose batteries (on the floor), for bots and the radar.
func loose_batteries() -> Array[Battery]:
    var list: Array[Battery] = []
    for node in get_tree().get_nodes_in_group("batteries"):
        var b := node as Battery
        if b != null and b.is_loose():
            list.append(b)
    return list


func alive_count(team := 0) -> int:
    var n := 0
    for c in contestants():
        if c.alive and (team == 0 or c.team == team):
            n += 1
    return n


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
        "ctb":
            var carry := "   |   CARRYING - get to your base!" if viewer.carrying != null else ""
            return "BATTERY  RED %d  -  %d BLUE   |   to %d   |   %s%s" % [team_score(1), team_score(2), score_limit, clock, carry]
        "elim":
            var lead := ranking()
            var leader_text := "1st %s %d" % [lead[0].display_name, lead[0].rounds_won] if not lead.is_empty() else ""
            return "ELIMINATION  round %d   |   You %d   |   %s   |   alive %d   |   %s" % [
                round_number, viewer.rounds_won, leader_text, alive_count(), clock]
        "party":
            var party := get_tree().get_first_node_in_group("party")
            return party.status_line() if party != null else "PARTY"
        _:
            return "Practice   |   %d kills" % viewer.kills


func _check_win() -> void:
    if mode == "ffa":
        for c in ranking():
            if c.kills >= score_limit:
                _end("%s WINS" % c.display_name.to_upper(), c)
                return
    elif mode == "tdm" or mode == "ctb":
        for team in [1, 2]:
            if team_score(team) >= score_limit:
                _end("%s TEAM WINS" % TEAM_NAMES[team])
                return


func _end_by_score() -> void:
    if mode == "ffa":
        var lead := ranking()
        _end("%s WINS" % lead[0].display_name.to_upper() if not lead.is_empty() else "TIME",
            lead[0] if not lead.is_empty() else null)
    elif mode == "tdm" or mode == "ctb":
        var r := team_score(1)
        var b := team_score(2)
        _end("RED TEAM WINS" if r > b else ("BLUE TEAM WINS" if b > r else "DRAW"))


# ---- elimination rounds ----------------------------------------------------------

func _check_round() -> void:
    var alive: Array[Character] = []
    for c in contestants():
        if c.alive:
            alive.append(c)
    if alive.size() <= 1:
        _end_round(alive[0] if alive.size() == 1 else null)


func _end_round_by_time() -> void:
    # most survivors' team, else nobody
    var alive: Array[Character] = []
    for c in contestants():
        if c.alive:
            alive.append(c)
    _end_round(alive[0] if alive.size() == 1 else null)


func _end_round(round_winner: Character) -> void:
    if not round_active:
        return
    round_active = false
    var text := "ROUND DRAW"
    if round_winner != null:
        round_winner.rounds_won += 1
        text = "%s WINS THE ROUND" % round_winner.display_name.to_upper()
    round_ended.emit(text, round_winner)
    if round_winner != null and round_winner.rounds_won >= score_limit:
        _end("%s WINS" % round_winner.display_name.to_upper(), round_winner)
        return
    await get_tree().create_timer(3.0).timeout
    if not active or not is_inside_tree():
        return
    round_number += 1
    for node in get_tree().get_nodes_in_group("pickups"):
        if node is HealthVial:
            node.queue_free()
    for c in contestants():
        c.alive = false
        respawn_now(c)
    time_left = time_limit
    round_active = true
    round_started.emit()


func _end(text: String, who: Character = null) -> void:
    if not active:
        return
    active = false
    winner_text = text
    winner = who
    Game.match_active = false
    match_ended.emit(text, who)
    await get_tree().create_timer(7.0).timeout
    if is_inside_tree():
        restart()


func restart() -> void:
    for node in get_tree().get_nodes_in_group("pickups"):
        if node is HealthVial:
            node.queue_free()
    for node in get_tree().get_nodes_in_group("batteries"):
        node.return_home()
    for c in contestants():
        c.kills = 0
        c.deaths = 0
        c.rounds_won = 0
        c.captures = 0
        c.alive = false
        respawn_now(c)
    time_left = time_limit
    winner_text = ""
    winner = null
    round_number = 1
    round_active = true
    active = true
    Game.match_active = true
    restarted.emit()
