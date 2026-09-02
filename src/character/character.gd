class_name Character
extends CharacterBody3D
## Shared body for the player, bots and target dummies: Microvolts-style movement
## (constant run speed, no sprint, full air control, snappy jump, melee double jump),
## health with head/body hitboxes, and the seven-slot Arsenal.
## Controllers write `yaw`, `pitch`, `wish_dir`, `jump_pressed` and the arsenal triggers.

signal died(victim: Character, killer: Character)
signal health_changed(hp: float, max_hp: float)
signal damaged(amount: float, source: Character, headshot: bool)
signal respawned()

const HEAD_SHAPE_INDEX := 1
const LAYER_WORLD := 1
const LAYER_CHARACTER := 2
const SPAWN_PROTECTION := 2.0
const TOON: Shader = preload("res://shaders/toon.gdshader")

@export var display_name := "Toy"
@export var team := 0
@export var body_color := Color(0.95, 0.42, 0.2)
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
var spawn_home := Vector3.ZERO

# controller inputs
var yaw := 0.0
var pitch := 0.0
var wish_dir := Vector3.ZERO
var jump_pressed := false

var _jumps_left := 0
var _was_on_floor := false
var _body_mat: ShaderMaterial
var _head_mat: ShaderMaterial
var _flash := 0.0

@onready var arsenal: Arsenal = $Arsenal
@onready var weapon_holder: Node3D = $WeaponHolder
@onready var body_mesh: MeshInstance3D = $Body
@onready var head_mesh: MeshInstance3D = $HeadMesh


func _ready() -> void:
    add_to_group("characters")
    spawn_home = global_position
    _body_mat = ShaderMaterial.new()
    _body_mat.shader = TOON
    _body_mat.set_shader_parameter("albedo", body_color)
    body_mesh.material_override = _body_mat
    _head_mat = ShaderMaterial.new()
    _head_mat.shader = TOON
    _head_mat.set_shader_parameter("albedo", body_color.lightened(0.35))
    head_mesh.material_override = _head_mat
    health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
    _flash = maxf(0.0, _flash - delta * 6.0)
    var f := _flash
    if protection_left > 0.0:
        f = maxf(f, 0.25 + 0.2 * sin(Time.get_ticks_msec() * 0.02))
    _body_mat.set_shader_parameter("flash", f)
    _head_mat.set_shader_parameter("flash", f)


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
    else:
        if _was_on_floor and _jumps_left == max_jumps():
            _jumps_left -= 1  # walked off a ledge: no free ground jump
        velocity.y -= gravity * delta

    if jump_pressed and _jumps_left > 0:
        velocity.y = jump_velocity
        _jumps_left -= 1
    jump_pressed = false

    _was_on_floor = is_on_floor()
    move_and_slide()


func max_jumps() -> int:
    return 1 + arsenal.data().extra_jumps


func center() -> Vector3:
    return global_position + Vector3(0, 1.0, 0)


func eye() -> Vector3:
    return global_position + Vector3(0, 1.6, 0)


func facing() -> Vector3:
    return Vector3(-sin(yaw), 0.0, -cos(yaw))


func aim_dir() -> Vector3:
    return Vector3(0, 0, -1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)


## Where shots come from and go. The player overrides this with the camera ray.
func get_aim_ray() -> Dictionary:
    return {"origin": eye(), "dir": aim_dir()}


func muzzle_position() -> Vector3:
    return weapon_holder.global_position - weapon_holder.global_transform.basis.z * 0.6


## Camera recoil hook; only the local player does something with it.
func apply_kick(_deg: float) -> void:
    pass


func take_damage(amount: float, source: Character, _hit_pos: Vector3, impulse: Vector3,
        headshot: bool) -> Dictionary:
    if not alive or protection_left > 0.0 or amount <= 0.0:
        return {"applied": false, "killed": false}
    hp = maxf(0.0, hp - amount)
    velocity += impulse
    _flash = 1.0
    damaged.emit(amount, source, headshot)
    health_changed.emit(hp, max_hp)
    if hp <= 0.0:
        _die(source)
        return {"applied": true, "killed": true}
    return {"applied": true, "killed": false}


func heal(amount: float) -> void:
    if alive:
        hp = minf(max_hp, hp + amount)
        health_changed.emit(hp, max_hp)


func _die(killer: Character) -> void:
    alive = false
    deaths += 1
    if killer != null and killer != self:
        killer.kills += 1
    velocity = Vector3.ZERO
    collision_layer = 0
    visible = false
    arsenal.trigger = false
    arsenal.alt = false
    died.emit(self, killer)


func respawn(at: Vector3, look_yaw := 0.0) -> void:
    global_position = at
    yaw = look_yaw
    pitch = 0.0
    velocity = Vector3.ZERO
    hp = max_hp
    alive = true
    protection_left = SPAWN_PROTECTION
    collision_layer = LAYER_CHARACTER
    visible = true
    arsenal.refill_all()
    arsenal.select(2)
    health_changed.emit(hp, max_hp)
    respawned.emit()
