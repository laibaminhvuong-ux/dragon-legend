class_name WorldMap
extends Control
# The world map (N): the loaded map drawn from its terrain grid (sea, grass, sand, rock, snow, shaded by height),
# its areas and towns by name (undiscovered ones as "???"), the quest waypoint and you. The game pauses while it is
# open. Works for planets and single areas alike.

signal opened
signal closed

const SIZE := 256            # pixels per side of the map picture
var play: PlaySession
var is_open := false
var _panel: PanelContainer
var _image: TextureRect
var _overlay: Control
var _title: Label
var _tex_for := ""

func _init(p: PlaySession) -> void:
	play = p
	name = "WorldMap"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.05, 0.07, 0.12, 0.95), 14))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 820)
	_panel.position = Vector2(-380, -410)
	_panel.anchor_left = 0.5; _panel.anchor_top = 0.5; _panel.anchor_right = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -380; _panel.offset_right = 380; _panel.offset_top = -410; _panel.offset_bottom = 410
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_title = UiKit.label("Map", "HeaderLarge")
	v.add_child(_title)
	var box := Control.new()
	box.custom_minimum_size = Vector2(720, 720)
	v.add_child(box)
	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	box.add_child(_image)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	box.add_child(_overlay)
	v.add_child(UiKit.label("N or Esc to close", "Muted"))
	_panel.visible = false

func toggle() -> void:
	if is_open: close()
	else: open()

func open() -> void:
	if not is_open:
		is_open = true
		opened.emit()
	_panel.visible = true
	_title.text = str(play.game.zone.name)
	if _tex_for != str(play.game.zone.id):
		_image.texture = ImageTexture.create_from_image(picture(play.world.get_node("Terrain").get_meta("grid"), play.game.zone))
		_tex_for = str(play.game.zone.id)
	_overlay.queue_redraw()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	closed.emit()

## The map picture from a terrain grid: colour by ground type, light from the north-west by slope.
static func picture(grid: Dictionary, zone: RefCounted) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var half: float = grid.half
	var sea: float = float(zone.water.level) if zone.water != null else -1e9
	for py in SIZE:
		for px in SIZE:
			var x := -half + (px + 0.5) / SIZE * half * 2.0
			var z := half - (py + 0.5) / SIZE * half * 2.0   # north is up
			var s: Dictionary = WorldTerrain.sample(grid, x, z)
			var y: float = s.y
			var c: Color
			if y <= -100.0:
				c = Color(0.08, 0.06, 0.1)
			elif y < sea - 0.02:
				c = Color(0.16, 0.36, 0.62).lerp(Color(0.08, 0.2, 0.42), clampf((sea - y) / 14.0, 0.0, 1.0))
			else:
				c = Color(0.36, 0.6, 0.28) * s.grass + Color(0.55, 0.45, 0.3) * s.dirt + Color(0.5, 0.48, 0.46) * s.rock \
					+ Color(0.86, 0.8, 0.6) * s.sand + Color(0.95, 0.97, 1.0) * s.snow
				var e: float = WorldTerrain.sample(grid, x - 6.0, z + 6.0).y - y
				c = c * clampf(1.0 - e * 0.04, 0.6, 1.25)
			img.set_pixel(px, py, c)
	return img

func _to_map(x: float, z: float) -> Vector2:
	var half: float = float(play.game.zone.size) / 2.0
	var s := _overlay.size
	return Vector2((x + half) / (half * 2.0) * s.x, (half - z) / (half * 2.0) * s.y)

func _draw_overlay() -> void:
	var zone: RuleZone = play.game.zone
	var font := get_theme_default_font()
	var visited: Array = play.game.slot.story.get("visited", [])
	for rid: String in zone.region_ids():
		var at := Vector2.ZERO
		if zone is RulePlanet:
			var r: Dictionary = (zone as RulePlanet).regions[rid]
			at = _to_map(float(r.x), float(r.z))
			_overlay.draw_arc(at, float(r.radius) / float(zone.size) * _overlay.size.x, 0, TAU, 40, Color(1, 1, 1, 0.25), 1.5)
		else:
			at = _to_map(0, 0)
		var known: bool = rid in visited
		var label: String = str(RuleTables.table("zones").get(rid, {}).get("name", rid)) if known else "???"
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_overlay.draw_string_outline(font, at - Vector2(w * 0.5, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
		_overlay.draw_string(font, at - Vector2(w * 0.5, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if known else Color(0.75, 0.78, 0.85))
	var wp: Variant = play.story.waypoint()
	if wp is Dictionary and wp.has("x"):
		var m := _to_map(float(wp.x), float(wp.z))
		_overlay.draw_circle(m, 7, Color(1, 0.75, 0.2))
		_overlay.draw_arc(m, 11, 0, TAU, 24, Color(1, 0.75, 0.2), 2)
	var pp: Vector3 = play.game.player.pos
	var me := _to_map(pp.x, pp.z)
	var yaw: float = play.follow.yaw
	var fwd := Vector2(sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	_overlay.draw_colored_polygon(PackedVector2Array([me + fwd * 12, me - fwd * 7 + side * 7, me - fwd * 7 - side * 7]), Color(1, 0.3, 0.25))
