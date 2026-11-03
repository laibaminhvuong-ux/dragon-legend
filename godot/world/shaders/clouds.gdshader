// Cloud layers: a high drifting deck in the sky, or a dense sea of clouds below floating worlds.
// Three noise octaves give soft billows; thicker parts are darker underneath, edges catch the sun,
// and the layer fades into the horizon colour with distance.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.68, 0.8, 0.92, 1.0);
uniform float scale = 0.00045;
uniform float coverage = 0.44;     // lower = more cloud
uniform float speed = 0.004;
uniform float fade_start = 900.0;
uniform float fade_end = 3000.0;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz * scale + vec2(TIME * speed, TIME * speed * 0.4);
	float n = texture(noise_tex, p).r * 0.55 + texture(noise_tex, p * 2.7 + 0.3).r * 0.3 + texture(noise_tex, p * 7.1 - TIME * speed * 0.5).r * 0.15;
	float d = smoothstep(coverage, coverage + 0.3, n);
	if (d < 0.01) discard;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(wpos.xz - cam.xz);
	vec3 col = cloud_color.rgb * mix(1.0, 0.75, smoothstep(0.6, 1.0, d));
	col = mix(col, horizon_color.rgb, smoothstep(fade_start, fade_end, dist));
	ALBEDO = col;
	ALPHA = d * 0.94 * (1.0 - smoothstep(fade_end * 0.75, fade_end * 1.1, dist));
}
