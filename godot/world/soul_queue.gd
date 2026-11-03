class_name SoulQueue
extends Node3D
# The line of souls waiting for King Yemmo's judgement: glowing wisps drift along a path to his desk, bob as
# they wait, fade out at the desk and rejoin at the back of the line. Pure decoration (no collision, no rules).

const COUNT := 26
const SPEED := 1.4

var path: Curve3D
var _souls: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _length := 1.0
var _t := 0.0

static func create(points: PackedVector3Array) -> SoulQueue:
	var q := SoulQueue.new()
	q.name = "SoulQueue"
	q.path = Curve3D.new()
	q.path.bake_interval = 0.5
	for i in points.size():
		var p := points[i]
		var tangent := Vector3.ZERO
		if i > 0 and i < points.size() - 1:
			tangent = (points[i + 1] - points[i - 1]) * 0.25
		q.path.add_point(p, -tangent, tangent)
	q._length = maxf(q.path.get_baked_length(), 1.0)
	q._build()
	return q

func _build() -> void:
	var body := SphereMesh.new()
	body.radius = 0.42; body.height = 0.84; body.radial_segments = 16; body.rings = 8
	var tail := CylinderMesh.new()
	tail.top_radius = 0.26; tail.bottom_radius = 0.0; tail.height = 1.1; tail.radial_segments = 12
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = Color(0.55, 0.75, 1.0, 0.72)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in COUNT:
		var s := MeshInstance3D.new()
		s.mesh = body
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := _mat.duplicate() as StandardMaterial3D
		s.material_override = m
		var t := MeshInstance3D.new()
		t.mesh = tail
		var tm := m.duplicate() as StandardMaterial3D
		tm.albedo_color.a = 0.3
		t.material_override = tm
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.position = Vector3(0, -0.15, -0.6)
		t.rotation.x = -PI / 2 - 0.35   # the tail trails behind and a little down, like a wisp
		s.add_child(t)
		add_child(s)
		_souls.append(s)
	_place(0.0)

func _process(dt: float) -> void:
	_t += dt
	_place(_t)

## Positions every soul for time t (also used by tests).
func _place(t: float) -> void:
	var spacing := _length / COUNT
	for i in COUNT:
		var d := fposmod(t * SPEED + i * spacing, _length)
		var s := _souls[i]
		var p := path.sample_baked(d)
		var ahead := path.sample_baked(minf(d + 0.6, _length))
		var phase := float(i) * 1.7
		s.position = p + Vector3(sin(t * 1.3 + phase) * 0.12, 1.4 + sin(t * 2.1 + phase) * 0.18, 0)
		var dir := ahead - p
		if dir.length() > 0.01:
			s.rotation.y = atan2(dir.x, dir.z)
		# fade in at the back of the line, fade out at the desk
		var a := clampf(d / 3.0, 0.0, 1.0) * clampf((_length - d) / 2.5, 0.0, 1.0)
		var m := s.material_override as StandardMaterial3D
		m.albedo_color.a = 0.72 * a
		(s.get_child(0) as MeshInstance3D).transparency = 1.0 - a
		s.scale = Vector3.ONE * (0.6 + 0.4 * a)
