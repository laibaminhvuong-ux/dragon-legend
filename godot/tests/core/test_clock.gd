extends TestCase
# Clock: fixed 1/60 s steps, at most 5 per frame; after a hitch the leftover time is dropped.

func _clock() -> Node:
	return load("res://core/clock.gd").new()

func test_one_step_per_sixtieth() -> void:
	var c := _clock()
	eq(c.advance(1.0 / 60.0), 1)
	c.free()

func test_accumulates() -> void:
	var c := _clock()
	eq([c.advance(1.0 / 180.0), c.advance(1.0 / 180.0), c.advance(1.0 / 180.0)], [0, 0, 1])
	c.free()

func test_hitch_capped_and_dropped() -> void:
	var c := _clock()
	eq(c.advance(2.0), 5, "a 2 s hitch runs at most 5 steps")
	eq(c.advance(0.0), 0, "the rest is dropped, no fast-forward")
	c.free()

func test_alpha_range() -> void:
	var c := _clock()
	c.advance(1.0 / 120.0)
	near(c.alpha, 0.5, 1e-6, "half a step")
	c.advance(10.0)
	ok(c.alpha >= 0.0 and c.alpha <= 1.0, "alpha stays in 0..1")
	c.free()
