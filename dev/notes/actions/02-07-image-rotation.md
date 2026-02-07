Let me clarify about the image rotation. Basically for the images we customly upload. What I want is an ability to rotate the images.

prd: custom images for a word rotate predictably across repeated displays
users: app users adding multiple custom images for a word
success: repeated triggers cycle through all images; no repeats until the queue is exhausted
non-goals: redesign image picker

repo notes
- custom image selection: `BabyKeyboardLock/utils/RandomWordList.swift` -> `getCustomImageURL`, `nextCustomImageIndex`
- display path: `BabyKeyboardLock/views/WordDisplayView.swift`, `BabyKeyboardLock/views/TypingGameView.swift`

suspected issues
- rotation queue advanced on each call; view re-render or multiple calls can skip images
- bookmark array can be shorter than `imagePaths`, which forces the first bookmark and breaks rotation

proposal
- cache selected image URL per displayed word (avoid advancing multiple times per render)
- if bookmark for an index is missing, fall back to the path for that index
- rebuild missing bookmarks on load when possible

plan/tests
- update `WordDisplayView`/`TypingGameView` to reuse a cached URL per word
- update `RandomWordList` bookmark handling
- manual test: add 3 images for a word, trigger 10 times, verify full rotation
