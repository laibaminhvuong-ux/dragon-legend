class_name GameSfx
extends RefCounted
# Non-positional general sounds (UI, progression, pickups, travel) from res://assets/audio/game/ (ElevenLabs
# bank, see manifest.json there). Static API: GameSfx.play(any_node_in_tree, "ui_click"). Voices live on one
# pooled host under the scene root, so a button that frees itself on press still finishes its click.
const DIR := "res://assets/audio/game/"
const SOUNDS := ["ui_click","ui_confirm","ui_back","menu_open","level_up","quest_accept","quest_complete","item_pickup","zeni","boost_ignite","travel_whoosh"]
const ALIASES := {"ui_close":"ui_back"}
const MAX_VOICES := 8
const MIN_REPEAT_MS := 60   # the same sound re-triggered faster than this is dropped (button mashing, coin bursts)
const BUS := "GameSFX"
static var _clips: Dictionary = {}
static var _last: Dictionary = {}

static func clip(id: String) -> AudioStream:
	var key: String = ALIASES.get(id, id)
	if not _clips.has(key):
		var path := DIR + key + ".wav"
		_clips[key] = load(path) if key in SOUNDS and ResourceLoader.exists(path) else null
	return _clips[key]

static func bus() -> String:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		var limiter := AudioEffectLimiter.new(); limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(index, limiter)
	return BUS

static func gain() -> float:
	return float(Settings.get_value("masterVolume")) * float(Settings.get_value("sfxVolume"))

static func _host(tree: SceneTree) -> Node:
	var host := tree.root.get_node_or_null("GameSfxVoices")
	if host == null:
		host = Node.new(); host.name = "GameSfxVoices"
		host.process_mode = Node.PROCESS_MODE_ALWAYS   # menu clicks still sound while the game is paused
		tree.root.add_child.call_deferred(host)
	return host

## Plays a general sound; `volume_db` trims it per call site. Returns false when muted, unknown or throttled.
static func play(owner: Node, id: String, volume_db := 0.0) -> bool:
	if owner == null or not owner.is_inside_tree() or gain() <= 0.001:
		return false
	var stream := clip(id)
	if stream == null:
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -100000)) < MIN_REPEAT_MS:
		return false
	_last[id] = now
	var host := _host(owner.get_tree())
	var voice: AudioStreamPlayer
	for child in host.get_children():
		if child is AudioStreamPlayer and not (child as AudioStreamPlayer).playing:
			voice = child as AudioStreamPlayer; break
	if voice == null:
		if host.get_child_count() >= MAX_VOICES:
			voice = host.get_child(0) as AudioStreamPlayer; voice.stop(); host.move_child(voice, -1)
		else:
			voice = AudioStreamPlayer.new(); voice.bus = bus()
			host.add_child(voice)
	voice.stream = stream
	voice.volume_db = linear_to_db(maxf(0.0001, gain() * 0.7)) + volume_db
	if voice.is_inside_tree(): voice.play()
	else: voice.play.call_deferred()
	return true
