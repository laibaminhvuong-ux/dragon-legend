class_name CombatAudio
extends Node3D
# Authored offline WAV bank with variations and layered phase identities. No runtime oscillator generation.
const MAX_VOICES := 24
const MAX_LOOPS := 8
const DIR := "res://assets/audio/combat/"
const ALIASES := {"hit":"impact_light","whoosh":"swing","beam":"wave_release","surge":"transform_release","charge":"charge_loop"}
static var _bank: Dictionary = {}
static var _clips: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var loops: Dictionary = {}
var charge: AudioStreamPlayer3D
var _paused := false
var _charging := false
var _dash := false
var _ground := true
var _variation: Dictionary = {}
static func bank() -> Dictionary:
	if _bank.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR+"manifest.json"))
		_bank = value if value is Dictionary else {}
	return _bank.get("families",{})
static func clip(kind: String,variation: int = 0) -> AudioStreamWAV:
	var key: String = ALIASES.get(kind,kind)
	var entries: Array = bank().get(key,[])
	if entries.is_empty():
		push_error("Missing combat sound family: "+key)
		return AudioStreamWAV.new()
	var entry: Dictionary = entries[posmod(variation,entries.size())]
	var path: String = DIR+entry.file
	if not _clips.has(path):
		var stream: AudioStreamWAV = load(path)
		if entry.loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0; stream.loop_end = int(entry.frames)
		_clips[path] = stream
	return _clips[path]
static func _bus() -> String:
	var index := AudioServer.get_bus_index("CombatSFX")
	if index<0:
		AudioServer.add_bus()
		index = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,"CombatSFX")
		var limiter := AudioEffectLimiter.new(); limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(index,limiter)
	return "CombatSFX"
func gain() -> float:
	return float(Settings.get_value("masterVolume"))*float(Settings.get_value("sfxVolume"))
func _voice() -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.max_distance = 90; voice.unit_size = 6; voice.bus = _bus()
	add_child(voice)
	return voice
func play_cue(kind: String,pos: Vector3,weight := 1.0,seed: int = -1) -> void:
	if gain()<=0.001 or not is_inside_tree(): return
	var key: String = ALIASES.get(kind,kind)
	if not bank().has(key): return
	var selected := seed if seed>=0 else int(_variation.get(key,-1))+1
	_variation[key] = selected
	var voice: AudioStreamPlayer3D
	for v in voices:
		if not v.playing and int(v.get_meta("busy_until",0))<=Time.get_ticks_msec(): voice = v; break
	if voice==null:
		if voices.size()>=MAX_VOICES:
			voice = voices[0]; voices.remove_at(0); voice.stop(); voices.append(voice)
		else: voice = _voice(); voices.append(voice)
	voice.position = to_local(pos); voice.stream = clip(key,selected)
	voice.pitch_scale = clampf(1.06-weight*0.08,0.83,1.12)
	voice.volume_db = linear_to_db(maxf(0.0001,gain()*0.6/sqrt(maxi(1,_playing()/3))))
	voice.set_meta("busy_until",Time.get_ticks_msec()+ceili(voice.stream.get_length()/voice.pitch_scale*1000))
	voice.play()
func _playing() -> int:
	var n := 0
	for v in voices:
		if v.playing or int(v.get_meta("busy_until",0))>Time.get_ticks_msec(): n += 1
	return n
func play_skill(id: String,phase: String,pos: Vector3,seed: int = 0) -> void:
	var profile := SkillCatalog.get_skill(id)
	var cue: String = profile.get("phases",{}).get(phase,{}).get("audio","")
	if cue!="": play_cue(cue,pos,1.0,seed)
func start_loop(key: String,family: String,pos: Vector3,seed: int = 0) -> void:
	if loops.has(key) or not is_inside_tree() or not bank().has(family): return
	if loops.size()>=MAX_LOOPS: stop_loop(str(loops.keys()[0]))
	var voice := _voice(); voice.position = to_local(pos); voice.stream = clip(family,seed)
	voice.volume_db = -70; voice.play()
	loops[key] = {"voice":voice,"level":0.0,"target":1.0}
func update_loop(key: String,pos: Vector3,intensity: float) -> void:
	if not loops.has(key): return
	loops[key].voice.position = to_local(pos)
	loops[key].target = clampf(intensity,0,1)
	loops[key].voice.pitch_scale = .9+clampf(intensity,0,1)*.18
func stop_loop(key: String) -> void:
	if not loops.has(key): return
	var voice: AudioStreamPlayer3D = loops[key].voice
	voice.stop(); voice.stream = null; voice.queue_free(); loops.erase(key)
func update_player(p: Dictionary,pos: Vector3,level: float) -> void:
	var charging: bool = p.get("charging",false) and p.get("health",1)>0
	if charging and not _charging: start_loop("base_charge","charge_loop",pos)
	if not charging and _charging: stop_loop("base_charge")
	if charging and loops.has("base_charge"):
		charge = loops.base_charge.voice
		update_loop("base_charge",pos,.4+clampf(level,0,1)*.6)
	else: charge = null
	if p.get("dashing",false) and not _dash: play_cue("swing",pos)
	if p.get("onGround",true) and not _ground and not p.get("flying",false): play_cue("landing",pos,.8)
	_dash = p.get("dashing",false); _ground = p.get("onGround",true); _charging = charging
func _process(dt: float) -> void:
	for voice in voices: voice.stream_paused = _paused
	for record: Dictionary in loops.values():
		record.voice.stream_paused = _paused
		record.level = lerpf(record.level,record.target,1-exp(-dt*12))
		record.voice.volume_db = linear_to_db(maxf(.0001,gain()*.3*record.level))
func set_paused(paused: bool) -> void:
	_paused = paused
	for voice in voices:
		voice.stream_paused = paused
		voice.volume_db = linear_to_db(maxf(.0001,gain()*.6/sqrt(maxi(1,_playing()/3))))
	for record: Dictionary in loops.values(): record.voice.stream_paused = paused
func stop_all() -> void:
	for voice in voices:
		voice.stop(); voice.stream = null; voice.set_meta("busy_until",0)
	for key: String in loops.keys(): stop_loop(key)
	charge = null; _charging = false; _dash = false
func _exit_tree() -> void:
	stop_all()
