2) Merging the baby keyboard app and baby keyboard website
- Use supabase as external data storage
- Shared auth
etc.

prd: unify app + website around a shared Supabase backend (words, translations, assets) with local caching
users: maintainers; multi-device households
success: same dataset + auth across app + site; offline-friendly local cache; supports images/audio/definitions
non-goals: migrate everything at once; real-time collaboration

repo notes
- current words/images are local (Swift + UserDefaults + Application Support)
- translation maps are hardcoded: `BabyKeyboardLock/EventEffectHandler.swift`

supabase architecture
- Postgres tables:
- `word_entries` (id, word, meaning_key, pos, category, tags)
- `translations` (word_entry_id, language, text)
- `definitions` (word_entry_id, language, text, source)
- `assets` (word_entry_id, kind=image|audio, language?, storage_path, metadata)
- Storage buckets: `images/`, `audio/`
- Auth: Supabase Auth (email magic link or OAuth)
- RLS: user-scoped rows (or shared “family” workspace)

client architecture (mac app)
- local mirror cache (Application Support):
- JSON snapshot + incremental updates, or SQLite (GRDB) for querying pools/tags
- asset cache on disk with hash keys; fetch-on-demand
- keep existing local-only path as fallback when offline

workflow
- prototype first:
- minimal supabase client, login, fetch `word_entries`, show count
- fetch one image asset and render in `WordDisplayView`

plan/tests
- build prototype module (no app behavior changes) behind a feature flag
- decide schema + RLS strategy
- manual: login, download dataset, run app offline, verify cached mode
