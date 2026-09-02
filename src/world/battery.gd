class_name Battery
extends Area3D
## Capture the Battery objective: a chunky toy AA cell. Lies at a spawn point (or where a
## carrier died), rides on a carrier's back, and is charged at a team base. Dropped batteries
## crawl back home after RETURN_AFTER seconds.

signal picked_up(battery: Battery, by: Character)
signal dropped(battery: Battery, at: Vector3)

const RETURN_AFTER := 20.0
const TOON: Shader = preload("res://shaders/toon.gdshader")

var home := Vector3.ZERO
var carrier: Character = null
var net_index := 0            ## index in the map's battery list (same order on every peer)
var _t := 0.0
var _dropped_left := -1.0
var _visual: Node3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _arena: Node


func _ready() -> void:
    add_to_group("batteries")
    collision_layer = 0
    collision_mask = Character.LAYER_CHARACTER
    monitoring = true
    monitorable = false
    _arena = get_parent()
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.9
    shape.shape = sphere
    add_child(shape)
    _build_visual()
    body_entered.connect(_on_body_entered)


func is_loose() -> bool:
    return carrier == null


func _process(delta: float) -> void:
    _t += delta
    if carrier == null:
        _visual.rotation.y += delta * 1.6
        _visual.position.y = 0.55 + sin(_t * 2.5) * 0.08
        if _dropped_left > 0.0 and Net.is_authority():
            _dropped_left -= delta
            if _dropped_left <= 0.0:
                return_home()
    if _beam:
        _beam.transparency = 0.55 + 0.15 * sin(_t * 3.0)


func _on_body_entered(body: Node3D) -> void:
    var c := body as Character
    if c == null or not c.alive or carrier != null or c.carrying != null or c is TargetDummy:
        return
    if not Game.match_active or not Net.is_authority():
        return
    pick_up.call_deferred(c)   # reparenting a CollisionObject inside a physics callback is not allowed


func pick_up(c: Character) -> void:
    if carrier != null or c.carrying != null or not c.alive:
        return
    carrier = c
    c.carrying = self
    _dropped_left = -1.0
    set_deferred("monitoring", false)
    reparent(c.battery_mount, false)
    position = Vector3.ZERO
    rotation = Vector3.ZERO
    _visual.position = Vector3.ZERO
    _visual.rotation = Vector3(deg_to_rad(-100.0), 0.0, 0.0)   # slung across the back
    _visual.scale = Vector3.ONE * 0.75
    _beam.visible = false
    _light.visible = false
    Sfx.play("vial_pickup", global_position, 2.0)
    Net.battery_changed(self)
    picked_up.emit(self, c)


## Carrier died (or scored): back on the floor at `at`.
func drop(at: Vector3) -> void:
    var c := carrier
    carrier = null
    if c != null:
        c.carrying = null
    reparent(_arena, false)
    global_position = at
    rotation = Vector3.ZERO
    _visual.rotation = Vector3.ZERO
    _visual.scale = Vector3.ONE
    _beam.visible = true
    _light.visible = true
    _dropped_left = RETURN_AFTER if at.distance_to(home) > 1.0 else -1.0
    set_deferred("monitoring", true)
    Net.battery_changed(self)
    dropped.emit(self, at)


## Client: mirror the server's state (carried by `by`, or loose at `at`).
func apply_remote(carried: bool, by: Character, at: Vector3) -> void:
    if carried and by != null:
        if carrier == by:
            return
        if carrier != null:
            drop(at)
        pick_up(by)
    else:
        if carrier == null and global_position.distance_to(at) < 0.05:
            return
        drop(at)
        _dropped_left = -1.0


func return_home() -> void:
    drop(home)
    _dropped_left = -1.0
    Vfx.jump_puff(home + Vector3(0, 0.2, 0))


# ---- visual --------------------------------------------------------------------

func _build_visual() -> void:
    _visual = Node3D.new()
    add_child(_visual)
    var body := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.32
    cyl.bottom_radius = 0.32
    cyl.height = 1.05
    body.mesh = cyl
    body.material_override = _mat(Color(0.16, 0.18, 0.22))
    _visual.add_child(body)
    # coloured label band
    var band := MeshInstance3D.new()
    var band_mesh := CylinderMesh.new()
    band_mesh.top_radius = 0.335
    band_mesh.bottom_radius = 0.335
    band_mesh.height = 0.62
    band.mesh = band_mesh
    band.position = Vector3(0, -0.05, 0)
    band.material_override = _mat(Color(0.98, 0.78, 0.15))
    _visual.add_child(band)
    var stripe := MeshInstance3D.new()
    var stripe_mesh := CylinderMesh.new()
    stripe_mesh.top_radius = 0.34
    stripe_mesh.bottom_radius = 0.34
    stripe_mesh.height = 0.1
    stripe.mesh = stripe_mesh
    stripe.position = Vector3(0, 0.34, 0)
    stripe.material_override = _mat(Color(0.95, 0.3, 0.2))
    _visual.add_child(stripe)
    # positive nub
    var nub := MeshInstance3D.new()
    var nub_mesh := CylinderMesh.new()
    nub_mesh.top_radius = 0.11
    nub_mesh.bottom_radius = 0.11
    nub_mesh.height = 0.14
    nub.mesh = nub_mesh
    nub.position = Vector3(0, 0.59, 0)
    nub.material_override = _mat(Color(0.8, 0.82, 0.86))
    _visual.add_child(nub)
    var plus := Label3D.new()
    plus.text = "+"
    plus.font_size = 160
    plus.pixel_size = 0.004
    plus.modulate = Color(0.12, 0.12, 0.14)
    plus.position = Vector3(0, 0.2, 0.345)
    plus.no_depth_test = false
    plus.double_sided = false
    _visual.add_child(plus)
    var bolt := Label3D.new()
    bolt.text = "ToyVolt"
    bolt.font_size = 90
    bolt.pixel_size = 0.0032
    bolt.modulate = Color(0.12, 0.12, 0.14)
    bolt.position = Vector3(0, -0.12, 0.345)
    bolt.double_sided = false
    _visual.add_child(bolt)
    # locator beam + light so the objective reads across the room
    _beam = MeshInstance3D.new()
    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.12
    beam_mesh.bottom_radius = 0.5
    beam_mesh.height = 9.0
    beam_mesh.radial_segments = 12
    _beam.mesh = beam_mesh
    _beam.position = Vector3(0, 4.5, 0)
    var bm := StandardMaterial3D.new()
    bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    bm.albedo_color = Color(1.0, 0.85, 0.3, 0.35)
    bm.cull_mode = BaseMaterial3D.CULL_DISABLED
    _beam.material_override = bm
    _beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_beam)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.85, 0.3)
    _light.light_energy = 2.0
    _light.omni_range = 6.0
    _light.position = Vector3(0, 1.2, 0)
    add_child(_light)


func _mat(color: Color) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("spec_strength", 0.45)
    return m
