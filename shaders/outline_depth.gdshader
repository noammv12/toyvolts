shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, fog_disabled, depth_draw_never;

// Low-preset toon outline: depth edges only. Skips the normal-roughness buffer read so the
// renderer does not have to write it in the depth prepass.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float thickness : hint_range(0.5, 3.0) = 1.0;
uniform float depth_threshold : hint_range(0.001, 0.2) = 0.03;
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

void fragment() {
    vec2 px = thickness / VIEWPORT_SIZE;
    vec2 uv = SCREEN_UV;
    float dc = linear_depth(uv);
    float dl = linear_depth(uv - vec2(px.x, 0.0));
    float dr = linear_depth(uv + vec2(px.x, 0.0));
    float du = linear_depth(uv - vec2(0.0, px.y));
    float dd = linear_depth(uv + vec2(0.0, px.y));
    float depth_diff = max(max(abs(dc - dl), abs(dc - dr)), max(abs(dc - du), abs(dc - dd)));
    float edge = step(depth_threshold * dc, depth_diff);
    edge *= strength * (1.0 - smoothstep(max_distance * 0.5, max_distance, dc));
    vec3 col = texture(screen_tex, uv).rgb;
    ALBEDO = mix(col, col * 0.18, edge);
}
