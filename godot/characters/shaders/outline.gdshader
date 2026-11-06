// Ink outline (anime look preview): the mesh again, pushed out along its normals and drawn back-faces only in a
// dark colour, so a thin line shows around the silhouette and where parts overlap. Width stays about the same
// on screen at any distance.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width = 0.0045;
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.08, 1.0);

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float k = clamp(-view_pos.z / 4.0, 0.6, 4.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view_pos.xyz += n * width * k;
	view_pos.z -= 0.03 * k;   // sit slightly behind the body: lines only at the silhouette, none across the face
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = ink.rgb;
}
