# Brag Plan: Kathalu (iOS)

## What is this app?
An iPhone app that teaches people who already speak Telugu to read it: script lessons, then short stories where you can tap any word to hear it and sound it out.

## The angle
Fluent out loud, illiterate on paper. The viewer is shown six everyday words the way a heritage speaker knows them, by sound, and then the same six in Telugu script, where they turn into shapes. No sentiment, no single "special" word: a plain, slightly wry statement of the gap, then the app closing it. The film ends on the same six words, now readable.

## Hook (first 2-3 seconds)
Six word cards land in romanization: pālu, pilli, nīḷḷu, kāki, ceṭṭu, pēru. "I can say all of these." On the strong cue at 3.70 s the cards flip to script (పాలు పిల్లి నీళ్ళు కాకి చెట్టు పేరు): "I can't read any of them."

## Key moments (the middle)
- The first lesson card: అ, "Sounds like the a in about." Then tracing it, then the river Journey with villages done.
- In the story మా పిల్లి, a tap on పిల్లి shows "pilli" above the word.
- The word sheet slides up; its syllable tiles పి and ల్లి light one after the other, then "pilli · cat".
- The bookshelf, then the whole 25-word story.

## Outro / punchline
The six cards again, in script, each with its sound and meaning underneath. "Kathalu" / "Read what you can already say."

## User flow worth showing
Learn a letter (lesson card → trace → Journey) → open a story and tap a word you're stuck on → sound it out from the syllable tiles → read the story.

## Tone
- Preset: polished
- Creative direction: matter-of-fact and a little wry; a heritage speaker stating a fact, not a memory. Explicitly not sentimental (the owner called the previous "I've said this word my whole life" opening corny).
- Interpretation: few scenes, long holds, one idea per scene; warmth comes from the app's own palette, not from the copy.

## Format: landscape — 1920x1080
## Duration: 23.75 seconds

## Visual identity (from the project)
- Background: #F7F3EA (Theme.background)
- Accent: #B5531A (Theme.accent)
- Text: #3A2A10 (Theme.textHeading); secondary #7A6E58; phonetic #8A6000; meaning #1A6B3A
- Display font: Georgia (stands in for the app's system serif, `Theme.latinSerif`)
- Body font: Noto Serif Telugu / Noto Sans Telugu (the app's bundled fonts)
- Strongest visual element: real simulator captures of main (e24a771) in a phone frame; the word-sheet syllable tiles

## Share copy (draft)
I can say పాలు, పిల్లి and నీళ్ళు. I couldn't read any of them. Kathalu is the iPhone app I'm building to fix that.

## Audio direction
- Role: warm bed with sparse professional accents
- Music: happy-beats-business-moves-vol-11-by-ende-dot-app.mp3 (bundled, 114.84 BPM)
- Music treatment: from 0 s, low (about 0.28), 0.5 s fade in, 1.5 s fade out under the wordmark
- Music cue guidance: preset read. Strong cues used: 3.70 s (cards flip to script), 6.34 s (phone lands), 12.65 s (reader scene), 17.91 s (story scene). Beat grid 9.50–11.60 s for the vowel chips; 15.28 / 15.81 / 16.34 s for the two tiles and the result.
- Audio-reactive treatment: subtle; the warm background glow breathes with the music's RMS. No waveform or equalizer visuals.
- SFX posture: sparse, motion-matched
- Audio-coupled moments: card flip, phone landing, the tap on a word, the sheet sliding up, the two syllable tiles, the wordmark
- Restraint rule: nothing on the hook's first line; no sound on every vowel chip

## Storyboard

### Scene 1 — Hook — 5.8s
Six cards in romanization arrive one by one; "I can say all of these." At 3.70 s they flip to Telugu script; "I can't read any of them."
Sequential/interaction: yes — six cards arrive one by one, then flip one after another
Audio intent: calm, then a small turn at the flip
Audio-coupled idea: one card sound on the flip
Transition mood: soft → Scene 2

### Scene 2 — Reveal — 3.16s
"KATHALU · కథలు" / "Learn to read the Telugu you already speak." The phone lands at 6.34 s with the Journey map (fresh).
Sequential/interaction: none
Audio intent: the bed opens up
Audio-coupled idea: soft impact as the phone lands
Transition mood: clean → Scene 3

### Scene 3 — Letters — 3.69s
"One letter at a time." Phone: the అ lesson card → tracing అ → the Journey with two villages done. Five vowel chips (అ ఆ ఇ ఈ ఉ) arrive on consecutive beats.
Sequential/interaction: yes — vowel chips one per beat (glyph accents, not lines to read); screens push like in-app navigation
Audio intent: steady pulse
Audio-coupled idea: none (the beat carries it)
Transition mood: clean → Scene 4

### Scene 4 — Words — 5.26s
"Stuck on a word? Tap it." Phone: మా పిల్లి in the reader; a simulated tap on పిల్లి at 13.70 s shows "pilli". At 14.76 s the real word sheet slides up; "Sound it out, piece by piece."; big tiles పి (15.28) and ల్లి (15.81) light up with "pi" and "lli", then "pilli · cat" (16.34).
Sequential/interaction: yes — simulated tap; two tiles then the result, one per beat, all held 1.2 s after
Audio intent: small, tactile
Audio-coupled idea: click on the tap, card slide for the sheet, two wood taps for the tiles, a soft drop for the result
Transition mood: clean → Scene 5

### Scene 5 — Story — 2.63s
"Then read a whole story." / "మా పిల్లి · Our Cat · 25 words". Phone: the bookshelf, then the story.
Sequential/interaction: none
Audio intent: the bed at its fullest
Audio-coupled idea: none
Transition mood: soft → Scene 6

### Scene 6 — Outro — 3.21s
The six cards in script with sound and meaning under each (pālu · milk …). "Kathalu" / "Read what you can already say." / "కథలు · for iPhone".
Sequential/interaction: yes — the cards return together, captions follow
Audio intent: resolve
Audio-coupled idea: one bell with the wordmark, ringing over the fade
Transition mood: fade out

**Music mood for this video:** upbeat but low in the mix
**Audio summary:** a quiet bed that opens at the reveal, a handful of tactile sounds on real interactions, and one bell on the name.
