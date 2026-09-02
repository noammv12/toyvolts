class_name PartyCannon
extends Node3D
## Corner confetti cannon: a tube on a tripod aimed at the room, firing a paper burst every
## few seconds (cosmetic, local timers on every peer).

const TOON: Shader = preload("res://shaders/toon.gdshader")

var index := 0
var target := Vector3(0, 8, 0)
var _tube: Node3D
var _next := 3.0
var _dir := Vector3.UP
var shots := 0


func _ready() -> void:
    add_to_group("cannons")
    _next = 2.0 + index * 1.3
    var base := _cyl(self, Vector3(0, 0.15, 0), 0.9, 0.9, 0.3, Color(0.35, 0.36, 0.4), 0.3)
    base.rotation = Vector3.ZERO
    var d := (target - global_position).normalized()
    _dir = d
    _tube = Node3D.new()
    _tube.position = Vector3(0, 1.6, 0)
    var up := Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT
    _tube.basis = Basis.looking_at(d, up)
    add_child(_tube)
    # the tube's axis is local -Z (looking_at); a cylinder is Y-up, so rotate it inside
    var tube := _cyl(_tube, Vector3(0, 0, -1.0), 0.42, 0.52, 2.4, PartyText.HOT_PINK, 0.4)
    tube.rotation = Vector3(deg_to_rad(90.0), 0, 0)
    var ring := _cyl(_tube, Vector3(0, 0, -2.15), 0.56, 0.56, 0.18, PartyText.GOLD, 0.5)
    ring.rotation = Vector3(deg_to_rad(90.0), 0, 0)
    var band := _cyl(_tube, Vector3(0, 0, -0.9), 0.5, 0.5, 0.25, PartyText.TEAL, 0.5)
    band.rotation = Vector3(deg_to_rad(90.0), 0, 0)
    # tripod legs
    for i in 3:
        var a := i * TAU / 3.0
        var leg := _cyl(self, Vector3(sin(a) * 0.45, 0.8, cos(a) * 0.45), 0.06, 0.06, 1.7, Color(0.3, 0.3, 0.34), 0.2)
        leg.rotation = Vector3(-cos(a) * 0.35, 0.0, sin(a) * 0.35)


func _cyl(parent: Node3D, pos: Vector3, r_top: float, r_bottom: float, h: float, c: Color, spec: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r_top
    cm.bottom_radius = r_bottom
    cm.height = h
    cm.radial_segments = 14
    cm.rings = 1
    mi.mesh = cm
    mi.position = pos
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", c)
    m.set_shader_parameter("spec_strength", spec)
    mi.material_override = m
    parent.add_child(mi)
    return mi


func _process(delta: float) -> void:
    _next -= delta
    if _next <= 0.0:
        _next = randf_range(4.0, 7.5)
        fire()


func muzzle() -> Vector3:
    return _tube.global_position + _dir * 2.3


func fire() -> void:
    shots += 1
    var fx := _fx()
    if fx != null:
        fx.confetti(muzzle(), _dir, 22.0, 120)
    Sfx.play("confetti_pop", muzzle(), 0.0, 0.1)
    Vfx.muzzle_flash(muzzle(), _dir, 0.9)
    var tw := create_tween()
    _tube.position = Vector3(0, 1.6, 0) - _dir * 0.35
    tw.tween_property(_tube, "position", Vector3(0, 1.6, 0), 0.35).set_ease(Tween.EASE_OUT)


func _fx() -> PartyFx:
    var p := get_tree().get_first_node_in_group("party")
    return p.fx if p != null else null
