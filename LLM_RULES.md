AI agent notes for this repo
- entry points: `BabyKeyboardLock/BabyKeyboardLockApp.swift`, `BabyKeyboardLock/views/ContentView.swift`
- effect registry + categories: `BabyKeyboardLock/LockEffect.swift`
- event pipeline: `BabyKeyboardLock/EventHandler.swift` (state, throttles) -> `BabyKeyboardLock/EventEffectHandler.swift` (effect logic)
- overlay windows: `BabyKeyboardLock/views/WordDisplayView.swift`, `BabyKeyboardLock/views/AnimationView.swift`, `BabyKeyboardLock/views/VisualEffectsView.swift`
- typing game: `BabyKeyboardLock/views/TypingGameView.swift`, `BabyKeyboardLock/TypingGameState.swift`
- localization strings: `BabyKeyboardLock/Localizable.xcstrings`
- tests: `BabyKeyboardLockTests/`, `BabyKeyboardLockUITests/`
- scripts/tools: `scripts/`, `archive/`

random word mode is the main application in the app (most code) and the default words mode
- data/model + persistence: `BabyKeyboardLock/utils/RandomWordList.swift`
- word sets (default sets, enable/disable, user defaults), baby name + probability, recent history, learning pool, custom images/bookmarks
- editor UI for sets/words: `BabyKeyboardLock/views/RandomWordEditorView.swift`
- settings UI + toggles: `BabyKeyboardLock/views/ContentView.swift` (word throttle, translation delay, display duration, gamify, learning pool sliders, word set enabling, custom images, learning editor)
- display/flashcards: `BabyKeyboardLock/views/WordDisplayView.swift` (word + translation overlay, flashcard image resolution: custom image -> baby image -> generated, size + duration)
- effect logic: `BabyKeyboardLock/EventEffectHandler.swift` (speakRandomWord, word selection + translations), `BabyKeyboardLock/EventHandler.swift` (gamifyRandomWord state)
- custom images UI: `BabyKeyboardLock/views/ContentView.swift` -> `CustomWordImageEditorView`
- learning words UI: `BabyKeyboardLock/views/ContentView.swift` -> `LearningWordEditorView`
