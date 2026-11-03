// Fighter body. CUSTOM0.xyz is the vertex's rest-pose (T-pose) position; the outfit region is chosen per pixel
// from it (rules mirror BodyRegions.region), with borders anti-aliased by fwidth. A region colour with alpha 0
// shows the skin (skin_color), so forms recolour every bare patch at once. The face (eyes, brows, mouth) is
// painted on the front of the head as signed-distance shapes, so expressions and form eye colours cost nothing.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// 0 skin 1 top 2 pants 3 boots 4 belt 5 wrist 6 sleeve 7 forearm 8 hands 9 undershirt 10 plate 11 upper arm 12 trim
uniform vec4 colors[13] : source_color;
uniform vec4 skin_color : source_color = vec4(0.95, 0.8, 0.65, 1.0);
uniform float skin_metal = 0.0;
uniform float plate_gloss = 0.0;
uniform vec4 eye_color : source_color = vec4(0.16, 0.11, 0.08, 1.0);
uniform int face = 0;            // 0 calm, 1 fierce, 2 smirk, 3 determined, 4 cold
uniform float brows = 1.0;
uniform vec4 brow_color : source_color = vec4(0.08, 0.06, 0.05, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);

varying vec3 rest;

void vertex() { rest = CUSTOM0.xyz; }

float above(float v, float e) { float w = max(fwidth(v), 1e-4); return smoothstep(e - w, e + w, v); }
float inside(float sdf) { float w = max(fwidth(sdf), 1e-5); return 1.0 - smoothstep(-w, w, sdf); }
float ellipse(vec2 q, vec2 ab) { return (length(q / ab) - 1.0) * min(ab.x, ab.y); }
float segment(vec2 q, vec2 a, vec2 b, float r) {
	vec2 pa = q - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

void fragment() {
	vec3 p = rest;
	float ax = abs(p.x);
	// torso, bottom to top (rgb = colour, a = 1 cloth / 0 skin)
	vec4 col = colors[3];
	col = mix(col, colors[2], above(p.y, 0.24));
	col = mix(col, colors[4], above(p.y, 0.93));
	col = mix(col, colors[1], above(p.y, 1.0));
	col = mix(col, colors[12], above(p.y, 1.0) * (1.0 - above(p.y, 1.04)) * plate_gloss);
	col = mix(col, colors[10], above(p.y, 1.13));
	float vneck = above(p.y, 1.36) * above(p.z, 0.03) * (1.0 - above(ax, (p.y - 1.33) * 0.9));
	col = mix(col, colors[9], vneck);
	float neck = max(above(p.y, 1.47) * (1.0 - above(ax, 0.085)), above(p.y, 1.53));
	col = mix(col, colors[0], neck);
	// arms
	vec4 arm = colors[6];
	arm = mix(arm, colors[11], above(ax, 0.3));
	arm = mix(arm, colors[7], above(ax, 0.47));
	arm = mix(arm, colors[5], above(ax, 0.665));
	arm = mix(arm, colors[8], above(ax, 0.735));
	float is_arm = above(ax, 0.2) * above(p.y, 1.22);
	col = mix(col, arm, is_arm);

	float skin = 1.0 - col.a;
	vec3 c = mix(col.rgb, skin_color.rgb, skin);

	// ---- face (front of the head)
	float front = above(p.z, 0.05) * above(p.y, 1.58) * (1.0 - is_arm);
	if (front > 0.0) {
		vec2 q = vec2(ax - 0.039, p.y - 1.703);       // per-eye frame, +x outwards
		float lid = 0.02;                              // upper lid cut (lower = narrower eye)
		float slope = 0.0;
		if (face == 1) { lid = 0.0068; slope = 0.3; }
		else if (face == 3) { lid = 0.009; slope = 0.18; }
		else if (face == 4) { lid = 0.0035; slope = 0.08; }
		else if (face == 2) { lid = 0.011; slope = 0.1; }
		float top_line = lid + slope * q.x;
		float eye_sdf = max(ellipse(q, vec2(0.021, 0.0128)), q.y - top_line);
		float eye = inside(eye_sdf) * front;
		vec2 iq = q - vec2(-0.002, -0.0015);
		float iris = inside(length(iq) - 0.0105) * eye;
		float pupil = inside(length(iq) - 0.0048) * eye;
		float glint = inside(length(iq - vec2(0.004, 0.0045)) - 0.0026) * eye;
		float lash = (1.0 - inside(eye_sdf + 0.0032)) * inside(eye_sdf - 0.0012) * above(q.y + 0.002, 0.0) * front;
		vec3 iris_col = mix(eye_color.rgb * 0.55, eye_color.rgb * 1.15, smoothstep(0.0105, 0.002, length(iq - vec2(0.0, -0.004))));
		c = mix(c, vec3(0.97, 0.96, 0.95), eye);
		c = mix(c, iris_col, iris);
		c = mix(c, vec3(0.02), pupil);
		c = mix(c, vec3(1.0), glint);
		c = mix(c, vec3(0.05, 0.04, 0.04), lash);
		// brows: inner end lower when fierce/determined/cold, a soft arch when calm
		float by = 1.73 + (face == 0 ? -0.002 : 0.0);
		float tilt = face == 1 ? 0.36 : (face == 3 ? 0.24 : (face == 4 ? 0.1 : (face == 2 ? 0.12 : -0.08)));
		vec2 bq = vec2(ax, p.y);
		float brow = inside(segment(bq, vec2(0.02, by - tilt * 0.02), vec2(0.064, by + tilt * 0.024), 0.0034)) * front * brows;
		c = mix(c, brow_color.rgb, brow);
		// mouth
		vec2 mq = vec2(p.x, p.y - 1.628);
		float mouth_sdf;
		if (face == 2) mouth_sdf = segment(mq, vec2(-0.016, -0.001), vec2(0.018, 0.005), 0.0018);
		else if (face == 1 || face == 3) mouth_sdf = segment(mq, vec2(-0.016, 0.0), vec2(0.016, 0.0), 0.002) + mq.x * mq.x * 3.0;
		else if (face == 4) mouth_sdf = segment(mq, vec2(-0.013, 0.0), vec2(0.013, 0.0), 0.0015);
		else mouth_sdf = segment(mq, vec2(-0.015, 0.001), vec2(0.015, 0.001), 0.0017) - (0.0003 - mq.x * mq.x * 0.0);
		if (face == 0) mouth_sdf = abs(length(mq - vec2(0.0, 0.03)) - 0.031) - 0.0017 + step(0.016, abs(mq.x)) * 1.0;
		c = mix(c, vec3(0.32, 0.12, 0.1), inside(mouth_sdf) * front);
		// a hint of nose shadow
		c *= 1.0 - 0.08 * inside(ellipse(vec2(p.x, p.y - 1.668), vec2(0.006, 0.011))) * front;
	}

	float plate = above(p.y, 1.0) * (1.0 - is_arm) * plate_gloss * (1.0 - skin);
	float weave = (fract(sin(dot(floor(UV * 900.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.05;
	c *= 1.0 + weave * (1.0 - skin) * (1.0 - plate);
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.88, mix(0.5, 0.3, skin_metal), skin), 0.3, plate);
	METALLIC = skin * skin_metal;
	SPECULAR = mix(mix(0.2, 0.35, skin), 0.6, plate);
	BACKLIGHT = c * 0.22 * skin * (1.0 - skin_metal);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * rim * 0.06;
}
