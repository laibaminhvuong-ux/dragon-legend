// Water: colour deepens with depth below the surface (depth texture), two smooth wave normal maps scrolling
// against each other, fresnel-weighted sky reflection via low roughness, and soft foam where it meets the shore.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.62, 0.66, 1.0);
uniform float clarity = 4.0;     // metres until the water is fully deep-coloured
uniform sampler2D wave_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float t = TIME;
	vec3 na = texture(wave_a, wpos.xz * 0.045 + vec2(t * 0.012, t * 0.008)).rgb;
	vec3 nb = texture(wave_b, wpos.xz * 0.11 - vec2(t * 0.02, -t * 0.015)).rgb;
	NORMAL_MAP = normalize(na + nb - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 world_floor = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	world_floor.xyz /= world_floor.w;
	float depth = clamp(-world_floor.z - (-VERTEX.z), 0.0, 100.0);
	float k = clamp(depth / clarity, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, k);
	float n = texture(foam_noise, wpos.xz * 0.15 + vec2(t * 0.03, 0.0)).r;
	float foam = smoothstep(0.7, 0.0, depth) * smoothstep(0.35, 0.65, n);
	ALBEDO = mix(col, vec3(0.95), foam * 0.85);
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	ALPHA = clamp(0.6 + k * 0.38 + foam, 0.0, 0.98);
}
