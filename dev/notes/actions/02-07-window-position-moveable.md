Make the settings window open in the top right corner instead of middle of the screen
Make the window with words closeable and moveable (hotkey? How to drag it?)

prd: adjust window positioning and make word display window closeable/moveable
users: app users on different monitors
success: settings opens top-right; word display window can be closed and dragged or toggled
non-goals: full window system refactor

repo notes
- task key: 09461e23 (`dev/notes/tasks.md`)
- settings window: `BabyKeyboardLock/views/ContentView.swift`, `BabyKeyboardLock/BabyKeyboardLockApp.swift`
- word display window: `BabyKeyboardLock/views/WordDisplayView.swift`, `BabyKeyboardLock/BabyKeyboardLockApp.swift`

proposal
- set main settings window frame to top-right on open
- make word display window moveable/closeable behind a toggle or hotkey

plan/tests
- manual: open settings and verify position
- manual: open word display window, drag/move/close, verify no lockups
