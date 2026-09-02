class_name PartyHat
extends RefCounted
## Cone party hat (world scale, ~0.55 m tall) built from primitives: cone, stripe ring,
## pompom, brim. Attached to a figure's head bone by Figure.add_hat(), or to any prop.

const TOON: Shader = preload("res://shaders/toon.gdshader")

static var _mats := {}


static func build(color: Color, height := 0.55) -> Node3D:
    var root := Node3D.new()
    root.name = "PartyHat"
    var accent := PartyText.TEAL if (color.r - PartyText.GOLD.r) * (color.r - PartyText.GOLD.r) + (color.g - PartyText.GOLD.g) * (color.g - PartyText.GOLD.g) + (color.b - PartyText.GOLD.b) * (color.b - PartyText.GOLD.b) < 0.15 else PartyText.GOLD
    var cone := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = 0.2
    cm.height = height
    cm.radial_segments = 16
    cm.rings = 1
    cone.mesh = cm
    cone.position = Vector3(0, height * 0.5, 0)
    cone.material_override = _mat(color)
    cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(cone)
    # stripe: a thin torus where the cone is 45% up
    var stripe := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.2 * 0.55 - 0.012
    tm.outer_radius = 0.2 * 0.55 + 0.02
    tm.rings = 16
    tm.ring_segments = 6
    stripe.mesh = tm
    stripe.position = Vector3(0, height * 0.45, 0)
    stripe.material_override = _mat(accent)
    stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(stripe)
    # pompom
    var pom := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.075
    sm.height = 0.15
    sm.radial_segments = 10
    sm.rings = 5
    pom.mesh = sm
    pom.position = Vector3(0, height + 0.03, 0)
    pom.material_override = _mat(accent)
    pom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(pom)
    # brim
    var brim := MeshInstance3D.new()
    var bm := TorusMesh.new()
    bm.inner_radius = 0.19
    bm.outer_radius = 0.235
    bm.rings = 18
    bm.ring_segments = 6
    brim.mesh = bm
    brim.position = Vector3(0, 0.01, 0)
    brim.material_override = _mat(PartyText.CREAM)
    brim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(brim)
    return root


static func _mat(color: Color) -> ShaderMaterial:
    if _mats.has(color):
        return _mats[color]
    var m := ShaderMaterial.new()
    m.shader = TOON
    m.set_shader_parameter("albedo", color)
    m.set_shader_parameter("spec_strength", 0.45)
    _mats[color] = m
    return m
