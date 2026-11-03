// Grass blades: dark roots to sunlit tips, per-clump colour variation (INSTANCE_CUSTOM), wind gusts that travel
// across the field, light passing through blades (backlight), and blades that shrink to nothing near the
// streaming radius so chunks never pop.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 root_color : source_color = vec4(0.18, 0.32, 0.09, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.80, 0.32, 1.0);
uniform vec4 dry_color : source_color = vec4(0.62, 0.62, 0.30, 1.0);
uniform vec4 forest_color : source_color = vec4(0.16, 0.30, 0.10, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float wind_strength = 0.16;
uniform float fade_end = 80.0;

varying float var_dry;
varying float var_forest;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = UV.y;
	float gust = sin(world.x * 0.07 + TIME * 1.3) * 0.5 + sin(world.z * 0.05 - TIME * 0.9) * 0.5;
	float flutter = sin(TIME * 4.0 + INSTANCE_CUSTOM.r * 30.0) * 0.25;
	VERTEX.x += (gust + flutter) * wind_strength * h * h;
	VERTEX.z += (gust * 0.6) * wind_strength * h * h;
	float d = distance(origin, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	float keep = 1.0 - smoothstep(fade_end * 0.65, fade_end, d);
	VERTEX *= vec3(1.0, keep, 1.0);
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
