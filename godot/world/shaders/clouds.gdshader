// Cloud layers: a high drifting deck in the sky, a dense sea of clouds below floating worlds, or extra
// layers at other heights (cumulus banks, low valley mist) from biome.cloudLayers.
// Three noise octaves give soft billows; thicker parts are darker underneath, edges catch the sun,
// and the layer fades into the horizon colour with distance. Mist layers (soft_depth > 0) also fade
// where they meet the ground, so a flat layer never shows a hard line against hills.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 cloud_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.68, 0.8, 0.92, 1.0);
uniform float scale = 0.00045;
uniform float coverage = 0.44;     // lower = more cloud
uniform float softness = 0.3;      // width of the cloud edge
uniform float opacity = 0.94;
uniform float shade = 0.75;        // brightness of the thickest parts
uniform float speed = 0.004;
uniform float fade_start = 900.0;
uniform float fade_end = 3000.0;
uniform float soft_depth = 0.0;    // metres: fade where the layer meets geometry (0 = off)
uniform float near_fade = 0.0;     // metres: fade when the camera is this close to the layer's height (0 = off)
uniform vec3 region = vec3(0.0);   // x, z, radius: fade out towards this circle's edge (radius 0 = off)

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz * scale + vec2(TIME * speed, TIME * speed * 0.4);
	float n = texture(noise_tex, p).r * 0.55 + texture(noise_tex, p * 2.7 + 0.3).r * 0.3 + texture(noise_tex, p * 7.1 - TIME * speed * 0.5).r * 0.15;
	float d = smoothstep(coverage, coverage + softness, n);
	if (d < 0.01) discard;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(wpos.xz - cam.xz);
	vec3 col = cloud_color.rgb * mix(1.0, shade, smoothstep(0.6, 1.0, d));
	col = mix(col, horizon_color.rgb, smoothstep(fade_start, fade_end, dist));
	ALBEDO = col;
	float a = d * opacity * (1.0 - smoothstep(fade_end * 0.75, fade_end * 1.1, dist));
	if (region.z > 0.0) {
		a *= 1.0 - smoothstep(region.z * 0.55, region.z, length(wpos.xz - region.xy));
	}
	if (soft_depth > 0.0) {
		float depth = texture(depth_tex, SCREEN_UV).r;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		float scene_z = -vp.z / vp.w;
		a *= clamp((scene_z + VERTEX.z) / soft_depth, 0.0, 1.0);
	}
	if (near_fade > 0.0) {
		a *= smoothstep(0.0, near_fade, abs(cam.y - wpos.y));
	}
	ALPHA = a;
}
