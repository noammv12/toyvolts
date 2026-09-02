class_name PostFx
extends MeshInstance3D
## Full-screen quad that applies the toon outline shader. Attach as a child of a Camera3D.

const OUTLINE: Shader = preload("res://shaders/outline_post.gdshader")


func _ready() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2(2, 2)
    quad.flip_faces = true
    mesh = quad
    extra_cull_margin = 16384.0
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var m := ShaderMaterial.new()
    m.shader = OUTLINE
    m.render_priority = 100
    material_override = m
    position = Vector3(0, 0, -0.5)
