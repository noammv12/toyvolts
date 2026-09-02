extends Node
## Probe: where is the head bone, which way is its Y, where does the party hat end up?
func _ready() -> void:
    Game.mode = "party"
    Game.bot_count = 0
    var arena: Node3D = (load("res://src/world/arena_greybox.tscn") as PackedScene).instantiate()
    add_child(arena)
    await get_tree().process_frame
    var p: Character = arena.local_player()
    p.controller.input_enabled = false
    for i in 40:
        await get_tree().process_frame
    var f := p.figure
    var sk := f.skeleton
    var head := sk.find_bone("head")
    var neck := sk.find_bone("neck")
    var gp := sk.get_bone_global_pose(head)
    var world := sk.global_transform * gp
    print("head bone idx %d (neck %d), rest origin %s, pose origin (skeleton space) %s, world rel %s" % [
        head, neck, sk.get_bone_global_rest(head).origin, gp.origin, (world.origin - p.global_position).snapped(Vector3(0.01, 0.01, 0.01))])
    var b := world.basis
    print("head axes world: x %s y %s z %s" % [b.x.normalized().snapped(Vector3(0.01,0.01,0.01)), b.y.normalized().snapped(Vector3(0.01,0.01,0.01)), b.z.normalized().snapped(Vector3(0.01,0.01,0.01))])
    print("skeleton scale %s, model scale %s" % [sk.global_transform.basis.get_scale(), f.model.scale])
    var hat: Node3D = f.hat
    print("hat rel %s, hat global scale %s, hat up axis %s" % [(hat.global_position - p.global_position).snapped(Vector3(0.01,0.01,0.01)),
        hat.global_transform.basis.get_scale(), hat.global_transform.basis.y.snapped(Vector3(0.01,0.01,0.01))])
    var names := PackedStringArray()
    for i in sk.get_bone_count():
        names.append(sk.get_bone_name(i))
    print("bones: ", ", ".join(names))
    # the mesh top: AABB of the model
    var top := 0.0
    for mi in f.model.find_children("*", "MeshInstance3D", true, false):
        var aabb: AABB = mi.global_transform * mi.get_aabb()
        top = maxf(top, aabb.position.y + aabb.size.y - p.global_position.y)
    print("model top %.2f m above the feet, eye %.2f" % [top, p.eye().y - p.global_position.y])
    get_tree().quit(0)
