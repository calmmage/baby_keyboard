1) Simple idea: save 'baby keyboard images' folder - and on launch auto-discover the images there, pull them in (i mean sync). I guess we will need some simple dict (word id <-> simple image name) 

prd: auto-sync a local “baby keyboard images” folder into custom word images
users: app users who want to manage images in Finder, not via UI re-adding
success: on launch, app scans the folder and updates custom images; no repeated manual picking
non-goals: cloud sync

repo notes
- custom images storage + bookmarks: `BabyKeyboardLock/utils/RandomWordList.swift` (`customWordImages`, `customWordImageBookmarks`, `getCustomImageURL`, `rebuildCustomImageBookmarksIfNeeded`)
- custom images UI: `BabyKeyboardLock/views/ContentView.swift` -> `CustomWordImageEditorView`

constraints
- accessing arbitrary folders reliably needs a security-scoped bookmark (user picks folder once)
- must not block UI on scanning; do it async

proposal
- add setting: “Images folder” with a “Select folder” button
- store folder bookmark in UserDefaults; on launch resolve bookmark and scan for image files
- naming convention => word id mapping:
- file name base maps to `wordKey` (same format already used): `word` or `word|meaningKey`
- optionally allow `word|meaningKey__N.ext` for multi images
- build sync:
- scan files, group by word key, sort stable, update `customWordImages[wordKey].imagePaths` to match
- rebuild bookmarks for new paths; prune removed paths + bookmarks

plan/tests
- implement `ImagesFolderSync` helper (new file) called from `RandomWordList.init()` after `loadCustomWordImages()`
- add minimal UI in `ContentView` to pick/reset folder
- manual: pick folder, add/remove/rename images in Finder, relaunch, verify the list updates + preview works
