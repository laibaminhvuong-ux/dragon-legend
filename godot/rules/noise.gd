class_name RuleNoise
extends RefCounted
# Exact JS Mulberry32/gradient-noise port. Gradients deliberately round to Float32 like JS.
class Random32 extends RefCounted:
	var state: int
	func _init(seed_value: int = 1) -> void:
		state = seed_value & 0xffffffff
	func next_float() -> float:
		state = (state + 0x6d2b79f5) & 0xffffffff
		var t: int = ((state ^ (state >> 15)) * (1 | state)) & 0xffffffff
		t = (((t + (((t ^ (t >> 7)) * (61 | t)) & 0xffffffff)) & 0xffffffff) ^ t) & 0xffffffff
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

var _perm := PackedInt32Array()
var _gx := PackedFloat32Array()
var _gy := PackedFloat32Array()
var _period: int

func _init(seed_value: int = 1, period: int = 0) -> void:
	_period = period
	var random := Random32.new(seed_value)
	var p: Array[int] = []
	for i in 256:
		p.append(i)
	for i in range(255, 0, -1):
		var j: int = floori(random.next_float() * (i + 1))
		var temp: int = p[i]
		p[i] = p[j]
		p[j] = temp
	for i in 512:
		_perm.append(p[i & 255])
	for i in 256:
		var a: float = random.next_float() * PI * 2.0
		_gx.append(cos(a))
		_gy.append(sin(a))

static func smooth_step(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func mix_value(a: float, b: float, weight: float) -> float:
	return a + (b - a) * weight

func _wrapped(value: int) -> int:
	return posmod(value, _period) & 255 if _period > 0 else value & 255

static func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

func noise2(x: float, y: float) -> float:
	var xf: int = floori(x)
	var yf: int = floori(y)
	var tx: float = x - xf
	var ty: float = y - yf
	var x0: int = _wrapped(xf)
	var y0: int = _wrapped(yf)
	var x1: int = _wrapped(xf + 1)
	var y1: int = _wrapped(yf + 1)
	var h00: int = _perm[_perm[x0] + y0]
	var h10: int = _perm[_perm[x1] + y0]
	var h01: int = _perm[_perm[x0] + y1]
	var h11: int = _perm[_perm[x1] + y1]
	var d00: float = _gx[h00] * tx + _gy[h00] * ty
	var d10: float = _gx[h10] * (tx - 1.0) + _gy[h10] * ty
	var d01: float = _gx[h01] * tx + _gy[h01] * (ty - 1.0)
	var d11: float = _gx[h11] * (tx - 1.0) + _gy[h11] * (ty - 1.0)
	var u: float = _fade(tx)
	var v: float = _fade(ty)
	return 1.414 * ((d00 + (d10 - d00) * u) + ((d01 + (d11 - d01) * u) - (d00 + (d10 - d00) * u)) * v)

func fbm(x: float, y: float, octaves: int = 5, lacunarity: float = 2.0, gain: float = 0.5) -> float:
	var total: float = 0.0
	var amp: float = 1.0
	var norm: float = 0.0
	var frequency: float = 1.0
	for i in octaves:
		total += noise2(x * frequency, y * frequency) * amp
		norm += amp
		amp *= gain
		frequency *= lacunarity
	return total / norm

func ridged(x: float, y: float, octaves: int = 5) -> float:
	var total: float = 0.0
	var amp: float = 0.5
	var frequency: float = 1.0
	var previous: float = 1.0
	for i in octaves:
		var n: float = 1.0 - absf(noise2(x * frequency, y * frequency))
		n *= n
		total += n * amp * previous
		previous = n
		amp *= 0.5
		frequency *= 2.0
	return total
