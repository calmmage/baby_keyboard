I WANT TO BE ABLE TO 1) VIEW 2) ROTATE AN IMAGE SELECTED FOR A WORD

prd: let users preview and rotate custom word images by 90-degree steps
users: app users adding custom images for specific words
success: can open a preview, rotate left/right, and see rotated image in the app
non-goals: full image editor

repo notes
- custom images UI: `BabyKeyboardLock/views/ContentView.swift` -> `CustomWordImageEditorView`
- custom images storage: `BabyKeyboardLock/utils/RandomWordList.swift`
- display paths: `BabyKeyboardLock/views/WordDisplayView.swift`, `BabyKeyboardLock/views/TypingGameView.swift`

proposal
- add preview sheet with image navigation and rotate buttons
- store per-image rotation (0/90/180/270) alongside image paths
- apply rotation when rendering custom images

plan/tests
- manual: rotate image, then trigger word display/typing view and verify rotation
