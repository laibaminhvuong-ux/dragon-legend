// Terrain splat: five photo-scanned ground textures (grass, dirt, rock, sand, snow) plus a forest-floor layer,
// blended by per-vertex weights (COLOR, UV2). Rock is projected triplanar on steep slopes so cliffs don't stretch.
// Two sampling scales + a macro noise break up visible tiling. Falls back to flat colours without textures.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool has_textures = false;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 grass_color : source_color = vec4(0.30, 0.48, 0.20, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.45, 0.36, 0.25, 1.0);
uniform vec4 rock_color : source_color = vec4(0.48, 0.46, 0.43, 1.0);
uniform vec4 sand_color : source_color = vec4(0.82, 0.74, 0.55, 1.0);
uniform vec4 snow_color : source_color = vec4(0.92, 0.94, 0.97, 1.0);
uniform vec4 forest_color : source_color = vec4(0.26, 0.33, 0.17, 1.0);
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 dirt_tint : source_color = vec4(1.0);
uniform vec4 rock_tint : source_color = vec4(1.0);
uniform vec4 sand_tint : source_color = vec4(1.0);
uniform float tile = 0.22;        // texture repeats per metre (≈4.5 m per tile)

varying vec3 wpos;
varying vec3 wnorm;
varying vec4 splat;
varying vec2 splat2;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	splat = COLOR;
	splat2 = UV2;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// sample at two scales, the second rotated, blended by a slow noise, to hide the repeat
vec4 tex2(sampler2D t, vec2 uv, float m) {
	vec2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37 + 0.17;
	return mix(texture(t, uv), texture(t, r), 0.35 + m * 0.4);
}
vec4 triplanar(sampler2D t, vec3 p, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0)); b /= (b.x + b.y + b.z);
	return texture(t, p.zy) * b.x + texture(t, p.xz) * b.y + texture(t, p.xy) * b.z;
}

void fragment() {
	vec2 uv = wpos.xz * tile;
	float macro = vnoise(wpos.xz * 0.02) * 0.6 + vnoise(wpos.xz * 0.11) * 0.4;
	float steep = smoothstep(0.82, 0.62, wnorm.y);           // cliffs read as rock regardless of weights
	vec4 w = splat;
	float snow = splat2.x, forest = splat2.y;
	w.b = max(w.b, steep * (1.0 - snow));
	float sum = w.r + w.g + w.b + w.a + snow + 1e-4;
	vec3 albedo; vec3 nrm = vec3(0.5, 0.5, 1.0); float rough = 0.9;
	if (has_textures) {
		// only sample the layers present at this pixel (weights are mostly 0 or 1, so this branches coherently)
		const float EPS = 0.004;
		albedo = vec3(0.0); nrm = vec3(0.0);
		if (w.r > EPS) {
			vec3 g = tex2(grass_albedo, uv, macro).rgb;
			vec3 ng = tex2(grass_normal, uv, macro).rgb;
			if (forest > EPS) {
				g = mix(g, tex2(forest_albedo, uv * 1.3, macro).rgb, forest);
				ng = mix(ng, tex2(forest_normal, uv * 1.3, macro).rgb, forest);
			}
			albedo += g * grass_tint.rgb * w.r; nrm += ng * w.r;
		}
		if (w.g > EPS) { albedo += tex2(dirt_albedo, uv, macro).rgb * dirt_tint.rgb * w.g; nrm += tex2(dirt_normal, uv, macro).rgb * w.g; }
		if (w.b > EPS) { albedo += triplanar(rock_albedo, wpos * tile * 0.6, wnorm).rgb * rock_tint.rgb * w.b; nrm += triplanar(rock_normal, wpos * tile * 0.6, wnorm).rgb * w.b; }
		if (w.a > EPS) { albedo += tex2(sand_albedo, uv, macro).rgb * sand_tint.rgb * w.a; nrm += tex2(sand_normal, uv, macro).rgb * w.a; }
		if (snow > EPS) { albedo += tex2(snow_albedo, uv, macro).rgb * (snow_color.rgb / vec3(0.92, 0.94, 0.97)) * snow; nrm += tex2(snow_normal, uv, macro).rgb * snow; }
		albedo /= sum; nrm /= sum;
		rough = (0.95 * w.r + 0.92 * w.g + 0.85 * w.b + 0.9 * w.a + 0.55 * snow) / sum;
	} else {
		vec3 g = mix(grass_color.rgb, forest_color.rgb, forest) * grass_tint.rgb;
		albedo = (g * w.r + dirt_color.rgb * dirt_tint.rgb * w.g + rock_color.rgb * rock_tint.rgb * w.b
			+ sand_color.rgb * sand_tint.rgb * w.a + snow_color.rgb * snow) / sum;
	}
	albedo *= mix(0.86, 1.12, macro);                      // large-scale light/dark variation
	ALBEDO = albedo;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = rough;
}
