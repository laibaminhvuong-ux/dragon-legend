class_name FightStyles
extends RefCounted
# Fighting styles (fight flow, 2026-11-04): Turtle School (default), Brawler, Speedster and Crane. Each style is a
# guard stance plus a 4-hit combo, a dash-in and a finisher, written as key poses for MoveClips (PoseModifier
# convention: arm x -1.5 = straight ahead, -3 = straight up; arm z + swings the left arm out / the right arm in;
# fore x - bends the elbow, + straightens it from the guard; thigh x - lifts the leg forward; shin x + bends the knee;
# hips/chest x + leans forward, y twists the body). Every strike is anticipation -> fast strike (contact) ->
# overshoot -> settle back into the guard, with the hips leading the chest, so moves flow into each other.

const IDS := ["turtle", "brawler", "speedster", "crane"]
const NAMES := {"turtle": "Turtle School", "brawler": "Brawler", "speedster": "Speedster", "crane": "Crane"}
## The spec's move names, mapped to their slot in the style's set.
const ALIASES := {   # Codex's stable move ids (docs/fighting-styles-contract.md) -> slot
	"turtle_jab": "combo1", "turtle_cross": "combo2", "turtle_front_kick": "combo3", "turtle_straight_punch": "combo4",
	"turtle_step_in": "dash", "turtle_double_palm_push": "finisher",
	"brawler_wide_hook": "combo1", "brawler_hammer_fist": "combo2", "brawler_shoulder_charge": "combo3", "brawler_uppercut": "combo4",
	"brawler_charge": "dash", "brawler_overhead_slam": "finisher",
	"speedster_jab_flurry": "combo1", "speedster_side_step_knee": "combo2", "speedster_spin_kick": "combo3", "speedster_back_fist": "combo4",
	"speedster_afterimage_blink": "dash", "speedster_blur_rush": "finisher",
	"crane_palm_strike": "combo1", "crane_high_kick": "combo2", "crane_knife_hand": "combo3", "crane_crane_kick": "combo4",
	"crane_gliding_step": "dash", "crane_one_finger_strike": "finisher",
}

static var _moves: Dictionary = {}
static var _library: AnimationLibrary
static var _reactions: Dictionary = {}

static func _add(a: Dictionary, b: Dictionary, w := 1.0) -> Dictionary:
	var out := a.duplicate()
	for k: String in b:
		out[k] = (out.get(k, Vector3.ZERO) as Vector3) + (b[k] as Vector3) * w
	return out

static func _key(t: float, ease: String, pose: Dictionary, lunge := 0.0) -> Dictionary:
	var k := pose.duplicate()
	k.t = t; k.ease = ease; k.lunge = lunge
	return k

## A strike: guard -> wind-up (anticipation) -> hit (fast, eased in) -> overshoot -> settle back into the guard.
static func _strike(guard: Dictionary, windup: Dictionary, hit: Dictionary, length: float, contact: float, lunge: float) -> Dictionary:
	var keys := [
		_key(0.0, "inout", guard),
		_key(contact * 0.55, "out", _add(guard, windup), lunge * 0.1),
		_key(contact, "in", _add(guard, hit), lunge * 0.85),
		_key(minf(length * 0.92, contact + 0.07), "out", _add(_add(guard, hit), hit, 0.12), lunge),
		_key(lerpf(contact, length, 0.6), "inout", _add(guard, hit, 0.35), lunge * 0.95),
		_key(length, "inout", guard, lunge * 0.9),
	]
	return {"length": length, "contact": contact, "keys": keys, "lunge": lunge}

## A move written key by key (offsets relative to the guard; times in seconds).
static func _seq(guard: Dictionary, length: float, contact: float, steps: Array) -> Dictionary:
	var keys := [_key(0.0, "inout", guard)]
	var lunge := 0.0
	for s: Array in steps:
		keys.append(_key(float(s[0]), str(s[1]), _add(guard, s[2]), float(s[3]) if s.size() > 3 else 0.0))
		lunge = maxf(lunge, float(s[3]) if s.size() > 3 else 0.0)
	keys.append(_key(length, "inout", guard, lunge * 0.9))
	return {"length": length, "contact": contact, "keys": keys, "lunge": lunge}

static func _stance(guard: Dictionary, length: float, breath: Dictionary) -> Dictionary:
	return {"length": length, "contact": 0.0, "loop": true, "keys": [
		_key(0.0, "inout", guard), _key(length * 0.5, "inout", _add(guard, breath)), _key(length, "inout", guard)]}

static func moves(style: String) -> Dictionary:
	if _moves.is_empty():
		_build()
	return _moves.get(style, _moves.turtle)

static func _build() -> void:
	var V := func(x: float, y := 0.0, z := 0.0) -> Vector3: return Vector3(x, y, z)
	# ---------------------------------------------------------------- Turtle School: balanced, solid, classic
	var tg := {"hips": V.call(0.05, 0.35), "chest": V.call(0.05, -0.2), "neck": V.call(0, -0.15),
		"armL": V.call(-0.85, 0, -0.3), "foreL": V.call(-1.9), "armR": V.call(-0.7, 0, 0.3), "foreR": V.call(-2.0),
		"thighL": V.call(-0.16, 0, 0.06), "shinL": V.call(0.3), "thighR": V.call(0.1, 0, -0.06), "shinR": V.call(0.28)}
	var turtle := {
		"turtle_stance": _stance(tg, 2.2, {"chest": V.call(-0.04), "armL": V.call(0.05), "armR": V.call(0.05)}),
		"turtle_combo1": _strike(tg, {"armL": V.call(0.25), "foreL": V.call(-0.3), "hips": V.call(0, 0.12)},
			{"armL": V.call(-0.7, 0, 0.2), "foreL": V.call(1.85), "chest": V.call(0.05, -0.25), "hips": V.call(0, -0.12)}, 0.42, 0.16, 0.25),
		"turtle_combo2": _strike(tg, {"hips": V.call(0, 0.18), "armR": V.call(0.2), "chest": V.call(0, 0.15)},
			{"armR": V.call(-0.85, 0, -0.3), "foreR": V.call(1.95), "hips": V.call(0.05, -0.6), "chest": V.call(0.12, -0.3),
				"thighR": V.call(-0.15), "armL": V.call(0.2, 0, 0.1)}, 0.5, 0.2, 0.35),
		"turtle_combo3": _strike(tg, {"thighR": V.call(-0.7), "shinR": V.call(1.3), "hips": V.call(-0.12)},
			{"thighR": V.call(-1.65), "shinR": V.call(-0.3), "hips": V.call(-0.25, -0.2), "armL": V.call(0.3, 0, 0.3), "armR": V.call(0.4, 0, -0.3)},
			0.6, 0.27, 0.3),
		"turtle_combo4": _strike(tg, {"hips": V.call(0, 0.25), "armR": V.call(0.3), "chest": V.call(0, 0.2)},
			{"armR": V.call(-0.9, 0, -0.3), "foreR": V.call(2.0), "hips": V.call(0.1, -0.75), "chest": V.call(0.15, -0.35), "thighR": V.call(-0.3),
				"shinL": V.call(0.2)}, 0.55, 0.22, 0.5),
		"turtle_dash": _strike(tg, {"hips": V.call(-0.05)}, {"hips": V.call(0.5), "chest": V.call(0.2), "armL": V.call(0.5, 0, 0.2),
			"armR": V.call(0.5, 0, -0.2), "thighL": V.call(-0.6), "shinL": V.call(0.6), "thighR": V.call(0.4)}, 0.45, 0.3, 1.0),
		"turtle_finisher": _strike(tg, {"armL": V.call(0.5, 0, 0.3), "armR": V.call(0.5, 0, -0.3), "foreL": V.call(0.2), "foreR": V.call(0.2),
			"hips": V.call(-0.12, 0.2), "thighL": V.call(-0.2), "shinL": V.call(0.4), "shinR": V.call(0.4)},
			{"armL": V.call(-0.7, 0, 0.3), "armR": V.call(-0.85, 0, -0.3), "foreL": V.call(1.9), "foreR": V.call(2.0), "chest": V.call(0.25, 0.2),
				"hips": V.call(0.15, -0.35), "thighL": V.call(-0.35), "shinL": V.call(0.3)}, 0.8, 0.32, 0.7),
	}
	# ---------------------------------------------------------------- Brawler: wide, low, heavy follow-through
	var bg := {"hips": V.call(0.12, 0.2), "chest": V.call(0.22, -0.1), "neck": V.call(-0.15, -0.1),
		"armL": V.call(-0.6, 0, 0.35), "foreL": V.call(-1.4), "armR": V.call(-0.5, 0, -0.35), "foreR": V.call(-1.4),
		"thighL": V.call(-0.18, 0, 0.2), "shinL": V.call(0.45), "thighR": V.call(0.04, 0, -0.2), "shinR": V.call(0.42)}
	var brawler := {
		"brawler_stance": _stance(bg, 2.6, {"chest": V.call(-0.06, 0.04), "armL": V.call(0.06), "armR": V.call(0.06), "shinL": V.call(0.06),
			"shinR": V.call(0.06)}),
		"brawler_combo1": _strike(bg, {"armR": V.call(-0.1, 0, -0.9), "hips": V.call(0, 0.45), "chest": V.call(0, 0.35)},
			{"armR": V.call(-1.0, 0, 0.75), "foreR": V.call(0.8), "hips": V.call(0.05, -0.65), "chest": V.call(0.1, -0.5), "armL": V.call(0.3, 0, 0.3)},
			0.62, 0.3, 0.3),
		"brawler_combo2": _strike(bg, {"armR": V.call(-2.4), "foreR": V.call(0.8), "chest": V.call(-0.3), "armL": V.call(-0.3)},
			{"armR": V.call(-0.5, 0, 0.25), "foreR": V.call(1.2), "chest": V.call(0.5), "hips": V.call(0.2), "neck": V.call(0.1),
				"shinL": V.call(0.3), "shinR": V.call(0.3)}, 0.66, 0.33, 0.2),
		"brawler_combo3": _strike(bg, {"hips": V.call(0, 0.65), "chest": V.call(0.1, 0.4), "armR": V.call(0.2, 0, 0.3)},
			{"hips": V.call(0.35, -0.25), "chest": V.call(0.35, -0.55), "armR": V.call(0.35, 0, 0.45), "armL": V.call(0.4, 0, -0.1),
				"thighL": V.call(-0.4), "shinL": V.call(0.4), "thighR": V.call(0.35)}, 0.7, 0.32, 1.0),
		"brawler_combo4": _strike(bg, {"chest": V.call(0.3, 0.25), "armL": V.call(0.45), "foreL": V.call(0.2), "shinL": V.call(0.35), "shinR": V.call(0.35)},
			{"armL": V.call(-1.9, 0, -0.2), "foreL": V.call(0.4), "chest": V.call(-0.35, -0.35), "hips": V.call(-0.15, -0.2), "neck": V.call(-0.2),
				"shinL": V.call(-0.3), "shinR": V.call(-0.3)}, 0.62, 0.28, 0.3),
		"brawler_dash": _strike(bg, {"chest": V.call(0.1)}, {"hips": V.call(0.35), "chest": V.call(0.3), "armL": V.call(0.1, 0, 0.5),
			"armR": V.call(0.1, 0, -0.5), "thighL": V.call(-0.55), "shinL": V.call(0.5)}, 0.6, 0.4, 0.9),
		"brawler_finisher": _seq(bg, 1.0, 0.52, [
			[0.3, "out", {"armL": V.call(-2.3, 0, -0.35), "armR": V.call(-2.4, 0, 0.35), "foreL": V.call(0.8), "foreR": V.call(0.8),
				"chest": V.call(-0.4), "hips": V.call(-0.15), "neck": V.call(-0.25), "shinL": V.call(-0.3), "shinR": V.call(-0.3)}, 0.05],
			[0.52, "in", {"armL": V.call(-0.3, 0, -0.35), "armR": V.call(-0.4, 0, 0.35), "foreL": V.call(1.2), "foreR": V.call(1.2),
				"chest": V.call(0.65), "hips": V.call(0.3), "thighL": V.call(-0.5), "shinL": V.call(0.9), "thighR": V.call(-0.2), "shinR": V.call(0.9)}, 0.4],
			[0.68, "out", {"armL": V.call(-0.2, 0, -0.4), "armR": V.call(-0.3, 0, 0.4), "foreL": V.call(1.2), "foreR": V.call(1.2),
				"chest": V.call(0.72), "hips": V.call(0.32), "thighL": V.call(-0.55), "shinL": V.call(1.0), "shinR": V.call(1.0)}, 0.42]]),
	}
	# ---------------------------------------------------------------- Speedster: light, bouncing, flurries and spins
	var sg := {"hips": V.call(0.08, 0.25), "chest": V.call(0.1, -0.1), "armL": V.call(-0.55, 0, -0.15), "foreL": V.call(-1.6),
		"armR": V.call(-0.45, 0, 0.15), "foreR": V.call(-1.7), "thighL": V.call(-0.14, 0, 0.05), "shinL": V.call(0.38),
		"thighR": V.call(0.0, 0, -0.05), "shinR": V.call(0.38), "footL": V.call(0.3), "footR": V.call(0.3)}
	var jabL := {"armL": V.call(-0.95, 0, 0.15), "foreL": V.call(1.55), "chest": V.call(0, -0.2), "hips": V.call(0, -0.1)}
	var jabR := {"armR": V.call(-1.05, 0, -0.15), "foreR": V.call(1.65), "chest": V.call(0, 0.2), "hips": V.call(0, 0.05)}
	var spin := func(a: float, extra: Dictionary) -> Dictionary: return _add({"hips": V.call(0, a)}, extra)
	var speedster := {
		"speedster_stance": _stance(sg, 1.6, {"shinL": V.call(0.2), "shinR": V.call(0.2), "chest": V.call(-0.03), "footL": V.call(-0.15),
			"footR": V.call(-0.15)}),
		"speedster_combo1": _seq(sg, 0.48, 0.1, [[0.1, "in", jabL, 0.15], [0.17, "out", {}, 0.18], [0.25, "in", jabR, 0.3],
			[0.32, "out", {}, 0.32], [0.39, "in", jabL, 0.4]]),
		"speedster_combo2": _strike(sg, {"hips": V.call(0, 0.1, 0.25), "thighR": V.call(-0.3)},
			{"thighR": V.call(-1.85), "shinR": V.call(1.9), "hips": V.call(0.12, -0.1, -0.15), "armL": V.call(-0.3, 0, -0.2), "armR": V.call(-0.3, 0, 0.2),
				"foreL": V.call(-0.3), "foreR": V.call(-0.3)}, 0.5, 0.22, 0.4),
		"speedster_combo3": _seq(sg, 0.66, 0.4, [
			[0.12, "out", spin.call(1.6, {"thighR": V.call(-0.4), "shinR": V.call(0.8)}), 0.1],
			[0.26, "linear", spin.call(3.2, {"thighR": V.call(-0.8, 0, -0.8), "shinR": V.call(0.4), "armL": V.call(0, 0, 0.6)}), 0.2],
			[0.4, "linear", spin.call(4.8, {"thighR": V.call(-0.5, 0, -1.45), "shinR": V.call(0.05), "hips": V.call(0, 0, 0.35),
				"armL": V.call(0, 0, 0.8), "armR": V.call(0, 0, -0.5)}), 0.3],
			[0.52, "out", spin.call(6.0, {"thighR": V.call(-0.2), "shinR": V.call(0.4)}), 0.32],
			[0.58, "inout", spin.call(6.2832, {}), 0.32]]),
		"speedster_combo4": _seq(sg, 0.52, 0.25, [
			[0.12, "out", {"hips": V.call(0, 0.9), "chest": V.call(0, 0.4), "armR": V.call(-0.9, 0, 0.6)}, 0.1],
			[0.25, "in", {"hips": V.call(0, -0.4), "chest": V.call(0, -0.5), "armR": V.call(-1.45, 0, -1.2), "foreR": V.call(1.4)}, 0.3],
			[0.33, "out", {"hips": V.call(0, -0.5), "chest": V.call(0, -0.6), "armR": V.call(-1.45, 0, -1.35), "foreR": V.call(1.5)}, 0.32]]),
		"speedster_dash": _strike(sg, {"hips": V.call(-0.1)}, {"hips": V.call(0.55), "chest": V.call(0.25), "armL": V.call(0.7, 0, 0.1),
			"armR": V.call(0.7, 0, -0.1), "thighL": V.call(-0.8), "shinL": V.call(0.9), "thighR": V.call(0.5)}, 0.4, 0.2, 1.2),
		"speedster_finisher": _seq(sg, 1.0, 0.82, [[0.12, "in", jabL, 0.3], [0.22, "in", jabR, 0.5], [0.32, "in", jabL, 0.65],
			[0.42, "in", jabR, 0.8], [0.52, "in", jabL, 0.9], [0.62, "out", {"hips": V.call(0, 0.6), "armR": V.call(0.3)}, 0.95],
			[0.82, "in", {"hips": V.call(0.15, -0.7), "chest": V.call(0.2, -0.35), "armR": V.call(-1.0, 0, -0.3), "foreR": V.call(1.7),
				"thighR": V.call(-0.3)}, 1.2]]),
	}
	# ---------------------------------------------------------------- Crane: low, calm, open palms and high kicks
	var cg := {"hips": V.call(0.02, 0.45), "chest": V.call(-0.05, -0.25), "neck": V.call(0, -0.2),
		"armL": V.call(-1.25, 0, -0.1), "foreL": V.call(-0.35), "armR": V.call(-0.35, 0, 0.35), "foreR": V.call(-1.7),
		"handL": V.call(-0.4), "thighL": V.call(-0.32, 0, 0.05), "shinL": V.call(0.25), "thighR": V.call(0.16, 0, -0.05), "shinR": V.call(0.7),
		"footL": V.call(0.2)}
	var crane := {
		"crane_stance": _stance(cg, 2.8, {"armL": V.call(-0.06, 0, 0.04), "armR": V.call(0.04), "chest": V.call(-0.04), "handL": V.call(0.15)}),
		"crane_combo1": _strike(cg, {"armL": V.call(0.5), "foreL": V.call(-0.9), "hips": V.call(0, 0.15)},
			{"armL": V.call(-0.3, 0, 0.1), "foreL": V.call(0.35), "handL": V.call(-0.6), "chest": V.call(0.1, -0.25), "hips": V.call(0.05, -0.15)},
			0.5, 0.2, 0.35),
		"crane_combo2": _strike(cg, {"thighL": V.call(0.3), "shinL": V.call(0.9), "hips": V.call(-0.1)},
			{"thighL": V.call(-1.9), "shinL": V.call(-0.25), "hips": V.call(-0.35, 0.2), "chest": V.call(-0.15), "armL": V.call(1.0, 0, 0.4),
				"armR": V.call(0.0, 0, -0.6)}, 0.7, 0.32, 0.2),
		"crane_combo3": _strike(cg, {"armR": V.call(-1.9, 0, 0.5), "foreR": V.call(0.6), "chest": V.call(0, 0.4), "hips": V.call(0, 0.15)},
			{"armR": V.call(-0.9, 0, -0.75), "foreR": V.call(1.6), "chest": V.call(0.1, -0.45), "hips": V.call(0, -0.3)}, 0.55, 0.25, 0.3),
		"crane_combo4": _seq(cg, 0.78, 0.4, [
			[0.2, "out", {"armL": V.call(-0.4, 0, 1.2), "armR": V.call(-0.6, 0, -1.2), "foreL": V.call(0.3), "foreR": V.call(1.5),
				"thighR": V.call(-0.7), "shinR": V.call(1.1), "thighL": V.call(0.4)}, 0.15],
			[0.4, "in", {"armL": V.call(-0.6, 0, 1.3), "armR": V.call(-0.8, 0, -1.3), "foreL": V.call(0.3), "foreR": V.call(1.6),
				"thighR": V.call(-2.2), "shinR": V.call(-0.9), "hips": V.call(-0.3), "thighL": V.call(0.45)}, 0.4],
			[0.5, "out", {"armL": V.call(-0.6, 0, 1.35), "armR": V.call(-0.8, 0, -1.35), "foreL": V.call(0.3), "foreR": V.call(1.6),
				"thighR": V.call(-2.3), "shinR": V.call(-0.9), "hips": V.call(-0.32), "thighL": V.call(0.45)}, 0.42]]),
		"crane_dash": _strike(cg, {"hips": V.call(-0.05)}, {"hips": V.call(0.25), "thighL": V.call(-0.3), "shinL": V.call(0.4), "shinR": V.call(0.3),
			"armR": V.call(0.4)}, 0.5, 0.3, 0.8),
		"crane_finisher": _seq(cg, 0.9, 0.42, [
			[0.24, "out", {"armR": V.call(0.7, 0, 0.1), "foreR": V.call(-0.4), "chest": V.call(-0.1, 0.5), "hips": V.call(0, 0.3),
				"armL": V.call(-0.2, 0, 0.3)}, 0.05],
			[0.42, "in", {"armR": V.call(-1.25, 0, -0.35), "foreR": V.call(1.7), "handR": V.call(-0.3), "chest": V.call(0.18, -0.45),
				"hips": V.call(0.1, -0.35), "armL": V.call(0.3, 0, 0.4), "thighL": V.call(-0.2)}, 0.5],
			[0.62, "out", {"armR": V.call(-1.28, 0, -0.38), "foreR": V.call(1.75), "handR": V.call(-0.3), "chest": V.call(0.2, -0.48),
				"hips": V.call(0.12, -0.38), "armL": V.call(0.32, 0, 0.42)}, 0.52]]),
	}
	_moves = {"turtle": turtle, "brawler": brawler, "speedster": speedster, "crane": crane}
	# hit reactions (shared by every style): a short stagger, a knockback (pushed back off the feet), a launch
	var n := {}
	_reactions = {
		"react_stagger": _seq(n, 0.5, 0.1, [[0.1, "out", {"chest": V.call(-0.35, 0.15), "neck": V.call(-0.3), "armL": V.call(-0.4, 0, 0.6),
			"armR": V.call(-0.3, 0, -0.5), "hips": V.call(-0.1), "shinL": V.call(0.3), "shinR": V.call(0.3)}, -0.15],
			[0.3, "inout", {"chest": V.call(-0.12), "neck": V.call(-0.1), "shinL": V.call(0.2), "shinR": V.call(0.2)}, -0.2]]),
		"react_knockback": _seq(n, 0.75, 0.12, [[0.12, "out", {"chest": V.call(-0.55), "neck": V.call(-0.45), "hips": V.call(-0.3),
			"armL": V.call(-1.0, 0, 0.9), "armR": V.call(-1.0, 0, -0.9), "thighL": V.call(-0.5), "thighR": V.call(-0.2), "shinL": V.call(0.4)}, -0.7],
			[0.45, "inout", {"chest": V.call(0.2), "hips": V.call(0.1), "thighL": V.call(-0.4), "shinL": V.call(0.7), "shinR": V.call(0.5),
				"armL": V.call(-0.3, 0, 0.3), "armR": V.call(-0.3, 0, -0.3)}, -0.9]]),
		"react_launch": _seq(n, 0.9, 0.12, [[0.12, "out", {"chest": V.call(-0.7), "neck": V.call(-0.6), "hips": V.call(-0.45),
			"armL": V.call(-1.6, 0, 0.9), "armR": V.call(-1.6, 0, -0.9), "thighL": V.call(-0.9), "thighR": V.call(-0.6), "shinL": V.call(0.8),
			"shinR": V.call(0.6)}, -0.5],
			[0.6, "inout", {"chest": V.call(-0.3), "hips": V.call(-0.2), "thighL": V.call(-0.6), "shinL": V.call(0.9), "shinR": V.call(0.7)}, -0.8]]),
	}

## The clip to play for a style's move: the exact move, else its alias slot, else that style's combo step, else turtle.
static func move_for(style: String, move: String, combo_step: int) -> String:
	if not IDS.has(style):
		style = "turtle"
	var m := moves(style)
	if m.has(move):
		return move
	if ALIASES.has(move) and move.begins_with(style + "_"):
		return "%s_%s" % [style, ALIASES[move]]
	return "%s_combo%d" % [style, clampi(combo_step, 1, 4)]

## Every style's moves as Animations for the fighter rig (built once; all fighters share the skeleton).
static func library(f: Fighter) -> AnimationLibrary:
	if _library != null:
		return _library
	var lib := AnimationLibrary.new()
	var base := MoveClips.base_pose(f.anim_player, f.skeleton, "Idle")
	var fists := MoveClips.hand_pose(f.anim_player, "Punch_Jab", 0.2)
	for style: String in IDS:
		var m := moves(style)
		for id: String in m:
			var mv: Dictionary = m[id]
			# Crane fights with open palms; every other style closes its hands into fists
			lib.add_animation(id, MoveClips.build(f.skeleton, base, mv.keys, float(mv.length), mv.get("loop", false), {} if style == "crane" else fists))
	for id: String in _reactions:
		var mv: Dictionary = _reactions[id]
		lib.add_animation(id, MoveClips.build(f.skeleton, base, mv.keys, float(mv.length)))
	_library = lib
	return lib

## Move data (length, contact, keys) for any clip in the library, styles and reactions alike.
static func data(id: String) -> Dictionary:
	if _moves.is_empty():
		_build()
	if _reactions.has(id):
		return _reactions[id]
	for style: String in IDS:
		if (_moves[style] as Dictionary).has(id):
			return _moves[style][id]
	return {}
