Need: generate remaining images for all words x all 12 styles without surprise costs; optionally backfill missing assets on demand

prd: controlled image generation system (on-demand + batch) for full style coverage
users: you (operator), app users who see missing images
success:
- missing coverage drops to near-zero for active words/styles
- no single run exceeds configured budget
- on-demand generation fills gaps with strict daily cap
non-goals:
- perfect artistic consistency across all providers
- realtime generation on every keypress

repo notes
- style model + parsing: `BabyKeyboardLock/utils/FlashcardStyle.swift`
- image lookup runtime: `BabyKeyboardLock/views/WordDisplayView.swift`, `BabyKeyboardLock/views/TypingGameView.swift`
- default words source: `BabyKeyboardLock/utils/RandomWordList.swift`
- batch generator: `scripts/generate_images.py`
- word parsing helpers: `scripts/word_utils.py`

proposal
- do both systems, with batch as primary and on-demand as safety net
- batch flow generates most assets cheaply/gradually
- on-demand only triggers for real missing assets and obeys hard quotas

on-demand system (yes, feasible)
- add setting toggles:
- `enableOnDemandGeneration` (default: off)
- `onDemandDailyBudgetUsd` (default small, e.g. 1.0)
- `onDemandMaxImagesPerDay` (e.g. 20)
- runtime behavior:
- when selected style image is missing, enqueue `(word, style)` generation job
- dedupe queue by key `(style, word)`
- if quota reached, skip and keep normal fallback behavior (custom image/baby image/no image)
- cache:
- save generated image into `BabyKeyboardLock/Resources/FlashcardImages/<style>/<style>_<word>.png` (or app support mirror)
- persist queue + per-day counters in local state file
- safety:
- only run when app is unlocked and user enabled toggle
- never block UI; job runs async

batch system (primary)
- extend `scripts/generate_images.py` with budget-first controls:
- `--max-cost-usd <float>` hard stop once actual returned cost reaches cap
- `--max-images <int>` explicit image cap per run (similar to existing `--limit`, keep one canonical flag)
- `--max-per-style <int>` avoid spending all budget on one style
- `--state-file <path>` persist completed/failed keys; support `--resume`
- `--retry-failures` for cheap reruns
- `--styles <list>` support subset runs (`simple,elvish,pastel`)
- keep existing `--dry-run` estimate + confirmation gate
- execution strategy to avoid spikes:
- run nightly or manually with small caps (example: 50 images OR $2 per run)
- prioritize styles you use most first
- run retry-only pass weekly

minimal rollout plan
1) prototype (required)
- create standalone prototype in `~/calmmage/experiments/prototypes`:
- simulate queue + daily budget + dedupe + persistence
- verify no duplicate jobs and budget stop works

2) batch script hardening
- implement new flags in `scripts/generate_images.py`
- add run state json (`generated`, `failed`, `spent`, timestamp)
- add summary output by style + cost

3) on-demand queue service
- add lightweight generation queue manager (new util)
- integrate into lookup miss path in `WordDisplayView`/`TypingGameView`
- gate behind settings toggle + budget counters

4) operator workflow
- dry-run first, then tiny paid run
- review samples per style
- increase caps gradually

acceptance tests
- batch:
- `--dry-run` prints count + estimate + style breakdown
- paid run with `--max-cost-usd 1.0` stops near cap and persists resumable state
- rerun with `--resume` skips already successful keys
- on-demand:
- missing `(word, style)` enqueues once and generates once
- after daily cap hit, new misses do not trigger generation
- app remains responsive while jobs run

example run policy
- day 1: `uv run python scripts/generate_images.py --style all --all-defaults --max-images 40 --max-cost-usd 1.5 --dry-run`
- day 1 execute: same command without `--dry-run`
- day 2+: resume with same caps; raise budget only after quality/cost review

open questions
- store generated assets in bundle tree vs Application Support mirror + sync script
- preferred provider/model for best cost-quality for kid-friendly art
