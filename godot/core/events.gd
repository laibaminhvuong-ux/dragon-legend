extends Node
# Autoload "Events": the game-wide signal bus. Names and payloads match the JS game's events, so ported
# rules can keep their one-line `emit_named("questAccepted", {id, title})` calls.

signal notify(text: String)
signal dialogue(d: Dictionary)
signal quest_accepted(id: String, title: String)
signal quest_completed(id: String, title: String)
signal quest_progress(id: String, objective: String)
signal travel(zone: String)
signal area_event(kind: String, d: Dictionary)
signal enemy_defeated(d: Dictionary)
signal levelup(level: int, gained: int)
signal stats(hud: Dictionary)
# combat, for views and VFX (payloads carry Vector3 coordinates)
signal attack(d: Dictionary)
signal damage(d: Dictionary)
signal beam(d: Dictionary)
signal avatar_strike(d: Dictionary)
signal zeni_transfer(d: Dictionary)

## Emits a JS-style event: name as in the JS game, payload the same object it sends.
func emit_named(name: String, payload: Variant = null) -> void:
	var d: Dictionary = payload if payload is Dictionary else {}
	match name:
		"notify": notify.emit(String(d.get("text", "")))
		"dialogue": dialogue.emit(d)
		"questAccepted": quest_accepted.emit(String(d.get("id", "")), String(d.get("title", "")))
		"questCompleted": quest_completed.emit(String(d.get("id", "")), String(d.get("title", "")))
		"questProgress": quest_progress.emit(String(d.get("id", "")), String(d.get("objective", "")))
		"travel": travel.emit(String(d.get("zone", "")))
		"enemyDefeated": enemy_defeated.emit(d)
		"levelup": levelup.emit(int(d.get("level", 0)), int(d.get("gained", 0)))
		"stats": stats.emit(d)
		"attack": attack.emit(d)
		"damage": damage.emit(d)
		"beam": beam.emit(d)
		"discovered", "teleport": area_event.emit(name, d)   # open world: a new area found / same-planet travel
		"avatarStrike": avatar_strike.emit(d)
		"zeniTransfer": zeni_transfer.emit(d)
		_: push_warning("Events: unknown event '%s'" % name)
