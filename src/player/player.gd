class_name Player
extends CharacterBody3D
## Microvolts-style controller: constant run speed, no sprint, full air control,
## short snappy jump, melee grants a double jump. Body yaw follows the camera.

signal weapon_changed(slot: int, weapon_name: String)
signal health_changed(hp: int, max_hp: int)

const WEAPON_NAMES: Array[String] = [
    "Melee", "Rifle", "Shotgun", "Sniper", "Gatling", "Bazooka", "Grenade Launcher",
]
const SLOT_MELEE := 1
const SLOT_RIFLE := 2
const SLOT_GATLING := 5

@export var run_speed := 7.0
@export var ground_accel := 60.0
@export var air_accel := 18.0
@export var gravity := 30.0
@export var jump_velocity := 9.5
@export var pitch_limits_deg := Vector2(-65.0, 75.0)

var max_hp := 100
var hp := 100
var weapon_slot := SLOT_RIFLE
var previous_slot := SLOT_MELEE
var yaw := 0.0
var pitch := 0.0

var _jumps_left := 0
var _was_on_floor := false

@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _spring_arm: SpringArm3D = $CameraRig/Pitch/SpringArm
@onready var camera: Camera3D = $CameraRig/Pitch/SpringArm/Camera


func _ready() -> void:
    _spring_arm.add_excluded_object(get_rid())
    yaw = deg_to_rad(float(Game.arg("yaw", "0")))
    pitch = deg_to_rad(float(Game.arg("pitch", "-10")))
    _apply_look()
    weapon_changed.emit(weapon_slot, WEAPON_NAMES[weapon_slot - 1])
    health_changed.emit(hp, max_hp)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if Game.mouse_captured:
            yaw -= event.relative.x * Game.mouse_sensitivity
            pitch = clampf(
                pitch - event.relative.y * Game.mouse_sensitivity,
                deg_to_rad(pitch_limits_deg.x), deg_to_rad(pitch_limits_deg.y))
        return
    for i in range(1, 8):
        if event.is_action_pressed("weapon_%d" % i):
            _select_weapon(i)
            return
    if event.is_action_pressed("weapon_last"):
        _select_weapon(previous_slot)
    elif event.is_action_pressed("weapon_next"):
        _select_weapon(wrapi(weapon_slot + 1, 1, 8))
    elif event.is_action_pressed("weapon_prev"):
        _select_weapon(wrapi(weapon_slot - 1, 1, 8))


func _physics_process(delta: float) -> void:
    _apply_look()

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var wish := global_transform.basis * Vector3(input.x, 0.0, input.y)
    if wish.length_squared() > 1.0:
        wish = wish.normalized()
    wish *= run_speed * speed_multiplier()
    var accel := ground_accel if is_on_floor() else air_accel
    velocity.x = move_toward(velocity.x, wish.x, accel * delta)
    velocity.z = move_toward(velocity.z, wish.z, accel * delta)

    if is_on_floor():
        _jumps_left = max_jumps()
    else:
        if _was_on_floor and _jumps_left == max_jumps():
            _jumps_left -= 1  # walked off a ledge: no free ground jump
        velocity.y -= gravity * delta

    if Input.is_action_just_pressed("jump") and _jumps_left > 0:
        velocity.y = jump_velocity
        _jumps_left -= 1

    _was_on_floor = is_on_floor()
    move_and_slide()


func _apply_look() -> void:
    rotation.y = yaw
    _pitch_node.rotation.x = pitch


func max_jumps() -> int:
    return 2 if weapon_slot == SLOT_MELEE else 1


func speed_multiplier() -> float:
    match weapon_slot:
        SLOT_MELEE:
            return 1.12
        SLOT_GATLING:
            return 0.8
        _:
            return 1.0


func _select_weapon(slot: int) -> void:
    if slot == weapon_slot or slot < 1 or slot > 7:
        return
    previous_slot = weapon_slot
    weapon_slot = slot
    weapon_changed.emit(slot, WEAPON_NAMES[slot - 1])
