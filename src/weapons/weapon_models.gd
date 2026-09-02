class_name WeaponModels
extends RefCounted
## Chunky two-tone toy weapons built from primitives (nerf-style: rounded plastic bodies,
## muzzle rings, magazines, scope glass). Local -Z is the muzzle direction, origin = grip.
## A node named "Barrels" on the gatling is spun by the Arsenal while firing.

const TOON: Shader = preload("res://shaders/toon.gdshader")
const ORANGE := Color(0.98, 0.5, 0.16)
const NAVY := Color(0.16, 0.22, 0.42)
const YELLOW := Color(0.98, 0.82, 0.22)
const WHITE := Color(0.95, 0.95, 0.93)
const DARK := Color(0.14, 0.14, 0.17)
const STEEL := Color(0.72, 0.75, 0.8)
const WOOD := Color(0.55, 0.36, 0.2)
const GLASS := Color(0.55, 0.85, 1.0)


static func build(d: WeaponData) -> Node3D:
    var root := Node3D.new()
    root.name = "Model_%d" % d.slot
    match d.slot:
        1: _melee(root)
        2: _rifle(root)
        3: _shotgun(root)
        4: _sniper(root)
        5: _gatling(root)
        6: _bazooka(root)
        7: _launcher(root)
    return root


# ---- designs ----------------------------------------------------------------------

static func _melee(r: Node3D) -> void:
    _cap(r, 0.032, 0.9, Vector3(0, 0, -0.32), WOOD)                     # handle
    _box(r, Vector3(0.11, 0.04, 0.09), Vector3(0, 0, 0.16), WOOD)        # D-grip
    _box(r, Vector3(0.26, 0.03, 0.34), Vector3(0, 0, -0.9), STEEL)       # blade
    _box(r, Vector3(0.28, 0.05, 0.05), Vector3(0, 0, -0.75), DARK)       # collar
    _box(r, Vector3(0.2, 0.035, 0.06), Vector3(0, 0, -1.06), STEEL)      # edge


static func _rifle(r: Node3D) -> void:
    _cap(r, 0.07, 0.6, Vector3(0, 0.02, -0.2), ORANGE)                   # body
    _box(r, Vector3(0.06, 0.05, 0.42), Vector3(0, 0.1, -0.2), NAVY)      # top rail
    _box(r, Vector3(0.04, 0.05, 0.04), Vector3(0, 0.15, -0.36), YELLOW)  # front sight
    _cyl(r, 0.03, 0.32, Vector3(0, 0.03, -0.62), NAVY)                   # barrel
    _cyl(r, 0.055, 0.07, Vector3(0, 0.03, -0.76), YELLOW)                # muzzle ring
    _box(r, Vector3(0.06, 0.2, 0.08), Vector3(0, -0.12, -0.12), NAVY)    # magazine
    _box(r, Vector3(0.06, 0.16, 0.07), Vector3(0, -0.1, 0.08), NAVY)     # grip
    _box(r, Vector3(0.09, 0.11, 0.26), Vector3(0, 0.0, 0.26), ORANGE)    # stock
    _box(r, Vector3(0.1, 0.04, 0.06), Vector3(0, -0.06, 0.4), NAVY)      # butt pad


static func _shotgun(r: Node3D) -> void:
    _cap(r, 0.065, 0.55, Vector3(0, 0.0, -0.12), Color(0.82, 0.3, 0.2))  # receiver
    _cyl(r, 0.036, 0.58, Vector3(0.04, 0.05, -0.62), NAVY)               # barrels
    _cyl(r, 0.036, 0.58, Vector3(-0.04, 0.05, -0.62), NAVY)
    _cyl(r, 0.058, 0.06, Vector3(0.04, 0.05, -0.88), YELLOW)             # muzzle rings
    _cyl(r, 0.058, 0.06, Vector3(-0.04, 0.05, -0.88), YELLOW)
    _box(r, Vector3(0.12, 0.08, 0.2), Vector3(0, -0.04, -0.5), YELLOW)   # pump
    _box(r, Vector3(0.09, 0.14, 0.3), Vector3(0, -0.02, 0.22), WOOD)     # stock
    _box(r, Vector3(0.06, 0.14, 0.07), Vector3(0, -0.11, 0.04), WOOD)    # grip
    _box(r, Vector3(0.05, 0.04, 0.05), Vector3(0, 0.12, -0.12), YELLOW)  # rear sight


static func _sniper(r: Node3D) -> void:
    _cap(r, 0.05, 0.85, Vector3(0, 0.0, -0.25), Color(0.2, 0.42, 0.3))   # body
    _cyl(r, 0.024, 0.55, Vector3(0, 0.02, -0.92), NAVY)                  # barrel
    _cyl(r, 0.045, 0.1, Vector3(0, 0.02, -1.2), DARK)                    # brake
    _cyl(r, 0.045, 0.32, Vector3(0, 0.13, -0.22), DARK)                  # scope tube
    _box(r, Vector3(0.03, 0.06, 0.04), Vector3(0, 0.08, -0.12), DARK)    # scope mount
    _box(r, Vector3(0.03, 0.06, 0.04), Vector3(0, 0.08, -0.32), DARK)
    _sphere(r, 0.04, Vector3(0, 0.13, -0.05), GLASS, true)               # eyepiece glass
    _sphere(r, 0.045, Vector3(0, 0.13, -0.4), GLASS, true)               # objective glass
    _box(r, Vector3(0.07, 0.13, 0.32), Vector3(0, -0.02, 0.3), ORANGE)   # stock
    _box(r, Vector3(0.05, 0.14, 0.06), Vector3(0, -0.1, 0.06), ORANGE)   # grip
    _box(r, Vector3(0.05, 0.12, 0.06), Vector3(0, -0.11, -0.3), NAVY)    # magazine
    _cyl(r, 0.012, 0.28, Vector3(0.06, -0.12, -0.7), STEEL)              # bipod legs
    _cyl(r, 0.012, 0.28, Vector3(-0.06, -0.12, -0.7), STEEL)


static func _gatling(r: Node3D) -> void:
    _box(r, Vector3(0.18, 0.2, 0.34), Vector3(0, 0.02, 0.0), Color(0.55, 0.35, 0.7))   # housing
    _cyl(r, 0.13, 0.05, Vector3(0, 0.02, -0.19), YELLOW)                 # front plate
    var barrels := Node3D.new()
    barrels.name = "Barrels"
    barrels.position = Vector3(0, 0.02, -0.55)
    r.add_child(barrels)
    for i in 6:
        var a := TAU * i / 6.0
        _cyl(barrels, 0.022, 0.7, Vector3(cos(a) * 0.065, sin(a) * 0.065, 0.0), DARK)
    _cyl(barrels, 0.1, 0.05, Vector3(0, 0, 0.2), STEEL)                  # barrel clamp
    _cyl(barrels, 0.1, 0.05, Vector3(0, 0, -0.28), STEEL)
    _cyl(r, 0.13, 0.18, Vector3(0.16, -0.02, 0.02), NAVY)                # ammo drum (side)
    _box(r, Vector3(0.05, 0.08, 0.22), Vector3(0, 0.16, 0.0), NAVY)      # top handle
    _box(r, Vector3(0.06, 0.16, 0.08), Vector3(0, -0.15, 0.1), DARK)     # grip
    _box(r, Vector3(0.1, 0.06, 0.12), Vector3(0, -0.06, 0.22), ORANGE)   # rear cap


static func _bazooka(r: Node3D) -> void:
    _cyl(r, 0.1, 1.15, Vector3(0, 0.12, -0.2), Color(0.5, 0.55, 0.32))   # tube
    _cone(r, 0.1, 0.14, 0.14, Vector3(0, 0.12, -0.84), ORANGE)           # muzzle flare
    _cone(r, 0.13, 0.1, 0.12, Vector3(0, 0.12, 0.44), ORANGE)            # exhaust
    _sphere(r, 0.07, Vector3(0, 0.12, -0.86), Color(0.9, 0.25, 0.2), false)  # warhead tip
    _box(r, Vector3(0.14, 0.05, 0.3), Vector3(0, 0.0, 0.15), NAVY)       # shoulder rest
    _box(r, Vector3(0.05, 0.14, 0.07), Vector3(0, -0.07, -0.1), NAVY)    # front grip
    _box(r, Vector3(0.05, 0.14, 0.07), Vector3(0, -0.07, 0.18), NAVY)    # rear grip
    _box(r, Vector3(0.04, 0.09, 0.12), Vector3(0, 0.26, -0.35), YELLOW)  # sight
    _cyl(r, 0.105, 0.06, Vector3(0, 0.12, -0.5), YELLOW)                 # band
    _cyl(r, 0.105, 0.06, Vector3(0, 0.12, 0.1), YELLOW)


static func _launcher(r: Node3D) -> void:
    _cap(r, 0.07, 0.36, Vector3(0, 0.02, -0.02), Color(0.2, 0.6, 0.6))   # receiver
    _cyl(r, 0.11, 0.18, Vector3(0, 0.04, -0.3), ORANGE)                  # revolver drum
    for i in 6:
        var a := TAU * i / 6.0
        _cyl(r, 0.028, 0.19, Vector3(cos(a) * 0.065, 0.04 + sin(a) * 0.065, -0.3), DARK)  # chambers
    _cyl(r, 0.06, 0.34, Vector3(0, 0.04, -0.58), NAVY)                   # barrel
    _cyl(r, 0.085, 0.07, Vector3(0, 0.04, -0.75), YELLOW)                # muzzle ring
    _box(r, Vector3(0.06, 0.15, 0.07), Vector3(0, -0.1, 0.06), NAVY)     # grip
    _box(r, Vector3(0.08, 0.11, 0.22), Vector3(0, 0.0, 0.26), NAVY)      # stock
    _box(r, Vector3(0.04, 0.05, 0.05), Vector3(0, 0.14, -0.55), YELLOW)  # sight


# ---- primitives -------------------------------------------------------------------

static func _mat(color: Color, glossy := true, emissive := false) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("spec_strength", 0.5 if glossy else 0.2)
    m.set_shader_parameter("spec_size", 0.12 if glossy else 0.06)
    if emissive:
        m.set_shader_parameter("flash", 0.35)
    return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, emissive := false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = pos
    mi.rotation = rot
    mi.material_override = _mat(color, true, emissive)
    parent.add_child(mi)
    return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _add(parent, mesh, pos, color)


## Cylinder along local Z.
static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 14
    return _add(parent, mesh, pos, color, Vector3(PI * 0.5, 0, 0))


## Cone/frustum along -Z: `front` is the radius at the -Z end.
static func _cone(parent: Node3D, back: float, front: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = back
    mesh.bottom_radius = front
    mesh.height = length
    mesh.radial_segments = 14
    return _add(parent, mesh, pos, color, Vector3(-PI * 0.5, 0, 0))


## Capsule along local Z (rounded body).
static func _cap(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = length
    mesh.radial_segments = 14
    return _add(parent, mesh, pos, color, Vector3(PI * 0.5, 0, 0))


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emissive: bool) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 14
    mesh.rings = 8
    return _add(parent, mesh, pos, color, Vector3.ZERO, emissive)
