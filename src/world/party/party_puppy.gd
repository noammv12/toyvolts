class_name PartyPuppy
extends Node3D
## A plush puppy (primitives) that hops after its owner along the navmesh, wags and yips.

const TOON: Shader = preload("res://shaders/toon.gdshader")
const SPEED := 5.5
const FOLLOW_DIST := 2.4

var owner_character: Character
var _nav: NavigationAgent3D
var _t := 0.0
var _retarget := 0.0
var _yip := 3.0
var _tail: MeshInstance3D
var _ears: Array[MeshInstance3D] = []
var _bodyroot: Node3D
var _moving := false
var travelled := 0.0


func _ready() -> void:
    add_to_group("puppies")
    _nav = NavigationAgent3D.new()
    _nav.path_desired_distance = 0.6
    _nav.target_desired_distance = FOLLOW_DIST
    _nav.path_max_distance = 4.0
    add_child(_nav)
    _bodyroot = Node3D.new()
    add_child(_bodyroot)
    var cream := Color(0.97, 0.9, 0.78)
    var brown := Color(0.55, 0.36, 0.22)
    var body := _mesh(_bodyroot, _capsule(0.27, 0.95), Vector3(0, 0.55, 0), cream)
    body.rotation = Vector3(deg_to_rad(90.0), 0, 0)
    _mesh(_bodyroot, _sphere(0.3), Vector3(0, 0.82, 0.48), cream)                 # head
    _mesh(_bodyroot, _sphere(0.14), Vector3(0, 0.74, 0.74), brown)                # snout
    _mesh(_bodyroot, _sphere(0.05), Vector3(0, 0.8, 0.86), Color(0.1, 0.08, 0.08)) # nose
    for x in [-0.12, 0.12]:
        _mesh(_bodyroot, _sphere(0.045), Vector3(x, 0.92, 0.72), Color(0.08, 0.08, 0.1))   # eyes
    for x in [-0.3, 0.3]:
        var ear := _mesh(_bodyroot, _sphere(0.13), Vector3(x, 0.8, 0.42), brown)
        ear.scale = Vector3(0.5, 1.4, 0.8)
        _ears.append(ear)
    for x in [-0.17, 0.17]:
        for z in [-0.3, 0.3]:
            _mesh(_bodyroot, _cyl(0.08, 0.34), Vector3(x, 0.17, z), cream)      # legs
    _tail = _mesh(_bodyroot, _cyl(0.05, 0.42), Vector3(0, 0.72, -0.5), cream)
    _tail.rotation = Vector3(deg_to_rad(-50.0), 0, 0)
    var collar := _mesh(_bodyroot, _torus(0.2, 0.26), Vector3(0, 0.72, 0.28), PartyText.TEAL)
    collar.rotation = Vector3(deg_to_rad(80.0), 0, 0)
    var hat := PartyHat.build(PartyText.GOLD, 0.35)
    hat.position = Vector3(0, 1.05, 0.44)
    hat.rotation = Vector3(deg_to_rad(-15.0), 0, 0)
    _bodyroot.add_child(hat)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = pos
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", c)
    m.set_shader_parameter("spec_strength", 0.15)
    mi.material_override = m
    parent.add_child(mi)
    return mi


func _sphere(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 12
    s.rings = 6
    return s


func _capsule(r: float, h: float) -> CapsuleMesh:
    var c := CapsuleMesh.new()
    c.radius = r
    c.height = h
    c.radial_segments = 12
    c.rings = 4
    return c


func _cyl(r: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = r
    c.bottom_radius = r
    c.height = h
    c.radial_segments = 8
    c.rings = 1
    return c


func _torus(inner: float, outer: float) -> TorusMesh:
    var t := TorusMesh.new()
    t.inner_radius = inner
    t.outer_radius = outer
    t.rings = 12
    t.ring_segments = 6
    return t


func _physics_process(delta: float) -> void:
    _t += delta
    _yip -= delta
    if _yip <= 0.0:
        _yip = randf_range(4.0, 9.0)
        Sfx.play("squeak", global_position, -2.0, 0.3)
    _moving = false
    if owner_character != null and is_instance_valid(owner_character):
        _retarget -= delta
        if _retarget <= 0.0:
            _retarget = 0.3
            if _nav.target_position.distance_to(owner_character.global_position) > 0.8:
                _nav.target_position = owner_character.global_position
        var flat := owner_character.global_position - global_position
        flat.y = 0.0
        if flat.length() > FOLLOW_DIST and not _nav.is_navigation_finished():
            var next := _nav.get_next_path_position()
            var d := next - global_position
            var ground_y := next.y
            d.y = 0.0
            if d.length() > 0.05:
                var step := d.normalized() * SPEED * delta
                global_position += step
                global_position.y = lerpf(global_position.y, ground_y, 0.3)
                travelled += step.length()
                rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 0.25)
                _moving = true
    _bodyroot.position.y = absf(sin(_t * 11.0)) * 0.3 if _moving else sin(_t * 2.0) * 0.02
    _tail.rotation = Vector3(deg_to_rad(-50.0), 0, sin(_t * (14.0 if _moving else 6.0)) * 0.6)
    for i in _ears.size():
        _ears[i].rotation.z = sin(_t * 9.0 + i * 2.0) * (0.25 if _moving else 0.06)
