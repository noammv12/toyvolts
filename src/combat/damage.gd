class_name Damage
extends RefCounted
## Area damage helpers shared by rockets, grenades and (later) zombie abilities.


## Applies splash damage to every living Character within `radius` of `center` that has
## line of sight (world geometry only). Damage falls off linearly to 30% at the edge.
## The shooter takes half damage. `exclude` is the character already hit directly.
static func splash(tree: SceneTree, center: Vector3, radius: float, damage: float,
        source: Character, knockback: float, exclude: Character = null) -> int:
    if radius <= 0.0 or damage <= 0.0:
        return 0
    var space := tree.root.world_3d.direct_space_state
    var hits := 0
    for node in tree.get_nodes_in_group("characters"):
        var c := node as Character
        if c == null or c == exclude or not c.alive:
            continue
        var to: Vector3 = c.center() - center
        var dist := to.length()
        if dist > radius + 0.35:
            continue
        var los := PhysicsRayQueryParameters3D.create(center, c.center(), Character.LAYER_WORLD)
        if space.intersect_ray(los):
            continue
        var t := clampf((dist - 0.35) / radius, 0.0, 1.0)
        var dmg := damage * lerpf(1.0, 0.3, t)
        if c == source:
            dmg *= 0.5
        var dir := to.normalized() if dist > 0.01 else Vector3.UP
        var impulse := (dir + Vector3.UP * 0.6).normalized() * knockback * lerpf(1.0, 0.4, t)
        var result := c.take_damage(dmg, source, c.center(), impulse, false)
        if result.applied:
            hits += 1
            if source != null and c != source and source.arsenal:
                source.arsenal.hit_confirmed.emit(result.killed, false)
    return hits
