# Dragon Legend

A 3D open-world action RPG inspired by Dragon Ball Z and Super: create a fighter from six races, take quests, level up, unlock transformations and fight through the story arcs.

Downloadable app for Windows (then Android, Mac, Linux). Built with Three.js and packaged with Electron/Capacitor.

Status: in development, with NPC quests, combat, progression and 23 story worlds. See `COLLABORATION.md` for the design, the tech setup and how the team works.

## Action RPG loop

Speak to NPCs with **G** (or your rebound Interact action). A nearby prompt shows the current binding. Choose **Accept quest** in the dialogue, follow the objective beacon, and finish the objective. Enemy objectives require actual combat kills. The quest tracker can track or abandon a quest.

Every world has a **Training Guide** near spawn and a camp of hostile trainees. Patrol contracts are repeatable: defeat three trainees for XP and zeni, level up, then spend stat points in **Skills & stats** or the pause menu. The guide also sells recovery capsules and cosmetic outfits. Use capsules, equip owned outfits, and choose learned techniques in the fighter journal. The selected technique, inventory and quest progress survive saves and travel. Existing saves migrate to schema v4.

Combat: hold **left mouse** for a four-hit melee combo, **right mouse** to guard, **E** for a ki projectile, and hold/release **R** to charge/fire the equipped technique (a starter Energy Wave is available immediately). **Tab** toggles target lock, **Q** dashes, **C** charges ki on the ground, **F** toggles flight, and **Space/Ctrl** ascend/descend. **T** cycles race transformations that you have unlocked through their quests. Enemies telegraph attacks, pursue nearby fighters, return home if lured too far, and respawn. Defeat returns you to the safe spawn without taking away your quests or currency.

Touch has Talk, Skill, Up, Down, Form and Lock buttons as well as movement/combat controls. In dialogue, gamepad Interact/A accepts the focused choice and B/Menu closes it. Keyboard Tab and Enter navigate dialogue normally.

Gameplay checks: `node tools/check_combat.mjs`, `node tools/check_rpg.mjs`, `node tools/check_movement.mjs`, `node tools/check_story.mjs`, `node tools/check_core.mjs`, and `node tools/check_world.mjs`. Browser acceptance: `node tools/check_rpg_smoke.mjs` (same Playwright/Chromium setup as the existing smoke checks); it covers proximity prompts, rebound interaction, quest acceptance, real combat kills, rewards, stat spending and saving.


## Level 2,000 and transformation mastery

The cap is 2,000. Main quests award XP budgeted for ten levels at their difficulty, most side quests four, and repeatable patrol/training quests five; race bonuses still apply. Difficulty and form milestones scale with the larger level range. The story now includes the Galactic Patrol/Moro and Granolah/Planet Cereal chapters. Old saves migrate once: existing levels above 1 scale tenfold, XP-bar progress is retained, and stat points for the added levels are awarded.

Saiyan and Half-Saiyan share their entire form list. Super Saiyan mastery unlocks Grade 2 (mastery level 25), Grade 3 (50), and Full Power (100), sharing the same mastery counter across grades. Full Power is required for Super Saiyan 2. Great Ape mastery level 100 evolves into Golden Great Ape; Golden mastery level 200 evolves into Super Saiyan 4. Super Saiyan 2 mastery level 120 plus the Goku Black/Zamasu milestone unlocks Rage. Active training, landed hits and kills earn mastery; idle menus and death do not.

At level 2,000 both Saiyan races choose one persistent endgame path: Beast, Ultra Instinct or Ultra Ego. UI Sign/Omen, Perfected/Mastered UI, Moro-era mastery training and True UI follow their story milestones. The separately learned UI Sign technique remains a weak temporary dodge focus without transformation stat multipliers.

Use the player menu bar: **Character**, **Accessories**, **Skills**, **Forms**, **Techniques**. Appearance and accessories have a live preview and update the in-world fighter; forms can be selected directly. The Forms page shows unlock requirements and mastery bars. Full details: [RACE_FORMS.md](RACE_FORMS.md). Run `node tools/check_forms.mjs` for progression/mastery rules and `node tools/check_forms_smoke.mjs` for browser menu/customization/form acceptance. `check_visuals.mjs` checks real Three.js scene structure with texture drawing stubbed; it does not replace browser rendering checks.


The **Ultra Instinct Energy Avatar** is an advanced technique on the instinct path. Learn it from Merus after Moro mastery by training in Perfected/True UI, equip it under Techniques, and hold/release **R** while in either full form. It manifests a giant energy projection for 6 seconds, repeatedly attacks a forward area, spends 60 level-scaled base ki, and has a 30-second cooldown. Death or losing the required form ends it. The Forms menu includes a shortcut to equip it; the HUD shows duration/cooldown. Run `node tools/check_avatar.mjs` for its unlock, combat, ki, cooldown and cancellation checks.
