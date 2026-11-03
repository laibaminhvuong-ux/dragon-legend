// Anime hair: per-instance colour and glow (transformations make it shine), a soft sheen band that slides with
// the view ("angel ring") and a rim; one material serves every fighter.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

instance uniform vec4 hair_color : source_color = vec4(0.08, 0.07, 0.07, 1.0);
instance uniform float glow = 0.0;

void fragment() {
	vec3 c = hair_color.rgb;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float band = smoothstep(0.55, 0.8, facing) * smoothstep(1.0, 0.85, facing);
	ALBEDO = c * (0.85 + 0.25 * facing);
	ROUGHNESS = 0.45;
	SPECULAR = 0.45;
	float rim = pow(1.0 - facing, 3.0);
	EMISSION = c * glow + c * band * 0.12 + vec3(1.0, 0.97, 0.9) * rim * 0.05;
}
