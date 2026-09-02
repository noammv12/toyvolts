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
var _bob := 0.0
var _shake_offset := Vector3.ZERO
var _dip := 0.0             ## weapon-swap camera dip (1 = just switched)
var _land_dip := 0.0        ## landing camera dip (1 = hit the floor hard)
var _noise := FastNoiseLite.new()
var _autofire_frame := -1
var _move_hold := Vector2.ZERO   ## --move=x,z: capture runs/walks without a keyboard
var _jump_frame := -1            ## --jump=N: capture jumps and landings
var _frame := 0
var _smoke := false          ## --net_smoke: aim at the nearest enemy and hold fire (loopback test)
var _smoke_ticks := 0
var _smoke_shots := 0
var _pitch_node: Node3D
var _spring_arm: SpringArm3D
var _nav: NavigationAgent3D   ## smoke mode only
var _cine_cam: Camera3D       ## party finale: an orbiting camera takes over for a while
var _crouch_cam := 0.0        ## camera rig drop while crouched (eases)
var _rig_y := 1.55
var _cine_left := 0.0
var _cine_t := 0.0
var _cine_center := Vector3.ZERO
var _cine_mode := "room"      ## "room" = the party finale orbit, "death" = around your own parts
var _cine_ray: PhysicsRayQueryParameters3D   ## keeps the death camera out of the furniture


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
    _rig_y = $CameraRig.position.y
    camera.add_child(PostFx.new())
    camera.current = true
    _noise.frequency = 2.0
    Vfx.shake.connect(_on_world_shake)
    character.arsenal.hit_confirmed.connect(_on_hit_confirmed)
    character.arsenal.weapon_changed.connect(_on_weapon_changed)
    character.damaged.connect(_on_damaged)
    character.fell_apart.connect(_on_fell_apart)
    character.respawned.connect(_on_respawned)
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
    if Game.has_arg("move"):       # debug: hold a move direction "x,z" (+z = forward)
        input_enabled = false
        var move := Game.arg("move").split(",")
        if move.size() == 2:
            _move_hold = Vector2(float(move[0]), float(move[1]))
    if Game.has_arg("jump"):       # debug: jump on frame N, then every 90 frames
        input_enabled = false
        _jump_frame = int(Game.arg("jump", "40"))
    if Game.has_arg("net_smoke"):
        input_enabled = false
        _smoke = true
        character.arsenal.fired.connect(func(_d: WeaponData) -> void: _smoke_shots += 1)
        _nav = NavigationAgent3D.new()
        _nav.path_desired_distance = 0.7
        _nav.target_desired_distance = 1.2
        _nav.path_max_distance = 4.0
        character.add_child(_nav)
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
    if _smoke:
        _smoke_feed(c)
        c.set_aim_ray(c.eye(), c.aim_dir())
        return
    if input_enabled:
        if c.alive and Game.mouse_captured and _cine_left <= 0.0:
            var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
            c.wish_dir = (Basis(Vector3.UP, c.yaw) * Vector3(input.x, 0.0, input.y)).limit_length(1.0)
            if Input.is_action_just_pressed("jump"):
                c.jump_pressed = true
            c.crouch_held = Input.is_action_pressed("crouch")
            c.arsenal.trigger = Input.is_action_pressed("fire")
            c.arsenal.alt = Input.is_action_pressed("alt_fire")
        else:
            c.wish_dir = Vector3.ZERO
            c.crouch_held = false
            c.arsenal.trigger = false
            c.arsenal.alt = false
    if _move_hold != Vector2.ZERO:   # capture: run without a keyboard
        c.wish_dir = (Basis(Vector3.UP, c.yaw) * Vector3(_move_hold.x, 0.0, -_move_hold.y)).limit_length(1.0)
    if _jump_frame >= 0 and _frame >= _jump_frame and (_frame - _jump_frame) % 90 == 0:
        c.jump_pressed = true
    if Game.has_arg("crouch"):   # capture: hold the crouch
        c.crouch_held = true
    # shots go where the crosshair points: a ray from the camera through screen centre, posed
    # with THIS tick's look (the body applies yaw right after feed; the rig would lag a tick)
    c.rotation.y = c.yaw
    _pose_camera()
    c.set_aim_ray(camera.global_position, -camera.global_transform.basis.z)


## Loopback smoke test: face the nearest living enemy and hold the rifle trigger.
func _smoke_feed(c: Character) -> void:
    var best: Character = null
    var best_d := INF
    for node in get_tree().get_nodes_in_group("characters"):
        var other := node as Character
        if other == null or other == c or not other.alive or (c.team != 0 and other.team == c.team):
            continue
        var d := c.global_position.distance_to(other.global_position)
        if d < best_d:
            best_d = d
            best = other
    c.wish_dir = Vector3.ZERO
    if best == null or not c.alive:
        c.arsenal.trigger = false
        return
    var dir := (best.center() - c.eye()).normalized()
    c.yaw = atan2(-dir.x, -dir.z)
    c.pitch = asin(clampf(dir.y, -1.0, 1.0))
    var los := PhysicsRayQueryParameters3D.create(c.eye(), best.center(), Character.LAYER_WORLD)
    var clear := c.get_world_3d().direct_space_state.intersect_ray(los).is_empty()
    if best_d > 6.0 or not clear:   # walk the navmesh toward the target like a bot would
        if _nav.target_position.distance_to(best.global_position) > 1.5:
            _nav.target_position = best.global_position
        if not _nav.is_navigation_finished():
            var step := _nav.get_next_path_position() - c.global_position
            if step.y > 0.45 and c.is_on_floor():
                c.jump_pressed = true
            step.y = 0.0
            c.wish_dir = step.normalized() if step.length() > 0.05 else Vector3.ZERO
    if c.arsenal.slot != 2:
        c.arsenal.select(2)
    c.arsenal.trigger = c.arsenal.swap_left <= 0.0 and clear
    _smoke_ticks += 1
    if _smoke_ticks % 120 == 1:
        print("[smoke] tick %d: target %s at %.1f m los=%s, hp %.0f, local shots %d" % [_smoke_ticks, best.display_name, best_d, clear, c.hp, _smoke_shots])


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
    _crouch_cam = lerpf(_crouch_cam, Character.CROUCH_CAMERA_DROP if character.crouching else 0.0, minf(1.0, delta * 12.0))
    $CameraRig.position.y = _rig_y - _crouch_cam
    _dip = maxf(0.0, _dip - delta * 7.0)
    _land_dip = maxf(0.0, _land_dip - delta * 4.5)
    var shake := _trauma * _trauma
    var t := Time.get_ticks_msec() * 0.001
    var sx := _noise.get_noise_2d(t * 40.0, 0.0) * shake * 0.05
    var sy := _noise.get_noise_2d(0.0, t * 40.0) * shake * 0.05
    var sz := _noise.get_noise_2d(t * 40.0, 100.0) * shake * 0.03
    # gentle run bob
    var speed := Vector2(character.velocity.x, character.velocity.z).length()
    if character.alive and character.grounded() and speed > 2.0:
        _bob_t += delta * 11.0
    _bob = sin(_bob_t) * 0.012 * clampf(speed / character.run_speed, 0.0, 1.0)
    _shake_offset = Vector3(sy, sx, sz)
    _pose_camera()
    var zf := arsenal.zoom_fov()
    var target_fov := zf if zf > 0.0 else BASE_FOV
    # the sniper scope snaps (quickscope), the rifle zoom eases
    var zoom_rate := 30.0 if arsenal.data().scope_overlay else 14.0
    camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * zoom_rate))
    if _cine_left > 0.0:
        _cine_left -= delta
        _cine_t += delta
        if _cine_mode == "death":
            var a := _cine_t * 0.55
            var r := 3.9 + 0.5 * sin(_cine_t * 0.7)
            var eye := _cine_center + Vector3(sin(a) * r, 1.8 + 0.3 * sin(_cine_t * 0.9), cos(a) * r)
            _cine_cam.global_position = _clear_of_walls(_cine_center + Vector3(0, 0.5, 0), eye)
            _cine_cam.look_at(_cine_center + Vector3(0, 0.2, 0), Vector3.UP)
        else:
            var a := _cine_t * 0.42
            var r := 19.0 - 2.5 * sin(_cine_t * 0.3)   # inside the walls, clear of the mirror ball and the pinata
            _cine_cam.global_position = Vector3(_cine_center.x + sin(a) * r, 9.0 + 1.0 * sin(_cine_t * 0.5), _cine_center.z + cos(a) * r)
            _cine_cam.look_at(_cine_center + Vector3(0, 2.0, 0), Vector3.UP)
        if _cine_left <= 0.0:
            end_cinematic()


## Hand the view to an orbiting camera for `seconds`, then give it back.
##   "room"  - the party finale, high and wide around the cake
##   "death" - close around the pile of parts you just became
func cinematic(center: Vector3, seconds: float, mode := "room") -> void:
    _cine_mode = mode
    _cine_center = center
    _cine_left = seconds
    _cine_t = 0.0
    if _cine_cam == null:
        _cine_cam = Camera3D.new()
        _cine_cam.fov = 62.0
        _cine_cam.near = 0.05
        get_tree().current_scene.add_child(_cine_cam)
        # the toon outline is a full-screen quad under the active camera: bring it along
        var fx := get_tree().get_first_node_in_group("post_fx")
        if fx != null:
            fx.reparent(_cine_cam, false)
            if Game.has_arg("no_postfx"):
                fx.visible = false
    _cine_cam.current = true


## A free camera would sit inside the sofa. Pull it in to the first wall between the subject
## and where it wants to be, the way the player's SpringArm does.
func _clear_of_walls(from: Vector3, want: Vector3) -> Vector3:
    if _cine_ray == null:
        _cine_ray = PhysicsRayQueryParameters3D.new()
        _cine_ray.collision_mask = Character.LAYER_WORLD
    _cine_ray.from = from
    _cine_ray.to = want
    var hit := get_world_3d().direct_space_state.intersect_ray(_cine_ray)
    if hit.is_empty():
        return want
    var pulled: Vector3 = hit.position + (from - want).normalized() * 0.3
    return Vector3(pulled.x, maxf(pulled.y, from.y - 0.2), pulled.z)


## Give the view back to the player camera (also called early when you respawn).
func end_cinematic() -> void:
    _cine_left = 0.0
    if _cine_cam == null:
        return
    var fx := get_tree().get_first_node_in_group("post_fx")
    if fx != null and fx.get_parent() == _cine_cam:
        fx.reparent(camera, false)   # the outline quad goes back to the player camera
    camera.current = true
    _cine_cam.queue_free()
    _cine_cam = null


func cinematic_active() -> bool:
    return _cine_left > 0.0


## Rig pose from the current look, recoil, shake, bob, swap dip and landing dip.
func _pose_camera() -> void:
    var dip := _dip * _dip * 0.045
    var land := _land_dip * _land_dip * 0.16
    _pitch_node.rotation = Vector3(character.pitch + _recoil + _shake_offset.x - dip * 0.35 - land * 0.5,
        _shake_offset.y, _shake_offset.z)
    _pitch_node.position = Vector3(0, _bob - dip - land, 0)


## Landing thump: a short camera drop proportional to how hard the toy hit the floor (0..1).
func apply_land_dip(hard: float) -> void:
    _land_dip = maxf(_land_dip, clampf(hard, 0.0, 1.0))
    add_trauma(hard * 0.22)


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


## Death camera: lift off the toy and orbit the pile of parts until the respawn.
func _on_fell_apart() -> void:
    if Game.headless or _cine_left > 0.0:
        return
    var rules := get_tree().get_first_node_in_group("match") as MatchController
    var seconds: float = rules.respawn_delay if rules != null else 3.0
    cinematic(character.global_position + Vector3(0, 0.35, 0), maxf(0.7, seconds - 0.3), "death")


func _on_respawned() -> void:
    if _cine_mode == "death":
        end_cinematic()


func _on_world_shake(pos: Vector3, strength: float) -> void:
    var dist := character.global_position.distance_to(pos)
    add_trauma(strength * clampf(1.0 - dist / 22.0, 0.0, 1.0))


func _on_damaged(amount: float, _source: Character, _headshot: bool) -> void:
    if amount <= 0.0:
        add_trauma(0.12)   # party hop
        return
    add_trauma(clampf(amount / 80.0, 0.15, 0.6))
