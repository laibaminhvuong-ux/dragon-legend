// Water: colour deepens with depth below the surface (depth texture), two scrolling wave normals,
// fresnel-weighted sky reflection via low roughness, and a foam line where the water meets the shore.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.62, 0.66, 1.0);
uniform float clarity = 4.0;     // metres until the water is fully deep-coloured
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	return vnoise(p * 0.35 + vec2(t * 0.05, t * 0.03)) * 0.6 + vnoise(p * 1.1 - vec2(t * 0.09, -t * 0.07)) * 0.4;
}

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float e = 0.15, t = TIME;
	float h = waves(wpos.xz, t);
	vec3 n = normalize(vec3(h - waves(wpos.xz + vec2(e, 0), t), e * 1.5, h - waves(wpos.xz + vec2(0, e), t)));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 world_floor = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	world_floor.xyz /= world_floor.w;
	float depth = clamp(-world_floor.z - (-VERTEX.z), 0.0, 100.0);
	float k = clamp(depth / clarity, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, k);
	float foam = smoothstep(0.6, 0.0, depth) * step(0.45, vnoise(wpos.xz * 2.0 + t * 0.3));
	ALBEDO = mix(col, vec3(0.95), foam * 0.8);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(0.55 + k * 0.4 + foam, 0.0, 0.97);
}
