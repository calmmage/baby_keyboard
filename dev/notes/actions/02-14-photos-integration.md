The idea is to follow Apple Photos to detect photos references some images, so literally just do a search for a table, a person, some kind of integration that way. I wonder if it's possible, but I'd like to reuse local photos if that's feasible at all and with custom word searches relevant to the word we are showcasing, but somehow cache it and speed it up. Obviously, first, build a prototype demo that showcases if it's possible to pull the user's photo with photo access and then use it in the app efficiently.

prd: explore Apple Photos integration to source relevant local images for words
users: app users with local photo libraries
success: prototype can query photos by keyword/person and return usable images; caching avoids repeated scans
non-goals: full production integration

repo notes
- app UI: `BabyKeyboardLock/views/ContentView.swift`
- image pipeline: `BabyKeyboardLock/utils/RandomWordList.swift`, `BabyKeyboardLock/views/WordDisplayView.swift`

proposal
- build a standalone prototype in `dev/` to request Photos access and run a keyword/person search
- measure query speed and cache results to a local index
- if feasible, design a minimal app integration behind a toggle

plan/tests
- prototype script/app using Photos framework
- verify access prompt and query results
