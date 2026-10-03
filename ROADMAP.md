# Kathalu iOS — Roadmap & Tech Debt

A planning reference for future work. Two parts:
1. **Proposed features**, ordered by the product priority we agreed on.
2. **Bugs & existing issues** worth fixing, ordered by severity.

Last reviewed 28 Jul 2026 (iPad readable-layout pass + Apple Pencil writing practice queued as #12/#13; Journey scroll fixed via iOS 18 `ScrollPosition`). Earlier: the Journey design spike (cartoon-river prototypes, DEBUG-only under `Views/Learn/Prototypes/`). Shipped so far: the Learn tab with reference charts + SM-2 drills for vowels, consonants, guninthalu, and vatthulu (feature #2, phases 1–4); TTS voice & speed customization (feature #5); global sound toggle and the Review-tab deck picker. Next up: the Journey lesson path (#2 phase 5 — design locked, phased plan in that section); dictionary work (#1) queued behind it.

**Effort key:** S ≈ ½–1 day · M ≈ 2–4 days · L ≈ 1–2 weeks · XL ≈ multi-week / new target.

---

## Part 1 — Feature roadmap (prioritized)

### 1. Own glossary / dictionary — accurate, local-first, DB-backed
**Priority: highest.** Meanings currently come only from the free MyMemory API — online-only, rate-limited, and frequently low-quality or an echo of the input. Every bad gloss also poisons the review deck. The goal is to **own our dictionary data** rather than depend on a translation endpoint.

**What to build**
- A first-class `WordEntry` model: `telugu`, `transliteration`, one or more `senses` (English gloss + optional part-of-speech, notes), and provenance (`curated` / `community` / `mymemory`).
- **Local-first lookup order:** (1) bundled dictionary → (2) user/cloud cache → (3) MyMemory fallback, with the result written back so each word is only ever fetched once.
- **Seed the dictionary from the stories themselves.** We already tokenize every story (`Story.words`, `TeluguText`). Generate the full unique word list across `stories.json`, machine-translate once as a *starting draft*, then curate. This bounds the problem to the vocabulary that actually appears in the app.

**Where the data lives — two complementary layers**
- **Bundled `Resources/dictionary.json`** shipped with the app: instant, offline, and the source of truth for the curated core vocabulary.
- **Backend dictionary table** (extends the existing FastAPI service): lets us improve entries without an app release, and enables a **community/crowdsourced** loop — users suggest or correct meanings, we moderate, corrections sync down to everyone. `APIClient`/`SyncEngine` already give us the auth + sync plumbing to extend.

**Approach notes**
- Better source data than MyMemory for the curation pass: Charles Philip Brown Telugu–English dictionary, Andhra Bharati, or Wiktionary dumps — richer and license-checkable.
- Validate/clean any machine output (strip provider warnings, drop glosses equal to the input, lowercase consistently).
- Model `senses` as a list from day one so a word can carry multiple meanings (needed for feature #6).

**Effort: L.** Phase it: (a) `WordEntry` model + local bundled lookup + fallback rewrite (M); (b) generate & curate the story-vocabulary seed (M, mostly data work); (c) backend table + community submit/moderate loop (M–L, optional follow-on).
**Files:** new `Models/WordEntry.swift`, `Resources/dictionary.json`, `Services/DictionaryService.swift` (replaces/absorbs `TranslationService`), `WordSheetView`, `APIClient`/`SyncEngine` for the DB layer.

### 2. Aksharamala — learn the Telugu script (vowels, consonants, guninthalu, vatthulu)
**Priority: high. Effort: XL — a whole new learning pillar. Status: phases 1–4 shipped; only the gamified lesson path (phase 5) remains.** Kathalu today assumes you can already read the script; it teaches *vocabulary in context*. A dedicated **Learn** section that teaches the writing system from the ground up opens the app to true beginners and gives existing readers a way to shore up gaps — especially guninthalu and vatthulu, which trip up most learners.

**The script, and what we'd cover**
- **Vowels — అచ్చులు (achchulu):** the ~16 independent vowels (అ ఆ ఇ ఈ ఉ ఊ ఋ ఎ ఏ ఐ ఒ ఓ ఔ …), plus anusvara / visarga (ం ః).
- **Consonants — హల్లులు (hallulu):** the ~36 base consonants (క ఖ గ ఘ ఙ … హ ళ క్ష ఱ).
- **Vowel signs — గుణింతాలు (guninthalu):** every consonant × vowel-sign (mātra) combination — the big క కా కి కీ కు కూ … grid. This is where reading fluency is actually won.
- **Compound consonants — వత్తులు (vatthulu):** subscript / conjunct forms (ottakshara) like క్క, స్త, ల్ల — the hardest and most-skipped part of learning the script.

**A new "Learn" tab / section**
- Add a 5th tab (**Learn · అక్షరాలు**) alongside Library / Review / Progress / Profile.
- **Reference charts:** browsable, sectioned grids for vowels, consonants, guninthalu, and vatthulu. Tap any akshara to hear it (SpeechService), see its transliteration + name, and an example word that uses it — real examples can be pulled from the story corpus via `TeluguText`.
- **Quiz / flashcard drills:** reuse the SM-2 engine and the deck-stack UI from Review, but as **separate script decks** so alphabet practice never mixes with vocabulary. Modes:
  - *Recognition:* see the akshara → recall its sound / name.
  - *Listening:* hear it (audio) → pick the right akshara.
  - *Production (later):* trace / handwrite, or type the transliteration.
- **Guninthalu drills:** given a consonant + a target vowel, pick or produce the correct combined form; reinforces mātra application.
- **Vatthulu drills:** recognize and assemble conjuncts.

**Gamified lessons — design decided.** A structured learn path — ordered units (vowels → consonants → guninthalu → vatthulu), each a short lesson plus a mastery check that unlocks the next. See **phase 5** below for the locked visual design and the phased implementation plan.

**Heavy reuse — why the effort is leveraged, not from-scratch**
- **`Transliterator`** already encodes the vowel / consonant / mātra / virama maps — essentially the seed data for the reference charts and the answer key for quizzes.
- **`SpeechService`** already pronounces Telugu — point it at single aksharas.
- **`SM2`** + **`ReviewView` / `DeckStackView`** give scheduling and a proven flashcard UI to fork.
- **Theme + bundled Noto Telugu fonts** already render the script beautifully.

**Data model**
- New `Akshara` model: `character`, `category` (vowel / consonant / guninthaa / vatthu), `transliteration`, `name`, `order`, optional `exampleWord`.
- Seed a bundled `Resources/aksharas.json` (partly generatable from `Transliterator`'s maps); mastery / scheduling state lives in `UserData` under its own keyspace so it syncs through the existing engine.

**Effort: XL — phase it**
1. ✅ **Done — Reference charts** for vowels + consonants, tap-to-hear (M). Shipped as the Learn tab: collapsible chart sections (closed by default), tap-to-hear tiles, and a compact detail drawer (glyph, romanization, sound hint, varga) that stays minimal while hopping between letters.
2. ✅ **Done — Flashcard decks** for vowels + consonants over SM-2, separate from vocab (M). Shuffled sessions (10 new/session), auto-pronounce on reveal, due/new pills on the Practice rows, Learn-tab badge for due letters, and the decks are also selectable from the Review tab's new deck picker.
3. ✅ **Done — Guninthalu** reference + drills (M–L). All 36×16 forms are *generated* from a 16-row vowel-sign table (no hardcoded grid): a Guninthalu explorer (consonant picker → full గుణింతం chart with formation breakdowns) plus an SM-2 quiz over the 16 signs where each rep pairs the sign with a rotating consonant (క first, then consonants the learner has studied) so the pattern transfers.
4. ✅ **Done — Vatthulu** reference + drills (M–L). All conjunct forms are *generated* (base + virama + consonant, no glyph table): a varga-grouped reference of all 36 vatthulu shown as their doubled forms (క్క) with formation breakdowns, shape notes, and tappable real example words, plus an SM-2 quiz over the **27 drillable vatthulu** — the 9 that barely occur in modern Telugu (ఖ ఙ ఝ ఠ ఢ ఫ హ క్ష ఱ) are chart-only, marked rare. Each quiz rep dresses the vatthu in a different real cluster from curated everyday words (త వత్తు rotates అత్త → పుస్తకం → రక్తం), and reveal pronounces the example word so the cluster is heard in context. Wired into the Review deck picker, a Practice row, and the Learn-tab due badge.
5. **Journey — gamified lesson path** (L–XL). ← **in progress; design locked 17 Jul 2026**

   **Design (prototyped in `Views/Learn/Prototypes/`, cartoon style chosen):** the journey
   renders as a playful cartoon river — the Godavari — flowing **bottom-to-top**: the
   traveler starts at the bottom of the map, completed stops sit beneath the boat, and the
   unexplored course rises into a light morning mist above, ending at a sea band across the
   top. **Villages** = lessons (a few letters each, letter glyph on the marker, letters
   listed in a caption chip), **temples** = section checkpoints at real Godavari landmarks
   (బాసర — where అక్షరాభ్యాసం happens → ధర్మపురి → భద్రాచలం → రాజమహేంద్రవరం → అంతర్వేది,
   the sagara sangamam), **book markers** = "you can now read…" reading milestones.
   Completed temples fly a red pennant; the current stop breathes with a START chip; locked
   stops are warm sandstone, never gray. All geometry derives from one layout engine
   (Catmull-Rom spline through seeded meandering stop positions — `RiverLayout`), rendered
   in a spring-green palette tuned for text contrast in both light and dark mode.
   **Learn-tab layout:** the tab defaults to the **Journey**; a top toggle switches to
   **Explore** — today's LearnView content (practice deck rows + reference charts).

   **Core rule: the journey is a guided front-end over the existing SM-2 ledger.** Lessons
   feed `rate(...)` on the same `aksharaCards` keys the practice decks already use
   (correct ≈ quality 4–5, wrong ≈ 2), and stop completion is *derived* from card state
   wherever possible, so the Journey, the Review-tab decks, and the due badges can never
   disagree. Path-only state (checkpoint passes, test-outs) lives in a new local
   `pathprogress.json` beside `aksharacards.json` — deliberately outside `UserData` so the
   sign-in rebuild can't wipe it.

   **Phases — vowels first, validated as a real learning system before widening:**
   - [x] **5a — Journey scaffold + Learn-tab layout (M).** _Built 17 Jul 2026._ Journey/Explore toggle (Journey
     default; Explore hosts the existing LearnView content unchanged). Promote the cartoon
     prototype into a real `JourneyView` driven by unit definitions in a new
     `Models/LearnPath.swift` (generated from `AksharaData`, not hand-tabulated) plus a
     `PathStore` for path-only state. Vowels section fully wired (4 villages + Basara);
     later sections render locked upstream. Auto-scroll to the current stop; tapping the
     current stop routes to its lesson.
   - [x] **5b — Vowel lessons: the learning loop (M).** _Built 17 Jul 2026. As-built:
     one SM-2 rating per letter per session (clean → 4, missed-but-recovered → 3;
     checkpoint 5/2) so multiple exercises don't inflate intervals; listening exercises
     drop out when sound is off._ New `LessonSessionView`: meet-it
     intro cards for each new letter (big glyph, auto-pronounce, sound hint), then
     multiple-choice exercises — *recognition* (glyph → pick the sound), *listening*
     (hear it → pick the glyph), *reverse* (romanization → pick the glyph) — with wrong
     answers requeued until cleared, haptic ticks + in-session combo, and an end-of-lesson
     celebration (letters-learned recap with speak buttons, river path animating forward).
     Results feed SM-2. The Basara checkpoint is a mixed no-hints quiz over all 16 vowels
     (~80% to pass) that raises the temple pennant.
   - [ ] **5c — Validate the loop before widening (S — gate). _Affordances built
     (strengthen badge + practice sessions, auto-complete from existing SM-2 state);
     the on-device tuning pass is the open gate._** Prove vowels actually
     stick: completed stops surface SM-2 due state (a "strengthen" affordance on the map),
     existing users' already-learned letters auto-complete their stops on first open
     (`repetitions ≥ 2`), and session length / exercise mix / letters-per-lesson get tuned
     from real on-device use. **Consonants don't start until this feels effective.**
   - [ ] **5d — Consonants section (S–M).** Varga-based villages over the same machinery,
     the first reading milestone (bare-consonant + vowel words mined from the story
     corpus), and the Dharmapuri checkpoint.
   - [ ] **5e — Guninthalu + vatthulu sections (M).** New *build-it* exercise type
     (assemble consonant + sign → syllable; base + vatthu → cluster — distractors are
     trivial since composite forms are generated), reading milestones mined via
     `TeluguText`, Bhadrachalam + Rajahmundry checkpoints.
   - [ ] **5f — Capstone & polish (S–M).** Antarvedi capstone deep-links into an easy
     Library story; per-section placement/test-out (pass the checkpoint → section marked
     complete, cards seeded as review); streak tie-in so lessons mark the reading day;
     delete `Views/Learn/Prototypes/` and its LearnView debug row.

**Files:** new `Views/Learn/`, `Models/Akshara.swift`, `Resources/aksharas.json`, extend `UserData` / `AppModel` for script mastery, reuse `Transliterator` / `SpeechService` / `SM2` / `DeckStackView`, add a tab in `RootView`. **Phase 5 adds:** `Views/Learn/Journey/` (JourneyView, river rendering promoted from the prototype, `LessonSessionView`), `Models/LearnPath.swift` (unit/section definitions), `PathStore` (in `LocalStore.swift`), Journey/Explore toggle in `LearnView`.

**As-built notes (phases 1–4):** script data lives in code (`Models/Akshara.swift`) rather than `aksharas.json`; SM-2 state lives in a separate local `aksharacards.json` (`AksharaStore`) — deliberately *outside* `UserData`, because the sign-in merge rebuilds `UserData` from the server and would wipe unknown fields. Script progress is therefore local-only for now (cloud sync would need backend support). Guninthalu and vatthulu quiz state are namespaced in the same store (`gunintha:<vowel>` / `vatthu:<letter>` keys).

### 3. Resume reading position (per-story bookmark)
**Priority: high, low cost.** Reopening a story always restarts at the top — punishing for longer reads spread across sessions.

**What to build**
- Persist the last position per story: page index for paged mode, scroll fraction for scroll mode. Hang it off the existing `StoryProgressEntry` (add `lastPosition` / `lastScrollFraction`).
- Restore on open; offer a subtle **"Resume vs. Start over"** affordance when a saved position exists partway through.
- The reader already tracks the pieces this needs — `pageIndex`, `scrollProgress`, and the new reading-timer segment start/pause — so wiring is mostly persistence + restore.

**Approach notes**
- Save on background/disappear (there's already an `onDisappear`/`scenePhase` hook in `ReaderView`).
- Scroll restoration needs a `ScrollViewReader` + stable anchor; account for font-size changes (fraction is safer than an absolute offset).

**Effort: S–M.** **Files:** `Models/VocabCard.swift` (`StoryProgressEntry`), `ReaderView`, `AppModel`.

### 4. Daily reminders & reading goal (local notifications)
**Priority: high — retention.** Streaks are the core loop but nothing brings the user back. A daily local notification is high-leverage and works fully offline.

**What to build**
- A configurable reminder time and an optional daily goal (e.g. "read 1 story" or "N new words"), set in Profile.
- `UNUserNotificationCenter` scheduling with a friendly, streak-aware message ("Keep your 🔥 N-day streak — today's story is ready").
- Suppress the reminder once the day's goal/reading is already done; re-schedule on completion and on app launch.
- Permission priming: ask at the right moment (after first finished story), not on cold launch.

**Approach notes**
- Deep-link the notification straight into today's story — the debug `openStory` hook shows the deep-link path is already close.
- Track goal progress off existing data (`readingDates`, `deckCards`).

**Effort: M.** **Files:** new `Services/NotificationService.swift`, `ProfileView`, `AppModel`.

### 5. ✅ TTS voice & speed customization — Done
**Shipped.** A "Voice & speed" settings screen (`SpeechSettingsView`), reachable from **Profile → Reading** and from the reader's **Aa menu** ("Voice & speed…" sheet):
- **Voice picker** listing every installed Telugu `AVSpeechSynthesisVoice` with Enhanced/Premium quality badges, plus a "System default" option; tapping a voice previews it immediately. Falls back gracefully (chosen voice → te-IN default → system voice) if a voice is uninstalled later.
- **Rate slider** (tortoise → hare, 0.2–0.65; default 0.42) that speaks a sample on release, with a reset-to-default button.
- **Global "Pronounce words on tap" toggle** lives here too (same `soundEnabled` setting as the Aa menu and the Learn/Review speaker buttons).
- Persisted as `speechVoiceID` / `speechRate` in `AppModel`, applied by `SpeechService` per utterance.
- _Note:_ iOS ships few Telugu voices; the screen's footer points users to **Settings → Accessibility → Spoken Content → Voices → Telugu** to download the more natural Enhanced/Premium voices — the app cannot trigger that download itself.

**Related work also done:** global sound toggle surfaced across Learn/Review/Guninthalu screens; vocab review cards now speak on reveal; Review tab gained a deck picker (Story words + script decks).

### 6. Richer word detail (senses, example sentences, occurrences)
**Priority: medium. Builds on #1.** The word sheet shows pronunciation + a single gloss. Context and multiple senses drive retention.

**What to build**
- Show the **sentence the word was tapped in**, plus **other occurrences** across the catalog (we can find them via `TeluguText`/`Story.words`).
- Render **multiple senses / parts of speech** from the new `WordEntry` model (#1).
- Optional: root/inflection hint and a "more examples" expander.

**Approach notes**
- Depends on #1's `senses` list and on tokenization that preserves sentence boundaries — worth adding a sentence-level split to `ReaderPage`/`Story` so both the tap sheet and read-aloud (#10) can reuse it.

**Effort: M.** **Files:** `WordSheetView`, `Story` / `ReaderPage` (sentence tokenization), `WordEntry`.

### 7. Home screen widgets (story of the day + streak)
**Priority: medium — retention/marketing.** `StoryStore.today` and `data.streak` already exist; a WidgetKit extension surfacing them is strong, low-data-risk value.

**What to build**
- Small + medium widgets: streak flame + today's story title, deep-linking into the reader.
- Optional lock-screen streak widget.

**Approach notes**
- Needs a **new widget target + App Group** to share `UserData`/story-of-the-day between app and widget — that's the bulk of the effort, not the UI.
- Reuse the deep-link path started by the `openStory` debug hook.

**Effort: L (mostly target/App-Group setup).** **Files:** new Widget extension target, shared model via App Group, small refactor so `StoryStore`/`UserData` are reachable from the extension.

### 8. Review modes & smarter scheduling
**Priority: medium.** Review is reveal-then-rate only. More modes deepen practice; the SM-2 engine is already solid and server-matched.

**What to build**
- **Typing/recall** mode (type the meaning or transliteration), **audio-only** cards (hear → recall), **leech detection** + suspend, and a per-session cap/goal.
- Card editing/suspend ties into the deck-management screen (#9).

**Approach notes**
- Keep scheduling in `SM2` untouched for parity with the backend; add mode/leech state around it.

**Effort: M–L.** **Files:** `ReviewView`, `AppModel`, possibly `SM2` (leech metadata only).

---

### The rest (lower priority)

### 9. Vocabulary browser & deck management
**Why:** You can *add* cards (`addToDeck`) but there's no screen to see, search, edit, or **delete** them — the deck only appears during a review session, and it grows unbounded. Also the natural home for the "correct this meaning" action feeding #1's community loop.
**What:** A searchable "Words" screen over `deckCards`, grouped by story/due state, with swipe-to-delete, edit-meaning, and re-listen. Add `removeCard` to `AppModel` + a sync delete.
**Effort: M.** **Files:** new `Views/Deck/`, `AppModel`, `APIClient`/`SyncEngine` (delete endpoint).
_Note: the deletion gap is also listed under bugs — it's a data-hygiene issue independent of the full screen._

### 10. Full read-aloud mode (sentence & paragraph TTS)
**Why:** We already speak single words; continuous narration with highlighting is a natural fit for a reading app and great listening practice.
**What:** Extend `SpeechService` with sentence/paragraph playback + `AVSpeechSynthesizerDelegate.willSpeakRangeOfSpeechString` to highlight the active word; play/pause in the reader chrome.
**Effort: M–L.** **Files:** `SpeechService`, `ReaderView`. Shares the sentence-tokenization work from #6 and the audio-session fix (already done — see bug #2 in Part 2).

### 11. Library search, filtering & difficulty levels
**Why:** The bookshelf is a flat horizontal scroll; it won't scale and gives no way to pick stories by level.
**What:** Search by title/collection; group/filter by collection; add a `difficulty`/`level` field to `Story` + `stories.json`, with a filter and a level chip on spines.
**Effort: M.** **Files:** `Story`, `stories.json`, `LibraryView`.

### 12. iPad support & readable layout
**Priority: medium — actively being tested on iPad.** The app is already universal (`TARGETED_DEVICE_FAMILY = "1,2"`) and runs on iPad, but every screen was laid out at phone width with **no size-class awareness**, so content stretches edge-to-edge: long Telugu reading lines, 4 giant chart tiles, oversized card stacks, a full-width segmented picker. No orientation lock, so landscape / Split View / Slide Over are all live too.

**Done so far (28 Jul 2026).** Added a reusable `readableColumn(_:alignment:)` modifier in `Theme` — caps content to a comfortable width and centers it; a **no-op on iPhone** (phone width is already below the cap), so it can't regress the phone layout. Applied to `ReaderView` (scroll + paged text columns) and `LearnView` (Explore content + header/picker block). Deployment target was also bumped to **iOS 18** (for the Journey `ScrollPosition` fix).

**Remaining — needs on-device eyeballing before blind-editing:**
- Review card stacks (Story words + script decks) — wrap content in `readableColumn(520, .center)`; verify swipe gestures + the `GeometryReader` progress bars still behave.
- Progress dashboard charts — cap width, or a two-column layout on the regular size class.
- Journey river map — left full-bleed on purpose; decide whether to cap it (wide/sparse on iPad) or keep it.
- Sheets present as centered form sheets with `.height()` detents on iPad — verify proportions.
- Paged reader — pagination is computed at full width but text is now capped at 700, so pages may under-fill vertically. Minor.
- Optional larger move: a `NavigationSplitView`/sidebar for the regular size class instead of the bottom `TabView`.

**Effort: S–M (remaining).** **Files:** `Theme.swift` (done), `ReviewView`, `ProgressDashboardView`, `JourneyView`, per-screen wraps.

### 13. Handwriting practice (Apple Pencil / touch)
**Priority: medium — high learning value on iPad; fills feature #2 phase 5's reserved "Production" exercise slot.** Practice writing aksharas by hand — Apple Pencil on iPad, finger fallback elsewhere. The capture side is trivial; **grading** is where the difficulty lives, so phase it by difficulty:

- **(a) Trace-over (easy — start here).** Render the target glyph faint underneath and trace on top with PencilKit; "grade" by stroke coverage against the glyph outline — no recognition needed. The best way to learn letterforms, especially guninthalu / vatthulu shapes.
- **(b) Self-assessed freehand (easy).** Blank box → "write ఔ" → draw → reveal the reference → self-rate. Plugs **directly into the existing reveal-then-rate SM-2 flow** with almost no new machinery.
- **(c) Automated recognition (hard — defer).** Actually classify the drawn glyph. Vision's handwriting recognition doesn't reliably cover Telugu, so this means training a Core ML classifier on Telugu handwriting datasets — real ML work, and accuracy across the 400+ *composite* forms is dubious. Those composites are exactly where tracing beats recognition, so this path buys the least. Research spike only if base vowels/consonants demand it.

**Approach notes.** `PKCanvasView` wrapped in a thin `UIViewRepresentable` gives pressure-sensitive ink, undo, and a palette for free. Slot as a new `LessonExercise.Kind` in the Journey and surface it only when Pencil/iPad (or finger) is available.

**Effort: (a)+(b) S–M · (c) L–XL.** **Files:** new PencilKit wrapper + writing-exercise view under `Views/Learn/Journey/`, `LessonSessionView` (new exercise kind), `Akshara` (glyph outline for coverage grading).

---

## Part 2 — Bugs & existing issues to fix

### High
- **Sync status indicator is effectively frozen.** `AppModel.syncStatus` reads `sync.status`, but `SyncEngine` is a plain `final class` (not `@Observable`), so Observation doesn't track it — ProfileView's "Syncing… / Synced / Offline" pill never updates after first render. `SyncEngine.status` is also mutated from background `Task`s while read on the main actor (data race). Fix: route status through the `@MainActor @Observable` `AppModel`, updated on the main actor.

- **~~`SpeechService` audio session is unconfigured.~~ ✅ Fixed.** Now sets the `.playback` category (`.spokenAudio` mode, `.duckOthers`) so pronunciation plays through the silent switch and ducks background audio, and falls back to the system default voice when `te-IN` isn't installed. _The follow-on (user-facing rate/voice settings) shipped as feature #5._

### Medium
- **Reading completion auto-fires and inflates stats.** `finishIfNeeded()` runs when a story fits on screen or on reaching the last page / 99% scroll, regardless of real reading — marking a reading day (streak++), incrementing `storiesRead`, and recording proficiency. Short stories can grant a streak on open. Gate on real dwell time (the new reading-timer accumulator is a natural signal) and/or scroll depth.

- **`ReaderView.pages` re-tokenizes the whole story on every render.** It's a computed property calling `ReaderPage.paginate(...)`, referenced from `body`, `progressFraction`, and `onChange`. The scroll reader already caches `scrollParagraphs`; the paged reader should cache the same way (recompute only when `story`/`fontSize` changes).

- **Changing font size mid-read misaligns revealed words.** Token IDs are `page-para-offset`; re-paginating at a new font size shifts them, so `revealedTokens` highlights the wrong words. Use IDs independent of pagination.

- **`TranslationService` returns unvalidated MyMemory output.** It lowercases and passes through whatever comes back — including provider warnings, quota messages, or an echo of the input — and `WordSheetView` always says "unavailable offline" even on an online failure. _(Subsumed by feature #1, but worth a quick guard sooner.)_

- **No way to delete saved cards.** `data.cards` only grows; a bad add or bad auto-gloss is permanent. Tracked as feature #9, but it's a correctness/data-hygiene gap on its own.

### Low / cleanup
- **Duplicate lookup counters.** `data.wordTaps[word]` and `VocabCard.lookups` both count look-ups; `mostLookedUp` uses `wordTaps` and `card.lookups` is essentially unused. Pick one.
- **Reading timer is display-only.** The session timer isn't persisted or sent to the backend, though `recordSession` could carry duration. Wire it up or note it's intentionally ephemeral.
- **Accessibility gaps.** Telugu text uses fixed point sizes (no Dynamic Type); tappable word tokens and book spines lack VoiceOver labels; word tap targets are small.
- **No automated tests.** `SM2`, `Transliterator`, `DayStamp`, and `UserData.streak` are pure and high-value to lock down, but there's no test target. Add unit tests before touching scheduling.
- **Hardcoded config.** `APIClient.baseURL` and the Supabase URL/anon key live inline. The anon key is publishable (safe to ship), but there's no dev/prod separation.
