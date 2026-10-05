PRD: Canonical word|meaning ID migration

Problem
- Runtime mixes canonical word_id (spelling|meaningKey) with plain lowercased word lookups.
- Translation/media still use fallback paths, causing ambiguity and language drift.
- Catalog currently has ru coverage, but missing de/fr/es/it/ja/zh entries.

Goal
- Make word_id the only identity in runtime flows.
- Remove silent fallback behavior.
- Guarantee no empty translations for enabled languages.

Non-goals
- UI redesign.
- New game mechanics.
- Remote CMS redesign.

Scope
1. Identity migration in runtime (selection, translation, media, typing).
2. Main words migration from legacy CustomWordSet to canonical entries.
3. Translation completeness tooling and population pipeline.
4. CI and app startup integrity gates.

Product requirements
1. Identity
- All runtime word objects carry id = makeWordID(spelling, meaningKey).
- All lookups use word_id first.
- speakAKeyWord selects canonical word objects (not raw strings).

2. Translation resolution
- Use WordRepository.translation(wordID:languageCode:) in production paths.
- Remove production dependence on spelling-only lookup and static dict maps.
- Missing translation -> critical warning + surfaced alert.

3. Main words model
- Replace CustomWordPair(english, translation) with canonical word entries.
- Store per-language translations and meaningKey.
- Migrate existing user data forward.

4. Media identity
- Custom image/video keys must be word_id.
- Remove plain-word image fallback.

5. Data quality gates
- Startup integrity check for required languages: ru,de,fr,es,it,ja,zh.
- CLI audit strict mode: fail when missing translations.
- CI runs strict audit and blocks merge on missing coverage.

Technical requirements
1. Repository APIs
- Keep translation(wordID:languageCode:) as canonical path.
- Deprecate runtime use of translation(english:meaningKey:).

2. Determinism
- No ambiguous spelling fallback in runtime translation/media paths.
- If word_id is unresolved, emit critical event and fail closed for translation output.

3. Backward compatibility
- One-time migration for legacy custom image keys and main words storage.
- Preserve user-added words/images where mapping is unambiguous.

4. Tests
- Add unit tests for homograph disambiguation by meaningKey.
- Add tests for strict word_id translation path.
- Add integration tests for speakRandomWord/speakAKeyWord/typingGame using word_id.
- Add script tests for audit --fail-on-missing behavior.

Populate strategy
1. Short term (migration helper)
- Populate from legacy EventEffectHandler dictionaries for overlapping vocabulary only.

2. Long term (primary)
- API-backed populate using OpenAI:
  - Input: word_id, spelling, meaningKey, source language text.
  - Output: strict JSON per language.
  - Deterministic batch pipeline with dry-run and write mode.

Implementation phases
1. Phase A: Contract hardening
- Thread word_id through event/typing/display paths.
- Convert speakAKeyWord to canonical selection.

2. Phase B: Remove runtime fallbacks
- Remove spelling-based fallback from production translation/media paths.
- Keep temporary migration flags only behind explicit debug toggles.

3. Phase C: Main words canonicalization
- Replace CustomWordSet storage model.
- Add migration for existing user defaults.

4. Phase D: Populate + gates
- Implement API-backed population command.
- Enforce strict audit in CI.

5. Phase E: Cleanup
- Remove legacy static dictionaries from production code.
- Remove deprecated runtime APIs.

Acceptance criteria
1. Runtime
- No production translation/media path uses plain-word fallback.
- No empty translation rendered/spoken for enabled language when catalog gate passes.

2. Data
- `uv run python -m scripts.catalog_translations --languages ru,de,fr,es,it,ja,zh --fail-on-missing audit` exits 0 on release catalog.

3. Codebase
- grep audit confirms word_id-first usage in EventEffectHandler, TypingGameState, WordDisplayView, RandomWordList.

4. Safety
- App startup shows critical alert if catalog coverage is incomplete.

Risks
- Incorrect legacy data migration for ambiguous spellings.
- Translation quality drift from automated population if prompts/context are weak.

Rollout
1. Dev: strict warnings + migration telemetry.
2. Beta: strict runtime, fallback disabled in tested flows.
3. Release: no legacy fallback in production paths, CI gate mandatory.
