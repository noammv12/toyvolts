class_name PartyCandle
extends StaticBody3D
## One of the twelve candles on the cake. Shoot it (any weapon, or a splash) to blow it out:
## the flame becomes a smoke puff and a squeak. Relit by the party reset.

signal blown_out(candle: PartyCandle)

const TOON: Shader = preload("res://shaders/toon.gdshader")
const HEIGHT := 1.3

var index := 0
var lit := true
var color := PartyText.PINK
var _flame: Sprite3D
var _core: Sprite3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
    add_to_group("shootable")
    add_to_group("candles")
    collision_layer = Character.LAYER_WORLD
    collision_mask = 0
    _t = randf() * 10.0
    var shape := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.radius = 0.34
    cyl.height = HEIGHT + 0.7
    shape.shape = cyl
    shape.position = Vector3(0, (HEIGHT + 0.7) * 0.5, 0)
    add_child(shape)
    # wax
    var body := MeshInstance3D.new()
    var bm := CylinderMesh.new()
    bm.top_radius = 0.15
    bm.bottom_radius = 0.17
    bm.height = HEIGHT
    bm.radial_segments = 12
    body.mesh = bm
    body.position = Vector3(0, HEIGHT * 0.5, 0)
    body.material_override = _mat(color, 0.35)
    add_child(body)
    # spiral stripes: three thin white rings
    for i in 3:
        var ring := MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.14
        tm.outer_radius = 0.19
        tm.rings = 14
        tm.ring_segments = 5
        ring.mesh = tm
        ring.position = Vector3(0, 0.25 + i * 0.4, 0)
        ring.rotation = Vector3(deg_to_rad(12.0), 0, 0)
        ring.material_override = _mat(PartyText.CREAM, 0.3)
        ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(ring)
    var wick := MeshInstance3D.new()
    var wm := CylinderMesh.new()
    wm.top_radius = 0.025
    wm.bottom_radius = 0.025
    wm.height = 0.16
    wm.radial_segments = 6
    wick.mesh = wm
    wick.position = Vector3(0, HEIGHT + 0.07, 0)
    wick.material_override = _mat(Color(0.15, 0.12, 0.1), 0.0)
    wick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(wick)
    _flame = Vfx._sprite_node(Vfx._radial, Color(1.0, 0.7, 0.25, 1.0), 1.05, true)
    _flame.position = Vector3(0, HEIGHT + 0.36, 0)
    add_child(_flame)
    _core = Vfx._sprite_node(Vfx._radial, Color(1.0, 1.0, 0.85, 1.0), 0.42, true)
    _core.position = Vector3(0, HEIGHT + 0.3, 0)
    add_child(_core)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.8, 0.45)
    _light.light_energy = 1.3
    _light.omni_range = 4.5
    _light.omni_attenuation = 1.4
    _light.shadow_enabled = false
    _light.position = Vector3(0, HEIGHT + 0.5, 0)
    add_child(_light)


func _process(delta: float) -> void:
    _t += delta
    var f := 0.86 + 0.14 * sin(_t * 23.0) * sin(_t * 7.3)
    _flame.scale = Vector3(0.9 + 0.1 * sin(_t * 11.0), 1.15 + 0.22 * sin(_t * 17.0), 1.0) * f
    _flame.position.x = sin(_t * 9.0) * 0.02
    _light.light_energy = 1.2 * f


func flame_position() -> Vector3:
    return global_position + Vector3(0, HEIGHT + 0.35, 0)


func on_shot(_by: Character, _pos: Vector3, _dir: Vector3, _weapon: WeaponData) -> void:
    if not lit:
        return
    set_lit(false, true)
    blown_out.emit(self)


func set_lit(on: bool, effects: bool) -> void:
    lit = on
    _flame.visible = on
    _core.visible = on
    _light.visible = on
    set_process(on)
    if effects:
        var p := flame_position()
        if on:
            Vfx.muzzle_flash(p, Vector3.UP, 0.5)
        else:
            Vfx.puff(p, Color(0.75, 0.75, 0.78, 0.7), 0.6, 1.4, 1.3)
            Sfx.play("candle_out", p, 0.0, 0.1)
            Sfx.play("squeak", p, -3.0, 0.25)


func _mat(c: Color, spec: float) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", c)
    m.set_shader_parameter("spec_strength", spec)
    return m
