class_name Character
extends CharacterBody3D
## Shared body for the player, bots and target dummies: Microvolts-style movement
## (constant run speed, no sprint, full air control, snappy jump, melee double jump),
## health with head/body hitboxes, the seven-slot Arsenal and an animated Figure.
## Controllers write `yaw`, `pitch`, `wish_dir`, `jump_pressed` and the arsenal triggers.

signal died(victim: Character, killer: Character)
signal health_changed(hp: float, max_hp: float)
signal damaged(amount: float, source: Character, headshot: bool)
signal respawned()

const HEAD_SHAPE_INDEX := 1
const LAYER_WORLD := 1
const LAYER_CHARACTER := 2
const SPAWN_PROTECTION := 2.0
const DEATH_HIDE_DELAY := 1.1

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
var spawn_home := Vector3.ZERO
var last_hit_weapon := ""
var respawn_at_msec := 0

# controller inputs
var yaw := 0.0
var pitch := 0.0
var wish_dir := Vector3.ZERO
var jump_pressed := false

var _jumps_left := 0
var _was_on_floor := false
var _flash := 0.0
var _death_serial := 0
var _team_ring: MeshInstance3D
var _step_t := 0.0

@onready var arsenal: Arsenal = $Arsenal
@onready var weapon_holder: Node3D = $WeaponHolder
@onready var figure: Figure = $Figure


func _ready() -> void:
    add_to_group("characters")
    spawn_home = global_position
    figure.setup(Skins.path(model_id), body_color, 0.35 if team != 0 else 0.0)
    _build_team_ring()
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
        figure.set_locomotion(v, is_on_floor(), delta)
        figure.set_pitch(pitch)
        figure.set_aiming(arsenal.data().kind != WeaponData.Kind.MELEE)


func _physics_process(delta: float) -> void:
    rotation.y = yaw
    weapon_holder.rotation.x = pitch
    protection_left = maxf(0.0, protection_left - delta)
    if not alive:
        velocity = Vector3.ZERO
        jump_pressed = false
        return

    var wish := wish_dir * run_speed * arsenal.data().run_speed_mult
    var accel := ground_accel if is_on_floor() else air_accel
    velocity.x = move_toward(velocity.x, wish.x, accel * delta)
    velocity.z = move_toward(velocity.z, wish.z, accel * delta)

    if is_on_floor():
        _jumps_left = max_jumps()
        if not _was_on_floor:
            Sfx.play("land", global_position, -2.0)
        var speed := Vector2(velocity.x, velocity.z).length()
        if speed > 2.0:
            _step_t -= delta * speed / run_speed
            if _step_t <= 0.0:
                _step_t = 0.34
                Sfx.play("footstep", global_position, 0.0, 0.15)
    else:
        if _was_on_floor and _jumps_left == max_jumps():
            _jumps_left -= 1  # walked off a ledge: no free ground jump
        velocity.y -= gravity * delta

    if jump_pressed and _jumps_left > 0:
        velocity.y = jump_velocity
        _jumps_left -= 1
        Sfx.play(Sfx.pick(["jump_a", "jump_b", "jump_c"]), global_position)
    jump_pressed = false

    _was_on_floor = is_on_floor()
    move_and_slide()


func max_jumps() -> int:
    return 1 + arsenal.data().extra_jumps


func center() -> Vector3:
    return global_position + Vector3(0, 0.95, 0)


func eye() -> Vector3:
    return global_position + Vector3(0, 1.45, 0)


func facing() -> Vector3:
    return Vector3(-sin(yaw), 0.0, -cos(yaw))


func aim_dir() -> Vector3:
    return Vector3(0, 0, -1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)


## Where shots come from and go. The player overrides this with the camera ray.
func get_aim_ray() -> Dictionary:
    return {"origin": eye(), "dir": aim_dir()}


func muzzle_position() -> Vector3:
    return arsenal.muzzle_position()


## Camera recoil hook; only the local player does something with it.
func apply_kick(_deg: float) -> void:
    pass


func take_damage(amount: float, source: Character, _hit_pos: Vector3, impulse: Vector3,
        headshot: bool) -> Dictionary:
    if not alive or protection_left > 0.0 or amount <= 0.0 or not Game.match_active:
        return {"applied": false, "killed": false}
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


func heal(amount: float) -> void:
    if alive:
        hp = minf(max_hp, hp + amount)
        health_changed.emit(hp, max_hp)


func _die(killer: Character) -> void:
    Game.trace("die:" + display_name)
    alive = false
    deaths += 1
    if killer != null and killer != self:
        killer.kills += 1
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
    died.emit(self, killer)


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
