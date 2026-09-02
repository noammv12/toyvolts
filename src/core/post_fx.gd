class_name PostFx
extends MeshInstance3D
## Full-screen quad that applies the toon outline shader. Attach as a child of a Camera3D.
## The Low preset uses the depth-only variant (no normal-roughness buffer read).

const OUTLINE: Shader = preload("res://shaders/outline_post.gdshader")
const OUTLINE_DEPTH: Shader = preload("res://shaders/outline_depth.gdshader")


func _ready() -> void:
    add_to_group("post_fx")
    var quad := QuadMesh.new()
    quad.size = Vector2(2, 2)
    quad.flip_faces = true
    mesh = quad
    extra_cull_margin = 16384.0
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    position = Vector3(0, 0, -0.5)
    refresh()


## Re-pick the shader for the current quality preset.
func refresh() -> void:
    var full: bool = Game.quality == "none" or Quality.preset(Game.quality).outline_normals
    var wanted := OUTLINE if full else OUTLINE_DEPTH
    var m := material_override as ShaderMaterial
    if m != null and m.shader == wanted:
        return
    m = ShaderMaterial.new()
    m.shader = wanted
    # Screen-reading materials live in the transparent pass; draw this FIRST there so sprites,
    # glow streaks and smoke (all transparent) are composited on top of the outlined image.
    m.render_priority = -128
    material_override = m
