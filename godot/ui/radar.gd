class_name DragonRadar
extends Control
# The Dragon Radar (port of web/src/ui/radar.js): a round green scope showing the orbs still to find, turning with
# the camera so "up" is where you look; out-of-range orbs sit on the rim as arrows. Toggled with the radar key.

const RANGE := 160.0
const SIZE := 190.0
var on := true
var t := 0.0
var here: Array = []
var pos := Vector3.ZERO
var yaw := 0.0
var _read: Label

func _init() -> void:
	name = "Radar"
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	position = Vector2(-SIZE - 24, -SIZE - 110)
	_read = UiKit.label("", "Muted")
	_read.position = Vector2(0, SIZE + 4)
	_read.add_theme_constant_override("outline_size", 4)
	add_child(_read)
	visible = false

func toggle() -> void:
	on = not on
	Events.emit_named("notify", {"text": "Dragon Radar on" if on else "Dragon Radar off"})

func refresh(story: RuleStory, p: Vector3, cam_yaw: float, dt: float, hidden: bool) -> void:
	var r: Variant = story.radar() if story != null else null
	var active := r is Dictionary and (not (r.here as Array).is_empty() or not (r.elsewhere as Array).is_empty())
	visible = active and on and not hidden
	if not visible:
		return
	t += dt
	here = r.here
	pos = p
	yaw = cam_yaw
	var near := INF
	for o: Dictionary in here:
		near = minf(near, Vector2(float(o.x) - p.x, float(o.z) - p.z).length())
	var parts: Array[String] = ["Dragon Radar [%s]" % UiKit.key_name("radar")]
	if not here.is_empty(): parts.append("%d here · nearest %d m" % [here.size(), roundi(near)])
	for e: Dictionary in r.elsewhere:
		parts.append("%d on %s" % [int(e.count), e.name])
	_read.text = "\n".join(parts)
	queue_redraw()

func _draw() -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	var R := SIZE * 0.5 - 6.0
	for i in 12:   # glass disc, dark rim to lighter centre
		var k := 1.0 - i / 12.0
		draw_circle(c, R * k, Color("#0b2e19").lerp(Color("#1f6b3a"), i / 12.0))
	for k in range(-3, 4):
		var o := k / 4.0 * R
		var h := sqrt(maxf(0.0, R * R - o * o))
		draw_line(c + Vector2(o, -h), c + Vector2(o, h), Color(0.63, 1.0, 0.75, 0.28), 1.0)
		draw_line(c + Vector2(-h, o), c + Vector2(h, o), Color(0.63, 1.0, 0.75, 0.28), 1.0)
	draw_arc(c, R + 1.5, 0, TAU, 64, Color("#cfd6dc"), 3.0, true)
	var a := t * 2.2
	for i in 10:   # sweep
		var w := float(i) / 10.0
		draw_line(c, c + Vector2.from_angle(a - w * 0.5) * R, Color(0.55, 1.0, 0.67, 0.3 * (1.0 - w)), 3.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(-7, 7), c + Vector2(0, 3), c + Vector2(7, 7)]), Color("#e9fff0"))
	var fx := sin(yaw); var fz := cos(yaw)
	var blink := 0.55 + 0.45 * sin(t * 6.0)
	for o: Dictionary in here:
		var dx := float(o.x) - pos.x; var dz := float(o.z) - pos.z
		var fwd := dx * fx + dz * fz
		var right := dx * -fz + dz * fx
		var p := Vector2(right / RANGE * R, -fwd / RANGE * R)
		var edge := p.length() > R - 12.0
		if edge:
			p = p.normalized() * (R - 12.0)
			var ang := p.angle()
			var tri := PackedVector2Array([Vector2(10, 0), Vector2(-6, -7), Vector2(-6, 7)])
			for j in 3: tri[j] = c + p + tri[j].rotated(ang)
			draw_colored_polygon(tri, Color(1.0, 0.78, 0.16, 0.6 + 0.4 * blink))
		else:
			draw_circle(c + p, 11.0 * blink + 4.0, Color(1.0, 0.69, 0.0, 0.25))
			draw_circle(c + p, 8.0, Color("#ffcc33"))
			draw_circle(c + p + Vector2(-2.5, -2.5), 2.6, Color("#fff6c8"))
