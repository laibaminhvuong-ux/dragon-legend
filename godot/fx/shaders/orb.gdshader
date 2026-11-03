// Dragon orb: glossy amber glass with 1-7 red stars floating on the front (object +Z), a warm inner glow.
shader_type spatial;
render_mode specular_schlick_ggx;
instance uniform int stars = 4;
instance uniform vec4 glow : source_color = vec4(1.0, 0.55, 0.12, 1.0);
instance uniform float ghost = 0.0;   // projection orbs are see-through
varying vec3 n_obj;
void vertex() { n_obj = normalize(VERTEX); }
float star(vec2 p, float r) {
	float a = atan(p.y, p.x) + 1.5708;
	float seg = 6.2831853 / 5.0;
	a = mod(a + seg * 0.5, seg) - seg * 0.5;
	float rr = r * mix(0.45, 1.0, pow(abs(cos(a * 2.5)), 6.0));
	return length(p) - rr * (0.75 + 0.25 * cos(a * 5.0));
}
void fragment() {
	vec3 n = normalize(n_obj);
	vec2 q = n.xy / max(0.2, n.z + 0.6);
	vec2 pts[7] = vec2[7](vec2(0.0, 0.0), vec2(-0.16, 0.14), vec2(0.16, 0.14), vec2(-0.16, -0.14), vec2(0.16, -0.14), vec2(0.0, 0.24), vec2(0.0, -0.24));
	float s = 0.0;
	for (int i = 0; i < 7; i++) {
		if (i >= stars) break;
		float d = star(q - pts[i] * 0.8, stars == 1 ? 0.11 : 0.07);
		s = max(s, 1.0 - smoothstep(-0.004, 0.006, d));
	}
	s *= step(0.0, n.z);
	vec3 amber = mix(vec3(1.0, 0.83, 0.42), vec3(0.94, 0.54, 0.07), 0.5 - n.y * 0.5);
	ALBEDO = mix(amber, vec3(0.85, 0.08, 0.1), s);
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = glow.rgb * (0.35 + rim * 0.6);
	ALPHA = 1.0 - ghost * 0.3;
}
