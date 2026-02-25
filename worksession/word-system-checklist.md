[ ] 1) Update all other code paths to the new indexing system; add more words; add `frequency`/popularity field.
[ ] 2) Review and integrate the existing word-pools script you created.
[ ] 3) Add `definition` field and definitions for all translations.
[ ] 4) Add articles for German (and evaluate equivalent metadata for other languages), e.g. `der Hund`.
[ ] 5) Improve user-facing “add new words” interface to be friendly and reasonable.
[ ] 6) Build a script that can add/augment words on the fly (AI API-assisted).

Notes:
- Do not mark any item as discussed unless explicitly confirmed by you.
- All checklist items are currently not discussed.

Low-hanging fruits to start with (proposed order, not marked discussed):
1. Item 2 (review existing word-pools script).
2. Item 4 (language article metadata model, starting with German).
3. Item 1 (indexing consistency pass; frequency field schema definition).

## Discussion Log

### 2026-02-25 - Initialization
- Created this checklist from your 6 items.
- No items marked as discussed.

### 2026-02-25 - Item 4 discussion
- Question: for which languages article metadata makes sense.
- Current app language set confirmed: `en`, `fr`, `ru`, `de`, `es`, `it`, `ja`, `zh`.
- Strong fit for article fields: `de`, `fr`, `es`, `it`.
- Optional fit: `en` (`a/an/the`) depending on pedagogy mode.
- Not article-based (skip article fields): `ru`, `ja`, `zh`.
- Direction from you: bake articles directly into translation text for `de`, `fr`, `es`, `it`.
- Additional direction: add definitions for all words; first implement one sample word only for review.
- Applied sample to first word (`mama|mother`) in `word_sets.json`.
- Additional direction: apply the same format to all words directly in JSON.
- Applied full-file update in `word_sets.json`: noun translations now include articles for `de`, `fr`, `es`, `it`; definitions are present for all entries and all translation languages.
- Adjustment requested by you: keep same-topic notes under one header.
- Item 4 and item 3 are still not marked as discussed.
