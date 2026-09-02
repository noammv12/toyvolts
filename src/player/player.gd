class_name Player
extends Character
## The local human: reads input, drives the over-shoulder camera, zoom, recoil.

const BASE_FOV := 70.0
const PITCH_LIMITS_DEG := Vector2(-65.0, 75.0)

var input_enabled := true   ## tests drive the character directly
var _recoil := 0.0

@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _spring_arm: SpringArm3D = $CameraRig/Pitch/SpringArm
@onready var camera: Camera3D = $CameraRig/Pitch/SpringArm/Camera


func _ready() -> void:
    super()
    add_to_group("player")
    _spring_arm.add_excluded_object(get_rid())
    yaw = deg_to_rad(float(Game.arg("yaw", "0")))
    pitch = deg_to_rad(float(Game.arg("pitch", "-10")))
    _pitch_node.rotation.x = pitch
    Game.set_mouse_captured(not Game.headless and not Game.has_arg("screenshot"))


func _unhandled_input(event: InputEvent) -> void:
    if not input_enabled:
        return
    if event is InputEventMouseMotion:
        if Game.mouse_captured and alive:
            var sens := Game.mouse_sensitivity
            if arsenal.aiming:
                sens *= arsenal.data().zoom_sens_mult
            yaw -= event.relative.x * sens
            pitch = clampf(pitch - event.relative.y * sens,
                deg_to_rad(PITCH_LIMITS_DEG.x), deg_to_rad(PITCH_LIMITS_DEG.y))
        return
    if not Game.mouse_captured:
        if event.is_action_pressed("menu"):
            Game.to_menu()
        return
    for i in range(1, 8):
        if event.is_action_pressed("weapon_%d" % i):
            arsenal.select(i)
            return
    if event.is_action_pressed("weapon_last"):
        arsenal.select_previous()
    elif event.is_action_pressed("weapon_next"):
        arsenal.select_offset(1)
    elif event.is_action_pressed("weapon_prev"):
        arsenal.select_offset(-1)
    elif event.is_action_pressed("reload"):
        arsenal.reload()


func _physics_process(delta: float) -> void:
    if input_enabled:
        if alive and Game.mouse_captured:
            var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
            wish_dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)).limit_length(1.0)
            if Input.is_action_just_pressed("jump"):
                jump_pressed = true
            arsenal.trigger = Input.is_action_pressed("fire")
            arsenal.alt = Input.is_action_pressed("alt_fire")
        else:
            wish_dir = Vector3.ZERO
            arsenal.trigger = false
            arsenal.alt = false
    super(delta)


func _process(delta: float) -> void:
    super(delta)
    _recoil = lerpf(_recoil, 0.0, minf(1.0, delta * 10.0))
    _pitch_node.rotation.x = pitch + _recoil
    var target_fov := arsenal.data().zoom_fov if arsenal.aiming else BASE_FOV
    camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * 14.0))


func apply_kick(deg: float) -> void:
    _recoil += deg_to_rad(deg)


## Shots go where the crosshair points: a ray from the camera through screen centre.
func get_aim_ray() -> Dictionary:
    return {"origin": camera.global_position, "dir": -camera.global_transform.basis.z}
