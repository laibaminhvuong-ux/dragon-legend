extends TestCase
# The souls waiting at King Yemmo's desk: they move along the line, fade in at the back, fade out at the desk.
func test_souls_walk_the_line_and_fade_at_both_ends() -> void:
	var q := SoulQueue.create(PackedVector3Array([Vector3(20, 0, 0), Vector3(10, 0, 0), Vector3(0, 0, 0)]))
	eq(q.get_child_count(), SoulQueue.COUNT)
	var first: Vector3 = (q.get_child(0) as Node3D).position
	q._place(2.0)
	ok((q.get_child(0) as Node3D).position.distance_to(first) > 1.0, "souls move")
	for c in q.get_children():
		var s := c as Node3D
		ok(s.position.y > 1.0 and s.position.y < 1.8, "float at chest height")
		ok(s.position.x >= -0.6 and s.position.x <= 20.6, "stay on the line")
	q.free()
