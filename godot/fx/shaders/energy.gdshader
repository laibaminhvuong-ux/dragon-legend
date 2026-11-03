// Ki energy (blasts, beams, avatar): additive, unshaded, a white-hot core fading to the energy colour at the rim.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 energy_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
instance uniform float strength = 1.0;
uniform float core_bias = 0.55;
void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float core = smoothstep(core_bias, 1.0, facing);
	vec3 c = mix(energy_color.rgb, vec3(1.0), core);
	ALBEDO = c * strength * (0.35 + 0.9 * facing);
}
