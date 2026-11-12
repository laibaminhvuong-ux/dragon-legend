// Scanned leafy models (bushes, shrubs) swaying in the world wind (WorldWind globals): the model's own albedo /
// normal textures with an alpha cut-out, bent along the wind more towards the top of the model (height above its
// bottom, `bottom`/`height` in model units), each instance on its own phase, leaves fluttering on top.
// Any other code may use it for a leafy textured mesh: set albedo_tex (+ normal_tex, alpha_cut, height, bottom).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, world_vertex_coords;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_normal = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = 0.5;
uniform float height = 1.0;    // model-space height of the mesh
uniform float bottom = 0.0;    // model-space y of its lowest point
uniform float sway = 1.0;
global uniform vec4 wind_field;   // xy direction (world x, z), z strength, w gustiness
global uniform float wind_time;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[1].xyz);
	float model_y = (VERTEX.y - origin.y) / max(scale, 0.0001);
	float h = clamp((model_y - bottom) / height, 0.0, 1.2);
	vec2 wd = wind_field.xy;
	float ws = wind_field.z * sway;
	float phase = dot(origin.xz, vec2(0.53, 0.29));
	float band = sin(dot(origin.xz, wd) * 0.06 - wind_time * 1.3) * 0.5 + 0.5;
	float lean = 0.3 + wind_field.w * band * 0.7;
	float rock = sin(wind_time * 1.9 + phase) * 0.35;
	vec3 push = vec3(wd.x, 0.0, wd.y) * (lean + rock) + vec3(-wd.y, 0.0, wd.x) * sin(wind_time * 2.4 + phase) * 0.2;
	vec3 leaves = vec3(sin(wind_time * 6.3 + dot(VERTEX, vec3(3.1, 2.3, 2.7))), 0.0, cos(wind_time * 5.7 + dot(VERTEX, vec3(2.3, 3.7, 1.9)))) * 0.05;
	VERTEX += (push * 0.16 * h * h + leaves * h) * scale * height * ws;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	ALBEDO = c.rgb;
	if (alpha_cut > 0.0) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	BACKLIGHT = c.rgb * 0.35;
}
