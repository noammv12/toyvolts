class_name PartyKpop
extends Node3D
## A K-pop stage at the edge of the dance floor: platform, neon sign, speaker stacks, a truss
## with stage lights and a big red PLAY button. Shoot the button: the K-pop track plays, the
## lights strobe on the beat and every guest lines up on the floor for a synchronised routine.

signal play_pressed(stage: PartyKpop)

const TOON: Shader = preload("res://shaders/toon.gdshader")
const BPM := 128.0
const FORMATION: Array[Vector3] = [Vector3(0, 0, 6.0), Vector3(-2.4, 0, 7.8), Vector3(2.4, 0, 7.8),
    Vector3(-4.6, 0, 9.6), Vector3(4.6, 0, 9.6), Vector3(-1.2, 0, 11.4), Vector3(1.2, 0, 11.4)]

var active := false
var presses := 0
var _lights: Array[OmniLight3D] = []
var _button: MeshInstance3D
var _button_mat: StandardMaterial3D
var _sign: Label3D
var _t := 0.0
var _mats := {}


func _ready() -> void:
    add_to_group("kpop")
    # platform (walkable, part of the navmesh)
    var platform := StaticBody3D.new()
    platform.collision_layer = Character.LAYER_WORLD
    platform.add_to_group(ArenaBase.NAV_GROUP)
    var ps := CollisionShape3D.new()
    var pb := BoxShape3D.new()
    pb.size = Vector3(10, 1.0, 3.2)
    ps.shape = pb
    ps.position = Vector3(0, 0.5, 0)
    platform.add_child(ps)
    platform.add_child(_box(Vector3(0, 0.5, 0), Vector3(10, 1.0, 3.2), Color(0.16, 0.15, 0.2), 0.2))
    platform.add_child(_box(Vector3(0, 1.02, 0), Vector3(9.6, 0.06, 2.8), PartyText.HOT_PINK, 0.5))
    add_child(platform)
    # back panel + neon sign
    var back := StaticBody3D.new()
    back.collision_layer = Character.LAYER_WORLD
    back.add_to_group(ArenaBase.NAV_GROUP)
    var bs := CollisionShape3D.new()
    var bb := BoxShape3D.new()
    bb.size = Vector3(10, 5.0, 0.4)
    bs.shape = bb
    bs.position = Vector3(0, 3.5, -1.7)
    back.add_child(bs)
    back.add_child(_box(Vector3(0, 3.5, -1.7), Vector3(10, 5.0, 0.4), Color(0.1, 0.1, 0.18), 0.1))
    add_child(back)
    _sign = Label3D.new()
    _sign.text = PartyText.KPOP_SIGN
    _sign.font_size = 150
    _sign.pixel_size = 0.014
    _sign.position = Vector3(0, 4.85, -1.45)
    _sign.modulate = PartyText.HOT_PINK
    _sign.outline_size = 16
    _sign.outline_modulate = PartyText.TEAL
    add_child(_sign)
    var sub := Label3D.new()
    sub.text = PartyText.KPOP_KO if PartyText.KPOP_KO_OK else PartyText.KPOP_SUB
    sub.font_size = 90
    sub.pixel_size = 0.012
    sub.position = Vector3(0, 3.75, -1.45)
    sub.modulate = PartyText.CREAM
    sub.outline_size = 10
    sub.outline_modulate = PartyText.HOT_PINK
    add_child(sub)
    var hint := Label3D.new()
    hint.text = PartyText.KPOP_HINT
    hint.font_size = 56
    hint.pixel_size = 0.011
    hint.position = Vector3(0, 2.95, -1.45)
    hint.modulate = PartyText.GOLD
    hint.outline_size = 7
    hint.outline_modulate = Color(0.1, 0.1, 0.18)
    add_child(hint)
    # speaker stacks with cones, hearts on them
    for x in [-4.0, 4.0]:
        add_child(_box(Vector3(x, 2.2, -0.9), Vector3(1.4, 2.4, 1.1), Color(0.08, 0.08, 0.1), 0.3))
        for y in [1.5, 2.8]:
            var cone := _cyl(Vector3(x, y, -0.3), 0.42, 0.12, Color(0.3, 0.3, 0.34), 0.4)
            cone.rotation = Vector3(deg_to_rad(90.0), 0, 0)
    # truss + hanging stage lights
    for x in [-4.8, 4.8]:
        _cyl(Vector3(x, 3.0, 1.3), 0.08, 5.8, Color(0.4, 0.4, 0.45), 0.4)
    add_child(_box(Vector3(0, 5.9, 1.3), Vector3(10, 0.2, 0.2), Color(0.4, 0.4, 0.45), 0.4))
    for i in 4:
        var x := -3.6 + i * 2.4
        var can := _cyl(Vector3(x, 5.45, 1.3), 0.22, 0.5, Color(0.12, 0.12, 0.14), 0.4)
        can.rotation = Vector3(deg_to_rad(-35.0), 0, 0)
        var l := OmniLight3D.new()
        l.position = Vector3(x, 5.1, 1.0)
        l.light_color = PartyText.color(i)
        l.light_energy = 0.0
        l.omni_range = 16.0
        l.omni_attenuation = 1.3
        l.shadow_enabled = false
        add_child(l)
        _lights.append(l)
    # the PLAY button: a red dome on a stand at the front of the stage
    _cyl(Vector3(0, 1.55, 1.15), 0.28, 1.1, Color(0.35, 0.35, 0.4), 0.4)
    _cyl(Vector3(0, 2.1, 1.15), 0.62, 0.16, Color(0.2, 0.2, 0.24), 0.4)
    _button = MeshInstance3D.new()
    var dome := SphereMesh.new()
    dome.radius = 0.55
    dome.height = 0.55
    dome.is_hemisphere = true
    dome.radial_segments = 20
    dome.rings = 8
    _button.mesh = dome
    _button.position = Vector3(0, 2.18, 1.15)
    _button_mat = StandardMaterial3D.new()
    _button_mat.albedo_color = Color(0.95, 0.15, 0.2)
    _button_mat.emission_enabled = true
    _button_mat.emission = Color(1.0, 0.2, 0.25)
    _button_mat.emission_energy_multiplier = 0.8
    _button_mat.roughness = 0.35
    _button.material_override = _button_mat
    add_child(_button)
    var pl := Label3D.new()
    pl.text = "PLAY"
    pl.font_size = 48
    pl.pixel_size = 0.008
    pl.position = Vector3(0, 1.65, 1.46)
    pl.modulate = PartyText.CREAM
    pl.outline_size = 6
    pl.outline_modulate = Color(0.1, 0.1, 0.14)
    add_child(pl)
    var button_body := ButtonHit.new()
    button_body.stage = self
    button_body.collision_layer = Character.LAYER_TARGET
    button_body.collision_mask = 0
    button_body.add_to_group("shootable")
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.85
    shape.shape = sphere
    shape.position = Vector3(0, 2.3, 1.15)
    button_body.add_child(shape)
    add_child(button_body)


class ButtonHit extends StaticBody3D:
    var stage: PartyKpop
    func on_shot(by: Character, pos: Vector3, dir: Vector3, weapon: WeaponData) -> void:
        stage.on_shot(by, pos, dir, weapon)


func button_position() -> Vector3:
    return _button.global_position + Vector3(0, 0.2, 0)


## Where guest `i` dances (world space) and where they face (the stage).
func formation_spot(i: int) -> Vector3:
    return to_global(FORMATION[posmod(i, FORMATION.size())])


func stage_position() -> Vector3:
    return global_position


func on_shot(_by: Character, _pos: Vector3, _dir: Vector3, _weapon: WeaponData) -> void:
    presses += 1
    Sfx.play("ui_click", button_position(), 4.0, 0.0)
    var tw := create_tween()
    _button.position.y = 2.05
    tw.tween_property(_button, "position:y", 2.18, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    play_pressed.emit(self)


func set_active(on: bool) -> void:
    active = on
    for l in _lights:
        l.light_energy = 2.5 if on else 0.0
    _button_mat.emission_energy_multiplier = 2.5 if on else 0.8


func _process(delta: float) -> void:
    _t += delta
    if active:
        var beat := _t * BPM / 60.0
        var pulse := 1.0 - fmod(beat, 1.0)
        for i in _lights.size():
            var l := _lights[i]
            l.light_color = PartyText.color(int(beat) + i * 2)
            l.light_energy = 1.2 + 2.4 * pulse * (1.0 if (int(beat) + i) % 2 == 0 else 0.5)
        _sign.scale = Vector3.ONE * (1.0 + 0.06 * pulse)
        _button_mat.emission_energy_multiplier = 1.5 + 1.5 * pulse
    else:
        _button_mat.emission_energy_multiplier = 0.8 + 0.5 * (0.5 + 0.5 * sin(_t * 3.0))


# ---- builders -----------------------------------------------------------------------

func _mat(c: Color, spec: float) -> ShaderMaterial:
    var key := [c, spec]
    if _mats.has(key):
        return _mats[key]
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", c)
    m.set_shader_parameter("spec_strength", spec)
    _mats[key] = m
    return m


func _box(pos: Vector3, size: Vector3, c: Color, spec: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    return mi


func _cyl(pos: Vector3, r: float, h: float, c: Color, spec: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = h
    cm.radial_segments = 16
    cm.rings = 1
    mi.mesh = cm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    add_child(mi)
    return mi
