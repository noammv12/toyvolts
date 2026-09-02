class_name ToonMat
extends RefCounted
## Re-routes a kit model's StandardMaterial3D surfaces through the toon shader so every
## object in the world shares the same banded look. Returns the created materials.
## With `shared`, identical inputs (texture, colour, tint, spec) reuse one material, so the
## whole map draws with a handful of materials instead of one per surface. Figures must NOT
## share: they animate `flash` / `tint` per character.

const TOON: Shader = preload("res://shaders/toon.gdshader")

static var _shared := {}


static func apply(root: Node, tint := Color.WHITE, tint_mix := 0.0, spec := 0.25, shared := false) -> Array[ShaderMaterial]:
    var mats: Array[ShaderMaterial] = []
    for mi in root.find_children("*", "MeshInstance3D", true, false):
        var mesh: Mesh = mi.mesh
        if mesh == null:
            continue
        for s in mesh.get_surface_count():
            var base := mesh.surface_get_material(s) as BaseMaterial3D
            var tex: Texture2D = base.albedo_texture if base != null else null
            var color: Color = base.albedo_color if base != null else Color.WHITE
            var key := [tex, color, tint, tint_mix, spec]
            var m: ShaderMaterial = _shared.get(key) if shared else null
            if m == null:
                m = ShaderMaterial.new()
                m.shader = TOON
                if tex != null:
                    m.set_shader_parameter("albedo_tex", tex)
                m.set_shader_parameter("albedo", color)
                m.set_shader_parameter("tint", tint)
                m.set_shader_parameter("tint_mix", tint_mix)
                m.set_shader_parameter("spec_strength", spec)
                if shared:
                    _shared[key] = m
            mi.set_surface_override_material(s, m)
            mats.append(m)
    return mats


static func shared_count() -> int:
    return _shared.size()
