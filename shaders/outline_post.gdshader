shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, fog_disabled, depth_draw_never;

// Full-screen toon outline: edges from depth discontinuities and normal changes.
// Lines take the local hue (darkened screen colour) so they never look pasted on.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float thickness : hint_range(0.5, 3.0) = 1.0;
uniform float depth_threshold : hint_range(0.001, 0.2) = 0.03;
uniform float normal_threshold : hint_range(0.05, 2.0) = 0.55;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float max_distance = 60.0;

varying mat4 inv_proj;

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
    inv_proj = INV_PROJECTION_MATRIX;
}

float linear_depth(vec2 uv) {
    float d = texture(depth_tex, uv).x;
    vec3 ndc = vec3(uv * 2.0 - 1.0, d);
    vec4 view = inv_proj * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return -view.z;
}

vec3 normal_at(vec2 uv) {
    return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
    vec2 px = thickness / VIEWPORT_SIZE;
    vec2 uv = SCREEN_UV;
    float dc = linear_depth(uv);
    float dl = linear_depth(uv - vec2(px.x, 0.0));
    float dr = linear_depth(uv + vec2(px.x, 0.0));
    float du = linear_depth(uv - vec2(0.0, px.y));
    float dd = linear_depth(uv + vec2(0.0, px.y));
    float depth_diff = max(max(abs(dc - dl), abs(dc - dr)), max(abs(dc - du), abs(dc - dd)));
    float depth_edge = step(depth_threshold * dc, depth_diff);

    vec3 nc = normal_at(uv);
    float ndiff = 0.0;
    ndiff = max(ndiff, 1.0 - dot(nc, normal_at(uv - vec2(px.x, 0.0))));
    ndiff = max(ndiff, 1.0 - dot(nc, normal_at(uv + vec2(px.x, 0.0))));
    ndiff = max(ndiff, 1.0 - dot(nc, normal_at(uv - vec2(0.0, px.y))));
    ndiff = max(ndiff, 1.0 - dot(nc, normal_at(uv + vec2(0.0, px.y))));
    float normal_edge = step(normal_threshold, ndiff);

    float edge = max(depth_edge, normal_edge * 0.7);
    edge *= strength * (1.0 - smoothstep(max_distance * 0.5, max_distance, dc));
    vec3 col = texture(screen_tex, uv).rgb;
    vec3 line = col * 0.18;
    ALBEDO = mix(col, line, edge);
}
