prd: app cleanup — fix voice attribution, reorganize settings, fill translation gaps, wire meaning key consistently
status: ready
scope: 5 workstreams from codebase audit; ranked by user-facing impact

---

## A. voice attribution bug (HIGH — broken UX)

symptom: set ru as primary → app speaks Cyrillic text with English voice (translit sound)

investigation:
- `createUtterance()` at EventEffectHandler.swift:505 does exact match then base language fallback — looks correct in code
- `utteranceLanguage(for: .russian, allowPersonalVoice: true)` returns `"ru-RU"` — correct
- `normalizedLanguageCandidates("ru-RU")` → `["ru-ru", "ru"]` — correct
- voice filter at lines 524-538 tries exact then base — should work
- possible causes:
  1. no Russian voice installed on system (System Settings > Accessibility > Spoken Content > System Voice > Manage Voices)
  2. stale build — voice code was recently reworked
  3. AVSpeechSynthesisVoice might use different locale format on some macOS versions

fix:
- add debug logging to `createUtterance()` — log requested language, available voices count, selected voice
- verify on device: `AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ru") }` — if empty, it's a system config issue
- consider adding a "test voice" button in settings that speaks a sample word and logs the voice used

---

## B. settings reorganization (HIGH — confusing UX)

current layout (broken):
```
Main Window → Words category:
  - flashcard controls
  - word display duration
  - word sets (edit button)
  - learning pool link

Advanced Settings tabs:
  General: startup, shortcuts
  Voice: personal voice toggle, word timing, [LANGUAGE — WRONG PLACE]
  Profile: baby name, images, folder sync
  Learning Pool: featured words, rotation, mix, tags
  Advanced: empty
```

proposed layout:
```
Main Window → Words category:
  - Language section (Primary / Secondary pickers) ← MOVED HERE, prominent
  - flashcard controls
  - word display duration
  - word sets (edit button)

Advanced Settings tabs:
  General: startup, shortcuts
  Voice: personal voice toggle, word timing (no language here)
  Profile: baby name, images, folder sync
  Learning Pool: featured words, rotation, mix, tags
  (remove empty Advanced tab)
```

rationale: language selection changes what the app speaks — it's a primary control, not a voice sub-setting. Users shouldn't have to dig into advanced settings to change language.

files:
- move language pickers from `AdvancedSettingsView.swift` (VoiceLanguageSettingsView) to `ContentView.swift` (Words category)
- remove empty Advanced tab

---

## C. add clarification/meaning field to word set editor (MEDIUM)

current state:
- `RandomWordEditorView` — 2 input fields: English word + Translation (NO clarification)
- `FeaturedWordsEditorView` — 3 fields: Word + Translation + Meaning/clarification ✓
- `LearningWordEditorView` — has clarification column ✓
- `CustomWordImageEditorView` — has clarification field ✓

fix:
- add optional "Meaning" text field to RandomWordEditorView input row
- pass clarification through to `RandomWord` constructor
- bonus: auto-suggest meaning keys from catalog when word has multiple entries (e.g. typing "orange" → suggest "оранжевый" / "апельсин")

files: `RandomWordEditorView.swift` — add third input field, update `addWord()` to include clarification

---

## D. populate translations for all 149 words × 6 languages (MEDIUM)

current coverage:
- Russian (ru): 149/149 (100%)
- French/Spanish/German/Italian/Japanese/Chinese: 30/149 each (20%)
- 119 words × 6 languages = 714 missing translations
- partial fallback to hardcoded static dictionaries in EventEffectHandler.swift (lines 45-276, ~182 entries per language, but only ~31 overlap with catalog words)

storage: `BabyKeyboardLock/Resources/word_sets.json` → each entry's `translations` array:
```json
"translations": [
  { "language": "ru", "text": "яблоко" },
  { "language": "fr", "text": "pomme" },
  { "language": "es", "text": "manzana" }
]
```

approach:
- write a python script to batch-generate translations via LLM for all 119 missing words × 6 languages
- output: updated word_sets.json with complete translations
- validate: no empty strings, proper Unicode, reasonable translations
- once catalog is complete → remove hardcoded static dictionaries from EventEffectHandler (lines 45-276)
- keep static dicts only for `speakAKeyWord` mode phonics words that aren't in catalog

---

## E. compound ID consistency (from previous audit)

already fixed (this session):
- [x] manual ID reconstruction in sort → use `.id` directly (AdvancedSettingsView.swift)
- [x] warning key pipe ambiguity → use `::` separator (EventEffectHandler.swift)

remaining (from 02-22-compound-id-audit-fixes.md):
- [ ] `CustomWordSet` schema: add clarification field, use compound ID instead of UUID
- [ ] `CustomWordImage` identity: change from UUID to compound key string

---

## F. reduce fallback complexity (LOW — tech debt)

current translation resolution chain (EventEffectHandler.getTranslation):
1. baby name override
2. custom word set single-translation (mainWords only)
3. WordRepository catalog by compound ID
4. WordRepository catalog by spelling fallback
5. RandomWordList `.translation` field (Russian only)
6. hardcoded static dictionaries (7 languages × ~182 words)
7. nil → critical warning

target (after D is complete):
1. baby name override
2. custom word set (with clarification support, per E)
3. WordRepository catalog by compound ID
4. nil → critical warning

remove: steps 4-6 become unnecessary once catalog coverage is complete

---

implementation order:
1. B — move language to main settings (immediate UX win, ~30 min)
2. D — populate translations via script (unblocks removing fallbacks)
3. A — debug voice attribution (may be system config, not code)
4. C — add clarification to word set editor
5. E — CustomWordSet/CustomWordImage schema fixes
6. F — remove fallback chain once coverage is verified
