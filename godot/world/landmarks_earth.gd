class_name LandmarksEarth
extends RefCounted
# Extra landmark builders for this world group, called from WorldLandmarks (hook keeps landmarks.gd small).
# Add a type name to TYPES and a match arm in build().

const TYPES: Array[String] = []

static func build(type: String, g: Node3D, zone: RefCounted, l: Dictionary) -> void:
	match type:
		_:
			pass
