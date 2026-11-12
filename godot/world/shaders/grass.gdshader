// Grass blades: dark roots to sunlit tips, per-clump colour variation (INSTANCE_CUSTOM), the world wind (WorldWind
// globals) bending them with gusts that travel across the field, light passing through blades (backlight), and blades that shrink to nothing near the
// streaming radius so chunks never pop.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform vec4 root_color : source_color = vec4(0.18, 0.32, 0.09, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.80, 0.32, 1.0);
uniform vec4 dry_color : source_color = vec4(0.62, 0.62, 0.30, 1.0);
uniform vec4 forest_color : source_color = vec4(0.16, 0.30, 0.10, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float wind_strength = 0.16;   // how far a blade tip leans in a strength-1 wind (metres, roughly)
global uniform vec4 wind_field;   // WorldWind: xy direction (world x, z), z strength, w gustiness
global uniform float wind_time;
uniform float fade_end = 80.0;

varying float var_dry;
varying float var_forest;

void vertex() {
	// world_vertex_coords: VERTEX is already in world space, so the wind can push along its world direction whatever
	// the clump's random rotation. Blades bend more towards the tip (UV.y squared); gust bands roll across the field
	// along the wind, and each clump flutters on its own phase (INSTANCE_CUSTOM.r).
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = UV.y;
	vec2 wd = wind_field.xy;
	float ws = wind_field.z;
	float band = sin(dot(origin.xz, wd) * 0.09 - wind_time * 1.7) * 0.5 + 0.5;
	float swell = 0.55 + wind_field.w * (band * 0.9 - 0.25);
	float phase = INSTANCE_CUSTOM.r * 30.0;
	float flutter = sin(wind_time * (3.2 + ws * 1.6) + phase) * (0.35 + 0.25 * ws);
	float side = sin(wind_time * 2.3 + phase * 1.7) * 0.25;
	vec3 push = vec3(wd.x, 0.0, wd.y) * (swell + flutter * 0.45) + vec3(-wd.y, 0.0, wd.x) * side * 0.5;
	vec3 bend = push * ws * wind_strength * 2.2 * h * h;
	VERTEX += bend;
	VERTEX.y -= dot(bend, bend) * 1.5;   // a bent blade gets shorter, not longer
	float d = distance(origin, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	float keep = 1.0 - smoothstep(fade_end * 0.65, fade_end, d);
	VERTEX.y = origin.y + (VERTEX.y - origin.y) * keep;
	var_dry = INSTANCE_CUSTOM.b;
	var_forest = INSTANCE_CUSTOM.g;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
}

void fragment() {
	vec3 tip = mix(tip_color.rgb, dry_color.rgb, smoothstep(0.75, 1.0, var_dry) * 0.6);
	tip = mix(tip, forest_color.rgb, var_forest * 0.7);
	vec3 col = mix(root_color.rgb, tip, pow(UV.y, 0.8)) * tint.rgb;
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.6;
	AO = mix(0.35, 1.0, UV.y);
	AO_LIGHT_AFFECT = 0.6;
}
