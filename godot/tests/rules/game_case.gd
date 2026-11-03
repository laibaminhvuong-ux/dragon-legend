extends TestCase
class Recorder extends RefCounted:
	var log: Array = []
	func emit_named(event: String,value: Dictionary = {}) -> void:
		log.append({"event":event,"value":value.duplicate(true)})
	func count(event: String) -> int:
		return log.filter(func(entry: Dictionary) -> bool:return entry.event==event).size()
func fresh(race: String = "Human",level: int = 1) -> RuleGame:
	var schema := RuleSchema.new()
	var slot: Dictionary = schema.new_slot(schema.default_look(race),1000)
	slot.level = level
	var game := RuleGame.new(0,slot,Recorder.new())
	game.player.pos = Vector3(0,game.zone.height_at(0,0),0)
	game.player.yaw = 0.0
	game.player.onGround = true
	for i in game.combat.enemies.size():
		var enemy: Dictionary = game.combat.enemies[i]
		enemy.pos = Vector3(80+i*10,game.zone.height_at(80+i*10,80),80)
		enemy.home = enemy.pos
	return game
func target(game: RuleGame,distance: float = 1.8) -> Dictionary:
	var enemy: Dictionary = game.combat.enemies[0]
	enemy.pos = game.player.pos+Vector3(0,0,distance)
	enemy.home = enemy.pos
	return enemy
func tick(game: RuleGame,it: Dictionary = {},frames: int = 1) -> void:
	for i in frames:
		game.update(1.0/60,it)
