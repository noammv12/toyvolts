class_name Figure
extends Node3D
## Animated toy figure. Loads a KayKit character GLB, routes its materials through the toon
## shader, builds an AnimationTree (locomotion blend space + air + upper-body aim pose +
## upper-body one-shot actions), exposes a right-hand grip for weapon models and a chest/head
## aim tilt. Character feeds it velocity, floor state, pitch and events.

const MODEL_SCALE := 0.76
const FACE_FIX_ROT_Y := PI      ## KayKit rigs face +Z; Godot forward is -Z
const TOON: Shader = preload("res://shaders/toon.gdshader")
const SKELETON_TRACK_PREFIX := "Rig/Skeleton3D:"
const AIM_POSE := "2H_Ranged_Aiming"   ## two-handed hold; AimModifier lifts the arms to chest height
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
    "melee_heavy": "2H_Melee_Attack_Chop",
    "reload": "2H_Ranged_Reload",
    "hit": "Hit_A",
    "throw": "Throw",
    "cheer": "Cheer",
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
var hat: Node3D                 ## party hat on the head bone (party mode)
var ready_ok := false

var _loco := Vector2.ZERO
var _air := 0.0
var _aim := 0.0
var _aim_target := 0.0
var _flash_applied := -1.0


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
    tree.set("parameters/loco/blend_position", _loco)
    tree.set("parameters/air/blend_amount", _air)
    tree.set("parameters/aim/blend_amount", _aim)


func set_aiming(holding_gun: bool) -> void:
    _aim_target = 1.0 if holding_gun else 0.0
    if aim_modifier:
        aim_modifier.arm_lift_target = 1.05 if holding_gun else 0.0
        aim_modifier.chest_twist_target = -0.55 if holding_gun else 0.0


func set_pitch(pitch: float) -> void:
    if aim_modifier:
        aim_modifier.pitch = pitch


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
    var length := anim_player.get_animation(anim_name).length
    tree.set("parameters/actions/transition_request", key)
    tree.set("parameters/action_speed/scale", length / maxf(duration, 0.05))
    tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


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


func weapon_transform() -> Transform3D:
    return grip.global_transform if grip else global_transform


## Party hat on the head bone (rebuilt by setup(): call again after changing the model).
func add_hat(color: Color) -> Node3D:
    if not ready_ok or skeleton == null:
        return null
    if hat != null and is_instance_valid(hat):
        hat.queue_free()
    var att := BoneAttachment3D.new()
    att.name = "HatMount"
    att.bone_name = "head"
    skeleton.add_child(att)
    hat = PartyHat.build(color)
    # the head bone sits at the neck (0.92 m) and KayKit heads are huge (top ~2.1 m); the
    # mount inherits the model + bone scale (~0.6), so local units are not metres
    hat.scale = Vector3.ONE * 2.0
    hat.position = Vector3(0, 1.42, 0.05)
    hat.rotation = Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(12.0))
    att.add_child(hat)
    return hat


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

    root.add_node("aimpose", _anim(AIM_POSE))
    var aim := AnimationNodeBlend2.new()
    _upper_filter(aim)
    root.add_node("aim", aim)
    root.connect_node("aim", 0, "air")
    root.connect_node("aim", 1, "aimpose")

    var actions := AnimationNodeTransition.new()
    actions.input_count = ACTIONS.size()
    actions.allow_transition_to_self = true
    actions.xfade_time = 0.0
    var i := 0
    for key in ACTIONS:
        actions.set_input_name(i, key)
        root.add_node("act_" + key, _anim(ACTIONS[key]))
        i += 1
    root.add_node("actions", actions)
    i = 0
    for key in ACTIONS:
        root.connect_node("actions", i, "act_" + key)
        i += 1
    var speed := AnimationNodeTimeScale.new()
    root.add_node("action_speed", speed)
    root.connect_node("action_speed", 0, "actions")

    var shot := AnimationNodeOneShot.new()
    shot.fadein_time = 0.05
    shot.fadeout_time = 0.15
    _upper_filter(shot)
    root.add_node("shot", shot)
    root.connect_node("shot", 0, "aim")
    root.connect_node("shot", 1, "action_speed")
    root.connect_node("output", 0, "shot")

    tree = AnimationTree.new()
    tree.name = "Tree"
    tree.tree_root = root
    model.add_child(tree)
    tree.anim_player = tree.get_path_to(anim_player)
    tree.active = true
    tree.set("parameters/actions/transition_request", "fire")


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
