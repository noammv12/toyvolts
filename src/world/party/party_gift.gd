class_name PartyGift
extends Node3D
## A wrapped present. Shoot the ribbon / bow on top: the lid pops off and a surprise comes out:
## a spring toy, a jack-in-the-box figure that cheers, a coin rain, a puppy plush that follows
## whoever opened it, or a fireworks battery.

signal opened(gift: PartyGift, by: Character)

enum Kind { SPRING, JACK, COINS, PUPPY, FIREWORKS }

const TOON: Shader = preload("res://shaders/toon.gdshader")
const SIZE := 2.2
const COIN_RAIN_SECONDS := 3.2
const FIREWORK_SHOTS := 16
const FIREWORK_INTERVAL := 1.5

var index := 0
var kind := Kind.SPRING
var color := PartyText.PINK
var ribbon_color := PartyText.GOLD
var is_open := false
var opener: Character = null
var surprise: Node3D = null
var _box: StaticBody3D
var _lid: Node3D
var _ribbon: Ribbon
var _lid_tween: Tween
var _coil: Coil
var _timer := 0.0
var _count := 0
var _mats := {}


class Ribbon extends StaticBody3D:
    var gift: PartyGift
    func on_shot(by: Character, _pos: Vector3, _dir: Vector3, _weapon: WeaponData) -> void:
        gift.open_by(by, true)


class Coil extends Node3D:
    var length := 3.0
    var top: Node3D
    var _rings: Node3D
    func build(len: float, c: Color, mat: ShaderMaterial) -> void:
        length = len
        _rings = Node3D.new()
        add_child(_rings)
        var n := 7
        for i in n:
            var r := MeshInstance3D.new()
            var tm := TorusMesh.new()
            tm.inner_radius = 0.36
            tm.outer_radius = 0.5
            tm.rings = 16
            tm.ring_segments = 6
            r.mesh = tm
            r.position = Vector3(0, (i + 0.5) / n * len, 0)
            r.rotation = Vector3(deg_to_rad(9.0), 0, 0)
            r.material_override = mat
            r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _rings.add_child(r)
        top = Node3D.new()
        add_child(top)
        set_stretch(0.05)
    func set_stretch(f: float) -> void:
        _rings.scale = Vector3(1, f, 1)
        top.position = Vector3(0, length * f, 0)


func _ready() -> void:
    add_to_group("gifts")
    var dark := color.darkened(0.25)
    _box = StaticBody3D.new()
    _box.collision_layer = Character.LAYER_WORLD
    _box.collision_mask = 0
    _box.add_to_group(ArenaBase.NAV_GROUP)
    var shape := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(SIZE, SIZE + 0.4, SIZE)
    shape.shape = bs
    shape.position = Vector3(0, (SIZE + 0.4) * 0.5, 0)
    _box.add_child(shape)
    _box.add_child(_mesh(_boxmesh(Vector3(SIZE, SIZE, SIZE)), Vector3(0, SIZE * 0.5, 0), color, 0.3))
    # vertical ribbon bands on the box sides
    _box.add_child(_mesh(_boxmesh(Vector3(0.36, SIZE + 0.02, SIZE + 0.06)), Vector3(0, SIZE * 0.5, 0), ribbon_color, 0.5))
    _box.add_child(_mesh(_boxmesh(Vector3(SIZE + 0.06, SIZE + 0.02, 0.36)), Vector3(0, SIZE * 0.5, 0), ribbon_color, 0.5))
    add_child(_box)
    _lid = Node3D.new()
    _lid.position = Vector3(0, SIZE + 0.22, 0)
    _lid.add_child(_mesh(_boxmesh(Vector3(SIZE + 0.24, 0.44, SIZE + 0.24)), Vector3.ZERO, dark, 0.3))
    add_child(_lid)
    _ribbon = Ribbon.new()
    _ribbon.gift = self
    _ribbon.collision_layer = Character.LAYER_TARGET
    _ribbon.collision_mask = 0
    _ribbon.add_to_group("shootable")
    var rs := CollisionShape3D.new()
    var rb := BoxShape3D.new()
    rb.size = Vector3(SIZE + 0.4, 1.3, SIZE + 0.4)
    rs.shape = rb
    rs.position = Vector3(0, 0.45, 0)
    _ribbon.add_child(rs)
    _ribbon.add_child(_mesh(_boxmesh(Vector3(0.36, 0.5, SIZE + 0.3)), Vector3(0, 0.02, 0), ribbon_color, 0.5))
    _ribbon.add_child(_mesh(_boxmesh(Vector3(SIZE + 0.3, 0.5, 0.36)), Vector3(0, 0.02, 0), ribbon_color, 0.5))
    for x in [-0.42, 0.42]:   # bow loops
        var loop := _mesh(_sphere(0.42), Vector3(x, 0.5, 0), ribbon_color, 0.5)
        loop.scale = Vector3(1.1, 0.55, 0.8)
        _ribbon.add_child(loop)
    _ribbon.add_child(_mesh(_sphere(0.2), Vector3(0, 0.5, 0), ribbon_color.darkened(0.2), 0.5))
    _lid.add_child(_ribbon)


func top_position() -> Vector3:
    return global_position + Vector3(0, SIZE + 0.6, 0)


func open_by(by: Character, effects: bool) -> void:
    if is_open:
        return
    is_open = true
    opener = by
    _ribbon.set_deferred("collision_layer", 0)
    _lid_tween = create_tween()
    var side := Vector3(SIZE * 0.95 + 0.6, 0.24, 0.3)
    _lid_tween.set_parallel(true)
    _lid_tween.tween_property(_lid, "position", Vector3(0, SIZE + 3.6, 0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    _lid_tween.tween_property(_lid, "rotation", Vector3(0.3, 0.6, 1.2), 0.45)
    _lid_tween.chain().tween_property(_lid, "position", side, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    _lid_tween.parallel().tween_property(_lid, "rotation", Vector3(0.0, 0.4, deg_to_rad(-100.0)), 0.5)
    if effects:
        Sfx.play("gift_open", top_position())
        var fx := _fx()
        if fx != null:
            fx.sparkle(top_position())
            fx.confetti(top_position(), Vector3.UP, 60.0, 50)
    _spawn_surprise()
    opened.emit(self, by)


func close() -> void:
    if not is_open:
        return
    is_open = false
    opener = null
    if _lid_tween != null and _lid_tween.is_valid():
        _lid_tween.kill()
    _lid.position = Vector3(0, SIZE + 0.22, 0)
    _lid.rotation = Vector3.ZERO
    _ribbon.set_deferred("collision_layer", Character.LAYER_TARGET)
    if surprise != null and is_instance_valid(surprise):
        surprise.queue_free()
    surprise = null
    _coil = null
    set_process(false)


func _spawn_surprise() -> void:
    surprise = Node3D.new()
    surprise.name = "Surprise"
    _timer = 0.0
    _count = 0
    match kind:
        Kind.SPRING:
            add_child(surprise)
            surprise.position = Vector3(0, SIZE - 0.3, 0)
            _coil = Coil.new()
            _coil.build(3.2, PartyText.TEAL, _mat(PartyText.TEAL, 0.5))
            surprise.add_child(_coil)
            var head := _mesh(_sphere(0.62), Vector3(0, 0.55, 0), PartyText.GOLD, 0.4)
            _coil.top.add_child(head)
            for x in [-0.22, 0.22]:
                _coil.top.add_child(_mesh(_sphere(0.08), Vector3(x, 0.7, 0.55), Color(0.1, 0.1, 0.12), 0.6))
            var mouth := _mesh(_boxmesh(Vector3(0.42, 0.07, 0.1)), Vector3(0, 0.4, 0.58), Color(0.5, 0.1, 0.15), 0.2)
            mouth.rotation = Vector3(0.0, 0.0, 0.0)
            _coil.top.add_child(mouth)
            var hat := PartyHat.build(PartyText.HOT_PINK, 0.5)
            hat.position = Vector3(0, 1.1, 0)
            hat.rotation = Vector3(0, 0, deg_to_rad(-15.0))
            _coil.top.add_child(hat)
            _launch_coil(1.2)
        Kind.JACK:
            add_child(surprise)
            surprise.position = Vector3(0, SIZE - 0.3, 0)
            _coil = Coil.new()
            _coil.build(2.0, PartyText.HOT_PINK, _mat(PartyText.HOT_PINK, 0.5))
            surprise.add_child(_coil)
            var fig := Figure.new()
            fig.rotation.y = PI   # face south (the birthday girl spawns there)
            _coil.top.add_child(fig)
            fig.setup(Skins.path(["Mage", "Rogue", "Barbarian", "Knight"][index % 4]), PartyText.LILAC, 0.25)
            fig.set_aiming(false)
            fig.add_hat(PartyText.GOLD)
            _launch_coil(1.0)
            set_process(true)
        Kind.COINS:
            add_child(surprise)
            var rain := GPUParticles3D.new()
            rain.amount = 160
            rain.lifetime = 3.0
            rain.one_shot = false
            rain.explosiveness = 0.0
            rain.local_coords = false
            var coin := CylinderMesh.new()
            coin.top_radius = 0.22
            coin.bottom_radius = 0.22
            coin.height = 0.06
            coin.radial_segments = 10
            coin.rings = 1
            var gold := StandardMaterial3D.new()
            gold.albedo_color = Color(1.0, 0.82, 0.3)
            gold.metallic = 0.85
            gold.roughness = 0.25
            gold.emission_enabled = true
            gold.emission = Color(1.0, 0.7, 0.2)
            gold.emission_energy_multiplier = 0.4
            coin.material = gold
            rain.draw_pass_1 = coin
            var pm := ParticleProcessMaterial.new()
            pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
            pm.emission_box_extents = Vector3(2.8, 0.3, 2.8)
            pm.direction = Vector3(0, -1, 0)
            pm.spread = 15.0
            pm.initial_velocity_min = 0.5
            pm.initial_velocity_max = 2.5
            pm.gravity = Vector3(0, -9.0, 0)
            pm.angle_min = 0.0
            pm.angle_max = 360.0
            pm.angular_velocity_min = -500.0
            pm.angular_velocity_max = 500.0
            pm.particle_flag_rotate_y = true
            rain.process_material = pm
            rain.position = Vector3(0, 8.5, 0)
            rain.emitting = true
            surprise.add_child(rain)
            set_process(true)
        Kind.PUPPY:
            get_parent().add_child(surprise)
            surprise.global_position = global_position + Vector3(SIZE * 0.5 + 1.2, 0, 1.0)
            var pup := PartyPuppy.new()
            pup.owner_character = opener
            surprise.add_child(pup)
            var fx := _fx()
            if fx != null:
                fx.sparkle(surprise.global_position + Vector3(0, 0.8, 0))
            Sfx.play("squeak", surprise.global_position, 0.0, 0.3)
        Kind.FIREWORKS:
            get_parent().add_child(surprise)
            surprise.global_position = global_position + Vector3(-(SIZE * 0.5 + 1.4), 0, 0.4)
            surprise.add_child(_mesh(_boxmesh(Vector3(1.6, 0.7, 1.1)), Vector3(0, 0.35, 0), Color(0.8, 0.2, 0.18), 0.3))
            for i in 6:
                var tube := _mesh(_cylmesh(0.13, 0.9), Vector3(-0.5 + (i % 3) * 0.5, 1.1, -0.25 + (i / 3) * 0.5),
                    [PartyText.GOLD, PartyText.TEAL, PartyText.SKY][i % 3], 0.4)
                surprise.add_child(tube)
            var label := Label3D.new()
            label.text = "FIREWORKS"
            label.font_size = 48
            label.pixel_size = 0.008
            label.position = Vector3(0, 0.38, 0.56)
            label.modulate = PartyText.CREAM
            surprise.add_child(label)
            set_process(true)


func _launch_coil(seconds: float) -> void:
    Sfx.play("boing", top_position(), 0.0, 0.1)
    var tw := create_tween()
    tw.tween_method(_coil.set_stretch, 0.05, 1.0, seconds).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    if kind == Kind.SPRING:
        set_process(true)


func _process(delta: float) -> void:
    if surprise == null or not is_instance_valid(surprise):
        set_process(false)
        return
    _timer += delta
    match kind:
        Kind.SPRING:
            if _timer > 1.3 and _coil != null:
                _coil.set_stretch(1.0 + 0.05 * sin(_timer * 4.0))
                _coil.top.rotation.y = sin(_timer * 1.3) * 0.5
        Kind.JACK:
            if _timer >= 2.2:
                _timer = 0.0
                var fig := _coil.top.get_child(0) as Figure
                if fig != null and fig.ready_ok:
                    fig.play_action("cheer", 1.1)
                Sfx.play("cheer", top_position(), -8.0, 0.2)
        Kind.COINS:
            if _count < 12 and _timer >= _count * 0.24:
                _count += 1
                Sfx.play("coin", top_position(), -2.0, 0.12)
            if _timer >= COIN_RAIN_SECONDS and surprise.get_child_count() == 1:
                (surprise.get_child(0) as GPUParticles3D).emitting = false
                _coin_pile()
            if _timer > COIN_RAIN_SECONDS + 4.0:
                set_process(false)
        Kind.FIREWORKS:
            if _count < FIREWORK_SHOTS and _timer >= _count * FIREWORK_INTERVAL + 0.8:
                var fx := _fx()
                if fx != null:
                    fx.firework(surprise.global_position + Vector3(0, 1.5, 0), PartyText.color(_count + index))
                _count += 1
            if _count >= FIREWORK_SHOTS:
                set_process(false)


## After the rain: a scatter of coins on the floor around the box.
func _coin_pile() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 77 + index
    var pile := Node3D.new()
    surprise.add_child(pile)
    var gold := _mat(Color(1.0, 0.82, 0.3), 0.7)
    for i in 28:
        var mi := MeshInstance3D.new()
        mi.mesh = _cylmesh(0.22, 0.06)
        var a := rng.randf() * TAU
        var r := rng.randf_range(1.6, 3.6)
        mi.position = Vector3(sin(a) * r, 0.03, cos(a) * r)
        mi.rotation = Vector3(0, rng.randf() * TAU, 0)
        mi.material_override = gold
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        pile.add_child(mi)


# ---- builders -------------------------------------------------------------------------

func _mesh(mesh: Mesh, pos: Vector3, c: Color, spec: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = _mat(c, spec)
    return mi


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


func _boxmesh(size: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = size
    return b


func _sphere(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 14
    s.rings = 7
    return s


func _cylmesh(r: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = r
    c.bottom_radius = r
    c.height = h
    c.radial_segments = 10
    c.rings = 1
    return c


func _fx() -> PartyFx:
    var p := get_tree().get_first_node_in_group("party")
    return p.fx if p != null else null
