# The brag video

A 24-second launch video for Kathalu iOS, made with [Hyperframes](https://hyperframes.heygen.com)
on 2026-11-18: `brag.mp4` (1920 × 1080, 30 fps), `brag.jpg` (the poster, baked in as frame 0 so
thumbnails show the six word cards) and `share-copy.txt`. The creative plan is `brag-plan.md`; the
hand-off to Hyperframes is `composition-brief.md`.

The angle: fluent out loud, illiterate on paper. Six everyday words arrive as sounds ("I can say
all of these."), flip to Telugu script ("I can't read any of them."), and come back at the end
readable.

Everything on screen is the app's own:

- **The phone screens** in `composition/assets/shots/` are simulator captures of `main` at
  `e24a771` (iPhone 17 Pro, light mode, 9:41 status bar): the Journey, the అ lesson card, tracing,
  the bookshelf, the story మా పిల్లి, a tapped word and its word sheet.
- **The six words**, their romanizations and meanings come from the glossary
  (`tools/glossary/review/glossary.json`), so they match what the app shows.
- **Colors** are `Theme` tokens and the Telugu fonts are the app's bundled Noto fonts.
- **Drawn for the film, not captures:** the word cards, the vowel chips, the two large syllable
  tiles beside the phone (they mirror the real tiles visible in the phone) and the tap ripple.
- **Demo data:** the learner's progress in the captures (eight vowels learned, a 4-day streak) was
  seeded for the shots.

## Change it

```sh
cd brag/composition
npx hyperframes@0.9.68 preview      # the Studio, to scrub the timeline
npx hyperframes@0.9.68 check        # the gate: lint, runtime, layout, contrast; fix every error
npx hyperframes@0.9.68 render --quality delivery --output ../brag.mp4
```

Then pick the poster frame, bake it as frame 0, and bring the mix up to about −17 LUFS (the raw
render sits near −26). From `brag/`; paste the `measured_*` values the third command prints into
the fourth:

```sh
ffmpeg -y -ss 5.0 -i brag.mp4 -frames:v 1 -q:v 2 brag.jpg
ffmpeg -y -i brag.mp4 -i brag.jpg -filter_complex "[0:v][1:v]overlay=0:0:enable='eq(n,0)'[v]" \
  -map "[v]" -map "0:a?" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a copy \
  -movflags +faststart brag.poster.mp4 && mv brag.poster.mp4 brag.mp4
ffmpeg -i brag.mp4 -af loudnorm=I=-17:TP=-1.5:LRA=7:print_format=json -f null -
ffmpeg -y -i brag.mp4 -c:v copy \
  -af "loudnorm=I=-17:TP=-1.5:LRA=7:measured_I=-25.68:measured_TP=-5.01:measured_LRA=1.90:measured_thresh=-35.76:offset=-0.19" \
  -ar 48000 -c:a aac -b:a 192k -movflags +faststart brag.norm.mp4 && mv brag.norm.mp4 brag.mp4
```

The whole film is one timeline in `composition/compositions/film.html` (the phone persists across
scenes); `index.html` hosts it and the audio clips. Timings marked `beat-locked` and `beat-grid`
follow the music (114.84 BPM; strong cues at 3.70, 6.34, 12.65 and 17.91 s). `assets/rms.json` is
the music's per-frame loudness, which the background glow follows.

**Refreshing a phone screen.** The captures need app states that normally take a tap: an open
lesson, a tapped word, the word sheet. They were taken from a scratch copy of `main` with a few
temporary `UserDefaults` launch arguments added (for example opening `WordSheetItem` in
`ReaderView.onAppear`), on a throwaway simulator, alongside the real `-openTab` / `-openStory`
hooks. Those temporary hooks are not in the repo. Screens are 864 px wide PNGs; the word sheet is
the lower part of its capture, cropped at y = 1158 of 2622.

## Credits

- Music: "Happy Beats / Business Moves Vol. 11" by Sascha Ende, [ende.app](https://ende.app/en),
  [CC BY 4.0](https://ende.app/en/standard-license). Credit it when posting the video.
- Sound effects: [Kenney](https://kenney.nl/), CC0.
- Fonts: Noto Serif Telugu and Noto Sans Telugu (OFL), the app's own.
- GSAP 3.15.0 is vendored in `composition/assets/js/` so the render needs no network.
