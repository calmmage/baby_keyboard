p.s. and add one other task: generate audio files using python scripts for invoking swift voice kit (personalized one)

prd: offline audio asset generation pipeline using Python orchestration + Swift Personal Voice synthesis
users: maintainers generating large audio caches for words/phrases per language
success: one command generates/updates audio files and manifest keyed by canonical `word_id`, with resumable and deterministic outputs
non-goals: replacing runtime live recording flow; cloud TTS service integration

problem
- current custom audio is mostly manual recording/upload
- we need pre-generated reusable audio for large vocab sets
- must support Personal Voice output when available

technical approach
- python orchestrator (`typer`) reads canonical dataset and plans jobs
- swift synth helper (small CLI target) performs actual speech synthesis using system voices / Personal Voice
- python calls swift helper per item, tracks outputs, retries, and writes manifest

proposed files
- `scripts/audio/generate_personal_voice_cache.py` (planner + runner)
- `tools/personal_voice_tts/` (swift cli package)
- `BabyKeyboardLock/Resources/AudioCache/` (optional local seed cache)
- `dev/notes/actions/` docs + runbook

input/output contract
- input rows:
- `word_id`, `spelling`, `meaning_key`, `language`, `text`, `voice_preference`
- output files:
- `audio/{language}/{word_id}__{voice_hash}.m4a`
- output manifest json:
- `word_id`, `language`, `voice_id`, `text_hash`, `file_path`, `duration_ms`, `generated_at`, `generator_version`

voice resolution strategy
- try explicit Personal Voice id first
- fallback to configured default system voice for that language
- fallback events are logged in manifest (`fallback_reason`)

caching/idempotency
- skip generation when `(word_id, language, voice_id, text_hash)` already exists
- `--force` flag regenerates selected/all items
- `--limit` and `--only-language` support prototyping and partial runs

prototype-first plan
- prototype in `~/work/projects/calmmage/experiments/prototypes`:
- minimal swift cli: synthesize one phrase with selected voice to file
- minimal python wrapper: invoke cli for 10 words and build manifest
- once verified, move into repo paths above

integration with app/web
- app: loader resolves local generated audio by canonical `word_id` + language before network assets
- web/supabase (future): optional uploader script publishes generated files into storage and inserts `assets` rows
- same manifest schema can be imported by sync adapter

risks
- Personal Voice availability differs per machine/user permissions
- synthesis throughput can be slow for 1000+ words
- voice IDs may change across OS upgrades

mitigations
- include explicit fallback and per-file status
- parallel batch mode with bounded worker count
- store both `voice_id` and human-readable `voice_name` in manifest

acceptance criteria
- one command generates at least 100 audio assets with reproducible manifest
- rerun without changes produces zero regenerated files
- fallback behavior is explicit and auditable
- app can resolve and play generated audio for matching `word_id`/language
