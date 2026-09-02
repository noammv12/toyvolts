class_name BatteryBase
extends Area3D
## A team's charging pad. A carrier of that team who steps on it scores.

signal charged(base: BatteryBase, by: Character)

const TOON: Shader = preload("res://shaders/toon.gdshader")

@export var team := 1
var _t := 0.0
var _ring: MeshInstance3D
var _pulse := 0.0


func _ready() -> void:
    add_to_group("battery_bases")
    collision_layer = 0
    collision_mask = Character.LAYER_CHARACTER
    monitoring = true
    monitorable = false
    var shape := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.radius = 2.4
    cyl.height = 3.0
    shape.shape = cyl
    shape.position = Vector3(0, 1.5, 0)
    add_child(shape)
    _build_visual()
    body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
    _t += delta
    _pulse = maxf(0.0, _pulse - delta * 2.0)
    if _ring:
        _ring.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 2.0) + _pulse * 0.5)


func _on_body_entered(body: Node3D) -> void:
    var c := body as Character
    if c == null or not c.alive or c.carrying == null or c.team != team or not Game.match_active:
        return
    if not Net.is_authority():
        return
    _pulse = 1.0
    charged.emit.call_deferred(self, c)   # the match controller reparents the cell: not inside a physics callback


func _build_visual() -> void:
    var color: Color = ArenaBase.TEAM_COLORS.get(team, Color.WHITE)
    var pad := MeshInstance3D.new()
    var pad_mesh := CylinderMesh.new()
    pad_mesh.top_radius = 2.4
    pad_mesh.bottom_radius = 2.6
    pad_mesh.height = 0.25
    pad.mesh = pad_mesh
    pad.position = Vector3(0, 0.125, 0)
    var pm := ShaderMaterial.new()
    pm.shader = TOON
    pm.set_shader_parameter("albedo", color.darkened(0.35))
    pad.material_override = pm
    add_child(pad)
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var cshape := CylinderShape3D.new()
    cshape.radius = 2.5
    cshape.height = 0.25
    cs.shape = cshape
    cs.position = Vector3(0, 0.125, 0)
    body.add_child(cs)
    body.collision_layer = Character.LAYER_WORLD
    add_child(body)
    _ring = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 2.0
    torus.outer_radius = 2.35
    torus.rings = 32
    torus.ring_segments = 8
    _ring.mesh = torus
    _ring.position = Vector3(0, 0.27, 0)
    _ring.scale = Vector3(1, 0.3, 1)
    var rm := StandardMaterial3D.new()
    rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rm.albedo_color = color
    rm.emission_enabled = true
    rm.emission = color
    rm.emission_energy_multiplier = 2.2
    _ring.material_override = rm
    _ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_ring)
    var beam := MeshInstance3D.new()
    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.9
    beam_mesh.bottom_radius = 2.0
    beam_mesh.height = 11.0
    beam_mesh.radial_segments = 16
    beam.mesh = beam_mesh
    beam.position = Vector3(0, 5.6, 0)
    var bm := StandardMaterial3D.new()
    bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    bm.albedo_color = Color(color, 0.12)
    bm.cull_mode = BaseMaterial3D.CULL_DISABLED
    beam.material_override = bm
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(beam)
    var light := OmniLight3D.new()
    light.light_color = color
    light.light_energy = 2.5
    light.omni_range = 9.0
    light.position = Vector3(0, 2.0, 0)
    add_child(light)
    var label := Label3D.new()
    label.text = "CHARGE"
    label.font_size = 120
    label.pixel_size = 0.012
    label.modulate = Color(color, 0.9)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = Vector3(0, 3.6, 0)
    add_child(label)
