# CLAUDE.md

Kathalu iOS — native SwiftUI port of the Kathalu web app (Telugu reading practice:
stories, tap-to-learn words, SM-2 flashcards, script lessons). See `README.md` for the
feature/structure overview and **`ROADMAP.md` for what to build next** — work here is
roadmap-driven, and shipped features get marked ✅ Done there with short as-built notes.

## Build & verify

`xcode-select` points at CommandLineTools, so `xcodebuild` needs a `DEVELOPER_DIR` prefix:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Kathalu.xcodeproj -scheme Kathalu \
  -destination 'platform=iOS Simulator,id=171632C6-2345-4D26-A271-D60B47AD3092' build
```

(That UDID is the local iPhone 17 Pro simulator.)

- **Compile-check only by default.** The user tests behavior on their own device and
  reports back — don't install/launch on the simulator unless the task specifically
  needs runtime observation (e.g. memory sampling) or they ask.
- The project uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77): new files
  anywhere under `Kathalu/` join the target automatically — never edit `project.pbxproj`
  to add files.
- There is no test target.

### DEBUG launch hooks (simctl launch args)

`-openTab <tab>` · `-openStory <idx>` · `-openDeck vowels|consonants|guninthalu|vatthulu`
· `-ttsStress 1` (10k-utterance TTS loop for leak hunting).

## Architecture — the rules that aren't obvious from the code

- Single `@Observable @MainActor` **`AppModel`** injected via `.environment(AppModel.self)`;
  views use `@Environment` + `@Bindable`. Tabs: Library / Learn / Review / Progress / Profile.
- **`SM2.schedule` must match the FastAPI backend's math exactly** — don't touch scheduling;
  add metadata around it instead.
- **Two persistence worlds, kept separate on purpose:**
  - `UserData` (`userdata.json` via `LocalStore`) — vocab cards, streaks, progress. Synced
    write-through by `SyncEngine` when signed in. **Sign-in rebuilds `UserData` from the
    server**, so any field the backend doesn't know about will be wiped.
  - Script-deck SM-2 state (`aksharacards.json` via `AksharaStore`) — deliberately outside
    `UserData` for that reason; local-only. Keys are namespaced: bare letter,
    `gunintha:<vowel>`, `vatthu:<letter>`.
- Simple settings (sound toggle, `speechVoiceID`, `speechRate`, appearance, font size) are
  UserDefaults-backed via `didSet` on AppModel properties. `didSet` doesn't fire during
  init — push loaded values into services at the **end** of `init` (after `sync` is set).
- Script data lives in code (`Models/Akshara.swift`), not JSON. Composite forms are
  **generated**, never tabulated: guninthalu = consonant + mātra, vatthulu/conjuncts =
  base + virama (్) + consonant. `Akshara.spoken` overrides TTS for glyphs the te-IN
  voice mispronounces (e.g. ౠ → "రూ") — extend that mechanism when the user reports a
  bad pronunciation.
- `SpeechService` is the only TTS path; it applies the user's voice/rate per utterance.
  Prefer speaking whole words over bare syllables — the voice handles context better.

## UI conventions

- All colors/fonts come from `Theme` (`Theme.serif` for Telugu, `Theme.latinSerif` for
  romanizations, `Theme.sans`); match existing tiles, sheets, DeckRow, and card-stack
  patterns before inventing new ones. New screens should look like they were always there.
- **Sheet detent gotcha:** present detail drawers with `.sheet(isPresented:)` plus a
  separate selection `@State` (clear it in `onDismiss`), never `.sheet(item:)` — an item
  change re-presents the sheet and resets a compact detent to full height. Pair with
  `.presentationBackgroundInteraction(.enabled(upThrough:))` so charts stay browsable.
- Review-session views (`AksharaReviewView`, `GuninthaluReviewView`, `VatthuluReviewView`)
  take an `embedded` flag so the Review tab's deck picker can host them without their own
  navigation chrome; keep that pattern for new decks.
- Speak only when `model.soundEnabled`; put a `SoundToggleButton` in the toolbar of any
  new screen that talks.

## Known landmines (details in ROADMAP.md Part 2)

- `SyncEngine` is not `@Observable` — the Profile sync pill doesn't live-update.
- `ReaderView.pages` re-paginates on every render; reveal-token IDs shift if font size
  changes mid-read.
- Story completion auto-fires on short stories and inflates streaks.
- MyMemory translation output is unvalidated (feature #1 replaces it).
