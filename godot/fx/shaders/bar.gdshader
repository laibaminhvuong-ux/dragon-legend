// Billboarded health bar: background, fill from the left, a thin frame. fill/flash per instance.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
instance uniform float fill = 1.0;
instance uniform float flash = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 uv = UV;
	float frame = step(uv.x, 0.012) + step(0.988, uv.x) + step(uv.y, 0.1) + step(0.9, uv.y);
	vec3 back = vec3(0.16, 0.1, 0.13);
	vec3 front = mix(vec3(0.94, 0.43, 0.32), vec3(1.0, 0.85, 0.4), flash);
	vec3 c = uv.x < fill ? front * (0.85 + 0.25 * (1.0 - uv.y)) : back;
	ALBEDO = mix(c, vec3(0.05), clamp(frame, 0.0, 1.0));
}
