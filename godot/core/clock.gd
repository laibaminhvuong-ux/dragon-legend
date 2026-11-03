extends Node
# Autoload "Clock": the fixed-step simulation clock (same as the JS game's core/loop.js).
# Each frame: `for i in Clock.advance(delta): <one 1/60 s simulation step>`; views interpolate with `alpha`.

const STEP := 1.0 / 60.0
const MAX_STEPS := 5   # after a long hitch, drop time rather than fast-forward
const EPS := 1e-9      # so three 1/180 s frames make exactly one step

var alpha := 0.0       # 0..1: how far between the last two steps the frame is
var _acc := 0.0

## Adds a frame's time and returns how many fixed steps to run now.
func advance(frame_dt: float) -> int:
	_acc += maxf(0.0, frame_dt)
	var n := 0
	while _acc >= STEP - EPS and n < MAX_STEPS:
		_acc -= STEP
		n += 1
	if n == MAX_STEPS and _acc >= STEP - EPS:
		_acc = 0.0
	_acc = maxf(0.0, _acc)
	alpha = clampf(_acc / STEP, 0.0, 1.0)
	return n
