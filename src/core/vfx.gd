extends Node
## Placeholder VFX: unshaded primitives, tweens and CPU particles.
## Autoload "Vfx". The art milestone replaces these with real effects.


func tracer(from: Vector3, to: Vector3, color := Color(1.0, 0.85, 0.45, 0.9)) -> void:
    var length := from.distance_to(to)
    if length < 0.05:
        return
    var mi := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.03, 0.03, length)
    mi.mesh = box
    var mat := _unshaded(color)
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    mi.global_position = (from + to) * 0.5
    var dir := (to - from).normalized()
    mi.look_at(to, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
    var tw := mi.create_tween()
    tw.tween_property(mat, "albedo_color:a", 0.0, 0.08)
    tw.tween_callback(mi.queue_free)


func muzzle_flash(pos: Vector3) -> void:
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.8, 0.5)
    light.light_energy = 4.0
    light.omni_range = 4.0
    add_child(light)
    light.global_position = pos
    var mi := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.12
    sphere.height = 0.24
    mi.mesh = sphere
    mi.material_override = _unshaded(Color(1.0, 0.9, 0.6, 0.9))
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    mi.global_position = pos
    _free_after([light, mi], 0.05)


func impact(pos: Vector3, normal: Vector3, on_character: bool) -> void:
    var p := _particles(14 if on_character else 10, 0.3, 2.0, 5.0, 0.06,
        Color(1.0, 0.35, 0.3) if on_character else Color(1.0, 0.9, 0.6))
    p.direction = normal
    p.spread = 50.0
    add_child(p)
    p.global_position = pos
    _free_after([p], 0.6)


func explosion(pos: Vector3, radius: float) -> void:
    var mi := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    mi.mesh = sphere
    var mat := _unshaded(Color(1.0, 0.6, 0.2, 0.85))
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    mi.global_position = pos
    mi.scale = Vector3.ONE * 0.2
    var tw := mi.create_tween().set_parallel(true)
    tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.16).set_ease(Tween.EASE_OUT)
    tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
    tw.chain().tween_callback(mi.queue_free)

    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.6, 0.3)
    light.light_energy = 8.0
    light.omni_range = radius * 3.0
    add_child(light)
    light.global_position = pos
    var lt := light.create_tween()
    lt.tween_property(light, "light_energy", 0.0, 0.3)
    lt.tween_callback(light.queue_free)

    var p := _particles(28, 0.6, 4.0, 9.0, 0.12, Color(0.35, 0.3, 0.28))
    p.direction = Vector3.UP
    p.spread = 180.0
    add_child(p)
    p.global_position = pos
    _free_after([p], 1.0)


func _particles(amount: int, lifetime: float, v_min: float, v_max: float, size: float,
        color: Color) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.one_shot = true
    p.emitting = true
    p.explosiveness = 1.0
    p.amount = amount
    p.lifetime = lifetime
    p.initial_velocity_min = v_min
    p.initial_velocity_max = v_max
    p.gravity = Vector3(0, -12, 0)
    var box := BoxMesh.new()
    box.size = Vector3.ONE * size
    box.material = _unshaded(color)
    p.mesh = box
    return p


func _unshaded(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = color
    return m


func _free_after(nodes: Array, seconds: float) -> void:
    get_tree().create_timer(seconds).timeout.connect(func() -> void:
        for n in nodes:
            if is_instance_valid(n):
                n.queue_free())
