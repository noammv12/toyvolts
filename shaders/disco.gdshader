shader_type spatial;
render_mode cull_back;

// Dance floor: a grid of tiles that pulse and change colour on the beat (party palette).
uniform float tile = 2.0;
uniform float speed = 1.4;
uniform float glow = 1.3;

varying vec3 wpos;

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 pal(int i) {
    if (i == 0) return vec3(0.98, 0.45, 0.68);
    if (i == 1) return vec3(0.99, 0.80, 0.28);
    if (i == 2) return vec3(0.22, 0.80, 0.78);
    if (i == 3) return vec3(0.72, 0.58, 0.95);
    if (i == 4) return vec3(0.45, 0.72, 0.98);
    return vec3(0.55, 0.92, 0.70);
}

void fragment() {
    vec2 cell = floor(wpos.xz / tile);
    float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
    float beat = floor(TIME * speed + h * 3.0);
    int idx = int(mod(h * 6.0 + beat, 6.0));
    vec3 col = pal(idx);
    float pulse = 0.55 + 0.45 * sin(TIME * speed * 6.2832 + h * 6.2832);
    vec2 g = fract(wpos.xz / tile);
    vec2 d = min(g, 1.0 - g);
    float line = 1.0 - smoothstep(0.02, 0.05, min(d.x, d.y));
    col = mix(col, vec3(0.08, 0.08, 0.1), line);
    ALBEDO = col * 0.45;
    EMISSION = col * pulse * glow * (1.0 - line);
    ROUGHNESS = 0.25;
    METALLIC = 0.0;
}
