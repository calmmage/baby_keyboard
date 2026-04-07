can we use our scripts to generate a bunch more words / word sets? like up to 1000 maybe

prd: generate and curate up to 1000 additional candidate words/sets using existing scripts
users: maintainers expanding vocabulary
success: reproducible script pipeline outputs 1000-word candidate dataset and optional app-ready set file
non-goals: perfect auto-translation quality across all languages

what we already have
- `scripts.word_dictionary_showcase` can generate large filtered vocab from wordfreq (`--pool-size`, `--limit`, `--mode`)
- `scripts.export_word_sets_json` can build app catalog JSON from structured input flow

recommended pipeline
- stage 1: generate candidates (1000+)
- command:
- `uv run python -m scripts.word_dictionary_showcase --lang en --pool-size 20000 --limit 1000 --pos noun,verb,adj --format jsonl > dev/notes/artifacts/word_candidates_en_1000.jsonl`
- stage 2: filter and tag
- remove stopwords/auxiliary forms already mostly handled
- apply age-appropriate blacklist and duplicate/collision checks
- stage 3: translation/meaning pass
- add `meaningKey` for ambiguous spellings
- fill target translations (ru first), keep unresolved rows marked explicitly
- stage 4: build app-ready catalog
- convert curated rows into canonical catalog (`entries` + `sets`)
- output `BabyKeyboardLock/Resources/word_sets.generated.json` for trial
- stage 5: controlled rollout
- import as new sets only (do not replace current defaults immediately)
- observe selection quality and speech/display behavior

design constraints
- 1000 auto-generated words without curation will include child-inappropriate or low-utility words
- ambiguous words must carry meaning keys before attaching images/translations
- large sets can degrade UX unless grouped into theme/level sets (for example 20 sets x 50 words)

acceptance criteria
- generated artifact is reproducible from one command + fixed filters
- no duplicate canonical IDs
- collision list (same spelling, multiple meanings) is explicit
- app can load generated set file without runtime errors
