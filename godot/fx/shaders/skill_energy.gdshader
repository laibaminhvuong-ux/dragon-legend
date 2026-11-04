shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3,0.8,1.0,1.0);
uniform float intensity = 1.0;
uniform float flow = 3.0;
void fragment() {
 float bands = .65+.35*sin(UV.y*35.0-TIME*flow*6.0+sin(UV.x*19.0)*2.0);
 float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.5);
 ALBEDO = tint.rgb;
 EMISSION = tint.rgb*(1.2+rim*2.0)*intensity;
 ALPHA = tint.a*bands*(.3+.7*rim);
}
