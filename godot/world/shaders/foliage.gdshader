// Tree foliage: leaf colour with world-space variation, gentle wind sway that grows with height, light passing
// through leaves (backlight), darker inside the canopy (vertex AO via normal facing). `glow` lights crystals.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 leaf_color : source_color = vec4(0.24, 0.45, 0.16, 1.0);
uniform float glow = 0.0;
uniform float wind = 0.08;

varying float var_shade;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.4 + world.x * 0.3 + world.z * 0.2) * wind * max(VERTEX.y - 1.0, 0.0) * 0.15;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	var_shade = 0.55 + 0.45 * clamp(dot(NORMAL, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5, 0.0, 1.0);
}

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = hash(floor(world * 1.7));
	vec3 col = leaf_color.rgb * mix(0.82, 1.15, n) * var_shade;
	ALBEDO = col;
	ROUGHNESS = 0.8;
	BACKLIGHT = col * 0.5;
	EMISSION = leaf_color.rgb * glow;
}
