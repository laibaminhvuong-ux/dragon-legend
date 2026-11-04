shader_type spatial;
// Walk-in building walls and roofs (user request, 2026-11-04): while the player is inside a building, that building
// is cut away above waist height so the camera can see in. inside_building = (x, z, radius, floor y); radius 0 = off.
global uniform vec4 inside_building;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.7;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (inside_building.z > 0.0 && distance(world_pos.xz, inside_building.xy) < inside_building.z && world_pos.y > inside_building.w + 1.25) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
}
