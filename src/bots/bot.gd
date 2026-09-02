class_name Bot
extends Character
## AI opponent. Targets the nearest visible enemy, picks a weapon by range (melee close,
## shotgun near, rifle mid, sniper far, a favourite heavy weapon sometimes), strafes and
## hops while engaged, wanders the navmesh otherwise and hunts health vials when hurt.

const NAMES := ["Zed", "Pixie", "Brick", "Gizmo", "Sprocket", "Dolly", "Bolt", "Widget", "Nova", "Tock"]
const THINK_INTERVAL := 0.15
const SKILL_RANGES := {"easy": [0.12, 0.35], "normal": [0.35, 0.75], "hard": [0.78, 1.0]}
const TRICK_SKILL := 0.7    ## from here on bots swap-cancel and wave-step like a player

@export var skill := 0.5   ## 0..1: aim error, reaction time, turn speed

var target: Character
var shots_fired := 0

var _think := 0.0
var _last_seen := 99.0
var _seen_for := 0.0
var _lost_pos := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _wander_left := 0.0
var _aim_error := Vector3.ZERO
var _aim_error_goal := Vector3.ZERO
var _aim_error_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _favorite := 2
var _nav_target := Vector3(INF, INF, INF)
var party_guest := false     ## birthday room: dance, wander, cheer; never fight
var _dance_left := 0.0
var _dance_t := 0.0
var _next_dance := 0.0
var _cheer_t := 0.0
var _cheer_until := 0.0
var cheers := 0
var _kpop_serial := -1
var _kpop_in_place := false
var _kpop_beat := -1

@onready var nav: NavigationAgent3D = $Nav


func _ready() -> void:
    super()
    add_to_group("bots")
    nav.path_desired_distance = 0.7
    nav.target_desired_distance = 1.2
    nav.path_max_distance = 4.0
    _favorite = [2, 3, 5, 6, 7].pick_random()
    _think = randf_range(0.3, 0.9)
    damaged.connect(_on_damaged)
    arsenal.fired.connect(_on_fired)
    party_guest = Game.mode == "party"
    if party_guest:
        _next_dance = randf_range(2.0, 6.0)
        arsenal.select.call_deferred(1)


func _on_fired(d: WeaponData) -> void:
    shots_fired += 1
    # swap-cancel: a skilled toy flicks to melee after every semi-auto shot; the next think
    # tick draws the gun again with its recovery already gone (twice the fire rate)
    if skill >= TRICK_SKILL and d.swap_cancel:
        arsenal.select(1)
        _think = minf(_think, 0.12)


func _on_damaged(amount: float, source: Character, _headshot: bool) -> void:
    if party_guest:
        _dance_left = maxf(_dance_left, 3.0)   # a hit guest breaks into a dance
        return
    if amount <= 0.0:
        return
    if source != null and source != self and source.alive and _is_enemy(source):
        if target == null or not target.alive or _last_seen > 1.0:
            target = source
            _lost_pos = source.global_position
            _last_seen = 0.4


func _physics_process(delta: float) -> void:
    if party_guest and alive:
        _party_brain(delta)
    elif alive and Game.match_active:
        _brain(delta)
    else:
        wish_dir = Vector3.ZERO
        arsenal.trigger = false
        arsenal.alt = false
    super(delta)


func _brain(delta: float) -> void:
    var ticked := false
    _think -= delta
    if _think <= 0.0:
        _think = THINK_INTERVAL
        ticked = true
        _pick_target()

    var sees := target != null and target.alive and _can_see(target)
    if sees:
        _last_seen = 0.0
        _seen_for += delta
        _lost_pos = target.global_position
    else:
        _last_seen += delta
        if _last_seen > 0.5:
            _seen_for = 0.0

    var engaged := target != null and target.alive and _last_seen < 2.5
    var objective := _objective_point()
    # hurt and out of the enemy's sight: duck behind whatever is between us (Microvolts crouch)
    crouch_held = engaged and not sees and hp < 50.0 and _last_seen < 1.5 and is_on_floor()
    if engaged:
        var dist := global_position.distance_to(target.global_position)
        if ticked:
            _choose_weapon(dist)
        _aim(delta, dist, sees)
        if carrying != null and objective != Vector3.INF:
            _move_to(objective, delta)   # a carrier runs for the pad and shoots on the way
        else:
            _move_engaged(delta, dist, sees)
        var reaction := lerpf(0.55, 0.12, skill)
        arsenal.trigger = sees and _seen_for > reaction and _aim_on_target(dist) and _safe_to_fire(dist)
        arsenal.alt = arsenal.slot == 4 and dist > 10.0
    else:
        arsenal.trigger = false
        arsenal.alt = false
        if ticked and arsenal.slot != 2:
            arsenal.select(2)
        if objective != Vector3.INF:
            _move_to(objective, delta)
            _look_along_motion(delta)
        else:
            _wander(delta)
        var s := arsenal.current()
        if s.uses_ammo() and s.clip < s.data.clip_size and s.reserve > 0 and not s.is_reloading():
            arsenal.reload()


# ---- party guest ----------------------------------------------------------------
## Wander the room, stop to dance (sway, hop, cheer) now and then, cheer nonstop in the finale.

func _party_brain(delta: float) -> void:
    arsenal.trigger = false
    arsenal.alt = false
    var party := get_tree().get_first_node_in_group("party")
    if party != null and party.kpop_active and party.kpop != null:
        _kpop_dance(delta, party)
        return
    _dance_t += delta
    _cheer_t -= delta
    var now := Time.get_ticks_msec() / 1000.0
    var finale := now < _cheer_until
    if finale:
        _dance_left = maxf(_dance_left, 0.5)
    if _dance_left > 0.0:
        _dance_left -= delta
        var face := Vector3.ZERO - global_position   # the cake
        face.y = 0.0
        if face.length() > 0.5:
            yaw = lerp_angle(yaw, atan2(-face.x, -face.z), minf(1.0, delta * 4.0))
        var side := Vector3(-cos(yaw), 0, sin(yaw))
        wish_dir = side * sin(_dance_t * 5.0) * 0.55
        pitch = lerpf(pitch, 0.0, minf(1.0, delta * 4.0))
        if is_on_floor() and randf() < delta * (2.2 if finale else 0.8):
            jump_pressed = true
        if _cheer_t <= 0.0:
            _cheer_t = randf_range(0.9, 1.6) if finale else randf_range(1.4, 2.6)
            figure.play_action("cheer", 1.0)
            cheers += 1
            if randf() < (0.6 if finale else 0.25):
                Sfx.play("cheer", center(), -10.0, 0.3)
        return
    _next_dance -= delta
    if _next_dance <= 0.0:
        _next_dance = randf_range(6.0, 12.0)
        _dance_left = randf_range(3.5, 6.5)
        return
    _wander(delta)


## The K-pop show: walk to my spot in the formation, face the stage, then sway, hop and cheer
## on the beat of the manager's shared clock (every guest in sync).
func _kpop_dance(delta: float, party: Node) -> void:
    if party.kpop_serial != _kpop_serial:
        _kpop_serial = party.kpop_serial
        _kpop_in_place = false
        _kpop_beat = -1
        _nav_target = Vector3(INF, INF, INF)
    var idx := maxi(0, -net_id - 1)
    var spot: Vector3 = party.kpop.formation_spot(idx)
    var flat := spot - global_position
    flat.y = 0.0
    if not _kpop_in_place:
        if flat.length() > 1.0:
            _move_to(spot, delta)
            _look_along_motion(delta)
            return
        _kpop_in_place = true
    var to_stage: Vector3 = party.kpop.stage_position() - global_position
    to_stage.y = 0.0
    if to_stage.length() > 0.1:
        yaw = lerp_angle(yaw, atan2(-to_stage.x, -to_stage.z), minf(1.0, delta * 6.0))
    pitch = lerpf(pitch, 0.0, minf(1.0, delta * 4.0))
    var beat: float = party.kpop_t * PartyKpop.BPM / 60.0
    var side := Vector3(-cos(yaw), 0, sin(yaw))
    var pull := flat.normalized() * clampf(flat.length() - 0.3, 0.0, 0.5) if flat.length() > 0.3 else Vector3.ZERO
    wish_dir = side * sin(beat * PI) * 0.7 + pull
    var bi := int(beat)
    if bi != _kpop_beat:
        _kpop_beat = bi
        if bi % 4 == 0 and is_on_floor():
            jump_pressed = true
        if bi % 8 == 4:
            figure.play_action("cheer", 0.9)
            cheers += 1


## The finale: cheer for `seconds` (hop, sway, "Cheer" clip).
func party_cheer(seconds: float) -> void:
    _cheer_until = Time.get_ticks_msec() / 1000.0 + seconds
    _dance_left = maxf(_dance_left, seconds)


# ---- perception ---------------------------------------------------------------

func _is_enemy(c: Character) -> bool:
    if c == null or c == self or not c.alive:
        return false
    return team == 0 or c.team != team


func _can_see(c: Character) -> bool:
    var from := eye()
    var to := c.center()
    var d := to - from
    if d.length() > 3.0 and rad_to_deg(facing().angle_to(d)) > 100.0:
        return false
    var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD)
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Capture the Battery: the pad when carrying, else the nearest loose cell within reach.
func _objective_point() -> Vector3:
    if Game.mode != "ctb":
        return Vector3.INF
    var m := get_tree().get_first_node_in_group("match") as MatchController
    if m == null:
        return Vector3.INF
    if carrying != null:
        return m.base_positions.get(team, Vector3.INF)
    var best := Vector3.INF
    var best_d := 28.0
    for b in m.loose_batteries():
        var d := global_position.distance_to(b.global_position)
        if d < best_d:
            best_d = d
            best = b.global_position
    return best


func _pick_target() -> void:
    var best: Character = null
    var best_d := INF
    for node in get_tree().get_nodes_in_group("characters"):
        var c := node as Character
        if not _is_enemy(c):
            continue
        var d := global_position.distance_to(c.global_position)
        if c.carrying != null:
            d -= 14.0   # enemy carriers are priority targets
        if not _can_see(c):
            d += 30.0
        if d < best_d:
            best_d = d
            best = c
    if target != null and target.alive and _last_seen < 1.0 and best != target:
        if best == null or global_position.distance_to(target.global_position) < best_d + 6.0:
            return
    if best != target:
        _seen_for = 0.0
    target = best


# ---- weapons ------------------------------------------------------------------

func _usable(slot: int) -> bool:
    var s := arsenal.states[slot - 1]
    return not s.uses_ammo() or s.clip > 0


func _choose_weapon(dist: float) -> void:
    var want := 2
    if dist < 2.6:
        want = 1
    elif dist < 7.0:
        want = 3 if _usable(3) else 2
    elif dist > 19.0:
        want = 4 if _usable(4) else 2
    else:
        want = 2
        if _favorite in [5, 6, 7] and _usable(_favorite) and dist > 5.0 and randf() < 0.6:
            want = _favorite
        elif _favorite == 3 and dist < 9.0 and _usable(3):
            want = 3
    if not _usable(want):
        want = 2
    if want != arsenal.slot:
        arsenal.select(want)


func _aim(delta: float, dist: float, sees: bool) -> void:
    _aim_error_t -= delta
    if _aim_error_t <= 0.0:
        _aim_error_t = randf_range(0.25, 0.6)
        var mag := (1.0 - skill) * 0.9
        _aim_error_goal = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * mag
    _aim_error = _aim_error.lerp(_aim_error_goal, minf(1.0, delta * 6.0))

    var point: Vector3 = target.center() if sees else _lost_pos + Vector3(0, 1, 0)
    point += _aim_error * clampf(dist / 8.0, 0.5, 3.0)
    var d := arsenal.data()
    if d.kind == WeaponData.Kind.PROJECTILE and sees:
        var flight := dist / maxf(d.projectile_speed, 1.0)
        point += target.velocity * flight * 0.8
        if d.projectile_gravity > 0.0:
            point += Vector3.UP * (0.5 * d.projectile_gravity * flight * flight)
    var dir := (point - eye()).normalized()
    var want_yaw := atan2(-dir.x, -dir.z)
    var want_pitch := asin(clampf(dir.y, -1.0, 1.0))
    var rate := lerpf(5.0, 14.0, skill)
    yaw = lerp_angle(yaw, want_yaw, minf(1.0, delta * rate))
    pitch = lerpf(pitch, want_pitch, minf(1.0, delta * rate))


func _aim_on_target(dist: float) -> bool:
    if arsenal.slot == 1:
        return dist < 2.4
    var to := target.center() - eye()
    var tolerance := 3.0 + 25.0 / maxf(dist, 1.0)
    return rad_to_deg(aim_dir().angle_to(to)) < tolerance


func _safe_to_fire(dist: float) -> bool:
    if arsenal.data().kind == WeaponData.Kind.PROJECTILE:
        return dist > 4.5
    return true


# ---- movement -----------------------------------------------------------------

func _move_engaged(delta: float, dist: float, sees: bool) -> void:
    var pref_min := 4.0
    var pref_max := 12.0
    match arsenal.slot:
        1:
            pref_min = 0.0
            pref_max = 1.6
        3:
            pref_min = 1.5
            pref_max = 5.0
        4:
            pref_min = 12.0
            pref_max = 30.0
        6, 7:
            pref_min = 6.0
            pref_max = 14.0
    if not sees:
        _move_to(_lost_pos, delta)
        return
    _strafe_t -= delta
    if _strafe_t <= 0.0:
        _strafe_t = randf_range(0.6, 1.4)
        if randf() < 0.7:
            _strafe = -_strafe
    var to := target.global_position - global_position
    to.y = 0.0
    if to.length() < 0.01:
        return
    var toward := to.normalized()
    if dist > pref_max:
        _move_to(target.global_position, delta)
    elif dist < pref_min:
        wish_dir = -toward
    else:
        var side := toward.cross(Vector3.UP) * _strafe
        wish_dir = (side + toward * 0.15).normalized()
        var hop_rate := 0.5 if skill < TRICK_SKILL else 1.3
        if is_on_floor() and randf() < delta * hop_rate:
            jump_pressed = true
        elif not is_on_floor() and skill >= TRICK_SKILL and jumps_left() > 0 and velocity.y < 0.0 and randf() < delta * 4.0:
            jump_pressed = true   # wave-step: second hop on the way down when melee is out


func _move_to(p: Vector3, delta: float) -> void:
    if _nav_target.distance_to(p) > 1.5:
        _nav_target = p
        nav.target_position = p
    if nav.is_navigation_finished():
        wish_dir = Vector3.ZERO
        return
    var next := nav.get_next_path_position()
    var dir := next - global_position
    var rise := dir.y
    dir.y = 0.0
    wish_dir = dir.normalized() if dir.length() > 0.05 else Vector3.ZERO
    # the baked navmesh floats ~0.5 m above the floor: only a real step (1 m stairs, crates) is a jump
    if is_on_floor() and rise > 0.8 and dir.length() < 1.6:
        jump_pressed = true
    if wish_dir != Vector3.ZERO and velocity.length() < 0.5:
        _stuck_t += delta
        if _stuck_t > 0.8 and is_on_floor():
            jump_pressed = true
        if _stuck_t > 2.0:
            _stuck_t = 0.0
            _wander_left = 0.0
            _nav_target = Vector3(INF, INF, INF)
    else:
        _stuck_t = 0.0


func _wander(delta: float) -> void:
    _wander_left -= delta
    if hp < 60.0 and not party_guest:
        var vial := _nearest_pickup(14.0)
        if vial != null:
            _move_to(vial.global_position, delta)
            _look_along_motion(delta)
            return
    if _wander_left <= 0.0 or (nav.is_navigation_finished() and _wander_target != Vector3.ZERO):
        _wander_left = randf_range(5.0, 9.0)
        var map := get_world_3d().navigation_map
        var p := NavigationServer3D.map_get_random_point(map, 1, false)
        _wander_target = p if p != Vector3.ZERO else global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
        _nav_target = Vector3(INF, INF, INF)
    _move_to(_wander_target, delta)
    _look_along_motion(delta)


func _look_along_motion(delta: float) -> void:
    if wish_dir.length() > 0.1:
        var want_yaw := atan2(-wish_dir.x, -wish_dir.z)
        yaw = lerp_angle(yaw, want_yaw, minf(1.0, delta * 6.0))
    pitch = lerpf(pitch, 0.0, minf(1.0, delta * 4.0))


func _nearest_pickup(max_dist: float) -> Node3D:
    var best: Node3D = null
    var best_d := max_dist
    for node in get_tree().get_nodes_in_group("pickups"):
        var p := node as Node3D
        if p == null:
            continue
        var d := global_position.distance_to(p.global_position)
        if d < best_d:
            best_d = d
            best = p
    return best
