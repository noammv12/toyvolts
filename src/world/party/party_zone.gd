class_name PartyZone
extends Area3D
## A volume that changes how toys move while inside: the bouncy castle (super jump + auto
## bounce on landing), the moon corner (low gravity) and the slide (downhill push). Purely
## local: the zone exists on every peer, so prediction and the host agree.

enum Kind { BOUNCE, MOON, SLIDE }

var kind := Kind.MOON
var push := Vector3.ZERO      ## SLIDE: acceleration applied while inside


func _ready() -> void:
    add_to_group("party_zones")
    collision_layer = 0
    collision_mask = Character.LAYER_CHARACTER
    monitoring = true
    monitorable = false
    body_entered.connect(_on_enter)
    body_exited.connect(_on_exit)


func set_box(size: Vector3, offset := Vector3.ZERO, rot := Vector3.ZERO) -> void:
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position = offset
    shape.rotation = rot
    add_child(shape)


func set_cylinder(radius: float, height: float, offset := Vector3.ZERO) -> void:
    var shape := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.radius = radius
    cyl.height = height
    shape.shape = cyl
    shape.position = offset
    add_child(shape)


func _on_enter(body: Node3D) -> void:
    var c := body as Character
    if c != null:
        c.enter_zone(self)


func _on_exit(body: Node3D) -> void:
    var c := body as Character
    if c != null:
        c.exit_zone(self)
