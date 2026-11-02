# Dragon Legend

A 3D open-world action RPG inspired by Dragon Ball Z and Super: create a fighter from six races, take quests, level up, unlock transformations and fight through the story arcs.

Downloadable app for Windows (then Android, Mac, Linux). Built with Three.js and packaged with Electron/Capacitor.

Status: in development, with NPC quests, combat, progression and 21 story worlds. See `COLLABORATION.md` for the design, the tech setup and how the team works.

## Action RPG loop

Speak to NPCs with **G** (or your rebound Interact action). A nearby prompt shows the current binding. Choose **Accept quest** in the dialogue, follow the objective beacon, and finish the objective. Enemy objectives require actual combat kills. The quest tracker can track or abandon a quest.

Every world has a **Training Guide** near spawn and a camp of hostile trainees. Patrol contracts are repeatable: defeat three trainees for XP and zeni, level up, then spend stat points in **Skills & stats** or the pause menu. The guide also sells recovery capsules and cosmetic outfits. Use capsules, equip owned outfits, and choose learned techniques in the fighter journal. The selected technique, inventory and quest progress survive saves and travel. Existing saves migrate to schema v3.

Combat: hold **left mouse** for a four-hit melee combo, **right mouse** to guard, **E** for a ki projectile, and hold/release **R** to charge/fire the equipped technique (a starter Energy Wave is available immediately). **Tab** toggles target lock, **Q** dashes, **C** charges ki on the ground, **F** toggles flight, and **Space/Ctrl** ascend/descend. **T** cycles race transformations that you have unlocked through their quests. Enemies telegraph attacks, pursue nearby fighters, return home if lured too far, and respawn. Defeat returns you to the safe spawn without taking away your quests or currency.

Touch has Talk, Skill, Up, Down, Form and Lock buttons as well as movement/combat controls. In dialogue, gamepad Interact/A accepts the focused choice and B/Menu closes it. Keyboard Tab and Enter navigate dialogue normally.

Gameplay checks: `node tools/check_combat.mjs`, `node tools/check_rpg.mjs`, `node tools/check_movement.mjs`, `node tools/check_story.mjs`, `node tools/check_core.mjs`, and `node tools/check_world.mjs`. Browser acceptance: `node tools/check_rpg_smoke.mjs` (same Playwright/Chromium setup as the existing smoke checks); it covers proximity prompts, rebound interaction, quest acceptance, real combat kills, rewards, stat spending and saving.
