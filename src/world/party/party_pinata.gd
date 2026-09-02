class_name PartyPinata
extends Node3D
## A paper donkey hanging from the ceiling on a rope. Every hit swings it (a pendulum on two
## axes) and after HITS_TO_BURST it bursts into candy cubes and item capsules.

signal hit(pinata: PartyPinata, hits: int)
signal burst(pinata: PartyPinata)

const TOON: Shader = preload("res://shaders/toon.gdshader")
const HITS_TO_BURST := 10
const ROPE := 5.5
const CANDY := 26
const STRIPES: Array[Color] = [PartyText.HOT_PINK, PartyText.GOLD, PartyText.TEAL, PartyText.LILAC, PartyText.MINT, PartyText.SKY]

var hits := 0
var is_burst := false
var _pivot: Node3D
var _body: Node3D
var _rope: MeshInstance3D
var _collider: StaticBody3D
var _ang := Vector2.ZERO      ## x: tilt about X (swings along z), y: tilt about Z (swings along x)
var _vel := Vector2.ZERO
var _punch := 0.0
var _candy: Array[RigidBody3D] = []
var _mats := {}


func _ready() -> void:
    add_to_group("shootable")
    add_to_group("pinata")
    _pivot = Node3D.new()
    add_child(_pivot)
    _rope = MeshInstance3D.new()
    var rm := CylinderMesh.new()
    rm.top_radius = 0.06
    rm.bottom_radius = 0.06
    rm.height = 1.0
    rm.radial_segments = 6
    _rope.mesh = rm
    _rope.material_override = _mat(Color(0.8, 0.7, 0.5), 0.0)
    _rope.position = Vector3(0, -ROPE * 0.5, 0)
    _rope.scale = Vector3(1, ROPE, 1)
    _rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _pivot.add_child(_rope)
    _body = Node3D.new()
    _body.position = Vector3(0, -ROPE, 0)
    _pivot.add_child(_body)
    _build_donkey()
    _collider = StaticBody3D.new()
    _collider.collision_layer = Character.LAYER_TARGET
    _collider.collision_mask = 0
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(3.0, 2.1, 1.5)
    shape.shape = box
    _collider.add_child(shape)
    _body.add_child(_collider)
    _vel = Vector2(0.25, 0.15)


func _build_donkey() -> void:
    var pink := PartyText.PINK
    _box(_body, Vector3(0, 0, 0), Vector3(2.0, 1.1, 0.9), pink)                       # torso
    for i in 6:                                                                           # paper fringe
        _box(_body, Vector3(0, -0.45 + i * 0.18, 0), Vector3(2.06, 0.1, 0.96), STRIPES[i])
    _box(_body, Vector3(1.25, 0.55, 0), Vector3(0.75, 0.75, 0.7), pink)               # head
    _box(_body, Vector3(1.75, 0.4, 0), Vector3(0.35, 0.4, 0.5), PartyText.GOLD)        # snout
    _box(_body, Vector3(1.15, 1.1, 0.22), Vector3(0.14, 0.5, 0.2), PartyText.TEAL)     # ears
    _box(_body, Vector3(1.15, 1.1, -0.22), Vector3(0.14, 0.5, 0.2), PartyText.TEAL)
    for x in [-0.7, 0.7]:
        for z in [-0.28, 0.28]:
            _box(_body, Vector3(x, -0.95, z), Vector3(0.28, 0.85, 0.28), PartyText.LILAC)   # legs
    _box(_body, Vector3(-1.15, 0.25, 0), Vector3(0.35, 0.12, 0.12), PartyText.GOLD)      # tail
    for z in [-0.2, 0.2]:                                                                 # eyes
        var eye := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.09
        sm.height = 0.18
        sm.radial_segments = 8
        sm.rings = 4
        eye.mesh = sm
        eye.position = Vector3(1.55, 0.7, z)
        eye.material_override = _mat(Color(0.1, 0.1, 0.12), 0.6)
        _body.add_child(eye)


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = _mat(c, 0.15)
    parent.add_child(mi)
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


func _physics_process(delta: float) -> void:
    var g := 9.8 / ROPE
    _vel.x += (-g * sin(_ang.x) - 0.35 * _vel.x) * delta
    _vel.y += (-g * sin(_ang.y) - 0.35 * _vel.y) * delta
    _ang += _vel * delta
    _pivot.rotation = Vector3(_ang.x, 0.0, _ang.y)
    _punch = maxf(0.0, _punch - delta * 4.0)
    _body.scale = Vector3.ONE * (1.0 + 0.16 * _punch)
    if not _candy.is_empty():
        for c in _candy:
            if is_instance_valid(c) and not c.freeze and c.get_meta("t", 0.0) + delta > 6.0:
                c.freeze = true
            elif is_instance_valid(c):
                c.set_meta("t", c.get_meta("t", 0.0) + delta)


func body_position() -> Vector3:
    return _body.global_position


## A push in world direction `dir` (from a shot); k in rad/s.
func kick(dir: Vector3, k := 1.7) -> void:
    _vel.x -= dir.z * k
    _vel.y += dir.x * k
    _punch = 1.0


func on_shot(_by: Character, pos: Vector3, dir: Vector3, _weapon: WeaponData) -> void:
    if is_burst:
        return
    hits += 1
    kick(dir)
    _hit_effects(pos)
    hit.emit(self, hits)
    if hits >= HITS_TO_BURST:
        do_burst(true)
        burst.emit(self)


func _hit_effects(pos: Vector3) -> void:
    Sfx.play("pinata_hit", pos, 0.0, 0.15)
    var fx := _fx()
    if fx != null:
        fx.confetti(pos, Vector3.UP, 120.0, 20)


## Client mirror of the host's hit count (with the host's kick direction in `dir`).
func apply_hits(new_hits: int, dir: Vector3) -> void:
    if new_hits > hits and not is_burst:
        hits = new_hits
        kick(dir)
        _hit_effects(body_position())


func do_burst(effects: bool) -> void:
    if is_burst:
        return
    is_burst = true
    hits = maxi(hits, HITS_TO_BURST)
    var at := body_position()
    _body.visible = false
    _collider.set_deferred("collision_layer", 0)
    _rope.scale = Vector3(1, ROPE * 0.55, 1)
    _rope.position = Vector3(0, -ROPE * 0.55 * 0.5, 0)
    if effects:
        Sfx.play("pinata_burst", at)
        Sfx.play("cheer", at, -4.0, 0.1)
        var fx := _fx()
        if fx != null:
            fx.confetti(at, Vector3.UP, 110.0, 160)
            fx.confetti(at + Vector3(0, 0.5, 0), Vector3.DOWN, 60.0, 60)
    _spawn_candy(at)


func _spawn_candy(at: Vector3) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    var parent := get_parent()
    for i in CANDY:
        var c := RigidBody3D.new()
        c.collision_layer = Character.LAYER_TARGET
        c.collision_mask = Character.LAYER_WORLD
        c.mass = 0.3
        var shape := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(0.36, 0.36, 0.36)
        shape.shape = bs
        c.add_child(shape)
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.36, 0.36, 0.36)
        mi.mesh = bm
        mi.material_override = _mat(STRIPES[i % STRIPES.size()], 0.5)
        c.add_child(mi)
        c.position = at + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
        c.linear_velocity = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(3.0, 9.0), rng.randf_range(-6.0, 6.0))
        c.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
        c.set_meta("t", 0.0)
        parent.add_child(c)
        _candy.append(c)


func restore() -> void:
    is_burst = false
    hits = 0
    _body.visible = true
    _collider.set_deferred("collision_layer", Character.LAYER_TARGET)
    _rope.scale = Vector3(1, ROPE, 1)
    _rope.position = Vector3(0, -ROPE * 0.5, 0)
    for c in _candy:
        if is_instance_valid(c):
            c.queue_free()
    _candy.clear()
    _ang = Vector2.ZERO
    _vel = Vector2(0.25, 0.15)


func _fx() -> PartyFx:
    var p := get_tree().get_first_node_in_group("party")
    return p.fx if p != null else null
