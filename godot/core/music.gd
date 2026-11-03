extends Node
# Autoload "Music": the game's original soundtrack (rendered from the web game's synth by tools/render_music.mjs)
# with crossfades between tracks. play() takes a track id ("hero", "battle"...), a world id or "menu".
# Volume follows Settings (masterVolume × musicVolume).

const FADE := 1.6
var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _target_db := [-80.0, -80.0]
var _streams: Dictionary = {}

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k in ["masterVolume", "musicVolume"]: _target_db[_active] = _db())

func _db() -> float:
	var v := float(Settings.get_value("masterVolume")) * float(Settings.get_value("musicVolume"))
	return linear_to_db(maxf(v, 0.0001)) - 4.0

## The track for a world or mood.
static func resolve(id: String) -> String:
	var m: Variant = RuleTables.table("music")
	var tracks: Dictionary = m.get("TRACKS", {}) if m is Dictionary else {}
	if tracks.has(id):
		return id
	var zones: Dictionary = m.get("ZONE_MUSIC", {}) if m is Dictionary else {}
	return str(zones.get(id, "hero"))

func play(id: String) -> void:
	var track := resolve(id)
	if track == current or _players.is_empty():
		return
	var path := "res://assets/music/%s.wav" % track
	if not ResourceLoader.exists(path):
		return
	current = track
	var s: AudioStreamWAV = _streams.get(track) if _streams.has(track) else load(path)
	if s != null and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_streams[track] = s
	_target_db[_active] = -80.0
	_active = 1 - _active
	var p := _players[_active]
	p.stream = s
	p.volume_db = -60.0
	_target_db[_active] = _db()
	p.play()

func stop() -> void:
	current = ""
	_target_db = [-80.0, -80.0]

func _process(dt: float) -> void:
	for i in _players.size():
		var p := _players[i]
		p.volume_db = move_toward(p.volume_db, _target_db[i], dt * 60.0 / FADE)
		if p.playing and p.volume_db <= -79.0 and _target_db[i] <= -80.0:
			p.stop()
