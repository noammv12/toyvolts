class_name Projectile
extends Node3D
## Rocket / grenade. Moves kinematically with a per-tick raycast (no tunnelling),
## explodes on contact (rocket) or bounces until the fuse runs out (grenade).

const MASK := Character.LAYER_WORLD | Character.LAYER_CHARACTER | Character.LAYER_TARGET
const MAX_LIFE := 12.0
const TOON: Shader = preload("res://shaders/toon.gdshader")

var data: WeaponData
var shooter: Character
var cosmetic := false      ## client copy: flies and explodes visually, hurts nobody
var velocity := Vector3.ZERO
var age := 0.0
var _exploded := false
var _trail: Node3D


func setup(weapon: WeaponData, owner_character: Character, initial_velocity: Vector3) -> void:
    data = weapon
    shooter = owner_character
    velocity = initial_velocity


func _ready() -> void:
    Game.trace("projectile")
    _build_mesh()
    _orient()
    var rocket := data.projectile_gravity <= 0.0
    _trail = Vfx.trail(self, rocket)
    if rocket:
        Sfx.attach_loop("rocket_loop", self)


func _physics_process(delta: float) -> void:
    if _exploded:
        return
    age += delta
    if data.fuse_time > 0.0 and age >= data.fuse_time:
        _explode(global_position, Vector3.UP, null)
        return
    if age > MAX_LIFE:
        Vfx.release_trail(_trail)
        queue_free()
        return

    velocity.y -= data.projectile_gravity * delta
    var from := global_position
    var to := from + velocity * delta
    var exclude: Array[RID] = []
    if age < 0.2 and is_instance_valid(shooter):
        exclude.append(shooter.get_rid())
    var query := PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        var target := hit.collider as Character
        var prop := Arsenal.shootable_of(hit.collider)
        if data.fuse_time <= 0.0 or (target != null and data.detonate_on_character) or prop != null:
            if prop != null and not cosmetic:
                prop.on_shot(shooter if is_instance_valid(shooter) else null, hit.position, velocity.normalized(), data)
            _explode(hit.position, hit.normal, target)
            return
        var n: Vector3 = hit.normal
        var bounced: Vector3 = velocity.bounce(n)
        var vn := n * bounced.dot(n)
        var vt := bounced - vn
        velocity = vn * data.bounciness + vt * 0.75
        if bounced.length() > 2.0:
            Sfx.play("grenade_bounce", hit.position, clampf(bounced.length() - 8.0, -10.0, 0.0), 0.15)
        if velocity.length() < 0.6:
            velocity = Vector3.ZERO
        global_position = hit.position + n * 0.08
    else:
        global_position = to
    _orient()


func _explode(pos: Vector3, normal: Vector3, direct_target: Character) -> void:
    _exploded = true
    var center := pos + normal * 0.12
    if direct_target != null and data.damage > 0.0 and is_instance_valid(shooter) and not cosmetic:
        var result := direct_target.take_damage(
            data.damage, shooter, pos, velocity.normalized() * data.knockback, false)
        if result.applied and shooter.arsenal:
            shooter.arsenal.hit_confirmed.emit(result.killed, false)
    # the direct target also takes splash: a direct rocket is nearly lethal, a near miss is not
    if not cosmetic:
        Damage.splash(get_tree(), center, data.splash_radius, data.splash_damage,
            shooter if is_instance_valid(shooter) else null, data.knockback, null)
    Vfx.explosion(center, data.splash_radius)
    Sfx.play("explosion", center, 0.0, 0.1)
    Vfx.release_trail(_trail)
    queue_free()


func _orient() -> void:
    if velocity.length_squared() > 0.01:
        var up := Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT
        look_at(global_position + velocity, up)


func _build_mesh() -> void:
    var mi := MeshInstance3D.new()
    var mat := ShaderMaterial.new()
    mat.shader = TOON
    if data.projectile_gravity > 0.0:
        var sphere := SphereMesh.new()
        sphere.radius = 0.13
        sphere.height = 0.26
        mi.mesh = sphere
        mat.set_shader_parameter("albedo", Color(0.3, 0.7, 0.35))
    else:
        var box := BoxMesh.new()
        box.size = Vector3(0.14, 0.14, 0.55)
        mi.mesh = box
        mat.set_shader_parameter("albedo", Color(0.85, 0.25, 0.2))
        var tip := MeshInstance3D.new()
        var tip_mesh := BoxMesh.new()
        tip_mesh.size = Vector3(0.1, 0.1, 0.12)
        tip.mesh = tip_mesh
        tip.position = Vector3(0, 0, -0.32)
        var tip_mat := ShaderMaterial.new()
        tip_mat.shader = TOON
        tip_mat.set_shader_parameter("albedo", Color(0.95, 0.75, 0.2))
        tip.material_override = tip_mat
        add_child(tip)
    mi.material_override = mat
    add_child(mi)
