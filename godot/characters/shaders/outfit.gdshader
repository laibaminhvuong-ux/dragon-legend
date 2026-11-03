// Fighter body. CUSTOM0.xyz is the vertex's rest-pose (T-pose) position; the outfit region is chosen per pixel
// from it (rules mirror BodyRegions.region), with borders anti-aliased by fwidth. Skin is smooth with a little
// light through it; cloth is matte with a faint weave; armour plate is semi-gloss.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// indices: 0 skin 1 top 2 pants 3 boots 4 belt 5 wrist 6 sleeve 7 forearm 8 hands 9 undershirt 10 plate 11 upper arm 12 trim
uniform vec4 colors[13] : source_color;
uniform float plate_gloss = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float flush = 0.0;
uniform vec4 flush_color : source_color = vec4(0.9, 0.15, 0.1, 1.0);

varying vec3 rest;

void vertex() { rest = CUSTOM0.xyz; }

float above(float v, float e) { float w = max(fwidth(v), 1e-4); return smoothstep(e - w, e + w, v); }

void fragment() {
	vec3 p = rest;
	float ax = abs(p.x);
	// torso, bottom to top
	vec3 col = colors[3].rgb;                                  // boots
	col = mix(col, colors[2].rgb, above(p.y, 0.24));           // trousers
	col = mix(col, colors[4].rgb, above(p.y, 0.93));           // belt
	col = mix(col, colors[1].rgb, above(p.y, 1.0));            // top / plate belly
	float trim = above(p.y, 1.0) * (1.0 - above(p.y, 1.04)) * plate_gloss;
	col = mix(col, colors[12].rgb, trim);                      // armour trim under the plate
	col = mix(col, colors[10].rgb, above(p.y, 1.13));          // chest
	float vneck = above(p.y, 1.36) * above(p.z, 0.03) * (1.0 - above(ax, (p.y - 1.33) * 0.9));
	col = mix(col, colors[9].rgb, vneck);                      // undershirt V / bodysuit collar
	float neck = max(above(p.y, 1.47) * (1.0 - above(ax, 0.085)), above(p.y, 1.53));
	col = mix(col, colors[0].rgb, neck);                       // neck + head
	// arms
	vec3 arm = colors[6].rgb;
	arm = mix(arm, colors[11].rgb, above(ax, 0.3));
	arm = mix(arm, colors[7].rgb, above(ax, 0.47));
	arm = mix(arm, colors[5].rgb, above(ax, 0.665));
	arm = mix(arm, colors[8].rgb, above(ax, 0.735));
	float is_arm = above(ax, 0.2) * above(p.y, 1.22);
	col = mix(col, arm, is_arm);

	float skin = 1.0 - min(distance(col, colors[0].rgb) * 8.0, 1.0);
	float plate = above(p.y, 1.0) * (1.0 - is_arm) * plate_gloss * (1.0 - skin);
	col = mix(col, mix(col, flush_color.rgb, flush), skin);
	float weave = (fract(sin(dot(floor(UV * 900.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.05;
	col *= 1.0 + weave * (1.0 - skin) * (1.0 - plate);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.88, 0.5, skin), 0.3, plate);
	SPECULAR = mix(mix(0.2, 0.35, skin), 0.6, plate);
	BACKLIGHT = col * 0.22 * skin;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * rim * 0.06;
}
