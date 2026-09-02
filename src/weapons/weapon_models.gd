class_name WeaponModels
extends RefCounted
## Placeholder toy weapon models built from primitives. Local -Z is the muzzle direction,
## origin is the grip. Replaced by real models in the art milestone.

const TOON: Shader = preload("res://shaders/toon.gdshader")
const STEEL := Color(0.75, 0.78, 0.82)
const DARK := Color(0.15, 0.15, 0.18)


static func build(d: WeaponData) -> Node3D:
    var root := Node3D.new()
    root.name = "Model_%d" % d.slot
    match d.slot:
        1:
            _box(root, Vector3(0.05, 0.05, 0.9), Vector3(0, 0, -0.35), d.color)
            _box(root, Vector3(0.22, 0.02, 0.3), Vector3(0, 0, -0.9), STEEL)
        2:
            _box(root, Vector3(0.09, 0.14, 0.55), Vector3(0, 0, -0.2), d.color)
            _cyl(root, 0.025, 0.4, Vector3(0, 0.04, -0.65), DARK)
            _box(root, Vector3(0.06, 0.18, 0.08), Vector3(0, -0.14, -0.1), Color(0.95, 0.8, 0.2))
            _box(root, Vector3(0.08, 0.1, 0.25), Vector3(0, -0.02, 0.2), DARK)
        3:
            _box(root, Vector3(0.11, 0.13, 0.4), Vector3(0, 0, -0.15), d.color)
            _cyl(root, 0.045, 0.5, Vector3(0, 0.03, -0.6), DARK)
            _cyl(root, 0.035, 0.45, Vector3(0, -0.05, -0.55), STEEL)
            _box(root, Vector3(0.09, 0.12, 0.25), Vector3(0, -0.02, 0.2), Color(0.45, 0.28, 0.18))
        4:
            _box(root, Vector3(0.08, 0.12, 0.5), Vector3(0, 0, -0.15), d.color)
            _cyl(root, 0.02, 0.75, Vector3(0, 0.03, -0.8), DARK)
            _cyl(root, 0.045, 0.28, Vector3(0, 0.13, -0.2), DARK)
            _box(root, Vector3(0.07, 0.14, 0.3), Vector3(0, -0.03, 0.22), Color(0.4, 0.3, 0.2))
        5:
            _box(root, Vector3(0.16, 0.18, 0.4), Vector3(0, 0, -0.05), d.color)
            for i in 4:
                var a := TAU * i / 4.0
                _cyl(root, 0.025, 0.6, Vector3(cos(a) * 0.05, sin(a) * 0.05, -0.55), DARK)
            _cyl(root, 0.09, 0.08, Vector3(0, 0, -0.28), STEEL)
            _box(root, Vector3(0.14, 0.12, 0.2), Vector3(0, -0.15, 0.05), DARK)
        6:
            _cyl(root, 0.09, 1.1, Vector3(0, 0.12, -0.25), d.color)
            _cyl(root, 0.11, 0.12, Vector3(0, 0.12, -0.8), Color(0.9, 0.35, 0.2))
            _box(root, Vector3(0.06, 0.12, 0.1), Vector3(0, -0.02, -0.1), DARK)
        7:
            _box(root, Vector3(0.1, 0.12, 0.35), Vector3(0, 0, -0.1), d.color)
            _cyl(root, 0.06, 0.4, Vector3(0, 0.02, -0.5), DARK)
            _cyl(root, 0.11, 0.1, Vector3(0, 0.0, -0.2), Color(0.95, 0.65, 0.2))
            _box(root, Vector3(0.08, 0.1, 0.2), Vector3(0, -0.03, 0.15), DARK)
    return root


static func _mat(color: Color) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = _mat(color)
    parent.add_child(mi)
    return mi


static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 12
    mi.mesh = mesh
    mi.position = pos
    mi.rotation_degrees.x = 90.0
    mi.material_override = _mat(color)
    parent.add_child(mi)
    return mi
