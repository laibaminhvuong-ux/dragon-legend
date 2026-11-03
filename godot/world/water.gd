class_name WorldWater
extends RefCounted
# Water for worlds with an ocean or a lake (zone.water: {x, z, radius, level, ocean}): a big disc at the exact
# water level with a depth-coloured, wave-normal, reflective shader and a foam line where it meets the shore.

const SHADER := preload("res://world/shaders/water.gdshader")

static func build(zone: RefCounted) -> Node3D:
	if zone.water == null:
		return null
	var w: Dictionary = zone.water
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var disc := CylinderMesh.new()
	var radius: float = zone.size * 2.0 if w.get("ocean", false) else float(w.radius)
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 96
	disc.rings = 1
	mi.mesh = disc
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var col: Variant = zone.biome.get("water")
	if col != null:
		m.set_shader_parameter("deep_color", Color.hex((int(col) << 8) | 0xff))
	mi.material_override = m
	mi.position = Vector3(float(w.get("x", 0)), float(w.level), float(w.get("z", 0)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
