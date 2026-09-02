extends Node3D
## Greybox arena at toy scale (a 1.8 m figure in a 48 m room). Built from a box table so the
## layout is easy to iterate. Replaced by a real map in the art milestone.

const TOON: Shader = preload("res://shaders/toon.gdshader")

const COL_FLOOR := Color(0.88, 0.85, 0.78)
const COL_WALL := Color(0.6, 0.72, 0.86)
const COL_PLATFORM := Color(0.55, 0.8, 0.6)
const COL_RAMP := Color(0.5, 0.74, 0.56)
const COL_CRATE := Color(0.95, 0.62, 0.24)
const COL_CRATE2 := Color(0.9, 0.45, 0.3)
const COL_PILLAR := Color(0.75, 0.6, 0.9)
const COL_TABLE := Color(0.62, 0.42, 0.28)

const ROOM := 48.0
const WALL_H := 6.0

var _mats := {}
var box_count := 0


func _ready() -> void:
    _build()


func _build() -> void:
    var half := ROOM * 0.5
    # floor + walls
    _box(Vector3(0, -0.5, 0), Vector3(ROOM, 1, ROOM), COL_FLOOR, Vector3.ZERO, true)
    _box(Vector3(0, WALL_H * 0.5, -half - 0.5), Vector3(ROOM + 2, WALL_H, 1), COL_WALL)
    _box(Vector3(0, WALL_H * 0.5, half + 0.5), Vector3(ROOM + 2, WALL_H, 1), COL_WALL)
    _box(Vector3(-half - 0.5, WALL_H * 0.5, 0), Vector3(1, WALL_H, ROOM + 2), COL_WALL)
    _box(Vector3(half + 0.5, WALL_H * 0.5, 0), Vector3(1, WALL_H, ROOM + 2), COL_WALL)

    # central platform with two ramps (rise 2.5 over 6)
    _box(Vector3(0, 1.25, 0), Vector3(8, 2.5, 8), COL_PLATFORM)
    var angle := atan(2.5 / 6.0)
    var ramp_len := sqrt(2.5 * 2.5 + 6.0 * 6.0) + 0.4
    _box(Vector3(7.0, 1.25 - 0.2, 0), Vector3(ramp_len, 0.4, 4), COL_RAMP, Vector3(0, 0, -angle))
    _box(Vector3(-7.0, 1.25 - 0.2, 0), Vector3(ramp_len, 0.4, 4), COL_RAMP, Vector3(0, 0, angle))

    # crate clusters (1 m and 2 m cubes, some stacked)
    for c in [
        Vector3(10, 1, 10), Vector3(12, 1, 10), Vector3(11, 3, 10),
        Vector3(-10, 1, -10), Vector3(-12, 1, -10), Vector3(-11, 3, -10),
        Vector3(14, 1, -14), Vector3(-14, 1, 14),
    ]:
        _box(c, Vector3(2, 2, 2), COL_CRATE)
    for c in [
        Vector3(6, 0.5, 14), Vector3(7, 0.5, 14), Vector3(6.5, 1.5, 14),
        Vector3(-6, 0.5, -14), Vector3(-7, 0.5, -14),
        Vector3(16, 0.5, 2), Vector3(-16, 0.5, -2),
    ]:
        _box(c, Vector3(1, 1, 1), COL_CRATE2)

    # pillars near the corners of the inner square
    for p in [Vector3(16, 0, 16), Vector3(-16, 0, 16), Vector3(16, 0, -16), Vector3(-16, 0, -16)]:
        _box(p + Vector3(0, 2.5, 0), Vector3(1.5, 5, 1.5), COL_PILLAR)

    # a toy-scale table: top at 3.5 m, reachable by the crate stairs beside it
    var table := Vector3(0, 0, -16)
    _box(table + Vector3(0, 3.2, 0), Vector3(10, 0.6, 6), COL_TABLE)
    for leg in [Vector3(4.5, 0, 2.5), Vector3(-4.5, 0, 2.5), Vector3(4.5, 0, -2.5), Vector3(-4.5, 0, -2.5)]:
        _box(table + leg + Vector3(0, 1.45, 0), Vector3(0.6, 2.9, 0.6), COL_TABLE)
    _box(table + Vector3(7.0, 0.5, 0), Vector3(2, 1, 2), COL_CRATE)
    _box(table + Vector3(9.0, 1.0, 0), Vector3(2, 2, 2), COL_CRATE)
    _box(table + Vector3(11.0, 1.5, 0), Vector3(2, 3, 2), COL_CRATE)


func _box(center: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, grid := false) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = center
    body.rotation = rot

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    shape.shape = box_shape
    body.add_child(shape)

    var mesh_instance := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh_instance.mesh = box_mesh
    mesh_instance.material_override = _mat(color, grid)
    body.add_child(mesh_instance)

    add_child(body)
    box_count += 1
    return body


func _mat(color: Color, grid: bool) -> ShaderMaterial:
    var key := [color, grid]
    if _mats.has(key):
        return _mats[key]
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("grid", grid)
    _mats[key] = m
    return m
