class_name ArenaBase
extends Node3D
## Shared arena plumbing: spawn points, match wiring, bots/dummies by Game.mode, navmesh bake,
## and helpers to place kit models, textured boxes and toon materials. Maps override _build().

const TOON: Shader = preload("res://shaders/toon.gdshader")
const DUMMY: PackedScene = preload("res://src/world/target_dummy.tscn")
const BOT: PackedScene = preload("res://src/bots/bot.tscn")
const NAV_GROUP := "navmesh_source"

const TEAM_COLORS := {1: Color(0.95, 0.42, 0.2), 2: Color(0.25, 0.5, 0.95)}
const FFA_COLORS: Array[Color] = [
    Color(0.25, 0.5, 0.95), Color(0.55, 0.8, 0.35), Color(0.85, 0.35, 0.75),
    Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.8), Color(0.6, 0.4, 0.9), Color(0.9, 0.5, 0.3),
]

var spawns: Array[Vector3] = []
var dummy_spots: Array[Vector3] = []
var box_count := 0
var navmesh_polys := 0
var _mats := {}
var _scene_cache := {}


func _ready() -> void:
    _build()
    _bake_navmesh()
    Vfx.warm_up()
    var match_node := get_node_or_null("Match") as MatchController
    if match_node:
        match_node.spawn_points = spawns
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
        "elim":
            if player:
                player.team = 0
            _spawn_bots(Game.bot_count, false)
        _:
            for pos in dummy_spots:
                var d := DUMMY.instantiate() as Character
                d.position = pos
                d.yaw = PI  # face the default spawn
                d.model_id = "Rogue"
                add_child(d)


## Map layout goes here.
func _build() -> void:
    pass


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
        var p := spawns[(i + 1) % spawns.size()]
        b.position = p
        b.yaw = atan2(p.x, p.z)
        add_child(b)


func _bake_navmesh() -> void:
    var region := NavigationRegion3D.new()
    var mesh := NavigationMesh.new()
    mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
    mesh.geometry_source_group_name = NAV_GROUP
    mesh.agent_radius = 0.5      # 2 cells
    mesh.agent_height = 2.0      # 8 cells
    mesh.agent_max_climb = 1.0   # 4 cells: 1 m steps are walkable (bots hop them)
    mesh.agent_max_slope = 40.0
    mesh.cell_size = 0.25
    mesh.cell_height = 0.25
    region.navigation_mesh = mesh
    add_child(region)
    region.bake_navigation_mesh(false)
    navmesh_polys = mesh.get_polygon_count()


# ---- building blocks -----------------------------------------------------------

## Flat-coloured collision box (greybox / toy blocks).
func _box(center: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, grid := false) -> StaticBody3D:
    return _box_mat(center, size, _mat(color, grid), rot)


func _box_mat(center: Vector3, size: Vector3, material: Material, rot := Vector3.ZERO) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = center
    body.rotation = rot
    body.add_to_group(NAV_GROUP)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    shape.shape = box_shape
    body.add_child(shape)
    var mesh_instance := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh_instance.mesh = box_mesh
    mesh_instance.material_override = material
    body.add_child(mesh_instance)
    add_child(body)
    box_count += 1
    return body


## Instances a kit model (GLTF/GLB), scales it, routes materials through the toon shader and
## gives every mesh a trimesh collider that also feeds the navmesh.
func _place(path: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, collide := true) -> Node3D:
    var scene: PackedScene = _scene_cache.get(path)
    if scene == null:
        scene = load(path) as PackedScene
        if scene == null:
            push_error("missing kit model " + path)
            return null
        _scene_cache[path] = scene
    var inst := scene.instantiate() as Node3D
    inst.position = pos
    inst.rotation.y = deg_to_rad(yaw_deg)
    inst.scale = Vector3.ONE * scale
    add_child(inst)
    ToonMat.apply(inst)
    if collide:
        for mi in inst.find_children("*", "MeshInstance3D", true, false):
            mi.create_trimesh_collision()
            for c in mi.get_children():
                if c is StaticBody3D:
                    c.add_to_group(NAV_GROUP)
                    c.collision_layer = Character.LAYER_WORLD
            box_count += 1
    return inst


func _mat(color: Color, grid := false) -> ShaderMaterial:
    var key := [color, grid]
    if _mats.has(key):
        return _mats[key]
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("grid", grid)
    _mats[key] = m
    return m


## Textured toon material from an ambientCG-style set (colour + optional normal map).
func _pbr(color_path: String, normal_path := "", uv_scale := Vector2.ONE, tint := Color.WHITE) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", tint)
    m.set_shader_parameter("albedo_tex", load(color_path))
    m.set_shader_parameter("uv_scale", uv_scale)
    if normal_path != "":
        m.set_shader_parameter("normal_tex", load(normal_path))
        m.set_shader_parameter("use_normal_map", true)
    return m
