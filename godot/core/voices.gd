extends Node
# Autoload "Voices": every character speaks with a voice of their own (port of web/src/audio/voice.js). The OS
# speech voices (Windows has several) are picked and tuned from who the speaker is (female, child, giant or boss,
# race) plus a pitch/speed offset unique to their name. Without speech voices, characters "babble": short
# synthesized syllables in their own pitch and timbre.

const FEMALE_HINTS := ["zira", "hazel", "susan", "eva", "catherine", "linda", "heera", "female", "woman", "aria", "jenny", "michelle",
	"sonia", "libby", "natasha", "clara", "emma", "samantha", "victoria", "karen", "moira", "tessa", "fiona"]
var _who: Dictionary = {}
var _voices: Array = []
var _player: AudioStreamPlayer
var _babble_left := 0

func _ready() -> void:
	_audio()

func _audio() -> AudioStreamPlayer:
	if _player == null:
		_player = AudioStreamPlayer.new()
		add_child(_player)
	return _player

func _load() -> void:
	if not _who.is_empty():
		return
	var chars: Variant = Data.get("characters")
	if chars is Dictionary:
		for c: Dictionary in (chars as Dictionary).values():
			var n := str(c.get("name", ""))
			if n != "" and not _who.has(n):
				var l: Dictionary = c.get("look", {}) if c.get("look") is Dictionary else {}
				_who[n] = {"female": bool(l.get("female", false)), "scale": float(c.get("scale", 1.0)), "race": str(l.get("race", "Human")), "build": str(l.get("build", ""))}
	if DisplayServer.get_name() != "headless":
		var all: Array = DisplayServer.tts_get_voices()
		var en := all.filter(func(v: Dictionary) -> bool: return str(v.get("language", "")).to_lower().begins_with("en"))
		_voices = en if not en.is_empty() else all

static func _hash(s: String) -> float:
	var h := 2166136261
	for ch in s.to_utf8_buffer():
		h = ((h ^ ch) * 16777619) & 0xffffffff
	return float(h) / 4294967295.0

## A voice profile: { female, pitch, rate, timbre, key }.
func profile(speaker: String) -> Dictionary:
	_load()
	var w: Dictionary = _who.get(speaker, {"female": false, "scale": 1.0, "race": "Human", "build": ""})
	if speaker == "You":
		return {"female": false, "pitch": 1.0, "rate": 1.02, "timbre": 0.5, "key": speaker}
	var h := _hash(speaker); var h2 := _hash(speaker + "#")
	var pitch := 1.25 if w.female else 0.95
	var rate := 1.0
	if float(w.scale) < 0.75: pitch += 0.45; rate += 0.08
	if float(w.scale) > 1.3: pitch -= 0.35; rate -= 0.12
	if w.build == "Muscular": pitch -= 0.08
	match str(w.race):
		"FrostDemon": pitch += 0.12; rate -= 0.06
		"Majin": pitch += 0.18; rate += 0.05
		"Namekian": pitch -= 0.1; rate -= 0.04
	pitch += (h - 0.5) * 0.36
	rate += (h2 - 0.5) * 0.2
	return {"female": w.female, "pitch": clampf(pitch, 0.1, 2.0), "rate": clampf(rate, 0.6, 1.4), "timbre": h2, "key": speaker}

func _volume() -> float:
	return float(Settings.get_value("masterVolume")) * float(Settings.get_value("voiceVolume"))

## The system voice for a profile: by gender where the names tell us, then spread by name.
func pick(p: Dictionary) -> String:
	if _voices.is_empty():
		return ""
	var fem := _voices.filter(func(v: Dictionary) -> bool: return _is_female(str(v.name)))
	var male := _voices.filter(func(v: Dictionary) -> bool: return not _is_female(str(v.name)))
	var pool: Array = (fem if p.female else male)
	if pool.is_empty(): pool = _voices
	return str(pool[int(_hash(str(p.key) + "voice") * pool.size()) % pool.size()].id)

static func _is_female(n: String) -> bool:
	var l := n.to_lower()
	for hint: String in FEMALE_HINTS:
		if l.contains(hint): return true
	return false

func say(speaker: String, text: String) -> void:
	if text == "" or _volume() <= 0.0 or not bool(Settings.get_value("voices")):
		return
	_load()
	var p := profile(speaker)
	var line := text.replace("*", "").replace("...", ", ")
	var v := pick(p)
	stop()
	if v == "":
		_babble(p, line)
		return
	DisplayServer.tts_speak(line, v, int(clampf(_volume(), 0.0, 1.0) * 100.0), float(p.pitch), float(p.rate), 0, true)

func stop() -> void:
	if DisplayServer.get_name() != "headless" and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	_audio().stop()

## Fallback: syllable blips shaped like the line, in the speaker's pitch and timbre.
func _babble(p: Dictionary, text: String) -> void:
	if not _audio().is_inside_tree():
		return
	var rate := 22050.0
	var base := 110.0 * pow(2.0, (float(p.pitch) - 0.6) * 1.6) * (1.6 if p.female else 1.0)
	var letters := 0
	for ch in text:
		if ch.to_lower() >= "a" and ch.to_lower() <= "z": letters += 1
	var syl := clampi(roundi(letters / 3.0), 3, 40)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = rate
	gen.buffer_length = 5.0
	_audio().stream = gen
	_player.volume_db = linear_to_db(0.18 * _volume())
	_player.play()
	var pb: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	var timbre := float(p.timbre)
	for i in syl:
		var f := base * (1.0 + 0.18 * sin(i * 1.7 + timbre * 9.0) + (0.25 if i == syl - 1 and text.strip_edges().ends_with("?") else 0.0))
		var n := int(rate * 0.075 / float(p.rate))
		for k in n:
			var tt := float(k) / rate
			var env := minf(1.0, float(k) / (rate * 0.01)) * (1.0 - float(k) / n)
			var ph := fmod(tt * f, 1.0)
			var s := (2.0 * absf(2.0 * ph - 1.0) - 1.0) if timbre < 0.33 else ((1.0 if ph < 0.5 else -1.0) * 0.6 if timbre < 0.66 else (2.0 * ph - 1.0) * 0.5)
			pb.push_frame(Vector2.ONE * s * env * 0.5)
		for k in int(rate * 0.03 / float(p.rate)):
			pb.push_frame(Vector2.ZERO)
