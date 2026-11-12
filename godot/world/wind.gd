class_name WorldWind
extends RefCounted
# The world's wind: one direction, strength and gustiness per map, published as shader globals so every shader can
# read it (grass, tree foliage, palm fronds, bushes, character hair, and any landmark shader that wants it):
#   global uniform vec4 wind_field;  // xy: unit direction the wind blows TOWARDS (world x, z); z: strength; w: gustiness
#   global uniform float wind_time;  // wind clock in seconds, advanced in ONE place (advance(), from WorldGrass._process)
# A zone may set biome.wind = {dir, strength, gust}: dir in degrees (0 = towards +x, 90 = towards +z) or [x, z];
# strength 0 (still) .. ~1.5 (gale), 1 = a stiff breeze; gust 0 (steady) .. 1 (very gusty). Missing keys fall back to
# the per-biome defaults below (calm indoors / Other World, stronger on mesas, Earth plains and snow). The "low"
# graphics quality turns wind and hair motion off (everything holds still, nothing is simulated).
# Scripts (fighters' hair, capes) read the same field through vector() / gust_now().

const DEFAULT := {"strength": 0.5, "gust": 0.4}
## Air speed (m/s) a strength-1 wind pushes at; fighters' hair reads wind as moving air like their own motion.
const AIR_SPEED := 7.0
## Realms with little or no weather (the afterlife, divine worlds, pocket dimensions): a faint stir only.
const CALM_PLANETS := ["Other World", "Sacred World", "Other Dimension", "Null Realm", "Time Nexus", "Echo Prison", "Interior"]

static var _globals_ready := false
static var dir := Vector2(1, 0)
static var strength := 0.0
static var gust := 0.0
static var time := 0.0
static var _last_frame := -1
static var _last_tick := -100000
static var _hair_quality := ""   # "" = not read yet; else the Settings quality the hair motion was last checked against
static var _hair_frame := -1

## Registers the shader globals (once). Call before materials that read them are drawn; safe to call often.
static func ensure_globals() -> void:
	if _globals_ready:
		return
	_globals_ready = true
	RenderingServer.global_shader_parameter_add(&"wind_field", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1, 0, 0, 0))
	RenderingServer.global_shader_parameter_add(&"wind_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)

## The wind for a map: {dir: Vector2 (unit), strength: float, gust: float}. biome.wind overrides the defaults.
static func settings_for(zone: Object) -> Dictionary:
	var d: Dictionary = _defaults(zone)
	var biome: Variant = zone.get("biome") if zone != null else null
	var own: Variant = (biome as Dictionary).get("wind") if biome is Dictionary else null
	if own is Dictionary:
		var w: Dictionary = own
		if w.has("strength"):
			d.strength = clampf(float(w.strength), 0.0, 2.0)
		if w.has("gust"):
			d.gust = clampf(float(w.gust), 0.0, 1.0)
		if w.has("dir"):
			d.dir = _dir(w.dir, d.dir)
	return d

static func _defaults(zone: Object) -> Dictionary:
	var id := str(zone.get("id")) if zone != null else ""
	var planet := str(zone.get("planet")) if zone != null else ""
	var def: Variant = zone.get("def") if zone != null else null
	var kind := str((def as Dictionary).get("kind", "")) if def is Dictionary else ""
	var biome: Dictionary = zone.get("biome") if zone != null and zone.get("biome") is Dictionary else {}
	var weather: Variant = biome.get("weather")
	var wtype := str((weather as Dictionary).get("type", "")) if weather is Dictionary else ""
	var mesas: Variant = zone.get("mesas") if zone != null else null
	# a steady direction per map (seeded by its id), so neighbouring maps differ but a map never changes
	var a := deg_to_rad(float(absi(hash(id)) % 360)) if id != "" else 0.6
	var out := {"dir": Vector2(cos(a), sin(a)), "strength": float(DEFAULT.strength), "gust": float(DEFAULT.gust)}
	if kind == "interior" or planet == "Interior":
		out.strength = 0.0; out.gust = 0.0
	elif planet in CALM_PLANETS:
		out.strength = 0.15; out.gust = 0.15
	elif wtype == "snow" or float(biome.get("snowLine", 999.0)) < 0.0 or str(zone.get("ground")) == "snow":
		out.strength = 1.05; out.gust = 0.75   # blizzard country
	elif wtype == "dust" or (mesas is Array and not (mesas as Array).is_empty()):
		out.strength = 0.9; out.gust = 0.65    # mesas and wastelands: hot gusting wind
	elif wtype == "rain":
		out.strength = 0.8; out.gust = 0.6
	elif id == "earth_plains" or str(biome.get("trees", "")) == "palm":
		out.strength = 0.75; out.gust = 0.55   # open plains, sea breeze on the islands
	return out

static func _dir(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		var d := Vector2(float(v[0]), float(v[1]))
		return d.normalized() if d.length() > 0.0001 else fallback
	if v is float or v is int:
		var a := deg_to_rad(float(v))
		return Vector2(cos(a), sin(a))
	return fallback

## Sets the wind for the map being built (WorldGrass.create calls this for every world). Quality "low": no wind.
static func apply(zone: Object, quality := "high") -> void:
	ensure_globals()
	var s := settings_for(zone)
	dir = s.dir
	strength = 0.0 if quality == "low" else float(s.strength)
	gust = float(s.gust)
	_push()

## Advances the wind clock (the single place it moves). Several callers in one frame advance it once.
static func advance(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_frame:
		return
	_last_frame = frame
	ensure_globals()
	time = fmod(time + delta, 3600.0)
	_last_tick = Time.get_ticks_msec()
	RenderingServer.global_shader_parameter_set(&"wind_time", time)

static func _push() -> void:
	RenderingServer.global_shader_parameter_set(&"wind_field", Vector4(dir.x, dir.y, strength, gust))

## 1 ± gust: how hard the wind blows right now (slow swells and quicker gusts).
static func gust_now(t := time) -> float:
	return maxf(0.0, 1.0 + gust * (0.45 * sin(t * 0.83) + 0.35 * sin(t * 2.1 + 1.3)))

## The moving air right now in world space (m/s). Zero when no world is ticking the wind (the character creator,
## menus): hair then reacts to the fighter's own motion only.
static func vector() -> Vector3:
	if strength <= 0.0 or Time.get_ticks_msec() - _last_tick > 500:
		return Vector3.ZERO
	var s := strength * gust_now() * AIR_SPEED
	return Vector3(dir.x * s, 0.0, dir.y * s)

## Hair/cape secondary motion on? Off on the "low" graphics quality (read live from Settings when it exists).
static func hair_motion_enabled() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _hair_frame:   # read once per frame, not once per fighter
		return _hair_quality != "low"
	_hair_frame = frame
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var settings := (loop as SceneTree).root.get_node_or_null("Settings")
		if settings != null and settings.has_method("get_value"):
			_hair_quality = str(settings.get_value("quality"))
	return _hair_quality != "low"
