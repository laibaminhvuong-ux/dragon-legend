// Aura lightning: additive, unshaded lines.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
void fragment() { ALBEDO = tint.rgb * 2.0; }
