shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Banded toon lighting + rim + hard specular. Outline is a separate inverted-hull pass (art milestone).
uniform vec4 albedo : source_color = vec4(0.9, 0.55, 0.25, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float bands : hint_range(1.0, 6.0) = 3.0;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.42;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;
uniform float spec_size : hint_range(0.0, 1.0) = 0.08;
uniform float spec_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool grid = false;
uniform float grid_size = 2.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;   // hit / spawn-protection whiteout
uniform vec4 tint : source_color = vec4(1.0);        // team colour wash
uniform float tint_mix : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 col = albedo.rgb * texture(albedo_tex, UV).rgb;
    if (grid) {
        vec2 g = fract(world_pos.xz / grid_size);
        vec2 d = min(g, 1.0 - g);
        float line = 1.0 - step(0.012, min(d.x, d.y));
        col *= mix(1.0, 0.88, line);
    }
    col = mix(col, col * tint.rgb * 1.7, tint_mix);
    ALBEDO = mix(col, vec3(1.0), flash);
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    SPECULAR = 0.0;
}

void light() {
    float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
    float stepped = floor(ndl * bands + 0.5) / bands;
    float shade = mix(shade_floor, 1.0, stepped);
    // LIGHT_COLOR already carries energy * PI; divide back to keep standard brightness.
    vec3 light = ATTENUATION * LIGHT_COLOR / PI;
    DIFFUSE_LIGHT += shade * light;

    float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float rim_mask = step(1.0 - rim_width, rim) * stepped;
    DIFFUSE_LIGHT += rim_mask * rim_strength * light;

    vec3 h = normalize(VIEW + LIGHT);
    float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 48.0);
    SPECULAR_LIGHT += step(1.0 - spec_size, spec) * spec_strength * light;
}
