Vocabulary.
- there's a new feature in the repo that is supposed to introduce smart word vocabulary rotation. I've built it but not properly tested. I am starting to think that components of it are not wired 
- I noticed auto-rotation of the vocabulary just doesn't work
Also, there's a task to add easy vocab preview

prd: learning rotation reliably drives random word selection and exposes a simple preview of the current pool
users: app users tuning word rotation
success: learning rotation changes output; pool preview visible and correct
non-goals: redesign full settings UI

repo notes
- rotation data + pool: `BabyKeyboardLock/utils/RandomWordList.swift` (learning* fields, `getLearningRandomWord`, `refreshLearningPool`, `getLearningPoolInfo`)
- toggle + sliders UI: `BabyKeyboardLock/views/ContentView.swift`
- editor UI: `BabyKeyboardLock/views/LearningWordEditorView.swift`
- random word selection entry: `BabyKeyboardLock/EventEffectHandler.swift` -> `speakRandomWord` -> `RandomWordList.shared.getRandomWord()`

suspected wiring gaps
- if `learningRotationEnabled` is true but pool is empty, `getLearningRandomWord` returns nil and `getRandomWord` does not fall back
- pool only refreshes daily or on manual refresh; may stay empty if sync fails
- preview exists only in editor; no quick view in main settings

proposal
- make `getRandomWord` fall back to standard random when learning pool is empty
- log when learning rotation is enabled but pool is empty
- add a lightweight pool preview sheet (table) in `ContentView` using `learningPoolKeys`/`learningWords`

plan/tests
- update `getRandomWord` fallback and add debug prints
- add preview button next to pool info and show a table (word, translation, known, favorite, tags)
- manual test: enable learning rotation, verify non-empty pool, verify rotation changes output
