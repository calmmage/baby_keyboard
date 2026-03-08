prd: fix remaining compound ID (`word|meaningKey`) inconsistencies
status: ready
scope: 4 issues found in full codebase audit; 2 functional bugs, 2 code quality

context
- full audit confirmed ~95% of codebase correctly uses `WordDataCatalog.makeWordID / splitWordID`
- custom image add/lookup flow is fully correct (clarification passed at every stage)
- core pipeline (JSON -> WordRepository -> RandomWordList -> EventEffectHandler -> speech) is solid
- 4 gaps remain below

---

issue 1: CustomWordSet has no meaning support (HIGH)
- file: `BabyKeyboardLock/utils/CustomWordSet.swift`
- `CustomWordPair` uses `UUID` for `.id`, stores only `english` + `translation` — no `clarification` / `meaningKey`
- `getTranslation(for:)` matches by plain english string — can't distinguish homophones
- used as fallback in `EventEffectHandler.getTranslation()` lines 612-621 for `mainWords` wordset
- impact: user adds custom "orange" → no way to specify fruit vs color; wrong image/translation possible

fix:
- add optional `clarification: String?` to `CustomWordPair`
- change `.id` from `UUID` to compound string via `makeWordID(spelling:meaningKey:)`
- update `getTranslation` to accept and match `meaningKey`
- update `getWordMap` to return compound keys
- migration: existing saved pairs have nil clarification → simple ID (backward compatible)

---

issue 2: CustomWordImage uses UUID identity (MEDIUM)
- file: `RandomWordList.swift` lines 50-102
- `CustomWordImage.id = UUID()` but `.word` field holds the compound key string
- SwiftUI `ForEach` identity is UUID, logical identity is `word|meaning`
- views use `splitKey(customImage.word)` string parsing to extract components
- not a bug today but fragile: if two entries share a UUID collision (impossible) or if identity matters for animation

fix:
- change `CustomWordImage.id` to `String` type, set to `word` field value (the compound key)
- remove `UUID()` default
- existing Codable decode: fall back to `word` value if `id` key missing (migration)

---

issue 3: warning key ambiguity with nested pipes (LOW)
- file: `EventEffectHandler.swift` lines 313, 321
- `key: "missing-translation|\(wordID)|\(language.rawValue)"`
- if wordID = `"orange|апельсин"` → key = `"missing-translation|orange|апельсин|ru"` (4 segments, not 3)
- dedup still works (exact string match) but semantically ambiguous

fix:
- use `::` separator for warning keys: `"missing-translation::\(wordID)::\(language.rawValue)"`

---

issue 4: manual ID reconstruction in sort (LOW)
- file: `AdvancedSettingsView.swift` lines 584-586
- `let lhsKey = "\(lhs.word)|\(lhs.clarification)"` — manual string concat instead of using `lhs.id`
- risk: empty string vs nil clarification produces different result than `makeWordID()`

fix:
- replace with `lhs.id.localizedCaseInsensitiveCompare(rhs.id)`

---

implementation order
1. issue 4 (1 line) — trivial, no migration
2. issue 3 (2 lines) — trivial, no migration
3. issue 2 (~10 lines) — small, backward-compatible Codable migration
4. issue 1 (~30 lines) — needs CustomWordPair schema change + UserDefaults migration

acceptance
- all word identity comparisons use `makeWordID` / existing `.id` — no manual `"\(word)|\(meaning)"` anywhere
- CustomWordSet supports clarification for homophones
- no regressions in custom image add/lookup/display flow
