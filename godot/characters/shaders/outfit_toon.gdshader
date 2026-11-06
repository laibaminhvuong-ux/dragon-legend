// Anime look (preview, user request 2026-11-06): the same fighter body as outfit.gdshader, lit in cel bands —
// one hard light/shadow edge with a cool-tinted shadow and a bright rim (no glossy highlights). An ink outline is
// drawn by outline.gdshader as the next pass.
shader_type spatial;
render_mode specular_disabled;

#define TOON
#include "res://characters/shaders/outfit_body.gdshaderinc"
// body include rev 4


void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.045, ndl) * smoothstep(0.35, 0.55, ATTENUATION);
	vec3 shade_tint = vec3(0.62, 0.64, 0.8);   // shadows lean cool, like cel art
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shade_tint * 0.3, vec3(0.78), lit);
}
