class_name ArenaBase
extends Node3D
## Shared arena plumbing: spawn points, match wiring, bots/dummies by Game.mode, navmesh bake,
## and helpers to place kit models, textured boxes and toon materials. Maps override _build().

const TOON: Shader = preload("res://shaders/toon.gdshader")
const DUMMY: PackedScene = preload("res://src/world/target_dummy.tscn")
const BOT: PackedScene = preload("res://src/bots/bot.tscn")
const CHARACTER: PackedScene = preload("res://src/character/character.tscn")
const PLAYER_COLOR := Color(0.95, 0.42, 0.2)
const BOT_NET_ID_BASE := -1     ## bots count down from -1 (peer ids are positive)
const NAV_GROUP := "navmesh_source"

const TEAM_COLORS := {1: Color(0.95, 0.42, 0.2), 2: Color(0.25, 0.5, 0.95)}
const FFA_COLORS: Array[Color] = [
    Color(0.25, 0.5, 0.95), Color(0.55, 0.8, 0.35), Color(0.85, 0.35, 0.75),
    Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.8), Color(0.6, 0.4, 0.9), Color(0.9, 0.5, 0.3),
]

var spawns: Array[Vector3] = []
var player_start := Vector3.INF               ## offline: where the local toy first stands (else spawns[0])
var dummy_spots: Array[Vector3] = []
var battery_spawns: Array[Vector3] = []     ## Capture the Battery: where cells appear
var base_positions := {}                    ## team -> Vector3 charging pad
var capsule_spawns: Array = []              ## [Vector3, "health" or "ammo"]
var box_count := 0
var navmesh_polys := 0
var local_human: Character
var _mats := {}
var _scene_cache := {}


func _ready() -> void:
    add_to_group("arena")
    Game.apply_quality()
    if not Game.headless:
        add_child(PauseMenu.new())
    _build()
    _bake_navmesh()
    Vfx.warm_up()
    Game.probe_quality()
    if Game.mode == "ctb":
        _build_ctb()
    if Game.mode != "elim":
        _build_capsules()
    var match_node := get_node_or_null("Match") as MatchController
    if match_node:
        match_node.spawn_points = spawns
        match_node.base_positions = base_positions
    _populate()
    Net.on_arena_ready(self)


## Who lives here at the start: the local human, bots by mode, dummies in practice.
func _populate() -> void:
    if Net.is_client():
        return   # the host spawns everyone and tells us
    var teams := Game.mode in ["tdm", "ctb"]
    var team := 1 if teams else 0
    var p := _side_spawn(team, 0) if (Game.mode == "ctb" and base_positions.has(team)) else spawns[0]
    if player_start != Vector3.INF and Game.mode != "ctb":
        p = player_start
    if Net.has_local_human():
        spawn_human(1, 1, Game.player_name, Game.skin, team, p, atan2(p.x, p.z), true)
    match Game.mode:
        "ffa", "elim":
            _spawn_bots(Game.bot_count, false)
        "tdm", "ctb":
            _spawn_bots(Game.bot_count, true)
        _:
            for pos in dummy_spots:
                var d := DUMMY.instantiate() as Character
                d.position = pos
                d.yaw = PI  # face the default spawn
                d.model_id = "Rogue"
                add_child(d)


func local_player() -> Character:
    return local_human


## A human-controlled toy. `local` attaches the keyboard/mouse/camera controller; otherwise the
## body waits for a network controller (server) or snapshots (client puppet).
func spawn_human(net_id: int, peer_id: int, display_name: String, skin: String, team: int,
        pos: Vector3, yaw: float, local: bool) -> Character:
    var c := CHARACTER.instantiate() as Character
    c.name = "C%d" % net_id
    c.net_id = net_id
    c.peer_id = peer_id
    c.display_name = display_name
    c.model_id = skin
    c.team = team
    c.body_color = TEAM_COLORS[team] if team != 0 else PLAYER_COLOR
    c.position = pos
    c.yaw = yaw
    add_child(c)
    if local:
        local_human = c
        PlayerController.attach(c)
    return c


## Map layout goes here.
func _build() -> void:
    pass


## Bases at the two first spawns unless the map placed them; batteries at battery_spawns
## (default: the spawn centroid).
func _build_ctb() -> void:
    if base_positions.is_empty() and spawns.size() >= 2:
        base_positions = {1: spawns[0], 2: spawns[1]}
    if battery_spawns.is_empty():
        var c := Vector3.ZERO
        for p in spawns:
            c += p
        battery_spawns = [c / maxf(spawns.size(), 1.0)]
    for team in base_positions:
        var b := BatteryBase.new()
        b.team = team
        b.position = base_positions[team]
        add_child(b)
    for i in battery_spawns.size():
        var cell := Battery.new()
        cell.net_index = i
        cell.home = battery_spawns[i]
        cell.position = battery_spawns[i]
        add_child(cell)


func _build_capsules() -> void:
    for i in capsule_spawns.size():
        var spec: Array = capsule_spawns[i]
        var cap := ItemCapsule.new()
        cap.net_index = i
        cap.kind = spec[1]
        cap.position = spec[0]
        add_child(cap)


func environment() -> Environment:
    var env := get_node_or_null("Env") as WorldEnvironment
    return env.environment if env else null


func sun() -> DirectionalLight3D:
    return get_node_or_null("Sun") as DirectionalLight3D


func _spawn_bots(count: int, teams: bool) -> void:
    for i in count:
        var b := BOT.instantiate() as Bot
        b.net_id = BOT_NET_ID_BASE - i
        b.display_name = Bot.NAMES[i % Bot.NAMES.size()]
        b.model_id = Skins.ALL[i % Skins.ALL.size()].id
        var range: Array = Bot.SKILL_RANGES.get(Game.bot_difficulty, Bot.SKILL_RANGES["normal"])
        b.skill = randf_range(range[0], range[1])
        if teams:
            b.team = 2 if i % 2 == 0 else 1
            b.body_color = TEAM_COLORS[b.team]
        else:
            b.team = 0
            b.body_color = FFA_COLORS[i % FFA_COLORS.size()]
        var p := spawns[(i + 1) % spawns.size()]
        if teams and Game.mode == "ctb" and base_positions.has(b.team):
            p = _side_spawn(b.team, i)
        b.position = p
        b.yaw = atan2(p.x, p.z)
        add_child(b)


## Spawn points on a team's half (closer to its own base), spread by index.
func _side_spawn(team: int, index: int) -> Vector3:
    var own: Vector3 = base_positions[team]
    var other: Vector3 = base_positions[2 if team == 1 else 1]
    var side: Array[Vector3] = []
    for p in spawns:
        if p.distance_to(own) < p.distance_to(other):
            side.append(p)
    if side.is_empty():
        side = spawns
    return side[index % side.size()]


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
    ToonMat.apply(inst, Color.WHITE, 0.0, 0.25, true)
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
