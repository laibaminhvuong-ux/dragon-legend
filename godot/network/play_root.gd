class_name CoopPlayRoot
extends Node
signal left
var client: CoopClient
var session: CoopPlaySession
var gi: GameInput
var canvas: CanvasLayer
var ui: PlayUi
var pending: Dictionary = {}
var _building := false
var _accumulator := 0.0
var status: Label
func begin(connection: CoopClient) -> void:
	client = connection
	client.frame.connect(receive)
	client.disconnected.connect(leave)
	client.failed.connect(show_error)
	gi = GameInput.new(); add_child(gi)
	canvas = CanvasLayer.new(); canvas.layer = 3; add_child(canvas)
	client.command("enter")
	receive(client.latest)
func receive(data: Dictionary) -> void:
	if data.is_empty(): return
	if session==null or session.game.zone.id!=data.map:
		pending = data
		if not _building: _building = true; rebuild.call_deferred()
	else: session.apply_frame(data)
func rebuild() -> void:
	if session!=null: session.shutdown(); session.queue_free(); session = null
	for child in canvas.get_children(): canvas.remove_child(child); child.queue_free()
	session = CoopPlaySession.new(); add_child(session)
	session.start_online(client,pending,gi)
	ui = PlayUi.new(session,gi); canvas.add_child(ui)
	status = Label.new(); status.position = Vector2(20,220); status.text = "Private server · "+client.code+" · Esc to leave"; canvas.add_child(status)
	gi.capture = true
	_building = false
func _process(dt: float) -> void:
	if session==null or _building: return
	var used := ui.handle_input()
	if not used and gi.pressed("pause"):
		leave(); return
	if used: gi.end_tick()
	_accumulator = minf(0.1,_accumulator+dt)
	while _accumulator>=1.0/60: session.step(1.0/60); gi.end_tick(); _accumulator -= 1.0/60
	session.render(dt,clampf(_accumulator*60,0,1)); ui.refresh(dt)
func leave() -> void:
	if client.failed.is_connected(show_error): client.failed.disconnect(show_error)
	if client.frame.is_connected(receive): client.frame.disconnect(receive)
	if client.disconnected.is_connected(leave): client.disconnected.disconnect(leave)
	client.close()
	if gi!=null: gi.capture = false
	if session!=null: session.shutdown(); session = null
	left.emit()
	queue_free()

func show_error(text: String) -> void:
	Events.emit_named("notify",{"text":text})
