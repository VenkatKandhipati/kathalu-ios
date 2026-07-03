# Kathalu iOS

Native SwiftUI port of [Kathalu](https://github.com/VenkatKandhipati/kathalu) — Telugu
reading practice with tap-to-learn words and SM-2 spaced repetition.

## Features

- **Library** — bookshelf of bundled stories, reading streak, 7-day strip, story of the day
- **Reader** — paged immersive reading; tap a word once for pronunciation (inline + voice),
  tap again for a meaning sheet and one-tap add to flashcards
- **Review** — SM-2 flashcards (same scheduling math as the backend), deck-stack UI,
  Again/Hard/Good/Easy with interval previews
- **Progress** — proficiency ring, streak / stories / words-known tiles, most-looked-up words
- **Profile** — optional username-only account (Supabase), appearance & font size settings

Works fully offline and anonymously; signing in imports local data once and then syncs
write-through to the FastAPI backend at `api.kathalu.me`, mirroring the web app's model.

## Structure

```
Kathalu/
├── KathaluApp.swift        app entry
├── Models/                 Story, VocabCard/DayStamp, API wire types (schemas.py mirror)
├── Services/               StoryStore, Transliterator, SM2, LocalStore, AuthService,
│                           APIClient, SyncEngine, TranslationService, SpeechService
├── ViewModels/             AppModel (@Observable root state)
├── Views/                  Theme + Onboarding / Library / Reader / Review / Progress / Profile
└── Resources/              stories.json (migrated from stories.js), Noto Telugu fonts
```

## Build

Open `Kathalu.xcodeproj` in Xcode 16+ and run (iOS 17+). No dependencies, no signing
required for the simulator.
