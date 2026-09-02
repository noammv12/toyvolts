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
## What a shot that hits this body sounds and looks like (Vfx.SURFACES). Textured surfaces
## infer it from the ambientCG set they use; flat-coloured blocks and kit models are toy
## plastic unless a map says otherwise.
const SURFACE_BY_TEXTURE := {
    "Wood": "wood", "Carpet": "fabric", "Fabric": "fabric",
    "Wallpaper": "paper", "Tiles": "plastic", "Plastic": "plastic",
}
## The same idea for kit models, keyed on the file name. Anything unlisted is toy plastic.
const SURFACE_BY_MODEL := {
    "kitchencounter": "metal", "kitchencabinet": "metal", "stove": "metal", "oven": "metal",
    "fridge": "metal", "sink": "metal", "extractorhood": "metal", "dishrack": "metal",
    "pot_": "metal", "pan_": "metal", "knife": "metal", "Can_": "metal", "Barrel": "metal",
    "crate": "wood", "chair": "wood", "table": "wood", "cuttingboard": "wood",
    "cabinet_": "wood", "shelf": "wood", "bookcase": "wood", "door_": "wood",
    "bed_": "fabric", "couch": "fabric", "pillow": "fabric", "rug": "fabric",
    "Box_": "paper", "book": "paper", "menu": "paper",
}

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
var _mat_surface := {}     ## Material -> surface kind, filled in by _pbr()


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
    p = safe_spawn(p)
    if Net.has_local_human():
        spawn_human(1, 1, Game.player_name, Game.skin, team, p, atan2(p.x, p.z), true)
    match Game.mode:
        "ffa", "elim", "party":
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


## A clear place to stand at (or near) `at`: the standing capsule must not overlap world
## geometry or another toy. Tries the spot, then rings of offsets out to ~3.6 m, then straight
## up. Bots idle on spawn points and props get added to maps, so the raw table is never trusted.
const SPAWN_RING_STEP := 1.2
const SPAWN_RINGS := 3

func safe_spawn(at: Vector3, exclude: Node = null) -> Vector3:
    if spawn_clear(at, exclude):
        return at
    for ring in range(1, SPAWN_RINGS + 1):
        var r := SPAWN_RING_STEP * ring
        for k in 8:
            var a := TAU * k / 8.0 + ring * 0.3
            var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
            if spawn_clear(p, exclude):
                return p
    for up in [1.0, 2.0, 3.0]:
        var p := at + Vector3(0, up, 0)
        if spawn_clear(p, exclude):
            return p
    return at


## The standing silhouette at `at` (feet) touches nothing solid: neither walls / furniture
## nor another toy's body.
func spawn_clear(at: Vector3, exclude: Node = null) -> bool:
    var world := get_world_3d()
    if world == null:
        return true
    var cap := CapsuleShape3D.new()
    cap.radius = 0.3
    cap.height = 1.7
    var q := PhysicsShapeQueryParameters3D.new()
    q.shape = cap
    q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.12 + 0.85, 0))
    q.collision_mask = Character.LAYER_WORLD | Character.LAYER_CHARACTER
    if exclude is CollisionObject3D:
        q.exclude = [exclude.get_rid()]
    var space := world.direct_space_state
    if not space.intersect_shape(q, 1).is_empty():
        return false
    # kit furniture is a hollow trimesh: a capsule in the pocket under a couch arm touches no
    # triangle, but the toy (and its camera) is inside the couch. Reject any spot whose chest
    # point lies within a placed model's box, plus a little clearance around it.
    var chest := at + Vector3(0, 0.9, 0)
    for box: AABB in furniture_boxes:
        if box.grow(FURNITURE_MARGIN).has_point(chest):
            return false
    return true


const FURNITURE_MARGIN := 0.3
var furniture_boxes: Array[AABB] = []     ## world boxes of every solid kit model (spawn checks)


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
        if Game.mode == "party":   # party guests: pastel toys with party names
            b.display_name = PartyText.GUESTS[i % PartyText.GUESTS.size()]
            b.body_color = PartyText.color(i)
        var p := spawns[(i + 1) % spawns.size()]
        if teams and Game.mode == "ctb" and base_positions.has(b.team):
            p = _side_spawn(b.team, i)
        p = safe_spawn(p)
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
func _box(center: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, grid := false,
        surface := "") -> StaticBody3D:
    return _box_mat(center, size, _mat(color, grid), rot, surface)


## Mark what a body is made of (Vfx.SURFACES). Maps call this for things the texture cannot
## tell us about: metal appliances, cardboard boxes, and so on.
func _tag_surface(body: Node, surface: String) -> Node:
    if body != null and surface != "":
        body.set_meta("surface", surface)
    return body


func _box_mat(center: Vector3, size: Vector3, material: Material, rot := Vector3.ZERO,
        surface := "") -> StaticBody3D:
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
    _tag_surface(body, surface if surface != "" else _mat_surface.get(material, "plastic"))
    return body


## Instances a kit model (GLTF/GLB), scales it, routes materials through the toon shader and
## gives every mesh a trimesh collider that also feeds the navmesh.
func _place(path: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, collide := true,
        surface := "") -> Node3D:
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
        var box := AABB()
        for mi in inst.find_children("*", "MeshInstance3D", true, false):
            var world_box: AABB = mi.global_transform * mi.get_aabb()
            box = world_box if box.size == Vector3.ZERO else box.merge(world_box)
            mi.create_trimesh_collision()
            for c in mi.get_children():
                if c is StaticBody3D:
                    c.add_to_group(NAV_GROUP)
                    c.collision_layer = Character.LAYER_WORLD
                    _tag_surface(c, surface if surface != "" else _model_surface(path))
            box_count += 1
        if box.size.length() > 1.0:
            furniture_boxes.append(box)
    return inst


## Guess what a kit model is made of from its file name (see SURFACE_BY_MODEL).
func _model_surface(path: String) -> String:
    var file := path.get_file()
    for tag in SURFACE_BY_MODEL:
        if file.contains(tag):
            return SURFACE_BY_MODEL[tag]
    return "plastic"


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
    for tag in SURFACE_BY_TEXTURE:
        if color_path.contains(tag):
            _mat_surface[m] = SURFACE_BY_TEXTURE[tag]
            break
    return m
