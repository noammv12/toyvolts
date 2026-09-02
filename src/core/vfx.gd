extends Node
## Effects: muzzle flashes, glowing tracers, impact sparks + puffs + decals, explosions
## (fireball, shockwave, smoke, debris, light), projectile trails, shell casings, camera
## shake requests. Autoload "Vfx". Textures are generated procedurally at start-up.

signal shake(pos: Vector3, strength: float)   ## the local player converts this to camera trauma

const MAX_DECALS := 96

var _radial: GradientTexture2D
var _ring: GradientTexture2D
var _smoke: ImageTexture
var _decals: Array[Decal] = []
var _spark_mesh: BoxMesh
var _debris_mesh: BoxMesh
var _casing_mesh: BoxMesh


func _ready() -> void:
    _radial = _gradient_tex([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
    _ring = _gradient_tex([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.6, 0.8, 1.0])
    _smoke = _smoke_tex()
    _spark_mesh = BoxMesh.new()
    _spark_mesh.size = Vector3(0.05, 0.05, 0.12)
    _spark_mesh.material = _particle_mat(Color(1.0, 0.85, 0.5), 2.5)
    _debris_mesh = BoxMesh.new()
    _debris_mesh.size = Vector3(0.18, 0.18, 0.18)
    _debris_mesh.material = _particle_mat(Color(0.35, 0.3, 0.28), 0.0)
    _casing_mesh = BoxMesh.new()
    _casing_mesh.size = Vector3(0.04, 0.04, 0.09)
    _casing_mesh.material = _particle_mat(Color(0.85, 0.7, 0.3), 0.0)


# ---- public ---------------------------------------------------------------------

## Spawns one of every effect far below the map so their shaders/pipelines compile before
## the first real shot (avoids a hitch on first use).
func warm_up() -> void:
    var p := Vector3(0, -60, 0)
    tracer(p, p + Vector3(0, 0, 3))
    muzzle_flash(p, Vector3.FORWARD)
    casing(p, Vector3.RIGHT)
    impact(p, Vector3.UP, false)
    impact(p, Vector3.UP, true)
    explosion(p, 2.0)
    var probe := Node3D.new()
    add_child(probe)
    probe.global_position = p
    trail(probe, true)
    trail(probe, false)
    _free_after([probe], 1.5)


## A short glowing streak that flies from the muzzle to the hit point (reads well even when
## seen from behind the shooter, unlike a full-length line).
func tracer(from: Vector3, to: Vector3, color := Color(1.0, 0.85, 0.45)) -> void:
    var length := from.distance_to(to)
    if length < 0.3:
        return
    var streak_len := minf(1.6, length * 0.6)
    var mi := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.07, 0.07, streak_len)
    mi.mesh = box
    var mat := _glow_mat(color, 4.0)
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    var dir := (to - from).normalized()
    var start := from + dir * streak_len * 0.5
    var end := to - dir * streak_len * 0.5
    mi.global_position = start
    mi.look_at(to, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
    var speed := 140.0
    var tw := mi.create_tween()
    tw.tween_property(mi, "global_position", end, maxf(length - streak_len, 0.1) / speed)
    tw.tween_property(mat, "albedo_color:a", 0.0, 0.04)
    tw.tween_callback(mi.queue_free)


func muzzle_flash(pos: Vector3, dir := Vector3.ZERO, size := 0.7) -> void:
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.75, 0.4)
    light.light_energy = 6.0
    light.omni_range = 5.0
    add_child(light)
    light.global_position = pos
    var flash := _billboard(_radial, Color(1.0, 0.8, 0.45, 1.0), size * randf_range(0.8, 1.2), true)
    add_child(flash)
    flash.global_position = pos + dir * 0.15
    flash.rotation.z = randf() * TAU
    var core := _billboard(_radial, Color(1.0, 1.0, 0.9, 1.0), size * 0.4, true)
    add_child(core)
    core.global_position = pos + dir * 0.2
    _free_after([light, flash, core], 0.07)


func casing(pos: Vector3, right: Vector3) -> void:
    var p := _gpu(1, 1.1, _pmat(right + Vector3.UP * 1.2, 25.0, 1.8, 3.0, Vector3(0, -12, 0), 1.0), _casing_mesh)
    p.process_material.angular_velocity_min = -600.0
    p.process_material.angular_velocity_max = 600.0
    add_child(p)
    p.global_position = pos
    _free_after([p], 1.4)


func impact(pos: Vector3, normal: Vector3, on_character: bool) -> void:
    var sparks := _gpu(16 if on_character else 12, 0.35, _pmat(normal, 55.0, 3.0, 7.5, Vector3(0, -14, 0), 0.9), _spark_mesh)
    if on_character:
        sparks.draw_pass_1 = _spark_mesh.duplicate()
        sparks.draw_pass_1.material = _particle_mat(Color(1.0, 0.4, 0.35), 1.5)
    add_child(sparks)
    sparks.global_position = pos
    _free_after([sparks], 0.6)
    var puff := _billboard(_smoke, Color(0.85, 0.8, 0.75, 0.55) if not on_character else Color(1.0, 0.5, 0.45, 0.5), 0.35, false)
    add_child(puff)
    puff.global_position = pos + normal * 0.08
    puff.rotation.z = randf() * TAU
    var tw := puff.create_tween().set_parallel(true)
    tw.tween_property(puff, "scale", Vector3.ONE * 2.2, 0.35).set_ease(Tween.EASE_OUT)
    tw.tween_property(puff, "modulate:a", 0.0, 0.35)
    tw.chain().tween_callback(puff.queue_free)
    if not on_character:
        _decal(pos, normal, 0.22, Color(0.12, 0.1, 0.09, 0.85))


func explosion(pos: Vector3, radius: float) -> void:
    # fireball
    var mi := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    mi.mesh = sphere
    var mat := _glow_mat(Color(1.0, 0.55, 0.15, 0.9), 3.0)
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    mi.global_position = pos
    mi.scale = Vector3.ONE * 0.25
    var tw := mi.create_tween().set_parallel(true)
    tw.tween_property(mi, "scale", Vector3.ONE * radius * 0.9, 0.18).set_ease(Tween.EASE_OUT)
    tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
    tw.chain().tween_callback(mi.queue_free)
    # shockwave ring
    var ring := _billboard(_ring, Color(1.0, 0.85, 0.6, 0.9), radius * 0.6, true)
    ring.axis = Vector3.AXIS_Y
    ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    add_child(ring)
    ring.global_position = pos + Vector3(0, 0.15, 0)
    ring.rotation.x = -PI * 0.5
    var rt := ring.create_tween().set_parallel(true)
    rt.tween_property(ring, "scale", Vector3.ONE * radius * 1.4 / (radius * 0.6), 0.35).set_ease(Tween.EASE_OUT)
    rt.tween_property(ring, "modulate:a", 0.0, 0.35)
    rt.chain().tween_callback(ring.queue_free)
    # light
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.6, 0.3)
    light.light_energy = 14.0
    light.omni_range = radius * 4.0
    add_child(light)
    light.global_position = pos
    var lt := light.create_tween()
    lt.tween_property(light, "light_energy", 0.0, 0.4)
    lt.tween_callback(light.queue_free)
    # smoke puffs
    for i in 6:
        var puff := _billboard(_smoke, Color(0.3, 0.28, 0.27, 0.7), radius * 0.35, false)
        add_child(puff)
        puff.global_position = pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.6), randf_range(-0.5, 0.5)) * radius * 0.5
        puff.rotation.z = randf() * TAU
        var pt := puff.create_tween().set_parallel(true)
        pt.tween_property(puff, "scale", Vector3.ONE * 3.5, 1.1).set_ease(Tween.EASE_OUT)
        pt.tween_property(puff, "global_position", puff.global_position + Vector3(0, radius * 0.9, 0), 1.1)
        pt.tween_property(puff, "modulate:a", 0.0, 1.1).set_delay(0.15)
        pt.chain().tween_callback(puff.queue_free)
    # debris + sparks
    var debris := _gpu(22, 1.3, _pmat(Vector3.UP, 180.0, 5.0, 12.0, Vector3(0, -18, 0), 0.6), _debris_mesh)
    debris.process_material.angular_velocity_min = -400.0
    debris.process_material.angular_velocity_max = 400.0
    add_child(debris)
    debris.global_position = pos
    _free_after([debris], 1.6)
    var sparks := _gpu(30, 0.5, _pmat(Vector3.UP, 180.0, 6.0, 14.0, Vector3(0, -10, 0), 1.5), _spark_mesh)
    add_child(sparks)
    sparks.global_position = pos
    _free_after([sparks], 0.8)
    _decal(pos, Vector3.UP, radius * 0.9, Color(0.08, 0.07, 0.06, 0.8), true)
    shake.emit(pos, clampf(radius / 2.5, 0.4, 1.2))


## Continuous smoke trail behind a projectile. Returns the emitter (parented to the node).
func trail(node: Node3D, rocket: bool) -> GPUParticles3D:
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE * (0.16 if rocket else 0.09)
    mesh.material = _particle_mat(Color(0.75, 0.72, 0.7) if rocket else Color(0.6, 0.6, 0.6), 0.0)
    var pm := _pmat(Vector3.UP, 180.0, 0.2, 0.6, Vector3(0, 0.8, 0), 2.0)
    pm.scale_min = 0.6
    pm.scale_max = 1.4
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    pm.emission_sphere_radius = 0.06
    var p := _gpu(40 if rocket else 24, 0.7 if rocket else 0.5, pm, mesh, false)
    p.explosiveness = 0.0
    p.local_coords = false
    node.add_child(p)
    if rocket:
        var flame := _billboard(_radial, Color(1.0, 0.6, 0.25, 0.95), 0.45, true)
        node.add_child(flame)
        flame.position = Vector3(0, 0, 0.35)
    return p


# ---- internals ------------------------------------------------------------------

## Soft round smoke puff: value noise masked by a radial falloff.
func _smoke_tex() -> ImageTexture:
    var size := 96
    var noise := FastNoiseLite.new()
    noise.frequency = 0.07
    noise.fractal_octaves = 4
    noise.seed = 7
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var dx := (x + 0.5) / size - 0.5
            var dy := (y + 0.5) / size - 0.5
            var d := sqrt(dx * dx + dy * dy) * 2.0
            var falloff := clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
            var n := 0.55 + 0.45 * noise.get_noise_2d(x, y)
            img.set_pixel(x, y, Color(1, 1, 1, clampf(falloff * n * 1.4, 0.0, 1.0)))
    return ImageTexture.create_from_image(img)


func _gradient_tex(colors: Array, offsets: Array) -> GradientTexture2D:
    var g := Gradient.new()
    g.colors = PackedColorArray(colors)
    g.offsets = PackedFloat32Array(offsets)
    var t := GradientTexture2D.new()
    t.gradient = g
    t.width = 64
    t.height = 64
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    return t


func _billboard(tex: Texture2D, color: Color, size: float, additive: bool) -> Sprite3D:
    var s := Sprite3D.new()
    s.texture = tex
    s.modulate = color
    s.pixel_size = size / 64.0
    s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s.shaded = false
    s.double_sided = true
    s.no_depth_test = false
    s.transparent = true
    s.render_priority = 2
    if additive:
        s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
        s.set("modulate", color)
        s.material_override = null
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
        m.albedo_texture = tex
        m.vertex_color_use_as_albedo = true
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 2.0
        s.material_override = m
    s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return s


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = color
    m.emission_enabled = true
    m.emission = Color(color.r, color.g, color.b)
    m.emission_energy_multiplier = energy
    return m


func _particle_mat(color: Color, emission: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emission > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
    m.albedo_color = color
    m.vertex_color_use_as_albedo = true
    if emission > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emission
    return m


func _pmat(direction: Vector3, spread: float, v_min: float, v_max: float, gravity: Vector3, damping: float) -> ParticleProcessMaterial:
    var pm := ParticleProcessMaterial.new()
    pm.direction = direction
    pm.spread = spread
    pm.initial_velocity_min = v_min
    pm.initial_velocity_max = v_max
    pm.gravity = gravity
    pm.damping_min = damping
    pm.damping_max = damping * 1.5
    pm.scale_min = 0.7
    pm.scale_max = 1.3
    return pm


func _gpu(amount: int, lifetime: float, pm: ParticleProcessMaterial, mesh: Mesh, one_shot := true) -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = amount
    p.lifetime = lifetime
    p.one_shot = one_shot
    p.explosiveness = 1.0 if one_shot else 0.0
    p.process_material = pm
    p.draw_pass_1 = mesh
    p.emitting = true
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p


func _decal(pos: Vector3, normal: Vector3, size: float, color: Color, floor_only := false) -> void:
    var d := Decal.new()
    d.texture_albedo = _radial
    d.modulate = color
    d.size = Vector3(size, 0.4, size)
    d.cull_mask = 1   # world only
    d.albedo_mix = 1.0
    d.upper_fade = 0.6
    d.lower_fade = 0.6
    add_child(d)
    d.global_position = pos + normal * 0.02
    var up := Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
    d.global_basis = Basis.looking_at(normal, up) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
    _decals.append(d)
    while _decals.size() > MAX_DECALS:
        var old: Decal = _decals.pop_front()
        if is_instance_valid(old):
            old.queue_free()
    get_tree().create_timer(18.0).timeout.connect(func() -> void:
        if is_instance_valid(d):
            var tw := d.create_tween()
            tw.tween_property(d, "modulate:a", 0.0, 2.0)
            tw.tween_callback(d.queue_free)
            _decals.erase(d))


func _free_after(nodes: Array, seconds: float) -> void:
    get_tree().create_timer(seconds).timeout.connect(func() -> void:
        for n in nodes:
            if is_instance_valid(n):
                n.queue_free())
