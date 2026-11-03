class_name QuestDirection
extends Control
# Camera-relative objective indicator, including targets behind the camera.
var play: PlaySession
var caption: Label
var arrow := Vector2.UP
var edge := false
func _init(p: PlaySession) -> void:
	play = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = Label.new(); caption.position = Vector2(-150,20); caption.size = Vector2(300,60)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color",Color("ffe17e"))
	caption.add_theme_constant_override("outline_size",5)
	caption.add_theme_font_size_override("font_size",17)
	add_child(caption)
static func place_marker(screen: Vector2,viewport: Vector2,behind: bool) -> Dictionary:
	var center := viewport*0.5
	var margin := Vector2(minf(90,viewport.x*0.2),minf(110,viewport.y*0.25))
	var half := (center-margin).max(Vector2.ONE)
	var delta := screen-center if screen.is_finite() else Vector2(viewport.x,0)
	if behind: delta = -delta
	if delta.length_squared()<0.01: delta = Vector2.LEFT if behind else Vector2.UP
	var outside: bool = behind or absf(delta.x)>half.x or absf(delta.y)>half.y
	if outside:
		var scale_k: float = maxf(absf(delta.x)/half.x,absf(delta.y)/half.y)
		delta /= maxf(0.0001,scale_k)
	return {"position":center+delta,"direction":delta.normalized(),"edge":outside}
func refresh() -> void:
	visible = false
	if play.game==null or play.game.player.health<=0 or play.camera==null or not play.camera.is_inside_tree() or play.is_frozen(): return
	var route: Variant = play.story.navigation()
	if route==null or not route.has("x"): return
	var target := Vector3(route.x,route.y+1.5,route.z)
	var dist: float = Vector2(target.x-play.game.player.pos.x,target.z-play.game.player.pos.z).length()
	if dist<3 and absf(target.y-play.game.player.pos.y)<4: return
	var behind := play.camera.is_position_behind(target)
	var screen := play.camera.unproject_position(target)
	var marker := place_marker(screen,get_viewport_rect().size,behind)
	position = marker.position
	arrow = marker.direction
	edge = marker.edge
	caption.position.x = -10 if position.x<160 else -290 if position.x>get_viewport_rect().size.x-160 else -150
	caption.text = "%s · %d m%s" % ["Travel pilot" if route.kind=="travel" else "Objective",roundi(dist)," · above" if target.y-play.game.player.pos.y>8 else " · below" if target.y-play.game.player.pos.y< -8 else ""]
	visible = true
	queue_redraw()
func _draw() -> void:
	var color := Color("ffe17e")
	if edge:
		var side := arrow.orthogonal()
		draw_colored_polygon(PackedVector2Array([arrow*13,-arrow*9+side*8,-arrow*9-side*8]),color)
	else:
		draw_polyline(PackedVector2Array([Vector2(-10,-10),Vector2(0,2),Vector2(10,-10)]),color,3,true)
		draw_arc(Vector2.ZERO,17,0,TAU,32,Color(color,0.5),1,true)
