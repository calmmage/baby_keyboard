Make sure we can (pre)view the current pool of words in the selection

prd: add quick preview of the current learning/selection pool
users: app users tuning learning rotation
success: pool list visible; shows status and category
non-goals: full analytics dashboard

repo notes
- task key: f0750a6c (`dev/notes/tasks.md`)
- cue: Can't see which words are actually selected
- learning pool source: `BabyKeyboardLock/utils/RandomWordList.swift`
- UI entry: `BabyKeyboardLock/views/ContentView.swift`, `BabyKeyboardLock/views/LearningWordEditorView.swift`

proposal
- add a compact table modal from settings showing current pool
- columns: word, translation, known, favorite, seen count, tags/category

plan/tests
- manual: open preview and verify pool matches current settings
