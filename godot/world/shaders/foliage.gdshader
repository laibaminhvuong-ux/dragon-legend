// Tree foliage: leaf colour with world-space variation, sway in the world wind (WorldWind globals) that grows with
// height above the tree's root (or along a palm frond: vertex COLOR.b = 1 marks an explicit flex in COLOR.g, 0 at
// the trunk, 1 at the tip), each tree on its own phase, leaves fluttering on top; light passing through leaves
// (backlight), darker inside the canopy (vertex AO via normal facing). `glow` lights crystals; `sway` scales the
// motion per material (0 = rigid, e.g. crystals).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, world_vertex_coords;

uniform vec4 leaf_color : source_color = vec4(0.24, 0.45, 0.16, 1.0);
uniform float glow = 0.0;
uniform float sway = 1.0;
global uniform vec4 wind_field;   // xy direction the wind blows to (world x, z), z strength, w gustiness
global uniform float wind_time;

varying float var_shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;   // the tree's root (MultiMesh: this instance)
	float scale = length(MODEL_MATRIX[0].xyz);
	float flex;
	if (COLOR.b > 0.5) {
		flex = COLOR.g * 0.9;   // palm frond: free at the tip
		VERTEX.y += sin(wind_time * 3.1 + dot(MODEL_MATRIX[3].xz, vec2(0.7, 0.3)) + COLOR.r * 6.28) * COLOR.g * COLOR.g * 0.12 * wind_field.z * sway * length(MODEL_MATRIX[0].xyz);   // and flaps
	} else {
		float hr = max(VERTEX.y - origin.y - 1.0 * scale, 0.0) / max(scale, 0.01);
		flex = min(hr * hr * 0.012, 0.8);   // giant trees: the crown sways, it does not swing metres
	}
	vec2 wd = wind_field.xy;
	float ws = wind_field.z * sway;
	float phase = dot(origin.xz, vec2(0.37, 0.61));
	float band = sin(dot(origin.xz, wd) * 0.035 - wind_time * 0.9) * 0.5 + 0.5;
	float lean = 0.35 + wind_field.w * band * 0.6;
	float rock = sin(wind_time * 1.25 + phase) * 0.3 + sin(wind_time * 2.7 + phase * 1.9) * 0.12;
	vec3 push = vec3(wd.x, 0.0, wd.y) * (lean + rock) + vec3(-wd.y, 0.0, wd.x) * sin(wind_time * 1.6 + phase * 1.3) * 0.15;
	vec3 leaves = vec3(sin(wind_time * 5.5 + dot(VERTEX, vec3(1.7, 2.3, 1.1))), 0.0, cos(wind_time * 6.1 + dot(VERTEX, vec3(2.1, 1.3, 1.9)))) * 0.04;
	VERTEX += (push * flex * scale + leaves * min(flex, 1.0) * scale) * ws;
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
