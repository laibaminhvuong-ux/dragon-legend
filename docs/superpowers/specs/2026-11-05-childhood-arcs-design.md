# Childhood arcs (Origins) — design (2026-11-05)

User: "the story is only since Goku is adult. What about when he was a kid. Add every arc since Goku as a kid and these should be first quest."

## Goal
Seven new story chapters covering Gokan's childhood, played BEFORE `m01_arrival`. New saves start at chapter 1; existing saves keep all progress and see the childhood chapters as an optional "Origins" line (no forced replay, no loss). Names follow the project rule: never canon names (use/extend `web/src/data/names.js`-style renames).

## Chapters (renamed)
1. **Emperor Pilav Saga** — Mt. Paozu: meet young Bulna (Dragon Orb radar); Ulong (shape-shifter), Yamcho & Puir in the desert; Ox-Lord's Fire Mountain (Roshu's wave puts out the fire); Emperor Pilav, Mae and Shoo at Pilav's Castle; the full moon and Gokan's Great Ape. Boss: Pilav's robot.
2. **21st World Tournament** — training at Kame House with Master Roshu and Krilan (milk delivery, rock moving); prelims, Gyran, Namu; final vs Jackie Chung.
3. **Red Ribbon Army Saga** — Colonel Silvar; Muscle Tower in the snow (General Whyte, Murasake, Cyborg 8 joins); General Bleu; Mercenary Tau; Korrin Tower climb; storm Red Ribbon HQ (Commander Rudd).
4. **Fortuneteller Baaba** — her five fighters (incl. a mummy and an invisible fighter); the masked fighter = Grandpa Gohin.
5. **22nd World Tournament** — Crane School: Tenzo and Chaozo, Mercenary Tau returns as a cyborg.
6. **King Piccor Saga** — Tamburin attacks the tournament fighters; Korrin's Ultra Divine Water; Yajirobi; Cymbel, Drumm; King Piccor at his castle.
7. **23rd World Tournament / Piccor Jr.** — training at Kamu's Lookout with Mr. Pobo; final vs Piccor Jr.; leads into `m01_arrival`.

## Places (Claude: Earth planet regions + landmarks, rebake Earth)
Mt. Paozu (Gokan's hut), Fire Mountain (burning castle), Pilav's Castle (desert), Muscle Tower (snow), Baaba's Palace, Korrin Tower + Kamu's Lookout (sky), King Piccor's castle, Tournament Island arena (reuse `budokai`). Kame House and Red Ribbon HQ already exist.

## Characters (Claude: looks; Codex: character table rows)
Kid Gokan (small, Power Pole on the back, monkey tail), kid Krilan, young Bulna, Ulong, Puir, Yamcho (young), Ox-Lord (giant), Pilav, Mae, Shoo, Master Roshu/Jackie Chung, Gyran, Namu, Silvar, Whyte, Murasake, Cyborg 8, Bleu, Mercenary Tau, Rudd, Baaba, Grandpa Gohin, Tenzo/Chaozo (young), Tamburin, Cymbel, Drumm, King Piccor, Korrin, Yajirobi, Piccor Jr.

## Ownership
- **Codex:** quests (ids `k01_…`), steps, dialogue, cutscene lines, bosses/levels/rewards, character rows + renames, new-save start at `k01`, `m01_arrival.after` = last childhood quest for NEW saves only, save migration so existing saves are unaffected (childhood line optional), story tests.
- **Claude:** Earth regions/landmarks + rebake, NPC/boss looks (kid Gokan etc.), cutscene presentation, GPU check, builds.
