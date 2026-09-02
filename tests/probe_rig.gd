extends Node
## Live probe: is the AnimationTree animating, is the aim blend applied, where is the hand grip?
func _ready() -> void:
    Game.mode = "practice"
    var arena: Node3D = (load("res://src/world/arena_greybox.tscn") as PackedScene).instantiate()
    add_child(arena)
    await get_tree().process_frame
    var p := arena.get_node("Player") as Player
    p.input_enabled = false
    var f := p.figure
    var sk := f.skeleton
    var hips := sk.find_bone("hips"); var chest := sk.find_bone("chest"); var ua := sk.find_bone("upperarm.r")
    var rest_ua := sk.get_bone_global_rest(ua).basis.get_euler()
    for i in 3:
        for j in 30:
            await get_tree().process_frame
        print("frame %d: aim=%.2f loco=%s air=%.2f active=%s hips_y=%.3f chest_rot=%s ua_rot=%s (rest %s)" % [
            (i + 1) * 30, float(f.tree.get("parameters/aim/blend_amount")), str(f.tree.get("parameters/loco/blend_position")),
            float(f.tree.get("parameters/air/blend_amount")), str(f.tree.active),
            sk.get_bone_pose_position(hips).y,
            str(sk.get_bone_global_pose(chest).basis.get_euler().snapped(Vector3(0.01, 0.01, 0.01))),
            str(sk.get_bone_global_pose(ua).basis.get_euler().snapped(Vector3(0.01, 0.01, 0.01))), str(rest_ua.snapped(Vector3(0.01,0.01,0.01)))])
    print("hand global:", f.hand.global_position - p.global_position, " grip global:", f.grip.global_position - p.global_position, " grip scale:", f.grip.global_transform.basis.get_scale())
    print("weapon model:", p.arsenal.current_model().name, " visible:", p.arsenal.current_model().visible, " pos rel:", p.arsenal.current_model().global_position - p.global_position, " muzzle rel:", p.muzzle_position() - p.global_position)
    print("model forward (grip -Z world):", (-f.grip.global_transform.basis.z).normalized().snapped(Vector3(0.01,0.01,0.01)), " player facing:", p.facing())
    var hb := f.hand.global_transform.basis
    print("hand slot axes world: x", hb.x.normalized().snapped(Vector3(0.01,0.01,0.01)), " y", hb.y.normalized().snapped(Vector3(0.01,0.01,0.01)), " z", hb.z.normalized().snapped(Vector3(0.01,0.01,0.01)))
    var hl := (f.skeleton.find_child("*", false, false) if false else null)
    var lhand := BoneAttachment3D.new(); lhand.bone_name = "handslot.l"; f.skeleton.add_child(lhand)
    await get_tree().process_frame
    print("left hand rel:", (lhand.global_position - p.global_position).snapped(Vector3(0.01,0.01,0.01)), " right hand rel:", (f.hand.global_position - p.global_position).snapped(Vector3(0.01,0.01,0.01)))
    print("anim_player current:", f.anim_player.current_animation, " playing:", f.anim_player.is_playing())
    var filt := f.tree.tree_root.get_node("aim") as AnimationNodeBlend2
    print("aim filter enabled:", filt.filter_enabled, " chest filtered:", filt.is_path_filtered(NodePath("Rig/Skeleton3D:chest")))
    var anim := f.anim_player.get_animation("2H_Ranged_Aiming")
    print("aiming anim tracks:", anim.get_track_count(), " path0:", anim.track_get_path(0), " loop:", anim.loop_mode)
    get_tree().quit(0)
