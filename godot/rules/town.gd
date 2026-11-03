class_name RuleTown
extends RefCounted
# The layout of an open-world town (landmark type "town"), the same every time from its seed: roads and buildings
# in town-local metres (centre 0,0, +z north). The rules use it for collision, the view draws it (world/town.gd).
# Styles: city (domes and towers round a plaza), village (farm houses, fields, a windmill), snowvillage (log
# cabins), harbor (houses on the island, piers and a lighthouse).

const NoiseRules = preload("res://rules/noise.gd")
static var _cache: Dictionary = {}

## {"roads": [{"x1","z1","x2","z2","w"}], "buildings": [{"kind","x","z","w","d","h","rot","color"}], "extras": [...]}
static func layout(l: Dictionary) -> Dictionary:
	var key := "%s:%s:%s" % [l.get("style", "village"), l.get("seed", 1), l.get("radius", 120)]
	if _cache.has(key):
		return _cache[key]
	var r := NoiseRules.Random32.new(int(l.get("seed", 1)) * 7919 + 13)
	var radius := float(l.get("radius", 120))
	var out := {"roads": [], "buildings": [], "extras": []}
	match str(l.get("style", "village")):
		"city": _city(out, r, radius)
		"harbor": _harbor(out, r, radius)
		"domevillage": _domes(out, r, radius)
		"ruins": _ruins(out, r, radius)
		"garden": _garden(out, r, radius)
		_: _village(out, r, radius, str(l.get("style", "village")))
	_cache[key] = out
	return out

## Circles the rules use for collision: one per building (the smaller side), tall as the building.
static func colliders(l: Dictionary) -> Array:
	var out: Array = []
	var s := float(l.get("scale", 1.0))
	for b: Dictionary in layout(l).buildings:
		var c := cos(float(l.get("rot", 0.0))); var sn := sin(float(l.get("rot", 0.0)))
		var bx := float(b.x) * s; var bz := float(b.z) * s
		out.append({"x": float(l.x) + bx * c + bz * sn, "z": float(l.z) - bx * sn + bz * c,
			"radius": minf(float(b.w), float(b.d)) * 0.5 * s, "height": float(b.h) * s})
	return out

static func _on_road(out: Dictionary, x: float, z: float, margin: float) -> bool:
	for rd: Dictionary in out.roads:
		var a := Vector2(rd.x1, rd.z1); var b := Vector2(rd.x2, rd.z2)
		var p := Vector2(x, z)
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < float(rd.w) * 0.5 + margin:
			return true
	return false

static func _free(out: Dictionary, x: float, z: float, size: float, spacing: float) -> bool:
	for b: Dictionary in out.buildings:
		if Vector2(x - float(b.x), z - float(b.z)).length() < (maxf(float(b.w), float(b.d)) + size) * 0.5 + spacing:
			return false
	return true

static func _city(out: Dictionary, r: NoiseRules.Random32, radius: float) -> void:
	var ring := radius * 0.55
	out.roads.append({"x1": 0.0, "z1": -radius, "x2": 0.0, "z2": radius, "w": 12.0})
	out.roads.append({"x1": -radius, "z1": 0.0, "x2": radius, "z2": 0.0, "w": 12.0})
	for i in 16:   # the ring road as straight pieces
		var a0 := float(i) / 16.0 * TAU; var a1 := float(i + 1) / 16.0 * TAU
		out.roads.append({"x1": cos(a0) * ring, "z1": sin(a0) * ring, "x2": cos(a1) * ring, "z2": sin(a1) * ring, "w": 9.0})
	out.extras.append({"kind": "plaza", "x": 0.0, "z": 0.0, "r": 26.0})
	out.extras.append({"kind": "fountain", "x": 0.0, "z": 0.0})
	var palette := [0xf4efe4, 0xf2e3b8, 0xe8f0f4, 0xf6d9c8, 0xdce8d4, 0xf0f0f0]
	var cell := 24.0
	var n := int(radius / cell)
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var x := gx * cell + (r.next_float() - 0.5) * 6.0
			var z := gz * cell + (r.next_float() - 0.5) * 6.0
			var d := Vector2(x, z).length()
			if d > radius * 0.93 or d < 34.0:
				continue
			var near := 1.0 - d / radius
			var kind := "tower" if near > 0.62 and r.next_float() < 0.7 else ("office" if near > 0.35 and r.next_float() < 0.6 else "dome")
			var w := 0.0; var h := 0.0
			match kind:
				"tower": w = 10.0 + r.next_float() * 6.0; h = 32.0 + r.next_float() * 34.0
				"office": w = 12.0 + r.next_float() * 6.0; h = 12.0 + r.next_float() * 14.0
				_: w = 9.0 + r.next_float() * 5.0; h = 6.0 + r.next_float() * 3.0
			if _on_road(out, x, z, w * 0.5 + 2.0) or not _free(out, x, z, w, 4.0):
				continue
			out.buildings.append({"kind": kind, "x": x, "z": z, "w": w, "d": w, "h": h, "rot": r.next_float() * TAU,
				"color": palette[floori(r.next_float() * palette.size())]})
	for i in 40:   # street lamps along the main roads
		var t := (float(i % 20) / 20.0) * 2.0 - 1.0
		var along := t * radius * 0.9
		if absf(along) < 30.0:
			continue
		out.extras.append({"kind": "lamp", "x": along if i < 20 else 8.0, "z": 8.0 if i < 20 else along})

static func _village(out: Dictionary, r: NoiseRules.Random32, radius: float, style: String) -> void:
	out.roads.append({"x1": 0.0, "z1": -radius, "x2": 0.0, "z2": radius * 0.8, "w": 6.0})
	out.roads.append({"x1": -radius * 0.8, "z1": 10.0, "x2": radius * 0.8, "z2": -10.0, "w": 5.0})
	var snow := style == "snowvillage"
	var palette := [0x9a6a44, 0x8a5a3a, 0x7a4e30] if snow else [0xf2e6c8, 0xe9d3a6, 0xf6f0e0, 0xdcc9a0]
	for attempt in 400:
		if out.buildings.size() >= (14 if snow else 18):
			break
		var a := r.next_float() * TAU
		var d := 16.0 + r.next_float() * radius * 0.78
		var x := cos(a) * d; var z := sin(a) * d
		var w := 7.0 + r.next_float() * 4.0
		if _on_road(out, x, z, w * 0.5 + 2.0) or not _free(out, x, z, w, 6.0):
			continue
		out.buildings.append({"kind": "cabin" if snow else "house", "x": x, "z": z, "w": w, "d": w * (0.7 + r.next_float() * 0.3),
			"h": 3.2 + r.next_float() * 1.2, "rot": r.next_float() * TAU, "color": palette[floori(r.next_float() * palette.size())]})
	if not snow:
		for i in 5:
			var a := r.next_float() * TAU
			var d := radius * (0.55 + r.next_float() * 0.35)
			out.extras.append({"kind": "field", "x": cos(a) * d, "z": sin(a) * d, "w": 18.0 + r.next_float() * 14.0, "d": 12.0 + r.next_float() * 10.0, "rot": r.next_float() * PI})
		for attempt in 50:
			var a := r.next_float() * TAU
			var x := cos(a) * radius * 0.6; var z := sin(a) * radius * 0.6
			if not _on_road(out, x, z, 8.0) and _free(out, x, z, 8.0, 6.0):
				out.buildings.append({"kind": "windmill", "x": x, "z": z, "w": 6.0, "d": 6.0, "h": 14.0, "rot": 0.0, "color": 0xf2ead8})
				break
	else:
		out.extras.append({"kind": "bonfire", "x": 10.0, "z": 14.0})

static func _harbor(out: Dictionary, r: NoiseRules.Random32, radius: float) -> void:
	var cz := 30.0   # the island's centre (see the harbour's terrain recipe)
	out.roads.append({"x1": 0.0, "z1": -40.0, "x2": 0.0, "z2": cz + 70.0, "w": 6.0})
	var palette := [0xf4f0e6, 0xd8e8f2, 0xf2d6c4, 0xe6f0d8, 0xf6e6b0]
	for attempt in 400:
		if out.buildings.size() >= 16:
			break
		var a := r.next_float() * TAU
		var d := 14.0 + r.next_float() * 78.0
		var x := cos(a) * d; var z := cz + sin(a) * d
		var w := 7.0 + r.next_float() * 4.0
		if _on_road(out, x, z, w * 0.5 + 2.0) or not _free(out, x, z, w, 5.0):
			continue
		out.buildings.append({"kind": "house", "x": x, "z": z, "w": w, "d": w * 0.8, "h": 3.4 + r.next_float() * 1.6,
			"rot": r.next_float() * TAU, "color": palette[floori(r.next_float() * palette.size())]})
	out.buildings.append({"kind": "lighthouse", "x": 92.0, "z": cz + 60.0, "w": 6.0, "d": 6.0, "h": 22.0, "rot": 0.0, "color": 0xf4f4f4})
	for i in 3:   # piers into the sea on the south side, with a boat at each
		var x := -50.0 + i * 50.0
		out.extras.append({"kind": "pier", "x": x, "z": cz - 118.0, "len": 34.0})
		out.extras.append({"kind": "boat", "x": x + 6.0, "z": cz - 140.0, "rot": r.next_float() * 0.6})

## Round white houses round a green, with paths (Nameck, Yardran, Grain markets).
static func _domes(out: Dictionary, r: NoiseRules.Random32, radius: float) -> void:
	out.roads.append({"x1": 0.0, "z1": -radius, "x2": 0.0, "z2": radius * 0.7, "w": 5.0})
	out.extras.append({"kind": "plaza", "x": 0.0, "z": 0.0, "r": 14.0})
	var palette := [0xf4f1e6, 0xeef4ea, 0xf2ecdc]
	for attempt in 400:
		if out.buildings.size() >= 14:
			break
		var a: float = r.next_float() * TAU
		var d: float = 22.0 + r.next_float() * radius * 0.7
		var x: float = cos(a) * d
		var z: float = sin(a) * d
		var w: float = 8.0 + r.next_float() * 5.0
		if _on_road(out, x, z, w * 0.5 + 2.0) or not _free(out, x, z, w, 6.0):
			continue
		out.buildings.append({"kind": "dome", "x": x, "z": z, "w": w, "d": w, "h": 6.0 + r.next_float() * 2.0, "rot": r.next_float() * TAU,
			"color": palette[floori(r.next_float() * palette.size())]})

## A wrecked city district: broken towers and blocks, rubble, no roads left.
static func _ruins(out: Dictionary, r: NoiseRules.Random32, radius: float) -> void:
	out.roads.append({"x1": 0.0, "z1": -radius, "x2": 0.0, "z2": radius, "w": 10.0})
	for attempt in 600:
		if out.buildings.size() >= 26:
			break
		var a: float = r.next_float() * TAU
		var d: float = 18.0 + r.next_float() * radius * 0.85
		var x: float = cos(a) * d
		var z: float = sin(a) * d
		var w: float = 9.0 + r.next_float() * 8.0
		if _on_road(out, x, z, w * 0.5 + 2.0) or not _free(out, x, z, w, 5.0):
			continue
		out.buildings.append({"kind": "ruin", "x": x, "z": z, "w": w, "d": w * (0.7 + r.next_float() * 0.3), "h": 6.0 + r.next_float() * 22.0,
			"rot": r.next_float() * TAU, "color": [0x8a8680, 0x9a948a, 0x76726c][floori(r.next_float() * 3)]})
	for i in 30:
		out.extras.append({"kind": "rubble", "x": (r.next_float() * 2.0 - 1.0) * radius * 0.8, "z": (r.next_float() * 2.0 - 1.0) * radius * 0.8, "s": 0.6 + r.next_float() * 1.6})

## Stone shrines among neat fields and trees (Beeros's temple gardens, the Kae's shrine).
static func _garden(out: Dictionary, r: NoiseRules.Random32, radius: float) -> void:
	out.roads.append({"x1": 0.0, "z1": -radius, "x2": 0.0, "z2": radius * 0.35 - 12.0, "w": 5.0})   # the path ends at the main shrine
	out.buildings.append({"kind": "shrine", "x": 0.0, "z": radius * 0.35, "w": 14.0, "d": 14.0, "h": 12.0, "rot": 0.0, "color": 0xd8c9a0})
	for attempt in 300:
		if out.buildings.size() >= 7:
			break
		var a: float = r.next_float() * TAU
		var d: float = 24.0 + r.next_float() * radius * 0.6
		var x: float = cos(a) * d
		var z: float = sin(a) * d
		if _on_road(out, x, z, 6.0) or not _free(out, x, z, 7.0, 8.0):
			continue
		out.buildings.append({"kind": "shrine", "x": x, "z": z, "w": 7.0, "d": 7.0, "h": 6.0, "rot": r.next_float() * TAU, "color": 0xcfc0a0})
	for i in 4:
		var a: float = r.next_float() * TAU
		out.extras.append({"kind": "field", "x": cos(a) * radius * 0.6, "z": sin(a) * radius * 0.6, "w": 16.0, "d": 10.0, "rot": r.next_float() * PI})
