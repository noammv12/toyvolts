extends Node3D
## Greybox arena at toy scale (a 1.8 m figure in a 48 m room). Built from a box table so the
## layout is easy to iterate; bakes a navmesh for the bots at runtime. Populates itself
## from Game.mode: practice (dummies), ffa or tdm (bots).

const TOON: Shader = preload("res://shaders/toon.gdshader")
const DUMMY: PackedScene = preload("res://src/world/target_dummy.tscn")
const BOT: PackedScene = preload("res://src/bots/bot.tscn")

const COL_FLOOR := Color(0.88, 0.85, 0.78)
const COL_WALL := Color(0.6, 0.72, 0.86)
const COL_PLATFORM := Color(0.55, 0.8, 0.6)
const COL_RAMP := Color(0.5, 0.74, 0.56)
const COL_CRATE := Color(0.95, 0.62, 0.24)
const COL_CRATE2 := Color(0.9, 0.45, 0.3)
const COL_PILLAR := Color(0.75, 0.6, 0.9)
const COL_TABLE := Color(0.62, 0.42, 0.28)

const TEAM_COLORS := {1: Color(0.95, 0.42, 0.2), 2: Color(0.25, 0.5, 0.95)}
const FFA_COLORS: Array[Color] = [
    Color(0.25, 0.5, 0.95), Color(0.55, 0.8, 0.35), Color(0.85, 0.35, 0.75),
    Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.8), Color(0.6, 0.4, 0.9), Color(0.9, 0.5, 0.3),
]

const ROOM := 48.0
const WALL_H := 6.0

const SPAWNS: Array[Vector3] = [
    Vector3(0, 0.2, 18), Vector3(0, 0.2, -20), Vector3(20, 0.2, 0), Vector3(-20, 0.2, 0),
    Vector3(18, 0.2, 18), Vector3(-18, 0.2, -18), Vector3(18, 0.2, -18), Vector3(-18, 0.2, 18),
]
const DUMMIES: Array[Vector3] = [Vector3(5, 0.2, 8), Vector3(0, 2.7, 0), Vector3(-12, 0.2, -6)]

var _mats := {}
var box_count := 0
var navmesh_polys := 0


func _ready() -> void:
    var match_node := get_node_or_null("Match") as MatchController
    if match_node:
        match_node.spawn_points = SPAWNS
    _build()
    _bake_navmesh()
    var player := get_node_or_null("Player") as Player
    match Game.mode:
        "ffa":
            if player:
                player.team = 0
            _spawn_bots(Game.bot_count, false)
        "tdm":
            if player:
                player.team = 1
                player.set_color(TEAM_COLORS[1])
            _spawn_bots(Game.bot_count, true)
        _:
            for pos in DUMMIES:
                var d := DUMMY.instantiate() as Character
                d.position = pos
                d.yaw = PI  # face the default spawn
                d.model_id = "Rogue"
                add_child(d)


func _spawn_bots(count: int, teams: bool) -> void:
    for i in count:
        var b := BOT.instantiate() as Bot
        b.display_name = Bot.NAMES[i % Bot.NAMES.size()]
        b.model_id = Skins.ALL[i % Skins.ALL.size()].id
        b.skill = randf_range(0.35, 0.75)
        if teams:
            b.team = 2 if i % 2 == 0 else 1
            b.body_color = TEAM_COLORS[b.team]
        else:
            b.team = 0
            b.body_color = FFA_COLORS[i % FFA_COLORS.size()]
        var p := SPAWNS[(i + 1) % SPAWNS.size()]
        b.position = p
        b.yaw = atan2(p.x, p.z)
        add_child(b)


func _bake_navmesh() -> void:
    var region := NavigationRegion3D.new()
    var mesh := NavigationMesh.new()
    mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
    mesh.geometry_source_group_name = "navmesh_source"
    mesh.agent_radius = 0.5      # 2 cells
    mesh.agent_height = 2.0      # 8 cells
    mesh.agent_max_climb = 1.0   # 4 cells: the 1 m crate steps are walkable (bots hop them)
    mesh.agent_max_slope = 40.0
    mesh.cell_size = 0.25
    mesh.cell_height = 0.25
    region.navigation_mesh = mesh
    add_child(region)
    region.bake_navigation_mesh(false)
    navmesh_polys = mesh.get_polygon_count()


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
    body.add_to_group("navmesh_source")

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
