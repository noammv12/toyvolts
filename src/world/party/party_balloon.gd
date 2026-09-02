class_name PartyBalloon
extends StaticBody3D
## A tethered helium balloon: bobs on its string, pops into confetti when shot. Lives on the
## target layer so toys walk through it but every gun, rocket and swing can hit it.

signal popped(balloon: PartyBalloon)

const TOON: Shader = preload("res://shaders/toon.gdshader")

static var _mats := {}
static var _string_mesh: CylinderMesh

var index := 0
var color := PartyText.PINK
var anchor := Vector3.ZERO      ## where the string is tied
var height := 4.0               ## string length
var is_popped := false
var _visual: Node3D
var _string: MeshInstance3D
var _phase := 0.0
var _t := 0.0


func _ready() -> void:
    add_to_group("shootable")
    add_to_group("balloons")
    collision_layer = Character.LAYER_TARGET
    collision_mask = 0
    _phase = index * 1.37
    _t = _phase
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.82
    shape.shape = sphere
    add_child(shape)
    _visual = Node3D.new()
    add_child(_visual)
    var ball := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.62
    sm.height = 1.24
    sm.radial_segments = 20
    sm.rings = 10
    ball.mesh = sm
    ball.scale = Vector3(1.0, 1.18, 1.0)
    ball.material_override = _mat(color)
    _visual.add_child(ball)
    var knot := MeshInstance3D.new()
    var km := CylinderMesh.new()
    km.top_radius = 0.11
    km.bottom_radius = 0.03
    km.height = 0.16
    km.radial_segments = 8
    knot.mesh = km
    knot.position = Vector3(0, -0.78, 0)
    knot.material_override = _mat(color)
    knot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visual.add_child(knot)
    if _string_mesh == null:
        _string_mesh = CylinderMesh.new()
        _string_mesh.top_radius = 0.016
        _string_mesh.bottom_radius = 0.016
        _string_mesh.height = 1.0
        _string_mesh.radial_segments = 5
        _string_mesh.rings = 1
    _string = MeshInstance3D.new()
    _string.mesh = _string_mesh
    _string.material_override = _mat(PartyText.CREAM)
    _string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _string.top_level = true
    add_child(_string)
    global_position = anchor + Vector3(0, height, 0)
    _update_string()


func _process(delta: float) -> void:
    _t += delta
    var bob := Vector3(sin(_t * 0.7 + _phase) * 0.28, height + sin(_t * 1.4 + _phase) * 0.2, cos(_t * 0.9 + _phase) * 0.28)
    global_position = anchor + bob
    _visual.rotation.z = sin(_t * 0.8 + _phase) * 0.08
    _update_string()


func _update_string() -> void:
    var from := anchor
    var to := global_position + Vector3(0, -0.85, 0)
    var d := to - from
    var length := d.length()
    if length < 0.05:
        _string.visible = false
        return
    _string.visible = not is_popped
    _string.global_position = (from + to) * 0.5
    var up := Vector3.RIGHT if absf(d.normalized().y) > 0.99 else Vector3.UP
    _string.global_basis = Basis.looking_at(d.normalized(), up) * Basis(Vector3.RIGHT, deg_to_rad(90.0))
    _string.scale = Vector3(1, length, 1)


func on_shot(_by: Character, _pos: Vector3, dir: Vector3, _weapon: WeaponData) -> void:
    if is_popped:
        return
    pop(true, dir)
    popped.emit(self)


func pop(effects: bool, dir := Vector3.UP) -> void:
    is_popped = true
    _visual.visible = false
    _string.visible = false
    set_deferred("collision_layer", 0)
    set_process(false)
    if effects:
        var fx := _fx()
        if fx != null:
            fx.confetti(global_position, (dir + Vector3.UP * 0.6).normalized(), 90.0, 60)
        Sfx.play("balloon_pop", global_position, 0.0, 0.12)


func inflate(effects: bool) -> void:
    is_popped = false
    _visual.visible = true
    set_deferred("collision_layer", Character.LAYER_TARGET)
    set_process(true)
    _update_string()
    if effects:
        Vfx.jump_puff(global_position)


func _fx() -> PartyFx:
    var p := get_tree().get_first_node_in_group("party")
    return p.fx if p != null else null


static func _mat(c: Color) -> ShaderMaterial:
    if _mats.has(c):
        return _mats[c]
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", c)
    m.set_shader_parameter("spec_strength", 0.7)
    m.set_shader_parameter("spec_size", 0.12)
    m.set_shader_parameter("rim_strength", 0.35)
    _mats[c] = m
    return m
