class_name CombatAudio
extends Node3D
# Original synthesized sounds, cached once; no downloads or third-party recordings.
const RATE := 22050
const MAX_VOICES := 12
static var _clips: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var charge: AudioStreamPlayer3D
var _charging := false
var _dash := false
var _ground := true
static func clip(kind: String) -> AudioStreamWAV:
	if _clips.has(kind): return _clips[kind]
	var duration := 0.16
	if kind=="beam": duration = 0.6
	if kind=="surge": duration = 0.65
	if kind=="charge": duration = 0.5
	var data := PackedByteArray()
	data.resize(int(duration*RATE)*2)
	var rng := RandomNumberGenerator.new(); rng.seed = 831
	var low := 0.0
	for i in data.size()/2:
		var t := float(i)/RATE
		var p := t/duration
		var noise := rng.randf_range(-1,1)
		low = lerpf(low,noise,0.18)
		var sample := 0.0
		match kind:
			"hit": sample = low*0.8+sin(TAU*(110*t-55*t*t))*0.35
			"guard": sample = sin(TAU*820*t)*0.25+noise*0.14
			"beam": sample = low*0.6+sin(TAU*(150*t+180*t*t))*0.24
			"surge": sample = low*0.65+sin(TAU*65*t)*0.28
			"charge": sample = sin(TAU*90*t)*0.17+sin(TAU*180*t)*0.08+low*0.12
			_: sample = noise*0.35+low*0.35
		var envelope := sin(PI*p) if kind=="charge" else minf(1,t/0.006)*pow(1-p,2.0)
		data.encode_s16(i*2,int(clampf(sample*envelope,-0.9,0.9)*24000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = data
	if kind=="charge":
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = data.size()/2
	_clips[kind] = sound
	return sound
func gain() -> float:
	return float(Settings.get_value("masterVolume"))*float(Settings.get_value("sfxVolume"))
func play_cue(kind: String,pos: Vector3,weight := 1.0) -> void:
	if gain()<=0.001 or not is_inside_tree(): return
	var voice: AudioStreamPlayer3D
	for v in voices:
		if not v.playing:
			voice = v
			break
	if voice==null:
		if voices.size()>=MAX_VOICES: return
		voice = AudioStreamPlayer3D.new()
		voice.max_distance = 65; voice.unit_size = 7
		add_child(voice)
		voices.append(voice)
	voice.position = pos
	voice.stream = clip(kind)
	voice.pitch_scale = clampf(1.1-weight*0.18,0.7,1.2)
	voice.volume_db = linear_to_db(maxf(0.0001,gain()*0.5))
	voice.play()
func update_player(p: Dictionary,pos: Vector3,level: float) -> void:
	var charging: bool = p.get("charging",false) and p.get("health",1)>0
	if charging and charge==null:
		charge = AudioStreamPlayer3D.new()
		charge.stream = clip("charge")
		charge.max_distance = 35; charge.unit_size = 5
		add_child(charge)
	if charge!=null:
		charge.position = pos
		charge.volume_db = linear_to_db(maxf(0.0001,gain()*0.28))
		charge.pitch_scale = 0.85+minf(level,1)*0.3
		if charging and not _charging: charge.play()
		if not charging and _charging: charge.stop()
	if p.get("dashing",false) and not _dash: play_cue("whoosh",pos)
	if p.get("onGround",true) and not _ground and not p.get("flying",false): play_cue("hit",pos,0.5)
	_dash = p.get("dashing",false)
	_ground = p.get("onGround",true)
	_charging = charging
func set_paused(paused: bool) -> void:
	for voice in voices:
		voice.stream_paused = paused
		voice.volume_db = linear_to_db(maxf(0.0001,gain()*0.5))
	if charge!=null: charge.stream_paused = paused
func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	if charge!=null:
		charge.stop()
		charge.stream = null
