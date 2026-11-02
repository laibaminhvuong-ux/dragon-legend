# Adding your own music

Dragon Legend has its own soundtrack built in: original pieces in the style of 90s anime action scores. You can replace any of them with audio files.

1. Put `.mp3` or `.ogg` files in this folder (`web/assets/music/`).
2. List them in `tracks.json`:

```json
{
  "menu": "title.mp3",
  "zones": { "namek": "namek.mp3", "king_kai": "other-world.mp3" },
  "moods": { "battle": "boss-fight.mp3", "hero": "adventure.mp3" }
}
```

- `menu`: the title screen.
- `zones`: one world. World ids are in `web/src/data/zones.js`, for example `earth_plains`, `namek`, `yardrat`, `lookout`, `htc`, `cell_games`, `beerus_planet` and `world_of_void`.
- `moods`: replaces a built-in track everywhere it plays: `hero`, `alien`, `otherworld`, `training`, `ruins`, `battle` or `calm`. `battle` plays when a villain is near. Which world uses which mood is in `web/src/data/music.js` (`ZONE_MUSIC`).

Files loop. Anything not listed keeps the built-in music.

**Copyright:** the official Dragon Ball soundtracks belong to their owners. The game's repository and releases are public, so only add music you have the rights to share.
