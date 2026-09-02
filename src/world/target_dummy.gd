class_name TargetDummy
extends Character
## Stationary practice target with a floating HP label. Respawns where it stood.

var _label: Label3D


func _ready() -> void:
    respawn_at_home = true
    super()
    _label = Label3D.new()
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.font_size = 64
    _label.pixel_size = 0.004
    _label.outline_size = 16
    _label.position = Vector3(0, 2.05, 0)
    _label.text = "%d" % hp
    add_child(_label)
    health_changed.connect(_on_health)


func _on_health(new_hp: float, _max_hp: float) -> void:
    _label.text = "%d" % new_hp
