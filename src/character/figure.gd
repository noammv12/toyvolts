class_name Figure
extends Node3D
## Animated toy figure. Loads a KayKit character GLB, routes its materials through the toon
## shader, builds an AnimationTree (locomotion blend space + air + full-body one-shot beats +
## upper-body aim pose + upper-body one-shot actions), exposes a right-hand grip for weapon
## models and a chest/head aim tilt. Character feeds it velocity, floor state, pitch and events.

const MODEL_SCALE := 0.76
const FACE_FIX_ROT_Y := PI      ## KayKit rigs face +Z; Godot forward is -Z
const TOON: Shader = preload("res://shaders/toon.gdshader")
const SKELETON_TRACK_PREFIX := "Rig/Skeleton3D:"
const AIM_POSE := "2H_Ranged_Aiming"   ## two-handed hold; AimModifier lifts the arms to chest height
const MELEE_POSE := "2H_Melee_Idle"    ## both hands on the shovel when melee is out
const WALK_AT := 0.45                  ## blend-space y where the walk clip sits (fraction of run speed)
const LEAN_DEG := 6.0                  ## roll into a strafe
const SQUASH := 0.35                   ## landing squash: scale x/z up, y down by this fraction
const UPPER_BONES := [
    "chest", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
    "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "head",
    "elbowIK.l", "handIK.l", "elbowIK.r", "handIK.r",
]
const LOOPING := [
    "Idle", "Running_A", "Running_B", "Walking_A", "Walking_Backwards", "Running_Strafe_Left",
    "Running_Strafe_Right", "Jump_Idle", "2H_Ranged_Aiming", "1H_Ranged_Aiming", "2H_Melee_Idle",
    "Unarmed_Idle",
]
const ACTIONS := {
    "fire": "2H_Ranged_Shoot",
    "fire_1h": "1H_Ranged_Shoot",
    "melee_light": "1H_Melee_Attack_Slice_Horizontal",
    "melee_up": "1H_Melee_Attack_Slice_Diagonal",
    "melee_over": "1H_Melee_Attack_Chop",
    "melee_heavy": "2H_Melee_Attack_Chop",
    "reload": "2H_Ranged_Reload",
    "hit": "Hit_A",
    "hit_back": "Hit_B",
    "throw": "Throw",
    "cheer": "Cheer",
}
## Full-body beats: they play UNDER the aim pose, so the legs move and the gun stays up.
const BODY_ACTIONS := {
    "jump_start": "Jump_Start",
    "jump_land": "Jump_Land",
    "jump_double": "Jump_Full_Short",
}

static var _scene_cache := {}

var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var tree: AnimationTree
var hand: BoneAttachment3D
var grip: Node3D                ## weapon models go here; local -Z is the barrel direction
var aim_modifier: AimModifier
var mats: Array[ShaderMaterial] = []
var hat: Node3D                 ## party hat, posed from the head bone every frame (party mode)
var last_action := ""           ## the last upper-body one-shot, for tests and captures
var last_body_action := ""      ## the last full-body beat
var ready_ok := false
var _head_idx := -1

var _loco := Vector2.ZERO
var _air := 0.0
var _aim := 0.0
var _aim_target := 0.0
var _melee_pose := 0.0
var _melee_target := 0.0
var _lean := 0.0
var _flash_applied := -1.0
var _scale_tween: Tween


func setup(model_path: String, tint: Color = Color.WHITE, tint_mix := 0.0) -> void:
    if model != null:
        model.queue_free()
        model = null
    hat = null
    mats.clear()
    var scene: PackedScene = _scene_cache.get(model_path)
    if scene == null:
        scene = load(model_path) as PackedScene
        if scene == null:
            push_error("Figure: cannot load " + model_path)
            return
        _scene_cache[model_path] = scene
    model = scene.instantiate() as Node3D
    model.scale = Vector3.ONE * MODEL_SCALE
    model.rotation.y = FACE_FIX_ROT_Y
    add_child(model)
    skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
    anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if skeleton == null or anim_player == null:
        push_error("Figure: no skeleton/animation player in " + model_path)
        return
    _hide_accessories()
    _apply_materials(tint, tint_mix)
    _set_loops()
    _build_tree()
    _setup_hand()
    _setup_aim()
    ready_ok = true


# ---- per-frame state ------------------------------------------------------------

## local_vel: x = strafe (+right), y = forward, both normalized to run speed.
func set_locomotion(local_vel: Vector2, on_floor: bool, delta: float) -> void:
    if not ready_ok:
        return
    _loco = _loco.lerp(local_vel.limit_length(1.0), minf(1.0, delta * 12.0))
    _air = lerpf(_air, 0.0 if on_floor else 1.0, minf(1.0, delta * 10.0))
    _aim = lerpf(_aim, _aim_target, minf(1.0, delta * 8.0))
    _melee_pose = lerpf(_melee_pose, _melee_target, minf(1.0, delta * 8.0))
    tree.set("parameters/loco/blend_position", _loco)
    tree.set("parameters/air/blend_amount", _air)
    tree.set("parameters/aim/blend_amount", _aim)
    tree.set("parameters/melee/blend_amount", _melee_pose)
    # bank into the strafe (the Figure node's own rotation is otherwise unused)
    var lean_target := -_loco.x * deg_to_rad(LEAN_DEG) * (1.0 - _air)
    _lean = lerpf(_lean, lean_target, minf(1.0, delta * 8.0))
    rotation.z = _lean
    if aim_modifier:
        # creeping crouched: lean into the walk on top of the hips drop
        aim_modifier.move_lean = aim_modifier.crouch_target * minf(1.0, _loco.length()) * 0.12
        aim_modifier.decay(delta)


## Upper-body pose for the weapon in hand. `slot` picks the stance flavour (5 = gatling: the
## barrel is heavy, so the arms sit lower and the torso turns further into it). Character calls
## this every frame, so per-weapon stance tweaks belong HERE, not on AimModifier from outside.
func set_stance(holding_gun: bool, slot := 0) -> void:
    _aim_target = 1.0 if holding_gun else 0.0
    _melee_target = 0.0 if holding_gun else 1.0
    if aim_modifier:
        var heavy := holding_gun and slot == 5
        aim_modifier.arm_lift_target = (0.78 if heavy else 1.05) if holding_gun else 0.0
        aim_modifier.chest_twist_target = (-0.8 if heavy else -0.55) if holding_gun else 0.0


func set_aiming(holding_gun: bool) -> void:
    set_stance(holding_gun)


func set_pitch(pitch: float) -> void:
    if aim_modifier:
        aim_modifier.pitch = pitch


## No KayKit crouch clip: the aim modifier drops the hips and leans the chest instead.
func set_crouch(on: bool) -> void:
    if aim_modifier:
        aim_modifier.crouch_target = 1.0 if on else 0.0


func set_flash(amount: float) -> void:
    if absf(amount - _flash_applied) < 0.002:
        return   # most frames: nothing to upload
    _flash_applied = amount
    for m in mats:
        m.set_shader_parameter("flash", amount)


func set_tint(tint: Color, tint_mix: float) -> void:
    for m in mats:
        m.set_shader_parameter("tint", tint)
        m.set_shader_parameter("tint_mix", tint_mix)


func play_action(key: String, duration: float) -> void:
    if not ready_ok or not ACTIONS.has(key):
        return
    Game.trace("act:" + key)
    var anim_name: String = ACTIONS[key]
    if not anim_player.has_animation(anim_name):
        return
    last_action = key
    var length := anim_player.get_animation(anim_name).length
    tree.set("parameters/actions/transition_request", key)
    tree.set("parameters/action_speed/scale", length / maxf(duration, 0.05))
    tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Take a hit from `from_local` -- a unit vector in the toy's own space pointing at whoever
## dealt it (-z is straight ahead). Picks the front or back flinch clip and kicks the chest away
## from the source; `strength` 0..1 scales the procedural part so a rifle tap is a nudge and a
## rocket is a whole-body jolt.
func play_hit(from_local: Vector3, headshot: bool, strength: float) -> void:
    if not ready_ok:
        return
    if strength > 0.55:
        play_action("hit_back" if from_local.z > 0.0 else "hit", 0.32)
    if aim_modifier:
        aim_modifier.flinch = Vector2(-from_local.x, -from_local.z) * strength * 0.3
        if headshot:
            aim_modifier.head_jerk = -strength * 0.45


## Full-body beat (jump takeoff / landing / double jump). Same contract as play_action, but it
## sits under the aim pose so a gun stays shouldered while the legs do the work.
func play_body_action(key: String, duration: float) -> void:
    if not ready_ok or not BODY_ACTIONS.has(key):
        return
    Game.trace("body:" + key)
    var anim_name: String = BODY_ACTIONS[key]
    if not anim_player.has_animation(anim_name):
        return
    last_body_action = key
    var length := anim_player.get_animation(anim_name).length
    tree.set("parameters/body_actions/transition_request", key)
    tree.set("parameters/body_speed/scale", length / maxf(duration, 0.05))
    tree.set("parameters/body_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Plastic squash-and-stretch on the whole toy (landing, spawn). `amount` 0..1, 1 = full SQUASH.
## Rides on the Figure node's scale, which nothing else writes; the hat follows automatically.
func squash(amount: float, seconds := 0.12) -> void:
    if not ready_ok:
        return
    var k := clampf(amount, 0.0, 1.5) * SQUASH
    _scale_from(Vector3(1.0 + k, 1.0 - k, 1.0 + k), seconds, Tween.TRANS_BACK)


## Spawn-in: grow from nothing with a little overshoot.
func pop_in(seconds := 0.28) -> void:
    if not ready_ok:
        return
    _scale_from(Vector3(0.05, 0.05, 0.05), seconds, Tween.TRANS_BACK)


func _scale_from(from: Vector3, seconds: float, trans: Tween.TransitionType) -> void:
    if _scale_tween != null and _scale_tween.is_valid():
        _scale_tween.kill()
    scale = from
    _scale_tween = create_tween()
    _scale_tween.tween_property(self, "scale", Vector3.ONE, seconds).set_ease(Tween.EASE_OUT).set_trans(trans)


func play_death() -> void:
    if not ready_ok:
        return
    Game.trace("anim_death")
    tree.active = false
    anim_player.play("Death_A" if randf() < 0.5 else "Death_B")


func revive() -> void:
    if not ready_ok:
        return
    anim_player.stop()
    tree.active = true
    # play_action() does not check tree.active, so a hit fired at the moment of death would
    # otherwise resume here mid-animation.
    tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
    tree.set("parameters/body_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
    visible = true
    rotation.z = 0.0
    _lean = 0.0


func weapon_transform() -> Transform3D:
    return grip.global_transform if grip else global_transform


## Party hat (rebuilt by setup(): call again after changing the model). The KayKit head bone
## sits at the neck and is animated with scale, so the hat is not parented to the bone: every
## frame it is posed from the bone's orthonormalised world pose, HAT_UP metres up the bone.
const HAT_UP := 0.86

func add_hat(color: Color) -> Node3D:
    if not ready_ok or skeleton == null:
        return null
    if hat != null and is_instance_valid(hat):
        hat.queue_free()
    _head_idx = skeleton.find_bone("head")
    hat = PartyHat.build(color, 0.62)
    add_child(hat)
    _pose_hat()
    return hat


func _process(_delta: float) -> void:
    if hat != null:
        _pose_hat()


func _pose_hat() -> void:
    if hat == null or not is_instance_valid(hat) or _head_idx < 0 or skeleton == null:
        return
    var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_head_idx)
    var basis := pose.basis.orthonormalized()
    var tilt := Basis(Vector3.FORWARD, deg_to_rad(-6.0)) * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
    var world := Transform3D(basis * tilt, pose.origin + basis.y * HAT_UP + basis.z * 0.03)
    hat.transform = global_transform.affine_inverse() * world


# ---- setup ----------------------------------------------------------------------

func _hide_accessories() -> void:
    for mi in model.find_children("*", "MeshInstance3D", true, false):
        var parent_name := mi.get_parent().name.to_lower()
        if parent_name.begins_with("handslot"):
            mi.visible = false


func _apply_materials(tint: Color, tint_mix: float) -> void:
    mats = ToonMat.apply(model, tint, tint_mix, 0.25)


func _set_loops() -> void:
    for anim_name in LOOPING:
        if anim_player.has_animation(anim_name):
            anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func _anim(anim_name: String) -> AnimationNodeAnimation:
    var n := AnimationNodeAnimation.new()
    n.animation = anim_name if anim_player.has_animation(anim_name) else "Idle"
    return n


func _upper_filter(node: AnimationNode) -> void:
    node.filter_enabled = true
    for bone in UPPER_BONES:
        node.set_filter_path(NodePath(SKELETON_TRACK_PREFIX + bone), true)


func _build_tree() -> void:
    var root := AnimationNodeBlendTree.new()

    var loco := AnimationNodeBlendSpace2D.new()
    loco.sync = true
    loco.add_blend_point(_anim("Idle"), Vector2(0, 0), -1, "idle")
    loco.add_blend_point(_anim("Walking_A"), Vector2(0, WALK_AT), -1, "walk")
    loco.add_blend_point(_anim("Running_A"), Vector2(0, 1), -1, "run")
    loco.add_blend_point(_anim("Walking_Backwards"), Vector2(0, -1), -1, "back")
    loco.add_blend_point(_anim("Running_Strafe_Left"), Vector2(-1, 0), -1, "left")
    loco.add_blend_point(_anim("Running_Strafe_Right"), Vector2(1, 0), -1, "right")
    root.add_node("loco", loco)

    root.add_node("jump", _anim("Jump_Idle"))
    var air := AnimationNodeBlend2.new()
    root.add_node("air", air)
    root.connect_node("air", 0, "loco")
    root.connect_node("air", 1, "jump")

    # full-body beats (takeoff / landing): unfiltered, so the legs move; they sit UNDER the
    # aim pose so a shouldered gun stays put.
    var body_shot := _one_shot_lane(root, BODY_ACTIONS, "body_actions", "body_speed", "body_shot",
        "air", 0.06, 0.12, false)

    root.add_node("meleepose", _anim(MELEE_POSE))
    var melee := AnimationNodeBlend2.new()
    _upper_filter(melee)
    root.add_node("melee", melee)
    root.connect_node("melee", 0, body_shot)
    root.connect_node("melee", 1, "meleepose")

    root.add_node("aimpose", _anim(AIM_POSE))
    var aim := AnimationNodeBlend2.new()
    _upper_filter(aim)
    root.add_node("aim", aim)
    root.connect_node("aim", 0, "melee")
    root.connect_node("aim", 1, "aimpose")

    var shot := _one_shot_lane(root, ACTIONS, "actions", "action_speed", "shot", "aim", 0.05, 0.15, true)
    root.connect_node("output", 0, shot)

    tree = AnimationTree.new()
    tree.name = "Tree"
    tree.tree_root = root
    model.add_child(tree)
    tree.anim_player = tree.get_path_to(anim_player)
    tree.active = true
    tree.set("parameters/actions/transition_request", "fire")


## Builds "<clips> -> Transition -> TimeScale -> OneShot(over `under`)" and returns the OneShot's
## node name. Both action lanes (upper-body actions, full-body beats) are the same shape.
func _one_shot_lane(root: AnimationNodeBlendTree, clips: Dictionary, transition_name: String,
        speed_name: String, shot_name: String, under: String, fade_in: float, fade_out: float,
        upper_only: bool) -> String:
    var transition := AnimationNodeTransition.new()
    transition.input_count = clips.size()
    transition.allow_transition_to_self = true
    transition.xfade_time = 0.0
    var i := 0
    for key in clips:
        transition.set_input_name(i, key)
        root.add_node(transition_name + "_" + key, _anim(clips[key]))
        i += 1
    root.add_node(transition_name, transition)
    i = 0
    for key in clips:
        root.connect_node(transition_name, i, transition_name + "_" + key)
        i += 1
    var speed := AnimationNodeTimeScale.new()
    root.add_node(speed_name, speed)
    root.connect_node(speed_name, 0, transition_name)
    var shot := AnimationNodeOneShot.new()
    shot.fadein_time = fade_in
    shot.fadeout_time = fade_out
    if upper_only:
        _upper_filter(shot)
    root.add_node(shot_name, shot)
    root.connect_node(shot_name, 0, under)
    root.connect_node(shot_name, 1, speed_name)
    return shot_name


func _setup_hand() -> void:
    hand = BoneAttachment3D.new()
    hand.name = "HandR"
    hand.bone_name = "handslot.r"
    skeleton.add_child(hand)
    grip = Node3D.new()
    grip.name = "Grip"
    # guns are re-aimed every frame by Arsenal (look-at); melee keeps the slot orientation
    grip.scale = Vector3.ONE / MODEL_SCALE       # weapon models are authored at world scale
    hand.add_child(grip)


func _setup_aim() -> void:
    aim_modifier = AimModifier.new()
    aim_modifier.name = "AimTilt"
    aim_modifier.side_axis = Vector3.RIGHT.rotated(Vector3.UP, -FACE_FIX_ROT_Y)
    skeleton.add_child(aim_modifier)
