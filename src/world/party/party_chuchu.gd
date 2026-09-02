class_name PartyChuchu
extends Node3D
## Chuchu, Hila's bulbul: a black-crested, yellow-vented songbird on a perch by the window.
## Sings every few seconds, turns her head, and when shot (or at the finale) flies a loop
## around the room, singing, then lands back on the perch.

signal took_off(bird: PartyChuchu)

const TOON: Shader = preload("res://shaders/toon.gdshader")
const LOOP_CENTER := Vector3(0, 4.8, 0)
const LOOP_RX := 14.0
const LOOP_RZ := 10.0
const TAKEOFF := 1.2
const PERCH_HEIGHT := 3.7

var flying := false
var flights := 0
var flight_seconds := 12.0
var _bird: Node3D
var _head: Node3D
var _wings: Array[MeshInstance3D] = []
var _t := 0.0
var _ft := 0.0
var _sing_in := 4.0
var _turn_in := 2.0
var _head_goal := 0.0
var _theta0 := 0.0
var _mats := {}


func _ready() -> void:
    add_to_group("shootable")
    add_to_group("chuchu")
    # perch: base, pole, crossbar
    _cyl(Vector3(0, 0.08, 0), 0.7, 0.16, Color(0.45, 0.3, 0.2), 0.2)
    _cyl(Vector3(0, PERCH_HEIGHT * 0.5 - 0.1, 0), 0.08, PERCH_HEIGHT - 0.2, Color(0.55, 0.38, 0.24), 0.2)
    var bar := _cyl(Vector3(0, PERCH_HEIGHT - 0.1, 0), 0.06, 1.4, Color(0.62, 0.45, 0.28), 0.2)
    bar.rotation = Vector3(0, 0, deg_to_rad(90.0))
    _bird = Node3D.new()
    _bird.position = Vector3(0, PERCH_HEIGHT + 0.28, 0)
    add_child(_bird)
    var body := _sphere(Vector3.ZERO, 0.32, Color(0.5, 0.46, 0.42), 0.15, _bird)
    body.scale = Vector3(1.0, 0.9, 1.6)
    var belly := _sphere(Vector3(0, -0.08, 0.05), 0.27, Color(0.78, 0.75, 0.7), 0.1, _bird)
    belly.scale = Vector3(1.0, 0.8, 1.5)
    _head = Node3D.new()
    _head.position = Vector3(0, 0.3, 0.34)
    _bird.add_child(_head)
    _sphere(Vector3.ZERO, 0.22, Color(0.1, 0.1, 0.11), 0.3, _head)
    var crest := _cyl(Vector3(0, 0.22, -0.06), 0.0, 0.28, Color(0.1, 0.1, 0.11), 0.2, _head, 0.08)
    crest.rotation = Vector3(deg_to_rad(-25.0), 0, 0)
    for x in [-0.14, 0.14]:
        _sphere(Vector3(x, -0.05, 0.12), 0.08, Color(0.95, 0.95, 0.93), 0.1, _head)   # white cheeks
        _sphere(Vector3(x * 0.9, 0.06, 0.16), 0.035, Color(0.9, 0.75, 0.2), 0.6, _head)  # eyes
    var beak := _cyl(Vector3(0, -0.02, 0.28), 0.0, 0.16, Color(0.15, 0.13, 0.12), 0.3, _head, 0.05)
    beak.rotation = Vector3(deg_to_rad(90.0), 0, 0)
    for x in [-1.0, 1.0]:
        var wing := _sphere(Vector3(x * 0.3, 0.06, 0.0), 0.26, Color(0.42, 0.38, 0.35), 0.15, _bird)
        wing.scale = Vector3(1.0, 0.18, 1.5)
        _wings.append(wing)
    var tail := MeshInstance3D.new()
    var tb := BoxMesh.new()
    tb.size = Vector3(0.12, 0.05, 0.5)
    tail.mesh = tb
    tail.position = Vector3(0, 0.05, -0.62)
    tail.rotation = Vector3(deg_to_rad(-18.0), 0, 0)
    tail.material_override = _mat(Color(0.32, 0.3, 0.28), 0.15)
    _bird.add_child(tail)
    _sphere(Vector3(0, -0.2, -0.4), 0.13, Color(0.98, 0.85, 0.2), 0.3, _bird)   # the yellow vent
    for x in [-0.09, 0.09]:
        _cyl(Vector3(x, -0.33, 0.04), 0.02, 0.22, Color(0.3, 0.25, 0.2), 0.2, _bird)
    var body_col := StaticBody3D.new()
    body_col.collision_layer = Character.LAYER_TARGET
    body_col.collision_mask = 0
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.75
    shape.shape = sphere
    body_col.add_child(shape)
    _bird.add_child(body_col)
    var name_label := Label3D.new()
    name_label.text = PartyText.CHUCHU_NAME
    name_label.font_size = 64
    name_label.pixel_size = 0.009
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_label.position = Vector3(0, 1.0, 0)
    name_label.modulate = PartyText.CREAM
    name_label.outline_size = 10
    name_label.outline_modulate = Color(0.25, 0.2, 0.15)
    _bird.add_child(name_label)
    var sub := Label3D.new()
    sub.text = PartyText.CHUCHU_SUB
    sub.font_size = 36
    sub.pixel_size = 0.009
    sub.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sub.position = Vector3(0, 0.62, 0)
    sub.modulate = PartyText.GOLD
    sub.outline_size = 7
    sub.outline_modulate = Color(0.25, 0.2, 0.15)
    _bird.add_child(sub)


func perch_position() -> Vector3:
    return global_position + Vector3(0, PERCH_HEIGHT + 0.28, 0)


func bird_position() -> Vector3:
    return _bird.global_position


func _process(delta: float) -> void:
    _t += delta
    if flying:
        _fly_step(delta)
        return
    _sing_in -= delta
    if _sing_in <= 0.0:
        _sing_in = randf_range(6.0, 11.0)
        sing()
    _turn_in -= delta
    if _turn_in <= 0.0:
        _turn_in = randf_range(1.5, 4.0)
        _head_goal = randf_range(-0.7, 0.7)
    _head.rotation.y = lerpf(_head.rotation.y, _head_goal, minf(1.0, delta * 6.0))
    _bird.position.y = PERCH_HEIGHT + 0.28 + 0.02 * sin(_t * 3.0)
    for w in _wings:
        w.rotation.z = lerpf(w.rotation.z, 0.0, minf(1.0, delta * 8.0))


func sing() -> void:
    Sfx.play("chirp", bird_position(), 0.0, 0.12)
    var fx := _fx()
    if fx != null:
        fx.sparkle(bird_position() + Vector3(0, 0.6, 0))


func on_shot(_by: Character, _pos: Vector3, _dir: Vector3, _weapon: WeaponData) -> void:
    if flying:
        return
    fly(true)
    took_off.emit(self)


## Take off, loop the room for `flight_seconds`, land back on the perch.
func fly(effects: bool) -> void:
    if flying:
        return
    flying = true
    flights += 1
    _ft = 0.0
    var p := perch_position() - LOOP_CENTER
    _theta0 = atan2(p.z / LOOP_RZ, p.x / LOOP_RX)
    if effects:
        sing()


func _loop_point(theta: float) -> Vector3:
    return LOOP_CENTER + Vector3(cos(theta) * LOOP_RX, 0.7 * sin(theta * 3.0), sin(theta) * LOOP_RZ)


func _fly_step(delta: float) -> void:
    _ft += delta
    var loop_time := maxf(flight_seconds - 2.0 * TAKEOFF, 0.5)
    var perch := perch_position()
    var target: Vector3
    var next: Vector3
    if _ft < TAKEOFF:
        var f := _ft / TAKEOFF
        target = perch.lerp(_loop_point(_theta0), smoothstep(0.0, 1.0, f))
        next = perch.lerp(_loop_point(_theta0), smoothstep(0.0, 1.0, minf(f + 0.05, 1.0)))
    elif _ft < TAKEOFF + loop_time:
        var theta := _theta0 + (_ft - TAKEOFF) / loop_time * TAU
        target = _loop_point(theta)
        next = _loop_point(theta + 0.05)
        if fmod(_ft, 1.6) < delta:
            sing()
    elif _ft < flight_seconds:
        var f := (_ft - TAKEOFF - loop_time) / TAKEOFF
        target = _loop_point(_theta0).lerp(perch, smoothstep(0.0, 1.0, f))
        next = perch
    else:
        _bird.global_position = perch
        _bird.rotation = Vector3.ZERO
        flying = false
        Sfx.play("chirp", perch, -3.0, 0.2)
        return
    _bird.global_position = target
    if next.distance_to(target) > 0.01:
        _bird.look_at(next, Vector3.UP)
    var flap := sin(_ft * 24.0) * 0.9
    _wings[0].rotation.z = flap
    _wings[1].rotation.z = -flap


func _fx() -> PartyFx:
    var p := get_tree().get_first_node_in_group("party")
    return p.fx if p != null else null


# ---- builders ---------------------------------------------------------------------

func _mat(c: Color, spec: float) -> ShaderMaterial:
    var key := [c, spec]
    if _mats.has(key):
        return _mats[key]
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", c)
    m.set_shader_parameter("spec_strength", spec)
    _mats[key] = m
    return m


func _sphere(pos: Vector3, r: float, c: Color, spec: float, parent: Node3D = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 14
    sm.rings = 7
    mi.mesh = sm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    (parent if parent != null else self).add_child(mi)
    return mi


func _cyl(pos: Vector3, r_top: float, h: float, c: Color, spec: float, parent: Node3D = null, r_bottom := -1.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r_top
    cm.bottom_radius = r_top if r_bottom < 0.0 else r_bottom
    cm.height = h
    cm.radial_segments = 10
    cm.rings = 1
    mi.mesh = cm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    (parent if parent != null else self).add_child(mi)
    return mi
