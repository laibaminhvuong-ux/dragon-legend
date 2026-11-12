// Painted sky for worlds that ask for more than a plain gradient (world/sky_bodies.gd fills it in):
// the same zenith/horizon/ground gradient and sun halo as ProceduralSkyMaterial, plus an optional
// starfield, a nebula / painted-cloud wash and up to 8 sky bodies (suns, moons, banded planets,
// ringed planets, translucent bubble planets, an eclipse disc).
// Static (no TIME): the radiance cubemap is baked once; per pixel it is a handful of maths and at most
// four noise lookups plus the bodies that are actually near the view ray.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.22, 0.45, 0.82, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.68, 0.8, 0.92, 1.0);
uniform vec4 ground_horizon : source_color = vec4(0.68, 0.8, 0.92, 1.0);
uniform vec4 ground_bottom : source_color = vec4(0.3, 0.33, 0.3, 1.0);
uniform float sky_curve = 0.12;
uniform float ground_curve = 0.02;
uniform float sun_angle_max = 0.14;   // radians: the sun's halo
uniform float sun_curve = 0.15;
uniform float sun_disc = 1.0;         // 0 hides the main sun's halo (eclipse worlds draw their own)

uniform float stars = 0.0;            // 0 = none, 1 = normal density
uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float nebula = 0.0;           // 0 = none; strength of the wash
uniform float nebula_scale = 1.0;
uniform vec2 nebula_offset = vec2(0.0);
uniform vec4 nebula_a : source_color = vec4(0.35, 0.1, 0.5, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.8, 0.2, 0.55, 1.0);
uniform vec4 nebula_c : source_color = vec4(0.3, 0.9, 0.7, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

// bodies (linear colours, set from sky_bodies.gd)
uniform int body_count = 0;
uniform vec4 body_dir[8];    // xyz: direction to the body, w: angular radius (radians)
uniform vec4 body_t[8];      // xyz: disc tangent, w: cos(reach) - rays outside skip the body
uniform vec4 body_b[8];      // xyz: disc bitangent, w: seed
uniform vec4 body_col[8];    // rgb: main colour, a: kind (0 sun, 1 moon, 2 planet, 3 ringed, 4 bubble, 5 eclipse)
uniform vec4 body_col2[8];   // rgb: second colour, a: ring tilt / glow strength

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float star_layer(vec3 d, float res, float keep, float rad) {
	vec3 p = d * res;
	vec3 c = floor(p);
	float h = hash13(c);
	if (h < keep) return 0.0;
	vec3 o = vec3(hash13(c + 11.1), hash13(c + 23.7), hash13(c + 5.3)) * 0.6 + 0.2;
	float dd = length(fract(p) - o);
	return smoothstep(rad, 0.0, dd) * (0.35 + 0.65 * (h - keep) / (1.0 - keep));
}

// x: turns round the horizon (-0.5..0.5, jumps by exactly 1 behind the view: the noise is seamless, so every
// lookup scales it by a whole number), y: elevation
vec2 sky_uv(vec3 d) {
	return vec2(atan(d.x, d.z) / (2.0 * PI), asin(clamp(d.y, -1.0, 1.0)) * (1.6 / PI));
}

void sky() {
	vec3 d = EYEDIR;
	float v_angle = acos(clamp(d.y, -1.0, 1.0));
	vec3 col;
	if (d.y >= 0.0) {
		float c = 1.0 - v_angle / (PI * 0.5);
		col = mix(horizon_color.rgb, top_color.rgb, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	} else {
		float c = (v_angle - PI * 0.5) / (PI * 0.5);
		col = mix(ground_horizon.rgb, ground_bottom.rgb, clamp(1.0 - pow(1.0 - c, 1.0 / ground_curve), 0.0, 1.0));
	}

	if (nebula > 0.0) {
		vec2 su = sky_uv(d);
		float k = max(1.0, round(4.0 * nebula_scale));
		vec2 uv = vec2(su.x * k, su.y * nebula_scale) + nebula_offset;
		vec2 cap = d.xz * 0.9 * nebula_scale + nebula_offset;
		float polar = smoothstep(0.55, 0.85, abs(d.y));
		// explicit LOD: the wrap line of atan() would otherwise pick a tiny mip
		float n1 = mix(textureLod(noise_tex, uv, 0.0).r, textureLod(noise_tex, cap, 0.0).r, polar);
		vec2 bu = vec2(su.x, su.y * 0.3) + 0.5;
		float big = mix(textureLod(noise_tex, bu, 0.0).r, textureLod(noise_tex, cap * 0.3 + 0.5, 0.0).r, polar);
		vec2 w = vec2(uv.x * 2.0, uv.y * 2.3) + vec2(n1 * 0.35, 0.17);
		float n2 = textureLod(noise_tex, w, 0.0).r;
		float dens = smoothstep(0.38, 0.78, n1 * 0.65 + n2 * 0.45) * smoothstep(0.3, 0.62, big);
		vec3 neb = mix(nebula_a.rgb, nebula_b.rgb, smoothstep(0.35, 0.7, n2));
		neb += nebula_c.rgb * pow(clamp(n2 * 1.25 - 0.25, 0.0, 1.0), 5.0) * 1.6;
		col = mix(col, neb, clamp(dens * nebula, 0.0, 1.0));
	}

	if (stars > 0.0 && !AT_CUBEMAP_PASS) {
		float lum = dot(col, vec3(0.3, 0.55, 0.15));
		float vis = 1.0 - smoothstep(0.18, 0.55, lum);
		if (vis > 0.0) {
			float s = star_layer(d, 260.0, 1.0 - 0.09 * stars, 0.28) + star_layer(d, 95.0, 1.0 - 0.05 * stars, 0.2) * 1.8;
			col += star_color.rgb * s * vis * 1.6;
		}
	}

	if (LIGHT0_ENABLED && sun_disc > 0.0) {
		float sa = acos(clamp(dot(LIGHT0_DIRECTION, d), -1.0, 1.0));
		vec3 sc = LIGHT0_COLOR * LIGHT0_ENERGY;
		if (sa < LIGHT0_SIZE) {
			col = sc;
		} else if (sa < sun_angle_max) {
			float c2 = (sa - LIGHT0_SIZE) / (sun_angle_max - LIGHT0_SIZE);
			col = mix(sc, col, clamp(1.0 - pow(1.0 - c2, 1.0 / sun_curve), 0.0, 1.0));
		}
	}

	vec3 L = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	for (int i = 0; i < body_count; i++) {
		vec4 bd = body_dir[i];
		float cd = dot(d, bd.xyz);
		if (cd < body_t[i].w) continue;
		vec3 t = body_t[i].xyz;
		vec3 b = body_b[i].xyz;
		float seed = body_b[i].w;
		vec2 q = vec2(dot(d, t), dot(d, b)) / sin(bd.w);
		float r = length(q);
		int kind = int(body_col[i].a + 0.5);
		vec3 c1 = body_col[i].rgb;
		vec3 c2 = body_col2[i].rgb;
		float aa = smoothstep(1.0, 0.965, r);
		if (kind == 0) {            // sun: hot disc and a soft halo
			float glow = exp(-max(r - 1.0, 0.0) * 1.6) * (1.0 - aa);
			col = mix(col, c1 * 3.0, aa) + c1 * glow * 0.55 * body_col2[i].a;
		} else if (kind == 5) {     // eclipse: dark disc with a lopsided bright corona
			float side = 1.0 + 0.9 * clamp(q.x / max(r, 0.001), -1.0, 1.0);
			float o = max(r - 1.0, 0.0);
			vec3 corona = c1 * (exp(-o * 9.0) * 3.0 * side + exp(-o * 1.8) * 0.5);
			col = mix(col + corona * (1.0 - aa), c2 + c1 * 0.05 * pow(r, 8.0), aa);
		} else if (kind == 4) {     // bubble planet: see-through, bright rim, swirls and a highlight
			if (r < 1.0) {
				float sw = textureLod(noise_tex, q * 0.35 + vec2(seed, seed * 0.7), 0.0).r;
				float swirl = smoothstep(0.5, 0.72, sw);
				float a = 0.16 + 0.6 * pow(r, 3.5) + 0.3 * swirl;
				vec3 bc = mix(c1, c2, swirl);
				float spec = exp(-dot(q - vec2(-0.38, 0.42), q - vec2(-0.38, 0.42)) * 22.0);
				col = mix(col, bc, clamp(a, 0.0, 1.0) * aa) + vec3(spec * 0.9 * aa);
			}
		} else {                    // moon / planet / ringed planet: a sphere lit by the sun
			float tilt = body_col2[i].a;
			vec2 rq = vec2(q.x, q.y / max(tilt, 0.05));
			float rl = length(rq);
			float ring = 0.0;
			vec3 rc = c2;
			if (kind == 3) {
				ring = smoothstep(1.32, 1.4, rl) * smoothstep(2.25, 2.15, rl) * (0.55 + 0.45 * sin(rl * 38.0 + seed));
				ring *= 0.85;
				rc = c2 * (0.6 + 0.4 * clamp(dot(L, b) * 0.5 + 0.7, 0.0, 1.0));
			}
			bool ring_front = q.y < 0.0;
			if (kind == 3 && !ring_front) col = mix(col, rc, ring);
			if (r < 1.0) {
				float z = sqrt(1.0 - r * r);
				vec3 n = t * q.x + b * q.y - bd.xyz * z;
				float nl = dot(n, L);
				// moons read as pale discs from any side; planets keep a real terminator
				float lam = kind == 1 ? 0.45 + 0.55 * clamp(nl * 0.5 + 0.5, 0.0, 1.0) : clamp(nl * 0.95 + 0.18, 0.12, 1.0);
				float tex;
				vec3 surf;
				if (kind == 1) {
					tex = textureLod(noise_tex, q * 0.4 + vec2(seed), 0.0).r;
					surf = mix(c1, c2, smoothstep(0.42, 0.68, tex));
				} else {
					tex = textureLod(noise_tex, vec2(seed + q.x * 0.05, q.y * 0.55), 0.0).r;
					surf = mix(c1, c2, smoothstep(0.35, 0.65, tex));
				}
				surf *= lam;
				surf += c1 * pow(r, 6.0) * 0.35;   // a thin lit atmosphere at the limb
				col = mix(col, surf, aa);
			}
			if (kind == 3 && ring_front) col = mix(col, rc, ring);
		}
	}
	COLOR = col;
}
