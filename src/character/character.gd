class_name Character
extends CharacterBody3D
## Shared body for the player, bots and target dummies: Microvolts-style movement
## (constant run speed, no sprint, full air control, snappy jump, melee double jump),
## health with head/body hitboxes, the seven-slot Arsenal and an animated Figure.
## Controllers write `yaw`, `pitch`, `wish_dir`, `jump_pressed` and the arsenal triggers: the
## local PlayerController, a Bot brain, or (online) the server applying a peer's input packets.
## Clients hold `puppet` copies of server-simulated toys that only interpolate snapshots.

signal died(victim: Character, killer: Character)
signal health_changed(hp: float, max_hp: float)
signal damaged(amount: float, source: Character, headshot: bool)
signal respawned()
signal landed(fall_speed: float)     ## cosmetic: hit the floor at this speed (m/s, positive)

const HEAD_SHAPE_INDEX := 1
const LAYER_WORLD := 1
const LAYER_CHARACTER := 2
const LAYER_TARGET := 4      ## shootable props (balloons, pinata, ribbons): guns hit them, bodies walk through
const PARTY_HOP := 7.0       ## party mode: a hit makes the toy hop and cheer instead of hurting it
const AUTO_BOUNCE := 5.5     ## bouncy castle: landing inside bounces you again
const STAND_HEIGHT := 1.15   ## body capsule height standing / crouched (Microvolts L-Ctrl crouch)
const CROUCH_HEIGHT := 0.8
const CROUCH_SPEED := 0.5    ## run speed multiplier while crouched
const CROUCH_CAMERA_DROP := 0.45
const SPAWN_PROTECTION := 2.0
const DEATH_HIDE_DELAY := 1.1
const JUMP_BUFFER := 0.15    ## seconds a mid-air jump press waits for a jump to become available

@export var display_name := "Toy"
@export var team := 0
@export var body_color := Color(0.95, 0.42, 0.2)
@export var model_id := "Knight"
@export var respawn_at_home := false
@export var run_speed := 7.0
@export var ground_accel := 60.0
@export var air_accel := 18.0
@export var gravity := 30.0
@export var jump_velocity := 9.5

var max_hp := 100.0
var hp := 100.0
var alive := true
var protection_left := 0.0
var kills := 0
var deaths := 0
var rounds_won := 0
var captures := 0            ## Capture the Battery deliveries
var carrying: Battery = null
var spawn_home := Vector3.ZERO
var last_hit_weapon := ""
var last_fire_msec := -100000   ## the radar shows enemies for a moment after they fire
var respawn_at_msec := 0
var net_id := 0             ## unique per match: humans = peer id, bots/dummies = 1000+
var peer_id := 0            ## multiplayer peer that owns this toy (0 = server-side bot/dummy)
var controller: Object = null ## PlayerController / NetInput: feed(self, delta) runs each physics tick
var puppet := false         ## client-side copy of a server-simulated toy (no simulation)
var puppet_on_floor := true
var predicted := false      ## client-side local toy: simulated here, reconciled with the server
var zone_gravity_mult := 1.0   ## PartyZone effects while inside (moon corner, bouncy castle, slide)
var zone_jump_mult := 1.0
var zone_bounce := false
var zone_push := Vector3.ZERO
var _zones: Array = []
var _fall_vy := 0.0          ## vertical speed just before the last move (bounce restitution)

# controller inputs
var yaw := 0.0
var pitch := 0.0
var wish_dir := Vector3.ZERO
var jump_pressed := false
var crouch_held := false
var crouching := false      ## the body is low: half speed, lower hitboxes, no jump
var view_tick := 0          ## server: the tick this remote human was rendering (lag compensation)

var _jumps_used := 0        ## jumps since the last floor contact (max_jumps() can change mid-air)
var _was_on_floor := false
var _jump_buffer := 0.0
var _aim_override := false
var _aim_origin := Vector3.ZERO
var _aim_dir := Vector3.FORWARD
var _flash := 0.0
var _anim_on_floor := true    ## ground contact as the ANIMATION sees it (puppets included)
var _anim_fall_vy := 0.0      ## last airborne vertical speed: how hard the landing was
var _death_serial := 0
var _team_ring: MeshInstance3D
var _step_t := 0.0

@onready var arsenal: Arsenal = $Arsenal
@onready var weapon_holder: Node3D = $WeaponHolder
@onready var figure: Figure = $Figure
@onready var battery_mount: Node3D = $BatteryMount
@onready var _body_shape: CollisionShape3D = $Collision
@onready var _head_shape: CollisionShape3D = $Head


func _ready() -> void:
    add_to_group("characters")
    spawn_home = global_position
    figure.setup(Skins.path(model_id), body_color, 0.35 if team != 0 else 0.0)
    _build_team_ring()
    if Game.mode == "party":
        figure.add_hat(PartyText.color(absi(net_id) + 1))
    health_changed.emit(hp, max_hp)


func set_color(color: Color) -> void:
    body_color = color
    figure.set_tint(color, 0.35 if team != 0 else 0.0)
    if _team_ring:
        _team_ring.material_override.albedo_color = Color(color, 0.85)
        _team_ring.visible = team != 0


func _process(delta: float) -> void:
    _flash = maxf(0.0, _flash - delta * 6.0)
    var f := _flash
    if protection_left > 0.0:
        f = maxf(f, 0.25 + 0.2 * sin(Time.get_ticks_msec() * 0.02))
    figure.set_flash(f)
    if alive:
        var local := global_transform.basis.inverse() * velocity
        var v := Vector2(local.x, -local.z) / maxf(run_speed, 0.1)
        figure.set_locomotion(v, grounded(), delta)
        figure.set_pitch(pitch)
        figure.set_stance(arsenal.data().kind != WeaponData.Kind.MELEE, arsenal.slot)
        _anim_ground_step()


## Takeoff and landing beats, driven from _process so REMOTE toys get them too: a puppet never
## runs the movement code (see _physics_process), but its snapshot carries velocity and
## on_floor, which is everything this needs.
func _anim_ground_step() -> void:
    var on_floor := grounded()
    if on_floor != _anim_on_floor:
        if on_floor:
            _land(_anim_fall_vy)
        elif puppet and velocity.y > 1.0:
            figure.play_body_action("jump_start", 0.28)
        _anim_on_floor = on_floor
    if not on_floor:
        _anim_fall_vy = velocity.y


## Everything a landing does that is only cosmetic: clip, squash, dust, camera dip, thud.
func _land(fall_vy: float) -> void:
    var speed := absf(minf(fall_vy, 0.0))
    Game.trace("land")
    landed.emit(speed)
    Sfx.play("land", global_position, -6.0 + clampf(speed * 0.4, 0.0, 5.0))
    if speed < 3.0:
        return
    var hard := clampf((speed - 3.0) / 13.0, 0.0, 1.0)
    figure.play_body_action("jump_land", lerpf(0.36, 0.22, hard))
    figure.squash(0.35 + 0.75 * hard)
    Vfx.jump_puff(global_position + Vector3(0, 0.08, 0), 0.8 + 0.7 * hard)
    if controller != null and controller.has_method("apply_land_dip"):
        controller.apply_land_dip(hard)


func _physics_process(delta: float) -> void:
    if controller != null:
        controller.feed(self, delta)
    if puppet:
        Net.puppet_step(self)
        rotation.y = yaw
        weapon_holder.rotation.x = pitch
        if crouching != crouch_held:
            _set_crouch(crouch_held)
        return
    if predicted:
        Net.client_before_simulate(self)
    rotation.y = yaw
    weapon_holder.rotation.x = pitch
    protection_left = maxf(0.0, protection_left - delta)
    if not alive:
        velocity = Vector3.ZERO
        jump_pressed = false
        if crouching:
            _set_crouch(false)
        return

    _update_crouch()
    var wish := wish_dir * run_speed * arsenal.data().run_speed_mult * (0.9 if carrying != null else 1.0) * (CROUCH_SPEED if crouching else 1.0)
    var accel := ground_accel if is_on_floor() else air_accel
    if zone_push != Vector3.ZERO:
        accel = 6.0   # the slide is slippery: input barely steers, the push wins
    velocity.x = move_toward(velocity.x, wish.x, accel * delta)
    velocity.z = move_toward(velocity.z, wish.z, accel * delta)
    if zone_push != Vector3.ZERO:
        velocity += zone_push * delta
        var flat := Vector2(velocity.x, velocity.z)
        if flat.length() > 15.0:
            flat = flat.normalized() * 15.0
            velocity.x = flat.x
            velocity.z = flat.y

    if is_on_floor():
        _jumps_used = 0
        _jump_buffer = 0.0
        if not _was_on_floor:
            if zone_bounce and _fall_vy < -AUTO_BOUNCE:
                velocity.y = -_fall_vy * 0.5   # the castle gives half the landing speed back
                Sfx.play("boing", global_position, -6.0, 0.2)
        var speed := Vector2(velocity.x, velocity.z).length()
        if speed > 2.0:
            _step_t -= delta * speed / run_speed
            if _step_t <= 0.0:
                _step_t = 0.34
                Sfx.play("footstep", global_position, 0.0, 0.15)
    else:
        if _was_on_floor and _jumps_used == 0:
            _jumps_used = 1  # walked off a ledge: no free ground jump
        velocity.y -= gravity * zone_gravity_mult * delta

    # Microvolts wave-step: any weapon can jump once; melee out (even drawn mid-air) allows a second.
    # A press with no jump left is kept for JUMP_BUFFER seconds: pressing just before melee is
    # selected mid-air still double-jumps the tick it is.
    _jump_buffer = maxf(0.0, _jump_buffer - delta)
    if jump_pressed and _jumps_used >= max_jumps() and not is_on_floor():
        _jump_buffer = JUMP_BUFFER
    if crouching:
        jump_pressed = false
        _jump_buffer = 0.0
    if (jump_pressed or _jump_buffer > 0.0) and _jumps_used < max_jumps():
        var second := _jumps_used > 0
        velocity.y = jump_velocity * zone_jump_mult * (0.92 if second else 1.0)
        _jumps_used += 1
        _jump_buffer = 0.0
        Sfx.play(Sfx.pick(["jump_a", "jump_b", "jump_c"]), global_position, 1.0 if second else 0.0)
        figure.play_body_action("jump_double" if second else "jump_start", 0.34 if second else 0.28)
        if second:
            Vfx.jump_puff(global_position + Vector3(0, 0.15, 0), 1.3)
    jump_pressed = false

    _was_on_floor = is_on_floor()
    _fall_vy = velocity.y
    move_and_slide()
    if predicted:
        Net.client_after_simulate(self)


func max_jumps() -> int:
    return 1 + arsenal.data().extra_jumps


## Floor contact as the animation and camera see it (puppets get it from the snapshot).
func grounded() -> bool:
    return puppet_on_floor if puppet else is_on_floor()


func is_local() -> bool:
    return controller is PlayerController


func is_human() -> bool:
    return peer_id != 0


func jumps_left() -> int:
    return max_jumps() - _jumps_used


func center() -> Vector3:
    return global_position + Vector3(0, 0.65 if crouching else 0.95, 0)


func eye() -> Vector3:
    return global_position + Vector3(0, 1.0 if crouching else 1.45, 0)


# ---- crouch (L-Ctrl): half speed, capsule 1.15 -> 0.8, head hitbox lowered, no jump, stand up
# only with headroom. The figure has no crouch clip, so the hips drop procedurally.

func _update_crouch() -> void:
    var want := crouch_held and is_on_floor()
    if want and not crouching:
        _set_crouch(true)
    elif not want and crouching and has_headroom():
        _set_crouch(false)


func _set_crouch(on: bool) -> void:
    crouching = on
    var cap := _body_shape.shape as CapsuleShape3D
    cap.height = CROUCH_HEIGHT if on else STAND_HEIGHT
    _body_shape.position = Vector3(0, cap.height * 0.5, 0)
    _head_shape.position = Vector3(0, 0.9 if on else 1.4, 0)   # crouched head top at 1.26 m
    figure.set_crouch(on)


## Room to stand: the full standing silhouette (body capsule + head, top at 1.76 m) must be
## clear of world geometry. Starts above the floor's physics margin.
func has_headroom() -> bool:
    var cap := CapsuleShape3D.new()
    cap.radius = 0.3
    cap.height = 1.7
    var q := PhysicsShapeQueryParameters3D.new()
    q.shape = cap
    q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.12 + 0.85, 0))
    q.collision_mask = LAYER_WORLD
    q.exclude = [get_rid()]
    return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func facing() -> Vector3:
    return Vector3(-sin(yaw), 0.0, -cos(yaw))


func aim_dir() -> Vector3:
    return Vector3(0, 0, -1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)


## Where shots come from and go. Humans aim along their camera ray (set by the controller
## every tick, or carried in a client's input packet); bots and dummies shoot from the eye.
func get_aim_ray() -> Dictionary:
    if _aim_override:
        return {"origin": _aim_origin, "dir": _aim_dir}
    return {"origin": eye(), "dir": aim_dir()}


func set_aim_ray(origin: Vector3, dir: Vector3) -> void:
    _aim_override = true
    _aim_origin = origin
    _aim_dir = dir


func muzzle_position() -> Vector3:
    return arsenal.muzzle_position()


## Camera recoil hook; only a local PlayerController does something with it.
func apply_kick(deg: float) -> void:
    if controller != null and controller.has_method("apply_kick"):
        controller.apply_kick(deg)


func take_damage(amount: float, source: Character, _hit_pos: Vector3, impulse: Vector3,
        headshot: bool) -> Dictionary:
    if not alive or protection_left > 0.0 or amount <= 0.0 or not Game.match_active:
        return {"applied": false, "killed": false}
    if Game.mode == "party":
        # no PvP at the party: a hit is a hop and a cheer (replicated as a 0-damage event)
        party_hit()
        damaged.emit(0.0, source, headshot)
        return {"applied": true, "killed": false}
    hp = maxf(0.0, hp - amount)
    velocity += impulse
    if source != null and source.arsenal != null:
        last_hit_weapon = source.arsenal.data().display_name
    _flash = 1.0
    if amount >= 25.0:
        figure.play_action("hit", 0.3)
    damaged.emit(amount, source, headshot)
    health_changed.emit(hp, max_hp)
    if hp <= 0.0:
        Sfx.play("death", center())
        _die(source)
        return {"applied": true, "killed": true}
    Sfx.play("hurt", center(), -2.0, 0.12)
    return {"applied": true, "killed": false}


func drop_battery() -> void:
    if carrying != null:
        carrying.drop.call_deferred(global_position + Vector3(0, 0.1, 0))


## Party mode: being shot makes a toy hop, squeak and cheer. Never hurts.
func party_hit() -> void:
    if not puppet and velocity.y < PARTY_HOP * 0.5:
        velocity.y = PARTY_HOP
    figure.play_action("cheer", 0.9)
    _flash = 0.5
    Sfx.play("squeak", center(), 0.0, 0.3)
    if randf() < 0.35:
        Sfx.play("cheer", center(), -9.0, 0.25)


# ---- party zones (bouncy castle, moon corner, slide) ---------------------------------

func enter_zone(zone: Node) -> void:
    if not _zones.has(zone):
        _zones.append(zone)
    _apply_zones()


func exit_zone(zone: Node) -> void:
    _zones.erase(zone)
    _apply_zones()


func _apply_zones() -> void:
    zone_gravity_mult = 1.0
    zone_jump_mult = 1.0
    zone_bounce = false
    zone_push = Vector3.ZERO
    for z in _zones:
        if not is_instance_valid(z):
            continue
        match z.kind:
            PartyZone.Kind.BOUNCE:
                zone_jump_mult = maxf(zone_jump_mult, 2.0)
                zone_bounce = true
            PartyZone.Kind.MOON:
                zone_gravity_mult = 0.3
                zone_jump_mult = maxf(zone_jump_mult, 1.15)
            PartyZone.Kind.SLIDE:
                zone_push = z.push


func heal(amount: float) -> void:
    if alive:
        hp = minf(max_hp, hp + amount)
        health_changed.emit(hp, max_hp)


func _die(killer: Character) -> void:
    Game.trace("die:" + display_name)
    deaths += 1
    if killer != null and killer != self:
        killer.kills += 1
    _die_visual()
    drop_battery()
    died.emit(self, killer)


## Client: the server says this toy took damage (hp is the server's value after the hit).
func damage_remote(amount: float, source: Character, headshot: bool, hp_after: float) -> void:
    if not alive:
        return
    if Game.mode == "party":
        party_hit()
        damaged.emit(0.0, source, headshot)
        return
    hp = hp_after
    _flash = 1.0
    if source != null and source.arsenal != null:
        last_hit_weapon = source.arsenal.data().display_name
    if amount >= 25.0:
        figure.play_action("hit", 0.3)
    damaged.emit(amount, source, headshot)
    health_changed.emit(hp, max_hp)
    if hp > 0.0:
        Sfx.play("hurt", center(), -2.0, 0.12)


## Client: the server says this toy fell apart (scores arrive separately).
func die_remote(_killer: Character) -> void:
    if not alive:
        return
    Sfx.play("death", center())
    hp = 0.0
    _die_visual()
    health_changed.emit(hp, max_hp)


func _die_visual() -> void:
    alive = false
    velocity = Vector3.ZERO
    collision_layer = 0
    arsenal.trigger = false
    arsenal.alt = false
    figure.play_death()
    _death_serial += 1
    var serial := _death_serial
    get_tree().create_timer(DEATH_HIDE_DELAY).timeout.connect(func() -> void:
        if not alive and serial == _death_serial:
            Game.trace("hide:" + display_name)
            visible = false)


func respawn(at: Vector3, look_yaw := 0.0) -> void:
    Game.trace("respawn:" + display_name)
    _death_serial += 1
    global_position = at
    yaw = look_yaw
    pitch = 0.0
    velocity = Vector3.ZERO
    hp = max_hp
    alive = true
    protection_left = SPAWN_PROTECTION
    collision_layer = LAYER_CHARACTER
    visible = true
    _anim_on_floor = true
    _anim_fall_vy = 0.0
    figure.revive()
    arsenal.refill_all()
    arsenal.select(2)
    Sfx.play("respawn", center())
    health_changed.emit(hp, max_hp)
    respawned.emit()


func _build_team_ring() -> void:
    _team_ring = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.42
    torus.outer_radius = 0.5
    torus.rings = 24
    torus.ring_segments = 8
    _team_ring.mesh = torus
    _team_ring.position = Vector3(0, 0.04, 0)
    _team_ring.scale = Vector3(1, 0.25, 1)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(body_color, 0.85)
    _team_ring.material_override = m
    _team_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _team_ring.visible = team != 0
    add_child(_team_ring)
