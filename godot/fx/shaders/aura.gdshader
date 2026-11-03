// Transformation aura shell (port of the JS aura): a unit sphere drawn up into flickering tongues of flame,
// additive, with brighter licks at the silhouette. Per-instance parameters, so every aura shares one material.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
instance uniform vec4 core : source_color = vec4(1.0, 1.0, 0.9, 1.0);
instance uniform float time = 0.0;
instance uniform float intensity = 1.0;
instance uniform float flicker = 0.8;
instance uniform float calm = 0.0;
instance uniform float burst = 0.0;

varying vec3 vp;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float n3(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 p = VERTEX;
	float h = p.y;
	float r = mix(0.62, 1.0, smoothstep(-1.0, -0.2, h)) * mix(1.0, 0.55, smoothstep(0.35, 1.0, h));
	p.xz *= r;
	float t = time * mix(2.6, 1.1, calm) * (0.6 + flicker * 0.6);
	float n = n3(vec3(p.x * 2.6, p.y * 2.0 - t, p.z * 2.6));
	float tongue = smoothstep(0.1, 1.0, h) * (0.35 + 0.9 * n) * mix(1.0, 0.35, calm);
	p.y += tongue * 0.75;
	p += NORMAL * (n - 0.5) * mix(0.16, 0.05, calm);
	p *= 1.0 + burst * 0.45;
	vp = VERTEX;
	VERTEX = p;
}

void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = atan(vp.z, vp.x);
	float t = time * mix(3.2, 1.2, calm) * (0.6 + flicker * 0.6);
	float s = n3(vec3(a * 2.5, vp.y * 3.0 - t, 0.5)) * 0.65 + n3(vec3(a * 6.0, vp.y * 7.0 - t * 1.7, 2.0)) * 0.35;
	s = mix(s, 0.62, calm * 0.7);
	float edge = pow(f, mix(0.9, 1.6, calm));
	float flame = smoothstep(0.22, 0.7, s);
	float alpha = (edge * 0.95 + 0.1 * flame) * mix(0.35, 1.0, flame) * smoothstep(-1.0, -0.55, vp.y);
	alpha *= intensity * (0.85 + 0.15 * sin(time * 23.0) * flicker) + burst * 0.6;
	vec3 col = mix(core.rgb, color.rgb, smoothstep(0.15, 0.8, f));
	ALBEDO = col * alpha * clamp(alpha, 0.0, 1.0) * 1.15;   // the JS additive blend weighted the colour by alpha twice
}
