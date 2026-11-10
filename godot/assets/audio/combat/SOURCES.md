# Combat sound bank

Generated with the ElevenLabs Sound Effects API (`eleven_text_to_sound_v2`) on the project owner's paid plan; commercial use is permitted under the ElevenLabs Terms of Service. One take per family from `tools/sfx_prompts.json` (generic physical descriptions, no franchise names); `_1` is the processed take, `_2`/`_3` are about +4.5% / -4.5% pitch-speed shifts with a slight brighter/darker tilt.

Built by `python3 tools/elevenlabs_sfx.py build` from the raw takes cached in `art/elevenlabs/raw/` (git-ignored; re-running `generate` never re-pays for a cached take). Processing: stereo downmix, DC block, leading-silence trim and tail fade on one-shots, 0.25 s equal-power crossfade into 2 s seamless loops, then full-clip RMS normalization (one-shots -22 dBFS, loops -24 dBFS) with a look-ahead limiter to the 0.70 / 0.42 peak ceilings.

The previous synthesized bank (`tools/build_combat_audio.py`) is superseded; do not re-run it over this folder.

RMS is not perceptual loudness: a listening pass in game is required.
