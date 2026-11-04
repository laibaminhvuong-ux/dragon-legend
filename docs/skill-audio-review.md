# Skill effects and sound listening pass

Launch `godot --path godot res://fx/skill_showcase.tscn`. It uses the real Fighter and current SkillPoses, without opening or writing a fighter save. Arrows select a skill; V changes the sound variant; H keeps gathering active so loops repeat; Q toggles quick taps; Space pauses. Leave H off to advance automatically.

Listen at a comfortable volume, with the camera/distance unchanged between comparisons:

1. **KiBlast / EnergyWave:** compare shot punch versus sustained energy. Check that three variants feel related, release is clear and the tail does not swamp the next shot. Q should still show a brief gather, without delaying the authoritative hit in gameplay.
2. **DestructoDisc / WolfFangFist:** listen for a rotating edge versus physical claw/rush contact. In gameplay, check that the last combo hit has more impact and guard sounds remain distinct. Normal strikes must not all sound like finishers.
3. **InstantTransmission / SpiritBomb:** distinguish departure/arrival from impact, and a large overhead gather from a small hand shot. A SpiritBomb still uses the game's immediate ray/contact timing; the effect must not imply a delayed projectile hit.
4. **Hold H for at least 10 seconds** on each of the six, changing V through all three variants. Listen for clicks, volume dips, repeating thumps or a sudden change in tone every two seconds. Also review **EnergyField, variant 1**: `shield_charge_1.wav` has a measured head/tail energy difference over 6 dB, flagged for listening even though its endpoint samples match. An objective flag is not a claim that a seam was heard.
5. In actual solo/co-op gameplay, check overlapping casts, guarded hits, loud finishers, pause/unpause, cancellation and moving away from the source. Charge loops should remain underneath release/contact sounds; no crackle, volume jump or hanging loop after a cast ends.

Measurements: [bank levels](combat-audio-levels.md), [per-clip JSON](combat-audio-levels.json). Delivered WAVs are normalized to full-clip RMS targets: one-shots -22 dBFS, loops -24 dBFS, with crest compression and peak ceilings. RMS is not perceptual LUFS: brighter or bass-heavy banks may still need listening adjustments. This pass belongs to the user/Claude; automated tests do not certify sound quality.
