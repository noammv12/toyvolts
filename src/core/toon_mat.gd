class_name ToonMat
extends RefCounted
## Re-routes a kit model's StandardMaterial3D surfaces through the toon shader so every
## object in the world shares the same banded look. Returns the created materials.

const TOON: Shader = preload("res://shaders/toon.gdshader")


static func apply(root: Node, tint := Color.WHITE, tint_mix := 0.0, spec := 0.25) -> Array[ShaderMaterial]:
    var mats: Array[ShaderMaterial] = []
    for mi in root.find_children("*", "MeshInstance3D", true, false):
        var mesh: Mesh = mi.mesh
        if mesh == null:
            continue
        for s in mesh.get_surface_count():
            var base := mesh.surface_get_material(s) as BaseMaterial3D
            var m := ShaderMaterial.new()
            m.shader = TOON
            if base != null:
                if base.albedo_texture != null:
                    m.set_shader_parameter("albedo_tex", base.albedo_texture)
                m.set_shader_parameter("albedo", base.albedo_color)
            m.set_shader_parameter("tint", tint)
            m.set_shader_parameter("tint_mix", tint_mix)
            m.set_shader_parameter("spec_strength", spec)
            mi.set_surface_override_material(s, m)
            mats.append(m)
    return mats
