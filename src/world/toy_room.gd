extends ArenaBase
## "Play Room": a child's bedroom at toy scale (everything x4). Wood floor, wallpaper, a rug
## arena in the middle with a coffee table, a bed with a ruler ramp, a dining table with chairs,
## a couch, a dresser, standing lamps, ABC blocks, soda cans and toy boxes as cover, and a big
## sun window that throws a cross-shaped shadow across the floor.

const FURN := "res://assets/env/furniture/"
const PROTO := "res://assets/env/prototype/"
const TEX := "res://assets/textures/"
const K := 4.0                 ## kit scale
const ROOM := 48.0
const WALL_H := 12.0
const HALF := ROOM * 0.5

const BLOCK_COLORS: Array[Color] = [
    Color(0.93, 0.3, 0.28), Color(0.25, 0.55, 0.95), Color(0.98, 0.78, 0.2),
    Color(0.35, 0.75, 0.4), Color(0.6, 0.4, 0.85), Color(0.98, 0.55, 0.25),
]
const LETTERS := "ABCDEFGHJKLMNPRSTUVWXYZ"

var _block_i := 0


func _build() -> void:
    spawns = [
        Vector3(0, 0.3, 19), Vector3(0, 0.3, -17), Vector3(21, 0.3, 2), Vector3(-21, 0.3, 4),
        Vector3(18, 0.3, 17), Vector3(-9.5, 0.3, -19.5), Vector3(19, 0.3, -18), Vector3(-17.5, 0.3, 19.5),
    ]
    player_start = Vector3(0, 0.3, 19)
    dummy_spots = [Vector3(5, 0.3, 8), Vector3(0, 2.3, 3), Vector3(-9, 0.3, -6)]
    base_positions = {1: Vector3(0, 0.3, 21.0), 2: Vector3(0, 0.3, -21.0)}       # red south, blue north
    battery_spawns = [Vector3(0, 2.1, 3), Vector3(-17, 0.3, 6), Vector3(17, 0.3, 4)]  # coffee-table top + wings
    capsule_spawns = [
        [Vector3(-3, 0.3, 12.5), "health"], [Vector3(9, 0.3, -18), "health"],
        [Vector3(-14, 4.3, -13), "health"], [Vector3(20.5, 4.3, 9), "health"],
        [Vector3(13, 4.3, -9), "ammo"], [Vector3(-13, 2.3, 17), "ammo"], [Vector3(2, 0.3, -4), "ammo"],
    ]
    _shell()
    _rug_and_coffee_table()
    _bed_corner()
    _dining_table()
    _couch_and_dresser()
    _lamps_and_decor()
    _cover()


# ---- room shell -----------------------------------------------------------------

func _shell() -> void:
    var floor_mat := _pbr(TEX + "WoodFloor051/WoodFloor051_1K-JPG_Color.jpg",
        TEX + "WoodFloor051/WoodFloor051_1K-JPG_NormalGL.jpg", Vector2(8, 8), Color(0.95, 0.9, 0.85))
    _box_mat(Vector3(0, -0.5, 0), Vector3(ROOM, 1, ROOM), floor_mat)

    var wall_mat := _pbr(TEX + "Wallpaper001A/Wallpaper001A_1K-JPG_Color.jpg",
        TEX + "Wallpaper001A/Wallpaper001A_1K-JPG_NormalGL.jpg", Vector2(6, 1.5), Color(0.92, 0.94, 1.0))
    wall_mat.set_shader_parameter("normal_depth", 0.35)
    var t := 1.0
    # north, south, west: solid
    _box_mat(Vector3(0, WALL_H * 0.5, -HALF - t * 0.5), Vector3(ROOM + 2 * t, WALL_H, t), wall_mat)
    _box_mat(Vector3(0, WALL_H * 0.5, HALF + t * 0.5), Vector3(ROOM + 2 * t, WALL_H, t), wall_mat)
    _box_mat(Vector3(-HALF - t * 0.5, WALL_H * 0.5, 0), Vector3(t, WALL_H, ROOM + 2 * t), wall_mat)
    # east: window opening z -6..6, y 4..11, with a cross frame (the sun comes from +X)
    var x := HALF + t * 0.5
    _box_mat(Vector3(x, WALL_H * 0.5, -HALF * 0.5 - 3.0), Vector3(t, WALL_H, HALF - 6.0), wall_mat)   # z -24..-6
    _box_mat(Vector3(x, WALL_H * 0.5, HALF * 0.5 + 3.0), Vector3(t, WALL_H, HALF - 6.0), wall_mat)    # z 6..24
    _box_mat(Vector3(x, 2.0, 0), Vector3(t, 4.0, 12.0), wall_mat)                                   # sill
    _box_mat(Vector3(x, 11.5, 0), Vector3(t, 1.0, 12.0), wall_mat)                                  # lintel
    var frame := _mat(Color(0.96, 0.96, 0.94))
    _box_mat(Vector3(x, 7.5, 0), Vector3(t + 0.2, 7.0, 0.5), frame)          # vertical bar
    _box_mat(Vector3(x, 7.5, 0), Vector3(t + 0.2, 0.5, 12.0), frame)         # horizontal bar
    _box_mat(Vector3(x, 4.0, 0), Vector3(t + 0.6, 0.4, 12.6), frame)         # sill trim
    # baseboards
    var base := _mat(Color(0.97, 0.97, 0.95))
    _box_mat(Vector3(0, 0.3, -HALF + 0.1), Vector3(ROOM, 0.6, 0.2), base)
    _box_mat(Vector3(0, 0.3, HALF - 0.1), Vector3(ROOM, 0.6, 0.2), base)
    _box_mat(Vector3(-HALF + 0.1, 0.3, 0), Vector3(0.2, 0.6, ROOM), base)
    _box_mat(Vector3(HALF - 0.1, 0.3, 0), Vector3(0.2, 0.6, ROOM), base)
    # ceiling + lamp
    _box_mat(Vector3(0, WALL_H + 0.5, 0), Vector3(ROOM + 2, 1, ROOM + 2), _mat(Color(0.95, 0.95, 0.93)))
    var lamp := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 2.2
    disc.bottom_radius = 2.4
    disc.height = 0.5
    lamp.mesh = disc
    lamp.position = Vector3(0, WALL_H - 0.3, 0)
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.97, 0.9)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.95, 0.85)
    lamp_mat.emission_energy_multiplier = 2.5
    lamp.material_override = lamp_mat
    add_child(lamp)
    _light(Vector3(0, WALL_H - 1.2, 0), Color(1.0, 0.95, 0.85), 5.5, 48.0)


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


# ---- middle: rug + coffee table -------------------------------------------------

func _rug_and_coffee_table() -> void:
    var rug := _pbr(TEX + "Carpet016/Carpet016_1K-JPG_Color.jpg",
        TEX + "Carpet016/Carpet016_1K-JPG_NormalGL.jpg", Vector2(4, 3), Color(0.95, 0.6, 0.55))
    _box_mat(Vector3(0, 0.03, 3), Vector3(24, 0.06, 18), rug)
    _place(FURN + "table_low.gltf", Vector3(0, 0.05, 3), 0.0, K)          # top at ~2 m
    _place(FURN + "pillow_A.gltf", Vector3(-7.5, 0.4, 3), 20.0, K)
    _place(FURN + "pillow_B.gltf", Vector3(7.5, 0.4, 3), -15.0, K)
    _place(FURN + "cactus_medium_A.gltf", Vector3(3, 2.05, 4.5), 0.0, K * 0.6)


# ---- north-west: bed with a ruler ramp ----------------------------------------------

func _bed_corner() -> void:
    _place(FURN + "bed_single_A.gltf", Vector3(-17.5, 0, -15), 0.0, K)      # 6.4 x 4 x 12, top ~4 m
    _place(FURN + "pillow_A.gltf", Vector3(-17.5, 4.3, -19), 0.0, K)
    _place(FURN + "cabinet_small.gltf", Vector3(-11.5, 0, -21.5), 0.0, K)   # nightstand, top 4 m
    _place(FURN + "lamp_table.gltf", Vector3(-11.5, 4.0, -21.5), 0.0, K)
    _light(Vector3(-11.5, 7.5, -21.5), Color(1.0, 0.85, 0.6), 1.6, 14.0)
    # wooden ruler leaning on the bed: floor at x=-6 -> bed top at x=-14.2, rise 4
    _ruler(Vector3(-5.5, 0, -13), Vector3(-14.0, 4.0, -13))
    _place(FURN + "book_set.gltf", Vector3(-8, 0.75, -20), 90.0, K)         # lying books = 1.5 m step
    _place(FURN + "book_single.gltf", Vector3(-4.5, 0.75, -20.5), 100.0, K)


## A giant wooden ruler used as a ramp (toy-scale ladder to furniture tops).
func _ruler(from: Vector3, to: Vector3) -> void:
    var wood := _pbr(TEX + "Wood066/Wood066_1K-JPG_Color.jpg", TEX + "Wood066/Wood066_1K-JPG_NormalGL.jpg",
        Vector2(1, 6), Color(1.0, 0.9, 0.7))
    var mid := (from + to) * 0.5
    var d := to - from
    var length := d.length() + 0.6
    var horiz := Vector2(d.x, d.z).length()
    var pitch := atan2(d.y, horiz)
    var yaw := atan2(-d.x, -d.z)
    var body := _box_mat(mid + Vector3(0, -0.12, 0), Vector3(2.2, 0.25, length), wood)
    body.rotation = Vector3(pitch, yaw, 0.0)
    # tick marks along the edge
    var ink := _mat(Color(0.2, 0.2, 0.22))
    for i in int(length / 1.2):
        var tick := _box_mat(Vector3.ZERO, Vector3(0.35 if i % 2 == 0 else 0.2, 0.06, 0.08), ink)
        tick.reparent(body)
        tick.position = Vector3(-0.9, 0.14, -length * 0.5 + 0.6 + i * 1.2)
        tick.rotation = Vector3.ZERO


# ---- east: dining table + chairs ----------------------------------------------------

func _dining_table() -> void:
    _place(FURN + "table_medium_long.gltf", Vector3(13, 0, -9), 0.0, K)   # 12 x 4 x 8, top 4 m
    _place(FURN + "chair_A.gltf", Vector3(13, 0, -2.2), 180.0, K)          # seat ~2.2 m
    _place(FURN + "chair_B.gltf", Vector3(6.2, 0, -9), 90.0, K)
    _place(FURN + "book_single.gltf", Vector3(13, 2.95, -2.2), 0.0, K)      # step from seat to table
    _place(FURN + "cactus_small_A.gltf", Vector3(16, 4.0, -11), 0.0, K * 0.7)
    _place(FURN + "pictureframe_standing_A.gltf", Vector3(10, 4.0, -11.5), 20.0, K * 0.8)
    _block(Vector3(13, 0, 3), 1.0)
    _block(Vector3(14.6, 0, 3.6), 2.0)


# ---- south / west: couch, dresser ---------------------------------------------------

func _couch_and_dresser() -> void:
    _place(FURN + "couch_pillows.gltf", Vector3(-13, 0, 17), 180.0, K)     # 12 x 4.9 x 6.4, seat 2 m
    _block(Vector3(-5.5, 0, 17.5), 1.0)
    _place(FURN + "cabinet_medium.gltf", Vector3(20.5, 0, 9), -90.0, K)     # dresser, top 4 m
    _place(FURN + "chair_stool.gltf", Vector3(20.5, 0, 15), 0.0, K)         # 2 m
    _place(FURN + "book_set.gltf", Vector3(20.5, 2.0, 15), 0.0, K)          # +1.5 -> 3.5
    _place(FURN + "shelf_B_large_decorated.gltf", Vector3(-24.0, 6.0, -2), 90.0, K, false)
    _place(FURN + "pictureframe_large_A.gltf", Vector3(-23.9, 7.5, 12), 90.0, K, false)
    _place(FURN + "pictureframe_medium.gltf", Vector3(8, 7.0, -23.9), 0.0, K, false)


# ---- lamps + decor ------------------------------------------------------------------

func _lamps_and_decor() -> void:
    _place(FURN + "lamp_standing.gltf", Vector3(19, 0, 20), 0.0, K)          # 4 wide, 10 tall
    _light(Vector3(19, 8.5, 20), Color(1.0, 0.88, 0.65), 3.2, 22.0)
    _place(FURN + "lamp_standing.gltf", Vector3(-20, 0, -2), 0.0, K)
    _light(Vector3(-20, 8.5, -2), Color(1.0, 0.88, 0.65), 3.2, 22.0)
    _place(FURN + "rug_oval_A.gltf", Vector3(-16, 0.02, 6), 30.0, K, false)


# ---- scattered cover ----------------------------------------------------------------

func _cover() -> void:
    for spec in [
        [PROTO + "Box_A.gltf", Vector3(6, 0, 12), 20.0, 3.5], [PROTO + "Box_C.gltf", Vector3(-8, 0, 10), -30.0, 3.5],
        [PROTO + "Box_B.gltf", Vector3(9, 0, -18), 45.0, 3.5], [PROTO + "Box_A.gltf", Vector3(-3, 0, -8), 10.0, 3.0],
        [PROTO + "Can_A.gltf", Vector3(16, 0, 10), 0.0, 3.6], [PROTO + "Can_B.gltf", Vector3(-12, 0, 12), 0.0, 3.6],
        [PROTO + "Can_A.gltf", Vector3(2, 0, -20), 0.0, 3.6], [PROTO + "Barrel_B.gltf", Vector3(20, 0, -12), 0.0, 2.2],
    ]:
        _place(spec[0], spec[1], spec[2], spec[3])
    _block(Vector3(-2, 0, 12.5), 1.0)
    _block(Vector3(-16, 0, -9), 2.0)
    _block(Vector3(-13.5, 0, -9), 1.0)
    _block(Vector3(7, 0, 8), 2.0)
    _block(Vector3(19.5, 0, -4), 1.0)
    _block(Vector3(-20, 0, 12), 1.0)
    _block(Vector3(-20, 1.0, 12), 1.0)


## ABC toy block: coloured cube with a letter on two faces.
func _block(floor_pos: Vector3, size: float) -> void:
    var color := BLOCK_COLORS[_block_i % BLOCK_COLORS.size()]
    var letter := LETTERS[_block_i % LETTERS.length()]
    _block_i += 1
    var body := _box(floor_pos + Vector3(0, size * 0.5, 0), Vector3(size, size, size), color)
    for face in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
        var l := Label3D.new()
        l.text = letter
        l.font_size = 220
        l.pixel_size = size * 0.0032
        l.modulate = Color(1, 1, 1, 0.92)
        l.outline_size = 0
        l.position = face * (size * 0.5 + 0.01)
        l.rotation.y = 0.0 if face.z > 0 else PI * 0.5
        body.add_child(l)
