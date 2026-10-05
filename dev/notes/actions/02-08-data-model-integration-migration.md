integrate new data model properly
- review the codebase and make a full prd of where it needs to be wired in properly
- p.s. any hidden issues we need to consider to support supabase in the future?

prd: migrate app runtime from legacy random-word structs to canonical word catalog model
users: app maintainers; data tooling; future web/supabase integration
success: one source of truth for word identity and metadata, consistent IDs across words/translations/images/audio/learning
non-goals: full supabase rollout in this task

repo review snapshot
- canonical model exists: `BabyKeyboardLock/utils/WordDataModel.swift`
- canonical dataset exists: `BabyKeyboardLock/Resources/word_sets.json`
- runtime still primarily legacy:
- `RandomWord`, `RandomWordSet`, `LearningWord` in `BabyKeyboardLock/utils/RandomWordList.swift`
- translations still partly hardcoded dictionaries in `BabyKeyboardLock/EventEffectHandler.swift`
- learning persistence is CSV keyed by `word|clarification`: `BabyKeyboardLock/utils/RandomWordList.swift` (`learning.csv`)
- custom images are local paths + security bookmarks keyed by `word|clarification`

what is already wired
- bundled canonical JSON is decoded and mapped into runtime sets (`WordDataCatalog.decode` + `mapCatalogToRandomWordSets`)
- meaning-aware translation lookup exists for selected random words
- runtime fallback order now includes bundled catalog translations by language code before hardcoded maps

gaps to wire fully
- canonical entry metadata dropped during mapping:
- `partOfSpeech`, `category`, `tags`, `definitions`, `assets` are not first-class runtime sources
- runtime IDs are still derived ad-hoc in multiple places (`wordKey`)
- learning state uses CSV with legacy columns, not canonical entry IDs with schema versioning
- custom image/audio attachment is split from canonical `assets`
- user edits (word sets) persist as encoded legacy structs in UserDefaults
- no dataset version pinning or migration ledger

migration design
- phase 1: compatibility index (low risk)
- keep current UI/runtime structs, but keep canonical catalog index loaded for lookup by `(spelling, meaningKey)`
- use catalog translation lookup before hardcoded maps
- output: fewer translation collisions, canonical translation path active
- phase 2: canonical repository layer
- add `WordRepository` API with typed queries:
- `entry(id)`, `entries(inSetID)`, `translations(entryID)`, `assets(entryID, kind)`
- `find(spelling, meaningKey)`
- refactor `RandomWordList` to consume repository instead of owning source schema logic
- phase 3: persistence normalization
- migrate learning persistence from CSV to JSON/SQLite with explicit schema version
- store state by canonical `entry.id`
- keep one-time CSV importer for backward compatibility
- phase 4: assets normalization
- represent custom local images as per-entry asset overrides
- keep local paths/bookmarks in local overlay store, not in base catalog
- add audio override path using same asset model
- phase 5: supabase-ready sync boundary
- separate data planes:
- base catalog plane (remote snapshot + local mirror)
- user overlay plane (favorites/known/custom assets/progress)
- sync only overlay rows per user; keep base snapshot versioned and cacheable

file-by-file wiring checklist
- `BabyKeyboardLock/utils/RandomWordList.swift`
- replace direct set/word array ownership with repository-backed selection
- keep compatibility adapters for current UI fields
- `BabyKeyboardLock/EventEffectHandler.swift`
- remove hard dependency on static translation maps once repository coverage is complete
- keep static maps only as fallback
- `BabyKeyboardLock/views/ContentView.swift`
- pool editor and custom image editor should read/write by canonical entry ID
- `BabyKeyboardLock/views/LearningWordEditorView.swift`
- display category/pos from canonical data, not inferred tags only
- `BabyKeyboardLock/views/WordDisplayView.swift`
- resolve image/audio assets via repository overlay chain
- `scripts/export_word_sets_json.py`
- become deterministic catalog builder with schema validation and stable IDs

hidden issues for future supabase support
- security-scoped bookmarks are local-only and not syncable across devices
- solution: store remote asset URI in supabase; keep bookmark only in local overlay
- language code mismatch:
- app uses locale-like codes (`ru-RU`), catalog often uses short codes (`ru`)
- enforce canonical language normalization utility shared by app + scripts
- ID normalization drift risk:
- current key builder lowercases and trims; scripts slug meanings differently in some cases
- enforce one ID constructor contract in both Swift and Python tests
- conflict model missing:
- user can edit local sets while remote catalog updates
- need merge policy: base snapshot immutable + user overlay precedence
- auth boundary missing:
- current app has no user identity model; supabase overlay writes require local user/session id
- migration safety:
- CSV/UserDefaults data requires one-time importer with rollback flag and telemetry markers

acceptance criteria
- all runtime word lookups use canonical IDs internally
- random selection, translation, image selection, and learning progress use same ID
- reset flow can rebuild from bundled catalog deterministically
- local overlays survive app restart and do not mutate base catalog file
- supabase adapter can be plugged without changing UI layer contracts
