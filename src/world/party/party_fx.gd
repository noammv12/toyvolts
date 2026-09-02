class_name PartyFx
extends Node3D
## Party effects, pooled like Vfx: confetti bursts (coloured paper), a confetti storm for the
## finale, gold sparkles, fireworks (rising streak, spherical burst, flash) and smoke puffs.
## Everything is created once; a burst allocates nothing.

const CONFETTI_POOL := 10
const SPARKLE_POOL := 4
const BURST_POOL := 8
const STREAK_POOL := 6
const LIGHT_POOL := 6
const STORM_AMOUNT := 480

var _confetti: Array[GPUParticles3D] = []
var _sparkle: Array[GPUParticles3D] = []
var _burst: Array[GPUParticles3D] = []
var _streak: Array[MeshInstance3D] = []
var _light: Array[OmniLight3D] = []
var _free := {}                ## kind -> Array[Node]
var _pending: Array = []       ## [clock, node, kind]
var _clock := 0.0
var _storm: GPUParticles3D
var _confetti_mesh: QuadMesh
var _spark_mesh: BoxMesh
var _streak_mesh: BoxMesh
var _tweens := {}
var stats := {"confetti": 0, "fireworks": 0}


func _ready() -> void:
    _confetti_mesh = QuadMesh.new()
    _confetti_mesh.size = Vector2(0.16, 0.11)
    var paper := StandardMaterial3D.new()
    paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    paper.vertex_color_use_as_albedo = true
    paper.cull_mode = BaseMaterial3D.CULL_DISABLED
    _confetti_mesh.material = paper
    _spark_mesh = BoxMesh.new()
    _spark_mesh.size = Vector3(0.09, 0.55, 0.09)
    var spark := StandardMaterial3D.new()
    spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark.vertex_color_use_as_albedo = true
    spark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _spark_mesh.material = spark
    _streak_mesh = BoxMesh.new()
    _streak_mesh.size = Vector3(0.12, 1.1, 0.12)
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = Color(1.0, 0.9, 0.6)
    glow.emission_enabled = true
    glow.emission = Color(1.0, 0.85, 0.5)
    glow.emission_energy_multiplier = 3.0
    _streak_mesh.material = glow
    for kind in ["confetti", "sparkle", "burst", "streak", "light"]:
        _free[kind] = []
    for i in CONFETTI_POOL:
        _free["confetti"].append(_make_confetti(90, 2.4, true))
    for i in SPARKLE_POOL:
        _free["sparkle"].append(_make_sparkle())
    for i in BURST_POOL:
        _free["burst"].append(_make_burst())
    for i in STREAK_POOL:
        var mi := MeshInstance3D.new()
        mi.mesh = _streak_mesh
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mi.visible = false
        add_child(mi)
        _free["streak"].append(mi)
    for i in LIGHT_POOL:
        var l := OmniLight3D.new()
        l.shadow_enabled = false
        l.visible = false
        add_child(l)
        _free["light"].append(l)
    _storm = _make_confetti(STORM_AMOUNT, 3.6, false)
    _storm.visible = true
    _storm.emitting = false


func _process(delta: float) -> void:
    _clock += delta
    var i := 0
    while i < _pending.size():
        var e: Array = _pending[i]
        if _clock >= e[0]:
            _release(e[1], e[2])
            _pending.remove_at(i)
        else:
            i += 1


# ---- public ------------------------------------------------------------------------

## Paper burst at `pos` flying along `dir` (Vector3.UP for a pop), `amount` is a hint (pool
## emitters are fixed size; smaller bursts just look denser).
func confetti(pos: Vector3, dir := Vector3.UP, spread_deg := 70.0, _amount := 80) -> void:
    stats.confetti += 1
    var p := _acquire("confetti") as GPUParticles3D
    var pm := p.process_material as ParticleProcessMaterial
    pm.spread = spread_deg
    p.global_position = pos
    var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT
    p.global_basis = Basis.looking_at(dir.normalized(), up) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
    p.emitting = false
    p.emitting = true
    _release_after(p, "confetti", 2.7)


## The finale's confetti storm from the cake top (continuous until stopped).
func storm(pos: Vector3, on: bool) -> void:
    _storm.global_position = pos
    _storm.emitting = on


func sparkle(pos: Vector3) -> void:
    var p := _acquire("sparkle") as GPUParticles3D
    p.global_position = pos
    p.emitting = false
    p.emitting = true
    _release_after(p, "sparkle", 1.0)


## A rocket rises ~9 m from `from` over 0.9 s, then bursts in `color`.
func firework(from: Vector3, color: Color) -> void:
    stats.fireworks += 1
    Sfx.play("firework_launch", from, -4.0, 0.15)
    var s := _acquire("streak") as MeshInstance3D
    s.global_position = from
    s.rotation = Vector3(0, 0, randf_range(-0.12, 0.12))
    var apex := from + Vector3(randf_range(-2.0, 2.0), randf_range(8.0, 11.0), randf_range(-2.0, 2.0))
    var tw := _tween(s)
    tw.tween_property(s, "global_position", apex, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    tw.tween_callback(func() -> void: burst(apex, color))
    _release_after(s, "streak", 0.92)


func burst(pos: Vector3, color: Color) -> void:
    var p := _acquire("burst") as GPUParticles3D
    p.global_position = pos
    var pm := p.process_material as ParticleProcessMaterial
    pm.color = color
    p.emitting = false
    p.emitting = true
    _release_after(p, "burst", 1.8)
    var l := _acquire("light") as OmniLight3D
    l.global_position = pos
    l.light_color = color
    l.light_energy = 10.0
    l.omni_range = 16.0
    _tween(l).tween_property(l, "light_energy", 0.0, 0.5)
    _release_after(l, "light", 0.55)
    Sfx.play("firework_burst", pos, 0.0, 0.12)
    Vfx.shake.emit(pos, 0.35)


# ---- pool ----------------------------------------------------------------------------

func _make_confetti(amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = amount
    p.lifetime = lifetime
    p.one_shot = one_shot
    p.explosiveness = 0.95 if one_shot else 0.0
    p.local_coords = false
    p.draw_pass_1 = _confetti_mesh
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3(0, 1, 0)
    pm.spread = 70.0
    pm.initial_velocity_min = 5.0 if one_shot else 9.0
    pm.initial_velocity_max = 11.0 if one_shot else 16.0
    pm.gravity = Vector3(0, -3.2, 0)
    pm.damping_min = 1.6
    pm.damping_max = 3.2
    pm.scale_min = 0.7
    pm.scale_max = 1.5
    pm.angle_min = 0.0
    pm.angle_max = 360.0
    pm.angular_velocity_min = -540.0
    pm.angular_velocity_max = 540.0
    pm.particle_flag_rotate_y = true
    pm.color_initial_ramp = _party_ramp()
    if not one_shot:
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        pm.emission_box_extents = Vector3(1.6, 0.3, 1.6)
    else:
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        pm.emission_sphere_radius = 0.25
    p.process_material = pm
    p.emitting = false
    p.visible = false
    add_child(p)
    return p


func _make_sparkle() -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = 28
    p.lifetime = 0.8
    p.one_shot = true
    p.explosiveness = 1.0
    p.local_coords = false
    var quad := QuadMesh.new()
    quad.size = Vector2(0.35, 0.35)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.albedo_texture = Vfx._radial
    m.albedo_color = PartyText.GOLD
    m.vertex_color_use_as_albedo = true
    quad.material = m
    p.draw_pass_1 = quad
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3(0, 1, 0)
    pm.spread = 180.0
    pm.initial_velocity_min = 2.5
    pm.initial_velocity_max = 6.0
    pm.gravity = Vector3(0, -2.0, 0)
    pm.damping_min = 2.0
    pm.damping_max = 4.0
    pm.scale_min = 0.5
    pm.scale_max = 1.2
    pm.color_ramp = _fade_ramp(Color(1, 1, 0.85), PartyText.GOLD)
    p.process_material = pm
    p.emitting = false
    p.visible = false
    add_child(p)
    return p


func _make_burst() -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = 110
    p.lifetime = 1.5
    p.one_shot = true
    p.explosiveness = 1.0
    p.local_coords = false
    p.draw_pass_1 = _spark_mesh
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3(0, 1, 0)
    pm.spread = 180.0
    pm.initial_velocity_min = 9.0
    pm.initial_velocity_max = 14.0
    pm.gravity = Vector3(0, -3.5, 0)
    pm.damping_min = 4.0
    pm.damping_max = 6.5
    pm.scale_min = 0.6
    pm.scale_max = 1.2
    pm.particle_flag_align_y = true
    pm.color = Color.WHITE
    pm.color_ramp = _fade_ramp(Color(1, 1, 1), Color(1, 1, 1))
    p.process_material = pm
    p.emitting = false
    p.visible = false
    add_child(p)
    return p


func _party_ramp() -> GradientTexture1D:
    var g := Gradient.new()
    g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
    var colors := PackedColorArray()
    var offsets := PackedFloat32Array()
    for i in PartyText.PALETTE.size():
        colors.append(PartyText.PALETTE[i])
        offsets.append(float(i) / PartyText.PALETTE.size())
    g.colors = colors
    g.offsets = offsets
    var t := GradientTexture1D.new()
    t.gradient = g
    t.width = 64
    return t


func _fade_ramp(a: Color, b: Color) -> GradientTexture1D:
    var g := Gradient.new()
    g.colors = PackedColorArray([a, b, Color(b.r, b.g, b.b, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    var t := GradientTexture1D.new()
    t.gradient = g
    t.width = 32
    return t


func _acquire(kind: String) -> Node:
    var list: Array = _free[kind]
    var n: Node = list.pop_back() if not list.is_empty() else null
    if n == null:
        match kind:
            "confetti":
                n = _make_confetti(90, 2.4, true)
            "sparkle":
                n = _make_sparkle()
            "burst":
                n = _make_burst()
            "light":
                n = OmniLight3D.new()
                n.shadow_enabled = false
                add_child(n)
            _:
                n = MeshInstance3D.new()
                n.mesh = _streak_mesh
                add_child(n)
    _kill_tween(n)
    if n is Node3D:
        n.visible = true
        n.scale = Vector3.ONE
        n.rotation = Vector3.ZERO
    return n


func _release(n: Node, kind: String) -> void:
    if not is_instance_valid(n):
        return
    _kill_tween(n)
    if n is GPUParticles3D:
        n.emitting = false
    if n is Node3D:
        n.visible = false
        n.position = Vector3(0, -100, 0)
    _free[kind].append(n)


func _release_after(n: Node, kind: String, seconds: float) -> void:
    _pending.append([_clock + seconds, n, kind])


func _tween(n: Node) -> Tween:
    _kill_tween(n)
    var tw := n.create_tween()
    _tweens[n] = tw
    return tw


func _kill_tween(n: Node) -> void:
    var tw: Tween = _tweens.get(n)
    if tw != null:
        if tw.is_valid():
            tw.kill()
        _tweens.erase(n)
