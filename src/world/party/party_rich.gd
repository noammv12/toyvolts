class_name PartyRich
extends StaticBody3D
## Rich, the family's grey-silver American Bully who looks like a hippopotamus: a giant plush
## asleep on his cushion (toys can climb him). Shoot him and he lifts his head, barks twice,
## wags and sheds a few hearts.

signal barked(rich: PartyRich)

const TOON: Shader = preload("res://shaders/toon.gdshader")
const GREY := Color(0.6, 0.62, 0.67)
const LIGHT := Color(0.76, 0.78, 0.82)
const DARK := Color(0.42, 0.44, 0.48)

var barks := 0
var happy_left := 0.0
var _t := 0.0
var _body: MeshInstance3D
var _head: Node3D
var _tail: MeshInstance3D
var _ears: Array[MeshInstance3D] = []
var _head_y := 1.6
var _mats := {}


func _ready() -> void:
    add_to_group("shootable")
    add_to_group("rich")
    collision_layer = Character.LAYER_WORLD
    collision_mask = 0
    add_to_group(ArenaBase.NAV_GROUP)
    # cushion (collider is the whole flat box) + the body mound (a box inside the ellipsoid)
    var cushion := CollisionShape3D.new()
    var cb := BoxShape3D.new()
    cb.size = Vector3(9.5, 0.5, 6.2)
    cushion.shape = cb
    cushion.position = Vector3(0, 0.25, 0)
    add_child(cushion)
    var mound := CollisionShape3D.new()
    var mb := BoxShape3D.new()
    mb.size = Vector3(5.4, 2.3, 3.2)
    mound.shape = mb
    mound.position = Vector3(0, 0.5 + 1.15, 0)
    add_child(mound)
    _box(Vector3(0, 0.25, 0), Vector3(9.5, 0.5, 6.2), Color(0.55, 0.16, 0.2), 0.15)
    _box(Vector3(0, 0.52, 0), Vector3(8.7, 0.08, 5.4), Color(0.72, 0.28, 0.32), 0.15)
    # body: a low wide barrel, lighter chest
    _body = _sphere(Vector3(0, 2.0, 0), 1.0, GREY, 0.2)
    _body.scale = Vector3(3.2, 1.5, 2.1)
    var chest := _sphere(Vector3(1.6, 1.4, 0), 1.0, LIGHT, 0.2)
    chest.scale = Vector3(1.9, 1.05, 1.7)
    # head: big, wide, flat snout (the hippo look)
    _head = Node3D.new()
    _head.position = Vector3(3.6, _head_y, 0)
    add_child(_head)
    var skull := _sphere(Vector3.ZERO, 1.0, GREY, 0.2, _head)
    skull.scale = Vector3(1.9, 1.5, 1.85)
    var snout := _sphere(Vector3(1.35, -0.35, 0), 1.0, LIGHT, 0.2, _head)
    snout.scale = Vector3(1.25, 0.72, 1.45)
    _box(Vector3(1.4, -0.85, 0), Vector3(1.9, 0.32, 2.2), DARK, 0.1, _head)     # jowls / mouth line
    var nose := _sphere(Vector3(2.5, -0.15, 0), 0.3, Color(0.12, 0.12, 0.13), 0.6, _head)
    nose.scale = Vector3(0.7, 0.75, 1.2)
    for z in [-0.6, 0.6]:
        _sphere(Vector3(1.0, 0.5, z), 0.17, Color(0.1, 0.1, 0.12), 0.7, _head)
        _sphere(Vector3(1.05, 0.56, z), 0.05, Color.WHITE, 0.0, _head)
    for z in [-1.0, 1.0]:
        var ear := _sphere(Vector3(-0.6, 1.25, z), 0.3, DARK, 0.15, _head)
        ear.scale = Vector3(0.9, 1.2, 0.6)
        _ears.append(ear)
    # legs (front stretched out, hind tucked), tail, collar and tag
    for z in [-0.95, 0.95]:
        var leg := _capsule(Vector3(4.2, 0.95, z), 0.45, 2.4, GREY, 0.2)
        leg.rotation = Vector3(0, 0, deg_to_rad(90.0))
        _sphere(Vector3(5.3, 0.85, z), 0.5, LIGHT, 0.2)
        var hind := _sphere(Vector3(-2.4, 1.1, z * 1.5), 0.7, GREY, 0.2)
        hind.scale = Vector3(1.2, 0.8, 0.9)
    _tail = _capsule(Vector3(-3.4, 1.7, 0.5), 0.13, 1.2, GREY, 0.2)
    _tail.rotation = Vector3(0, 0, deg_to_rad(55.0))
    var collar := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 1.55
    tm.outer_radius = 1.8
    tm.rings = 24
    tm.ring_segments = 8
    collar.mesh = tm
    collar.position = Vector3(2.55, 1.75, 0)
    collar.rotation = Vector3(0, 0, deg_to_rad(90.0))
    collar.material_override = _mat(PartyText.TEAL, 0.4)
    add_child(collar)
    var tag := _box(Vector3(2.8, 0.95, 0.75), Vector3(0.5, 0.45, 0.12), PartyText.GOLD, 0.6)
    tag.rotation = Vector3(0, deg_to_rad(-25.0), 0)
    var tl := Label3D.new()
    tl.text = PartyText.RICH_NAME
    tl.font_size = 40
    tl.pixel_size = 0.005
    tl.position = Vector3(0, 0, 0.07)
    tl.modulate = Color(0.25, 0.15, 0.05)
    tag.add_child(tl)
    var name_label := Label3D.new()
    name_label.text = PartyText.RICH_NAME
    name_label.font_size = 72
    name_label.pixel_size = 0.012
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_label.position = Vector3(3.4, 4.6, 0)
    name_label.modulate = PartyText.CREAM
    name_label.outline_size = 12
    name_label.outline_modulate = Color(0.3, 0.32, 0.36)
    add_child(name_label)
    var sub := Label3D.new()
    sub.text = PartyText.RICH_SUB
    sub.font_size = 40
    sub.pixel_size = 0.01
    sub.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sub.position = Vector3(3.4, 4.1, 0)
    sub.modulate = PartyText.PINK
    sub.outline_size = 8
    sub.outline_modulate = Color(0.3, 0.32, 0.36)
    add_child(sub)
    # a bone
    var bone := Node3D.new()
    bone.position = Vector3(1.0, 0.7, 3.4)
    bone.rotation = Vector3(0, deg_to_rad(30.0), 0)
    add_child(bone)
    var shaft := _capsule(Vector3.ZERO, 0.14, 1.1, PartyText.CREAM, 0.3, bone)
    shaft.rotation = Vector3(0, 0, deg_to_rad(90.0))
    for x in [-0.55, 0.55]:
        for z in [-0.14, 0.14]:
            _sphere(Vector3(x, 0, z), 0.2, PartyText.CREAM, 0.3, bone)


func _process(delta: float) -> void:
    _t += delta
    happy_left = maxf(0.0, happy_left - delta)
    var breath := 1.0 + 0.025 * sin(_t * 1.6)
    _body.scale = Vector3(3.2, 1.5 * breath, 2.1)
    if happy_left > 0.0:
        _tail.rotation = Vector3(0, sin(_t * 26.0) * 0.8, deg_to_rad(55.0))
        _head.position.y = _head_y + 0.5 * clampf(happy_left / 1.5, 0.0, 1.0) + 0.06 * sin(_t * 9.0)
        _head.rotation.z = sin(_t * 7.0) * 0.06
        for i in _ears.size():
            _ears[i].rotation.x = sin(_t * 14.0 + i) * 0.35
    else:
        _tail.rotation = Vector3(0, sin(_t * 1.2) * 0.12, deg_to_rad(55.0))
        _head.position.y = lerpf(_head.position.y, _head_y, minf(1.0, delta * 3.0))
        _head.rotation.z = lerpf(_head.rotation.z, 0.0, minf(1.0, delta * 3.0))


func head_position() -> Vector3:
    return _head.global_position + Vector3(0, 0.8, 0)


func on_shot(_by: Character, _pos: Vector3, _dir: Vector3, _weapon: WeaponData) -> void:
    bark(true)
    barked.emit(self)


## The reaction: two woofs, head up, tail wag, hearts.
func bark(effects: bool) -> void:
    barks += 1
    happy_left = 4.0
    if effects:
        Sfx.play("woof", head_position(), 0.0, 0.08)
        var fx := _fx()
        if fx != null:
            fx.sparkle(head_position() + Vector3(0.6, 0.6, 0))
            fx.confetti(head_position() + Vector3(0, 0.5, 0), Vector3.UP, 45.0, 30)


func _fx() -> PartyFx:
    var p := get_tree().get_first_node_in_group("party")
    return p.fx if p != null else null


# ---- builders ----------------------------------------------------------------------

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


func _sphere(pos: Vector3, r: float, c: Color, spec: float, parent: Node3D = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 20
    sm.rings = 10
    mi.mesh = sm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    (parent if parent != null else self).add_child(mi)
    return mi


func _capsule(pos: Vector3, r: float, h: float, c: Color, spec: float, parent: Node3D = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = r
    cm.height = h
    cm.radial_segments = 14
    cm.rings = 5
    mi.mesh = cm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    (parent if parent != null else self).add_child(mi)
    return mi


func _box(pos: Vector3, size: Vector3, c: Color, spec: float, parent: Node3D = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = _mat(c, spec)
    (parent if parent != null else self).add_child(mi)
    return mi
