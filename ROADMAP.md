# Kathalu iOS — Roadmap & Tech Debt

A planning reference for future work. Two parts:
1. **Proposed features**, ordered by the product priority we agreed on.
2. **Bugs & existing issues** worth fixing, ordered by severity.

Last reviewed against `main` @ commit `b05ad58` (post sound-toggle / reading-timer work).

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
- Model `senses` as a list from day one so a word can carry multiple meanings (needed for feature #5).

**Effort: L.** Phase it: (a) `WordEntry` model + local bundled lookup + fallback rewrite (M); (b) generate & curate the story-vocabulary seed (M, mostly data work); (c) backend table + community submit/moderate loop (M–L, optional follow-on).
**Files:** new `Models/WordEntry.swift`, `Resources/dictionary.json`, `Services/DictionaryService.swift` (replaces/absorbs `TranslationService`), `WordSheetView`, `APIClient`/`SyncEngine` for the DB layer.

### 2. Resume reading position (per-story bookmark)
**Priority: high, low cost.** Reopening a story always restarts at the top — punishing for longer reads spread across sessions.

**What to build**
- Persist the last position per story: page index for paged mode, scroll fraction for scroll mode. Hang it off the existing `StoryProgressEntry` (add `lastPosition` / `lastScrollFraction`).
- Restore on open; offer a subtle **"Resume vs. Start over"** affordance when a saved position exists partway through.
- The reader already tracks the pieces this needs — `pageIndex`, `scrollProgress`, and the new reading-timer segment start/pause — so wiring is mostly persistence + restore.

**Approach notes**
- Save on background/disappear (there's already an `onDisappear`/`scenePhase` hook in `ReaderView`).
- Scroll restoration needs a `ScrollViewReader` + stable anchor; account for font-size changes (fraction is safer than an absolute offset).

**Effort: S–M.** **Files:** `Models/VocabCard.swift` (`StoryProgressEntry`), `ReaderView`, `AppModel`.

### 3. Daily reminders & reading goal (local notifications)
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

### 4. TTS voice & speed customization
**Priority: medium, low cost.** `SpeechService` hardcodes `te-IN` at rate `0.42`. Learners vary; slower pronunciation is a common ask. Natural complement to the new sound toggle.

**What to build**
- A rate slider and a voice picker (enumerate available `AVSpeechSynthesisVoice`s for Telugu; fall back gracefully when none is installed), persisted like the other `AppModel` settings.
- Surface in the "Aa" reader menu and/or Profile → Reading.
- A "test" button that speaks a sample word at the chosen settings.

**Approach notes**
- Do the `AVAudioSession` configuration from bug #2 here too (silent-mode playback, ducking, missing-voice handling) — this feature and that fix overlap heavily.

**Effort: S.** **Files:** `SpeechService`, `AppModel`, `ReaderView` / `ProfileView`.

### 5. Richer word detail (senses, example sentences, occurrences)
**Priority: medium. Builds on #1.** The word sheet shows pronunciation + a single gloss. Context and multiple senses drive retention.

**What to build**
- Show the **sentence the word was tapped in**, plus **other occurrences** across the catalog (we can find them via `TeluguText`/`Story.words`).
- Render **multiple senses / parts of speech** from the new `WordEntry` model (#1).
- Optional: root/inflection hint and a "more examples" expander.

**Approach notes**
- Depends on #1's `senses` list and on tokenization that preserves sentence boundaries — worth adding a sentence-level split to `ReaderPage`/`Story` so both the tap sheet and read-aloud (#9) can reuse it.

**Effort: M.** **Files:** `WordSheetView`, `Story` / `ReaderPage` (sentence tokenization), `WordEntry`.

### 6. Home screen widgets (story of the day + streak)
**Priority: medium — retention/marketing.** `StoryStore.today` and `data.streak` already exist; a WidgetKit extension surfacing them is strong, low-data-risk value.

**What to build**
- Small + medium widgets: streak flame + today's story title, deep-linking into the reader.
- Optional lock-screen streak widget.

**Approach notes**
- Needs a **new widget target + App Group** to share `UserData`/story-of-the-day between app and widget — that's the bulk of the effort, not the UI.
- Reuse the deep-link path started by the `openStory` debug hook.

**Effort: L (mostly target/App-Group setup).** **Files:** new Widget extension target, shared model via App Group, small refactor so `StoryStore`/`UserData` are reachable from the extension.

### 7. Review modes & smarter scheduling
**Priority: medium.** Review is reveal-then-rate only. More modes deepen practice; the SM-2 engine is already solid and server-matched.

**What to build**
- **Typing/recall** mode (type the meaning or transliteration), **audio-only** cards (hear → recall), **leech detection** + suspend, and a per-session cap/goal.
- Card editing/suspend ties into the deck-management screen (#8).

**Approach notes**
- Keep scheduling in `SM2` untouched for parity with the backend; add mode/leech state around it.

**Effort: M–L.** **Files:** `ReviewView`, `AppModel`, possibly `SM2` (leech metadata only).

---

### The rest (lower priority)

### 8. Vocabulary browser & deck management
**Why:** You can *add* cards (`addToDeck`) but there's no screen to see, search, edit, or **delete** them — the deck only appears during a review session, and it grows unbounded. Also the natural home for the "correct this meaning" action feeding #1's community loop.
**What:** A searchable "Words" screen over `deckCards`, grouped by story/due state, with swipe-to-delete, edit-meaning, and re-listen. Add `removeCard` to `AppModel` + a sync delete.
**Effort: M.** **Files:** new `Views/Deck/`, `AppModel`, `APIClient`/`SyncEngine` (delete endpoint).
_Note: the deletion gap is also listed under bugs — it's a data-hygiene issue independent of the full screen._

### 9. Full read-aloud mode (sentence & paragraph TTS)
**Why:** We already speak single words; continuous narration with highlighting is a natural fit for a reading app and great listening practice.
**What:** Extend `SpeechService` with sentence/paragraph playback + `AVSpeechSynthesizerDelegate.willSpeakRangeOfSpeechString` to highlight the active word; play/pause in the reader chrome.
**Effort: M–L.** **Files:** `SpeechService`, `ReaderView`. Shares the sentence-tokenization work from #5 and the audio-session fix from #4/bug #2.

### 10. Library search, filtering & difficulty levels
**Why:** The bookshelf is a flat horizontal scroll; it won't scale and gives no way to pick stories by level.
**What:** Search by title/collection; group/filter by collection; add a `difficulty`/`level` field to `Story` + `stories.json`, with a filter and a level chip on spines.
**Effort: M.** **Files:** `Story`, `stories.json`, `LibraryView`.

---

## Part 2 — Bugs & existing issues to fix

### High
- **Sync status indicator is effectively frozen.** `AppModel.syncStatus` reads `sync.status`, but `SyncEngine` is a plain `final class` (not `@Observable`), so Observation doesn't track it — ProfileView's "Syncing… / Synced / Offline" pill never updates after first render. `SyncEngine.status` is also mutated from background `Task`s while read on the main actor (data race). Fix: route status through the `@MainActor @Observable` `AppModel`, updated on the main actor.

- **`SpeechService` audio session is unconfigured.** No `AVAudioSession` category is set, so pronunciation may not play in silent mode, won't duck other audio, and there's no fallback/signal when the `te-IN` voice is missing (silent failure). Configure `.playback`/`.ambient` and handle a nil Telugu voice. _(Overlaps with feature #4 — do together.)_

### Medium
- **Reading completion auto-fires and inflates stats.** `finishIfNeeded()` runs when a story fits on screen or on reaching the last page / 99% scroll, regardless of real reading — marking a reading day (streak++), incrementing `storiesRead`, and recording proficiency. Short stories can grant a streak on open. Gate on real dwell time (the new reading-timer accumulator is a natural signal) and/or scroll depth.

- **`ReaderView.pages` re-tokenizes the whole story on every render.** It's a computed property calling `ReaderPage.paginate(...)`, referenced from `body`, `progressFraction`, and `onChange`. The scroll reader already caches `scrollParagraphs`; the paged reader should cache the same way (recompute only when `story`/`fontSize` changes).

- **Changing font size mid-read misaligns revealed words.** Token IDs are `page-para-offset`; re-paginating at a new font size shifts them, so `revealedTokens` highlights the wrong words. Use IDs independent of pagination.

- **`TranslationService` returns unvalidated MyMemory output.** It lowercases and passes through whatever comes back — including provider warnings, quota messages, or an echo of the input — and `WordSheetView` always says "unavailable offline" even on an online failure. _(Subsumed by feature #1, but worth a quick guard sooner.)_

- **No way to delete saved cards.** `data.cards` only grows; a bad add or bad auto-gloss is permanent. Tracked as feature #8, but it's a correctness/data-hygiene gap on its own.

### Low / cleanup
- **Duplicate lookup counters.** `data.wordTaps[word]` and `VocabCard.lookups` both count look-ups; `mostLookedUp` uses `wordTaps` and `card.lookups` is essentially unused. Pick one.
- **Reading timer is display-only.** The session timer isn't persisted or sent to the backend, though `recordSession` could carry duration. Wire it up or note it's intentionally ephemeral.
- **Accessibility gaps.** Telugu text uses fixed point sizes (no Dynamic Type); tappable word tokens and book spines lack VoiceOver labels; word tap targets are small.
- **No automated tests.** `SM2`, `Transliterator`, `DayStamp`, and `UserData.streak` are pure and high-value to lock down, but there's no test target. Add unit tests before touching scheduling.
- **Hardcoded config.** `APIClient.baseURL` and the Supabase URL/anon key live inline. The anon key is publishable (safe to ship), but there's no dev/prod separation.
