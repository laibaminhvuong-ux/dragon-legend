// Ultra Intuition Energy Avatar (user request 2026-11-06: "the avatar looks terrible"): a giant see-through copy of
// the fighter made of silver-blue energy. Bright rim at the silhouette, a faint glassy body, flowing bands of light
// rising through it and a soft flicker; additive, so it glows over the scene without hiding it.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform vec4 energy_color : source_color = vec4(0.62, 0.82, 1.0, 1.0);
instance uniform vec4 core_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
instance uniform float strength = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	float flow = noise(world_pos * vec3(0.7, 0.35, 0.7) - vec3(0.0, TIME * 1.6, 0.0));
	float bands = smoothstep(0.55, 0.85, flow) * 0.55;
	float flicker = 0.92 + 0.08 * sin(TIME * 9.0 + world_pos.y * 2.0);
	vec3 body = energy_color.rgb * (0.10 + bands * 0.6);
	vec3 edge = mix(energy_color.rgb, core_color.rgb, smoothstep(0.55, 0.95, rim)) * rim * 1.6;
	float near_cam = smoothstep(0.8, 3.5, -VERTEX.z);   // fades out close to the camera: never blocks the view of the fighter
	ALBEDO = (body + edge) * strength * flicker * near_cam;
}
