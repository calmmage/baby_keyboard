---
calmmage_id: nn0vXJFT
---
- x1
    - Auto-move word to `known` after X views
    - Add settings control for threshold X (default: 20)
    - `X = 0` disables auto-marking
    - Apply rule when `seenCount` increments in learning rotation
    - PRD: `dev/notes/actions/02-14-vocab-scale-pool-flashcards-enrichment.md`
- x2
    - Word sets future rework: add virtual `All words` set + large curated `basic` / `middle` / `advanced` sets
    - `All words` should be computed (not explicit giant `wordIDs` list)
    - Generate big sets via scripts and ship in bundled catalog
    - PRD: `dev/notes/actions/02-14-vocab-scale-pool-flashcards-enrichment.md`
- b
    - `key: a5c5f25c`
    - Plan controlled generation for remaining images (on-demand + capped batch)
    - PRD: `dev/notes/actions/02-14-image-generation-rest-prd-plan.md`
- c
    - `key: 98723cbd`
    - Plan rollout for generating and ingesting the rest of flashcard videos (manual-first, then API batch)
    - PRD: `/Users/petrlavrov/calmmage/new/ai-tasks/02-14-baby-keyboard/05-video-generation-rollout-plan/prd.md`
- d
    - `key: aa458095`
    - Scale vocabulary + pool + flashcards + AI enrichment to 10k words
    - PRD: `dev/notes/actions/02-14-vocab-scale-pool-flashcards-enrichment.md`
- e
    - `key: d07be04c`
    - `cue: Just saw a bug`
    - Bugfix: custom image is incorrectly scaled when it's rotated - shown out of proportion in a frame
- f
    - `key: 75d1b16e`
    - Make the window with words flashcard closeable and moveable (hotkey? How to drag it? Still not working. Is there a hotkey? Can we do an 'x' button?)
- g
    - `key: ddd1a65b`
    [Service utility]
    Publish calmlib, install and download quick draw images
- h
    - `key: 48f24568`
    - Finish scripts.word_dictionary_showcase to generate a rich progressive dictionary and add definition mode
    - use python scripts to generate unlimited (full nltk) word pool.
    - Decide if we should commit the whole thing or add words dynamically when the current pool is finished learning
    - PRD: `dev/notes/actions/02-07-dictionary-showcase-definition.md`
    - Related PRD: `dev/notes/actions/02-08-wordset-generation-1000.md`
- i
    - `key: f0750a6c`
    - `cue: Can't see which words are actually selected`
    - Make sure we can (pre)view the current pool of words in the selection
    - Bonus: make it a table that showcases
        - status in learning (num viewings, known or not)
        - category in database - e.g. activity / relative / item / ...
    - PRD: `dev/notes/actions/02-07-word-pool-preview.md`
    - Related PRD: `dev/notes/actions/02-07-vocab-rotation-preview.md`
- j
    - `key: 45ed1f4f`
    - Add multi-image support to photos
    - PRD: `dev/notes/actions/1-image-cache.md`
- k
    - `key: 4acf1c5b`
    - `cue: I'm tired of manually deleting and re-adding the app in privacy settings`
    - Add permissions reset command
    - Add a command to quickly re-set permissions (with sudo) of the app after deploy (delete and re-add)
- l
    - `key: e271e2ab`
    - `cue: I have to re-load photos every time I relaunch the app, and it is annoying`
    - Debug and fix photo loading issue
    - Add custom photos config
    - Add a text yaml config of local photos - to avoid re-adding them constantly. Re-load on start
    - PRD: `dev/notes/actions/02-08-images-folder-auto-sync.md`
- m
    - `key: eca3009a`
    [Publishing]
    Find a way to publish and distribute images other than git - upload to storage, download on first launch
    - PRD: `dev/notes/actions/02-08-app-website-supabase-merge.md`
- n
    - `key: 8bd1d2ea`
    [Dictionary]
    Fix issues with words meanings and image discrepancies - Orange - color and fruit, drink - verb and noun
    - PRD: `dev/notes/actions/7-collisions.md`
- o
    - `key: 441b4ef3`
    - `cue: My PC turns into a heater when I run my app..`
    [Audio]
    - Generate audio samples with TTS and cache on disk to prevent running heavy AI model every time instead of just playing the sound
    - Add 'refresh cache' button in Settings
- p
    - `key: 78983d50`
    [Gamification]
    Test the flashcard display for game mode
- q
    - `key: 4abc703d`
    - `cue: Couldn't get a specific word - mama - to appear at all`
    [Probably solved]
    - Rework random into pseudo-random that balances probabilities into a more even shuffle
    - PRD: `dev/notes/actions/2-rng.md`
- r
    - `key: 490a0894`
      Load images from user folder instead of including resources in the package. Bonus: Auto-generate words for images and use that set in text
    - PRD: `dev/notes/actions/02-08-images-folder-auto-sync.md`
- s
    - `key: 8e21dce0`
    [Future idea, when Daria grows]
    - Gamify keyboard locker somehow
    - Idea 1: Add a new mode, where the baby has to type the word correctly for it to appear on the screen and be
      pronounced
    - When baby types the letters correctly - make them appear on screen (e.g. if she types 'M' - show 'M', then add
      'A' etc.). Allow any words from selected word sets.
      Some nice animation when the word is completed correctly
    - Add a setting checkbox "reset on error".
    Improve game mode - remove per-letter sound, Allow all words simultaneousl
    - PRD: `dev/notes/actions/3-gamify-random-word.md`
- t
    - `key: 8d4d24da`
    - `cue: I tried to deploy on Anna's macbook using make deploy, and it failed saying it can't export archive because it misses the certificate. The main question is do i create a new one or copy this one?`
    [Publishing and sharing]
    - Figure out how to deploy on another machine - missing certificate
    Build description signature: c6f264918b4db5acd581c2181fb6fac3
    Build description path: /Users/annalav/Library/Developer/Xcode/DerivedData/BabyKeyboardLock-bgubpirqszsziihdvtozqvgxmqja/Build/Intermediates.noindex/ArchiveIntermediates/BabyKeyboardLock/IntermediateBuildFilesPath/XCBuildData/c6f264918b4db5acd581c2181fb6fac3.xcbuilddata
    /Users/annalav/Documents/GitHub/baby_keyboard/BabyKeyboardLock.xcodeproj: error: No signing certificate "Mac Development" found: No "Mac Development" signing certificate matching team ID "5XCYR4LUMD" with a private key was found. (in target 'BabyKeyboardLock' from project 'BabyKeyboardLock')
    a
- u
    - `key: 6d7aeb24`
    - `cue: We need one clear place for data model and migration`
    - Migrate New data model
    - Unify word dataset + meaning ids + annotations + translations + assets + definitions
    - Decide local initialization/reset workflow + future sync path
    - PRD: `dev/notes/actions/02-07-word-data-model-storage.md`
    - Related PRD: `dev/notes/actions/02-08-data-model-integration-migration.md`
- v
    - `key: 9f1a2c63`
    - `cue: Manage images in Finder and auto-sync into app`
    - Add images-folder bookmark + scan/sync on launch
    - Map file names to `word|meaningKey` keys and support multi-image naming
    - PRD: `dev/notes/actions/02-08-images-folder-auto-sync.md`
- w
    - `key: a4c9d031`
    - `cue: Merge app + website data/auth`
    - Design Supabase schema/auth/RLS + local mirror cache strategy
    - Prototype client fetch + asset download path
    - PRD: `dev/notes/actions/02-08-app-website-supabase-merge.md`
- x
    - `key: b2e8f5a1`
    - `cue: Reuse Apple Photos for word images`
    - Build a prototype for Photos permission + keyword/person search + caching
    - Evaluate performance and feasibility for app integration
    - PRD: `dev/notes/actions/02-14-photos-integration.md`
- y
    - Add featured words mechanism to baby keyboard (separate interactive window + always include in learning pool; bonus web parity)
    - PRD: `/Users/petrlavrov/calmmage/new/ai-tasks/02-14-baby-keyboard/04-featured-words/prd.md`
    - `key: 53b9c0f2`
    - `cue: first launch should guide setup clearly`
    - Design first-launch onboarding flow with guided setup and skip option
    - PRD: `dev/notes/actions/02-09-onboarding-first-launch.md`
- z
    - `key: 0f7e6a4d`
    - `cue: learning pool controls are confusing`
    - Rework learning-pool mix controls to normalized/understandable behavior while preserving mixed selection
    - PRD: `dev/notes/actions/02-09-learning-pool-mix-ux.md`
- aa
    - `key: 3c97b24e`
    - `cue: drop old web and rebuild cleanly around canonical data model`
    - Rewrite web app from scratch with canonical `word|meaningKey` IDs and v2 APIs
    - Keep/re-implement image generation on the fly and audio recording flows
    - Document old web architecture/packages worth reusing (framework/UI/data stack)
    - PRD: `dev/notes/actions/02-09-web-rewrite-from-scratch.md`
- ab
    - `key: 5f12c8ad`
    - `cue: generate reusable audio cache with Personal Voice`
    - Build Python + Swift pipeline to generate audio files from canonical words and cache with manifest
    - Support Personal Voice with deterministic fallback behavior
    - PRD: `dev/notes/actions/02-09-personal-voice-audio-generation.md`
## Done
- [x] a
    - `key: 687f2ef9`
    - Rework settings split: move secondary/stationary controls to Settings scene, keep main window for frequent controls
    - PRD: `/Users/petrlavrov/calmmage/new/ai-tasks/02-14-baby-keyboard/03-rework-settings/prd.md`
- [x] ac
    - `key: f260c606`
    - `cue: There's too many buttons now, including 'no images' and 'random' - we could instead allow customizing enabling each style separately`
    - Rework 'images' to bool flags enable / disable
- [x] ad
    - `key: bf68e67c`
    - `cue: How do i enrich the features of the app instead of just background rework`
    - Generate videos based on photos as first frame and play them on a second key press
- [x] ae
    - `key: 22b01d8d`
    - `cue: Just saw a bug`
    - Bugfix: We have both 'granddad' and 'grandpa'. Remove the one that's in the dict in text - replace with other
- [x] ai
    - `key: e3b45d72`
    - Add custom image preview + 90-degree rotation support
    - PRD: `dev/notes/actions/02-07-image-rotation.md`
- [x] aj
    - `key: 09461e23`
    - Make the settings window open in the top right corner instead of middle of the screen
    - PRD: `dev/notes/actions/02-07-window-position-moveable.md`
