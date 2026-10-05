Let me reiterate:
1) It's not exactly 'merge' - re-implement the app features into a Next.js web app
2) old web in `dev/` is inspiration only
3) use features/content (and maybe code where useful) from the Swift app
4) keep web-only features not in core app yet, especially image generation on the fly

prd: rewrite web app from scratch around canonical word model (`word + meaning`) and current app architecture
users: family admins managing words/assets; child-facing flashcard session users
success: new web uses same canonical IDs/data semantics as app, supports on-demand image generation, supports audio recording, and stays easy to extend for supabase-backed sync
non-goals: migrate old web UI flows 1:1; keep backward compatibility with old `web/` APIs

keep from old web (explicit)
- image generation on the fly via API route
- audio recording in web UI
- note: audio recording flow must also be designed for local mac app integration (shared data contract)
- support both pre-synthesized audio generation pipeline and per-word custom recording overrides

trigger model
- do not lock keyboard like mac app; trigger next word on any key press
- keep explicit click/tap trigger button for mouse/touch flows

source-of-truth model alignment
- canonical model: `BabyKeyboardLock/utils/WordDataModel.swift`
- repository/runtime mapping: `BabyKeyboardLock/utils/WordRepository.swift`
- bundled canonical dataset: `BabyKeyboardLock/Resources/word_sets.json`
- ID contract: `word_id = spelling|meaning_key` (or `spelling` when meaning key is empty)

new web architecture (rebuild)
- framework: Next.js App Router + TypeScript strict + Server/Route Handlers
- UI: shadcn/radix patterns, modular components
- auth/data/storage: Supabase (Auth + Postgres + Storage)
- package direction from old web to keep:
- `next`, `react`, `typescript`
- `@supabase/supabase-js`, `@supabase/ssr`
- `@radix-ui/*`, `lucide-react`
- `react-hook-form`, `zod`
- `tailwindcss`, `tailwind-merge`, `clsx`
- avoid carrying old prototype-only packages unless required by a concrete feature

domain schema target (supabase)
- `word_entries`: `id`, `spelling`, `meaning_key`, `part_of_speech`, `category`, `tags_json`, timestamps
- `word_sets`: set metadata
- `word_set_entries`: set-to-word mapping + ordering
- `translations`: `word_id`, `language`, `text`
- `definitions`: `word_id`, `language`, `text`, `source`
- `assets`: `word_id`, `kind(image|audio)`, `language?`, `storage_path`, `rotation_degrees`, metadata json
- `user_word_progress`: known/favorite/seen stats
- `user_settings`: language + pool prefs

api surface (v2)
- `GET /api/v2/words`: filtered pool + optional progress join
- `POST /api/v2/word-progress`: known/favorite/seen updates
- `POST /api/v2/assets/image/generate`: generate image + persist asset row
- `POST /api/v2/assets/audio/upload`: upload recorded audio + persist asset row
- `GET /api/v2/sets`: set definitions and membership
- `POST /api/v2/sync/export`: export canonical snapshot for local app mirror (optional first phase)

mac app integration contract
- local app remains offline-first with local sqlite/cache
- syncable fields must match canonical model + asset metadata (especially `rotation_degrees`)
- web-generated assets are referenced by stable `word_id` and language/kind tags
- audio captured on web is stored in the same asset table/format expected by app sync adapter

implementation phases
- phase 0: freeze old `web/` as archive reference, no further feature work there
- phase 1: scaffold clean web app (`web-next/` or clean `web/`) with auth + health checks
- phase 2: implement canonical schema + RLS + typed API routes
- phase 3: implement child player + manage words flows on v2 APIs
- phase 4: implement image generation and audio recording/upload on v2 asset contracts
- phase 5: app sync bridge prototype (snapshot pull + asset pull)
- phase 6: cutover, deprecate old routes

quality gates
- no `ignoreBuildErrors` in Next config
- end-to-end path works: create word -> upload/record asset -> display in player
- contract tests for ID normalization (`spelling|meaning_key`)
- migration script validates no duplicate `(spelling, meaning_key)` collisions

deliverables
- new web PRD-backed architecture doc + schema SQL + RLS policies
- working v2 player/manage flows
- image generation and audio recording paths wired to canonical asset model
- migration notes from old `web/` to new stack

acceptance criteria
- all web word/asset operations are keyed by canonical `word_id`
- image generation and recorded audio are persisted and readable via v2 APIs
- schema supports future definitions/annotations expansion without breaking IDs
- app-side sync can consume same rows without ad-hoc translation layer

appendix: old web architecture snapshot to preserve
- strong parts worth reusing:
- Next.js App Router server/client split
- Supabase SSR middleware/session handling
- shadcn/radix component system
- modular API route structure under `app/api`
- avoid reusing as-is:
- old route contracts with mismatched payloads
- schema tied to `word_en/word_ru/word_de` columns only
- prototype leftovers (`ignoreBuildErrors`, inconsistent scripts/contracts)
