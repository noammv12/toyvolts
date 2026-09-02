class_name AimModifier
extends SkeletonModifier3D
## Tilts the chest and head with the aim pitch after the animation has been applied,
## so the figure visibly looks up and down where it shoots.

var pitch := 0.0
var side_axis := Vector3.RIGHT   ## skeleton-space axis to rotate around (character's right)
var chest_weight := 0.55
var head_weight := 0.45
var arm_lift_target := 0.0       ## radians both upper arms are raised while holding a gun
var head_scale := 0.8            ## KayKit heads are chibi-sized; shrink toward action-figure proportions
var chest_twist_target := 0.0    ## radians the torso turns so a held gun sits beside the body, not behind the head
var crouch_target := 0.0         ## 0..1: hips drop + forward lean (procedural crouch, no clip in the kit)
var crouch_drop := 0.42          ## model units the hips sink at full crouch (x0.76 = 0.32 m)
var move_lean := 0.0             ## extra forward chest lean (radians) while creeping crouched
var _crouch := 0.0
var _move_lean := 0.0
var _chest_twist := 0.0
var up_axis := Vector3.UP
var _arm_lift := 0.0

var _chest := -1
var _head := -1
var _hips := -1
var _arms: Array[int] = []


func _ready() -> void:
    var sk := get_skeleton()
    if sk:
        _chest = sk.find_bone("chest")
        _head = sk.find_bone("head")
        _hips = sk.find_bone("hips")
        for b in ["upperarm.l", "upperarm.r"]:
            var idx := sk.find_bone(b)
            if idx >= 0:
                _arms.append(idx)


func _process_modification() -> void:
    var sk := get_skeleton()
    if sk == null:
        return
    _arm_lift = lerpf(_arm_lift, arm_lift_target, 0.15)
    _chest_twist = lerpf(_chest_twist, chest_twist_target, 0.15)
    _crouch = lerpf(_crouch, crouch_target, 0.2)
    _move_lean = lerpf(_move_lean, move_lean, 0.15)
    if _hips >= 0 and _crouch > 0.001:
        sk.set_bone_pose_position(_hips, sk.get_bone_pose_position(_hips) + Vector3(0, -crouch_drop * _crouch, 0))
        _rotate_about_side(sk, _chest, -0.35 * _crouch)
    if absf(_move_lean) > 0.001:
        _rotate_about_side(sk, _chest, -_move_lean)
        _rotate_about_side(sk, _head, _move_lean * 0.6)   # keep the eyes up
    if _head >= 0 and head_scale != 1.0:
        sk.set_bone_pose_scale(_head, Vector3.ONE * head_scale)
    if absf(_chest_twist) > 0.001:
        _rotate_about(sk, _chest, up_axis, _chest_twist)
        _rotate_about(sk, _head, up_axis, -_chest_twist)   # keep the face forward
    if absf(pitch) > 0.001:
        _rotate_about_side(sk, _chest, pitch * chest_weight)
        _rotate_about_side(sk, _head, pitch * head_weight)
    if absf(_arm_lift) > 0.001:
        for idx in _arms:
            _rotate_about_side(sk, idx, _arm_lift + pitch * (1.0 - chest_weight))


## Rotates a bone in skeleton space around the character's side axis (positive = up).
func _rotate_about_side(sk: Skeleton3D, idx: int, angle: float) -> void:
    _rotate_about(sk, idx, side_axis, angle)


func _rotate_about(sk: Skeleton3D, idx: int, axis: Vector3, angle: float) -> void:
    if idx < 0 or absf(angle) < 0.0001:
        return
    var parent := sk.get_bone_parent(idx)
    var parent_basis := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
    var axis_local := (parent_basis.inverse() * axis).normalized()
    var rot := Quaternion(axis_local, angle)
    sk.set_bone_pose_rotation(idx, rot * sk.get_bone_pose_rotation(idx))
