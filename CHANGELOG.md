# Changelog

## Unreleased

### Features
- Added a native shared-library player that streams the web generator's versioned creation feed; free-play advances on any blocked key, while Reward mode reveals a creation only after a correct gamified letter or completed typing word.
- Resetting word sets now also clears featured words and learning-pool state before rebuilding from bundled defaults, so reset behaves like an actual state reset for word-mode data.
- Added explicit word-source modes:
  - Mode 1 (`Pool + Featured`) uses pool rotation with featured topics and extra featured words.
  - Mode 2 (`Legacy Sets`) keeps classic set-selection behavior for simpler deterministic control.
- Video demo mode now locks flashcard style to `simple` and keeps demo audio aligned to the demo word (default `cat`) on taps.
- Word/media resolution is now more `id`-centric: custom image/video lookup paths can resolve by `wordID` in display and typing game flows.
- Translation lookup is now more `id`-centric (canonical repository `wordID` first), and fallback translations are shown in the card instead of disappearing when secondary text matches primary text.
- Settings UI was reorganized into `General / Speech / Library / Media`; baby name moved into General, mode + pool/set controls into Library, and flashcard/image controls into Media.
- Added two generation CLIs:
  - `scripts.generate_library_words` to propose new catalog entries (id + `translations[en]` skeleton)
  - `scripts.generate_llm_definitions` to fill meaningful definitions via `calmlib.llm` (Haiku default model)

### Housekeeping
- Accessibility foundation: reliable AX prompt, in-app permission/event-tap status, non-fatal tap setup, no quit on permission loss. Keyword: `accessibility-foundation`.
- Catalog model decode/normalize was hardened for mixed schema shapes while preserving `id` as canonical key. Keyword: `catalog-normalization`.
