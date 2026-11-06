// Fighter body. CUSTOM0.xyz is the vertex's rest-pose (T-pose) position; the outfit region is chosen per pixel
// from it (rules mirror BodyRegions.region), with borders anti-aliased by fwidth. A region colour with alpha 0
// shows the skin (skin_color), so forms recolour every bare patch at once. The face (eyes, brows, mouth) is
// painted on the front of the head as signed-distance shapes, so expressions and form eye colours cost nothing.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://characters/shaders/outfit_body.gdshaderinc"
