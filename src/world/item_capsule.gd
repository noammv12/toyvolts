class_name ItemCapsule
extends Area3D
## Microvolts item match: gacha capsules on fixed map points. "health" heals 35, "ammo" tops
## up every weapon's reserve. Vanishes on pickup and pops back after RESPAWN seconds.

const RESPAWN := 20.0
const HEAL := 35.0
const TOON: Shader = preload("res://shaders/toon.gdshader")

@export var kind := "health"   ## health | ammo
var net_index := 0             ## index in the map's capsule list (same order on every peer)
var _t := 0.0
var _respawn_left := 0.0
var _visual: Node3D


func _ready() -> void:
    add_to_group("capsules")
    add_to_group("pickups" if kind == "health" else "ammo_pickups")
    collision_layer = 0
    collision_mask = Character.LAYER_CHARACTER
    monitoring = true
    monitorable = false
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.8
    shape.shape = sphere
    add_child(shape)
    _build_visual()
    body_entered.connect(_on_body_entered)


func is_available() -> bool:
    return _respawn_left <= 0.0


func _process(delta: float) -> void:
    _t += delta
    if _respawn_left > 0.0:
        if Net.is_authority():
            _respawn_left -= delta
            if _respawn_left <= 0.0:
                _show(true)
                Net.capsule_changed(self)
        return
    _visual.rotation.y += delta * 1.8
    _visual.position.y = 0.6 + sin(_t * 2.8) * 0.07


func _on_body_entered(body: Node3D) -> void:
    var c := body as Character
    if c == null or not c.alive or _respawn_left > 0.0 or c is TargetDummy or not Net.is_authority():
        return
    if kind == "health":
        if c.hp >= c.max_hp:
            return
        c.heal(HEAL)
    else:
        if not c.arsenal.top_up_reserves(0.34):
            return
    Sfx.play("vial_pickup", global_position, 0.0 if kind == "health" else -3.0)
    Vfx.jump_puff(global_position + Vector3(0, 0.2, 0))
    _respawn_left = RESPAWN
    _show(false)
    Net.capsule_changed(self)


## Client: mirror the server (a hidden capsule waits for the server's "back" event).
func set_available_remote(on: bool) -> void:
    if on == is_available():
        return
    _respawn_left = 0.0 if on else RESPAWN
    _show(on)
    if not on:
        Sfx.play("vial_pickup", global_position, 0.0 if kind == "health" else -3.0)


func _show(on: bool) -> void:
    _visual.visible = on
    set_deferred("monitoring", on)
    if on:
        Vfx.jump_puff(global_position + Vector3(0, 0.2, 0))


func _build_visual() -> void:
    _visual = Node3D.new()
    add_child(_visual)
    var top_color := Color(0.35, 0.9, 0.45) if kind == "health" else Color(0.3, 0.6, 0.98)
    var top := MeshInstance3D.new()
    var top_mesh := SphereMesh.new()
    top_mesh.radius = 0.42
    top_mesh.height = 0.42
    top_mesh.is_hemisphere = true
    top.mesh = top_mesh
    top.material_override = _mat(top_color, 0.5)
    _visual.add_child(top)
    var bottom := MeshInstance3D.new()
    var bottom_mesh := SphereMesh.new()
    bottom_mesh.radius = 0.42
    bottom_mesh.height = 0.42
    bottom_mesh.is_hemisphere = true
    bottom.mesh = bottom_mesh
    bottom.rotation.x = PI
    bottom.material_override = _mat(Color(0.96, 0.96, 0.94), 0.5)
    _visual.add_child(bottom)
    var seam := MeshInstance3D.new()
    var seam_mesh := CylinderMesh.new()
    seam_mesh.top_radius = 0.43
    seam_mesh.bottom_radius = 0.43
    seam_mesh.height = 0.05
    seam.mesh = seam_mesh
    seam.material_override = _mat(Color(0.2, 0.2, 0.24), 0.2)
    _visual.add_child(seam)
    var icon := Label3D.new()
    icon.text = "+" if kind == "health" else "AMMO"
    icon.font_size = 140 if kind == "health" else 64
    icon.pixel_size = 0.0035
    icon.modulate = Color(1, 1, 1, 0.95)
    icon.position = Vector3(0, 0.2, 0.35)
    icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _visual.add_child(icon)


func _mat(color: Color, spec: float) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("spec_strength", spec)
    return m
