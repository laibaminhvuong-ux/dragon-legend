extends "res://tests/rules/game_case.gd"
func test_held_charge_emits_once_releases_same_sequence_and_preserves_instant_hit() -> void:
	var g := fresh(); var enemy := target(g,9)
	tick(g,{"beam":true},30)
	var before: Dictionary = g.combat.snapshot().skill.duplicate(true)
	eq(before.phase,"prepare"); ok(before.charge>0)
	var prepares: Array = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="attack" and row.value.get("phase")=="prepare")
	eq(prepares.size(),1); near(enemy.health,enemy.maxHealth)
	tick(g)
	var released: Dictionary = g.combat.snapshot().skill
	eq(released.phase,"release"); eq(released.action_sequence,before.action_sequence)
	ok(enemy.health<enemy.maxHealth)
	var impacts: Array = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage")
	ok(not impacts.is_empty()); eq(impacts[0].value.move_id,"EnergyWave")
	eq(impacts[0].value.actor_id,g.player.id); eq(impacts[0].value.target_id,enemy.id)
func test_block_cancel_low_ki_and_projectile_context() -> void:
	var g := fresh()
	tick(g,{"beam":true}); tick(g,{"block":true})
	ok(g.combat.skill.is_empty()); ok(g.player.skillState.is_empty())
	g.player.ki = 0; ok(not g.combat.fire("KiBlast")); ok(g.combat.skill.is_empty())
	g.player.ki = g.player.maxKi; ok(g.combat.fire("KiBlast"))
	var shot: Dictionary = g.combat.projectiles[0]
	eq(shot.move_id,"KiBlast"); eq(shot.presentation.actor_id,g.player.id)
	ok(shot.presentation.has("seed")); ok(shot.presentation.has("pose"))
func test_runtime_presentation_is_not_written_into_fighter_save() -> void:
	var g := fresh(); tick(g,{"beam":true})
	ok(g.player.skillState.has("move_id"))
	var saved := g.to_save()
	ok(not saved.has("skillState")); ok(not saved.has("skill"))

func test_projectile_keeps_original_cast_after_next_skill_and_passives_cost_nothing() -> void:
	var g := fresh(); var enemy := target(g,8)
	ok(g.combat.fire("KiBlast"))
	var context: Dictionary = g.combat.projectiles[0].presentation.duplicate(true)
	g.player.ki = g.player.maxKi
	ok(g.combat.fire("EnergyWave"))
	g.combat.hit(enemy,2,g.player,false,context)
	var impact: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage").back().value
	eq(impact.move_id,"KiBlast"); eq(impact.action_sequence,context.action_sequence)
	var ki: float = g.player.ki
	ok(not g.combat.fire("GodKi")); ok(not g.combat.fire("FusionDance")); near(g.player.ki,ki)

func test_kaioken_overlay_keeps_held_technique_sequence_and_dodge_is_metadata_only() -> void:
	var g := fresh("Saiyan",2000); g.slot.moves.append("Kaioken")
	tick(g,{"beam":true})
	var sequence: int = g.combat.skill.action_sequence
	ok(g.kaioken.toggle()==null); tick(g,{"beam":true})
	eq(g.combat.skill.action_sequence,sequence); eq(g.player.skillState.move_id,"EnergyWave")
	var overlays: Array = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="attack" and row.value.get("move_id")=="Kaioken")
	eq(overlays.size(),1)
	var health: float = g.player.health; g.combat.emit_dodge(); near(g.player.health,health)
	tick(g); eq(g.combat.skill.action_sequence,sequence)

func test_kaioken_and_unavailable_avatar_release_do_not_leave_permanent_charge() -> void:
	var g := fresh("Saiyan",2000); g.slot.moves.append("Kaioken")
	ok(g.combat.set_technique("Kaioken")); tick(g,{"beam":true}); tick(g)
	ok(g.combat.skill.is_empty()); ok(g.player.skillState.is_empty())
	g.combat.begin_skill("UltraInstinctAvatar","prepare")
	ok(not g.combat.fire("UltraInstinctAvatar")); ok(g.combat.skill.is_empty())
