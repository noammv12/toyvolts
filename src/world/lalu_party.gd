extends ArenaBase
## "Lalu's Birthday": Hila's party room at toy scale (everything x4). A giant three-tier cake
## with twelve candles in the middle, thirty tethered balloons, a pinata on a rope, five
## gifts with surprises, confetti cannons in the corners, a disco dance floor with a mirror
## ball, a bouncy castle (super jump), a moon corner (low gravity), a dining table with a
## slide down to the floor, a HAPPY BIRTHDAY HILA banner and a sign from Noam & Daniel.

const FURN := "res://assets/env/furniture/"
const PROTO := "res://assets/env/prototype/"
const TEX := "res://assets/textures/"
const DISCO: Shader = preload("res://shaders/disco.gdshader")
const K := 4.0
const ROOM := 52.0
const WALL_H := 12.0
const HALF := ROOM * 0.5
const CAKE_TOP := 5.4
const TABLE_TOP := 4.0
const TABLE_POS := Vector3(-19, 0, 2)
const DANCE_POS := Vector3(14, 0, 14)
const CASTLE_POS := Vector3(17, 0, -17)
const MOON_POS := Vector3(-17, 0, -17)

var party: PartyManager
var _letter_i := 0


func _build() -> void:
    spawns = [
        Vector3(0, 0.3, 20), Vector3(0, 0.3, -21), Vector3(22, 0.3, 3), Vector3(-22, 0.3, 12),
        Vector3(10, 0.3, 21), Vector3(-4, 0.3, -21), Vector3(22, 0.3, -6), Vector3(-22, 0.3, 20),
    ]
    player_start = Vector3(0, 0.3, 20)
    dummy_spots = [Vector3(5, 0.3, 10), Vector3(-5, 0.3, 10), Vector3(0, TABLE_TOP + 0.3, 2)]
    base_positions = {1: Vector3(0, 0.3, 23.0), 2: Vector3(0, 0.3, -23.0)}
    battery_spawns = [Vector3(0, CAKE_TOP + 0.1, 0), Vector3(-19, TABLE_TOP + 0.1, 2), Vector3(14, 0.3, 14)]
    capsule_spawns = [
        [Vector3(6, 0.3, 16), "health"], [Vector3(-6, 0.3, -16), "health"], [Vector3(20, 0.3, 8), "health"],
        [Vector3(-16, TABLE_TOP + 0.1, -2), "ammo"], [Vector3(6, 0.3, -10), "ammo"], [Vector3(-8, 0.3, 6), "ammo"],
    ]
    party = PartyManager.new()
    party.name = "Party"
    add_child(party)
    party.cake_top = Vector3(0, CAKE_TOP + 0.4, 0)
    party.corners = [Vector3(21, 1, 21), Vector3(-21, 1, 21), Vector3(21, 1, -21), Vector3(-21, 1, -21)]
    _shell()
    _cake()
    _candles()
    _table_and_slide()
    _dance_floor()
    _bouncy_castle()
    _moon_corner()
    _gifts()
    _pinata()
    _cannons()
    _balloons()
    _banner_and_signs()
    _streamers_and_lights()
    _hila_eggs()
    if Game.has_arg("kpop"):   # capture: the show is on from the start
        party.kpop_start.call_deferred()
    if Game.has_arg("party_smoke") and Net.is_authority():
        party.smoke()
    if Game.has_arg("party_finish") and Net.is_authority():
        party.finish_all()


# ---- room shell -----------------------------------------------------------------

func _shell() -> void:
    var floor_mat := _pbr(TEX + "WoodFloor051/WoodFloor051_1K-JPG_Color.jpg",
        TEX + "WoodFloor051/WoodFloor051_1K-JPG_NormalGL.jpg", Vector2(8, 8), Color(1.0, 0.9, 0.9))
    _box_mat(Vector3(0, -0.5, 0), Vector3(ROOM, 1, ROOM), floor_mat)
    var wall_mat := _pbr(TEX + "Wallpaper001A/Wallpaper001A_1K-JPG_Color.jpg",
        TEX + "Wallpaper001A/Wallpaper001A_1K-JPG_NormalGL.jpg", Vector2(6, 1.5), Color(1.0, 0.86, 0.93))
    wall_mat.set_shader_parameter("normal_depth", 0.3)
    var t := 1.0
    _box_mat(Vector3(0, WALL_H * 0.5, -HALF - t * 0.5), Vector3(ROOM + 2 * t, WALL_H, t), wall_mat)
    _box_mat(Vector3(0, WALL_H * 0.5, HALF + t * 0.5), Vector3(ROOM + 2 * t, WALL_H, t), wall_mat)
    _box_mat(Vector3(-HALF - t * 0.5, WALL_H * 0.5, 0), Vector3(t, WALL_H, ROOM + 2 * t), wall_mat)
    # east wall with a big window (the sun comes from +X)
    var x := HALF + t * 0.5
    _box_mat(Vector3(x, WALL_H * 0.5, -HALF * 0.5 - 3.0), Vector3(t, WALL_H, HALF - 6.0), wall_mat)
    _box_mat(Vector3(x, WALL_H * 0.5, HALF * 0.5 + 3.0), Vector3(t, WALL_H, HALF - 6.0), wall_mat)
    _box_mat(Vector3(x, 2.0, 0), Vector3(t, 4.0, 12.0), wall_mat)
    _box_mat(Vector3(x, 11.5, 0), Vector3(t, 1.0, 12.0), wall_mat)
    var frame := _mat(Color(0.98, 0.98, 0.96))
    _box_mat(Vector3(x, 7.5, 0), Vector3(t + 0.2, 7.0, 0.5), frame)
    _box_mat(Vector3(x, 7.5, 0), Vector3(t + 0.2, 0.5, 12.0), frame)
    _box_mat(Vector3(x, 4.0, 0), Vector3(t + 0.6, 0.4, 12.6), frame)
    # teal wainscot band + gold trim: the party colours on every wall
    var band := _mat(PartyText.TEAL)
    var trim := _mat(PartyText.GOLD)
    for spec in [[Vector3(0, 0.9, -HALF + 0.12), Vector3(ROOM, 1.8, 0.24)], [Vector3(0, 0.9, HALF - 0.12), Vector3(ROOM, 1.8, 0.24)],
            [Vector3(-HALF + 0.12, 0.9, 0), Vector3(0.24, 1.8, ROOM)], [Vector3(HALF - 0.12, 0.9, 0), Vector3(0.24, 1.8, ROOM)]]:
        _box_mat(spec[0], spec[1], band)
        _box_mat(spec[0] + Vector3(0, 1.05, 0), Vector3(spec[1].x + 0.1 if spec[1].x > 1 else 0.34, 0.3, spec[1].z + 0.1 if spec[1].z > 1 else 0.34), trim)
    # ceiling + lamp
    _box_mat(Vector3(0, WALL_H + 0.5, 0), Vector3(ROOM + 2, 1, ROOM + 2), _mat(Color(0.97, 0.95, 0.96)))
    var lamp := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 2.4
    disc.bottom_radius = 2.6
    disc.height = 0.5
    lamp.mesh = disc
    lamp.position = Vector3(0, WALL_H - 0.3, 0)
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.97, 0.92)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.95, 0.88)
    lamp_mat.emission_energy_multiplier = 2.5
    lamp.material_override = lamp_mat
    add_child(lamp)
    _light(Vector3(0, WALL_H - 1.2, 0), Color(1.0, 0.95, 0.88), 5.0, 52.0)


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


# ---- the cake ---------------------------------------------------------------------

func _cake() -> void:
    var plate := _cyl_body(Vector3(0, 0.15, 0), 7.2, 0.3, Color(0.86, 0.88, 0.93), 0.7)
    plate.add_to_group(NAV_GROUP)
    var tiers := [[5.6, 0.3, 1.8, Color(0.98, 0.6, 0.76)], [4.2, 2.1, 1.7, Color(0.99, 0.72, 0.82)], [2.8, 3.8, 1.6, Color(0.98, 0.6, 0.76)]]
    for i in tiers.size():
        var tr: Array = tiers[i]
        var r: float = tr[0]
        var y0: float = tr[1]
        var h: float = tr[2]
        _cyl_body(Vector3(0, y0 + h * 0.5, 0), r, h, tr[3], 0.25)
        # icing lip + drips
        _cyl_mesh(Vector3(0, y0 + h - 0.18, 0), r + 0.18, 0.36, PartyText.CREAM, 0.35)
        for d in 10:
            var a := d * TAU / 10.0 + i * 0.3
            var drip := MeshInstance3D.new()
            var cm := CapsuleMesh.new()
            cm.radius = 0.16
            cm.height = 0.7 + (d % 3) * 0.25
            cm.radial_segments = 8
            cm.rings = 3
            drip.mesh = cm
            drip.position = Vector3(sin(a) * (r + 0.1), y0 + h - 0.5 - (d % 3) * 0.12, cos(a) * (r + 0.1))
            drip.material_override = _mat(PartyText.CREAM)
            drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(drip)
        # sprinkles: little coloured dots on the icing lip
        for d in 14:
            var a := d * TAU / 14.0 + i * 0.7
            var dot := MeshInstance3D.new()
            var sm := SphereMesh.new()
            sm.radius = 0.16
            sm.height = 0.32
            sm.radial_segments = 8
            sm.rings = 4
            dot.mesh = sm
            dot.position = Vector3(sin(a) * (r - 0.1), y0 + h + 0.05, cos(a) * (r - 0.1))
            dot.material_override = _mat(PartyText.color(d + i))
            dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(dot)
        # a stripe band around each tier
        _cyl_mesh(Vector3(0, y0 + h * 0.45, 0), r + 0.04, 0.3, [PartyText.TEAL, PartyText.GOLD, PartyText.LILAC][i], 0.4)
    # topper: a gold star on a stick
    _cyl_mesh(Vector3(0, CAKE_TOP + 0.45, 0), 0.06, 0.9, PartyText.GOLD, 0.5)
    var star := MeshInstance3D.new()
    var pm := PrismMesh.new()
    pm.size = Vector3(0.9, 0.9, 0.2)
    star.mesh = pm
    star.position = Vector3(0, CAKE_TOP + 1.1, 0)
    star.material_override = _mat(PartyText.GOLD)
    add_child(star)
    var star2 := MeshInstance3D.new()
    star2.mesh = pm
    star2.position = Vector3(0, CAKE_TOP + 1.1, 0)
    star2.rotation = Vector3(PI, 0, 0)
    star2.material_override = _mat(PartyText.GOLD)
    add_child(star2)


func _candles() -> void:
    for i in 12:
        var a := i * TAU / 12.0
        var c := PartyCandle.new()
        c.color = PartyText.color(i)
        c.position = Vector3(sin(a) * 2.15, CAKE_TOP, cos(a) * 2.15)
        add_child(c)
        party.add_candle(c)


func _cyl_body(pos: Vector3, r: float, h: float, color: Color, spec: float) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    body.collision_layer = Character.LAYER_WORLD
    body.add_to_group(NAV_GROUP)
    var shape := CollisionShape3D.new()
    var cs := CylinderShape3D.new()
    cs.radius = r
    cs.height = h
    shape.shape = cs
    body.add_child(shape)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = h
    cm.radial_segments = 32
    cm.rings = 1
    mi.mesh = cm
    var m := _mat(color)
    if spec != 0.25:
        m = ShaderMaterial.new()
        m.shader = TOON
        m.set_shader_parameter("albedo", color)
        m.set_shader_parameter("spec_strength", spec)
    mi.material_override = m
    body.add_child(mi)
    add_child(body)
    box_count += 1
    return body


func _cyl_mesh(pos: Vector3, r: float, h: float, color: Color, spec: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = h
    cm.radial_segments = 28
    cm.rings = 1
    mi.mesh = cm
    mi.position = pos
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("spec_strength", spec)
    mi.material_override = m
    add_child(mi)
    return mi


# ---- west: dining table, present stairs, the slide ------------------------------------

func _table_and_slide() -> void:
    _place(FURN + "table_medium_long.gltf", TABLE_POS, 90.0, K)      # 8 wide (x), 12 long (z), top 4 m
    _place(FURN + "chair_A.gltf", TABLE_POS + Vector3(0, 0, -8.8), 0.0, K)
    _place(FURN + "chair_B.gltf", TABLE_POS + Vector3(-6.6, 0, 0), 90.0, K)
    _place(FURN + "chair_A.gltf", TABLE_POS + Vector3(-6.6, 0, 5), 90.0, K)
    # on the table: plates, a jar, a bowl of candy (restaurant kit)
    _place("res://assets/env/restaurant/plate.gltf", TABLE_POS + Vector3(-2, TABLE_TOP, -3), 0.0, K * 0.7)
    _place("res://assets/env/restaurant/plate.gltf", TABLE_POS + Vector3(2, TABLE_TOP, 4.5), 20.0, K * 0.7)
    _place("res://assets/env/restaurant/bowl.gltf", TABLE_POS + Vector3(-1.5, TABLE_TOP, 3), 0.0, K * 0.7)
    _place("res://assets/env/restaurant/jar_B_medium.gltf", TABLE_POS + Vector3(2.5, TABLE_TOP, -1), 0.0, K * 0.7)
    _place("res://assets/env/restaurant/food_burger.gltf", TABLE_POS + Vector3(-2, TABLE_TOP + 0.05, -3), 0.0, K * 0.7)
    # present stairs up to the table top (1 m rises: guests climb them too)
    var z0 := TABLE_POS.z + 6.0
    for i in 3:
        var h := 3.0 - i
        var b := _box(Vector3(TABLE_POS.x, h * 0.5, z0 + 0.8 + i * 1.6), Vector3(3.2, h, 1.6), PartyText.color(i + 2))
        var rib := _mat(PartyText.CREAM)
        _box_mat(Vector3(TABLE_POS.x, h * 0.5, z0 + 0.8 + i * 1.6), Vector3(0.4, h + 0.04, 1.64), rib)
        b.name = "Stair%d" % i
    # the slide: table edge (x = -13, y = 4) down to the floor (x = -3, y = 0)
    var from := Vector3(TABLE_POS.x + 4.0, TABLE_TOP, TABLE_POS.z)
    var to := Vector3(TABLE_POS.x + 10.5, 0.1, TABLE_POS.z)
    var mid := (from + to) * 0.5
    var d := to - from
    var length := d.length() + 1.0
    var pitch := atan2(d.y, Vector2(d.x, d.z).length())
    var yaw := atan2(-d.x, -d.z)
    var slide_mat := ShaderMaterial.new()
    slide_mat.shader = TOON
    slide_mat.set_shader_parameter("albedo", PartyText.GOLD)
    slide_mat.set_shader_parameter("spec_strength", 0.6)
    var bed := _box_mat(mid + Vector3(0, -0.15, 0), Vector3(2.6, 0.3, length), slide_mat)
    bed.rotation = Vector3(pitch, yaw, 0.0)
    for side in [-1.0, 1.0]:
        var rail := _box_mat(Vector3.ZERO, Vector3(0.25, 0.7, length), _mat(PartyText.TEAL))
        rail.reparent(bed)
        rail.position = Vector3(side * 1.3, 0.35, 0)
        rail.rotation = Vector3.ZERO
    # slide zone: pushes downhill, slippery
    var zone := PartyZone.new()
    zone.kind = PartyZone.Kind.SLIDE
    zone.push = Vector3(d.x, 0.0, d.z).normalized() * 26.0
    zone.position = mid + Vector3(0, 0.9, 0)
    zone.rotation = Vector3(pitch, yaw, 0.0)
    zone.set_box(Vector3(2.4, 2.0, length - 1.5))
    add_child(zone)
    # a landing rug at the bottom
    _place(FURN + "rug_oval_A.gltf", to + Vector3(1.2, 0.02, 0), 90.0, K * 0.6, false)


# ---- south-east: the disco dance floor ------------------------------------------------

func _dance_floor() -> void:
    var floor_body := StaticBody3D.new()
    floor_body.position = DANCE_POS + Vector3(0, 0.08, 0)
    floor_body.collision_layer = Character.LAYER_WORLD
    floor_body.add_to_group(NAV_GROUP)
    var shape := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(12.4, 0.16, 12.4)
    shape.shape = bs
    floor_body.add_child(shape)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(12.4, 0.16, 12.4)
    mi.mesh = bm
    var m := ShaderMaterial.new()
    m.shader = DISCO
    mi.material_override = m
    party.disco = m
    floor_body.add_child(mi)
    add_child(floor_body)
    box_count += 1
    # rim
    _box(DANCE_POS + Vector3(0, 0.1, -6.35), Vector3(12.9, 0.2, 0.25), Color(0.2, 0.2, 0.24))
    _box(DANCE_POS + Vector3(0, 0.1, 6.35), Vector3(12.9, 0.2, 0.25), Color(0.2, 0.2, 0.24))
    _box(DANCE_POS + Vector3(-6.35, 0.1, 0), Vector3(0.25, 0.2, 12.9), Color(0.2, 0.2, 0.24))
    _box(DANCE_POS + Vector3(6.35, 0.1, 0), Vector3(0.25, 0.2, 12.9), Color(0.2, 0.2, 0.24))
    # mirror ball on a rod
    var rod := MeshInstance3D.new()
    var rm := CylinderMesh.new()
    rm.top_radius = 0.06
    rm.bottom_radius = 0.06
    rm.height = 2.2
    rod.mesh = rm
    rod.position = DANCE_POS + Vector3(0, WALL_H - 1.1, 0)
    rod.material_override = _mat(Color(0.3, 0.3, 0.34))
    add_child(rod)
    var ball := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 1.3
    sm.height = 2.6
    sm.radial_segments = 14
    sm.rings = 8
    ball.mesh = sm
    ball.position = DANCE_POS + Vector3(0, WALL_H - 3.3, 0)
    var mm := StandardMaterial3D.new()
    mm.albedo_color = Color(0.9, 0.92, 0.98)
    mm.metallic = 1.0
    mm.roughness = 0.12
    mm.metallic_specular = 0.9
    ball.material_override = mm
    ball.name = "MirrorBall"
    add_child(ball)
    var spinner := PartySpinner.new()
    spinner.ball = ball
    spinner.lights = [
        _light(DANCE_POS + Vector3(3, 6.5, 3), PartyText.PINK, 2.2, 14.0),
        _light(DANCE_POS + Vector3(-3, 6.5, -3), PartyText.TEAL, 2.2, 14.0),
    ]
    add_child(spinner)
    # a speaker box (the stage at the north edge brings its own stacks)
    _place(PROTO + "Box_B.gltf", DANCE_POS + Vector3(-7.5, 0, 6.5), 0.0, 3.0)


class PartySpinner extends Node:
    var ball: MeshInstance3D
    var lights: Array = []
    var _t := 0.0
    func _process(delta: float) -> void:
        _t += delta
        if ball != null:
            ball.rotation.y += delta * 0.9
        for i in lights.size():
            var l := lights[i] as OmniLight3D
            if l != null:
                l.light_color = PartyText.color(int(_t * 1.4) + i * 3)
                l.light_energy = 1.8 + 0.8 * sin(_t * 4.0 + i)


# ---- north-east: the bouncy castle ------------------------------------------------------

func _bouncy_castle() -> void:
    var p := CASTLE_POS
    var pad := _box(p + Vector3(0, 0.35, 0), Vector3(11.5, 0.7, 11.5), PartyText.PINK)
    pad.name = "CastlePad"
    # inflatable walls: sausages on three sides (open to the south-west)
    for spec in [[Vector3(0, 1.1, -5.4), Vector3(0, 0, 0), 11.0], [Vector3(5.4, 1.1, 0), Vector3(0, PI * 0.5, 0), 11.0],
            [Vector3(-5.4, 1.1, 2.5), Vector3(0, PI * 0.5, 0), 6.0], [Vector3(0.5, 1.1, 5.4), Vector3(0, 0, 0), 10.0]]:
        var wall := MeshInstance3D.new()
        var cm := CapsuleMesh.new()
        cm.radius = 0.8
        cm.height = spec[2]
        cm.radial_segments = 12
        cm.rings = 4
        wall.mesh = cm
        wall.position = p + spec[0]
        wall.rotation = Vector3(PI * 0.5, 0, 0) if spec[1].y == 0.0 else Vector3(0, 0, PI * 0.5)
        wall.material_override = _mat(PartyText.TEAL)
        add_child(wall)
    # towers with gold roofs
    for x in [-5.4, 5.4]:
        for z in [-5.4, 5.4]:
            var tower := MeshInstance3D.new()
            var cm := CapsuleMesh.new()
            cm.radius = 1.1
            cm.height = 6.0
            cm.radial_segments = 12
            cm.rings = 4
            tower.mesh = cm
            tower.position = p + Vector3(x, 3.0, z)
            tower.material_override = _mat(PartyText.LILAC)
            add_child(tower)
            var roof := MeshInstance3D.new()
            var rm := CylinderMesh.new()
            rm.top_radius = 0.0
            rm.bottom_radius = 1.4
            rm.height = 1.6
            rm.radial_segments = 12
            roof.mesh = rm
            roof.position = p + Vector3(x, 6.6, z)
            roof.material_override = _mat(PartyText.GOLD)
            add_child(roof)
    var zone := PartyZone.new()
    zone.kind = PartyZone.Kind.BOUNCE
    zone.position = p + Vector3(0, 3.5, 0)
    zone.set_box(Vector3(10.8, 6.0, 10.8))
    add_child(zone)
    _sign(p + Vector3(0, 0, 7.3), "BOUNCY CASTLE", "super jump inside!", 0.0, PartyText.HOT_PINK, 4.0)


# ---- north-west: the moon corner -------------------------------------------------------

func _moon_corner() -> void:
    var p := MOON_POS
    var moon := _cyl_body(p + Vector3(0, 0.2, 0), 7.0, 0.4, Color(0.62, 0.63, 0.68), 0.05)
    moon.name = "MoonPad"
    # craters (dark discs) and rocks
    for spec in [[Vector3(2.5, 0, 1.5), 1.6], [Vector3(-3, 0, -2), 1.1], [Vector3(-1, 0, 3.5), 0.8], [Vector3(3.5, 0, -3.5), 1.3]]:
        _cyl_mesh(p + spec[0] + Vector3(0, 0.41, 0), spec[1], 0.04, Color(0.42, 0.43, 0.48), 0.0)
    for spec in [[Vector3(-4.5, 0, 3), 0.7], [Vector3(4.8, 0, 2.2), 0.5], [Vector3(0.5, 0, -4.8), 0.6]]:
        var rock := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = spec[1]
        sm.height = spec[1] * 1.6
        sm.radial_segments = 8
        sm.rings = 4
        rock.mesh = sm
        rock.position = p + spec[0] + Vector3(0, 0.4 + spec[1] * 0.5, 0)
        rock.material_override = _mat(Color(0.5, 0.5, 0.55))
        add_child(rock)
    # flag
    _cyl_mesh(p + Vector3(-2, 2.4, -2), 0.07, 4.0, Color(0.85, 0.85, 0.9), 0.3)
    var flag := _box_mat(p + Vector3(-1.1, 3.9, -2), Vector3(1.8, 1.1, 0.06), _mat(PartyText.HOT_PINK))
    flag.collision_layer = 0
    var l := Label3D.new()
    l.text = "LALU"
    l.font_size = 64
    l.pixel_size = 0.012
    l.position = Vector3(0, 0, 0.05)
    l.modulate = PartyText.CREAM
    flag.add_child(l)
    var zone := PartyZone.new()
    zone.kind = PartyZone.Kind.MOON
    zone.position = p + Vector3(0, 5.5, 0)
    zone.set_cylinder(7.0, 11.0)
    add_child(zone)
    _sign(p + Vector3(0, 0, 8.4), "MOON CORNER", "low gravity: jump high, float down", 0.0, PartyText.SKY, 4.0)


# ---- gifts, pinata, cannons, balloons --------------------------------------------------------

func _gifts() -> void:
    var specs := [
        [Vector3(7, 0, 9), PartyGift.Kind.SPRING, PartyText.TEAL, PartyText.GOLD],
        [Vector3(-8, 0, 12), PartyGift.Kind.JACK, PartyText.HOT_PINK, PartyText.CREAM],
        [Vector3(9, 0, -8), PartyGift.Kind.COINS, PartyText.LILAC, PartyText.GOLD],
        [Vector3(-9, 0, -6), PartyGift.Kind.PUPPY, PartyText.SKY, PartyText.HOT_PINK],
        [Vector3(0, 0, -13), PartyGift.Kind.FIREWORKS, PartyText.GOLD, PartyText.TEAL],
    ]
    for s in specs:
        var g := PartyGift.new()
        g.position = s[0]
        g.kind = s[1]
        g.color = s[2]
        g.ribbon_color = s[3]
        g.rotation.y = deg_to_rad(randf_range(-12.0, 12.0))
        add_child(g)
        party.add_gift(g)
        box_count += 1


func _pinata() -> void:
    var p := PartyPinata.new()
    p.position = Vector3(-10, WALL_H - 0.2, 9)
    add_child(p)
    party.set_pinata(p)
    # rope hook on the ceiling
    _cyl_mesh(Vector3(-10, WALL_H - 0.25, 9), 0.3, 0.3, Color(0.3, 0.3, 0.34), 0.3)


func _cannons() -> void:
    for c in party.corners:
        var cannon := PartyCannon.new()
        cannon.position = Vector3(c.x * 1.13, 0, c.z * 1.13)
        cannon.target = Vector3(c.x * 0.2, 9.0, c.z * 0.2)
        add_child(cannon)
        party.add_cannon(cannon)


func _balloons() -> void:
    var anchors: Array = []
    # around the cake plate
    for i in 8:
        var a := i * TAU / 8.0 + 0.2
        anchors.append([Vector3(sin(a) * 7.6, 0.3, cos(a) * 7.6), 4.0 + (i % 3) * 0.9])
    # table corners and chairs
    for off in [Vector3(-3.6, TABLE_TOP, -5.6), Vector3(3.6, TABLE_TOP, -5.6), Vector3(-3.6, TABLE_TOP, 5.6), Vector3(3.6, TABLE_TOP, 5.6),
            Vector3(0, 2.2, -8.8), Vector3(-6.6, 2.2, 0)]:
        anchors.append([TABLE_POS + off, 3.0])
    # dance floor edge
    for i in 6:
        var a := i * TAU / 6.0 + PI / 6.0   # none straight in front of the stage
        anchors.append([DANCE_POS + Vector3(sin(a) * 6.0, 0.3, cos(a) * 6.0), 3.5 + (i % 2) * 1.2])
    # castle towers
    for x in [-5.4, 5.4]:
        for z in [-5.4, 5.4]:
            anchors.append([CASTLE_POS + Vector3(x, 7.4, z), 2.4])
    # moon flag, gifts, wall weights
    anchors.append([MOON_POS + Vector3(-2, 4.5, -2), 2.5])
    anchors.append([Vector3(7, 2.6, 9), 3.2])
    anchors.append([Vector3(-8, 2.6, 12), 2.8])
    anchors.append([Vector3(9, 2.6, -8), 3.4])
    anchors.append([Vector3(-9, 2.6, -6), 3.0])
    anchors.append([Vector3(-22, 0.3, 0), 5.0])
    var i := 0
    for spec in anchors:
        if i >= 30:
            break
        var b := PartyBalloon.new()
        b.color = PartyText.color(i)
        b.anchor = spec[0]
        b.height = spec[1]
        b.index = i
        add_child(b)
        party.add_balloon(b)
        # a little weight where a string meets the floor
        if spec[0].y < 0.5:
            _cyl_mesh(spec[0] + Vector3(0, 0.0, 0), 0.3, 0.2, PartyText.color(i + 1), 0.4)
        i += 1


# ---- banner, signs, streamers, party lights ---------------------------------------------------

func _banner_and_signs() -> void:
    var z := -6.5
    _letter_row(PartyText.BANNER_TOP, Vector3(0, 10.2, z), 1.5, 1.95)
    _letter_row(PartyText.BANNER_NAME, Vector3(0, 7.9, z), 2.2, 2.9)
    _sign(Vector3(10.5, 0, 15.5), PartyText.SIGN, PartyText.SIGN_SMALL, -55.0, PartyText.PINK, 6.6)
    if PartyText.HEBREW_OK:
        var l := Label3D.new()
        l.text = PartyText.HEBREW
        l.font_size = 140
        l.pixel_size = 0.018
        l.position = Vector3(13, 5.4, -HALF + 0.2)
        l.modulate = PartyText.HOT_PINK
        l.outline_size = 14
        l.outline_modulate = PartyText.CREAM
        add_child(l)
        var l2 := Label3D.new()
        l2.text = PartyText.HEBREW
        l2.font_size = 140
        l2.pixel_size = 0.018
        l2.position = Vector3(-13, 5.4, HALF - 0.2)
        l2.rotation.y = PI
        l2.modulate = PartyText.TEAL
        l2.outline_size = 14
        l2.outline_modulate = PartyText.CREAM
        add_child(l2)


## Letter cubes hanging from the ceiling on strings, readable from both sides.
func _letter_row(text: String, center: Vector3, size: float, spacing: float) -> void:
    var n := text.length()
    var width := (n - 1) * spacing
    for i in n:
        var ch := text[i]
        if ch == " ":
            continue
        var x := center.x - width * 0.5 + i * spacing
        var sag := sin(float(i) / maxf(n - 1, 1) * PI) * 0.5
        var pos := Vector3(x, center.y - sag, center.z)
        var color := PartyText.color(_letter_i)
        _letter_i += 1
        var cube := _box(pos, Vector3(size, size, size), color)
        cube.collision_layer = 0   # decoration high above: nothing bumps into it
        for face in [Vector3(0, 0, 1), Vector3(0, 0, -1)]:
            var l := Label3D.new()
            l.text = ch
            l.font_size = 220
            l.pixel_size = size * 0.0034
            l.modulate = PartyText.CREAM
            l.outline_size = 0
            l.position = face * (size * 0.5 + 0.01)
            l.rotation.y = 0.0 if face.z > 0 else PI
            cube.add_child(l)
        var string_len := WALL_H - (pos.y + size * 0.5)
        _cyl_mesh(Vector3(pos.x, pos.y + size * 0.5 + string_len * 0.5, pos.z), 0.02, string_len, PartyText.CREAM, 0.0)


## A standing wooden sign with two lines of text.
func _sign(pos: Vector3, text: String, small: String, yaw_deg: float, color: Color, width: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation.y = deg_to_rad(yaw_deg)
    add_child(root)
    var wood := _pbr(TEX + "Wood066/Wood066_1K-JPG_Color.jpg", "", Vector2(1, 1), Color(1.0, 0.9, 0.75))
    var post := _box_mat(Vector3.ZERO, Vector3(0.3, 3.0, 0.3), wood)
    post.reparent(root)
    post.position = Vector3(0, 1.5, 0)
    post.rotation = Vector3.ZERO
    var board := _box_mat(Vector3.ZERO, Vector3(width, 2.2, 0.25), _mat(color))
    board.reparent(root)
    board.position = Vector3(0, 3.3, 0)
    board.rotation = Vector3.ZERO
    var l := Label3D.new()
    l.text = text
    l.font_size = 96
    l.pixel_size = 0.0058
    l.position = Vector3(0, 3.55, 0.14)
    l.modulate = PartyText.CREAM
    l.outline_size = 8
    l.outline_modulate = Color(0.15, 0.1, 0.12)
    root.add_child(l)
    var s := Label3D.new()
    s.text = small
    s.font_size = 56
    s.pixel_size = 0.0058
    s.position = Vector3(0, 2.85, 0.14)
    s.modulate = PartyText.CREAM
    s.outline_size = 6
    s.outline_modulate = Color(0.15, 0.1, 0.12)
    root.add_child(s)


func _streamers_and_lights() -> void:
    # zigzag paper streamers along the four walls, just under the ceiling
    var y := WALL_H - 1.0
    for wall in 4:
        var n := 12
        for i in n:
            var t0 := float(i) / n
            var t1 := float(i + 1) / n
            var a := _wall_point(wall, t0) + Vector3(0, y + (0.7 if i % 2 == 0 else -0.7), 0)
            var b := _wall_point(wall, t1) + Vector3(0, y + (0.7 if i % 2 == 1 else -0.7), 0)
            var mid := (a + b) * 0.5
            var d := b - a
            var seg := _box_mat(mid, Vector3(0.12, 0.42, d.length()), _mat(PartyText.color(i + wall)))
            seg.collision_layer = 0
            seg.look_at_from_position(mid, b, Vector3.UP)
    # coloured party lights in the four corners of the ceiling
    for i in 4:
        var c: Vector3 = party.corners[i]
        _light(Vector3(c.x * 0.7, WALL_H - 1.5, c.z * 0.7), PartyText.color(i * 2), 1.6, 24.0)
    # a couple of picture frames + a shelf to make it a room
    _place(FURN + "pictureframe_large_A.gltf", Vector3(-HALF + 0.1, 7.5, 14), 90.0, K, false)
    _place(FURN + "pictureframe_medium.gltf", Vector3(HALF - 0.1, 7.0, -18), -90.0, K, false)
    _place(FURN + "shelf_B_small_decorated.gltf", Vector3(12, 6.0, HALF - 0.1), 180.0, K, false)
    _place(FURN + "lamp_standing.gltf", Vector3(-23, 0, -3), 0.0, K)
    _light(Vector3(-23, 8.5, -3), Color(1.0, 0.88, 0.65), 2.5, 20.0)
    _place(FURN + "lamp_standing.gltf", Vector3(23, 0, 16), 0.0, K)
    _light(Vector3(23, 8.5, 16), Color(1.0, 0.88, 0.65), 2.5, 20.0)


## Hila's three things: a K-pop stage on the dance floor, Rich asleep on his cushion, Chuchu
## on a perch by the window.
func _hila_eggs() -> void:
    var stage := PartyKpop.new()
    stage.position = Vector3(DANCE_POS.x, 0, DANCE_POS.z - 8.0)
    add_child(stage)
    party.set_kpop(stage)
    box_count += 2
    var rich := PartyRich.new()
    rich.position = Vector3(-11, 0, 17)
    rich.rotation.y = -0.27   # his head toward the birthday girl's spawn
    add_child(rich)
    party.set_rich(rich)
    box_count += 1
    var bird := PartyChuchu.new()
    bird.position = Vector3(21.5, 0, -3)
    add_child(bird)
    party.set_chuchu(bird)


func _wall_point(wall: int, t: float) -> Vector3:
    var s := -HALF + 1.0 + t * (ROOM - 2.0)
    match wall:
        0:
            return Vector3(s, 0, -HALF + 0.4)
        1:
            return Vector3(s, 0, HALF - 0.4)
        2:
            return Vector3(-HALF + 0.4, 0, s)
        _:
            return Vector3(HALF - 0.4, 0, s)
