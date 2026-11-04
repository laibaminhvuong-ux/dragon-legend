extends Node
# Runs after tree initialization, so actual stream players (not off-tree mocks) are exercised.
func _ready() -> void: call_deferred("run")
func run() -> void:
	var audio := CombatAudio.new(); add_child(audio)
	for i in 12: audio.start_loop(str(i),"wave_charge",Vector3.ZERO,i)
	assert(audio.loops.size()==CombatAudio.MAX_LOOPS)
	await get_tree().physics_frame
	await get_tree().physics_frame
	audio.set_paused(true)
	for record: Dictionary in audio.loops.values(): assert(record.voice.stream_paused)
	audio.set_paused(false)
	for i in 35: audio.play_cue("hit",Vector3.ZERO,1,i)
	assert(audio.voices.size()==CombatAudio.MAX_VOICES if audio.gain()>.001 else audio.voices.is_empty())
	await get_tree().physics_frame
	await get_tree().physics_frame
	for key: String in audio.loops.keys(): audio.stop_loop(key)
	assert(audio.loops.is_empty())
	audio.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	print("Audio runtime smoke passed: loops, pause/resume, voice caps and teardown."); get_tree().quit(0)
