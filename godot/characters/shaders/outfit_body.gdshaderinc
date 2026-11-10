// Shared by outfit.gdshader (standard look) and outfit_toon.gdshader (anime look): uniforms, regions, face.

// 0 skin 1 top 2 pants 3 boots 4 belt 5 wrist 6 sleeve 7 forearm 8 hands 9 undershirt 10 plate 11 upper arm 12 trim
// 13 boot trim 14 boot laces
uniform vec4 colors[15] : source_color;
uniform float cloth = 0.0;        // Cloth amount (0 tight .. 1 baggy): soft fold shadows on loose clothes
uniform float sleeve_end = 0.3;   // rest |x| where the clothed part of the arm ends
uniform float boot_top = 0.24;    // rest height of the boots' top edge (Cloth.boot_top)
uniform float boot_detail = 0.0;  // 1 = cuff trim line, wrap laces and a dark sole on the boots
uniform vec4 skin_color : source_color = vec4(0.95, 0.8, 0.65, 1.0);
uniform float skin_metal = 0.0;
uniform float plate_gloss = 0.0;
uniform vec4 eye_color : source_color = vec4(0.16, 0.11, 0.08, 1.0);
uniform int face = 0;            // 0 calm, 1 fierce, 2 smirk, 3 determined, 4 cold
uniform float brows = 1.0;
uniform vec4 brow_color : source_color = vec4(0.08, 0.06, 0.05, 1.0);
// per-character face proportions (FaceShape); the defaults are the original face
uniform vec4 face_eyes = vec4(1.0, 0.0, 0.0, 0.0);    // size, extra gap, outer-corner tilt, height offset
uniform vec4 face_brows = vec4(1.0, 1.0, 0.0, 0.0);   // thickness, length, arch, height offset
uniform vec4 face_mouth = vec4(1.0, 0.0, 1.0, 0.0);
uniform float feminine = 0.0;   // female faces: bolder lashes with a flick, coloured lips   // width, height offset, iris size, mark (1 scar, 2 freckles)
uniform float manga = 1.0;   // 1 = manga-style painted face (default), 0 = the earlier face
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);

varying vec3 rest;

void vertex() { rest = CUSTOM0.xyz; }

float above(float v, float e) { float w = max(fwidth(v), 1e-4); return smoothstep(e - w, e + w, v); }
float inside(float sdf) { float w = max(fwidth(sdf), 1e-5); return 1.0 - smoothstep(-w, w, sdf); }
float ellipse(vec2 q, vec2 ab) { return (length(q / ab) - 1.0) * min(ab.x, ab.y); }
// Soft cloth folds (stable in rest space, so they follow the animation): 0..1 where a fold's shadow lies.
float fold_band(float v, float w) { return smoothstep(0.72, 0.98, sin(v)) * w; }
float cloth_folds(vec3 p, float is_arm) {
	float ax = abs(p.x);
	float wob = 0.75 + 0.25 * sin(p.x * 23.0 + p.y * 17.0 + p.z * 19.0);   // folds come and go along their length
	float f = 0.0;
	// trousers: bunched zigzag folds above the boots, diagonal creases at the knee, long folds down the thigh
	float pants = above(p.y, boot_top + 0.01) * (1.0 - above(p.y, 0.92)) * (1.0 - is_arm);
	if (pants > 0.0) {
		float lx = p.x - sign(p.x) * 0.089;
		float th = atan(lx, p.z + 0.01);
		float side = sign(p.x);
		f = max(f, fold_band((p.y - boot_top) * 80.0 + 1.1 * sin(th * 3.0 + p.y * 21.0), 1.0 - smoothstep(boot_top + 0.06, boot_top + 0.12, p.y)));
		f = max(f, fold_band(p.y * 40.0 + th * 1.4 * side, smoothstep(0.44, 0.48, p.y) * (1.0 - smoothstep(0.57, 0.64, p.y))) * wob);
		f = max(f, fold_band(th * 2.0 * side + p.y * 16.0, smoothstep(0.64, 0.7, p.y) * (1.0 - smoothstep(0.82, 0.88, p.y)) * 0.9) * wob);
		f *= pants;
	}
	// sleeves: rings bunched near the shoulder and the hem / elbow
	if (is_arm > 0.0 && ax < sleeve_end) {
		float ph = atan(p.z + 0.065, p.y - 1.44);
		float sl = fold_band((ax - 0.2) * 58.0 + 0.9 * sin(ph * 2.0 + ax * 31.0), 1.0) * wob;
		sl *= 1.0 - above(ax, sleeve_end - 0.02);
		f = max(f, sl * is_arm);
	}
	// top: folds fanning up from the sash, diagonal pulls from the armpits on the chest
	float top = above(p.y, 1.0) * (1.0 - above(p.y, 1.36)) * (1.0 - is_arm);
	if (top > 0.0) {
		float th = atan(p.x, p.z);
		f = max(f, fold_band(th * 9.0 + 1.4 * sin(p.y * 13.0 + th * 2.0), (1.0 - smoothstep(1.04, 1.17, p.y))) * wob * top);
		f = max(f, fold_band((p.y + ax * 1.3) * 42.0, smoothstep(0.07, 0.13, ax) * smoothstep(1.12, 1.2, p.y) * (1.0 - smoothstep(1.3, 1.36, p.y)) * 0.85) * wob * top);
	}
	return f;
}

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
	col = mix(col, colors[2], above(p.y, boot_top));
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
	// boots: dark sole, wrap laces round the shaft, a contrasting trim line at the cuff
	float boot = (1.0 - above(p.y, boot_top)) * (1.0 - is_arm);
	if (boot > 0.0 && boot_detail > 0.0) {
		// wrap laces: tilted bands, alternating, so they cross on the front of the shin
		float lx = p.x - sign(p.x) * 0.089;
		float lace = 0.0;
		float lace_lo = 0.13, lace_hi = boot_top - 0.045;
		for (int k = 0; k < 3; k++) {
			float yk = mix(lace_lo, lace_hi, float(k) / 2.0);
			float tilt = (k % 2 == 0 ? 0.32 : -0.32) * lx * step(-0.01, p.z);
			lace = max(lace, 1.0 - above(abs(p.y - yk - tilt), 0.0045));
			lace = max(lace, (1.0 - above(abs(p.y - yk + tilt), 0.0045)) * step(-0.01, p.z));
		}
		vec3 bc = col.rgb;
		bc = mix(bc, colors[14].rgb, lace);
		bc = mix(bc, colors[13].rgb, above(p.y, boot_top - 0.03) * (1.0 - above(p.y, boot_top - 0.016)));
		bc = mix(bc, bc * 0.42, 1.0 - above(p.y, 0.017));
		col.rgb = mix(col.rgb, bc, boot);
	}

	float skin = 1.0 - col.a;
	vec3 c = mix(col.rgb, skin_color.rgb, skin);

	// ---- face (front of the head)
	float front = above(p.z, 0.05) * above(p.y, 1.58) * (1.0 - is_arm);
	if (front > 0.0) {
		if (manga > 0.5) {
		// ---- manga face (user request 2026-11-06): big tall eyes with a heavy upper lash line and an outer flick,
		// a tall iris darker at the top with two shine spots, thin raised brows, a tiny mouth and a nose tick
		vec2 q = vec2(ax - 0.042 - face_eyes.y, p.y - 1.696 - face_eyes.w);
		q.y -= q.x * face_eyes.z * 0.6;
		q /= face_eyes.x;
		float cut = 0.0;            // how far the upper lid comes down (expression)
		float droop = 0.0;          // inner-corner tilt of the upper lid
		if (face == 1) { cut = 0.0075; droop = 0.32; }       // fierce
		else if (face == 3) { cut = 0.005; droop = 0.2; }    // determined
		else if (face == 4) { cut = 0.009; droop = 0.06; }   // cold
		else if (face == 2) { cut = 0.004; droop = 0.1; }    // smirk
		vec2 ab = mix(vec2(0.0215, 0.0158), vec2(0.0228, 0.0198), feminine);   // men: sharper, slimmer eyes
		float top_line = ab.y * 0.72 - cut + droop * (-q.x);   // lower toward the nose when angry
		float eye_sdf = max(ellipse(q, ab), q.y - top_line);
		float eye = inside(eye_sdf) * front;
		vec2 iq = q - vec2(-0.0015, -0.002);
		float ir = face_mouth.z;
		float iris = inside(ellipse(iq, vec2(0.0108, 0.0148) * ir)) * eye;
		float pupil = inside(ellipse(iq - vec2(0.0, 0.001), vec2(0.0042, 0.0062) * ir)) * eye;
		float shine = max(inside(length(iq - vec2(0.0042, 0.0058)) - 0.0034), inside(length(iq - vec2(-0.0038, -0.0062)) - 0.0016)) * eye;
		vec3 iris_col = mix(eye_color.rgb * 1.35, eye_color.rgb * 0.45, smoothstep(-0.012, 0.01, iq.y));   // light below, dark above
		iris_col = mix(iris_col, eye_color.rgb * 0.3, 1.0 - inside(ellipse(iq, vec2(0.0094, 0.0134) * ir)));  // dark rim
		float upper = q.y > top_line - 0.0034 - 0.0018 * feminine ? 1.0 : 0.0;
		float lash = inside(eye_sdf - 0.0018) * (1.0 - inside(eye_sdf + 0.0045 + 0.0012 * feminine)) * upper * front;
		lash = max(lash, feminine * inside(segment(q, vec2(ab.x * 0.82, top_line), vec2(ab.x * 1.22, top_line + 0.0035), 0.0024)) * front);  // women: outer flick
		lash = max(lash, (1.0 - feminine) * inside(segment(q, vec2(ab.x * 0.85, top_line - 0.001), vec2(ab.x * 1.08, top_line - 0.003), 0.0015)) * front);  // men: a short sharp corner
		float lower = (1.0 - inside(eye_sdf + 0.0009)) * inside(eye_sdf - 0.0009) * step(q.y, -0.008) * step(0.004, q.x) * front * (0.35 + 0.65 * feminine);
		c = mix(c, vec3(0.99, 0.98, 0.97), eye);
		c = mix(c, iris_col, iris);
		c = mix(c, vec3(0.03, 0.025, 0.03), pupil);
		c = mix(c, vec3(1.0), shine);
		c = mix(c, vec3(0.06, 0.05, 0.06), max(lash, lower * 0.8));
		// brows: thin strokes set well above the eyes; angle by expression
		float by = 1.729 + face_eyes.w + face_brows.w;
		float tilt = face == 1 ? 0.5 : (face == 3 ? 0.32 : (face == 4 ? 0.12 : (face == 2 ? 0.16 : -0.12)));
		vec2 bq = vec2(ax - face_eyes.y, p.y);
		float bx = clamp((bq.x - 0.045) / 0.026, -1.0, 1.0);
		bq.y -= (face_brows.z * 0.003 + 0.002) * (1.0 - bx * bx);
		float brow_end = 0.024 + 0.042 * face_brows.y;
		float brow = inside(segment(bq, vec2(0.022, by - tilt * 0.018), vec2(brow_end, by + tilt * 0.02 * face_brows.y), 0.0022 * face_brows.x)) * front * brows;
		c = mix(c, brow_color.rgb, brow);
		// nose: one short shade stroke on the side away from the light
		c *= 1.0 - 0.22 * inside(segment(vec2(p.x, p.y), vec2(0.005, 1.672), vec2(0.0075, 1.66), 0.0012)) * front;
		// mouth: small and simple
		vec2 mq = vec2(p.x / face_mouth.x, p.y - 1.626 - face_mouth.y);
		float mouth_sdf;
		if (face == 2) mouth_sdf = segment(mq, vec2(-0.01, 0.0), vec2(0.012, 0.004), 0.0014);
		else if (face == 1) mouth_sdf = segment(mq, vec2(-0.011, -0.001), vec2(0.011, -0.001), 0.0016) + mq.x * mq.x * 4.0;
		else if (face == 3) mouth_sdf = segment(mq, vec2(-0.01, 0.0), vec2(0.01, 0.0), 0.0014);
		else if (face == 4) mouth_sdf = segment(mq, vec2(-0.008, 0.0), vec2(0.008, 0.0), 0.0011);
		else mouth_sdf = max(max(abs(length(mq - vec2(0.0, 0.022)) - 0.023) - 0.0014, abs(mq.x) - 0.011), mq.y - 0.012);   // the smile is the bottom of the circle only   // clip with max: a step makes fwidth draw lines down the face
		c = mix(c, vec3(0.36, 0.14, 0.12), inside(mouth_sdf) * front);
		if (feminine > 0.5) {
			c = mix(c, vec3(0.78, 0.36, 0.4), inside(ellipse(vec2(mq.x, mq.y + 0.0012), vec2(0.009 * face_mouth.x, 0.0035))) * 0.6 * front);
		}
		// blush under the eyes (soft), a mark if any
		c = mix(c, c * vec3(1.0, 0.86, 0.84), 0.35 * inside(ellipse(vec2(ax - 0.05, p.y - 1.672), vec2(0.016, 0.006))) * front * (0.4 + feminine * 0.6));
		if (face_mouth.w > 0.5 && face_mouth.w < 1.5) {
			float scar = inside(segment(vec2(p.x, p.y), vec2(-0.062, 1.708), vec2(-0.032, 1.664), 0.0016));
			c = mix(c, skin_color.rgb * vec3(0.72, 0.52, 0.5), scar * front);
		}
		} else {
		vec2 q = vec2(ax - 0.039 - face_eyes.y, p.y - 1.703 - face_eyes.w);   // per-eye frame, +x outwards
			q.y -= q.x * face_eyes.z;                      // tilted eyes (outer corner up or down)
			q /= face_eyes.x;                              // bigger or smaller eyes
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
			float iris = inside(length(iq) - 0.0105 * face_mouth.z) * eye;
			float pupil = inside(length(iq) - 0.0048 * face_mouth.z) * eye;
			float glint = inside(length(iq - vec2(0.004, 0.0045)) - 0.0026) * eye;
			float lash = (1.0 - inside(eye_sdf + 0.0032 + 0.0018 * feminine)) * inside(eye_sdf - 0.0012) * above(q.y + 0.002, 0.0) * front;
			lash = max(lash, feminine * inside(segment(q, vec2(0.018, 0.006), vec2(0.03, 0.013), 0.0016)) * front);   // outer flick
			vec3 iris_col = mix(eye_color.rgb * 0.55, eye_color.rgb * 1.15, smoothstep(0.0105, 0.002, length(iq - vec2(0.0, -0.004))));
			c = mix(c, vec3(0.97, 0.96, 0.95), eye);
			c = mix(c, iris_col, iris);
			c = mix(c, vec3(0.02), pupil);
			c = mix(c, vec3(1.0), glint);
			c = mix(c, vec3(0.05, 0.04, 0.04), lash);
				// brows: inner end lower when fierce/determined/cold, a soft arch when calm
			float by = 1.73 + (face == 0 ? -0.002 : 0.0) + face_eyes.w + face_brows.w;
			float tilt = face == 1 ? 0.36 : (face == 3 ? 0.24 : (face == 4 ? 0.1 : (face == 2 ? 0.12 : -0.08)));
			vec2 bq = vec2(ax - face_eyes.y, p.y);
			float bx = clamp((bq.x - 0.042) / 0.024, -1.0, 1.0);
			bq.y -= face_brows.z * 0.004 * (1.0 - bx * bx);   // arched or flat brows
			float brow_end = 0.02 + 0.044 * face_brows.y;
			float brow = inside(segment(bq, vec2(0.02, by - tilt * 0.02), vec2(brow_end, by + tilt * 0.024 * face_brows.y), 0.0034 * face_brows.x)) * front * brows;
			c = mix(c, brow_color.rgb, brow);
			// mouth
			vec2 mq = vec2(p.x / face_mouth.x, p.y - 1.628 - face_mouth.y);
			float mouth_sdf;
			if (face == 2) mouth_sdf = segment(mq, vec2(-0.016, -0.001), vec2(0.018, 0.005), 0.0018);
			else if (face == 1 || face == 3) mouth_sdf = segment(mq, vec2(-0.016, 0.0), vec2(0.016, 0.0), 0.002) + mq.x * mq.x * 3.0;
			else if (face == 4) mouth_sdf = segment(mq, vec2(-0.013, 0.0), vec2(0.013, 0.0), 0.0015);
			else mouth_sdf = segment(mq, vec2(-0.015, 0.001), vec2(0.015, 0.001), 0.0017) - (0.0003 - mq.x * mq.x * 0.0);
			if (face == 0) mouth_sdf = max(max(abs(length(mq - vec2(0.0, 0.03)) - 0.031) - 0.0017, abs(mq.x) - 0.016), mq.y - 0.015);
			c = mix(c, vec3(0.32, 0.12, 0.1), inside(mouth_sdf) * front);
			if (feminine > 0.5) {   // lips: a soft rose tint around the mouth line
				float lips = inside(ellipse(vec2(mq.x, mq.y + 0.001), vec2(0.017 * face_mouth.x, 0.0055)));
				c = mix(c, vec3(0.72, 0.3, 0.34), lips * 0.75 * front);
			}
			// a mark: a scar across one cheek, or freckles
			if (face_mouth.w > 0.5 && face_mouth.w < 1.5) {
				float scar = inside(segment(vec2(p.x, p.y), vec2(-0.062, 1.708), vec2(-0.032, 1.664), 0.0016));
				c = mix(c, skin_color.rgb * vec3(0.72, 0.52, 0.5), scar * front);
			} else if (face_mouth.w > 1.5) {
				vec2 fq = vec2(ax, p.y) * 260.0;
				float dots = step(0.82, fract(sin(dot(floor(fq), vec2(12.9898, 78.233))) * 43758.5453))
					* step(length(fract(fq) - 0.5), 0.3) * inside(ellipse(vec2(ax - 0.045, p.y - 1.672), vec2(0.022, 0.011)));
				c = mix(c, skin_color.rgb * vec3(0.72, 0.55, 0.42), dots * front);
			}
			// a hint of nose shadow
			c *= 1.0 - 0.08 * inside(ellipse(vec2(p.x, p.y - 1.668), vec2(0.006, 0.011))) * front;
		}
	}

	float plate = above(p.y, 1.0) * (1.0 - is_arm) * plate_gloss * (1.0 - skin);
	// loose clothes: one flat darker tone in the folds (a cel band, not a gradient), a lighter edge on the sleeve
	// hems and along the raised lapel
	if (cloth > 0.0) {
		float cl = (1.0 - skin) * (1.0 - plate) * (1.0 - boot);
		float fold = above(cloth_folds(p, is_arm) * min(1.0, cloth * 1.3), 0.5) * cl;
		c *= 1.0 - 0.17 * fold;
		float hem = is_arm * step(0.1, sleeve_end) * above(ax, sleeve_end - 0.016) * (1.0 - above(ax, sleeve_end - 0.004));
		float dv = ax - (p.y - 1.33) * 0.9;
		float lapel = above(p.y, 1.37) * above(p.z, 0.03) * above(dv, 0.003) * (1.0 - above(dv, 0.012)) * (1.0 - is_arm);
		c *= 1.0 + 0.14 * max(hem, lapel) * cl * min(1.0, cloth * 2.0);
	}
	float weave = (fract(sin(dot(floor(UV * 900.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.05;
	c *= 1.0 + weave * (1.0 - skin) * (1.0 - plate);
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.88, mix(0.5, 0.3, skin_metal), skin), 0.3, plate);
	METALLIC = skin * skin_metal;
	SPECULAR = mix(mix(0.2, 0.35, skin), 0.6, plate);
#ifdef TOON
	SPECULAR = 0.0;   // cel look: no glossy reflections, only the drawn highlight in light()
	ROUGHNESS = 1.0;
#endif
	BACKLIGHT = c * 0.22 * skin * (1.0 - skin_metal);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * rim * 0.06;
}
