extends ArenaBase
## "Diner": a restaurant kitchen at toy scale (KayKit Restaurant Bits x3). A cook line of
## counters, stoves and ovens along the north wall (walkable 3 m ledge), a long counter
## island in the middle (the battery sits on top), fridges and crate stacks as cover, dining
## tables and chairs on the south side, tiled floor, sun through the east windows.

const KIT := "res://assets/env/restaurant/"
const TEX := "res://assets/textures/"
const K := 3.0                 ## kit scale: 1 kit unit = 3 m
const ROOM_X := 48.0
const ROOM_Z := 36.0
const WALL_H := 12.0
const HX := ROOM_X * 0.5
const HZ := ROOM_Z * 0.5
const TOP := 3.0               ## counter / table top height


func _build() -> void:
    spawns = [
        Vector3(-21, 0.3, 10), Vector3(21, 0.3, -10), Vector3(-21, 0.3, -10), Vector3(21, 0.3, 10),
        Vector3(-6.5, 0.3, 5), Vector3(3, 0.3, -8), Vector3(-8, 0.3, -9), Vector3(6.5, 0.3, -5),
    ]
    player_start = Vector3(0, 0.3, 15)
    dummy_spots = [Vector3(4, 0.3, 8), Vector3(-6, 0.3, 9), Vector3(0, TOP + 0.3, 0)]
    base_positions = {1: Vector3(-21.0, 0.3, 0.0), 2: Vector3(21.0, 0.3, 0.0)}   # red west, blue east
    battery_spawns = [Vector3(0, TOP + 0.1, 0), Vector3(-12, TOP + 0.1, 11), Vector3(12, TOP + 0.1, 11)]
    capsule_spawns = [
        [Vector3(-18, TOP + 0.1, -13.5), "health"], [Vector3(18, TOP + 0.1, -13.5), "health"],
        [Vector3(0, TOP + 0.1, -13.5), "health"], [Vector3(0, 0.3, 5.5), "health"],
        [Vector3(-12, 0.3, -5), "ammo"], [Vector3(12, 0.3, 5), "ammo"], [Vector3(0, 0.3, -8), "ammo"],
    ]
    _shell()
    _cook_line()
    _island()
    _appliances_and_crates()
    _dining()
    _decor_and_lights()


# ---- room shell -----------------------------------------------------------------

func _shell() -> void:
    var floor_mat := _pbr(TEX + "Tiles074/Tiles074_1K-JPG_Color.jpg", TEX + "Tiles074/Tiles074_1K-JPG_NormalGL.jpg",
        Vector2(12, 9), Color(0.96, 0.95, 0.92))
    floor_mat.set_shader_parameter("spec_strength", 0.45)
    _box_mat(Vector3(0, -0.5, 0), Vector3(ROOM_X, 1, ROOM_Z), floor_mat)
    _box_mat(Vector3(0, WALL_H + 0.5, 0), Vector3(ROOM_X + 2, 1, ROOM_Z + 2), _mat(Color(0.93, 0.93, 0.9)))
    # kit wall tiles (12 m wide): windows on the east wall (the sun side) and one on the north
    var tile := 4.0 * K
    for i in 4:
        var x := -HX + tile * 0.5 + i * tile
        _place(KIT + ("wall_window_open.gltf" if i == 1 else "wall.gltf"), Vector3(x, 0, -HZ), 0.0, K)
        _place(KIT + ("wall_doorway.gltf" if i == 2 else "wall.gltf"), Vector3(x, 0, HZ), 180.0, K)
    for i in 3:
        var z := -HZ + tile * 0.5 + i * tile
        _place(KIT + "wall.gltf", Vector3(-HX, 0, z), 90.0, K)
        _place(KIT + ("wall_window_open.gltf" if i != 1 else "wall_orderwindow.gltf"), Vector3(HX, 0, z), -90.0, K)
    _place(KIT + "door_A.gltf", Vector3(-2.4, 0, HZ - 0.6), 180.0, K)
    # invisible backstop so nothing slips through tile seams
    var ghost := _mat(Color(0, 0, 0, 0))
    for wall in [[Vector3(0, WALL_H * 0.5, -HZ - 1.2), Vector3(ROOM_X + 4, WALL_H, 1)],
            [Vector3(0, WALL_H * 0.5, HZ + 1.2), Vector3(ROOM_X + 4, WALL_H, 1)],
            [Vector3(-HX - 1.2, WALL_H * 0.5, 0), Vector3(1, WALL_H, ROOM_Z + 4)],
            [Vector3(HX + 1.2, WALL_H * 0.5, 0), Vector3(1, WALL_H, ROOM_Z + 4)]]:
        var b := _box_mat(wall[0], wall[1], ghost)
        for c in b.get_children():
            if c is MeshInstance3D:
                c.visible = false


# ---- north wall: the cook line (3 m ledge, stoves, ovens, cabinets, hoods) ---------------

func _cook_line() -> void:
    var z := -HZ + 1.5 + 1.0 * K   # counters are 2 kit units deep: back face against the wall
    var pieces := ["kitchencounter_straight_A", "stove_multi", "kitchencounter_straight_A_decorated",
        "kitchencounter_sink", "kitchencounter_straight_B", "oven", "stove_multi", "kitchencounter_straight_A"]
    for i in pieces.size():
        var x := -HX + 1.0 * K + i * 2.0 * K
        _place(KIT + pieces[i] + ".gltf", Vector3(x, 0, z), 0.0, K)
        if pieces[i] == "stove_multi":
            _place(KIT + "extractorhood.gltf", Vector3(x, 0, -HZ + 0.75), 0.0, K, false)
            _place(KIT + ("pan_A.gltf" if i == 1 else "pot_A_stew.gltf"), Vector3(x, 1.2 * K, z - 0.6), 0.0, K, false)
        elif i in [0, 2, 4, 7]:
            _place(KIT + "kitchencabinet.gltf", Vector3(x, 0, -HZ + 0.75), 0.0, K, false)
    _place(KIT + "dishrack_plates.gltf", Vector3(-HX + 1.0 * K, TOP, z + 0.4), 20.0, K, false)
    _place(KIT + "cuttingboard.gltf", Vector3(-HX + 5.0 * K, TOP, z + 0.3), 0.0, K, false)
    _place(KIT + "food_burger.gltf", Vector3(-HX + 5.0 * K + 0.4, TOP + 0.45, z + 0.3), 0.0, K * 0.8, false)
    # ramps up to the ledge at both ends (bots need slopes)
    _ramp(Vector3(-HX + 3.0, 0, z + 6.5), Vector3(-HX + 3.0, TOP, z + 3.2))
    _ramp(Vector3(HX - 3.0, 0, z + 6.5), Vector3(HX - 3.0, TOP, z + 3.2))


# ---- centre: the counter island -----------------------------------------------------

func _island() -> void:
    var n := 5
    for i in n:
        var x := (i - (n - 1) * 0.5) * 2.0 * K
        var piece := "kitchencounter_straight_B" if i % 2 == 0 else "kitchencounter_straight_A"
        _place(KIT + piece + ".gltf", Vector3(x, 0, 0), 0.0, K)
    _place(KIT + "kitchencounter_outercorner.gltf", Vector3(-(n + 1) * K, 0, 0), 0.0, K)
    _place(KIT + "kitchencounter_outercorner.gltf", Vector3((n + 1) * K, 0, 0), 180.0, K)
    _place(KIT + "pot_large.gltf", Vector3(-9, TOP, 0.3), 15.0, K * 0.9, false)
    _place(KIT + "plate.gltf", Vector3(8, TOP, -0.4), 0.0, K, false)
    _place(KIT + "food_stew.gltf", Vector3(8, TOP + 0.3, -0.4), 0.0, K, false)
    _place(KIT + "knife.gltf", Vector3(11, TOP + 0.6, 0.6), -60.0, K * 0.9, false)
    # stool + crate stairs on both sides, ramps at the ends
    _place(KIT + "chair_stool.gltf", Vector3(-4, 0, 5.2), 0.0, K)          # 1.5 m
    _place(KIT + "crate_tomatoes.gltf", Vector3(4, 0, 5.4), 0.0, K)        # 2.8 m
    _place(KIT + "chair_stool.gltf", Vector3(4, 0, -5.2), 0.0, K)
    _place(KIT + "crate_buns.gltf", Vector3(-4, 0, -5.4), 0.0, K)
    _ramp(Vector3(-24.5 + 3.0, 0, -6.0), Vector3(-24.5 + 7.5, TOP, -3.0))
    _ramp(Vector3(24.5 - 3.0, 0, 6.0), Vector3(24.5 - 7.5, TOP, 3.0))


# ---- fridges, ovens and crate stacks as cover ------------------------------------------

func _appliances_and_crates() -> void:
    _place(KIT + "fridge_A.gltf", Vector3(-17, 0.8 * K, -9), 90.0, K)      # 7.5 m tall blocks
    _place(KIT + "fridge_B.gltf", Vector3(17, 1.25 * K, 9), -90.0, K)
    _place(KIT + "pillar_A.gltf", Vector3(-12, 0, 9), 0.0, K)
    _place(KIT + "pillar_A.gltf", Vector3(12, 0, -9), 0.0, K)
    _crate_stack(Vector3(-8, 0, 9), 2, 20.0)
    _crate_stack(Vector3(8, 0, -9), 2, -15.0)
    _crate_stack(Vector3(-15, 0, 3), 1, 0.0)
    _crate_stack(Vector3(15, 0, -3), 1, 0.0)
    _crate_stack(Vector3(-20, 0, 14), 3, 10.0)
    _crate_stack(Vector3(20, 0, -14), 3, -10.0)


func _crate_stack(at: Vector3, count: int, yaw: float) -> void:
    var kinds := ["crate", "crate_cheese", "crate_potatoes", "crate_onions", "crate_lettuce"]
    for i in count:
        var kind: String = kinds[(i + int(absf(at.x))) % kinds.size()] if i < count - 1 else "crate_lid"
        if i == count - 1 and count > 1:
            _place(KIT + kinds[(i + 1) % kinds.size()] + ".gltf", at + Vector3(0, i * 0.8 * K, 0), yaw + i * 7.0, K)
            _place(KIT + "crate_lid.gltf", at + Vector3(0, (i + 1) * 0.8 * K, 0), yaw + i * 7.0, K, false)
        else:
            _place(KIT + kind + ".gltf", at + Vector3(0, i * 0.8 * K, 0), yaw + i * 7.0, K)


# ---- south side: dining tables + chairs -------------------------------------------------

func _dining() -> void:
    for x in [-12.0, 12.0]:
        _place(KIT + "kitchentable_A_large.gltf", Vector3(x, 0, 11), 0.0, K)   # 9 x 6, top 3 m
        _place(KIT + "chair_A.gltf", Vector3(x - 2.5, 0, 15.2), 180.0, K)
        _place(KIT + "chair_B.gltf", Vector3(x + 2.5, 0, 15.2), 180.0, K)
        _place(KIT + "chair_A.gltf", Vector3(x + 2.5, 0, 6.8), 0.0, K)
        _place(KIT + "ketchup.gltf", Vector3(x - 1.0, TOP, 11.5), 0.0, K, false)
        _place(KIT + "mustard.gltf", Vector3(x - 0.2, TOP, 11.5), 0.0, K, false)
        _place(KIT + "menu.gltf", Vector3(x + 1.5, TOP, 10.5), -30.0, K, false)
    _place(KIT + "table_round_A.gltf", Vector3(0, 0, 12), 0.0, K)                  # 9 m round, top 3 m
    _place(KIT + "chair_stool.gltf", Vector3(-6.2, 0, 12), 0.0, K)
    _place(KIT + "chair_stool.gltf", Vector3(6.2, 0, 12), 0.0, K)
    _place(KIT + "food_burger.gltf", Vector3(-1.2, TOP, 11.5), 0.0, K, false)
    _place(KIT + "food_stew.gltf", Vector3(1.4, TOP, 12.6), 0.0, K, false)
    _place(KIT + "table_round_A_small.gltf", Vector3(-19, 0, -14), 0.0, K)
    _place(KIT + "table_round_A_small.gltf", Vector3(19, 0, 14), 0.0, K)


# ---- shelves, jars, lights --------------------------------------------------------------

func _decor_and_lights() -> void:
    var z := -HZ + 0.75
    for x in [-20.0, -14.0, 14.0, 20.0]:
        _place(KIT + "shelf_papertowel.gltf", Vector3(x, 2.6 * K, z), 0.0, K, false)
        _place(KIT + "jar_A_large.gltf", Vector3(x - 1.4, 2.6 * K + 0.45, z + 0.9), 0.0, K, false)
        _place(KIT + "jar_B_medium.gltf", Vector3(x + 1.0, 2.6 * K + 0.45, z + 0.9), 0.0, K, false)
    for x in [-14.0, 0.0, 14.0]:
        var lamp := MeshInstance3D.new()
        var disc := CylinderMesh.new()
        disc.top_radius = 1.4
        disc.bottom_radius = 1.6
        disc.height = 0.4
        lamp.mesh = disc
        lamp.position = Vector3(x, WALL_H - 0.25, 0)
        var lamp_mat := StandardMaterial3D.new()
        lamp_mat.albedo_color = Color(1.0, 0.98, 0.92)
        lamp_mat.emission_enabled = true
        lamp_mat.emission = Color(1.0, 0.96, 0.88)
        lamp_mat.emission_energy_multiplier = 2.5
        lamp.material_override = lamp_mat
        add_child(lamp)
        _light(Vector3(x, WALL_H - 1.5, 0), Color(1.0, 0.96, 0.88), 4.5, 30.0)
    _light(Vector3(-17, 6.0, -13), Color(1.0, 0.8, 0.55), 2.0, 14.0)   # warm glow by the stoves
    _light(Vector3(9, 6.0, -13), Color(1.0, 0.8, 0.55), 2.0, 14.0)


func _light(pos: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
    var l := OmniLight3D.new()
    l.position = pos
    l.light_color = color
    l.light_energy = energy
    l.omni_range = range_m
    l.omni_attenuation = 1.2
    l.shadow_enabled = false
    add_child(l)
    return l


## A steel baking-tray ramp between two points (slopes are what the navmesh can climb).
func _ramp(from: Vector3, to: Vector3) -> void:
    var steel := _mat(Color(0.72, 0.75, 0.78))
    steel.set_shader_parameter("spec_strength", 0.6)
    var mid := (from + to) * 0.5
    var d := to - from
    var length := d.length() + 0.8
    var horiz := Vector2(d.x, d.z).length()
    var pitch := atan2(d.y, horiz)
    var yaw := atan2(-d.x, -d.z)
    var body := _box_mat(mid + Vector3(0, -0.12, 0), Vector3(2.6, 0.25, length), steel)
    body.rotation = Vector3(pitch, yaw, 0.0)
    var lip := _mat(Color(0.5, 0.53, 0.56))
    for side in [-1.0, 1.0]:
        var rail := _box_mat(Vector3.ZERO, Vector3(0.12, 0.3, length), lip)
        rail.reparent(body)
        rail.position = Vector3(side * 1.25, 0.1, 0)
        rail.rotation = Vector3.ZERO
