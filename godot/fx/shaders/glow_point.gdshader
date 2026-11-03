// A soft additive glow dot (aura glitter, sparks): billboarded quad with a radial falloff.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a = a * a * (0.5 + 0.5 * step(d, 0.35));
	ALBEDO = tint.rgb * COLOR.rgb * a * 1.5;
}
