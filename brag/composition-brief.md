# Hyperframes Composition Brief: Kathalu (iOS)

## Objective
Create a short launch-style brag video for Kathalu, an iPhone app that teaches Telugu speakers to read Telugu.

## Output
- Composition directory: `composition/`
- Rendered video: `brag.mp4`
- Format: landscape — 1920x1080, 30 fps
- Duration: 23.75 seconds

## Source Material
- Project root: `/Users/venkat/code/kathalu-ios` (main, e24a771)
- Primary files read: `CLAUDE.md`, `ROADMAP.md`, `Kathalu/Views/Theme.swift`, `Kathalu/Views/Reader/WordSheetView.swift`, `Kathalu/Models/Syllables.swift`, `Kathalu/Resources/stories.json`, `tools/glossary/review/glossary.json`
- Product name: Kathalu (కథలు)
- Tagline / strongest claim: learn to read the Telugu you already speak
- Key UI to show: real simulator captures in `composition/assets/shots/` (Journey, lesson card, tracing, bookshelf, reader, tapped word, word sheet)
- Copy that must appear verbatim (from the app or its data):
  - the six words and their romanizations and meanings from the glossary: పాలు pālu milk · పిల్లి pilli cat · నీళ్ళు nīḷḷu water · కాకి kāki crow · చెట్టు ceṭṭu tree · పేరు pēru name
  - మా పిల్లి · Our Cat · 25 words

## Creative Direction
- Tone preset: polished
- Creative direction: matter-of-fact, slightly wry, not sentimental
- Interpretation: long holds, one idea per scene, the app's own palette
- Angle: fluent out loud, illiterate on paper; six words go from sounds to shapes and back to readable
- Hook: six romanized cards, "I can say all of these."; they flip to script, "I can't read any of them."
- Outro / punchline: the same cards in script with sound and meaning; "Kathalu — Read what you can already say."
- Avoid: generic SaaS language, abstract filler, any feature not on main (no read-aloud, no fluency chart), sentimental framing

## Visual Identity
- Background #F7F3EA · Text #3A2A10 · Accent #B5531A · Secondary #7A6E58 · Phonetic #8A6000 · Meaning #1A6B3A
- Display font: Georgia · Telugu: Noto Serif Telugu / Noto Sans Telugu (bundled with the app, copied to `assets/fonts/`)
- Visual references: the app's card tiles (cream card, 1px #EFE7D6 border), the syllable tiles, the accent underline of the reader

## Storyboard
Use the storyboard in `brag-plan.md` as the creative contract.
1. Hook — 0.00–5.80 — six cards, two lines, flip at 3.70
2. Reveal — 5.80–8.96 — name, claim, phone lands at 6.34
3. Letters — 8.96–12.65 — lesson, trace, Journey; vowel chips on the beat
4. Words — 12.65–17.91 — tap a word, word sheet, syllable tiles
5. Story — 17.91–20.54 — bookshelf, then the story
6. Outro — 20.54–23.75 — cards decoded, wordmark, claim

## Audio
- Audio role: warm bed, sparse accents
- Music: `assets/music/happy-beats-business-moves-vol-11-by-ende-dot-app.mp3`, volume about 0.28, fade in 0.5 s, fade out 1.5 s
- Music cue guidance: bundled preset `happy-beats-business-moves-vol-11-by-ende-dot-app.music-cues.md`; strong cues 3.70, 6.34, 12.65, 17.91; beats 9.50–11.60 and 15.28–16.34
- Audio-reactive treatment: subtle; background glow follows per-frame RMS (`assets/rms.json`, extracted with ffmpeg + numpy because the Hyperframes media-use helper is not installed here)
- SFX: card slide (flip, sheet), soft impact (phone), click (tap), two light wood taps (tiles), soft drop (result), bell (wordmark)
- SFX analysis guidance: `sfx-analysis.md`; low or medium high-frequency-risk files only

## Hyperframes Instructions
The Hyperframes skills are not installed in this environment, so the composition follows the CLI's own docs (`hyperframes docs compositions|data-attributes|gsap|audio`) and is gated by `hyperframes check`. One root composition hosts one sub-composition (`compositions/film.html`) and the audio clips. Local assets only (GSAP is vendored in `assets/js/`). Render locally.
