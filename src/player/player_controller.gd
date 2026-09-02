class_name PlayerController
extends Node3D
## The local human. Reads input, drives the over-shoulder camera, zoom, recoil, shake, bob and
## the swap dip. Attached as a child of the Character it controls; the Character calls feed()
## at the top of every physics tick, so the body never knows whether a keyboard, a bot brain or
## a network packet is driving it.

const BASE_FOV := 70.0
const PITCH_LIMITS_DEG := Vector2(-65.0, 75.0)
const SCENE_PATH := "res://src/player/player_controller.tscn"

var character: Character
var input_enabled := true   ## tests and debug captures drive the character directly
var camera: Camera3D
var _recoil := 0.0
var _trauma := 0.0
var _bob_t := 0.0
var _dip := 0.0             ## weapon-swap camera dip (1 = just switched)
var _noise := FastNoiseLite.new()
var _autofire_frame := -1
var _frame := 0
var _pitch_node: Node3D
var _spring_arm: SpringArm3D


## Instance the controller scene under `c` (which must already be inside the tree).
static func attach(c: Character) -> PlayerController:
    var ctrl := (load(SCENE_PATH) as PackedScene).instantiate() as PlayerController
    c.add_child(ctrl)
    return ctrl


func _ready() -> void:
    character = get_parent() as Character
    _pitch_node = $CameraRig/Pitch
    _spring_arm = $CameraRig/Pitch/SpringArm
    camera = $CameraRig/Pitch/SpringArm/Camera
    character.controller = self
    character.add_to_group("local_player")
    _spring_arm.add_excluded_object(character.get_rid())
    camera.add_child(PostFx.new())
    camera.current = true
    _noise.frequency = 2.0
    Vfx.shake.connect(_on_world_shake)
    character.arsenal.hit_confirmed.connect(_on_hit_confirmed)
    character.arsenal.weapon_changed.connect(_on_weapon_changed)
    character.damaged.connect(_on_damaged)
    if Game.has_arg("slot"):
        character.arsenal.select.call_deferred(int(Game.arg("slot")))
    if Game.has_arg("orbit"):   # debug: orbit the camera around the figure (degrees)
        $CameraRig.rotation.y = deg_to_rad(float(Game.arg("orbit")))
    if Game.has_arg("pos"):     # debug: start position "x,y,z"
        var parts := Game.arg("pos").split(",")
        if parts.size() == 3:
            character.global_position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
    if Game.has_arg("autofire"):   # debug: hold the trigger from frame N on
        input_enabled = false
        _autofire_frame = int(Game.arg("autofire", "40"))
    if Game.has_arg("yaw"):
        character.yaw = deg_to_rad(float(Game.arg("yaw")))
    character.pitch = deg_to_rad(float(Game.arg("pitch", "-10")))
    _pitch_node.rotation.x = character.pitch
    Game.set_mouse_captured(not Game.headless and not Game.has_arg("screenshot"))


func _unhandled_input(event: InputEvent) -> void:
    if not input_enabled or character == null:
        return
    if event is InputEventMouseMotion:
        if Game.mouse_captured and character.alive:
            var sens := Game.mouse_sensitivity
            var zf := character.arsenal.zoom_fov()
            if zf > 0.0:
                sens *= clampf(zf / BASE_FOV, 0.12, 1.0) * 1.6
            character.yaw -= event.relative.x * sens
            character.pitch = clampf(character.pitch - event.relative.y * sens,
                deg_to_rad(PITCH_LIMITS_DEG.x), deg_to_rad(PITCH_LIMITS_DEG.y))
        return
    if not Game.mouse_captured:
        if event.is_action_pressed("menu"):
            Game.to_menu()
        return
    var arsenal := character.arsenal
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


## Called by the Character at the top of its physics tick: write this tick's inputs.
func feed(c: Character, _delta: float) -> void:
    if input_enabled:
        if c.alive and Game.mouse_captured:
            var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
            c.wish_dir = (Basis(Vector3.UP, c.yaw) * Vector3(input.x, 0.0, input.y)).limit_length(1.0)
            if Input.is_action_just_pressed("jump"):
                c.jump_pressed = true
            c.arsenal.trigger = Input.is_action_pressed("fire")
            c.arsenal.alt = Input.is_action_pressed("alt_fire")
        else:
            c.wish_dir = Vector3.ZERO
            c.arsenal.trigger = false
            c.arsenal.alt = false
    # shots go where the crosshair points: a ray from the camera through screen centre
    c.set_aim_ray(camera.global_position, -camera.global_transform.basis.z)


func _process(delta: float) -> void:
    if character == null:
        return
    _frame += 1
    var arsenal := character.arsenal
    if _autofire_frame >= 0 and _frame >= _autofire_frame:
        # semi-auto weapons need a release between shots: pulse the trigger
        arsenal.trigger = arsenal.data().auto or ((_frame - _autofire_frame) / 8) % 2 == 0
    _recoil = lerpf(_recoil, 0.0, minf(1.0, delta * 10.0))
    _trauma = maxf(0.0, _trauma - delta * 1.6)
    _dip = maxf(0.0, _dip - delta * 7.0)
    var shake := _trauma * _trauma
    var t := Time.get_ticks_msec() * 0.001
    var sx := _noise.get_noise_2d(t * 40.0, 0.0) * shake * 0.05
    var sy := _noise.get_noise_2d(0.0, t * 40.0) * shake * 0.05
    var sz := _noise.get_noise_2d(t * 40.0, 100.0) * shake * 0.03
    # gentle run bob
    var speed := Vector2(character.velocity.x, character.velocity.z).length()
    if character.alive and character.grounded() and speed > 2.0:
        _bob_t += delta * 11.0
    var bob := sin(_bob_t) * 0.012 * clampf(speed / character.run_speed, 0.0, 1.0)
    var dip := _dip * _dip * 0.045
    _pitch_node.rotation = Vector3(character.pitch + _recoil + sy - dip * 0.35, sx, sz)
    _pitch_node.position = Vector3(0, bob - dip, 0)
    var zf := arsenal.zoom_fov()
    var target_fov := zf if zf > 0.0 else BASE_FOV
    # the sniper scope snaps (quickscope), the rifle zoom eases
    var zoom_rate := 30.0 if arsenal.data().scope_overlay else 14.0
    camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * zoom_rate))


func apply_kick(deg: float) -> void:
    _recoil += deg_to_rad(deg)
    add_trauma(deg * 0.08)


func add_trauma(amount: float) -> void:
    _trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_weapon_changed(_slot: int, _data: WeaponData) -> void:
    _dip = 1.0


## Sniper kills get the "crunch": a freeze-frame, a heavy kick and a layered thud.
func _on_hit_confirmed(killed: bool, headshot: bool) -> void:
    if not killed or character.arsenal.slot != 4:
        return
    add_trauma(0.6)
    _recoil += deg_to_rad(1.2)
    Sfx.play_ui("melee_hit", 3.0, 0.0)
    Sfx.play_ui("explosion", -13.0, 0.0)
    Game.hitstop(0.12 if headshot else 0.09)


func _on_world_shake(pos: Vector3, strength: float) -> void:
    var dist := character.global_position.distance_to(pos)
    add_trauma(strength * clampf(1.0 - dist / 22.0, 0.0, 1.0))


func _on_damaged(amount: float, _source: Character, _headshot: bool) -> void:
    add_trauma(clampf(amount / 80.0, 0.15, 0.6))
