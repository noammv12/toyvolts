class_name HealthVial
extends Area3D
## Dropped where a toy falls apart. Anyone hurt who walks over it heals.

const HEAL := 30.0
const LIFETIME := 20.0
const TOON: Shader = preload("res://shaders/toon.gdshader")

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
    Game.trace("vial")
    add_to_group("pickups")
    collision_layer = 0
    collision_mask = Character.LAYER_CHARACTER
    monitoring = true
    monitorable = false

    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.7
    shape.shape = sphere
    add_child(shape)

    var mat := ShaderMaterial.new()
    mat.shader = TOON
    mat.set_shader_parameter("albedo", Color(0.3, 0.9, 0.45))
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.13
    capsule.height = 0.5
    body.mesh = capsule
    body.material_override = mat
    body.position = Vector3(0, 0.35, 0)
    add_child(body)
    var cap_mat := ShaderMaterial.new()
    cap_mat.shader = TOON
    cap_mat.set_shader_parameter("albedo", Color(0.95, 0.95, 0.95))
    var cap := MeshInstance3D.new()
    var cap_mesh := CylinderMesh.new()
    cap_mesh.top_radius = 0.09
    cap_mesh.bottom_radius = 0.09
    cap_mesh.height = 0.1
    cap.mesh = cap_mesh
    cap.material_override = cap_mat
    cap.position = Vector3(0, 0.62, 0)
    add_child(cap)

    body_entered.connect(_on_body_entered)
    get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
    _base_y = position.y


func _process(delta: float) -> void:
    _t += delta
    rotate_y(delta * 2.5)
    position.y = _base_y + sin(_t * 3.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
    var c := body as Character
    if c != null and c.alive and c.hp < c.max_hp:
        c.heal(HEAL)
        Sfx.play("vial_pickup", global_position)
        queue_free()
