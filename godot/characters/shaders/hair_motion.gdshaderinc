// Hair secondary motion (shared by hair.gdshader, hair_toon.gdshader and the ink outline, so the line follows the
// moving hair). Hair meshes are built in Hair's head space: the skull centre is about (0, 0.06, 0), radius ~0.105.
// The scalp stays put; spike tips, long locks and ponytails swing more the further they reach from the skull.
// hair_sway (per fighter, set by Fighter from Hair.Motion): xyz = offset of a fully free tip in this mesh's own
// space (lags the fighter's motion, pushed by the wind); w = wind flutter amount. Zero = the rest shape.
// It must be the FIRST instance uniform in every shader that includes this (same instance index in all passes).
instance uniform vec4 hair_sway = vec4(0.0);
global uniform float wind_time;

vec3 hair_motion(vec3 v) {
	vec3 rel = v - vec3(0.0, 0.06, 0.0);
	float w = smoothstep(0.10, 0.32, length(rel));
	float lock = dot(v, vec3(23.0, 17.0, 29.0));   // each spike / lock on its own phase
	vec3 flutter = vec3(sin(wind_time * 7.0 + lock), 0.4 * sin(wind_time * 5.3 + lock * 1.3), cos(wind_time * 6.1 + lock * 0.7));
	return v + (hair_sway.xyz + flutter * hair_sway.w * 0.01) * w;
}
