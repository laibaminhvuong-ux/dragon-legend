// Anime hair (preview, user request 2026-11-06): painted in three flat tones from the angle to a fixed key light
// above and in front (the classic cel trick, readable in any scene), plus a crisp sheen band and rim. The per-
// instance colour and glow work like hair.gdshader (transformations make it shine).
shader_type spatial;
render_mode cull_disabled, unshaded;

#include "res://characters/shaders/hair_motion.gdshaderinc"   // first instance uniform: hair_sway (secondary motion)

instance uniform vec4 hair_color : source_color = vec4(0.08, 0.07, 0.07, 1.0);
instance uniform float glow = 0.0;

void vertex() {
	VERTEX = hair_motion(VERTEX);
}

void fragment() {
	vec3 c = hair_color.rgb;
	vec3 key = normalize((VIEW_MATRIX * vec4(0.35, 0.85, 0.4, 0.0)).xyz);   // world-space key light
	float k = dot(NORMAL, key);
	float tone = 0.42 + 0.33 * step(-0.1, k) + 0.33 * step(0.45, k);   // shadow / mid / lit
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float sheen = step(0.74, facing) * step(facing, 0.84) * step(0.2, k);
	float rim = smoothstep(0.8, 0.88, 1.0 - facing) * step(0.0, k);
	vec3 lit = c * tone * 1.25 + c * sheen * 0.35 + vec3(0.07, 0.08, 0.12) * step(0.45, k) * (1.0 - max(c.r, max(c.g, c.b))) + vec3(1.0, 0.97, 0.9) * rim * 0.06;   // dark hair gets a blue-grey lit side
	ALBEDO = lit + c * glow * 1.5;
}
